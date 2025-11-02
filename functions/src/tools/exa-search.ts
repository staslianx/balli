//
// Exa API Integration
// Semantic web search for medical sources and general information
//

import Exa from 'exa-js';

// Initialize Exa client
const exaApiKey = process.env.EXA_API_KEY;
if (!exaApiKey) {
  console.warn('⚠️ [EXA] EXA_API_KEY not configured - searches will fail');
}
const exa = new Exa(exaApiKey || '');

export interface ExaSearchResult {
  id: string;
  title: string;
  url: string;
  domain: string;
  publishedDate: string | null;
  author: string | null;
  snippet: string; // Text excerpt
  highlights: string[]; // Highlighted relevant sentences
  credibilityLevel: 'medical_institution' | 'peer_reviewed' | 'expert_authored' | 'general';
}

/**
 * Trusted medical domains for Pro tier medical research
 */
export const TRUSTED_MEDICAL_DOMAINS = [
  // Medical Institutions (⭐⭐⭐)
  'mayoclinic.org',
  'clevelandclinic.org',
  'hopkinsmedicine.org',
  'cdc.gov',
  'nih.gov',
  'who.int',

  // Diabetes-Specific Organizations (⭐⭐⭐)
  'diabetes.org',        // American Diabetes Association
  'joslin.org',          // Joslin Diabetes Center
  'jdrf.org',            // Type 1 Diabetes Research
  'diabetesed.net',      // Barbara Davis Center
  'beyondtype1.org',     // Type 1 Diabetes education
  'diatribe.org',        // Diabetes news & devices

  // International Organizations (⭐⭐)
  'idf.org',             // International Diabetes Federation
  'easd.org',            // European Association for the Study of Diabetes

  // Peer-Reviewed Journals (⭐⭐⭐)
  'diabetesjournals.org',
  'endocrine.org',

  // Evidence Synthesis (⭐⭐⭐)
  'cochranelibrary.com'  // Systematic reviews
];

/**
 * Search Exa for medical sources (Pro tier)
 * Restricted to trusted medical domains
 */
