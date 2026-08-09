<?php

return [
    /*
    |--------------------------------------------------------------------------
    | SafeLink Threat Detection Configuration
    |--------------------------------------------------------------------------
    */

    'api_keys' => [
        'google_safe_browsing' => env('GOOGLE_SAFE_BROWSING_API_KEY', ''),
        'virustotal'           => env('VIRUSTOTAL_API_KEY', ''),
        'hibp'                 => env('HIBP_API_KEY', ''),
        'phishtank'            => env('PHISHTANK_APP_KEY', ''),
        'abusech'              => env('ABUSECH_AUTH_KEY', ''),
        'gemini'               => env('GEMINI_API_KEY', ''),
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
    ],

    /*
    |--------------------------------------------------------------------------
    | Nepali / Romanized Nepali scam phrases (SMS & chat)
    |--------------------------------------------------------------------------
    */
    'nepali_phishing_keywords' => [
        // Devanagari
        'तुरुन्त', 'तुरंत', 'खाता लक', 'खाता बन्द', 'लक भएको', 'लक भयो',
        'भेरिफाई', 'भेरिफाइ', 'पासवर्ड', 'ओटीपी', 'otp पठाउ', 'लिङ्कमा क्लिक',
        'क्लिक गर्नुहोस्', 'लिङ्क खोल्नुहोस्', 'पुरस्कार', 'लटरी',
        'जित्नुभयो', 'रकम प्राप्त', 'पैसा पठाउ', 'बैंक खाता', 'केवाईसी',
        'kyc अपडेट', 'भ्याट फिर्ता', 'भन्सार शुल्क', 'पार्सल रोकिएको',
        'अनधिकृत पहुँच', 'सुरक्षा चेतावनी', 'खाता निलम्बित', 'रकम ट्रान्सफर',
        'इसेवा', 'खल्ती', 'मोबाइल बैंकिङ', 'पिन नम्बर', 'कार्ड विवरण',
        // Romanized Nepali / Hinglish common in SMS
        'turunta', 'turanta', 'khata lock', 'account lock', 'otp pathaunus',
        'otp pathau', 'password dinus', 'click garnus', 'link kholnus',
        'link ma click', 'paisa jeet', 'prize jeetnu', 'lottery',
        'bank verify', 'kyc update', 'kyc garnus', 'esewa verify',
        'khalti verify', 'refund aayo', 'parcel rukeko', 'customs fee',
        'pin number pathau', 'card details', 'unauthorized access',
    ],
];
