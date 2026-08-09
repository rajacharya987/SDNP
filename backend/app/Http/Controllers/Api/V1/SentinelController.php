<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\FingerprintService;
use Illuminate\Http\Request;

class SentinelController extends Controller
{
    protected FingerprintService $fingerprintService;

    public function __construct(FingerprintService $fingerprintService)
    {
        $this->fingerprintService = $fingerprintService;
    }

    /**
     * Generate website security fingerprint & threat score.
     */
    public function fingerprint(Request $request)
    {
        $request->validate([
            'url' => 'required|string|max:2048',
            'page_meta' => 'nullable|array',
        ]);

        $url = trim($request->input('url'));
        $pageMeta = $request->input('page_meta', []);

        $result = $this->fingerprintService->generateFingerprint($url, $pageMeta);

        return $this->successResponse($result, 'SentinelX website fingerprint generated');
    }

    /**
     * Audit browser extensions & permissions risk.
     */
    public function extensionAudit(Request $request)
    {
        $extensions = $request->input('extensions', []);

        $audited = array_map(function ($ext) {
            $permissions = $ext['permissions'] ?? [];
            $riskScore = 0;
            $riskFlags = [];

            if (in_array('<all_urls>', $permissions) || in_array('http://*/*', $permissions) || in_array('https://*/*', $permissions)) {
                $riskScore += 40;
                $riskFlags[] = 'Broad web access to all websites (<all_urls>)';
            }
            if (in_array('cookies', $permissions)) {
                $riskScore += 25;
                $riskFlags[] = 'Access to sensitive session cookies';
            }
            if (in_array('webRequest', $permissions) || in_array('webRequestBlocking', $permissions)) {
                $riskScore += 25;
                $riskFlags[] = 'Intercepts network traffic (webRequest)';
            }
            if (in_array('tabs', $permissions) || in_array('history', $permissions)) {
                $riskScore += 10;
                $riskFlags[] = 'Reads active browser tabs & history';
            }

            $verdict = $riskScore >= 50 ? 'HIGH_RISK' : ($riskScore >= 25 ? 'MEDIUM_RISK' : 'SAFE');

            return [
                'id' => $ext['id'] ?? 'unknown',
                'name' => $ext['name'] ?? 'Extension',
                'version' => $ext['version'] ?? '1.0',
                'risk_score' => min(100, $riskScore),
                'verdict' => $verdict,
                'risk_flags' => $riskFlags,
            ];
        }, $extensions);

        return $this->successResponse([
            'total_audited' => count($audited),
            'high_risk_count' => count(array_filter($audited, fn($e) => $e['verdict'] === 'HIGH_RISK')),
            'extensions' => $audited,
        ], 'Extension permission audit completed');
    }

    /**
     * Get SentinelX Global Dashboard Protection Status.
     */
    public function dashboard()
    {
        return $this->successResponse([
            'system' => 'SentinelX Personal Security Platform',
            'layers' => [
                'web_protection' => 'ACTIVE',
                'dns_protection' => 'ACTIVE',
                'extension_protection' => 'ACTIVE',
                'system_agent' => 'ACTIVE',
            ],
            'stats' => [
                'threats_blocked_total' => 17,
                'phishing_blocked' => 8,
                'malware_blocked' => 4,
                'suspicious_extensions' => 3,
                'malicious_dns_blocked' => 2,
            ],
            'device_health' => [
                'network' => 'Protected',
                'browser' => 'Protected',
                'dns' => 'Protected',
                'system' => 'Protected',
            ]
        ], 'SentinelX status retrieved');
    }
}
