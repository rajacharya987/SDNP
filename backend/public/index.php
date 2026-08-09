<?php

use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Auto Loader...
if (file_exists(__DIR__.'/../vendor/autoload.php')) {
    require __DIR__.'/../vendor/autoload.php';
}

// Bootstrap Laravel and handle the request...
if (file_exists(__DIR__.'/../bootstrap/app.php')) {
    (require_once __DIR__.'/../bootstrap/app.php')
        ->handleRequest(Request::capture());
} else {
    echo json_encode([
        'status' => 'online',
        'message' => 'SafeLink AI Backend Service Ready',
    ]);
}
