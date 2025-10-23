/**
 * Research Helper Functions
 * Shared utilities for research search functionality
 */
import { Genkit } from 'genkit';
import type { ExaSearchResult } from '../tools/exa-search';
import type { PubMedArticleResult } from '../tools/pubmed-search';
import type { MedRxivResult } from '../tools/medrxiv-search';
import type { ClinicalTrialResult } from '../tools/clinical-trials';
/**
 * Generate contextual follow-up questions using AI based on the query and answer
 * @param ai - Genkit AI instance
 * @param model - Model reference to use for generation
 * @param query - Original user query
 * @param answer - The generated answer
 * @param strategy - Search strategy used (direct_knowledge, medical_sources, deep_research)
 * @returns Promise resolving to array of 3 contextual questions in Turkish
 */
export declare function generateRelatedQuestions(ai: Genkit, model: any, query: string, answer: string, strategy: string): Promise<string[]>;
/**
 * Calculate confidence level based on strategy and source count
 * @param strategy - Search strategy used
 * @param sourceCount - Number of sources found
 * @returns Confidence level 0-100
 */
export declare function calculateConfidence(strategy: string, sourceCount: number): number;
/**
 * Map credibility level from API response to UI badge
 * @param level - Credibility level from API
 * @returns UI credibility badge type
 */
export declare function mapCredibilityLevel(level: string): 'medical_source' | 'peer_reviewed' | 'clinical_trial' | 'expert';
/**
 * Source types for research results
 * Used to display appropriate badges in iOS client
 */
export type SourceType = 'pubmed' | 'medrxiv' | 'clinicalTrial' | 'exaWeb' | 'knowledgeBase';
/**
 * Formatted source with type information for client consumption
 */
export interface FormattedSource {
    title: string;
    url: string | null;
    type: SourceType;
    authors?: string;
    journal?: string;
    year?: string;
    snippet?: string;
    credibilityLevel?: string;
}
/**
 * Format research sources with type information
 * Combines results from all APIs into a unified format for client
 *
 * @param exa - Exa search results (trusted medical websites)
 * @param pubmed - PubMed article results
 * @param arxiv - arXiv paper results
 * @param clinicalTrials - ClinicalTrials.gov results
 * @returns Array of formatted sources with type metadata
 */
export declare function formatSourcesWithTypes(exa: ExaSearchResult[], pubmed: PubMedArticleResult[], medrxiv: MedRxivResult[], clinicalTrials: ClinicalTrialResult[]): FormattedSource[];
//# sourceMappingURL=research-helpers.d.ts.map