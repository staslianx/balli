/**
 * Source Deduplicator - Cross-Round Deduplication
 * Tracks and filters duplicate sources across multiple research rounds
 */
import { ExaSearchResult } from './exa-search';
import { PubMedArticleResult } from './pubmed-search';
import { MedRxivResult } from './medrxiv-search';
import { ClinicalTrialResult } from './clinical-trials';
/**
 * Source Deduplication Tracker
 * Maintains set of seen identifiers across rounds
 */
export declare class SourceDeduplicator {
    private seenIdentifiers;
    private duplicateCount;
    /**
     * Extract unique identifier from a source
     * Priority: DOI > PubMed ID > medRxiv DOI > URL
     */
    private extractIdentifier;
    /**
     * Convert identifier to string key for Set
     */
    private identifierToKey;
    /**
     * Check if a source has been seen before
     */
    isSeen(source: ExaSearchResult | PubMedArticleResult | MedRxivResult | ClinicalTrialResult): boolean;
    /**
     * Mark a source as seen
     */
    markSeen(source: ExaSearchResult | PubMedArticleResult | MedRxivResult | ClinicalTrialResult): void;
    /**
     * Filter duplicates from PubMed results
     */
    filterPubMed(articles: PubMedArticleResult[]): PubMedArticleResult[];
    /**
     * Filter duplicates from medRxiv results
     */
    filterMedRxiv(papers: MedRxivResult[]): MedRxivResult[];
    /**
     * Filter duplicates from Clinical Trials results
     */
    filterClinicalTrials(trials: ClinicalTrialResult[]): ClinicalTrialResult[];
    /**
     * Filter duplicates from Exa results
     */
    filterExa(results: ExaSearchResult[]): ExaSearchResult[];
    /**
     * Get statistics
     */
    getStats(): {
        totalSeen: number;
        duplicatesFiltered: number;
    };
    /**
     * Log deduplication summary
     */
    logSummary(): void;
}
//# sourceMappingURL=source-deduplicator.d.ts.map