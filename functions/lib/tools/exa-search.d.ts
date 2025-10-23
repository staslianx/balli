export interface ExaSearchResult {
    id: string;
    title: string;
    url: string;
    domain: string;
    publishedDate: string | null;
    author: string | null;
    snippet: string;
    highlights: string[];
    credibilityLevel: 'medical_institution' | 'peer_reviewed' | 'expert_authored' | 'general';
}
/**
 * Trusted medical domains for Pro tier medical research
 */
export declare const TRUSTED_MEDICAL_DOMAINS: string[];
/**
 * Search Exa for medical sources (Pro tier)
 * Restricted to trusted medical domains
 */
export declare function searchMedicalSources(query: string, numResults?: number): Promise<ExaSearchResult[]>;
/**
 * Search Exa for general web content (Flash tier)
 * Can search across all domains
 */
export declare function searchGeneralWeb(query: string, numResults?: number, includeDomains?: string[], useAutoprompt?: boolean): Promise<ExaSearchResult[]>;
/**
 * Format Exa results for Gemini consumption
 */
export declare function formatExaForAI(results: ExaSearchResult[], isMedical?: boolean): string;
//# sourceMappingURL=exa-search.d.ts.map