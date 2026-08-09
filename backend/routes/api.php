<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BreachController;
use App\Http\Controllers\Api\V1\SentinelController;
use App\Http\Controllers\Api\V1\SmsAnalyzerController;
use App\Http\Controllers\Api\V1\TempMailController;
use App\Http\Controllers\Api\V1\UrlScannerController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| SafeLink AI & SentinelX API Routes (V1)
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function () {

    // Health check endpoint
    Route::get('/health', function () {
        return response()->json([
            'status' => 'healthy',
            'app' => 'SentinelX Personal Cybersecurity Platform',
            'version' => '2.0.0',
            'timestamp' => now()->toIso8601String(),
        ]);
    });

    // --- Original Mobile App Endpoints (Preserved) ---
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    Route::post('/scan-url', [UrlScannerController::class, 'scan']);
    Route::get('/scan-history', [UrlScannerController::class, 'history']);

    Route::post('/analyze-sms', [SmsAnalyzerController::class, 'analyze']);

    Route::post('/check-breach', [BreachController::class, 'check']);
    Route::get('/breach-history', [BreachController::class, 'history']);

    Route::post('/temp-mail/generate', [TempMailController::class, 'generate']);
    Route::get('/temp-mail/inbox/{address}', [TempMailController::class, 'inbox']);

    // --- SentinelX Multi-Layer Security Platform Endpoints ---
    Route::post('/sentinel/fingerprint', [SentinelController::class, 'fingerprint']);
    Route::post('/sentinel/extension-audit', [SentinelController::class, 'extensionAudit']);
    Route::get('/sentinel/dashboard', [SentinelController::class, 'dashboard']);

    // Protected Routes (Sanctum)
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
    });
});
