// Test Vertex AI configuration
require('dotenv').config();

async function testVertexAI() {
  console.log('\n🧪 Testing Vertex AI Configuration\n');
  console.log('='.repeat(60));

  // Check environment variables
  console.log('📋 Environment Variables:');
  console.log(`   USE_VERTEX_AI: ${process.env.USE_VERTEX_AI}`);
  console.log(`   GOOGLE_CLOUD_PROJECT_ID: ${process.env.GOOGLE_CLOUD_PROJECT_ID}`);
  console.log(`   EXA_API_KEY: ${process.env.EXA_API_KEY ? '✅ Set' : '❌ Missing'}`);
  console.log(`   EXASEARCH_API_KEY: ${process.env.EXASEARCH_API_KEY ? '✅ Set' : '❌ Missing'}`);

  console.log('\n' + '='.repeat(60));
  console.log('🔧 Loading Provider Configuration...\n');

  const { getProviderName, getModelReferences } = require('./lib/providers');

  const provider = getProviderName();
  const models = getModelReferences();

  console.log(`   Provider: ${provider}`);
  console.log(`   Router Model: ${models.router}`);
  console.log(`   Tier 1 Model: ${models.tier1}`);
  console.log(`   Tier 2 Model: ${models.tier2}`);
  console.log(`   Tier 3 Model: ${models.tier3}`);

  console.log('\n' + '='.repeat(60));

  if (provider === 'vertexai') {
    console.log('✅ Vertex AI Configured Successfully!');
    console.log('   - Context caching: Available');
    console.log('   - Cost savings: Up to 70%');
  } else {
    console.log('⚠️  Still using Google AI');
    console.log('   - Context caching: Not available');
  }

  console.log('='.repeat(60) + '\n');
}

testVertexAI().catch(error => {
  console.error('❌ Configuration test failed:', error);
  process.exit(1);
});
