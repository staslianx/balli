"use strict";
//
// arXiv API Integration
// Search arXiv preprint repository for diabetes and medical research papers
//
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.searchArxiv = searchArxiv;
exports.formatArxivForAI = formatArxivForAI;
exports.isRelevantCategory = isRelevantCategory;
const axios_1 = __importDefault(require("axios"));
const xml2js_1 = require("xml2js");
/**
 * Search arXiv for preprint research papers
 * API Documentation: http://arxiv.org/help/api/user-manual
 *
 * Relevant arXiv categories for diabetes research:
 * - q-bio.QM: Quantitative Methods (diabetes modeling)
 * - q-bio.TO: Tissues and Organs (pancreas, insulin)
 * - cs.LG: Machine Learning (AI for diabetes prediction)
 * - cs.AI: Artificial Intelligence (clinical decision support)
 */
async function searchArxiv(query, maxResults = 10, categories, // e.g., ['q-bio', 'cs']
yearsBack // Only search papers from last N years
) {
    try {
        // Build search query with category filters
        let searchQuery = `all:${query}`;
        if (categories && categories.length > 0) {
            const categoryFilters = categories.map(cat => `cat:${cat}*`).join(' OR ');
            searchQuery = `(${searchQuery}) AND (${categoryFilters})`;
        }
        // Build API parameters
        const params = {
            search_query: searchQuery,
            start: 0,
            max_results: maxResults,
            sortBy: 'relevance',
            sortOrder: 'descending'
        };
        console.log(`📄 [ARXIV] Searching for: ${query}${categories ? ` in categories: ${categories.join(', ')}` : ''}`);
        // Make API request
        const response = await axios_1.default.get('http://export.arxiv.org/api/query', {
            params,
            timeout: 10000 // 10 second timeout
        });
        // Parse XML response
        const papers = await parseXMLResponse(response.data);
        // Filter by date if specified
        if (yearsBack && yearsBack > 0) {
            const cutoffDate = new Date();
            cutoffDate.setFullYear(cutoffDate.getFullYear() - yearsBack);
            return papers.filter(paper => {
                const paperDate = new Date(paper.published);
                return paperDate >= cutoffDate;
            });
        }
        return papers;
    }
    catch (error) {
        console.error(`❌ [ARXIV] Search failed:`, error.message);
        // Return empty array on error rather than throwing
        // This allows other tools to still provide value
        return [];
    }
}
/**
 * Parse arXiv XML response into structured paper results
 */
async function parseXMLResponse(xmlData) {
    return new Promise((resolve) => {
        (0, xml2js_1.parseString)(xmlData, (err, result) => {
            if (err) {
                console.error('❌ [ARXIV] XML Parse Error:', err);
                resolve([]);
                return;
            }
            const entries = result.feed?.entry || [];
            const papers = entries.map((entry) => {
                // Extract arXiv ID from the full ID URL
                const fullId = entry.id?.[0] || '';
                const arxivId = fullId.split('/abs/')[1] || fullId;
                // Extract authors
                const authors = (entry.author || []).map((a) => a.name?.[0] || 'Unknown');
                // Extract categories
                const categories = (entry.category || []).map((c) => c.$?.term || '');
                // Build URLs
                const url = `https://arxiv.org/abs/${arxivId}`;
                const pdfUrl = `https://arxiv.org/pdf/${arxivId}.pdf`;
                return {
                    arxivId,
                    title: entry.title?.[0]?.replace(/\s+/g, ' ').trim() || 'Untitled',
                    authors,
                    abstract: entry.summary?.[0]?.replace(/\s+/g, ' ').trim() || 'No abstract available',
                    published: entry.published?.[0]?.split('T')[0] || '',
                    updated: entry.updated?.[0]?.split('T')[0] || '',
                    categories,
                    url,
                    pdfUrl,
                    journal: 'arXiv (preprint)',
                    comments: entry['arxiv:comment']?.[0] || null
                };
            });
            resolve(papers);
        });
    });
}
/**
 * Format arXiv results for Gemini consumption
 */
function formatArxivForAI(papers) {
    if (papers.length === 0) {
        return 'No arXiv papers found for the specified query.';
    }
    return papers.map((paper, index) => {
        const parts = [
            `${index + 1}. ${paper.title}`,
            `   arXiv ID: ${paper.arxivId}`,
            `   Authors: ${paper.authors.slice(0, 3).join(', ')}${paper.authors.length > 3 ? ' et al.' : ''}`,
            `   Published: ${paper.published}`,
            `   Categories: ${paper.categories.join(', ')}`,
            `   Abstract: ${paper.abstract.slice(0, 400)}${paper.abstract.length > 400 ? '...' : ''}`,
            paper.comments ? `   Note: ${paper.comments}` : null,
            `   URL: ${paper.url}`,
            `   PDF: ${paper.pdfUrl}`
        ].filter(Boolean);
        return parts.join('\n');
    }).join('\n\n');
}
/**
 * Determine if an arXiv category is relevant to diabetes research
 */
function isRelevantCategory(category) {
    const relevantPrefixes = [
        'q-bio', // Quantitative Biology (all subcategories)
        'cs.LG', // Machine Learning
        'cs.AI', // Artificial Intelligence
        'stat.ML', // Machine Learning (Statistics)
        'physics.med-ph' // Medical Physics
    ];
    return relevantPrefixes.some(prefix => category.startsWith(prefix));
}
//# sourceMappingURL=arxiv-search.js.map