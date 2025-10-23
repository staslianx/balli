/**
 * Intelligent Source Selector - Top-P Style Selection with Deduplication
 *
 * Automatically selects the best sources for synthesis based on:
 * 1. Relevance scores (top-P selection)
 * 2. Token budget constraints
 * 3. Semantic deduplication (avoid near-duplicates)
 * 4. Quality thresholds
 *
 * SELECTION STRATEGY:
 * - Sort sources by relevance (highest first)
 * - Select top N sources (default: 30)
 * - Extend to 35 if high-scoring sources (>70) available
 * - Remove semantic near-duplicates
 * - Respect token budget (default: 16800 tokens)
 *
 * INTEGRATION POINT:
 * - Called after source ranking
 * - Before synthesis formatting
 * - Automatic selection (no manual intervention)
 */
import { RankedSource } from './source-ranker';
/**
 * Selected source with full metadata for synthesis
 */
export interface SelectedSource {
    source: any;
    relevanceScore: number;
    sourceType: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa';
    citation: string;
    summary: string;
    credibilityBadge: string;
    estimatedTokens: number;
}
/**
 * Source selection result
 */
export interface SourceSelectionResult {
    selectedSources: SelectedSource[];
    totalSources: number;
    selectedCount: number;
    deduplicatedCount: number;
    totalTokens: number;
    selectionStrategy: string;
    qualityMetrics: {
        averageRelevance: number;
        minRelevance: number;
        maxRelevance: number;
        highQualityCount: number;
    };
}
/**
 * Configuration for source selection
 */
export interface SourceSelectionConfig {
    baseLimit?: number;
    extendedLimit?: number;
    highQualityThreshold?: number;
    tokenBudget?: number;
    minRelevanceScore?: number;
    semanticSimilarityThreshold?: number;
    enableSemanticDedup?: boolean;
}
/**
 * Select the best sources for synthesis using top-P style strategy
 *
 * @param rankedSources - Sources with relevance scores (already sorted)
 * @param config - Selection configuration
 * @returns Selected sources optimized for synthesis
 */
export declare function selectSourcesForSynthesis(rankedSources: RankedSource[], config?: SourceSelectionConfig): Promise<SourceSelectionResult>;
/**
 * Format selected sources for AI synthesis prompt
 *
 * @param selectedSources - Sources selected for synthesis
 * @returns Formatted string for synthesis prompt
 */
export declare function formatSelectedSourcesForSynthesis(selectedSources: SelectedSource[]): string;
//# sourceMappingURL=source-selector.d.ts.map