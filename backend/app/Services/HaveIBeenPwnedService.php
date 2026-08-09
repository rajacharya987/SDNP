<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class HaveIBeenPwnedService
{
    protected string $apiKey;
    protected string $endpoint;

    public function __construct()
    {
        $this->apiKey = config('safelink.api_keys.hibp', '');
        $this->endpoint = config('services.haveibeenpwned.endpoint', 'https://haveibeenpwned.com/api/v3/breachedaccount/');
    }

    /**
     * Check if an email account has been leaked in public data breaches.
     *
     * @param string $account (Email or Username)
     * @return array
     */
    public function checkAccount(string $account): array
    {
        if (empty($this->apiKey)) {
            // Mock response for development when API key is missing
            return [
                'status' => 'mocked',
                'account' => $account,
                'breached' => false,
                'breach_count' => 0,
                'breaches' => [],
                'message' => 'HIBP API key not configured. Register at haveibeenpwned.com to enable live breach scanning.',
            ];
        }

        try {
            $response = Http::withHeaders([
                'hibp-api-key' => $this->apiKey,
                'user-agent'   => 'SafeLink-AI-App',
            ])->get("{$this->endpoint}" . urlencode($account) . "?truncateResponse=false");

            if ($response->status() === 200) {
                $breaches = $response->json();
                return [
                    'status' => 'success',
                    'account' => $account,
                    'breached' => true,
                    'breach_count' => count($breaches),
                    'breaches' => array_map(function ($b) {
                        return [
                            'name' => $b['Name'] ?? 'Unknown',
                            'title' => $b['Title'] ?? 'Unknown',
                            'domain' => $b['Domain'] ?? '',
                            'breach_date' => $b['BreachDate'] ?? '',
                            'pwn_count' => $b['PwnCount'] ?? 0,
                            'description' => strip_tags($b['Description'] ?? ''),
                            'data_classes' => $b['DataClasses'] ?? [],
                        ];
                    }, $breaches),
                    'message' => 'Account found in data breaches!',
                ];
            }

            if ($response->status() === 404) {
                return [
                    'status' => 'clean',
                    'account' => $account,
                    'breached' => false,
                    'breach_count' => 0,
                    'breaches' => [],
                    'message' => 'Good news! No breach records found for this account.',
                ];
            }

            Log::error('HIBP API Error', ['status' => $response->status(), 'body' => $response->body()]);
            return [
                'status' => 'error',
                'account' => $account,
                'breached' => false,
                'breach_count' => 0,
                'breaches' => [],
                'message' => 'Failed to query Have I Been Pwned database.',
            ];

        } catch (\Exception $e) {
            Log::error('HIBP Service Exception', ['error' => $e->getMessage()]);
            return [
                'status' => 'error',
                'account' => $account,
                'breached' => false,
                'breach_count' => 0,
                'breaches' => [],
                'message' => $e->getMessage(),
            ];
        }
    }
}
