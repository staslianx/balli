//
// medRxiv API Integration
// Search medRxiv preprint repository for medical and health sciences research
//

import axios from 'axios';

export interface MedRxivResult {
  title: string;
  authors: string;
  abstract: string;
  date: string; // Publication date (YYYY-MM-DD)
  doi: string;
  url: string;
  category: string; // e.g., "Diabetes and Endocrinology"
  version: number;
}

/**
 * Search medRxiv for medical preprints
 * API Documentation: https://api.biorxiv.org/
 *
 * medRxiv is specifically for medical research preprints,
 * making it far more relevant than arXiv for diabetes research
 */
export async function searchMedRxiv(
  query: string,
  maxResults: number = 3,
  minDate: string = '2023-01-01' // Only recent preprints (last 2 years)
): Promise<MedRxivResult[]> {
  try {
    console.log(`🔬 [MEDRXIV] Searching for: ${query} (since ${minDate})`);

    // medRxiv API endpoint
    // Format: /details/server/query/cursor/format
    const baseUrl = 'https://api.biorxiv.org/details/medrxiv';
    const searchUrl = `${baseUrl}/${encodeURIComponent(query)}/na/na/na/na/${maxResults * 2}/json`;

    // Use axios with timeout
    const response = await axios.get(searchUrl, {
      timeout: 3000, // 3 second timeout for reliability
      headers: {
        'User-Agent': 'DiabetesHealthApp/1.0'
      }
    });

    if (response.status !== 200) {
      console.error(`❌ [MEDRXIV] API error: ${response.status}`);
      return [];
    }

    const data = response.data;

    if (!data.collection || data.collection.length === 0) {
      console.log(`📭 [MEDRXIV] No preprints found for query: ${query}`);
      return [];
    }

    // Filter by date
    let results = data.collection;
    if (minDate) {
      const cutoffDate = new Date(minDate);
      results = results.filter((item: any) => {
        const itemDate = new Date(item.date);
        return itemDate >= cutoffDate;
      });
    }

    // Transform and limit results
    const papers: MedRxivResult[] = results.slice(0, maxResults).map((item: any) => ({
      title: item.title || 'Untitled',
      authors: item.authors || 'Unknown Authors',
      abstract: item.abstract || 'No abstract available',
      date: item.date || '',
      doi: item.doi || '',
      url: `https://www.medrxiv.org/content/${item.doi}`,
      category: item.category || 'Medical Research',
      version: item.version || 1
    }));

    console.log(`✅ [MEDRXIV] Retrieved ${papers.length} preprints (filtered by date: ${minDate})`);

    return papers;

  } catch (error: any) {
    if (error.code === 'ECONNABORTED' || error.message?.includes('timeout')) {
      console.error(`⏱️ [MEDRXIV] Search timeout after 3000ms`);
    } else {
      console.error(`❌ [MEDRXIV] Search failed:`, error.message);
    }

    // Return empty array on error for graceful degradation
    return [];
  }
}

/**
 * Format medRxiv results for Gemini consumption
 */
export function formatMedRxivForAI(papers: MedRxivResult[]): string {
  if (papers.length === 0) {
    return 'No medRxiv preprints found for the specified query.';
  }

  return '📄 medRxiv Preprints (Medical Research):\n\n' + papers.map((paper, index) => {
    const parts = [
      `${index + 1}. ${paper.title}`,
      `   DOI: ${paper.doi}`,
      `   Authors: ${paper.authors}`,
      `   Published: ${paper.date}`,
      `   Category: ${paper.category}`,
      `   Abstract: ${paper.abstract.slice(0, 400)}${paper.abstract.length > 400 ? '...' : ''}`,
      `   URL: ${paper.url}`
    ].filter(Boolean);

    return parts.join('\n');
  }).join('\n\n');
}
