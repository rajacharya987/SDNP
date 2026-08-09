<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class VirusTotalService
{
    protected string $apiKey;
    protected string $endpoint;

    public function __construct()
    {
        $this->apiKey = config('safelink.api_keys.virustotal', '');
        $this->endpoint = config('services.virustotal.endpoint', 'https://www.virustotal.com/api/v3/urls');
    }

    public function isConfigured(): bool
    {
        return $this->apiKey !== '';
    }

    public function apiKey(): string
    {
        return $this->apiKey;
    }

    public function lookupUrl(string $url): string
    {
        $urlId = rtrim(strtr(base64_encode($url), '+/', '-_'), '=');
        return "{$this->endpoint}/{$urlId}";
    }

    public function submitEndpoint(): string
    {
        return $this->endpoint;
    }

    /**
     * Scan a URL via VirusTotal v3 API.
     */
    public function scanUrl(string $url): array
    {
        if (!$this->isConfigured()) {
            return $this->untestedResult();
        }

        try {
            $response = Http::withHeaders([
                'x-apikey' => $this->apiKey,
            ])
                ->timeout(8)
                ->connectTimeout(3)
                ->acceptJson()
                ->get($this->lookupUrl($url));

            if ($response->status() === 404) {
                return $this->submitAndLookup($url);
            }

            return $this->interpret(
                $response->successful() ? $response->json() : null,
                $response->successful(),
                $response->body(),
                $response->status()
            );
        } catch (\Exception $e) {
            Log::error('VirusTotal Exception', ['error' => $e->getMessage()]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Submit unknown URL for analysis, then re-query (or mark pending — never clean).
     */
    protected function submitAndLookup(string $url): array
    {
        try {
            $submit = Http::withHeaders([
                'x-apikey' => $this->apiKey,
            ])
                ->asForm()
                ->timeout(8)
                ->connectTimeout(3)
                ->post($this->submitEndpoint(), ['url' => $url]);

            if (!$submit->successful()) {
                return [
                    'status' => 'untested',
                    'is_malicious' => false,
                    'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                    'message' => 'URL not in VirusTotal yet; submit failed.',
                ];
            }

            // Brief pause then re-GET cached report if available
            usleep(400000);

            $response = Http::withHeaders([
                'x-apikey' => $this->apiKey,
            ])
                ->timeout(8)
                ->connectTimeout(3)
                ->acceptJson()
                ->get($this->lookupUrl($url));

            if ($response->successful()) {
                return $this->interpret($response->json(), true, $response->body(), $response->status());
            }

            return [
                'status' => 'untested',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => 'VirusTotal analysis pending — not treated as clean.',
            ];
        } catch (\Throwable $e) {
            Log::warning('VirusTotal submit failed', ['error' => $e->getMessage()]);
            return [
                'status' => 'untested',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => 'VirusTotal submit/lookup failed — not treated as clean.',
            ];
        }
    }

    public function untestedResult(): array
    {
        return [
            'status' => 'untested',
            'is_malicious' => false,
            'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
            'message' => 'VirusTotal API key not configured.',
        ];
    }

    public function interpret(?array $data, bool $successful = true, string $rawBody = '', int $statusCode = 0): array
    {
        if ($statusCode === 404) {
            return [
                'status' => 'untested',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => 'URL not in VirusTotal database yet.',
            ];
        }

        if (!$successful) {
            Log::error('VirusTotal API error', ['status' => $statusCode, 'response' => substr($rawBody, 0, 500)]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => 'Failed to reach VirusTotal API.',
            ];
        }

        $attributes = $data['data']['attributes'] ?? [];
        $stats = $attributes['last_analysis_stats'] ?? [
            'malicious' => 0,
            'suspicious' => 0,
            'harmless' => 0,
            'undetected' => 0,
        ];

        $maliciousCount = (int) ($stats['malicious'] ?? 0);
        $suspiciousCount = (int) ($stats['suspicious'] ?? 0);

        return [
            'status' => ($maliciousCount > 0 || $suspiciousCount > 0) ? 'flagged' : 'clean',
            'is_malicious' => $maliciousCount > 0,
            'is_suspicious' => $suspiciousCount > 0,
            'stats' => $stats,
            'message' => "VirusTotal: {$maliciousCount} malicious, {$suspiciousCount} suspicious vendors.",
        ];
    }
}
