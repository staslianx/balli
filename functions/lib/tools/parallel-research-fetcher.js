"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.TIER_CONFIGS = void 0;
exports.fetchAllResearchSources = fetchAllResearchSources;
exports.createT2Config = createT2Config;
exports.createT3Config = createT3Config;
const exa_search_1 = require("./exa-search");
const pubmed_search_1 = require("./pubmed-search");
const medrxiv_search_1 = require("./medrxiv-search");
const clinical_trials_1 = require("./clinical-trials");
const query_translator_1 = require("./query-translator");
const v2_1 = require("firebase-functions/v2");
/**
 * API timeout configurations (in milliseconds)
 * CRITICAL: Academic APIs (PubMed, medRxiv, ClinicalTrials) need longer timeouts
 * because they:
 * 1. Search through millions of papers
 * 2. Run on government/academic infrastructure (slower than commercial)
 * 3. Have rate limiting and anti-bot measures
 * 4. Need to fetch metadata for multiple results
 *
 * For T3 Deep Research requesting 8-10 sources per API, we need:
 * - PubMed: 10-15s (NIH servers, complex queries, multiple result fetches)
 * - medRxiv: 8-10s (Preprint server, slower than production APIs)
 * - ClinicalTrials: 10-12s (Government database, complex trial metadata)
 * - Exa: 10s (Commercial API, fast and reliable)
 */
const API_TIMEOUTS = {
    PUBMED: 15000, // 15 seconds for PubMed (was 3s - too short!)
    MEDRXIV: 10000, // 10 seconds for medRxiv (was 3s - too short!)
    CLINICAL_TRIALS: 12000, // 12 seconds for ClinicalTrials.gov (was 3s - too short!)
    EXA: 10000 // 10 seconds for Exa (paid API, more reliable)
};
/**
 * Wrap promise with timeout
 * Returns rejected promise if operation exceeds timeout
 */
function withTimeout(promise, timeoutMs, operationName) {
    return Promise.race([
        promise,
        new Promise((_, reject) => setTimeout(() => reject(new Error(`${operationName} timeout after ${timeoutMs}ms`)), timeoutMs))
    ]);
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
async function fetchAllResearchSources(query, config, progressCallback) {
    const startTime = Date.now();
    console.log(`🔬 [PARALLEL-FETCH] Fetching ${config.exaCount + config.pubmedCount + config.medrxivCount + config.clinicalTrialsCount} sources in parallel`);
    console.log(`📊 [PARALLEL-FETCH] Distribution: Exa: ${config.exaCount}, PubMed: ${config.pubmedCount}, ` +
        `medRxiv: ${config.medrxivCount}, Trials: ${config.clinicalTrialsCount}`);
    console.log(`📝 [PARALLEL-FETCH] Original query: "${query.substring(0, 80)}..."`);
    // Translate Turkish queries to English for academic APIs (PubMed, medRxiv, ClinicalTrials)
    // Exa works fine with Turkish, so we keep the original query for it
    const englishQuery = await (0, query_translator_1.translateToEnglishForAPIs)(query);
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
                const results = await withTimeout((0, exa_search_1.searchMedicalSources)(query, config.exaCount), API_TIMEOUTS.EXA, 'Exa search');
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
                return { status: 'fulfilled', value: results, timing };
            }
            catch (error) {
                const timing = Date.now() - exaStart;
                v2_1.logger.warn(`⏱️ [PARALLEL-FETCH] Exa failed/timeout after ${timing}ms`, { error: error.message });
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
                return { status: 'rejected', reason: error.message, timing };
            }
        })()
        : Promise.resolve({ status: 'fulfilled', value: [], timing: 0 });
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
                const results = await withTimeout((0, pubmed_search_1.searchPubMed)(englishQuery, config.pubmedCount), API_TIMEOUTS.PUBMED, 'PubMed search');
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
                return { status: 'fulfilled', value: results, timing };
            }
            catch (error) {
                const timing = Date.now() - pubmedStart;
                v2_1.logger.warn(`⏱️ [PARALLEL-FETCH] PubMed failed/timeout after ${timing}ms`, { error: error.message });
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
                return { status: 'rejected', reason: error.message, timing };
            }
        })()
        : Promise.resolve({ status: 'fulfilled', value: [], timing: 0 });
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
                const results = await withTimeout((0, medrxiv_search_1.searchMedRxiv)(englishQuery, config.medrxivCount, '2023-01-01'), API_TIMEOUTS.MEDRXIV, 'medRxiv search');
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
                return { status: 'fulfilled', value: results, timing };
            }
            catch (error) {
                const timing = Date.now() - medrxivStart;
                v2_1.logger.warn(`⏱️ [PARALLEL-FETCH] medRxiv failed/timeout after ${timing}ms`, { error: error.message });
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
                return { status: 'rejected', reason: error.message, timing };
            }
        })()
        : Promise.resolve({ status: 'fulfilled', value: [], timing: 0 });
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
                const results = await withTimeout((0, clinical_trials_1.searchClinicalTrials)(englishQuery, undefined, 'all', config.clinicalTrialsCount), API_TIMEOUTS.CLINICAL_TRIALS, 'ClinicalTrials search');
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
                return { status: 'fulfilled', value: results, timing };
            }
            catch (error) {
                const timing = Date.now() - trialsStart;
                v2_1.logger.warn(`⏱️ [PARALLEL-FETCH] ClinicalTrials failed/timeout after ${timing}ms`, { error: error.message });
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
                return { status: 'rejected', reason: error.message, timing };
            }
        })()
        : Promise.resolve({ status: 'fulfilled', value: [], timing: 0 });
    // Execute all searches in parallel
    const [exaResult, pubmedResult, medrxivResult, trialsResult] = await Promise.all([
        exaPromise,
        pubmedPromise,
        medrxivPromise,
        trialsPromise
    ]);
    const totalTime = Date.now() - startTime;
    // Extract results and errors
    const results = {
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
        v2_1.logger.info(`✅ [PARALLEL-FETCH] All APIs succeeded! Retrieved ${totalSources}/${requestedSources} sources in ${totalTime}ms ` +
            `(Exa: ${results.exa.length}, PubMed: ${results.pubmed.length}, ` +
            `medRxiv: ${results.medrxiv.length}, Trials: ${results.clinicalTrials.length})`);
    }
    else {
        v2_1.logger.warn(`⚠️ [PARALLEL-FETCH] Graceful degradation: ${errorCount} API(s) failed, continuing with partial results. ` +
            `Retrieved ${totalSources}/${requestedSources} sources in ${totalTime}ms ` +
            `(Exa: ${results.exa.length}, PubMed: ${results.pubmed.length}, ` +
            `medRxiv: ${results.medrxiv.length}, Trials: ${results.clinicalTrials.length})`, { errors: results.errors });
    }
    v2_1.logger.debug(`⏱️ [PARALLEL-FETCH] API timings: ` +
        `Exa: ${results.timings.exa}ms, PubMed: ${results.timings.pubmed}ms, ` +
        `medRxiv: ${results.timings.medrxiv}ms, Trials: ${results.timings.clinicalTrials}ms`);
    // Warn if we got significantly fewer sources than requested (50% threshold)
    if (totalSources < requestedSources * 0.5) {
        v2_1.logger.warn(`⚠️ [PARALLEL-FETCH] Low source retrieval rate: ` +
            `${((totalSources / requestedSources) * 100).toFixed(0)}% ` +
            `(${totalSources}/${requestedSources}). User may receive degraded results.`);
    }
    return results;
}
/**
 * Preset configurations for T2 and T3 tiers
 */
