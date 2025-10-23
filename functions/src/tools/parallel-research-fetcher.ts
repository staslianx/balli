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

import { searchMedicalSources, type ExaSearchResult } from './exa-search';
import { searchPubMed, type PubMedArticleResult } from './pubmed-search';
import { searchMedRxiv, type MedRxivResult } from './medrxiv-search';
import { searchClinicalTrials, type ClinicalTrialResult } from './clinical-trials';
import { translateToEnglishForAPIs } from './query-translator';
import { logger } from 'firebase-functions/v2';

/**
 * API timeout configurations (in milliseconds)
 * Based on audit recommendations
 */
const API_TIMEOUTS = {
  PUBMED: 3000,           // 3 seconds for PubMed
  MEDRXIV: 3000,          // 3 seconds for medRxiv
  CLINICAL_TRIALS: 3000,  // 3 seconds for ClinicalTrials.gov
  EXA: 10000              // 10 seconds for Exa (paid API, more reliable)
};

/**
 * Wrap promise with timeout
 * Returns rejected promise if operation exceeds timeout
 */
function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  operationName: string
): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(
        () => reject(new Error(`${operationName} timeout after ${timeoutMs}ms`)),
        timeoutMs
      )
    )
  ]);
}

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
  exaCount: number;              // Exa medical sources (trusted domains)
  pubmedCount: number;            // PubMed peer-reviewed articles
  medrxivCount: number;           // medRxiv medical preprints
  clinicalTrialsCount: number;    // ClinicalTrials.gov studies
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
export async function fetchAllResearchSources(
  query: string,
  config: ResearchFetchConfig,
  progressCallback?: ProgressCallback
): Promise<ResearchFetchResults> {
  const startTime = Date.now();

  console.log(
    `🔬 [PARALLEL-FETCH] Fetching ${config.exaCount + config.pubmedCount + config.medrxivCount + config.clinicalTrialsCount} sources in parallel`
  );
  console.log(
    `📊 [PARALLEL-FETCH] Distribution: Exa: ${config.exaCount}, PubMed: ${config.pubmedCount}, ` +
    `medRxiv: ${config.medrxivCount}, Trials: ${config.clinicalTrialsCount}`
  );
  console.log(`📝 [PARALLEL-FETCH] Original query: "${query.substring(0, 80)}..."`);

  // Translate Turkish queries to English for academic APIs (PubMed, medRxiv, ClinicalTrials)
  // Exa works fine with Turkish, so we keep the original query for it
  const englishQuery = await translateToEnglishForAPIs(query);
  console.log(`📝 [PARALLEL-FETCH] English query for APIs: "${englishQuery.substring(0, 80)}..."`);
  console.log(`📝 [PARALLEL-FETCH] Translation changed query: ${query !== englishQuery}`);

  // Track total expected sources for progress
  const totalExpected = config.exaCount + config.pubmedCount + config.medrxivCount + config.clinicalTrialsCount;
  let fetchedCount = 0;

  // Helper to update progress
  const updateProgress = () => {
    if (progressCallback) {
      progressCallback({
        type: 'progress_update',
        fetched: fetchedCount,
        total: totalExpected
      });
    }
  };

  // Create fetch promises with individual timing, TIMEOUTS, and PROGRESS EVENTS
  const exaStart = Date.now();
  const exaPromise = config.exaCount > 0
    ? (async () => {
        // Emit start event
        if (progressCallback) {
          progressCallback({
            type: 'api_started',
            api: 'exa',
            count: config.exaCount
          });
        }

        try {
          const results = await withTimeout(
            searchMedicalSources(query, config.exaCount),
            API_TIMEOUTS.EXA,
            'Exa search'
          );
          const timing = Date.now() - exaStart;
          fetchedCount += results.length;
          updateProgress();

          // Emit completion event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'exa',
              count: results.length,
              duration: timing,
              success: true
            });
          }

          return { status: 'fulfilled' as const, value: results, timing };
        } catch (error: any) {
          const timing = Date.now() - exaStart;
          logger.warn(`⏱️ [PARALLEL-FETCH] Exa failed/timeout after ${timing}ms`, { error: error.message });

          // Emit failure event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'exa',
              count: 0,
              duration: timing,
              success: false
            });
          }

          return { status: 'rejected' as const, reason: error.message, timing };
        }
      })()
    : Promise.resolve({ status: 'fulfilled' as const, value: [], timing: 0 });

  const pubmedStart = Date.now();
  const pubmedPromise = config.pubmedCount > 0
    ? (async () => {
        // Emit start event
        if (progressCallback) {
          progressCallback({
            type: 'api_started',
            api: 'pubmed',
            count: config.pubmedCount
          });
        }

        try {
          const results = await withTimeout(
            searchPubMed(englishQuery, config.pubmedCount),
            API_TIMEOUTS.PUBMED,
            'PubMed search'
          );
          const timing = Date.now() - pubmedStart;
          fetchedCount += results.length;
          updateProgress();

          // Emit completion event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'pubmed',
              count: results.length,
              duration: timing,
              success: true
            });
          }

          return { status: 'fulfilled' as const, value: results, timing };
        } catch (error: any) {
          const timing = Date.now() - pubmedStart;
          logger.warn(`⏱️ [PARALLEL-FETCH] PubMed failed/timeout after ${timing}ms`, { error: error.message });

          // Emit failure event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'pubmed',
              count: 0,
              duration: timing,
              success: false
            });
          }

          return { status: 'rejected' as const, reason: error.message, timing };
        }
      })()
    : Promise.resolve({ status: 'fulfilled' as const, value: [], timing: 0 });

  const medrxivStart = Date.now();
  const medrxivPromise = config.medrxivCount > 0
    ? (async () => {
        // Emit start event
        if (progressCallback) {
          progressCallback({
            type: 'api_started',
            api: 'medrxiv',
            count: config.medrxivCount
          });
        }

        try {
          const results = await withTimeout(
            searchMedRxiv(englishQuery, config.medrxivCount, '2023-01-01'),
            API_TIMEOUTS.MEDRXIV,
            'medRxiv search'
          );
          const timing = Date.now() - medrxivStart;
          fetchedCount += results.length;
          updateProgress();

          // Emit completion event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'medrxiv',
              count: results.length,
              duration: timing,
              success: true
            });
          }

          return { status: 'fulfilled' as const, value: results, timing };
        } catch (error: any) {
          const timing = Date.now() - medrxivStart;
          logger.warn(`⏱️ [PARALLEL-FETCH] medRxiv failed/timeout after ${timing}ms`, { error: error.message });

          // Emit failure event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'medrxiv',
              count: 0,
              duration: timing,
              success: false
            });
          }

          return { status: 'rejected' as const, reason: error.message, timing };
        }
      })()
    : Promise.resolve({ status: 'fulfilled' as const, value: [], timing: 0 });

  const trialsStart = Date.now();
  const trialsPromise = config.clinicalTrialsCount > 0
    ? (async () => {
        // Emit start event
        if (progressCallback) {
          progressCallback({
            type: 'api_started',
            api: 'clinicaltrials',
            count: config.clinicalTrialsCount
          });
        }

        try {
          const results = await withTimeout(
            searchClinicalTrials(englishQuery, undefined, 'all', config.clinicalTrialsCount),
            API_TIMEOUTS.CLINICAL_TRIALS,
            'ClinicalTrials search'
          );
          const timing = Date.now() - trialsStart;
          fetchedCount += results.length;
          updateProgress();

          // Emit completion event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'clinicaltrials',
              count: results.length,
              duration: timing,
              success: true
            });
          }

          return { status: 'fulfilled' as const, value: results, timing };
        } catch (error: any) {
          const timing = Date.now() - trialsStart;
          logger.warn(`⏱️ [PARALLEL-FETCH] ClinicalTrials failed/timeout after ${timing}ms`, { error: error.message });

          // Emit failure event
          if (progressCallback) {
            progressCallback({
              type: 'api_completed',
              api: 'clinicaltrials',
              count: 0,
              duration: timing,
              success: false
            });
          }

          return { status: 'rejected' as const, reason: error.message, timing };
        }
      })()
    : Promise.resolve({ status: 'fulfilled' as const, value: [], timing: 0 });

  // Execute all searches in parallel
  const [exaResult, pubmedResult, medrxivResult, trialsResult] = await Promise.all([
    exaPromise,
    pubmedPromise,
    medrxivPromise,
    trialsPromise
  ]);

  const totalTime = Date.now() - startTime;

  // Extract results and errors
  const results: ResearchFetchResults = {
    exa: exaResult.status === 'fulfilled' ? exaResult.value : [],
    pubmed: pubmedResult.status === 'fulfilled' ? pubmedResult.value : [],
    medrxiv: medrxivResult.status === 'fulfilled' ? medrxivResult.value : [],
    clinicalTrials: trialsResult.status === 'fulfilled' ? trialsResult.value : [],
    timings: {
      exa: exaResult.timing,
      pubmed: pubmedResult.timing,
      medrxiv: medrxivResult.timing,
      clinicalTrials: trialsResult.timing,
      total: totalTime
    },
    errors: {}
  };

  // Collect errors if any (already logged above, but store for response metadata)
  if (exaResult.status === 'rejected') {
    results.errors.exa = exaResult.reason;
  }
  if (pubmedResult.status === 'rejected') {
    results.errors.pubmed = pubmedResult.reason;
  }
  if (medrxivResult.status === 'rejected') {
    results.errors.medrxiv = medrxivResult.reason;
  }
  if (trialsResult.status === 'rejected') {
    results.errors.clinicalTrials = trialsResult.reason;
  }

  // Log summary with graceful degradation info
  const totalSources = results.exa.length + results.pubmed.length + results.medrxiv.length + results.clinicalTrials.length;
  const requestedSources = config.exaCount + config.pubmedCount + config.medrxivCount + config.clinicalTrialsCount;
  const errorCount = Object.keys(results.errors).length;

  if (errorCount === 0) {
    logger.info(
      `✅ [PARALLEL-FETCH] All APIs succeeded! Retrieved ${totalSources}/${requestedSources} sources in ${totalTime}ms ` +
      `(Exa: ${results.exa.length}, PubMed: ${results.pubmed.length}, ` +
      `medRxiv: ${results.medrxiv.length}, Trials: ${results.clinicalTrials.length})`
    );
  } else {
    logger.warn(
      `⚠️ [PARALLEL-FETCH] Graceful degradation: ${errorCount} API(s) failed, continuing with partial results. ` +
      `Retrieved ${totalSources}/${requestedSources} sources in ${totalTime}ms ` +
      `(Exa: ${results.exa.length}, PubMed: ${results.pubmed.length}, ` +
      `medRxiv: ${results.medrxiv.length}, Trials: ${results.clinicalTrials.length})`,
      { errors: results.errors }
    );
  }

  logger.debug(
    `⏱️ [PARALLEL-FETCH] API timings: ` +
    `Exa: ${results.timings.exa}ms, PubMed: ${results.timings.pubmed}ms, ` +
    `medRxiv: ${results.timings.medrxiv}ms, Trials: ${results.timings.clinicalTrials}ms`
  );

  // Warn if we got significantly fewer sources than requested (50% threshold)
  if (totalSources < requestedSources * 0.5) {
    logger.warn(
      `⚠️ [PARALLEL-FETCH] Low source retrieval rate: ` +
      `${((totalSources / requestedSources) * 100).toFixed(0)}% ` +
      `(${totalSources}/${requestedSources}). User may receive degraded results.`
    );
  }

  return results;
}

