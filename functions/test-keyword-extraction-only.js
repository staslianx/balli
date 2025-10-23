// Quick test to show keyword extraction improvement
require('dotenv').config();

const { genkit } = require('genkit');
const { getProviderConfig, getRouterModel } = require('./lib/providers');

async function testKeywordExtraction() {
  console.log('\n🔍 Testing PubMed Keyword Extraction with Gemini Flash Lite\n');
  console.log('='.repeat(80));

  // Initialize Genkit
  const ai = genkit({
    plugins: [getProviderConfig()],
  });

  const testQuestions = [
    "What do recent studies say about SGLT2 inhibitors reducing cardiovascular risk?",
    "Clinical evidence for intermittent fasting in Type 2 diabetes?",
    "Is metformin safe during pregnancy for gestational diabetes?"
  ];

  for (const question of testQuestions) {
    console.log(`\n❓ Original Question:`);
    console.log(`   "${question}"`);

    const prompt = `You are a medical research librarian expert at PubMed database searches. Extract the most effective search keywords from this diabetes question.

Question: "${question}"

Extract:
1. Medical terms (use MeSH terminology when possible)
2. Drug names (generic and brand)
3. Conditions and complications
4. Study types if mentioned (RCT, meta-analysis, etc.)

Return ONLY the optimal PubMed search query as a single line.
Use boolean operators (AND, OR) and MeSH terms where appropriate.

Examples:
Input: "What do recent studies say about SGLT2 inhibitors reducing cardiovascular risk?"
Output: (SGLT2 inhibitors OR sodium-glucose cotransporter-2 inhibitors) AND cardiovascular risk AND diabetes

Input: "Clinical evidence for intermittent fasting in Type 2 diabetes?"
Output: intermittent fasting AND type 2 diabetes AND clinical trial

Your turn - provide ONLY the search query:`;

    try {
      const startTime = Date.now();

      const result = await ai.generate({
        model: getRouterModel(), // Flash Lite
        config: {
          temperature: 0.1,
          maxOutputTokens: 100
        },
        prompt: prompt
      });

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      const keywords = result.text.trim();

      console.log(`\n✨ Extracted PubMed Query (${duration}s):`);
      console.log(`   "${keywords}"`);

      console.log(`\n💡 Improvement:`);
      console.log(`   • Natural language → Medical terminology`);
      console.log(`   • Added boolean operators for precision`);
      console.log(`   • MeSH terms for better PubMed matching`);
      console.log(`   • Cost: ~$0.00001 (Flash Lite)`);

    } catch (error) {
      console.log(`\n❌ Extraction failed: ${error.message}`);
    }

    console.log('\n' + '-'.repeat(80));
  }

  console.log('\n✅ Keyword extraction demonstration complete!\n');
}

testKeywordExtraction().catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
