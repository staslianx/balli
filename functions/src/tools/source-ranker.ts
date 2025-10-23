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

import { logger } from 'firebase-functions/v2';

/**
 * Ranked source with relevance score
 */
export interface RankedSource {
  source: any; // Original source object
  relevanceScore: number; // 0-100 (100 = most relevant)
  reasoning: string; // Why this score was assigned
  sourceType: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa';
}

/**
 * Source ranking results
 */
export interface SourceRankingResult {
  rankedSources: RankedSource[];
  topSources: RankedSource[]; // Top N most relevant
  totalSources: number;
  averageRelevance: number;
  rankingDuration: number; // milliseconds
}

/**
 * Configuration for source ranking
 */
export interface RankingConfig {
  topN: number; // Number of top sources to return (e.g., 30)
}

/**
 * Rank research sources by relevance to user query using keyword matching
 *
 * @param query - User's research question
 * @param sources - Object containing sources from all APIs
 * @param config - Ranking configuration
 * @returns Ranking results with top N sources
 */
export async function rankSourcesByRelevance(
  query: string,
  sources: {
    pubmed: any[];
    medrxiv: any[];
    clinicalTrials: any[];
    exa: any[];
  },
  config: RankingConfig
): Promise<SourceRankingResult> {
  const startTime = Date.now();

  logger.info(
    `🎯 [SOURCE-RANKER] Starting keyword-based ranking: ` +
    `PubMed(${sources.pubmed.length}), medRxiv(${sources.medrxiv.length}), ` +
    `Trials(${sources.clinicalTrials.length}), Exa(${sources.exa.length})`
  );

  try {
    // Extract keywords from query
    const keywords = extractKeywords(query);

    // Flatten all sources with type labels
    const allSources: Array<{ source: any; sourceType: RankedSource['sourceType'] }> = [
      ...sources.pubmed.map(s => ({ source: s, sourceType: 'pubmed' as const })),
      ...sources.medrxiv.map(s => ({ source: s, sourceType: 'medrxiv' as const })),
      ...sources.clinicalTrials.map(s => ({ source: s, sourceType: 'clinicaltrials' as const })),
      ...sources.exa.map(s => ({ source: s, sourceType: 'exa' as const }))
    ];

    // Score each source
    const rankedSources: RankedSource[] = allSources.map((item) => {
      const title = extractTitle(item.source, item.sourceType);
      const abstract = extractAbstract(item.source, item.sourceType);
      const content = `${title} ${abstract}`.toLowerCase();

      // Calculate keyword match score (0-70 points)
      const keywordScore = calculateKeywordScore(content, keywords);

      // Apply credibility boost (0-15 points)
      const credibilityBoost = getCredibilityBoost(item.sourceType);

      // Apply recency boost (0-15 points)
      const recencyBoost = getRecencyBoost(item.source, item.sourceType);

      const finalScore = Math.min(100, keywordScore + credibilityBoost + recencyBoost);

      return {
        source: item.source,
        relevanceScore: Math.round(finalScore),
        reasoning: `Keywords: ${keywordScore}, Credibility: ${credibilityBoost}, Recency: ${recencyBoost}`,
        sourceType: item.sourceType
      };
    });

    // Sort by relevance score (descending)
    rankedSources.sort((a, b) => b.relevanceScore - a.relevanceScore);

    // Get top N sources
    const topSources = rankedSources.slice(0, config.topN);

    // Calculate average relevance
    const averageRelevance = rankedSources.length > 0
      ? rankedSources.reduce((sum, s) => sum + s.relevanceScore, 0) / rankedSources.length
      : 0;

    const duration = Date.now() - startTime;

    logger.info(
      `✅ [SOURCE-RANKER] Ranking complete in ${duration}ms: ` +
      `Top 5 scores: [${topSources.slice(0, 5).map(s => s.relevanceScore).join(', ')}], ` +
      `Average: ${averageRelevance.toFixed(1)}`
    );

    return {
      rankedSources,
      topSources,
      totalSources: rankedSources.length,
      averageRelevance: Math.round(averageRelevance),
      rankingDuration: duration
    };
  } catch (error: any) {
    logger.error(`❌ [SOURCE-RANKER] Ranking failed:`, error);
    throw error;
  }
}

/**
 * Reorder sources array based on ranking results
 */
