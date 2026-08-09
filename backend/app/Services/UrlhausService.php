<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class UrlhausService
{
    protected string $authKey;
    protected string $urlEndpoint = 'https://urlhaus-api.abuse.ch/v1/url/';
    protected string $hostEndpoint = 'https://urlhaus-api.abuse.ch/v1/host/';

    public function __construct()
    {
        $this->authKey = (string) config('safelink.api_keys.abusech', '');
    }

    public function isConfigured(): bool
    {
        return $this->authKey !== '';
    }

    public function authKey(): string
    {
        return $this->authKey;
    }

    public function urlEndpoint(): string
    {
        return $this->urlEndpoint;
    }

    public function hostEndpoint(): string
    {
        return $this->hostEndpoint;
    }

    public function untestedResult(): array
    {
        return [
            'status' => 'untested',
            'is_malicious' => false,
            'message' => 'URLhaus Auth-Key not configured (free at https://auth.abuse.ch/).',
        ];
    }

    public function checkUrl(string $url, string $host): array
    {
        if (!$this->isConfigured()) {
            return $this->untestedResult();
        }

        try {
            $urlResponse = Http::asForm()
                ->withHeaders(['Auth-Key' => $this->authKey])
                ->timeout(8)
                ->connectTimeout(3)
                ->post($this->urlEndpoint, ['url' => $url]);

            $urlResult = $this->interpretUrl(
                $urlResponse->successful() ? $urlResponse->json() : null,
                $urlResponse->successful(),
                $urlResponse->body()
            );

            if ($urlResult['is_malicious']) {
                return $urlResult;
            }

            $hostResponse = Http::asForm()
                ->withHeaders(['Auth-Key' => $this->authKey])
                ->timeout(8)
                ->connectTimeout(3)
                ->post($this->hostEndpoint, ['host' => $host]);

            $hostResult = $this->interpretHost(
                $hostResponse->successful() ? $hostResponse->json() : null,
                $hostResponse->successful(),
                $hostResponse->body()
            );

            if ($hostResult['is_malicious']) {
                return $hostResult;
            }

            if ($urlResult['status'] === 'error' && $hostResult['status'] === 'error') {
                return $urlResult;
            }

            return [
                'status' => 'clean',
                'is_malicious' => false,
                'message' => 'Not listed in URLhaus malware database.',
            ];
        } catch (\Throwable $e) {
            Log::warning('URLhaus Exception', ['error' => $e->getMessage()]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    public function interpretUrl(?array $data, bool $successful = true, string $rawBody = ''): array
    {
        if (!$successful) {
            Log::warning('URLhaus URL query failed', ['body' => substr($rawBody, 0, 500)]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'message' => 'Failed to reach URLhaus URL API.',
            ];
        }

        $queryStatus = $data['query_status'] ?? '';

        if ($queryStatus === 'ok') {
            $threat = $data['threat'] ?? 'malware_download';
            $urlStatus = $data['url_status'] ?? '';
            return [
                'status' => 'flagged',
                'is_malicious' => true,
                'message' => "URLhaus: {$threat} (status: {$urlStatus})",
            ];
        }

        if (in_array($queryStatus, ['no_results', 'invalid_url'], true)) {
            return [
                'status' => 'clean',
                'is_malicious' => false,
                'message' => 'URL not found in URLhaus.',
            ];
        }

        return [
            'status' => 'error',
            'is_malicious' => false,
            'message' => 'URLhaus unexpected response: '.$queryStatus,
        ];
    }

    public function interpretHost(?array $data, bool $successful = true, string $rawBody = ''): array
    {
        if (!$successful) {
            return [
                'status' => 'error',
                'is_malicious' => false,
                'message' => 'Failed to reach URLhaus host API.',
            ];
        }

        $queryStatus = $data['query_status'] ?? '';

        if ($queryStatus === 'ok') {
            $urlCount = is_array($data['urls'] ?? null) ? count($data['urls']) : 0;
            return [
                'status' => 'flagged',
                'is_malicious' => true,
                'message' => "URLhaus: host associated with {$urlCount} malware URL(s).",
            ];
        }

        if ($queryStatus === 'no_results') {
            return [
                'status' => 'clean',
                'is_malicious' => false,
                'message' => 'Host not found in URLhaus.',
            ];
        }

        return [
            'status' => 'error',
            'is_malicious' => false,
            'message' => 'URLhaus host unexpected response: '.$queryStatus,
        ];
    }
}
