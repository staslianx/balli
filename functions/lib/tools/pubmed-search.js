"use strict";
//
// PubMed E-utilities API Integration
// Search PubMed for peer-reviewed biomedical literature
//
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.searchPubMed = searchPubMed;
exports.formatPubMedForAI = formatPubMedForAI;
exports.getArticleQualityScore = getArticleQualityScore;
const axios_1 = __importDefault(require("axios"));
/**
 * Search PubMed E-utilities for biomedical literature
 * API Documentation: https://www.ncbi.nlm.nih.gov/books/NBK25501/
 */
async function searchPubMed(query, maxResults = 10, yearsBack = 5, // Default to last 5 years (2020+)
studyTypes // e.g., ['Clinical Trial', 'Meta-Analysis']
) {
    try {
        const apiKey = process.env.PUBMED_API_KEY || '';
        // Build search query with filters
        let searchQuery = query;
        // Add study type filters
        if (studyTypes && studyTypes.length > 0) {
            const typeFilters = studyTypes.map(type => `"${type}"[Publication Type]`).join(' OR ');
            searchQuery = `(${searchQuery}) AND (${typeFilters})`;
        }
        console.log(`🏥 [PUBMED] Searching for: ${query}${yearsBack ? ` (last ${yearsBack} years)` : ''}`);
        // Step 1: Search for article IDs
        const searchUrl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi';
        const searchParams = new URLSearchParams({
            db: 'pubmed',
            term: searchQuery,
            retmax: String(maxResults),
            retmode: 'json',
            sort: 'relevance'
        });
        // Add API key if available (increases rate limit)
        if (apiKey) {
            searchParams.append('api_key', apiKey);
        }
        // Add date filter if specified
        if (yearsBack && yearsBack > 0) {
            const days = yearsBack * 365;
            searchParams.append('reldate', String(days));
        }
        const searchResponse = await axios_1.default.get(`${searchUrl}?${searchParams.toString()}`, {
            timeout: 10000 // 10 second timeout
        });
        const ids = searchResponse.data.esearchresult?.idlist || [];
        if (ids.length === 0) {
            console.log(`📭 [PUBMED] No articles found for query: ${query}`);
            return [];
        }
        console.log(`📚 [PUBMED] Found ${ids.length} articles, fetching details...`);
        // Step 2: Fetch article details
        const fetchUrl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi';
        const fetchParams = new URLSearchParams({
            db: 'pubmed',
            id: ids.join(','),
            retmode: 'json'
        });
        if (apiKey) {
            fetchParams.append('api_key', apiKey);
        }
        const fetchResponse = await axios_1.default.get(`${fetchUrl}?${fetchParams.toString()}`, {
            timeout: 15000 // 15 second timeout for fetching details
        });
        const articlesData = fetchResponse.data.result;
        // Transform to our schema
        const articles = ids.map((id) => {
            const article = articlesData[id];
            if (!article)
                return null;
            // Extract authors
            const authors = (article.authors || []).map((a) => a.name || 'Unknown');
            // Extract MeSH terms
            const meshTerms = (article.articleids || [])
                .filter((aid) => aid.idtype === 'pubmed')
                .map((aid) => aid.value);
            // Determine article type
            const articleType = determineArticleType(article.pubtype || []);
            return {
                pmid: id,
                title: article.title || 'Untitled',
                authors,
                abstract: '', // Summaries don't include abstracts, would need efetch
                journal: article.source || 'Unknown Journal',
                publishDate: article.pubdate || '',
                doi: article.elocationid?.startsWith('doi:') ? article.elocationid.substring(4) : null,
                url: `https://pubmed.ncbi.nlm.nih.gov/${id}/`,
                citationCount: null, // Not available in esummary
                articleType,
                meshTerms: meshTerms.slice(0, 5) // Limit to top 5 terms
            };
        }).filter((a) => a !== null);
        console.log(`✅ [PUBMED] Retrieved ${articles.length} articles`);
        return articles;
    }
    catch (error) {
        console.error(`❌ [PUBMED] Search failed:`, error.message);
        // Return empty array on error rather than throwing
        // This allows other tools to still provide value
        return [];
    }
}
/**
 * Determine article type from PubMed publication types
 */
function determineArticleType(pubTypes) {
    const typeMap = {
        'Meta-Analysis': 'Meta-Analysis',
        'Systematic Review': 'Systematic Review',
        'Randomized Controlled Trial': 'RCT',
        'Clinical Trial': 'Clinical Trial',
        'Observational Study': 'Observational Study',
        'Case Reports': 'Case Report',
        'Review': 'Review'
    };
    for (const pubType of pubTypes) {
        if (typeMap[pubType]) {
            return typeMap[pubType];
        }
    }
    return 'Research Article';
}
/**
 * Format PubMed results for Gemini consumption
 */
function formatPubMedForAI(articles) {
    if (articles.length === 0) {
        return 'No PubMed articles found for the specified query.';
    }
    return articles.map((article, index) => {
        const parts = [
            `${index + 1}. ${article.title}`,
            `   PMID: ${article.pmid}`,
            `   Authors: ${article.authors.slice(0, 3).join(', ')}${article.authors.length > 3 ? ' et al.' : ''}`,
            `   Journal: ${article.journal}`,
            `   Published: ${article.publishDate}`,
            `   Type: ${article.articleType}`,
            article.doi ? `   DOI: ${article.doi}` : null,
            article.meshTerms.length > 0 ? `   Topics: ${article.meshTerms.join(', ')}` : null,
            `   URL: ${article.url}`
        ].filter(Boolean);
        return parts.join('\n');
    }).join('\n\n');
}
/**
 * Get article quality score based on publication type
 * Higher scores indicate stronger evidence
 */
function getArticleQualityScore(articleType) {
    const scoreMap = {
        'Meta-Analysis': 10,
        'Systematic Review': 9,
        'RCT': 8,
        'Clinical Trial': 7,
        'Observational Study': 6,
        'Review': 5,
        'Case Report': 4,
        'Research Article': 5
    };
    return scoreMap[articleType] || 5;
}
//# sourceMappingURL=pubmed-search.js.map