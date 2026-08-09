<?php

return [
    /*
    |--------------------------------------------------------------------------
    | SafeLink Threat Detection Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration options for external threat intelligence APIs (Google Safe
    | Browsing, VirusTotal, HIBP) and internal heuristic engine thresholds.
    |
    */

    'api_keys' => [
        'google_safe_browsing' => env('GOOGLE_SAFE_BROWSING_API_KEY', ''),
        'virustotal'           => env('VIRUSTOTAL_API_KEY', ''),
        'hibp'                 => env('HIBP_API_KEY', ''),
    ],

    'thresholds' => [
        'high_risk'   => env('RISK_THRESHOLD_HIGH', 75),
        'medium_risk' => env('RISK_THRESHOLD_MEDIUM', 45),
        'cache_hours' => env('CACHE_SCAN_RESULTS_HOURS', 24),
    ],

    'suspicious_tlds' => [
        'xyz', 'top', 'tk', 'ml', 'ga', 'cf', 'gq', 'work', 'click', 'link',
        'download', 'zip', 'mov', 'monster', 'rest', 'cam', 'bid', 'best'
    ],

    'url_shorteners' => [
        'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'buff.ly',
        'ow.ly', 'rb.gy', 'cutt.ly', 'shorturl.at', 'v.gd', 'clck.ru'
    ],

    'phishing_keywords' => [
        'urgent', 'immediate action', 'verify account', 'account suspended',
        'claim prize', 'unauthorized access', 'security alert', 'bank locked',
        'refund approved', 'lottery winner', 'confirm identity', 'package delayed',
        'customs fee', 'tax refund', 'crypto bonus', 'free gift'
    ]
];
