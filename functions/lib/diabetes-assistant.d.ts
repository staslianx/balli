/**
 * Diabetes Research Assistant - NEW 2-Tier Architecture
 *
 * Smart routing system that optimizes cost and quality:
 * - Tier 1 (FLASH): Gemini 2.5 Flash with optional Exa search - $0.0001-0.003
 * - Tier 2 (PRO_RESEARCH): Gemini 2.5 Pro + comprehensive research - $0.015-0.030
 *
 * Uses Gemini 2.5 Flash Lite for fast, accurate routing with few-shot prompting
 */
export interface DiabetesAssistantRequest {
    question: string;
    userId: string;
    diabetesProfile?: {
        type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
        medications?: string[];
    };
}
export interface DiabetesAssistantResponse {
    answer: string;
    tier: 1 | 2 | 3;
    processingTier: 'MODEL' | 'SEARCH' | 'RESEARCH';
    thinkingSummary?: string;
    routing: {
        selectedTier: number;
        reasoning: string;
        confidence: number;
    };
    sources: Array<{
        title: string;
        url?: string;
        type: string;
        [key: string]: any;
    }>;
    metadata: {
        processingTime: string;
        modelUsed: string;
        costTier: 'low' | 'medium' | 'high';
        toolsUsed?: string[];
    };
    researchSummary?: {
        totalStudies: number;
        pubmedArticles: number;
        clinicalTrials: number;
        arxivPapers?: number;
        exaMedicalSources?: number;
        evidenceQuality: string;
    };
    rateLimitInfo?: {
        remaining: number;
        resetAt: string;
    };
}
/**
 * Main diabetes assistant function
 */
export declare const diabetesAssistant: import("firebase-functions/v2/https").CallableFunction<any, Promise<DiabetesAssistantResponse>, unknown>;
/**
 * Health check endpoint
 */
export declare const diabetesAssistantHealth: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    status: string;
    timestamp: string;
    architecture: string;
    tiers: {
        flash: string;
        proResearch: string;
    };
    router: string;
    rateLimits: {
        proResearchDailyLimit: number;
    };
}>, unknown>;
/**
 * Get user's Tier 3 usage stats
 */
export declare const getTier3UsageStats: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    count: number;
    limit: number;
    remaining: number;
    resetAt: string;
}>, unknown>;
//# sourceMappingURL=diabetes-assistant.d.ts.map