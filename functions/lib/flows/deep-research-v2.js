"use strict";
/**
 * Deep Research V2 - Multi-Round Research with Latents Planning and Reflection
 *
 * COMPLETE FLOW:
 * 1. Planning Phase (Latents) → ResearchPlan
 * 2. Round 1: Initial Fetch → Sources
 * 3. Reflection Phase (Latents) → ResearchReflection
 * 4. Decision: Continue or Synthesize?
 * 5. Rounds 2-4: Refined Fetches (if needed)
 * 6. Final Synthesis
 *
 * iOS APP expects these SSE events (DO NOT CHANGE):
 * - planning_started, planning_complete
 * - round_started, round_complete
 * - api_started, api_completed, source_found
 * - reflection_started, reflection_complete
 * - synthesis_started, answer_complete
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.executeDeepResearchV2 = executeDeepResearchV2;
exports.formatResearchForSynthesis = formatResearchForSynthesis;
const v2_1 = require("firebase-functions/v2");
// Planning and reflection
const latents_planner_1 = require("../tools/latents-planner");
const latents_reflector_1 = require("../tools/latents-reflector");
// Query refinement
const query_refiner_1 = require("../tools/query-refiner");
// Source deduplication
const source_deduplicator_1 = require("../tools/source-deduplicator");
// Source ranking
const source_ranker_1 = require("../tools/source-ranker");
// Source selection
const source_selector_1 = require("../tools/source-selector");
// Stopping conditions
const stopping_condition_evaluator_1 = require("../tools/stopping-condition-evaluator");
// Research fetching
const query_analyzer_1 = require("../tools/query-analyzer");
const parallel_research_fetcher_1 = require("../tools/parallel-research-fetcher");
// Source formatting
const exa_search_1 = require("../tools/exa-search");
const pubmed_search_1 = require("../tools/pubmed-search");
const medrxiv_search_1 = require("../tools/medrxiv-search");
const clinical_trials_1 = require("../tools/clinical-trials");
/**
 * Helper to emit SSE events
 */
function emitSSE(res, event) {
    const data = `data: ${JSON.stringify(event)}\n\n`;
    res.write(data);
}
/**
 * Convert fetched sources to SourceResponse format for iOS app
 */
function formatSourcesForIOS(uniqueSources) {
    const formatted = [];
    // Format Exa sources
    for (const source of uniqueSources.exa) {
        formatted.push({
            id: source.id || source.url,
            url: source.url,
            domain: source.domain || new URL(source.url).hostname,
            title: source.title,
            snippet: source.text || source.snippet || '',
            publishDate: source.publishedDate || source.published_date || null,
            author: source.author || null,
            credibilityBadge: 'credible', // Exa sources are generally credible
            type: 'medical_source'
        });
    }
    // Format PubMed sources
    for (const source of uniqueSources.pubmed) {
        formatted.push({
            id: source.pmid,
            url: `https://pubmed.ncbi.nlm.nih.gov/${source.pmid}/`,
            domain: 'pubmed.ncbi.nlm.nih.gov',
            title: source.title,
            snippet: source.abstract || '',
            publishDate: source.pubdate || null,
            author: source.authors?.[0] || null,
            credibilityBadge: 'highly_credible',
            type: 'pubmed'
        });
    }
    // Format medRxiv sources
    for (const source of uniqueSources.medrxiv) {
        formatted.push({
            id: source.doi,
            url: source.url,
            domain: 'medrxiv.org',
            title: source.title,
            snippet: source.abstract || '',
            publishDate: source.date || null,
            author: source.authors?.split(',')[0] || null,
            credibilityBadge: 'credible',
            type: 'medrxiv'
        });
    }
    // Format Clinical Trial sources
    for (const source of uniqueSources.clinicalTrials) {
        formatted.push({
            id: source.nctId,
            url: `https://clinicaltrials.gov/study/${source.nctId}`,
            domain: 'clinicaltrials.gov',
            title: source.title,
            snippet: source.description || '',
            publishDate: source.startDate || null,
            author: source.sponsor || null,
            credibilityBadge: 'highly_credible',
            type: 'clinical_trial'
        });
    }
    return formatted;
}
/**
 * Execute multi-round deep research with Latents planning and reflection
 *
 * @param question - User's research query
 * @param res - Express response object for SSE streaming
 * @returns DeepResearchResults with all rounds and sources
 */
