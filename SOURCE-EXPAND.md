# Task: Improve Medical Research Sources Configuration

## Context
I'm building a diabetes health app with 3 research tiers. Currently using Exa, PubMed, arXiv, and ClinicalTrials APIs. Need to improve source quality and relevance for diabetes research.

## Current Issues
1. Missing key diabetes-specific sources
2. Using arXiv (irrelevant for medical research)
3. PubMed count too low (only 5 results)
4. No date filtering for recency
5. Missing evidence synthesis sources (Cochrane)

## Required Changes

### 1. Update Trusted Medical Domains Array
Location: Likely in `exa-search.ts` or a config file

**Find this array:**
```typescript
TRUSTED_MEDICAL_DOMAINS = [
  'mayoclinic.org',
  'diabetes.org',
  'joslin.org',
  'clevelandclinic.org',
  'hopkinsmedicine.org',
  'jdrf.org',
  'cdc.gov',
  'who.int',
  'nih.gov',
  'endocrine.org',
  'diabetesjournals.org'
]
```

**Replace with this expanded list:**
```typescript
const TRUSTED_MEDICAL_DOMAINS = [
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
  'diabetesed.net',      // Barbara Davis Center - NEW
  'beyondtype1.org',     // T1D education - NEW
  'diatribe.org',        // Diabetes news & devices - NEW

  // International Organizations (⭐⭐)
  'idf.org',             // International Diabetes Federation - NEW
  'easd.org',            // European diabetes org - NEW

  // Peer-Reviewed Journals (⭐⭐⭐)
  'diabetesjournals.org',
  'endocrine.org',

  // Evidence Synthesis (⭐⭐⭐)
  'cochranelibrary.com'  // Systematic reviews - NEW
];
```

### 2. Replace arXiv with medRxiv
Location: `parallel-research-fetcher.ts` or similar

**Current code probably looks like:**
```typescript
async function searchArxiv(query: string, limit: number) {
  // arXiv implementation
}
```

**Replace with medRxiv implementation:**
```typescript
interface MedRxivResult {
  title: string;
  authors: string;
  abstract: string;
  date: string;
  doi: string;
  url: string;
  category: string;
}

async function searchMedRxiv(
  query: string,
  limit: number = 3,
  minDate: string = '2023-01-01'
): Promise<MedRxivResult[]> {
  try {
    const baseUrl = 'https://api.biorxiv.org/details/medrxiv';
    const searchUrl = `${baseUrl}/${encodeURIComponent(query)}/na/na/na/na/${limit}/json`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000);

    const response = await fetch(searchUrl, {
      signal: controller.signal,
      headers: { 'User-Agent': 'DiabetesHealthApp/1.0' }
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      console.error(`medRxiv API error: ${response.status}`);
      return [];
    }

    const data = await response.json();

    if (!data.collection || data.collection.length === 0) {
      return [];
    }

    // Filter by date
    let results = data.collection;
    if (minDate) {
      results = results.filter((item: any) =>
        new Date(item.date) >= new Date(minDate)
      );
    }

    return results.slice(0, limit).map((item: any) => ({
      title: item.title,
      authors: item.authors,
      abstract: item.abstract,
      date: item.date,
      doi: item.doi,
      url: `https://www.medrxiv.org/content/${item.doi}`,
      category: item.category
    }));

  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      console.error('medRxiv search timeout');
    } else {
      console.error('medRxiv search error:', error);
    }
    return [];
  }
}
```

### 3. Update Tier 3 Source Counts
Location: `parallel-research-fetcher.ts` where you do `Promise.allSettled`

**Find code that looks like:**
```typescript
const [exaResults, pubmedResults, arxivResults, clinicalTrialsResults] =
  await Promise.allSettled([
    searchMedicalSources(translatedQuery, 10),
    searchPubMed(translatedQuery, 5),
    searchArxiv(translatedQuery, 5),
    searchClinicalTrials(translatedQuery, 5)
  ]);
```

**Update to:**
```typescript
const [exaResults, pubmedResults, medrxivResults, clinicalTrialsResults] =
  await Promise.allSettled([
    searchMedicalSources(translatedQuery, 10),
    searchPubMed(translatedQuery, 8),          // Increased from 5 to 8
    searchMedRxiv(translatedQuery, 3, '2023-01-01'),  // Replaced arXiv, only recent
    searchClinicalTrials(translatedQuery, 4)   // Reduced from 5 to 4
  ]);
```

**Update the return statement:**
```typescript
return {
  exa: exaResults.status === 'fulfilled' ? exaResults.value : [],
  pubmed: pubmedResults.status === 'fulfilled' ? pubmedResults.value : [],
  medrxiv: medrxivResults.status === 'fulfilled' ? medrxivResults.value : [], // Changed from arxiv
  clinicalTrials: clinicalTrialsResults.status === 'fulfilled' ? clinicalTrialsResults.value : []
};
```

### 4. Add Date Filtering to PubMed (if not already there)

**Find your PubMed function and add minDate parameter:**
```typescript
async function searchPubMed(
  query: string,
  limit: number,
  minDate: string = '2020-01-01'  // Add this parameter
) {
  // In your PubMed API query, add date filter
  // PubMed uses format: query AND ("2020/01/01"[Date - Publication] : "3000"[Date - Publication])
}
```

### 5. Update Clinical Trials Status Filter (if not already there)

**In your searchClinicalTrials function, filter by status:**
```typescript
async function searchClinicalTrials(query: string, limit: number) {
  // Add to your API parameters:
  const params = {
    'expr': query,
    'filter.overallStatus': ['RECRUITING', 'ACTIVE_NOT_RECRUITING', 'COMPLETED'],
    'pageSize': limit
  };
}
```

## Summary of Changes
- ✅ Added 6 new trusted medical domains (diabetes-specific + Cochrane)
- ✅ Replaced arXiv with medRxiv (actually relevant for medical research)
- ✅ Increased PubMed from 5 → 8 results (most valuable source)
- ✅ Added date filtering (PubMed: 2020+, medRxiv: 2023+)
- ✅ Added clinical trial status filtering
- ✅ New total: Still 25 sources (10 Exa + 8 PubMed + 3 medRxiv + 4 Clinical Trials)

## Expected Impact
- Better diabetes-specific content from specialized organizations
- More relevant preprints (medRxiv vs arXiv)
- More peer-reviewed research (8 vs 5 PubMed results)
- More recent research (date filtering)
- Higher quality evidence synthesis (Cochrane reviews)

## Testing
After implementation, test with query:
"CGM accuracy and reliability research"

Should return:
- Diabetes organization content (ADA, JDRF, diaTribe)
- Recent PubMed studies (2020+)
- Recent medRxiv preprints (2023+)
- Active/recent clinical trials
- No arXiv results (irrelevant for medical)