export async function searchMedicalSources(
  query: string,
  numResults: number = 8
): Promise<ExaSearchResult[]> {
  const startTime = Date.now();

  try {
    console.log(`\n┌─ EXA MEDICAL SEARCH ──────────────────────────────────────────────────────┐`);
    console.log(`🏥 [EXA-MEDICAL] Starting search...`);
    console.log(`   • Query: "${query}"`);
    console.log(`   • Target results: ${numResults}`);
    console.log(`   • Search type: Neural (semantic)`);
    console.log(`   • Trusted domains: ${TRUSTED_MEDICAL_DOMAINS.length} domains`);
    console.log(`   • Text extraction: 500 chars max`);
    console.log(`   • Highlights: 3 sentences per result`);

    const response = await exa.searchAndContents(query, {
      type: 'neural', // Semantic search for better medical context
      numResults,
      includeDomains: TRUSTED_MEDICAL_DOMAINS,
      text: { maxCharacters: 500 },
      highlights: { numSentences: 3 }
    });

    const duration = Date.now() - startTime;

    console.log(`\n✅ [EXA-MEDICAL] Search complete:`);
    console.log(`   • Results found: ${response.results.length}`);
    console.log(`   • Duration: ${duration}ms`);

    const processed = response.results.map((result: any) => {
      const domain = new URL(result.url).hostname.replace('www.', '');
      const credibilityLevel = determineCredibilityLevel(domain);

      return {
        id: result.id || result.url,
        title: result.title || 'Untitled',
        url: result.url,
        domain,
        publishedDate: result.publishedDate || null,
        author: result.author || null,
        snippet: result.text?.substring(0, 300) || '',
        highlights: result.highlights || [],
        credibilityLevel
      };
    });

    // Log credibility breakdown
    const credibilityCounts = processed.reduce((acc, r) => {
      acc[r.credibilityLevel] = (acc[r.credibilityLevel] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    console.log(`\n📊 [EXA-MEDICAL] Source credibility breakdown:`);
    if (credibilityCounts['medical_institution']) {
      console.log(`   • Medical institutions ⭐⭐⭐: ${credibilityCounts['medical_institution']}`);
    }
    if (credibilityCounts['peer_reviewed']) {
      console.log(`   • Peer-reviewed ⭐⭐: ${credibilityCounts['peer_reviewed']}`);
    }
    if (credibilityCounts['expert_authored']) {
      console.log(`   • Expert-authored ⭐: ${credibilityCounts['expert_authored']}`);
    }
    if (credibilityCounts['general']) {
      console.log(`   • General sources: ${credibilityCounts['general']}`);
    }

    // Log top 5 results
    if (processed.length > 0) {
      console.log(`\n📚 [EXA-MEDICAL] Top results:`);
      processed.slice(0, 5).forEach((result, idx) => {
        console.log(`   ${idx + 1}. ${result.title.substring(0, 70)}${result.title.length > 70 ? '...' : ''}`);
        console.log(`      Domain: ${result.domain} | Credibility: ${formatCredibilityLevel(result.credibilityLevel)}`);
        if (result.publishedDate) {
          console.log(`      Published: ${result.publishedDate}`);
        }
      });
    }

    console.log(`└───────────────────────────────────────────────────────────────────────────┘\n`);

    return processed;

  } catch (error: any) {
    const duration = Date.now() - startTime;
    console.error(`\n❌ [EXA-MEDICAL] Search failed after ${duration}ms:`);
    console.error(`   • Error: ${error.message}`);
    console.error(`   • Query: "${query}"`);
    console.log(`└───────────────────────────────────────────────────────────────────────────┘\n`);
    return [];
  }
}

/**
 * Search Exa for general web content (Flash tier)
 * Can search across all domains
 */
export async function searchGeneralWeb(
  query: string,
  numResults: number = 5,
  includeDomains?: string[],
  useAutoprompt: boolean = true
): Promise<ExaSearchResult[]> {
  try {
    console.log(`🔍 [EXA-GENERAL] Searching web for: "${query}"`);

    const searchOptions: any = {
      type: 'neural',
      numResults,
      text: { maxCharacters: 500 },
      useAutoprompt
    };

    // Add domain filtering if specified
    if (includeDomains && includeDomains.length > 0) {
      searchOptions.includeDomains = includeDomains;
    }

    const response = await exa.searchAndContents(query, searchOptions);

    return response.results.map((result: any) => {
      const domain = new URL(result.url).hostname.replace('www.', '');

      return {
        id: result.id || result.url,
        title: result.title || 'Untitled',
        url: result.url,
        domain,
        publishedDate: result.publishedDate || null,
        author: result.author || null,
        snippet: result.text?.substring(0, 300) || '',
        highlights: result.highlights || [],
        credibilityLevel: determineCredibilityLevel(domain)
      };
    });

  } catch (error: any) {
    console.error(`❌ [EXA-GENERAL] Search failed:`, error.message);
    return [];
  }
}

/**
 * Determine credibility level based on domain
 */
function determineCredibilityLevel(domain: string): 'medical_institution' | 'peer_reviewed' | 'expert_authored' | 'general' {
  // Medical institutions
  const medicalInstitutions = ['mayoclinic.org', 'clevelandclinic.org', 'hopkinsmedicine.org', 'cdc.gov', 'nih.gov', 'who.int'];
  if (medicalInstitutions.includes(domain)) {
    return 'medical_institution';
  }

  // Peer-reviewed/professional organizations (including new diabetes sources and Cochrane)
  const peerReviewed = [
    'diabetes.org', 'joslin.org', 'jdrf.org', 'endocrine.org', 'diabetesjournals.org',
    'diabetesed.net', 'beyondtype1.org', 'diatribe.org', 'idf.org', 'easd.org', 'cochranelibrary.com'
  ];
  if (peerReviewed.includes(domain)) {
    return 'peer_reviewed';
  }

  // Expert-authored sites
  const expertAuthored = ['healthline.com', 'webmd.com', 'verywellhealth.com'];
  if (expertAuthored.includes(domain)) {
    return 'expert_authored';
  }

  return 'general';
}

/**
 * Format Exa results for Gemini consumption
 */
export function formatExaForAI(results: ExaSearchResult[], isMedical: boolean = false): string {
  if (results.length === 0) {
    return 'No results found for the specified query.';
  }

  const prefix = isMedical ? '🏥 Medical Sources:' : '🔍 Web Sources:';

  return `${prefix}\n\n` + results.map((result, index) => {
    const parts = [
      `${index + 1}. ${result.title}`,
      `   Source: ${result.domain}`,
      `   Credibility: ${formatCredibilityLevel(result.credibilityLevel)}`,
      result.publishedDate ? `   Published: ${result.publishedDate}` : null,
      result.author ? `   Author: ${result.author}` : null,
      `   Excerpt: ${result.snippet}`,
      result.highlights.length > 0 ? `   Key Points: ${result.highlights.join(' | ')}` : null,
      `   URL: ${result.url}`
    ].filter(Boolean);

    return parts.join('\n');
  }).join('\n\n');
}

/**
 * Format credibility level for display
 */
function formatCredibilityLevel(level: string): string {
  const levelMap: Record<string, string> = {
    'medical_institution': 'Medical Institution ⭐⭐⭐',
    'peer_reviewed': 'Peer-Reviewed ⭐⭐',
    'expert_authored': 'Expert-Authored ⭐',
    'general': 'General Source'
  };

  return levelMap[level] || level;
}
