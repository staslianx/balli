/**
 * Parallel Research Fetcher
 * Fetches from multiple research APIs concurrently with fault tolerance
 * Supports T2 (10 sources) and T3 (25 sources) configurations
 *
 * RELIABILITY IMPROVEMENTS:
 * - Individual timeouts per API (PubMed: 3s, arXiv: 3s, ClinicalTrials: 3s, Exa: 10s)
 * - Graceful degradation: continues with partial results if some APIs fail
 * - Uses Promise.allSettled for fault tolerance
 * - Detailed timeout and error logging
 */
import { type ExaSearchResult } from './exa-search';
import { type PubMedArticleResult } from './pubmed-search';
import { type MedRxivResult } from './medrxiv-search';
import { type ClinicalTrialResult } from './clinical-trials';
/**
 * Progress callback for real-time research updates
 * Called as each API starts/completes
 */
export type ProgressCallback = (event: {
    type: 'api_started' | 'api_completed' | 'progress_update';
    api?: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa';
    count?: number;
    duration?: number;
    success?: boolean;
    fetched?: number;
    total?: number;
}) => void;
/**
 * Configuration for research fetch operation
 * Defines how many sources to fetch from each API
 */
export interface ResearchFetchConfig {
    exaCount: number;
    pubmedCount: number;
    medrxivCount: number;
    clinicalTrialsCount: number;
}
/**
 * Results from parallel research fetch
 * Includes timing data for performance monitoring
 */
export interface ResearchFetchResults {
    exa: ExaSearchResult[];
    pubmed: PubMedArticleResult[];
    medrxiv: MedRxivResult[];
    clinicalTrials: ClinicalTrialResult[];
    timings: {
        exa: number;
        pubmed: number;
        medrxiv: number;
        clinicalTrials: number;
        total: number;
    };
    errors: {
        exa?: string;
        pubmed?: string;
        medrxiv?: string;
        clinicalTrials?: string;
    };
}
/**
 * Fetch from all research sources in parallel
 * Uses Promise.allSettled for fault tolerance - if one API fails, others still return results
 *
 * @param query - User's search query
 * @param config - Source count configuration
 * @param progressCallback - Optional callback for real-time progress updates
 * @returns Research results with timing data
 */
export declare function fetchAllResearchSources(query: string, config: ResearchFetchConfig, progressCallback?: ProgressCallback): Promise<ResearchFetchResults>;
/**
 * Preset configurations for T2 and T3 tiers
 */
export declare const TIER_CONFIGS: {
    /**
     * T2 Hybrid Research: 10 total sources
     * 5 Exa (trusted medical sites) + 5 dynamic API (PubMed/medRxiv/Trials)
     */
    T2: (pubmedCount: number, medrxivCount: number, clinicalTrialsCount: number) => ResearchFetchConfig;
    /**
     * T3 Deep Research: 25 total sources
     * 10 Exa (trusted medical sites) + 15 dynamic API (PubMed/medRxiv/Trials)
     */
    T3: (pubmedCount: number, medrxivCount: number, clinicalTrialsCount: number) => ResearchFetchConfig;
};
/**
 * Create T2 configuration with dynamic API distribution
 * @param pubmedCount - Number of PubMed articles
 * @param medrxivCount - Number of medRxiv preprints
 * @param clinicalTrialsCount - Number of clinical trials
 * @returns T2 research configuration
 */
export declare function createT2Config(pubmedCount: number, medrxivCount: number, clinicalTrialsCount: number): ResearchFetchConfig;
/**
 * Create T3 configuration with dynamic API distribution
 * @param pubmedCount - Number of PubMed articles
 * @param medrxivCount - Number of medRxiv preprints
 * @param clinicalTrialsCount - Number of clinical trials
 * @returns T3 research configuration
 */
export declare function createT3Config(pubmedCount: number, medrxivCount: number, clinicalTrialsCount: number): ResearchFetchConfig;
//# sourceMappingURL=parallel-research-fetcher.d.ts.map