<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CheckBreachRequest;
use App\Models\BreachLog;
use App\Services\HaveIBeenPwnedService;
use Illuminate\Support\Facades\Log;

class BreachController extends Controller
{
    protected HaveIBeenPwnedService $hibpService;

    public function __construct(HaveIBeenPwnedService $hibpService)
    {
        $this->hibpService = $hibpService;
    }

    /**
     * Check if email or phone has been compromised in data breaches.
     */
    public function check(CheckBreachRequest $request)
    {
        $identifier = trim($request->validated()['identifier']);
        $result = $this->hibpService->checkAccount($identifier);
        $userId = $request->user()?->id;

        dispatch(function () use ($identifier, $result, $userId) {
            try {
                BreachLog::create([
                    'user_id' => $userId,
                    'identifier' => $identifier,
                    'is_breached' => $result['breached'],
                    'breach_count' => $result['breach_count'],
                    'breach_details' => $result['breaches'],
                ]);
            } catch (\Exception $e) {
                Log::warning('Failed to log breach check', ['error' => $e->getMessage()]);
            }
        })->afterResponse();

        return $this->successResponse($result, $result['message']);
    }

    /**
     * Get breach check history logs.
     */
    public function history()
    {
        $logs = BreachLog::latest()->take(50)->get();
        return $this->successResponse($logs, 'Recent breach logs fetched');
    }
}
