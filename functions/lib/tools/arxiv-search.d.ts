export interface ArxivPaperResult {
    arxivId: string;
    title: string;
    authors: string[];
    abstract: string;
    published: string;
    updated: string;
    categories: string[];
    url: string;
    pdfUrl: string;
    journal: string;
    comments: string | null;
}
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
export declare function searchArxiv(query: string, maxResults?: number, categories?: string[], // e.g., ['q-bio', 'cs']
yearsBack?: number): Promise<ArxivPaperResult[]>;
/**
 * Format arXiv results for Gemini consumption
 */
export declare function formatArxivForAI(papers: ArxivPaperResult[]): string;
/**
 * Determine if an arXiv category is relevant to diabetes research
 */
export declare function isRelevantCategory(category: string): boolean;
//# sourceMappingURL=arxiv-search.d.ts.map