<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BreachController;
use App\Http\Controllers\Api\V1\SmsAnalyzerController;
use App\Http\Controllers\Api\V1\TempMailController;
use App\Http\Controllers\Api\V1\UrlScannerController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| SafeLink AI API Routes (V1)
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function () {

    // Health check endpoint
    Route::get('/health', function () {
        return response()->json([
            'status' => 'healthy',
            'app' => 'SafeLink AI Backend',
            'version' => '1.0.0',
            'timestamp' => now()->toIso8601String(),
        ]);
    });

    // Authentication Routes
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    // Core Security & Threat Scanning Endpoints
    Route::post('/scan-url', [UrlScannerController::class, 'scan']);
    Route::get('/scan-history', [UrlScannerController::class, 'history']);

    // SMS & Social Engineering Analyzer
    Route::post('/analyze-sms', [SmsAnalyzerController::class, 'analyze']);

    // Data Breach Checker
    Route::post('/check-breach', [BreachController::class, 'check']);
    Route::get('/breach-history', [BreachController::class, 'history']);

    // Temporary Email Utilities
    Route::post('/temp-mail/generate', [TempMailController::class, 'generate']);
    Route::get('/temp-mail/inbox/{address}', [TempMailController::class, 'inbox']);

    // Protected Routes (Sanctum)
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
    });
});
