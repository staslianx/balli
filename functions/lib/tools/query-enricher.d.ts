/**
 * Query Enricher - Adds conversation context to search queries
 *
 * Solves the "when should I do tests?" → HIV results problem
 * by enriching vague queries with conversation context
 */
export interface QueryEnrichmentInput {
    currentQuestion: string;
    conversationHistory?: Array<{
        role: string;
        content: string;
    }>;
    diabetesProfile?: {
        type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
        medications?: string[];
    };
}
export interface EnrichedQuery {
    original: string;
    enriched: string;
    reasoning: string;
    contextUsed: boolean;
}
/**
 * Enrich a search query with conversation context
 */
export declare function enrichQuery(input: QueryEnrichmentInput): Promise<EnrichedQuery>;
//# sourceMappingURL=query-enricher.d.ts.map