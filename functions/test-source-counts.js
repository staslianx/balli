/**
 * Quick diagnostic test for T3 source count calculation
 * Run with: node test-source-counts.js
 */

// Simulate the query analysis for a general query
const queryAnalysis = {
  category: 'general',
  pubmedRatio: 0.55,
  medrxivRatio: 0.2,
  clinicalTrialsRatio: 0.25,
  confidence: 0.8
};

// Calculate source counts for Round 1 (15 API sources)
const apiSourceCount = 15;

const pubmedCount = Math.round(queryAnalysis.pubmedRatio * apiSourceCount);
const medrxivCount = Math.round(queryAnalysis.medrxivRatio * apiSourceCount);
let clinicalTrialsCount = Math.round(queryAnalysis.clinicalTrialsRatio * apiSourceCount);

// Adjust to ensure exact sum
const calculatedSum = pubmedCount + medrxivCount + clinicalTrialsCount;
const diff = apiSourceCount - calculatedSum;

if (diff !== 0) {
  clinicalTrialsCount += diff;
}

// Final config
const exaCount = 10;
const config = {
  exaCount: exaCount,
  pubmedCount: Math.max(0, pubmedCount),
  medrxivCount: Math.max(0, medrxivCount),
  clinicalTrialsCount: Math.max(0, clinicalTrialsCount)
};

const totalSources = config.exaCount + config.pubmedCount + config.medrxivCount + config.clinicalTrialsCount;

console.log('\n📊 T3 ROUND 1 SOURCE COUNT CALCULATION');
console.log('=====================================');
console.log(`\nQuery Analysis:`);
console.log(`  Category: ${queryAnalysis.category}`);
console.log(`  PubMed Ratio: ${(queryAnalysis.pubmedRatio * 100).toFixed(0)}%`);
console.log(`  medRxiv Ratio: ${(queryAnalysis.medrxivRatio * 100).toFixed(0)}%`);
console.log(`  Trials Ratio: ${(queryAnalysis.clinicalTrialsRatio * 100).toFixed(0)}%`);

console.log(`\nAPI Source Count (to distribute): ${apiSourceCount}`);

console.log(`\nCalculated Counts:`);
console.log(`  PubMed: ${pubmedCount} (${(queryAnalysis.pubmedRatio * 100).toFixed(0)}% of ${apiSourceCount})`);
console.log(`  medRxiv: ${medrxivCount} (${(queryAnalysis.medrxivRatio * 100).toFixed(0)}% of ${apiSourceCount})`);
console.log(`  Trials: ${clinicalTrialsCount} (${(queryAnalysis.clinicalTrialsRatio * 100).toFixed(0)}% of ${apiSourceCount}, adjusted for diff=${diff})`);

console.log(`\nFinal Config:`);
console.log(`  Exa: ${config.exaCount}`);
console.log(`  PubMed: ${config.pubmedCount}`);
console.log(`  medRxiv: ${config.medrxivCount}`);
console.log(`  ClinicalTrials: ${config.clinicalTrialsCount}`);

console.log(`\n✅ TOTAL SOURCES: ${totalSources}`);
console.log(`   Expected: 25`);
console.log(`   Status: ${totalSources === 25 ? '✅ CORRECT' : '❌ WRONG'}`);
console.log('');
