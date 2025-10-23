/**
 * Query Analyzer Tool
 * Analyzes user queries to determine optimal API source distribution
 * Uses Gemini 2.5 Flash for fast, accurate categorization
 *
 * Cost: ~$0.00001 per analysis
 * Timeout: 2 seconds
 */
/**
 * Query category types for diabetes research
 */
export type QueryCategory = 'drug_safety' | 'new_research' | 'treatment' | 'nutrition' | 'general';
/**
 * Analysis result with optimal API distribution
 */
export interface QueryAnalysis {
    category: QueryCategory;
    pubmedRatio: number;
    medrxivRatio: number;
    clinicalTrialsRatio: number;
    confidence: number;
}
/**
 * Analyze query and return optimal API source distribution
 * @param query - User's question
 * @param targetSourceCount - Total number of API sources to fetch (e.g., 5 for T2, 15 for T3)
 * @returns QueryAnalysis with category and optimal API ratios
 */
export declare function analyzeQuery(query: string, targetSourceCount: number): Promise<QueryAnalysis>;
/**
 * Calculate exact source counts from ratios
 * Ensures counts sum to targetSourceCount
 * @param analysis - Query analysis with ratios
 * @param targetSourceCount - Total sources needed
 * @returns Object with exact counts per API
 */
export declare function calculateSourceCounts(analysis: QueryAnalysis, targetSourceCount: number): {
    pubmedCount: number;
    medrxivCount: number;
    clinicalTrialsCount: number;
};
//# sourceMappingURL=query-analyzer.d.ts.map