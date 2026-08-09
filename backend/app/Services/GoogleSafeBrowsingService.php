<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GoogleSafeBrowsingService
{
    protected string $apiKey;
    protected string $endpoint;

    public function __construct()
    {
        $this->apiKey = config('safelink.api_keys.google_safe_browsing', '');
        $this->endpoint = config('services.google_safe_browsing.endpoint', 'https://safebrowsing.googleapis.com/v4/threatMatches:find');
    }

    /**
     * Check if a URL is flagged by Google Safe Browsing.
     *
     * @param string $url
     * @return array
     */
    public function checkUrl(string $url): array
    {
        if (empty($this->apiKey)) {
            return [
                'status' => 'untested',
                'is_malicious' => false,
                'threat_types' => [],
                'message' => 'Google Safe Browsing API key not configured. Using heuristic verification.',
            ];
        }

        try {
            $payload = [
                'client' => [
                    'clientId' => 'safelink-ai',
                    'clientVersion' => '1.0.0',
                ],
                'threatInfo' => [
                    'threatTypes' => [
                        'MALWARE',
                        'SOCIAL_ENGINEERING',
                        'UNWANTED_SOFTWARE',
                        'POTENTIALLY_HARMFUL_APPLICATION',
                    ],
                    'platformTypes' => ['ANY_PLATFORM'],
                    'threatEntryTypes' => ['URL'],
                    'threatEntries' => [
                        ['url' => $url],
                    ],
                ],
            ];

            $response = Http::post("{$this->endpoint}?key={$this->apiKey}", $payload);

            if ($response->successful()) {
                $data = $response->json();
                $matches = $data['matches'] ?? [];

                if (!empty($matches)) {
                    $threats = array_column($matches, 'threatType');
                    return [
                        'status' => 'flagged',
                        'is_malicious' => true,
                        'threat_types' => $threats,
                        'message' => 'Threat detected by Google Safe Browsing.',
                    ];
                }

                return [
                    'status' => 'clean',
                    'is_malicious' => false,
                    'threat_types' => [],
                    'message' => 'No threat detected by Google Safe Browsing.',
                ];
            }

            Log::error('Google Safe Browsing API error', ['response' => $response->body()]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'threat_types' => [],
                'message' => 'Failed to reach Google Safe Browsing API.',
            ];

        } catch (\Exception $e) {
            Log::error('Google Safe Browsing Exception', ['error' => $e->getMessage()]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'threat_types' => [],
                'message' => $e->getMessage(),
            ];
        }
    }
}
