<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'name' => 'SafeLink AI Threat Detection API',
        'status' => 'online',
        'documentation' => '/api/v1/health',
    ]);
});
