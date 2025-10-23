"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.selectSourcesForSynthesis = selectSourcesForSynthesis;
exports.formatSelectedSourcesForSynthesis = formatSelectedSourcesForSynthesis;
const v2_1 = require("firebase-functions/v2");
/**
 * Select the best sources for synthesis using top-P style strategy
 *
 * @param rankedSources - Sources with relevance scores (already sorted)
 * @param config - Selection configuration
 * @returns Selected sources optimized for synthesis
 */
async function selectSourcesForSynthesis(rankedSources, config = {}) {
    const startTime = Date.now();
    // Apply defaults
    const { baseLimit = 25, extendedLimit = 30, highQualityThreshold = 70, tokenBudget = 16800, minRelevanceScore = 40, semanticSimilarityThreshold = 0.85, enableSemanticDedup = true } = config;
    v2_1.logger.info(`🎯 [SOURCE-SELECTOR] Starting selection: ${rankedSources.length} sources, ` +
        `base limit=${baseLimit}, extended limit=${extendedLimit}`);
    // ===== STEP 1: Filter by minimum relevance =====
    const qualifiedSources = rankedSources.filter(s => s.relevanceScore >= minRelevanceScore);
    if (qualifiedSources.length < rankedSources.length) {
        v2_1.logger.info(`📊 [SOURCE-SELECTOR] Filtered out ${rankedSources.length - qualifiedSources.length} ` +
            `sources below threshold (${minRelevanceScore})`);
    }
    // ===== STEP 2: Determine selection limit (top-P style) =====
    let selectionLimit = baseLimit;
    // Count high-quality sources
    const highQualitySources = qualifiedSources.filter(s => s.relevanceScore >= highQualityThreshold);
    // Extend limit if we have many high-quality sources
    if (highQualitySources.length > baseLimit) {
        selectionLimit = Math.min(extendedLimit, highQualitySources.length);
        v2_1.logger.info(`📈 [SOURCE-SELECTOR] Extended limit to ${selectionLimit} ` +
            `(${highQualitySources.length} high-quality sources available)`);
    }
    // ===== STEP 3: Select top sources =====
    let candidateSources = qualifiedSources.slice(0, selectionLimit);
    v2_1.logger.info(`✂️ [SOURCE-SELECTOR] Selected top ${candidateSources.length} sources ` +
        `from ${qualifiedSources.length} qualified sources`);
    // ===== STEP 4: Semantic deduplication (remove near-duplicates) =====
    let deduplicatedCount = 0;
    if (enableSemanticDedup && candidateSources.length > 1) {
        const { unique, duplicateCount } = await deduplicateSemanticallySimilar(candidateSources, semanticSimilarityThreshold);
        deduplicatedCount = duplicateCount;
        candidateSources = unique;
        if (duplicateCount > 0) {
            v2_1.logger.info(`🔍 [SOURCE-SELECTOR] Removed ${duplicateCount} semantically similar sources, ` +
                `${candidateSources.length} remain`);
        }
    }
    // ===== STEP 5: Token budget management =====
    const selectedSources = [];
    let currentTokens = 0;
    for (const rankedSource of candidateSources) {
        const selectedSource = formatSourceForSynthesis(rankedSource);
        const sourceTokens = selectedSource.estimatedTokens;
        // Check if adding this source would exceed budget
        if (currentTokens + sourceTokens > tokenBudget) {
            v2_1.logger.warn(`⚠️ [SOURCE-SELECTOR] Token budget reached: ${currentTokens} + ${sourceTokens} > ${tokenBudget}, ` +
                `stopping at ${selectedSources.length} sources`);
            break;
        }
        selectedSources.push(selectedSource);
        currentTokens += sourceTokens;
    }
    // ===== STEP 6: Calculate quality metrics =====
    const relevanceScores = selectedSources.map(s => s.relevanceScore);
    const averageRelevance = relevanceScores.reduce((sum, r) => sum + r, 0) / relevanceScores.length;
    const minRelevance = Math.min(...relevanceScores);
    const maxRelevance = Math.max(...relevanceScores);
    const highQualityCount = selectedSources.filter(s => s.relevanceScore > 80).length;
    const result = {
        selectedSources,
        totalSources: rankedSources.length,
        selectedCount: selectedSources.length,
        deduplicatedCount,
        totalTokens: currentTokens,
        selectionStrategy: determineStrategyDescription(rankedSources.length, selectedSources.length, deduplicatedCount, selectionLimit, baseLimit),
        qualityMetrics: {
            averageRelevance,
            minRelevance,
            maxRelevance,
            highQualityCount
        }
    };
    const duration = Date.now() - startTime;
    v2_1.logger.info(`✅ [SOURCE-SELECTOR] Selection complete in ${duration}ms: ` +
        `${selectedSources.length}/${rankedSources.length} sources selected, ` +
        `${currentTokens}/${tokenBudget} tokens used, ` +
        `avg relevance=${averageRelevance.toFixed(1)}, ` +
        `${highQualityCount} high-quality sources`);
    // Log top 5 selected sources
    v2_1.logger.info(`🏆 [SOURCE-SELECTOR] Top 5 selected sources:`);
    selectedSources.slice(0, 5).forEach((source, idx) => {
        const title = source.citation.substring(0, 60);
        v2_1.logger.info(`  ${idx + 1}. [${source.relevanceScore}] ${source.sourceType}: ${title}... (${source.estimatedTokens} tokens)`);
    });
    return result;
}
/**
 * Remove semantically similar sources (near-duplicates)
 * Uses simple title/abstract similarity for now
 * TODO: Use vector embeddings for more accurate similarity detection
 */
