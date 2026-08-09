<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\AnalyzeSmsRequest;
use App\Services\TextAnalysisService;

class SmsAnalyzerController extends Controller
{
    protected TextAnalysisService $analysisService;

    public function __construct(TextAnalysisService $analysisService)
    {
        $this->analysisService = $analysisService;
    }

    /**
     * Analyze message text for phishing, scam indicators, and social engineering red flags.
     */
    public function analyze(AnalyzeSmsRequest $request)
    {
        $message = $request->validated()['message'];
        $analysis = $this->analysisService->analyzeMessage($message);

        return $this->successResponse($analysis, 'Message analysis completed');
    }
}
