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

    /**
     * Scan a URL via VirusTotal v3 API.
     *
     * @param string $url
     * @return array
     */
    public function scanUrl(string $url): array
    {
        if (empty($this->apiKey)) {
            return [
                'status' => 'untested',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => 'VirusTotal API key not configured.',
            ];
        }

        try {
            // Encode URL in base64 without padding for VT v3 lookup
            $urlId = rtrim(strtr(base64_encode($url), '+/', '-_'), '=');

            $response = Http::withHeaders([
                'x-apikey' => $this->apiKey,
            ])->get("{$this->endpoint}/{$urlId}");

            if ($response->successful()) {
                $attributes = $response->json('data.attributes', []);
                $stats = $attributes['last_analysis_stats'] ?? [
                    'malicious' => 0,
                    'suspicious' => 0,
                    'harmless' => 0,
                    'undetected' => 0,
                ];

                $maliciousCount = $stats['malicious'] ?? 0;
                $suspiciousCount = $stats['suspicious'] ?? 0;

                return [
                    'status' => ($maliciousCount > 0 || $suspiciousCount > 1) ? 'flagged' : 'clean',
                    'is_malicious' => $maliciousCount > 0,
                    'stats' => $stats,
                    'message' => "VirusTotal engine scan completed. Flagged by {$maliciousCount} vendors.",
                ];
            }

            Log::error('VirusTotal API error', ['response' => $response->body()]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'stats' => ['malicious' => 0, 'suspicious' => 0, 'harmless' => 0, 'undetected' => 0],
                'message' => 'Failed to reach VirusTotal API.',
            ];

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
}