export function reorderSourcesByRanking(
  sources: {
    pubmed: any[];
    medrxiv: any[];
    clinicalTrials: any[];
    exa: any[];
  },
  rankingResult: SourceRankingResult
): {
  pubmed: any[];
  medrxiv: any[];
  clinicalTrials: any[];
  exa: any[];
} {
  const pubmedReordered: any[] = [];
  const medrxivReordered: any[] = [];
  const trialsReordered: any[] = [];
  const exaReordered: any[] = [];

  for (const ranked of rankingResult.topSources) {
    if (ranked.sourceType === 'pubmed') pubmedReordered.push(ranked.source);
    else if (ranked.sourceType === 'medrxiv') medrxivReordered.push(ranked.source);
    else if (ranked.sourceType === 'clinicaltrials') trialsReordered.push(ranked.source);
    else if (ranked.sourceType === 'exa') exaReordered.push(ranked.source);
  }

  return {
    pubmed: pubmedReordered,
    medrxiv: medrxivReordered,
    clinicalTrials: trialsReordered,
    exa: exaReordered
  };
}

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Extract keywords from query (simple tokenization)
 */
function extractKeywords(query: string): string[] {
  const stopWords = new Set(['the', 'a', 'an', 'and', 'or', 'but', 'is', 'are', 'was', 'were', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 've', 'nedir', 'ne', 'nasıl', 'için']);

  return query
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter(word => word.length > 2 && !stopWords.has(word));
}

/**
 * Calculate keyword match score (0-70 points)
 */
function calculateKeywordScore(content: string, keywords: string[]): number {
  if (keywords.length === 0) return 35; // Neutral score if no keywords

  let matches = 0;
  for (const keyword of keywords) {
    if (content.includes(keyword)) {
      matches++;
    }
  }

  const matchRatio = matches / keywords.length;
  return Math.round(matchRatio * 70);
}

/**
 * Extract title from source based on type
 */
function extractTitle(source: any, sourceType: string): string {
  switch (sourceType) {
    case 'pubmed':
      return source.title || source.article_title || '';
    case 'medrxiv':
      return source.title || '';
    case 'clinicaltrials':
      return source.title || source.study_title || source.officialTitle || '';
    case 'exa':
      return source.title || '';
    default:
      return '';
  }
}

/**
 * Extract abstract/summary from source
 */
function extractAbstract(source: any, sourceType: string): string {
  switch (sourceType) {
    case 'pubmed':
      return source.abstract || source.abstractText || '';
    case 'medrxiv':
      return source.abstract || '';
    case 'clinicaltrials':
      return source.briefSummary || source.summary || '';
    case 'exa':
      return source.text || source.summary || '';
    default:
      return '';
  }
}

/**
 * Get credibility boost based on source type (0-15 points)
 */
function getCredibilityBoost(sourceType: string): number {
  switch (sourceType) {
    case 'pubmed':
    case 'clinicaltrials':
      return 15; // Highly credible peer-reviewed sources
    case 'medrxiv':
      return 8; // Medical preprints, less vetted
    case 'exa':
      return 5; // Web sources, least credible
    default:
      return 0;
  }
}

/**
 * Extract publish date from source
 */
function extractPublishDate(source: any, sourceType: string): string | null {
  switch (sourceType) {
    case 'pubmed':
      return source.pubDate || source.publishedDate || source.pub_date || null;
    case 'medrxiv':
      return source.date || source.publishedDate || null;
    case 'clinicaltrials':
      return source.studyFirstPostDate || source.lastUpdatePostDate || null;
    case 'exa':
      return source.publishedDate || source.date || null;
    default:
      return null;
  }
}

/**
 * Get recency boost based on publication date (0-15 points)
 */
function getRecencyBoost(source: any, sourceType: string): number {
  const publishDate = extractPublishDate(source, sourceType);
  if (!publishDate) return 0;

  try {
    const pubYear = new Date(publishDate).getFullYear();
    const currentYear = new Date().getFullYear();
    const yearsDiff = currentYear - pubYear;

    if (yearsDiff <= 1) return 15; // Very recent (within 1 year)
    if (yearsDiff <= 3) return 10; // Recent (within 3 years)
    if (yearsDiff <= 5) return 5;  // Moderately recent
    return 0; // Older than 5 years
  } catch {
    return 0; // Invalid date
  }
}
