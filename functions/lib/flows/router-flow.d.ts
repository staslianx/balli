/**
 * Router Flow - Decides between T1, T2, and T3
 *
 * NEW 3-TIER SYSTEM:
 * - T1 (tier 1): Model-only responses with Flash (40% of queries)
 * - T2 (tier 2): Hybrid Research with Flash + thinking + 10 sources (40% of queries)
 * - T3 (tier 3): Deep Research with Pro + 25+ sources - USER CONTROLLED ONLY (20% of queries)
 *
 * Uses simple string matching for tier determination:
 * - Contains "derinleş" → T3 (Deep Research)
 * - Contains "araştır" → T2 (Hybrid Research)
 * - Everything else → T1 (Model-only)
 */
export interface RouterInput {
    question: string;
    userId: string;
    diabetesProfile?: {
        type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
        medications?: string[];
    };
    conversationHistory?: Array<{
        role: string;
        content: string;
    }>;
}
export interface RouterOutput {
    tier: 0 | 1 | 2 | 3;
    reasoning: string;
    confidence: number;
    explicitDeepRequest?: boolean;
    isRecallRequest?: boolean;
    searchTerms?: string;
}
export declare function routeQuestion(input: RouterInput): Promise<RouterOutput>;
//# sourceMappingURL=router-flow.d.ts.map