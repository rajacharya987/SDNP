<?php

return [

    'google_safe_browsing' => [
        'api_key' => env('GOOGLE_SAFE_BROWSING_API_KEY'),
        'endpoint' => 'https://safebrowsing.googleapis.com/v4/threatMatches:find',
    ],

    'virustotal' => [
        'api_key' => env('VIRUSTOTAL_API_KEY'),
        'endpoint' => 'https://www.virustotal.com/api/v3/urls',
    ],

    'haveibeenpwned' => [
        'api_key' => env('HIBP_API_KEY'),
        'endpoint' => 'https://haveibeenpwned.com/api/v3/breachedaccount/',
    ],

];
