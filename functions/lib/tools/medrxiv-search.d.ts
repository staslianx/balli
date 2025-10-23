export interface MedRxivResult {
    title: string;
    authors: string;
    abstract: string;
    date: string;
    doi: string;
    url: string;
    category: string;
    version: number;
}
/**
 * Search medRxiv for medical preprints
 * API Documentation: https://api.biorxiv.org/
 *
 * medRxiv is specifically for medical research preprints,
 * making it far more relevant than arXiv for diabetes research
 */
export declare function searchMedRxiv(query: string, maxResults?: number, minDate?: string): Promise<MedRxivResult[]>;
/**
 * Format medRxiv results for Gemini consumption
 */
export declare function formatMedRxivForAI(papers: MedRxivResult[]): string;
//# sourceMappingURL=medrxiv-search.d.ts.map