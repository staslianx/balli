// Test PubMed keyword extraction with Gemini Flash Lite
require('dotenv').config();

const { tier3MedicalResearch } = require('./lib/flows/tier3-flow');

async function testPubMedKeywordExtraction() {
  console.log('\n🧪 Testing PubMed Keyword Extraction with Flash Lite\n');
  console.log('='.repeat(80));

  const testQuestions = [
    {
      question: "What do recent studies say about SGLT2 inhibitors reducing cardiovascular risk?",
      expected: "Should extract: SGLT2 inhibitors, cardiovascular risk, diabetes"
    },
    {
      question: "Clinical evidence for intermittent fasting in Type 2 diabetes?",
      expected: "Should extract: intermittent fasting, Type 2 diabetes, clinical trial"
    },
    {
      question: "Is metformin safe during pregnancy for gestational diabetes?",
      expected: "Should extract: metformin, pregnancy, gestational diabetes, safety"
    }
  ];

  for (const test of testQuestions) {
    console.log(`\n📝 Question: "${test.question}"`);
    console.log(`📌 ${test.expected}`);
    console.log('-'.repeat(80));

    const startTime = Date.now();

    try {
      const result = await tier3MedicalResearch({
        question: test.question,
        userId: 'test-pubmed-keywords',
        diabetesProfile: {
          type: '2',
          diagnosisYear: 2020,
          medications: ['metformin']
        }
      });

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      console.log(`\n✅ Results (${duration}s):`);
      console.log(`   PubMed Articles: ${result.researchSummary.pubmedArticles}`);
      console.log(`   Clinical Trials: ${result.researchSummary.clinicalTrials}`);
      console.log(`   Total Studies: ${result.researchSummary.totalStudies}`);
      console.log(`   Evidence Quality: ${result.researchSummary.evidenceQuality}`);

      if (result.sources.length > 0) {
        console.log(`\n📚 Top Sources:`);
        result.sources.slice(0, 3).forEach((source, i) => {
          console.log(`   ${i + 1}. ${source.title}`);
          console.log(`      ${source.url}`);
        });
      }

    } catch (error) {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`\n❌ Failed (${duration}s): ${error.message}`);
    }

    console.log('\n' + '='.repeat(80));
  }

  console.log('\n✅ PubMed keyword extraction test completed!\n');
}

testPubMedKeywordExtraction().catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
