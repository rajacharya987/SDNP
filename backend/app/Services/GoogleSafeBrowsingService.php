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

    public function isConfigured(): bool
    {
        return $this->apiKey !== '';
    }

    public function endpoint(): string
    {
        return "{$this->endpoint}?key={$this->apiKey}";
    }

    public function payload(string $url): array
    {
        return [
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
    }

    public function checkUrl(string $url): array
    {
        if (!$this->isConfigured()) {
            return $this->untestedResult();
        }

        try {
            $response = Http::timeout(8)
                ->connectTimeout(3)
                ->acceptJson()
                ->asJson()
                ->post($this->endpoint(), $this->payload($url));

            return $this->interpret(
                $response->successful() ? $response->json() : null,
                $response->successful(),
                $response->body(),
                $response->status()
            );
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

    public function untestedResult(): array
    {
        return [
            'status' => 'untested',
            'is_malicious' => false,
            'threat_types' => [],
            'message' => 'Google Safe Browsing API key not configured.',
        ];
    }

    public function interpret(?array $data, bool $successful = true, string $rawBody = '', int $statusCode = 0): array
    {
        if (!$successful) {
            Log::error('Google Safe Browsing API error', [
                'status' => $statusCode,
                'response' => substr($rawBody, 0, 800),
            ]);

            // Misconfigured / blocked API keys should not poison SAFE eligibility forever
            if (in_array($statusCode, [400, 403], true)) {
                return [
                    'status' => 'untested',
                    'is_malicious' => false,
                    'threat_types' => [],
                    'message' => 'Google Safe Browsing API key blocked or invalid. Enable Safe Browsing API in Google Cloud.',
                ];
            }

            return [
                'status' => 'error',
                'is_malicious' => false,
                'threat_types' => [],
                'message' => 'Failed to reach Google Safe Browsing API.',
            ];
        }

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
}