/**
 * Preset configurations for T2 and T3 tiers
 */
export const TIER_CONFIGS = {
  /**
   * T2 Hybrid Research: 10 total sources
   * 5 Exa (trusted medical sites) + 5 dynamic API (PubMed/medRxiv/Trials)
   */
  T2: (pubmedCount: number, medrxivCount: number, clinicalTrialsCount: number): ResearchFetchConfig => ({
    exaCount: 5,
    pubmedCount,
    medrxivCount,
    clinicalTrialsCount
  }),

  /**
   * T3 Deep Research: 25 total sources
   * 10 Exa (trusted medical sites) + 15 dynamic API (PubMed/medRxiv/Trials)
   */
  T3: (pubmedCount: number, medrxivCount: number, clinicalTrialsCount: number): ResearchFetchConfig => ({
    exaCount: 10,
    pubmedCount,
    medrxivCount,
    clinicalTrialsCount
  })
};

/**
 * Create T2 configuration with dynamic API distribution
 * @param pubmedCount - Number of PubMed articles
 * @param medrxivCount - Number of medRxiv preprints
 * @param clinicalTrialsCount - Number of clinical trials
 * @returns T2 research configuration
 */
export function createT2Config(
  pubmedCount: number,
  medrxivCount: number,
  clinicalTrialsCount: number
): ResearchFetchConfig {
  // Validate total API sources = 5
  const apiTotal = pubmedCount + medrxivCount + clinicalTrialsCount;
  if (apiTotal !== 5) {
    console.warn(
      `⚠️ [CONFIG] T2 API sources should sum to 5, got ${apiTotal}. ` +
      `Adjusting to maintain total of 10 sources.`
    );
  }

  return TIER_CONFIGS.T2(pubmedCount, medrxivCount, clinicalTrialsCount);
}

/**
 * Create T3 configuration with dynamic API distribution
 * @param pubmedCount - Number of PubMed articles
 * @param medrxivCount - Number of medRxiv preprints
 * @param clinicalTrialsCount - Number of clinical trials
 * @returns T3 research configuration
 */
export function createT3Config(
  pubmedCount: number,
  medrxivCount: number,
  clinicalTrialsCount: number
): ResearchFetchConfig {
  // Validate total API sources = 15
  const apiTotal = pubmedCount + medrxivCount + clinicalTrialsCount;
  if (apiTotal !== 15) {
    console.warn(
      `⚠️ [CONFIG] T3 API sources should sum to 15, got ${apiTotal}. ` +
      `Adjusting to maintain total of 25 sources.`
    );
  }

  return TIER_CONFIGS.T3(pubmedCount, medrxivCount, clinicalTrialsCount);
}
