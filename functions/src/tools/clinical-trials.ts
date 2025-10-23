//
// ClinicalTrials.gov API Integration
// Search clinical trials database for diabetes treatment research
//

import axios from 'axios';

export interface ClinicalTrialResult {
  nctId: string; // NCT identifier (e.g., NCT12345678)
  title: string;
  status: string; // e.g., "Recruiting", "Completed", "Active, not recruiting"
  summary: string;
  conditions: string[]; // e.g., ["Diabetes Mellitus, Type 2"]
  interventions: string[]; // e.g., ["Drug: Metformin", "Behavioral: Diet"]
  phase: string | null; // e.g., "Phase 3", "Phase 4"
  enrollmentCount: number | null;
  startDate: string | null;
  completionDate: string | null;
  locations: string[]; // Country names
  url: string; // ClinicalTrials.gov URL
}

/**
 * Search ClinicalTrials.gov for clinical studies
 * API Documentation: https://clinicaltrials.gov/api/v2/studies
 */
export async function searchClinicalTrials(
  condition: string,
  intervention?: string,
  status?: 'recruiting' | 'completed' | 'active' | 'all',
  maxResults: number = 10
): Promise<ClinicalTrialResult[]> {
  try {
    // Build query parameters
    const params: any = {
      'query.cond': condition,
      pageSize: maxResults,
      format: 'json',
      // Sort by relevance
      sort: '@relevance'
    };

    // Add intervention filter if specified
    if (intervention) {
      params['query.intr'] = intervention;
    }

    // Add status filter
    if (status && status !== 'all') {
      const statusMap = {
        recruiting: 'RECRUITING',
        completed: 'COMPLETED',
        active: 'ACTIVE_NOT_RECRUITING'
      };
      params['filter.overallStatus'] = statusMap[status];
    }

    console.log(`🔬 [CLINICAL-TRIALS] Searching for: ${condition}${intervention ? ` + ${intervention}` : ''}`);

    // Make API request
    const response = await axios.get('https://clinicaltrials.gov/api/v2/studies', {
      params,
      timeout: 10000 // 10 second timeout
    });

    // Parse results
    const studies = response.data?.studies || [];

    return studies.map((study: any) => {
      const protocolSection = study.protocolSection || {};
      const identificationModule = protocolSection.identificationModule || {};
      const statusModule = protocolSection.statusModule || {};
      const descriptionModule = protocolSection.descriptionModule || {};
      const conditionsModule = protocolSection.conditionsModule || {};
      const armsInterventionsModule = protocolSection.armsInterventionsModule || {};
      const designModule = protocolSection.designModule || {};
      const contactsLocationsModule = protocolSection.contactsLocationsModule || {};

      return {
        nctId: identificationModule.nctId || '',
        title: identificationModule.officialTitle || identificationModule.briefTitle || 'Untitled Study',
        status: statusModule.overallStatus || 'Unknown',
        summary: descriptionModule.briefSummary || descriptionModule.detailedDescription || 'No summary available',
        conditions: conditionsModule.conditions || [],
        interventions: (armsInterventionsModule.interventions || []).map((i: any) =>
          `${i.type || 'Unknown'}: ${i.name || 'Unnamed'}`
        ),
        phase: designModule.phases?.[0] || null,
        enrollmentCount: statusModule.enrollmentInfo?.count || null,
        startDate: statusModule.startDateStruct?.date || null,
        completionDate: statusModule.completionDateStruct?.date || null,
        locations: Array.from(new Set(
          (contactsLocationsModule.locations || []).map((loc: any) => loc.country)
        )),
        url: `https://clinicaltrials.gov/study/${identificationModule.nctId}`
      };
    });
  } catch (error: any) {
    console.error(`❌ [CLINICAL-TRIALS] Search failed:`, error.message);

    // Return empty array on error rather than throwing
    // This allows other tools to still provide value
    return [];
  }
}

/**
 * Format clinical trial results for Gemini consumption
 */
export function formatClinicalTrialsForAI(trials: ClinicalTrialResult[]): string {
  if (trials.length === 0) {
    return 'No clinical trials found for the specified criteria.';
  }

  return trials.map((trial, index) => {
    const parts = [
      `${index + 1}. ${trial.title}`,
      `   NCT ID: ${trial.nctId}`,
      `   Status: ${trial.status}`,
      trial.phase ? `   Phase: ${trial.phase}` : null,
      trial.enrollmentCount ? `   Enrollment: ${trial.enrollmentCount} participants` : null,
      `   Conditions: ${trial.conditions.join(', ')}`,
      trial.interventions.length > 0 ? `   Interventions: ${trial.interventions.join(', ')}` : null,
      `   Summary: ${trial.summary.slice(0, 300)}${trial.summary.length > 300 ? '...' : ''}`,
      `   URL: ${trial.url}`
    ].filter(Boolean);

    return parts.join('\n');
  }).join('\n\n');
}
