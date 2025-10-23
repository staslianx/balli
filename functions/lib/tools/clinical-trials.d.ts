export interface ClinicalTrialResult {
    nctId: string;
    title: string;
    status: string;
    summary: string;
    conditions: string[];
    interventions: string[];
    phase: string | null;
    enrollmentCount: number | null;
    startDate: string | null;
    completionDate: string | null;
    locations: string[];
    url: string;
}
/**
 * Search ClinicalTrials.gov for clinical studies
 * API Documentation: https://clinicaltrials.gov/api/v2/studies
 */
export declare function searchClinicalTrials(condition: string, intervention?: string, status?: 'recruiting' | 'completed' | 'active' | 'all', maxResults?: number): Promise<ClinicalTrialResult[]>;
/**
 * Format clinical trial results for Gemini consumption
 */
export declare function formatClinicalTrialsForAI(trials: ClinicalTrialResult[]): string;
//# sourceMappingURL=clinical-trials.d.ts.map