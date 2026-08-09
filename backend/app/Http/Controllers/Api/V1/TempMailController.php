<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class TempMailController extends Controller
{
    /**
     * Generate a new temporary burner email address.
     */
    public function generate()
    {
        $randomPrefix = strtolower(Str::random(10));
        $domain = 'safelink-temp.com';
        $emailAddress = "{$randomPrefix}@{$domain}";

        return $this->successResponse([
            'email' => $emailAddress,
            'expires_in_minutes' => 60,
            'created_at' => now()->toIso8601String(),
        ], 'Temporary burner mail generated successfully');
    }

    /**
     * Fetch inbox for a given temporary email address.
     */
    public function inbox(Request $request, string $address)
    {
        // Mock inbox messages for temporary mail functionality
        $sampleMessages = [
            [
                'id' => (string) Str::uuid(),
                'sender' => 'noreply@subscription-trap.com',
                'subject' => 'Welcome! Confirm your free trial',
                'body' => 'Thank you for signing up. Please click the button below to start your trial.',
                'received_at' => now()->subMinutes(2)->toIso8601String(),
            ],
            [
                'id' => (string) Str::uuid(),
                'sender' => 'security@service.org',
                'subject' => 'Your Verification Code',
                'body' => 'Your 6-digit confirmation code is 849-204.',
                'received_at' => now()->subMinutes(5)->toIso8601String(),
            ]
        ];

        return $this->successResponse([
            'address' => $address,
            'messages_count' => count($sampleMessages),
            'messages' => $sampleMessages,
        ], 'Inbox updated');
    }
}
