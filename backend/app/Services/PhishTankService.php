<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PhishTankService
{
    protected string $appKey;
    protected string $endpoint = 'https://checkurl.phishtank.com/checkurl/';

    public function __construct()
    {
        $this->appKey = (string) config('safelink.api_keys.phishtank', '');
    }

    public function isConfigured(): bool
    {
        // Without an app key PhishTank is best-effort (strict rate limits).
        return $this->appKey !== '';
    }

    public function isAvailable(): bool
    {
        return true;
    }

    public function endpoint(): string
    {
        return $this->endpoint;
    }

    public function formParams(string $url): array
    {
        $params = [
            'url' => $url,
            'format' => 'json',
        ];

        if ($this->appKey !== '') {
            $params['app_key'] = $this->appKey;
        }

        return $params;
    }

    public function checkUrl(string $url): array
    {
        try {
            $response = Http::asForm()
                ->timeout(8)
                ->connectTimeout(3)
                ->withHeaders([
                    'User-Agent' => 'phishtank/SafeLink-AI',
                ])
                ->post($this->endpoint, $this->formParams($url));

            return $this->interpret(
                $response->successful() ? $response->json() : null,
                $response->successful(),
                $response->body(),
                $response->status()
            );
        } catch (\Throwable $e) {
            Log::warning('PhishTank Exception', ['error' => $e->getMessage()]);
            return [
                'status' => $this->isConfigured() ? 'error' : 'untested',
                'is_malicious' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    public function interpret(?array $data, bool $successful = true, string $rawBody = '', int $statusCode = 0): array
    {
        if (!$successful) {
            Log::warning('PhishTank API error', ['status' => $statusCode, 'body' => substr($rawBody, 0, 500)]);
            // Without app key, treat outages/rate-limits as untested so other free feeds can still clear SAFE
            $status = $this->isConfigured() ? 'error' : 'untested';
            return [
                'status' => $status,
                'is_malicious' => false,
                'message' => $statusCode === 509
                    ? 'PhishTank rate limit exceeded.'
                    : 'Failed to reach PhishTank API.',
            ];
        }

        $results = $data['results'] ?? $data;
        $inDatabase = filter_var($results['in_database'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $valid = filter_var($results['valid'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $verified = filter_var($results['verified'] ?? false, FILTER_VALIDATE_BOOLEAN);

        // Only currently-valid phishing entries count (historical listings may have valid=false)
        if ($inDatabase && $valid) {
            return [
                'status' => 'flagged',
                'is_malicious' => true,
                'message' => $verified
                    ? 'Verified phishing URL in PhishTank database.'
                    : 'Active phishing URL in PhishTank database.',
            ];
        }

        return [
            'status' => 'clean',
            'is_malicious' => false,
            'message' => $inDatabase
                ? 'Previously listed in PhishTank but no longer valid.'
                : 'Not found in PhishTank database.',
        ];
    }
}
