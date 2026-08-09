<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SiteAvailabilityService
{
    /**
     * Check whether the host resolves and the URL responds over HTTP(S).
     */
    public function check(string $url, string $host): array
    {
        $dnsOk = false;
        $httpOk = false;
        $httpStatus = null;
        $reason = '';

        // DNS resolve
        if (filter_var($host, FILTER_VALIDATE_IP)) {
            $dnsOk = true;
        } else {
            $records = @dns_get_record($host, DNS_A + DNS_AAAA);
            if (!empty($records)) {
                $dnsOk = true;
            } else {
                $ips = @gethostbynamel($host);
                $dnsOk = is_array($ips) && count($ips) > 0;
            }
        }

        if (!$dnsOk) {
            return [
                'status' => 'unavailable',
                'available' => false,
                'dns_ok' => false,
                'http_ok' => false,
                'http_status' => null,
                'message' => 'This site is not available (domain does not resolve).',
            ];
        }

        try {
            $response = Http::timeout(6)
                ->connectTimeout(3)
                ->withHeaders([
                    'User-Agent' => 'SafeLink-AI/1.0 (availability-check)',
                    'Accept' => '*/*',
                ])
                ->withOptions([
                    'allow_redirects' => [
                        'max' => 5,
                        'track_redirects' => true,
                    ],
                    'verify' => false,
                ])
                ->head($url);

            $httpStatus = $response->status();

            // Some hosts reject HEAD — fall back to GET
            if (in_array($httpStatus, [405, 501], true) || $httpStatus >= 500) {
                $response = Http::timeout(6)
                    ->connectTimeout(3)
                    ->withHeaders([
                        'User-Agent' => 'SafeLink-AI/1.0 (availability-check)',
                        'Accept' => 'text/html,application/xhtml+xml',
                    ])
                    ->withOptions([
                        'allow_redirects' => ['max' => 5],
                        'verify' => false,
                    ])
                    ->get($url);
                $httpStatus = $response->status();
            }

            // Any HTTP response (including 4xx) means the site exists / is reachable
            $httpOk = $httpStatus > 0 && $httpStatus < 600;
            if ($httpStatus >= 500) {
                $httpOk = false;
                $reason = "Server error (HTTP {$httpStatus})";
            } elseif ($httpStatus === 0) {
                $httpOk = false;
                $reason = 'No HTTP response';
            }
        } catch (\Throwable $e) {
            Log::info('Site availability HTTP check failed', [
                'host' => $host,
                'error' => $e->getMessage(),
            ]);
            $httpOk = false;
            $reason = $e->getMessage();
        }

        if (!$httpOk) {
            $message = 'This site is not available';
            if ($reason !== '') {
                $message .= " ({$reason})";
            } else {
                $message .= ' (could not connect).';
            }

            return [
                'status' => 'unavailable',
                'available' => false,
                'dns_ok' => true,
                'http_ok' => false,
                'http_status' => $httpStatus,
                'message' => $message,
            ];
        }

        return [
            'status' => 'available',
            'available' => true,
            'dns_ok' => true,
            'http_ok' => true,
            'http_status' => $httpStatus,
            'message' => "Site is reachable (HTTP {$httpStatus}).",
        ];
    }
}
