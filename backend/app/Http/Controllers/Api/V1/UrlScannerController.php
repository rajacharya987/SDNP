<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ScanUrlRequest;
use App\Models\ScanHistory;
use App\Services\GeminiService;
use App\Services\GoogleSafeBrowsingService;
use App\Services\OpenPhishService;
use App\Services\PhishTankService;
use App\Services\SiteAvailabilityService;
use App\Services\UrlhausService;
use App\Services\VirusTotalService;
use Illuminate\Http\Client\Pool;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class UrlScannerController extends Controller
{
    public function __construct(
        protected GoogleSafeBrowsingService $googleService,
        protected VirusTotalService $virusTotalService,
        protected OpenPhishService $openPhishService,
        protected PhishTankService $phishTankService,
        protected UrlhausService $urlhausService,
        protected SiteAvailabilityService $availabilityService,
        protected GeminiService $geminiService
    ) {}

    /**
     * Scan URL or Subscription Link for security threats.
     */
    public function scan(ScanUrlRequest $request)
    {
        $url = trim($request->validated()['url']);

        if (!preg_match('#^https?://#i', $url)) {
            $url = 'https://' . $url;
        }

        $parsedUrl = parse_url($url);
        $host = strtolower($parsedUrl['host'] ?? '');

        if ($host === '') {
            return $this->errorResponse('Invalid URL format provided', 422);
        }

        $cacheKey = 'safelink_scan_' . md5($url);
        $cached = Cache::get($cacheKey);
        if (is_array($cached) && ($cached['checks_complete'] ?? false) === true) {
            return $this->successResponse($cached, 'URL security analysis complete');
        }

        $heuristicResult = $this->runHeuristics($url, $host);
        $availability = $this->availabilityService->check($url, $host);
        $intel = $this->fetchThreatIntelParallel($url, $host);

        $googleResult = $intel['google'];
        $virusTotalResult = $intel['virustotal'];
        $openPhishResult = $intel['openphish'];
        $phishTankResult = $intel['phishtank'];
        $urlhausResult = $intel['urlhaus'];

        $riskScore = 0;
        $threatDetails = [];

        $siteAvailable = ($availability['available'] ?? false) === true;
        if (!$siteAvailable) {
            $riskScore += 25;
            $threatDetails[] = $availability['message'] ?? 'This site is not available';
        }

        if (!empty($heuristicResult['threats'])) {
            $riskScore += $heuristicResult['score'];
            $threatDetails = array_merge($threatDetails, $heuristicResult['threats']);
        }

        if ($googleResult['is_malicious'] ?? false) {
            $riskScore += 60;
            $threatDetails[] = 'Google Safe Browsing: Flagged as ' . implode(', ', $googleResult['threat_types'] ?? ['threat']);
        }

        if ($virusTotalResult['is_malicious'] ?? false) {
            $maliciousVendors = $virusTotalResult['stats']['malicious'] ?? 0;
            $riskScore += min(50, $maliciousVendors * 15);
            $threatDetails[] = "VirusTotal: Flagged by {$maliciousVendors} security vendors";
        } elseif (($virusTotalResult['is_suspicious'] ?? false) || (($virusTotalResult['stats']['suspicious'] ?? 0) > 0)) {
            $suspiciousVendors = (int) ($virusTotalResult['stats']['suspicious'] ?? 0);
            $riskScore += min(25, $suspiciousVendors * 8);
            $threatDetails[] = "VirusTotal: Marked suspicious by {$suspiciousVendors} vendors";
        }

        if ($openPhishResult['is_malicious'] ?? false) {
            $riskScore += 70;
            $threatDetails[] = 'OpenPhish: ' . ($openPhishResult['message'] ?? 'Listed phishing URL');
        }

        if ($phishTankResult['is_malicious'] ?? false) {
            $riskScore += 70;
            $threatDetails[] = 'PhishTank: ' . ($phishTankResult['message'] ?? 'Verified phishing');
        }

        if ($urlhausResult['is_malicious'] ?? false) {
            $riskScore += 65;
            $threatDetails[] = 'URLhaus: ' . ($urlhausResult['message'] ?? 'Malware URL/host');
        }

        $providerStatuses = [
            'google_safe_browsing' => $googleResult['status'] ?? 'error',
            'virustotal' => $virusTotalResult['status'] ?? 'error',
            'openphish' => $openPhishResult['status'] ?? 'error',
            'phishtank' => $phishTankResult['status'] ?? 'error',
            'urlhaus' => $urlhausResult['status'] ?? 'untested',
        ];

        $cleanCount = 0;
        $errorCount = 0;
        $attemptedCount = 0;

        foreach ($providerStatuses as $status) {
            if ($status === 'untested') {
                continue;
            }
            $attemptedCount++;
            if ($status === 'clean') {
                $cleanCount++;
            } elseif ($status === 'error') {
                $errorCount++;
            }
        }

        foreach ($providerStatuses as $name => $status) {
            if ($status === 'error') {
                $label = str_replace('_', ' ', $name);
                $threatDetails[] = ucfirst($label) . ' check failed — result incomplete';
            }
        }

        $finalScore = min(100, $riskScore);
        $checksComplete = $errorCount === 0 && $cleanCount >= 2;
        if ($attemptedCount === 1 && $cleanCount === 1 && empty($heuristicResult['threats']) && $errorCount === 0) {
            $checksComplete = true;
        }
        // OpenPhish always attempted when feed works — if only feed + one other clean
        if (!$checksComplete && $cleanCount >= 2 && $errorCount === 0) {
            $checksComplete = true;
        }

        if ($finalScore < 35 && !$checksComplete) {
            $finalScore = max($finalScore, 35);
            $threatDetails[] = 'Incomplete security check — do not trust this link yet';
        }

        if ($finalScore >= 70) {
            $verdict = 'DANGEROUS';
            $verdictTitle = 'Dangerous Phishing / Scam Source';
            $verdictColor = 'red';
        } elseif ($finalScore >= 35) {
            $verdict = 'SUSPICIOUS';
            $verdictTitle = $checksComplete
                ? 'Suspicious or Unverified Subscription Link'
                : 'Incomplete security check — do not trust yet';
            $verdictColor = 'yellow';
        } else {
            $verdict = 'SAFE';
            $verdictTitle = 'Safe & Clean Domain';
            $verdictColor = 'green';
        }

        // Never allow SAFE when checks incomplete
        if ($verdict === 'SAFE' && !$checksComplete) {
            $verdict = 'SUSPICIOUS';
            $verdictTitle = 'Incomplete security check — do not trust yet';
            $verdictColor = 'yellow';
            $finalScore = max($finalScore, 35);
        }

        // Site down / does not exist — always surface clearly (keep danger if already worse)
        if (!$siteAvailable) {
            if ($verdict === 'SAFE') {
                $verdict = 'UNAVAILABLE';
                $verdictColor = 'yellow';
                $finalScore = max($finalScore, 35);
            } elseif ($verdict === 'SUSPICIOUS') {
                $verdict = 'UNAVAILABLE';
            }
            $verdictTitle = 'This site is not available';
        }

        $threatDetails = array_values(array_unique(array_filter($threatDetails)));

        $deepAnalysis = [
            'status' => 'skipped',
            'message' => 'Pattern analysis unavailable.',
            'summary' => '',
        ];

        $explain = $this->geminiService->explainScan([
            'url' => $url,
            'domain' => $host,
            'verdict' => $verdict,
            'risk_score' => $finalScore,
            'site_available' => $siteAvailable,
            'threat_details' => $threatDetails,
            'checks_complete' => $checksComplete,
            'providers' => $providerStatuses,
        ]);

        $analystSummary = '';
        if (is_array($explain)) {
            $deepAnalysis = [
                'status' => $explain['status'] ?? 'skipped',
                'message' => $explain['message'] ?? 'Pattern analysis completed.',
                'summary' => $explain['summary'] ?? '',
            ];
            $analystSummary = (string) ($explain['summary'] ?? '');
            foreach ($explain['extra_findings'] ?? [] as $finding) {
                if ($finding !== '') {
                    $threatDetails[] = $finding;
                }
            }
            $threatDetails = array_values(array_unique(array_filter($threatDetails)));
            // Wording only — do not let deep analysis flip SAFE to DANGEROUS alone
            if ($analystSummary !== '' && in_array($verdict, ['SAFE', 'SUSPICIOUS', 'UNAVAILABLE'], true)) {
                // Keep verdict_title for SAFE/DANGEROUS rigid cases; enrich SUSPICIOUS/UNAVAILABLE lightly
                if ($verdict === 'SUSPICIOUS' && strlen($analystSummary) < 120) {
                    $verdictTitle = $analystSummary;
                }
            }
        }

        $payload = [
            'url' => $url,
            'domain' => $host,
            'verdict' => $verdict,
            'verdict_title' => $verdictTitle,
            'verdict_color' => $verdictColor,
            'risk_score' => $finalScore,
            'checks_complete' => $checksComplete,
            'providers_clean' => $cleanCount,
            'site_available' => $siteAvailable,
            'analyst_summary' => $analystSummary !== ''
                ? $analystSummary
                : ($verdictTitle.' SafeLink scan finished.'),
            'threat_details' => $threatDetails,
            'breakdown' => [
                'availability' => $availability,
                'heuristics' => $heuristicResult,
                'google_safe_browsing' => $googleResult,
                'virustotal' => $virusTotalResult,
                'openphish' => $openPhishResult,
                'phishtank' => $phishTankResult,
                'urlhaus' => $urlhausResult,
                'deep_analysis' => $deepAnalysis,
            ],
            'scanned_at' => now()->toIso8601String(),
        ];

        $cacheHours = (int) config('safelink.thresholds.cache_hours', 24);
        if ($checksComplete) {
            Cache::put($cacheKey, $payload, now()->addHours($cacheHours));
        } else {
            Cache::put($cacheKey, $payload, now()->addMinutes(2));
        }

        $userId = $request->user()?->id;
        dispatch(function () use ($payload, $googleResult, $virusTotalResult, $heuristicResult, $userId) {
            try {
                ScanHistory::create([
                    'user_id' => $userId,
                    'url' => $payload['url'],
                    'domain' => $payload['domain'],
                    'verdict' => $payload['verdict'],
                    'risk_score' => $payload['risk_score'],
                    'threat_details' => $payload['threat_details'],
                    'google_safe_browsing_status' => $googleResult['status'] ?? 'unknown',
                    'virustotal_status' => $virusTotalResult['status'] ?? 'unknown',
                    'heuristics_status' => empty($heuristicResult['threats']) ? 'passed' : 'flagged',
                ]);
            } catch (\Exception $e) {
                Log::warning('Failed to log scan history', ['error' => $e->getMessage()]);
            }
        })->afterResponse();

        return $this->successResponse($payload, 'URL security analysis complete');
    }

    public function history()
    {
        $logs = ScanHistory::latest()->take(50)->get();
        return $this->successResponse($logs, 'Recent scan history fetched');
    }

    /**
     * Parallel threat intel from free + existing providers.
     */
    protected function fetchThreatIntelParallel(string $url, string $host): array
    {
        $googleConfigured = $this->googleService->isConfigured();
        $vtConfigured = $this->virusTotalService->isConfigured();
        $urlhausConfigured = $this->urlhausService->isConfigured();

        $openPhishResult = $this->openPhishService->checkUrl($url, $host);

        try {
            $googleService = $this->googleService;
            $virusTotalService = $this->virusTotalService;
            $phishTankService = $this->phishTankService;
            $urlhausService = $this->urlhausService;

            $responses = Http::pool(function (Pool $pool) use (
                $url,
                $host,
                $googleConfigured,
                $vtConfigured,
                $urlhausConfigured,
                $googleService,
                $virusTotalService,
                $phishTankService,
                $urlhausService
            ) {
                $requests = [];

                if ($googleConfigured) {
                    $requests['google'] = $pool->as('google')
                        ->timeout(8)
                        ->connectTimeout(3)
                        ->acceptJson()
                        ->asJson()
                        ->post($googleService->endpoint(), $googleService->payload($url));
                }

                if ($vtConfigured) {
                    $requests['vt'] = $pool->as('vt')
                        ->withHeaders(['x-apikey' => $virusTotalService->apiKey()])
                        ->timeout(8)
                        ->connectTimeout(3)
                        ->acceptJson()
                        ->get($virusTotalService->lookupUrl($url));
                }

                $requests['phishtank'] = $pool->as('phishtank')
                    ->asForm()
                    ->timeout(8)
                    ->connectTimeout(3)
                    ->withHeaders(['User-Agent' => 'phishtank/SafeLink-AI'])
                    ->post($phishTankService->endpoint(), $phishTankService->formParams($url));

                if ($urlhausConfigured) {
                    $requests['urlhaus'] = $pool->as('urlhaus')
                        ->asForm()
                        ->withHeaders(['Auth-Key' => $urlhausService->authKey()])
                        ->timeout(8)
                        ->connectTimeout(3)
                        ->post($urlhausService->urlEndpoint(), ['url' => $url]);

                    $requests['urlhaus_host'] = $pool->as('urlhaus_host')
                        ->asForm()
                        ->withHeaders(['Auth-Key' => $urlhausService->authKey()])
                        ->timeout(8)
                        ->connectTimeout(3)
                        ->post($urlhausService->hostEndpoint(), ['host' => $host]);
                }

                return $requests;
            });

            $googleResult = $googleConfigured
                ? $this->googleService->interpret(
                    ($responses['google'] ?? null)?->successful() ? $responses['google']->json() : null,
                    ($responses['google'] ?? null)?->successful() ?? false,
                    ($responses['google'] ?? null)?->body() ?? '',
                    ($responses['google'] ?? null)?->status() ?? 0
                )
                : $this->googleService->untestedResult();

            if ($vtConfigured) {
                $vtResponse = $responses['vt'] ?? null;
                if ($vtResponse && $vtResponse->status() === 404) {
                    $virusTotalResult = $this->virusTotalService->scanUrl($url);
                } else {
                    $virusTotalResult = $this->virusTotalService->interpret(
                        $vtResponse?->successful() ? $vtResponse->json() : null,
                        $vtResponse?->successful() ?? false,
                        $vtResponse?->body() ?? '',
                        $vtResponse?->status() ?? 0
                    );
                }
            } else {
                $virusTotalResult = $this->virusTotalService->untestedResult();
            }

            $ptResponse = $responses['phishtank'] ?? null;
            if ($ptResponse === null || $ptResponse instanceof \Illuminate\Http\Client\RequestException || !method_exists($ptResponse, 'successful')) {
                $phishTankResult = $this->phishTankService->checkUrl($url);
            } else {
                $phishTankResult = $this->phishTankService->interpret(
                    $ptResponse->successful() ? $ptResponse->json() : null,
                    $ptResponse->successful(),
                    $ptResponse->body(),
                    $ptResponse->status()
                );
                // Pool can flake on PhishTank — retry once sequentially
                if (($phishTankResult['status'] ?? '') === 'error') {
                    $phishTankResult = $this->phishTankService->checkUrl($url);
                }
            }

            if ($urlhausConfigured) {
                $uhUrl = $responses['urlhaus'] ?? null;
                $uhHost = $responses['urlhaus_host'] ?? null;
                $urlResult = $this->urlhausService->interpretUrl(
                    $uhUrl?->successful() ? $uhUrl->json() : null,
                    $uhUrl?->successful() ?? false,
                    $uhUrl?->body() ?? ''
                );
                if ($urlResult['is_malicious']) {
                    $urlhausResult = $urlResult;
                } else {
                    $hostResult = $this->urlhausService->interpretHost(
                        $uhHost?->successful() ? $uhHost->json() : null,
                        $uhHost?->successful() ?? false,
                        $uhHost?->body() ?? ''
                    );
                    if ($hostResult['is_malicious']) {
                        $urlhausResult = $hostResult;
                    } elseif ($urlResult['status'] === 'error' && $hostResult['status'] === 'error') {
                        $urlhausResult = $urlResult;
                    } else {
                        $urlhausResult = [
                            'status' => 'clean',
                            'is_malicious' => false,
                            'message' => 'Not listed in URLhaus malware database.',
                        ];
                    }
                }
            } else {
                $urlhausResult = $this->urlhausService->untestedResult();
            }

            return [
                'google' => $googleResult,
                'virustotal' => $virusTotalResult,
                'openphish' => $openPhishResult,
                'phishtank' => $phishTankResult,
                'urlhaus' => $urlhausResult,
            ];
        } catch (\Throwable $e) {
            Log::warning('Parallel threat intel failed, falling back', ['error' => $e->getMessage()]);
            return [
                'google' => $this->googleService->checkUrl($url),
                'virustotal' => $this->virusTotalService->scanUrl($url),
                'openphish' => $openPhishResult,
                'phishtank' => $this->phishTankService->checkUrl($url),
                'urlhaus' => $this->urlhausService->checkUrl($url, $host),
            ];
        }
    }

    protected function runHeuristics(string $url, string $host): array
    {
        $score = 0;
        $threats = [];
        $path = strtolower(parse_url($url, PHP_URL_PATH) ?? '');
        $scheme = strtolower(parse_url($url, PHP_URL_SCHEME) ?? '');

        if ($scheme === 'http') {
            $score += 15;
            $threats[] = 'Insecure HTTP link (no HTTPS)';
        }

        if (str_contains($url, '@')) {
            $score += 40;
            $threats[] = 'URL contains @ (possible credential phishing trick)';
        }

        if (str_contains($host, 'xn--')) {
            $score += 35;
            $threats[] = 'Punycode / internationalized domain (possible homograph attack)';
        }

        $suspiciousTlds = config('safelink.suspicious_tlds', []);
        $parts = explode('.', $host);
        $tld = end($parts) ?: '';
        if (in_array($tld, $suspiciousTlds, true)) {
            $score += 25;
            $threats[] = "Suspicious TLD extension: .{$tld}";
        }

        $shorteners = config('safelink.url_shorteners', []);
        if (in_array($host, $shorteners, true)) {
            $score += 20;
            $threats[] = "Known URL shortening service detected: {$host}";
        }

        if (preg_match('/^\d{1,3}(?:\.\d{1,3}){3}$/', $host)) {
            $score += 40;
            $threats[] = 'Direct IP address hostname instead of domain name';
        }

        if (count($parts) > 4) {
            $score += 15;
            $threats[] = 'Excessive subdomain levels (' . count($parts) . ')';
        }

        if (strlen($host) > 45) {
            $score += 10;
            $threats[] = 'Unusually long hostname';
        }

        $pathKeywords = ['login', 'verify', 'secure', 'update', 'account', 'signin', 'password', 'confirm', 'wallet', 'billing'];
        foreach ($pathKeywords as $keyword) {
            if (str_contains($path, $keyword)) {
                $score += 12;
                $threats[] = "Suspicious path keyword: {$keyword}";
                break;
            }
        }

        $brandKeywords = ['google', 'paypal', 'facebook', 'amazon', 'apple', 'netflix', 'microsoft', 'instagram', 'whatsapp', 'bankofamerica', 'chase', 'wellsfargo'];
        foreach ($brandKeywords as $brand) {
            if (str_contains($host, $brand) && !str_ends_with($host, "{$brand}.com") && !str_ends_with($host, "{$brand}.org") && !str_ends_with($host, "{$brand}.net")) {
                $score += 35;
                $threats[] = "Possible brand impersonation / typosquatting target: {$brand}";
            }
        }

        if (substr_count($host, '-') >= 3 && preg_match('/(login|secure|account|verify|support)/', $host)) {
            $score += 20;
            $threats[] = 'Hyphen-heavy host resembling a brand support portal';
        }

        return [
            'score' => $score,
            'threats' => array_values(array_unique($threats)),
        ];
    }
}
