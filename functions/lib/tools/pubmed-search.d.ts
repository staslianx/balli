export interface PubMedArticleResult {
    pmid: string;
    title: string;
    authors: string[];
    abstract: string;
    journal: string;
    publishDate: string;
    doi: string | null;
    url: string;
    citationCount: number | null;
    articleType: string;
    meshTerms: string[];
}
/**
 * Search PubMed E-utilities for biomedical literature
 * API Documentation: https://www.ncbi.nlm.nih.gov/books/NBK25501/
 */
export declare function searchPubMed(query: string, maxResults?: number, yearsBack?: number, // Default to last 5 years (2020+)
studyTypes?: string[]): Promise<PubMedArticleResult[]>;
/**
 * Format PubMed results for Gemini consumption
 */
export declare function formatPubMedForAI(articles: PubMedArticleResult[]): string;
/**
 * Get article quality score based on publication type
 * Higher scores indicate stronger evidence
 */
export declare function getArticleQualityScore(articleType: string): number;
//# sourceMappingURL=pubmed-search.d.ts.map