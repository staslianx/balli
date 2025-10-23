// Quick test to verify the 3-tier system is working
require('dotenv').config();

const { diabetesAssistant } = require('./lib/diabetes-assistant');

async function quickTest() {
  console.log('🧪 Quick Diabetes Assistant Test\n');

  const testCases = [
    {
      tier: 1,
      question: "What is HbA1c?",
      description: "Tier 1: Direct Knowledge"
    },
    {
      tier: 2,
      question: "What are the best CGM devices in 2025?",
      description: "Tier 2: Web Search"
    }
  ];

  for (const test of testCases) {
    console.log(`\n${'='.repeat(80)}`);
    console.log(`📝 ${test.description}`);
    console.log(`❓ Question: "${test.question}"`);
    console.log('='.repeat(80));

    const startTime = Date.now();

    try {
      const result = await diabetesAssistant({
        question: test.question,
        userId: 'test-user-quick',
        diabetesProfile: {
          type: '2',
          diagnosisYear: 2020,
          medications: ['metformin']
        }
      });

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      console.log(`\n✅ SUCCESS (${duration}s)`);
      console.log(`   Tier: ${result.tier}`);
      console.log(`   Confidence: ${result.confidence}`);
      console.log(`   Answer: ${result.answer.substring(0, 200)}...`);
      console.log(`   Sources: ${result.sources?.length || 0}`);

    } catch (error) {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`\n❌ FAILED (${duration}s)`);
      console.log(`   Error: ${error.message}`);
    }
  }

  console.log('\n' + '='.repeat(80));
  console.log('✅ Quick test completed!');
  console.log('='.repeat(80));
}

quickTest().catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
