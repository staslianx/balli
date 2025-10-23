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

import { Response } from 'express';
import { logger } from 'firebase-functions/v2';

// Planning and reflection
import { planResearchStrategy } from '../tools/latents-planner';
import { reflectOnResearchQuality } from '../tools/latents-reflector';

// Query refinement
import { refineQueryForGaps } from '../tools/query-refiner';

// Source deduplication
import { SourceDeduplicator } from '../tools/source-deduplicator';

// Source ranking
import { rankSourcesByRelevance, reorderSourcesByRanking } from '../tools/source-ranker';

// Source selection
import { selectSourcesForSynthesis, formatSelectedSourcesForSynthesis } from '../tools/source-selector';

// Stopping conditions
import {
  evaluateStoppingConditions,
  shouldDoReflection,
  calculateCompletenessScore
} from '../tools/stopping-condition-evaluator';

// Research fetching
import { analyzeQuery, calculateSourceCounts } from '../tools/query-analyzer';
import {
  fetchAllResearchSources,
  createT3Config,
  ProgressCallback,
  ResearchFetchConfig
} from '../tools/parallel-research-fetcher';

// Source formatting
import { formatExaForAI } from '../tools/exa-search';
import { formatPubMedForAI } from '../tools/pubmed-search';
import { formatMedRxivForAI } from '../tools/medrxiv-search';
import { formatClinicalTrialsForAI } from '../tools/clinical-trials';

// Types
import {
  ResearchPlan,
  ResearchReflection,
  RoundResult,
  DeepResearchResults
} from './deep-research-v2-types';

/**
 * SSE Event Types (iOS app expects these)
 */
