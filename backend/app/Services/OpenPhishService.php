<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class OpenPhishService
{
    protected const FEED_URL = 'https://openphish.com/feed.txt';
    protected const CACHE_KEY = 'openphish_feed_urls';
    protected const HOST_CACHE_KEY = 'openphish_feed_hosts';
    protected const CACHE_TTL_SECONDS = 3600;

    public function isConfigured(): bool
    {
        return true;
    }

    /**
     * Check URL / host against the cached OpenPhish community feed.
     */
    public function checkUrl(string $url, string $host): array
    {
        try {
            $this->ensureFeedLoaded();

            $normalized = rtrim(strtolower($url), '/');
            $urls = Cache::get(self::CACHE_KEY, []);
            $hosts = Cache::get(self::HOST_CACHE_KEY, []);

            if (!is_array($urls) || empty($urls)) {
                return [
                    'status' => 'error',
                    'is_malicious' => false,
                    'message' => 'OpenPhish feed unavailable.',
                ];
            }

            if (isset($urls[$normalized]) || isset($urls[$url]) || isset($urls[strtolower($url)])) {
                return [
                    'status' => 'flagged',
                    'is_malicious' => true,
                    'message' => 'URL listed on OpenPhish phishing feed.',
                ];
            }

            $hostLower = strtolower($host);
            if ($hostLower !== '' && isset($hosts[$hostLower])) {
                return [
                    'status' => 'flagged',
                    'is_malicious' => true,
                    'message' => "Host listed on OpenPhish phishing feed: {$hostLower}",
                ];
            }

            return [
                'status' => 'clean',
                'is_malicious' => false,
                'message' => 'Not found in OpenPhish feed.',
            ];
        } catch (\Throwable $e) {
            Log::warning('OpenPhish check failed', ['error' => $e->getMessage()]);
            return [
                'status' => 'error',
                'is_malicious' => false,
                'message' => 'OpenPhish check failed: '.$e->getMessage(),
            ];
        }
    }

    public function ensureFeedLoaded(): void
    {
        if (Cache::has(self::CACHE_KEY) && Cache::has(self::HOST_CACHE_KEY)) {
            return;
        }

        $response = Http::timeout(12)
            ->connectTimeout(4)
            ->withHeaders(['User-Agent' => 'SafeLink-AI/1.0'])
            ->get(self::FEED_URL);

        if (!$response->successful()) {
            Log::error('OpenPhish feed download failed', ['status' => $response->status()]);
            Cache::put(self::CACHE_KEY, [], 120);
            Cache::put(self::HOST_CACHE_KEY, [], 120);
            return;
        }

        $urlMap = [];
        $hostMap = [];
        foreach (preg_split("/\r\n|\n|\r/", $response->body()) as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }
            $normalized = rtrim(strtolower($line), '/');
            $urlMap[$normalized] = true;
            $parsedHost = parse_url($line, PHP_URL_HOST);
            if (is_string($parsedHost) && $parsedHost !== '') {
                $hostMap[strtolower($parsedHost)] = true;
            }
        }

        Cache::put(self::CACHE_KEY, $urlMap, self::CACHE_TTL_SECONDS);
        Cache::put(self::HOST_CACHE_KEY, $hostMap, self::CACHE_TTL_SECONDS);
    }
}