async function executeDeepResearchV2(question, res) {
    const overallStartTime = Date.now();
    v2_1.logger.info(`🔬 [DEEP-RESEARCH-V2] Starting multi-round research for: "${question.substring(0, 100)}..."`);
    // ===== PHASE 1: PLANNING (Latents) =====
    emitSSE(res, {
        type: 'planning_started',
        message: 'Araştırma stratejisi planlanıyor...',
        sequence: 0
    });
    const plan = await (0, latents_planner_1.planResearchStrategy)(question);
    emitSSE(res, {
        type: 'planning_complete',
        plan,
        sequence: 1
    });
    v2_1.logger.info(`📋 [DEEP-RESEARCH-V2] Plan: ${plan.estimatedRounds} rounds, ` +
        `strategy="${plan.strategy}", focus=[${plan.focusAreas.join(', ')}]`);
    // ===== PHASE 2: MULTI-ROUND RESEARCH =====
    const maxRounds = Math.min(plan.estimatedRounds, 4); // Hard cap at 4
    const rounds = [];
    const deduplicator = new source_deduplicator_1.SourceDeduplicator();
    let currentQuery = question;
    let shouldContinue = true;
    for (let roundNum = 1; roundNum <= maxRounds && shouldContinue; roundNum++) {
        const roundStartTime = Date.now();
        v2_1.logger.info(`🔄 [DEEP-RESEARCH-V2] Starting Round ${roundNum}/${maxRounds}`);
        // ===== FIX: Correct source count calculation =====
        // Round 1: 25 total sources (10 Exa + 15 Academic APIs)
        // Rounds 2-4: 15 total sources (5 Exa + 10 Academic APIs)
        const exaCount = roundNum === 1 ? 10 : 5;
        const apiSourceCount = roundNum === 1 ? 15 : 10; // FIXED: Was 25/15, now 15/10
        const totalSourceCount = exaCount + apiSourceCount;
        emitSSE(res, {
            type: 'round_started',
            round: roundNum,
            query: currentQuery,
            estimatedSources: totalSourceCount, // Report accurate total including Exa
            sequence: roundNum * 10
        });
        // ===== STEP 1: Query Analysis (determine Academic API source distribution) =====
        const queryAnalysis = await (0, query_analyzer_1.analyzeQuery)(currentQuery, apiSourceCount);
        const sourceCounts = (0, query_analyzer_1.calculateSourceCounts)(queryAnalysis, apiSourceCount);
        v2_1.logger.debug(`📊 [DEEP-RESEARCH-V2] Round ${roundNum} distribution: ` +
            `Exa=${exaCount}, PubMed=${sourceCounts.pubmedCount}, ` +
            `medRxiv=${sourceCounts.medrxivCount}, Trials=${sourceCounts.clinicalTrialsCount}`);
        // ===== STEP 2: Create Config (explicit Exa count) =====
        const config = {
            exaCount: exaCount,
            pubmedCount: sourceCounts.pubmedCount,
            medrxivCount: sourceCounts.medrxivCount,
            clinicalTrialsCount: sourceCounts.clinicalTrialsCount
        };
        // Validate total matches expectation
        const actualTotal = config.exaCount + config.pubmedCount + config.medrxivCount + config.clinicalTrialsCount;
        if (actualTotal !== totalSourceCount) {
            v2_1.logger.warn(`⚠️ [DEEP-RESEARCH-V2] Source count mismatch in Round ${roundNum}: ` +
                `expected ${totalSourceCount}, got ${actualTotal}`);
        }
        v2_1.logger.info(`📊 [DEEP-RESEARCH-V2] Round ${roundNum} requesting ${actualTotal} sources: ` +
            `Exa=${config.exaCount}, PubMed=${config.pubmedCount}, ` +
            `medRxiv=${config.medrxivCount}, Trials=${config.clinicalTrialsCount}`);
        // ===== STEP 3: Fetch Sources (parallel with progress tracking) =====
        // Progress callback for SSE events
        const progressCallback = (event) => {
            if (event.type === 'api_started') {
                // Include the actual query string in the message for debugging
                const queryPreview = event.query ? ` [Query: ${event.query.substring(0, 50)}...]` : '';
                const messages = {
                    pubmed: `PubMed'den ${event.count} makale aranıyor...${queryPreview}`,
                    medrxiv: `medRxiv'den ${event.count} önbaskı çalışma kontrol ediliyor...${queryPreview}`,
                    clinicaltrials: `Klinik denemeler inceleniyor (${event.count} deneme)...${queryPreview}`,
                    exa: `Güvenilir tıbbi siteler taranıyor (${event.count} kaynak)...${queryPreview}`
                };
                emitSSE(res, {
                    type: 'api_started',
                    api: event.api,
                    count: event.count,
                    message: messages[event.api] || `${event.api} aranıyor...${queryPreview}`,
                    query: event.query // Pass full query in dedicated field
                });
            }
            else if (event.type === 'api_completed') {
                const messages = {
                    pubmed: (count, duration, success) => success
                        ? `PubMed: ${count} makale ✓ (${(duration / 1000).toFixed(1)}s)`
                        : `PubMed: sonuç alınamadı`,
                    medrxiv: (count, duration, success) => success
                        ? `medRxiv: ${count} önbaskı ✓ (${(duration / 1000).toFixed(1)}s)`
                        : `medRxiv: sonuç alınamadı`,
                    clinicaltrials: (count, duration, success) => success
                        ? `Trials: ${count} deneme ✓ (${(duration / 1000).toFixed(1)}s)`
                        : `Trials: sonuç alınamadı`,
                    exa: (count, duration, success) => success
                        ? `Exa: ${count} kaynak ✓ (${(duration / 1000).toFixed(1)}s)`
                        : `Exa: sonuç alınamadı`
                };
                emitSSE(res, {
                    type: 'api_completed',
                    api: event.api,
                    count: event.count,
                    duration: event.duration,
                    message: messages[event.api](event.count, event.duration, event.success),
                    success: event.success
                });
            }
        };
        const fetchResults = await (0, parallel_research_fetcher_1.fetchAllResearchSources)(currentQuery, config, progressCallback);
        // ===== STEP 3: Deduplicate Sources =====
        const uniqueSources = {
            exa: deduplicator.filterExa(fetchResults.exa),
            pubmed: deduplicator.filterPubMed(fetchResults.pubmed),
            medrxiv: deduplicator.filterMedRxiv(fetchResults.medrxiv),
            clinicalTrials: deduplicator.filterClinicalTrials(fetchResults.clinicalTrials)
        };
        const roundSourceCount = uniqueSources.exa.length +
            uniqueSources.pubmed.length +
            uniqueSources.medrxiv.length +
            uniqueSources.clinicalTrials.length;
        // Emit source_found events for key sources
        for (const article of uniqueSources.pubmed.slice(0, 3)) {
            emitSSE(res, {
                type: 'source_found',
                title: article.title,
                sourceType: 'PubMed'
            });
        }
        const roundDuration = Date.now() - roundStartTime;
        const roundResult = {
            roundNumber: roundNum,
            sources: uniqueSources,
            sourceCount: roundSourceCount,
            duration: roundDuration
        };
        rounds.push(roundResult);
        // Format sources for iOS app
        const formattedSources = formatSourcesForIOS(uniqueSources);
        emitSSE(res, {
            type: 'round_complete',
            round: roundNum,
            sourceCount: roundSourceCount,
            duration: roundDuration,
            sources: formattedSources, // Pass actual sources to iOS
            status: 'complete',
            sequence: roundNum * 10 + 5
        });
        v2_1.logger.info(`✅ [DEEP-RESEARCH-V2] Round ${roundNum} complete: ` +
            `${roundSourceCount} unique sources in ${roundDuration}ms`);
        // ===== STEP 4: REFLECTION (if not final round) =====
        if ((0, stopping_condition_evaluator_1.shouldDoReflection)(roundNum, maxRounds)) {
            emitSSE(res, {
                type: 'reflection_started',
                round: roundNum,
                sequence: roundNum * 10 + 6
            });
            const reflection = await (0, latents_reflector_1.reflectOnResearchQuality)(question, roundNum, roundResult, rounds.slice(0, -1), // All previous rounds
            maxRounds);
            roundResult.reflection = reflection;
            emitSSE(res, {
                type: 'reflection_complete',
                round: roundNum,
                reflection,
                sequence: roundNum * 10 + 7
            });
            v2_1.logger.info(`🧠 [DEEP-RESEARCH-V2] Reflection: quality=${reflection.evidenceQuality}, ` +
                `continue=${reflection.shouldContinue}, gaps=${reflection.gapsIdentified.length}`);
            // ===== STEP 5: STOPPING CONDITION EVALUATION =====
            const stoppingDecision = (0, stopping_condition_evaluator_1.evaluateStoppingConditions)(roundNum, maxRounds, roundResult, rounds, reflection);
            if (stoppingDecision.shouldStop) {
                v2_1.logger.info(`🛑 [DEEP-RESEARCH-V2] Stopping: ${stoppingDecision.reason}`);
                shouldContinue = false;
            }
            else {
                // ===== STEP 6: QUERY REFINEMENT for next round =====
                if (reflection.gapsIdentified.length > 0 && roundNum < maxRounds) {
                    const refinedQuery = await (0, query_refiner_1.refineQueryForGaps)(question, reflection.gapsIdentified, roundNum + 1);
                    currentQuery = refinedQuery.refined;
                    v2_1.logger.info(`🔄 [DEEP-RESEARCH-V2] Query refined for Round ${roundNum + 1}: ` +
                        `"${currentQuery.substring(0, 80)}..." (focus: ${refinedQuery.focusArea})`);
                }
            }
        }
        else {
            // Final round - no reflection needed
            v2_1.logger.info(`🏁 [DEEP-RESEARCH-V2] Final round ${roundNum} - skipping reflection`);
            shouldContinue = false;
        }
    }
    // ===== PHASE 3: AGGREGATE RESULTS =====
    const totalDuration = Date.now() - overallStartTime;
    // Combine all sources
    const allSources = {
        exa: rounds.flatMap(r => r.sources.exa),
        pubmed: rounds.flatMap(r => r.sources.pubmed),
        medrxiv: rounds.flatMap(r => r.sources.medrxiv),
        clinicalTrials: rounds.flatMap(r => r.sources.clinicalTrials)
    };
    const totalSources = allSources.exa.length +
        allSources.pubmed.length +
        allSources.medrxiv.length +
        allSources.clinicalTrials.length;
    // Log deduplication summary
    deduplicator.logSummary();
    // ===== PHASE 3.5: AI-POWERED SOURCE RELEVANCE RANKING =====
    v2_1.logger.info(`🎯 [DEEP-RESEARCH-V2] Ranking ${totalSources} sources by relevance...`);
    // NEW: Emit source selection started event for user-friendly stage display
    emitSSE(res, {
        type: 'source_selection_started',
        message: 'En ilgili kaynakları seçiyorum',
        sequence: 200
    });
    // Rank all sources by relevance to original query
    const rankingResult = await (0, source_ranker_1.rankSourcesByRelevance)(question, // Original query for best relevance
    allSources, {
        topN: 30 // Top 30 most relevant sources
    });
    // Reorder sources by relevance (highest score first)
    const rankedSources = (0, source_ranker_1.reorderSourcesByRanking)(allSources, rankingResult);
    v2_1.logger.info(`✅ [DEEP-RESEARCH-V2] Ranking complete: avg relevance=${rankingResult.averageRelevance.toFixed(1)}, ` +
        `top score=${rankingResult.topSources[0]?.relevanceScore || 0}, ` +
        `duration=${rankingResult.rankingDuration}ms`);
    // ===== PHASE 3.6: INTELLIGENT SOURCE SELECTION (TOP-P STRATEGY) =====
    v2_1.logger.info(`🎯 [DEEP-RESEARCH-V2] Selecting best sources for synthesis...`);
    // Select top sources using intelligent top-P strategy
    const selectionResult = await (0, source_selector_1.selectSourcesForSynthesis)(rankingResult.rankedSources, // Use ranked sources with scores
    {
        baseLimit: 25, // Start with top 25
        extendedLimit: 30, // Extend to 30 if many high-quality sources
        highQualityThreshold: 70, // Threshold for extension
        tokenBudget: 16800, // Maximum tokens for synthesis
        minRelevanceScore: 40, // Minimum score to include
        semanticSimilarityThreshold: 0.85, // Similarity threshold for dedup
        enableSemanticDedup: true // Enable near-duplicate removal
    });
    v2_1.logger.info(`✅ [DEEP-RESEARCH-V2] Selection complete: ${selectionResult.selectedCount}/${totalSources} sources, ` +
        `${selectionResult.deduplicatedCount} duplicates removed, ` +
        `${selectionResult.totalTokens} tokens, ` +
        `strategy: ${selectionResult.selectionStrategy}`);
    // NEW: Emit synthesis preparation event for user-friendly stage display
    emitSSE(res, {
        type: 'synthesis_preparation',
        message: 'Bilgileri bir araya getiriyorum',
        sequence: 210
    });
    const results = {
        plan,
        rounds,
        totalSources,
        totalDuration,
        allSources: rankedSources, // Keep all ranked sources for reference
        rankingMetadata: {
            averageRelevance: rankingResult.averageRelevance,
            topSourceScore: rankingResult.topSources[0]?.relevanceScore || 0,
            rankingDuration: rankingResult.rankingDuration
        },
        selectionMetadata: {
            selectedCount: selectionResult.selectedCount,
            deduplicatedCount: selectionResult.deduplicatedCount,
            totalTokens: selectionResult.totalTokens,
            selectionStrategy: selectionResult.selectionStrategy,
            qualityMetrics: selectionResult.qualityMetrics
        },
        selectedSources: selectionResult.selectedSources // Selected sources for synthesis
    };
    // Calculate completeness score
    const lastReflection = rounds[rounds.length - 1]?.reflection || {
        evidenceQuality: 'medium',
        gapsIdentified: [],
        shouldContinue: false,
        reasoning: 'No reflection performed'
    };
    const completenessScore = (0, stopping_condition_evaluator_1.calculateCompletenessScore)(rounds, lastReflection);
    v2_1.logger.info(`✅ [DEEP-RESEARCH-V2] Research complete: ${rounds.length} rounds, ` +
        `${totalSources} sources, ${(totalDuration / 1000).toFixed(1)}s, ` +
        `completeness=${(completenessScore * 100).toFixed(0)}%`);
    return results;
}
/**
 * Format research results for AI synthesis
 * Uses selected sources if available, otherwise uses all sources
 */
