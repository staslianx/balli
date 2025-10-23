/**
 * Source Relevance Ranker - Simple Keyword-Based Source Prioritization
 *
 * Uses keyword matching and metadata scoring to rank research sources by relevance.
 * Stateless implementation with no embeddings or vector search.
 *
 * RANKING CRITERIA:
 * 1. Keyword relevance (title + abstract matching)
 * 2. Source credibility boost (PubMed/Trials > medRxiv > Exa)
 * 3. Recency boost (for medical queries, newer is better)
 */
/**
 * Ranked source with relevance score
 */
export interface RankedSource {
    source: any;
    relevanceScore: number;
    reasoning: string;
    sourceType: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa';
}
/**
 * Source ranking results
 */
export interface SourceRankingResult {
    rankedSources: RankedSource[];
    topSources: RankedSource[];
    totalSources: number;
    averageRelevance: number;
    rankingDuration: number;
}
/**
 * Configuration for source ranking
 */
export interface RankingConfig {
    topN: number;
}
/**
 * Rank research sources by relevance to user query using keyword matching
 *
 * @param query - User's research question
 * @param sources - Object containing sources from all APIs
 * @param config - Ranking configuration
 * @returns Ranking results with top N sources
 */
export declare function rankSourcesByRelevance(query: string, sources: {
    pubmed: any[];
    medrxiv: any[];
    clinicalTrials: any[];
    exa: any[];
}, config: RankingConfig): Promise<SourceRankingResult>;
/**
 * Reorder sources array based on ranking results
 */
export declare function reorderSourcesByRanking(sources: {
    pubmed: any[];
    medrxiv: any[];
    clinicalTrials: any[];
    exa: any[];
}, rankingResult: SourceRankingResult): {
    pubmed: any[];
    medrxiv: any[];
    clinicalTrials: any[];
    exa: any[];
};
//# sourceMappingURL=source-ranker.d.ts.map