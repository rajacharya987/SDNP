<?php

namespace App\Services;

class TextAnalysisService
{
    protected array $phishingKeywords;

    public function __construct()
    {
        $this->phishingKeywords = config('safelink.phishing_keywords', []);
    }

    /**
     * Analyze message body for SMS phishing, scam patterns, and social engineering urgency flags.
     *
     * @param string $message
     * @return array
     */
    public function analyzeMessage(string $message): array
    {
        $lowercaseMessage = strtolower($message);
        $detectedFlags = [];
        $score = 0;

        // 1. Urgency & Social Engineering Trigger Checks
        $urgencyKeywords = ['urgent', 'immediate action', 'within 24 hours', 'account suspended', 'locked', 'expired'];
        foreach ($urgencyKeywords as $keyword) {
            if (str_contains($lowercaseMessage, $keyword)) {
                $detectedFlags[] = "Urgency Indicator: '{$keyword}'";
                $score += 25;
            }
        }

        // 2. Financial & Reward Bait Checks
        $financialKeywords = ['claim prize', 'winner', 'refund approved', 'tax refund', 'lottery', 'crypto bonus', 'bank alert', 'unauthorized access'];
        foreach ($financialKeywords as $keyword) {
            if (str_contains($lowercaseMessage, $keyword)) {
                $detectedFlags[] = "Financial Bait: '{$keyword}'";
                $score += 30;
            }
        }

        // 3. Extract embedded URLs in message
        preg_match_all('#\bhttps?://[^\s()<>]+(?:\([\w\d]+\)|([^[:punct:]\s]|/))#', $message, $urlMatches);
        $extractedUrls = $urlMatches[0] ?? [];

        if (!empty($extractedUrls)) {
            $detectedFlags[] = "Contains Embedded Links (" . count($extractedUrls) . ")";
            $score += 15;

            // Check if link uses shortener or IP address
            foreach ($extractedUrls as $url) {
                if (preg_match('/(bit\.ly|tinyurl\.com|t\.co|rb\.gy|cutt\.ly|shorturl\.at)/i', $url)) {
                    $detectedFlags[] = "URL Shortener Link Detected: {$url}";
                    $score += 20;
                }
                if (preg_match('/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/', $url)) {
                    $detectedFlags[] = "IP Address Hostname Detected: {$url}";
                    $score += 35;
                }
            }
        }

        // 4. Excessive Capitalization Check
        $capitalLetterCount = preg_match_all('/[A-Z]/', $message);
        $totalLetterCount = strlen(preg_replace('/[^a-zA-Z]/', '', $message));
        if ($totalLetterCount > 10 && ($capitalLetterCount / $totalLetterCount) > 0.4) {
            $detectedFlags[] = "High Capitalization Ratio (Aggressive Tone)";
            $score += 10;
        }

        // Cap score at 100
        $finalScore = min(100, $score);

        // Determine Verdict
        if ($finalScore >= 70) {
            $verdict = 'HIGH_RISK_SCAM';
            $verdictColor = 'red';
            $verdictTitle = 'High Risk Scam Message';
        } elseif ($finalScore >= 35) {
            $verdict = 'SUSPICIOUS';
            $verdictColor = 'yellow';
            $verdictTitle = 'Suspicious Message - Proceed with Caution';
        } else {
            $verdict = 'SAFE';
            $verdictColor = 'green';
            $verdictTitle = 'Likely Safe Message';
        }

        return [
            'risk_score' => $finalScore,
            'verdict' => $verdict,
            'verdict_title' => $verdictTitle,
            'verdict_color' => $verdictColor,
            'flags_detected' => array_unique($detectedFlags),
            'extracted_urls' => $extractedUrls,
            'recommendation' => $finalScore >= 35 
                ? 'Do NOT click any embedded links or provide personal details. Verify with the organization directly.'
                : 'Message appears normal, but remain vigilant when opening links.',
        ];
    }
}