function formatResearchForSynthesis(results) {
    // If we have selected sources, use them (optimized for synthesis)
    if (results.selectedSources && results.selectedSources.length > 0) {
        let context = `# DEEP RESEARCH V2 FINDINGS\n\n`;
        context += `## Research Overview\n`;
        context += `- Rounds completed: ${results.rounds.length}/${results.plan.estimatedRounds}\n`;
        context += `- Strategy: ${results.plan.strategy}\n`;
        context += `- Focus areas: ${results.plan.focusAreas.join(', ')}\n`;
        context += `- Total sources found: ${results.totalSources}\n`;
        context += `- Selected for synthesis: ${results.selectedSources.length} (${results.selectionMetadata?.selectionStrategy || 'top sources'})\n`;
        context += `- Average relevance: ${results.selectionMetadata?.qualityMetrics.averageRelevance.toFixed(1) || 'N/A'}/100\n\n`;
        // Use formatted selected sources
        context += (0, source_selector_1.formatSelectedSourcesForSynthesis)(results.selectedSources);
        return context;
    }
    // Fallback: Use all sources (legacy behavior)
    let context = `# DEEP RESEARCH V2 FINDINGS (${results.totalSources} sources, ${results.rounds.length} rounds)\n\n`;
    context += `## Research Strategy\n`;
    context += `- Rounds completed: ${results.rounds.length}/${results.plan.estimatedRounds}\n`;
    context += `- Strategy: ${results.plan.strategy}\n`;
    context += `- Focus areas: ${results.plan.focusAreas.join(', ')}\n\n`;
    // Add sources by type
    if (results.allSources.exa.length > 0) {
        context += (0, exa_search_1.formatExaForAI)(results.allSources.exa, true) + '\n\n';
    }
    if (results.allSources.pubmed.length > 0) {
        context += (0, pubmed_search_1.formatPubMedForAI)(results.allSources.pubmed) + '\n\n';
    }
    if (results.allSources.medrxiv.length > 0) {
        context += '📄 Recent Medical Preprints (medRxiv - Cutting-Edge Research):\n\n';
        context += (0, medrxiv_search_1.formatMedRxivForAI)(results.allSources.medrxiv) + '\n\n';
    }
    if (results.allSources.clinicalTrials.length > 0) {
        context += (0, clinical_trials_1.formatClinicalTrialsForAI)(results.allSources.clinicalTrials) + '\n\n';
    }
    return context;
}
//# sourceMappingURL=deep-research-v2.js.map