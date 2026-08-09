<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GeminiService
{
    protected string $apiKey;
    protected string $model;

    public function __construct()
    {
        $this->apiKey = (string) config('safelink.api_keys.gemini', '');
        $this->model = (string) config('services.gemini.model', 'gemini-2.5-flash');
    }

    public function isConfigured(): bool
    {
        return $this->apiKey !== '';
    }

    /**
     * Deep SMS / message threat analysis. Returns SafeLink-branded fields only.
     * When $preferNepali is true, summary and action are written in simple Nepali.
     */
    public function analyzeSms(string $message, bool $preferNepali = false): ?array
    {
        if (!$this->isConfigured()) {
            return null;
        }

        $langRule = $preferNepali
            ? "The message is in Nepali. Write summary and recommended_action in simple Nepali (नेपाली) that parents can understand. Keep flags short; Nepali or English is fine."
            : "Write summary and recommended_action in clear simple English. If the message is Nepali, you may use simple Nepali instead.";

        $prompt = <<<PROMPT
You are the silent internal scoring module of SafeLink, a cybersecurity URL/SMS scanner.
Never mention AI, Gemini, LLM, OpenAI, ChatGPT, or that you are a language model.
Write like a security engine report.

Analyze the message for phishing / social engineering / scams (including Nepali SMS scams: bank lock, OTP, prize, KYC, eSewa/Khalti bait).
{$langRule}
Return ONLY valid JSON (no markdown) with this exact shape:
{
  "risk_score": 0-100 integer,
  "flags": ["short finding strings"],
  "summary": "1-2 sentence SafeLink engine summary for the user",
  "recommended_action": "one clear action sentence",
  "verdict": "SAFE" | "SUSPICIOUS" | "HIGH_RISK_SCAM"
}
PROMPT;

        $raw = $this->generate($prompt."\n\nMESSAGE:\n".$message);
        $data = $this->parseJson($raw);
        if ($data === null) {
            return null;
        }

        return [
            'risk_score' => min(100, max(0, (int) ($data['risk_score'] ?? 0))),
            'flags' => array_values(array_filter(array_map('strval', $data['flags'] ?? []))),
            'summary' => $this->sanitizeCopy((string) ($data['summary'] ?? '')),
            'recommended_action' => $this->sanitizeCopy((string) ($data['recommended_action'] ?? '')),
            'verdict' => strtoupper((string) ($data['verdict'] ?? 'SUSPICIOUS')),
        ];
    }

    /**
     * Explain an already-scored URL scan. Must not override hard verdict alone.
     */
    public function explainScan(array $scanContext): ?array
    {
        if (!$this->isConfigured()) {
            return null;
        }

        $contextJson = json_encode($scanContext, JSON_UNESCAPED_SLASHES);

        $prompt = <<<'PROMPT'
You are the silent reporting module of SafeLink cybersecurity scanner.
Never mention AI, Gemini, LLM, or that you are a language model.
Do not invent new provider verdicts. Only explain the given scan context.

Return ONLY valid JSON (no markdown):
{
  "status": "clean" | "flagged" | "skipped",
  "summary": "2 short sentences for the user, SafeLink tone",
  "extra_findings": ["optional extra engine findings"]
}
If risk is low and checks look fine, status=clean.
If risk is elevated or unavailable, status=flagged.
PROMPT;

        $raw = $this->generate($prompt."\n\nSCAN_CONTEXT:\n".$contextJson);
        $data = $this->parseJson($raw);
        if ($data === null) {
            return null;
        }

        $status = strtolower((string) ($data['status'] ?? 'skipped'));
        if (!in_array($status, ['clean', 'flagged', 'skipped'], true)) {
            $status = 'skipped';
        }

        return [
            'status' => $status,
            'summary' => $this->sanitizeCopy((string) ($data['summary'] ?? '')),
            'extra_findings' => array_values(array_filter(array_map(
                fn ($f) => $this->sanitizeCopy((string) $f),
                $data['extra_findings'] ?? []
            ))),
            'message' => 'Deep pattern analysis completed.',
        ];
    }

    protected function generate(string $prompt): ?string
    {
        try {
            $url = sprintf(
                'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s',
                urlencode($this->model),
                urlencode($this->apiKey)
            );

            // 2.5 flash spends part of maxOutputTokens on "thinking"; keep headroom
            // so JSON answers are not truncated mid-object.
            $response = Http::timeout(20)
                ->connectTimeout(5)
                ->acceptJson()
                ->asJson()
                ->post($url, [
                    'contents' => [
                        [
                            'role' => 'user',
                            'parts' => [['text' => $prompt]],
                        ],
                    ],
                    'generationConfig' => [
                        'temperature' => 0.2,
                        'maxOutputTokens' => 2048,
                        'responseMimeType' => 'application/json',
                    ],
                ]);

            if (!$response->successful()) {
                Log::warning('Deep analysis engine HTTP error', [
                    'status' => $response->status(),
                    'body' => substr($response->body(), 0, 400),
                ]);

                // Retry once on a lighter model if quota/model unavailable
                if (in_array($response->status(), [404, 429], true) && $this->model !== 'gemini-2.0-flash') {
                    return $this->generateWithModel($prompt, 'gemini-2.0-flash');
                }

                return null;
            }

            return $this->extractText($response->json());
        } catch (\Throwable $e) {
            Log::warning('Deep analysis engine failed', ['error' => $e->getMessage()]);
            return null;
        }
    }

    protected function generateWithModel(string $prompt, string $model): ?string
    {
        try {
            $url = sprintf(
                'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s',
                urlencode($model),
                urlencode($this->apiKey)
            );

            $response = Http::timeout(20)
                ->connectTimeout(5)
                ->acceptJson()
                ->asJson()
                ->post($url, [
                    'contents' => [
                        [
                            'role' => 'user',
                            'parts' => [['text' => $prompt]],
                        ],
                    ],
                    'generationConfig' => [
                        'temperature' => 0.2,
                        'maxOutputTokens' => 2048,
                        'responseMimeType' => 'application/json',
                    ],
                ]);

            if (!$response->successful()) {
                Log::warning('Deep analysis fallback model failed', [
                    'model' => $model,
                    'status' => $response->status(),
                ]);
                return null;
            }

            return $this->extractText($response->json());
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * Prefer the last non-thought text part (2.5 models may include thought parts).
     */
    protected function extractText(mixed $payload): ?string
    {
        if (!is_array($payload)) {
            return null;
        }

        $parts = $payload['candidates'][0]['content']['parts'] ?? [];
        if (!is_array($parts) || $parts === []) {
            return null;
        }

        $text = null;
        foreach ($parts as $part) {
            if (!is_array($part)) {
                continue;
            }
            if (!empty($part['thought'])) {
                continue;
            }
            if (isset($part['text']) && is_string($part['text']) && $part['text'] !== '') {
                $text = $part['text'];
            }
        }

        return $text;
    }

    protected function parseJson(?string $raw): ?array
    {
        if ($raw === null || trim($raw) === '') {
            return null;
        }

        $trimmed = trim($raw);
        // Strip accidental fences
        $trimmed = preg_replace('/^```(?:json)?\s*/i', '', $trimmed) ?? $trimmed;
        $trimmed = preg_replace('/\s*```$/', '', $trimmed) ?? $trimmed;

        $decoded = json_decode($trimmed, true);
        if (is_array($decoded)) {
            return $decoded;
        }

        if (preg_match('/\{.*\}/s', $trimmed, $m)) {
            $decoded = json_decode($m[0], true);
            return is_array($decoded) ? $decoded : null;
        }

        return null;
    }

    protected function sanitizeCopy(string $text): string
    {
        $text = trim($text);
        $banned = [
            '/\bas an ai\b/i',
            '/\bas a language model\b/i',
            '/\bgemini\b/i',
            '/\bchatgpt\b/i',
            '/\bopenai\b/i',
            '/\bllm\b/i',
            '/\bi am an? ai\b/i',
        ];
        foreach ($banned as $pattern) {
            $text = preg_replace($pattern, 'SafeLink', $text) ?? $text;
        }

        return trim($text);
    }
}
