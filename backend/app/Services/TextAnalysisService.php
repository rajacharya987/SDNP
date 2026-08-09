<?php

namespace App\Services;

class TextAnalysisService
{
    protected array $phishingKeywords;
    protected array $nepaliKeywords;

    public function __construct(
        protected GeminiService $geminiService
    ) {
        $this->phishingKeywords = config('safelink.phishing_keywords', []);
        $this->nepaliKeywords = config('safelink.nepali_phishing_keywords', []);
    }

    /**
     * Analyze message body for SMS phishing, scam patterns, and social engineering urgency flags.
     * Detects Nepali (Devanagari) / romanized Nepali bait and returns parent-friendly guides.
     */
    public function analyzeMessage(string $message): array
    {
        $lowercaseMessage = mb_strtolower($message, 'UTF-8');
        $detectedFlags = [];
        $score = 0;
        $isNepali = $this->containsNepaliScript($message);

        $urgencyKeywords = ['urgent', 'immediate action', 'within 24 hours', 'account suspended', 'locked', 'expired'];
        foreach ($urgencyKeywords as $keyword) {
            if (str_contains($lowercaseMessage, $keyword)) {
                $detectedFlags[] = "Urgency Indicator: '{$keyword}'";
                $score += 25;
            }
        }

        $financialKeywords = ['claim prize', 'winner', 'refund approved', 'tax refund', 'lottery', 'crypto bonus', 'bank alert', 'unauthorized access'];
        foreach ($financialKeywords as $keyword) {
            if (str_contains($lowercaseMessage, $keyword)) {
                $detectedFlags[] = "Financial Bait: '{$keyword}'";
                $score += 30;
            }
        }

        foreach ($this->phishingKeywords as $keyword) {
            $needle = mb_strtolower((string) $keyword, 'UTF-8');
            if ($needle !== '' && str_contains($lowercaseMessage, $needle)) {
                $detectedFlags[] = "Scam phrase: '{$keyword}'";
                $score += 18;
            }
        }

        // Nepali + romanized Nepali scam phrases
        $nepaliHits = 0;
        foreach ($this->nepaliKeywords as $keyword) {
            $needle = mb_strtolower((string) $keyword, 'UTF-8');
            if ($needle === '') {
                continue;
            }
            if (str_contains($lowercaseMessage, $needle) || str_contains($message, (string) $keyword)) {
                $detectedFlags[] = "नेपाली शंकास्पद शब्द: '{$keyword}'";
                $score += 28;
                $nepaliHits++;
                $isNepali = true;
            }
        }

        preg_match_all('#\bhttps?://[^\s()<>]+(?:\([\w\d]+\)|([^[:punct:]\s]|/))#u', $message, $urlMatches);
        $extractedUrls = $urlMatches[0] ?? [];

        if (!empty($extractedUrls)) {
            $detectedFlags[] = 'Contains Embedded Links (' . count($extractedUrls) . ')';
            $score += 15;

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

        $capitalLetterCount = preg_match_all('/[A-Z]/', $message);
        $totalLetterCount = strlen(preg_replace('/[^a-zA-Z]/', '', $message));
        if ($totalLetterCount > 10 && ($capitalLetterCount / $totalLetterCount) > 0.4) {
            $detectedFlags[] = 'High Capitalization Ratio (Aggressive Tone)';
            $score += 10;
        }

        $finalScore = min(100, $score);
        $summary = '';
        $recommendation = $finalScore >= 35
            ? 'Do NOT click any embedded links or provide personal details. Verify with the organization directly.'
            : 'Message appears normal, but remain vigilant when opening links.';

        // Deep pattern pass — ask for Nepali guidance when message is Nepali
        $deep = $this->geminiService->analyzeSms($message, $isNepali);
        if (is_array($deep)) {
            $finalScore = max($finalScore, min(100, (int) ($deep['risk_score'] ?? 0)));
            foreach ($deep['flags'] ?? [] as $flag) {
                $flag = trim((string) $flag);
                if ($flag !== '') {
                    $detectedFlags[] = $flag;
                }
            }
            if (!empty($deep['summary'])) {
                $summary = (string) $deep['summary'];
            }
            if (!empty($deep['recommended_action'])) {
                $recommendation = (string) $deep['recommended_action'];
            }
        }

        if ($finalScore >= 70) {
            $verdict = 'HIGH_RISK_SCAM';
            $verdictColor = 'red';
            $verdictTitle = $isNepali ? 'ठगी जस्तो सन्देश — नखोल्नुहोस्' : 'High Risk Scam Message';
        } elseif ($finalScore >= 35) {
            $verdict = 'SUSPICIOUS';
            $verdictColor = 'yellow';
            $verdictTitle = $isNepali ? 'शंकास्पद सन्देश — सावधान' : 'Suspicious Message - Proceed with Caution';
        } else {
            $verdict = 'SAFE';
            $verdictColor = 'green';
            $verdictTitle = $isNepali ? 'ठूलो खतरा देखिएन' : 'Likely Safe Message';
        }

        $guideNe = $this->nepaliGuide($finalScore, !empty($extractedUrls), $nepaliHits > 0);
        $guideEn = $this->englishGuide($finalScore, !empty($extractedUrls));

        if ($isNepali) {
            // Prefer Nepali copy for parents when the message itself is Nepali.
            if ($summary === '' || !$this->containsNepaliScript($summary)) {
                $summary = $guideNe['summary'];
            }
            if (!$this->containsNepaliScript($recommendation)) {
                $recommendation = $guideNe['action'];
            }
        } elseif ($summary === '') {
            $summary = $verdictTitle.'. SafeLink message scan completed.';
        }

        return [
            'risk_score' => $finalScore,
            'verdict' => $verdict,
            'verdict_title' => $verdictTitle,
            'verdict_color' => $verdictColor,
            'summary' => $summary,
            'flags_detected' => array_values(array_unique($detectedFlags)),
            'extracted_urls' => $extractedUrls,
            'recommendation' => $recommendation,
            'language' => $isNepali ? 'ne' : 'en',
            'is_nepali' => $isNepali,
            'guide_ne' => $guideNe['action'],
            'guide_en' => $guideEn,
            'steps_ne' => $guideNe['steps'],
            'deep_analysis' => [
                'status' => is_array($deep)
                    ? (($finalScore >= 35) ? 'flagged' : 'clean')
                    : 'skipped',
                'message' => is_array($deep)
                    ? 'Pattern analysis completed.'
                    : 'Pattern analysis unavailable — keyword engine used.',
            ],
        ];
    }

    protected function containsNepaliScript(string $text): bool
    {
        return (bool) preg_match('/[\x{0900}-\x{097F}]/u', $text);
    }

    /**
     * Plain Nepali guidance for moms/dads.
     */
    protected function nepaliGuide(int $score, bool $hasLink, bool $hitNepaliPhrase): array
    {
        if ($score >= 70) {
            return [
                'summary' => 'यो सन्देश ठगी (स्क्याम) जस्तो देखिन्छ। पासवर्ड, OTP वा पैसा नदिनुहोस्।',
                'action' => 'लिङ्क नखोल्नुहोस्। सन्देश मेटाउनुहोस्। बैंक वा परिवारलाई सोध्नुहोस्।',
                'steps' => [
                    'कुनै पनि लिङ्क नखोल्नुहोस्',
                    'OTP वा पासवर्ड नदिनुहोस्',
                    'पैसा नपठाउनुहोस्',
                    'परिवार वा नजिकको व्यक्तिलाई देखाउनुहोस्',
                ],
            ];
        }

        if ($score >= 35) {
            return [
                'summary' => 'यो सन्देश शंकास्पद छ। हतार नगर्नुहोस्।',
                'action' => 'लिङ्क नखोल्नुहोस्। पहिले परिवार वा थाहा भएको व्यक्तिलाई सोध्नुहोस्।',
                'steps' => [
                    'लिङ्क अहिले नखोल्नुहोस्',
                    'पठाउने नम्बर/नाम चिनिएको हो कि हेर्नुहोस्',
                    'शंका लागे परिवारलाई देखाउनुहोस्',
                    $hasLink ? 'SafeLink बाट लिङ्क जाँच गर्नुहोस्' : 'सन्देश सुरक्षित राख्नुहोस्',
                ],
            ];
        }

        return [
            'summary' => 'ठूलो खतरा देखिएन। तर अज्ञात लिङ्क अझै नखोल्नुहोस्।',
            'action' => 'अपरिचित लिङ्क नखोल्नुहोस्। शंका लागे SafeLink मा जाँच गर्नुहोस्।',
            'steps' => [
                'अपरिचित लिङ्क नखोल्नुहोस्',
                'OTP कसैलाई नदिनुहोस्',
                'शंका लागे फेरि SafeLink मा जाँच गर्नुहोस्',
            ],
        ];
    }

    protected function englishGuide(int $score, bool $hasLink): string
    {
        if ($score >= 70) {
            return 'Do not open links or share OTP/password. Delete the message and ask family or your bank.';
        }
        if ($score >= 35) {
            return 'Be careful. Do not open links yet. Ask someone you trust before taking any action.';
        }

        return 'No major scam signs found. Still avoid unknown links.';
    }
}