async function deduplicateSemanticallySimilar(sources, similarityThreshold) {
    const unique = [];
    let duplicateCount = 0;
    for (const source of sources) {
        const sourceText = extractTextForComparison(source);
        // Check similarity with already selected sources
        let isDuplicate = false;
        for (const existingSource of unique) {
            const existingText = extractTextForComparison(existingSource);
            // Simple similarity check using Jaccard similarity on word sets
            const similarity = calculateJaccardSimilarity(sourceText, existingText);
            if (similarity > similarityThreshold) {
                isDuplicate = true;
                v2_1.logger.debug(`🔍 [SOURCE-SELECTOR] Duplicate detected: similarity=${similarity.toFixed(2)}, ` +
                    `keeping higher-scored source`);
                break;
            }
        }
        if (!isDuplicate) {
            unique.push(source);
        }
        else {
            duplicateCount++;
        }
    }
    return { unique, duplicateCount };
}
/**
 * Extract text for similarity comparison
 */
function extractTextForComparison(rankedSource) {
    const source = rankedSource.source;
    const type = rankedSource.sourceType;
    let title = '';
    let abstract = '';
    if (type === 'pubmed') {
        title = source.title || '';
        abstract = source.abstract || '';
    }
    else if (type === 'medrxiv') {
        title = source.title || '';
        abstract = source.abstract || '';
    }
    else if (type === 'clinicaltrials') {
        title = source.title || '';
        abstract = source.description || '';
    }
    else if (type === 'exa') {
        title = source.title || '';
        abstract = source.text || source.snippet || '';
    }
    return (title + ' ' + abstract).toLowerCase();
}
/**
 * Calculate Jaccard similarity between two texts
 * Returns 0-1 (0 = completely different, 1 = identical)
 */
function calculateJaccardSimilarity(text1, text2) {
    // Tokenize into words
    const words1 = new Set(text1.split(/\s+/).filter(w => w.length > 3)); // Ignore short words
    const words2 = new Set(text2.split(/\s+/).filter(w => w.length > 3));
    // Calculate intersection and union
    const intersection = new Set([...words1].filter(w => words2.has(w)));
    const union = new Set([...words1, ...words2]);
    if (union.size === 0)
        return 0;
    return intersection.size / union.size;
}
/**
 * Format ranked source for synthesis with full metadata
 */
function formatSourceForSynthesis(rankedSource) {
    const source = rankedSource.source;
    const type = rankedSource.sourceType;
    let citation = '';
    let summary = '';
    let credibilityBadge = '';
    if (type === 'pubmed') {
        const authors = source.authors?.[0] || 'Unknown';
        const journal = source.journal || 'PubMed';
        const year = source.pubdate?.split('-')[0] || '';
        citation = `${authors} et al. (${year}). ${source.title}. ${journal}.`;
        summary = source.abstract || '';
        credibilityBadge = 'highly_credible';
    }
    else if (type === 'medrxiv') {
        const authors = source.authors || 'Unknown';
        const year = source.date?.split('-')[0] || '';
        citation = `${authors} et al. (${year}). ${source.title}. medRxiv preprint.`;
        summary = source.abstract || '';
        credibilityBadge = 'credible';
    }
    else if (type === 'clinicaltrials') {
        const year = source.startDate?.split('-')[0] || '';
        citation = `${source.title}. ClinicalTrials.gov ID: ${source.nctId}. Started: ${year}.`;
        summary = source.description || '';
        credibilityBadge = 'highly_credible';
    }
    else if (type === 'exa') {
        const domain = source.domain || 'Web';
        const year = source.publishedDate?.split('-')[0] || '';
        citation = `${source.title}. ${domain}. ${year ? `Published: ${year}.` : ''}`;
        summary = source.text || source.snippet || '';
        credibilityBadge = 'credible';
    }
    // Estimate tokens (rough: ~4 chars per token)
    const estimatedTokens = Math.ceil((citation.length + summary.length) / 4);
    return {
        source,
        relevanceScore: rankedSource.relevanceScore,
        sourceType: type,
        citation,
        summary,
        credibilityBadge,
        estimatedTokens
    };
}
/**
 * Determine human-readable strategy description
 */