type SSEEvent =
  | { type: 'planning_started'; message: string; sequence: number }
  | { type: 'planning_complete'; plan: ResearchPlan; sequence: number }
  | { type: 'round_started'; round: number; query: string; estimatedSources: number; sequence: number }
  | { type: 'round_complete'; round: number; sourceCount: number; duration: number; sources: any[]; status: string; sequence: number }
  | { type: 'api_started'; api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa'; count: number; message: string }
  | { type: 'api_completed'; api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa'; count: number; duration: number; message: string; success: boolean }
  | { type: 'source_found'; title: string; sourceType: string }
  | { type: 'reflection_started'; round: number; sequence: number }
  | { type: 'reflection_complete'; round: number; reflection: ResearchReflection; sequence: number }
  | { type: 'source_selection_started'; message: string; sequence: number }  // NEW: Stage 7
  | { type: 'synthesis_preparation'; message: string; sequence: number }     // NEW: Stage 8
  | { type: 'synthesis_started'; totalRounds: number; totalSources: number; sequence: number }
  | { type: 'token'; content: string }
  | { type: 'answer_complete'; metadata: any };

/**
 * Helper to emit SSE events
 */
function emitSSE(res: Response, event: SSEEvent): void {
  const data = `data: ${JSON.stringify(event)}\n\n`;
  res.write(data);
}

/**
 * Convert fetched sources to SourceResponse format for iOS app
 */
function formatSourcesForIOS(uniqueSources: {
  exa: any[];
  pubmed: any[];
  medrxiv: any[];
  clinicalTrials: any[];
}): any[] {
  const formatted: any[] = [];

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
export async function executeDeepResearchV2(
  question: string,
  res: Response
): Promise<DeepResearchResults> {
  const overallStartTime = Date.now();

  logger.info(`🔬 [DEEP-RESEARCH-V2] Starting multi-round research for: "${question.substring(0, 100)}..."`);

  // ===== PHASE 1: PLANNING (Latents) =====
  emitSSE(res, {
    type: 'planning_started',
    message: 'Araştırma stratejisi planlanıyor...',
    sequence: 0
  });

  const plan = await planResearchStrategy(question);

  emitSSE(res, {
    type: 'planning_complete',
    plan,
    sequence: 1
  });

  logger.info(
    `📋 [DEEP-RESEARCH-V2] Plan: ${plan.estimatedRounds} rounds, ` +
    `strategy="${plan.strategy}", focus=[${plan.focusAreas.join(', ')}]`
  );

  // ===== PHASE 2: MULTI-ROUND RESEARCH =====
  const maxRounds = Math.min(plan.estimatedRounds, 4); // Hard cap at 4
  const rounds: RoundResult[] = [];
  const deduplicator = new SourceDeduplicator();

  let currentQuery = question;
  let shouldContinue = true;

  for (let roundNum = 1; roundNum <= maxRounds && shouldContinue; roundNum++) {
    const roundStartTime = Date.now();

    logger.info(`🔄 [DEEP-RESEARCH-V2] Starting Round ${roundNum}/${maxRounds}`);

    // Round 1: 25 sources for broad coverage, Rounds 2-4: 15 sources for focused gap-filling
    const apiSourceCount = roundNum === 1 ? 25 : 15;

    emitSSE(res, {
      type: 'round_started',
      round: roundNum,
      query: currentQuery,
      estimatedSources: apiSourceCount,
      sequence: roundNum * 10
    });

    // ===== STEP 1: Query Analysis (determine source distribution) =====
    const queryAnalysis = await analyzeQuery(currentQuery, apiSourceCount);
    const sourceCounts = calculateSourceCounts(queryAnalysis, apiSourceCount);

    logger.debug(
      `📊 [DEEP-RESEARCH-V2] Round ${roundNum} distribution: ` +
      `PubMed=${sourceCounts.pubmedCount}, medRxiv=${sourceCounts.medrxivCount}, ` +
      `Trials=${sourceCounts.clinicalTrialsCount}`
    );

    // ===== STEP 2: Fetch Sources (parallel with progress tracking) =====
    const config: ResearchFetchConfig = createT3Config(
      sourceCounts.pubmedCount,
      sourceCounts.medrxivCount,
      sourceCounts.clinicalTrialsCount
    );

    // Progress callback for SSE events
    const progressCallback: ProgressCallback = (event) => {
      if (event.type === 'api_started') {
        const messages: Record<string, string> = {
          pubmed: `PubMed'den ${event.count} makale aranıyor...`,
          medrxiv: `medRxiv'den ${event.count} önbaskı çalışma kontrol ediliyor...`,
          clinicaltrials: `Klinik denemeler inceleniyor (${event.count} deneme)...`,
          exa: `Güvenilir tıbbi siteler taranıyor (${event.count} kaynak)...`
        };

        emitSSE(res, {
          type: 'api_started',
          api: event.api!,
          count: event.count!,
          message: messages[event.api!] || `${event.api} aranıyor...`
        });
      } else if (event.type === 'api_completed') {
        const messages: Record<string, (count: number, duration: number, success: boolean) => string> = {
          pubmed: (count, duration, success) =>
            success
              ? `PubMed: ${count} makale ✓ (${(duration / 1000).toFixed(1)}s)`
              : `PubMed: sonuç alınamadı`,
          medrxiv: (count, duration, success) =>
            success
              ? `medRxiv: ${count} önbaskı ✓ (${(duration / 1000).toFixed(1)}s)`
              : `medRxiv: sonuç alınamadı`,
          clinicaltrials: (count, duration, success) =>
            success
              ? `Trials: ${count} deneme ✓ (${(duration / 1000).toFixed(1)}s)`
              : `Trials: sonuç alınamadı`,
          exa: (count, duration, success) =>
            success
              ? `Exa: ${count} kaynak ✓ (${(duration / 1000).toFixed(1)}s)`
              : `Exa: sonuç alınamadı`
        };

        emitSSE(res, {
          type: 'api_completed',
          api: event.api!,
          count: event.count!,
          duration: event.duration!,
          message: messages[event.api!](event.count!, event.duration!, event.success!),
          success: event.success!
        });
      }
    };

    const fetchResults = await fetchAllResearchSources(currentQuery, config, progressCallback);

    // ===== STEP 3: Deduplicate Sources =====
    const uniqueSources = {
      exa: deduplicator.filterExa(fetchResults.exa),
      pubmed: deduplicator.filterPubMed(fetchResults.pubmed),
      medrxiv: deduplicator.filterMedRxiv(fetchResults.medrxiv),
      clinicalTrials: deduplicator.filterClinicalTrials(fetchResults.clinicalTrials)
    };

    const roundSourceCount =
      uniqueSources.exa.length +
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

    const roundResult: RoundResult = {
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
      sources: formattedSources,  // Pass actual sources to iOS
      status: 'complete',
      sequence: roundNum * 10 + 5
    });

    logger.info(
      `✅ [DEEP-RESEARCH-V2] Round ${roundNum} complete: ` +
      `${roundSourceCount} unique sources in ${roundDuration}ms`
    );

    // ===== STEP 4: REFLECTION (if not final round) =====
    if (shouldDoReflection(roundNum, maxRounds)) {
      emitSSE(res, {
        type: 'reflection_started',
        round: roundNum,
        sequence: roundNum * 10 + 6
      });

      const reflection = await reflectOnResearchQuality(
        question,
        roundNum,
        roundResult,
        rounds.slice(0, -1), // All previous rounds
        maxRounds
      );

      roundResult.reflection = reflection;

      emitSSE(res, {
        type: 'reflection_complete',
        round: roundNum,
        reflection,
        sequence: roundNum * 10 + 7
      });

      logger.info(
        `🧠 [DEEP-RESEARCH-V2] Reflection: quality=${reflection.evidenceQuality}, ` +
        `continue=${reflection.shouldContinue}, gaps=${reflection.gapsIdentified.length}`
      );

      // ===== STEP 5: STOPPING CONDITION EVALUATION =====
      const stoppingDecision = evaluateStoppingConditions(
        roundNum,
        maxRounds,
        roundResult,
        rounds,
        reflection
      );

      if (stoppingDecision.shouldStop) {
        logger.info(`🛑 [DEEP-RESEARCH-V2] Stopping: ${stoppingDecision.reason}`);
        shouldContinue = false;
      } else {
        // ===== STEP 6: QUERY REFINEMENT for next round =====
        if (reflection.gapsIdentified.length > 0 && roundNum < maxRounds) {
          const refinedQuery = await refineQueryForGaps(
            question,
            reflection.gapsIdentified,
            roundNum + 1
          );

          currentQuery = refinedQuery.refined;

          logger.info(
            `🔄 [DEEP-RESEARCH-V2] Query refined for Round ${roundNum + 1}: ` +
            `"${currentQuery.substring(0, 80)}..." (focus: ${refinedQuery.focusArea})`
          );
        }
      }
    } else {
      // Final round - no reflection needed
      logger.info(`🏁 [DEEP-RESEARCH-V2] Final round ${roundNum} - skipping reflection`);
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

  const totalSources =
    allSources.exa.length +
    allSources.pubmed.length +
    allSources.medrxiv.length +
    allSources.clinicalTrials.length;

  // Log deduplication summary
  deduplicator.logSummary();

  // ===== PHASE 3.5: AI-POWERED SOURCE RELEVANCE RANKING =====
  logger.info(`🎯 [DEEP-RESEARCH-V2] Ranking ${totalSources} sources by relevance...`);

  // NEW: Emit source selection started event for user-friendly stage display
  emitSSE(res, {
    type: 'source_selection_started',
    message: 'En ilgili kaynakları seçiyorum',
    sequence: 200
  });

  // Rank all sources by relevance to original query
  const rankingResult = await rankSourcesByRelevance(
    question, // Original query for best relevance
    allSources,
    {
      topN: 30 // Top 30 most relevant sources
    }
  );

  // Reorder sources by relevance (highest score first)
  const rankedSources = reorderSourcesByRanking(allSources, rankingResult);

  logger.info(
    `✅ [DEEP-RESEARCH-V2] Ranking complete: avg relevance=${rankingResult.averageRelevance.toFixed(1)}, ` +
    `top score=${rankingResult.topSources[0]?.relevanceScore || 0}, ` +
    `duration=${rankingResult.rankingDuration}ms`
  );

  // ===== PHASE 3.6: INTELLIGENT SOURCE SELECTION (TOP-P STRATEGY) =====
  logger.info(`🎯 [DEEP-RESEARCH-V2] Selecting best sources for synthesis...`);

  // Select top sources using intelligent top-P strategy
  const selectionResult = await selectSourcesForSynthesis(
    rankingResult.rankedSources, // Use ranked sources with scores
    {
      baseLimit: 25, // Start with top 25
      extendedLimit: 30, // Extend to 30 if many high-quality sources
      highQualityThreshold: 70, // Threshold for extension
      tokenBudget: 16800, // Maximum tokens for synthesis
      minRelevanceScore: 40, // Minimum score to include
      semanticSimilarityThreshold: 0.85, // Similarity threshold for dedup
      enableSemanticDedup: true // Enable near-duplicate removal
    }
  );

  logger.info(
    `✅ [DEEP-RESEARCH-V2] Selection complete: ${selectionResult.selectedCount}/${totalSources} sources, ` +
    `${selectionResult.deduplicatedCount} duplicates removed, ` +
    `${selectionResult.totalTokens} tokens, ` +
    `strategy: ${selectionResult.selectionStrategy}`
  );

  // NEW: Emit synthesis preparation event for user-friendly stage display
  emitSSE(res, {
    type: 'synthesis_preparation',
    message: 'Bilgileri bir araya getiriyorum',
    sequence: 210
  });

  const results: DeepResearchResults = {
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
    evidenceQuality: 'medium' as const,
    gapsIdentified: [],
    shouldContinue: false,
    reasoning: 'No reflection performed'
  };

  const completenessScore = calculateCompletenessScore(rounds, lastReflection);

  logger.info(
    `✅ [DEEP-RESEARCH-V2] Research complete: ${rounds.length} rounds, ` +
    `${totalSources} sources, ${(totalDuration / 1000).toFixed(1)}s, ` +
    `completeness=${(completenessScore * 100).toFixed(0)}%`
  );

  return results;
}

/**
 * Format research results for AI synthesis
 * Uses selected sources if available, otherwise uses all sources
 */
export function formatResearchForSynthesis(results: DeepResearchResults): string {
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
    context += formatSelectedSourcesForSynthesis(results.selectedSources);

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
    context += formatExaForAI(results.allSources.exa, true) + '\n\n';
  }

  if (results.allSources.pubmed.length > 0) {
    context += formatPubMedForAI(results.allSources.pubmed) + '\n\n';
  }

  if (results.allSources.medrxiv.length > 0) {
    context += '📄 Recent Medical Preprints (medRxiv - Cutting-Edge Research):\n\n';
    context += formatMedRxivForAI(results.allSources.medrxiv) + '\n\n';
  }

  if (results.allSources.clinicalTrials.length > 0) {
    context += formatClinicalTrialsForAI(results.allSources.clinicalTrials) + '\n\n';
  }

  return context;
}
