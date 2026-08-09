<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ScanUrlRequest;
use App\Models\ScanHistory;
use App\Services\GoogleSafeBrowsingService;
use App\Services\VirusTotalService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class UrlScannerController extends Controller
{
    protected GoogleSafeBrowsingService $googleService;
    protected VirusTotalService $virusTotalService;

    public function __construct(
        GoogleSafeBrowsingService $googleService,
        VirusTotalService $virusTotalService
    ) {
        $this->googleService = $googleService;
        $this->virusTotalService = $virusTotalService;
    }

    /**
     * Scan URL or Subscription Link for security threats.
     */
    public function scan(ScanUrlRequest $request)
    {
        $url = trim($request->validated()['url']);

        // Ensure scheme
        if (!preg_match('#^https?://#i', $url)) {
            $url = 'https://' . $url;
        }

        $parsedUrl = parse_url($url);
        $host = strtolower($parsedUrl['host'] ?? '');

        if (empty($host)) {
            return $this->errorResponse('Invalid URL format provided', 422);
        }

        $cacheKey = 'safelink_scan_' . md5($url);

        // 1. Check Redis Cache
        if (Cache::has($cacheKey)) {
            return $this->successResponse(Cache::get($cacheKey), 'URL scan results retrieved from cache');
        }

        // 2. Perform Heuristic Analysis
        $heuristicResult = $this->runHeuristics($url, $host);

        // 3. Perform Google Safe Browsing API check
        $googleResult = $this->googleService->checkUrl($url);

        // 4. Perform VirusTotal API scan check
        $virusTotalResult = $this->virusTotalService->scanUrl($url);

        // 5. Aggregate Risk Score & Verdict Calculation
        $riskScore = 0;
        $threatDetails = [];

        // Heuristic points
        if (!empty($heuristicResult['threats'])) {
            $riskScore += $heuristicResult['score'];
            $threatDetails = array_merge($threatDetails, $heuristicResult['threats']);
        }

        // Google Safe Browsing points
        if ($googleResult['is_malicious']) {
            $riskScore += 60;
            $threatDetails[] = 'Google Safe Browsing: Flagged as ' . implode(', ', $googleResult['threat_types']);
        }

        // VirusTotal points
        if ($virusTotalResult['is_malicious']) {
            $maliciousVendors = $virusTotalResult['stats']['malicious'] ?? 0;
            $riskScore += min(50, $maliciousVendors * 15);
            $threatDetails[] = "VirusTotal: Flagged by {$maliciousVendors} security vendors";
        }

        // Cap risk score at 100
        $finalScore = min(100, $riskScore);

        if ($finalScore >= 70) {
            $verdict = 'DANGEROUS';
            $verdictTitle = 'Dangerous Phishing / Scam Source';
            $verdictColor = 'red';
        } elseif ($finalScore >= 35) {
            $verdict = 'SUSPICIOUS';
            $verdictTitle = 'Suspicious or Unverified Subscription Link';
            $verdictColor = 'yellow';
        } else {
            $verdict = 'SAFE';
            $verdictTitle = 'Safe & Clean Domain';
            $verdictColor = 'green';
        }

        $resultPayload = [
            'url' => $url,
            'domain' => $host,
            'verdict' => $verdict,
            'verdict_title' => $verdictTitle,
            'verdict_color' => $verdictColor,
            'risk_score' => $finalScore,
            'threat_details' => $threatDetails,
            'breakdown' => [
                'heuristics' => $heuristicResult,
                'google_safe_browsing' => $googleResult,
                'virustotal' => $virusTotalResult,
            ],
            'scanned_at' => now()->toIso8601String(),
        ];

        // 6. Cache result for 24 hours in Redis
        Cache::put($cacheKey, $resultPayload, now()->addHours(config('safelink.thresholds.cache_hours', 24)));

        // 7. Save Scan Log into DB
        try {
            ScanHistory::create([
                'user_id' => $request->user()?->id,
                'url' => $url,
                'domain' => $host,
                'verdict' => $verdict,
                'risk_score' => $finalScore,
                'threat_details' => $threatDetails,
                'google_safe_browsing_status' => $googleResult['status'],
                'virustotal_status' => $virusTotalResult['status'],
                'heuristics_status' => empty($heuristicResult['threats']) ? 'passed' : 'flagged',
            ]);
        } catch (\Exception $e) {
            Log::warning('Failed to log scan history', ['error' => $e->getMessage()]);
        }

        return $this->successResponse($resultPayload, 'URL security analysis complete');
    }

    /**
     * Get scan history logs.
     */
    public function history()
    {
        $logs = ScanHistory::latest()->take(50)->get();
        return $this->successResponse($logs, 'Recent scan history fetched');
    }

    /**
     * Internal Heuristic checks.
     */
    protected function runHeuristics(string $url, string $host): array
    {
        $score = 0;
        $threats = [];

        // Check suspicious TLDs
        $suspiciousTlds = config('safelink.suspicious_tlds', []);
        $tld = pathinfo($host, PATHINFO_EXTENSION);
        if (in_array($tld, $suspiciousTlds)) {
            $score += 25;
            $threats[] = "Suspicious TLD extension: .{$tld}";
        }

        // Check URL shorteners
        $shorteners = config('safelink.url_shorteners', []);
        if (in_array($host, $shorteners)) {
            $score += 20;
            $threats[] = "Known URL shortening service detected: {$host}";
        }

        // Check IP Hostname
        if (preg_match('/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/', $host)) {
            $score += 40;
            $threats[] = "Direct IP address hostname instead of domain name";
        }

        // Check excessive subdomains
        $subdomainParts = explode('.', $host);
        if (count($subdomainParts) > 4) {
            $score += 15;
            $threats[] = "Excessive subdomain levels (" . count($subdomainParts) . ")";
        }

        // Check typosquatting / brand spoofing keywords
        $brandKeywords = ['google', 'paypal', 'facebook', 'amazon', 'apple', 'netflix', 'bankofamerica', 'chase', 'wellsfargo'];
        foreach ($brandKeywords as $brand) {
            if (str_contains($host, $brand) && !str_ends_with($host, "{$brand}.com") && !str_ends_with($host, "{$brand}.org")) {
                $score += 35;
                $threats[] = "Possible brand impersonation / typosquatting target: {$brand}";
            }
        }

        return [
            'score' => $score,
            'threats' => $threats,
        ];
    }
}