function determineStrategyDescription(totalSources, selectedCount, deduplicatedCount, selectionLimit, baseLimit) {
    if (selectedCount === totalSources) {
        return 'Included all sources (below limit)';
    }
    if (selectionLimit > baseLimit) {
        return `Extended selection to ${selectionLimit} sources (high-quality threshold met)`;
    }
    if (deduplicatedCount > 0) {
        return `Top-P selection with deduplication (${deduplicatedCount} near-duplicates removed)`;
    }
    return `Top-P selection (top ${selectedCount} most relevant sources)`;
}
/**
 * Format selected sources for AI synthesis prompt
 *
 * @param selectedSources - Sources selected for synthesis
 * @returns Formatted string for synthesis prompt
 */
function formatSelectedSourcesForSynthesis(selectedSources) {
    let formatted = `# SELECTED RESEARCH SOURCES (${selectedSources.length} sources)\n\n`;
    // Group by source type
    const byType = {
        pubmed: selectedSources.filter(s => s.sourceType === 'pubmed'),
        medrxiv: selectedSources.filter(s => s.sourceType === 'medrxiv'),
        clinicaltrials: selectedSources.filter(s => s.sourceType === 'clinicaltrials'),
        exa: selectedSources.filter(s => s.sourceType === 'exa')
    };
    // Format PubMed sources
    if (byType.pubmed.length > 0) {
        formatted += `## 🔬 Peer-Reviewed Articles (PubMed) - ${byType.pubmed.length} sources\n\n`;
        byType.pubmed.forEach((source, idx) => {
            formatted += `### [${idx + 1}] ${source.citation}\n`;
            formatted += `**Relevance:** ${source.relevanceScore}/100 | **Credibility:** ${source.credibilityBadge}\n\n`;
            formatted += `${source.summary.substring(0, 500)}${source.summary.length > 500 ? '...' : ''}\n\n`;
        });
    }
    // Format Clinical Trial sources
    if (byType.clinicaltrials.length > 0) {
        formatted += `## 🏥 Clinical Trials - ${byType.clinicaltrials.length} sources\n\n`;
        byType.clinicaltrials.forEach((source, idx) => {
            formatted += `### [${byType.pubmed.length + idx + 1}] ${source.citation}\n`;
            formatted += `**Relevance:** ${source.relevanceScore}/100 | **Credibility:** ${source.credibilityBadge}\n\n`;
            formatted += `${source.summary.substring(0, 500)}${source.summary.length > 500 ? '...' : ''}\n\n`;
        });
    }
    // Format medRxiv sources
    if (byType.medrxiv.length > 0) {
        formatted += `## 📄 Recent Medical Research (medRxiv) - ${byType.medrxiv.length} sources\n\n`;
        byType.medrxiv.forEach((source, idx) => {
            const prevCount = byType.pubmed.length + byType.clinicaltrials.length;
            formatted += `### [${prevCount + idx + 1}] ${source.citation}\n`;
            formatted += `**Relevance:** ${source.relevanceScore}/100 | **Credibility:** ${source.credibilityBadge}\n\n`;
            formatted += `${source.summary.substring(0, 500)}${source.summary.length > 500 ? '...' : ''}\n\n`;
        });
    }
    // Format Exa medical sources
    if (byType.exa.length > 0) {
        formatted += `## 🌐 Medical Websites (Exa) - ${byType.exa.length} sources\n\n`;
        byType.exa.forEach((source, idx) => {
            const prevCount = byType.pubmed.length + byType.clinicaltrials.length + byType.medrxiv.length;
            formatted += `### [${prevCount + idx + 1}] ${source.citation}\n`;
            formatted += `**Relevance:** ${source.relevanceScore}/100 | **Credibility:** ${source.credibilityBadge}\n\n`;
            formatted += `${source.summary.substring(0, 400)}${source.summary.length > 400 ? '...' : ''}\n\n`;
        });
    }
    return formatted;
}
//# sourceMappingURL=source-selector.js.map