exports.TIER_CONFIGS = {
    /**
     * T2 Hybrid Research: 10 total sources
     * 5 Exa (trusted medical sites) + 5 dynamic API (PubMed/medRxiv/Trials)
     */
    T2: (pubmedCount, medrxivCount, clinicalTrialsCount) => ({
        exaCount: 5,
        pubmedCount,
        medrxivCount,
        clinicalTrialsCount
    }),
    /**
     * T3 Deep Research: 25 total sources
     * 10 Exa (trusted medical sites) + 15 dynamic API (PubMed/medRxiv/Trials)
     */
    T3: (pubmedCount, medrxivCount, clinicalTrialsCount) => ({
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
function createT2Config(pubmedCount, medrxivCount, clinicalTrialsCount) {
    // Validate total API sources = 5
    const apiTotal = pubmedCount + medrxivCount + clinicalTrialsCount;
    if (apiTotal !== 5) {
        console.warn(`⚠️ [CONFIG] T2 API sources should sum to 5, got ${apiTotal}. ` +
            `Adjusting to maintain total of 10 sources.`);
    }
    return exports.TIER_CONFIGS.T2(pubmedCount, medrxivCount, clinicalTrialsCount);
}
/**
 * Create T3 configuration with dynamic API distribution
 * @param pubmedCount - Number of PubMed articles
 * @param medrxivCount - Number of medRxiv preprints
 * @param clinicalTrialsCount - Number of clinical trials
 * @returns T3 research configuration
 *
 * NOTE: This function is DEPRECATED. Prefer constructing ResearchFetchConfig directly
 * with explicit exaCount to avoid confusion about source count expectations.
 *
 * IMPORTANT: API sources (pubmedCount + medrxivCount + clinicalTrialsCount) should sum to 15,
 * NOT 25. The function adds 10 Exa sources automatically.
 */
function createT3Config(pubmedCount, medrxivCount, clinicalTrialsCount) {
    // Validate total API sources = 15 (Exa sources are added separately)
    const apiTotal = pubmedCount + medrxivCount + clinicalTrialsCount;
    if (apiTotal !== 15) {
        v2_1.logger.error(`❌ [CONFIG] T3 API sources MUST sum to 15, got ${apiTotal}. ` +
            `T3 config adds 10 Exa sources automatically for 25 total. ` +
            `Received: PubMed=${pubmedCount}, medRxiv=${medrxivCount}, Trials=${clinicalTrialsCount}`);
        // Scale down proportionally to fit 15 sources
        const scale = 15 / apiTotal;
        const adjustedPubmed = Math.round(pubmedCount * scale);
        const adjustedMedrxiv = Math.round(medrxivCount * scale);
        const adjustedTrials = 15 - adjustedPubmed - adjustedMedrxiv; // Ensure exact sum
        v2_1.logger.warn(`⚠️ [CONFIG] Auto-adjusting API sources to sum to 15: ` +
            `PubMed=${adjustedPubmed}, medRxiv=${adjustedMedrxiv}, Trials=${adjustedTrials}`);
        return exports.TIER_CONFIGS.T3(adjustedPubmed, adjustedMedrxiv, adjustedTrials);
    }
    return exports.TIER_CONFIGS.T3(pubmedCount, medrxivCount, clinicalTrialsCount);
}
//# sourceMappingURL=parallel-research-fetcher.js.map