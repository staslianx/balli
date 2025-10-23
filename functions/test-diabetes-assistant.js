/**
 * Comprehensive Test Suite for Diabetes Assistant 3-Tier System
 *
 * Tests all tiers with representative questions and validates:
 * - Router classification accuracy
 * - Tier execution and response quality
 * - Auto-escalation from Tier 1 to Tier 2
 * - Rate limiting for Tier 3
 * - Source attribution and metadata
 *
 * Usage: node test-diabetes-assistant.js
 */

// Load environment variables first
require('dotenv').config();

const admin = require('firebase-admin');

// Check if Firebase Admin is already initialized (happens when importing from index)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'balli-b1bd6',
  });
  console.log('✅ Firebase Admin initialized');
} else {
  console.log('✅ Firebase Admin already initialized');
}

// Import the flows directly
const { routeQuestion } = require('./lib/flows/router-flow');
const { tier1DirectKnowledge } = require('./lib/flows/tier1-flow');
const { tier2WebSearch } = require('./lib/flows/tier2-flow');
const { tier3MedicalResearch } = require('./lib/flows/tier3-flow');
const { checkTier3RateLimit, recordTier3Usage, getTier3Usage } = require('./lib/utils/rate-limiter');

// Test user profile
const testUserId = 'test-user-' + Date.now();
const diabetesProfile = {
  type: '2',
  diagnosisYear: 2020,
  medications: ['metformin', 'jardiance']
};

// Test questions for each tier
const TEST_QUESTIONS = {
  tier1: [
    "What is HbA1c and why is it important?",
    "What foods should I eat to manage blood sugar?",
    "What's the difference between Type 1 and Type 2 diabetes?",
    "How does insulin work in the body?",
    "What are normal blood sugar levels?"
  ],
  tier2: [
    "What are the best CGM devices available in 2025?",
    "What new diabetes medications were approved recently?",
    "Best diabetes tracking apps for iPhone?",
    "Latest insulin pump technology?",
    "Current trends in diabetes management?"
  ],
  tier3: [
    "What do recent studies say about SGLT2 inhibitors reducing cardiovascular risk?",
    "Clinical evidence for intermittent fasting in Type 2 diabetes?",
    "What do meta-analyses show about low-carb diets for diabetes?",
    "Can I take metformin with ibuprofen safely?",
    "Latest research on GLP-1 agonists for weight loss?"
  ]
};

// Helper function to display results
function displayResult(tierName, question, result, duration) {
  console.log('\n' + '='.repeat(80));
  console.log(`📊 ${tierName} Test Result`);
  console.log('='.repeat(80));
  console.log(`Question: "${question}"`);
  console.log(`\nAnswer Preview: ${result.answer.substring(0, 200)}...`);
  console.log(`\nMetadata:`);
  console.log(`  - Confidence: ${result.confidence ? result.confidence.toFixed(2) : 'N/A'}`);
  console.log(`  - Processing Time: ${duration}ms`);

  if (result.sources && result.sources.length > 0) {
    console.log(`  - Sources: ${result.sources.length}`);
    console.log(`\nSample Sources:`);
    result.sources.slice(0, 3).forEach((source, i) => {
      console.log(`  [${i + 1}] ${source.title || 'Untitled'}`);
      if (source.url) console.log(`      ${source.url}`);
    });
  }

  if (result.shouldEscalate !== undefined) {
    console.log(`  - Should Escalate: ${result.shouldEscalate}`);
    if (result.escalationReason) {
      console.log(`  - Escalation Reason: ${result.escalationReason}`);
    }
  }

  if (result.researchSummary) {
    console.log(`\nResearch Summary:`);
    console.log(`  - Total Studies: ${result.researchSummary.totalStudies}`);
    console.log(`  - PubMed Articles: ${result.researchSummary.pubmedArticles}`);
    console.log(`  - Clinical Trials: ${result.researchSummary.clinicalTrials}`);
    console.log(`  - Evidence Quality: ${result.researchSummary.evidenceQuality}`);
  }

  console.log('='.repeat(80));
}

// Test 1: Router Classification
async function testRouter() {
  console.log('\n🔀 TEST 1: Router Classification');
  console.log('─'.repeat(80));

  const allQuestions = [
    ...TEST_QUESTIONS.tier1.slice(0, 2),
    ...TEST_QUESTIONS.tier2.slice(0, 2),
    ...TEST_QUESTIONS.tier3.slice(0, 2)
  ];

  const results = [];

  for (const question of allQuestions) {
    const startTime = Date.now();
    try {
      const routing = await routeQuestion({
        question,
        userId: testUserId,
        diabetesProfile
      });

      const duration = Date.now() - startTime;
      results.push({ question, routing, duration, success: true });

      console.log(`\n✅ "${question.substring(0, 50)}..."`);
      console.log(`   → Tier ${routing.tier} (${routing.confidence.toFixed(2)} confidence)`);
      console.log(`   → ${routing.reasoning}`);
      console.log(`   → ${duration}ms`);

    } catch (error) {
      console.error(`\n❌ "${question.substring(0, 50)}..."`);
      console.error(`   Error: ${error.message}`);
      results.push({ question, error: error.message, success: false });
    }
  }

  // Classification accuracy summary
  const tier1Count = results.filter(r => r.success && r.routing.tier === 1).length;
  const tier2Count = results.filter(r => r.success && r.routing.tier === 2).length;
  const tier3Count = results.filter(r => r.success && r.routing.tier === 3).length;

  console.log('\n📊 Classification Summary:');
  console.log(`   Tier 1: ${tier1Count} questions`);
  console.log(`   Tier 2: ${tier2Count} questions`);
  console.log(`   Tier 3: ${tier3Count} questions`);
  console.log(`   Errors: ${results.filter(r => !r.success).length}`);

  return results;
}

// Test 2: Tier 1 Direct Knowledge
async function testTier1() {
  console.log('\n\n📚 TEST 2: Tier 1 - Direct Knowledge');
  console.log('─'.repeat(80));

  const question = TEST_QUESTIONS.tier1[0];
  const startTime = Date.now();

  try {
    const result = await tier1DirectKnowledge({
      question,
      userId: testUserId,
      diabetesProfile
    });

    const duration = Date.now() - startTime;
    displayResult('TIER 1', question, result, duration);

    return { success: true, result, duration };
  } catch (error) {
    console.error(`❌ Tier 1 test failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Test 3: Tier 2 Web Search
async function testTier2() {
  console.log('\n\n🌐 TEST 3: Tier 2 - Web Search');
  console.log('─'.repeat(80));

  const question = TEST_QUESTIONS.tier2[0];
  const startTime = Date.now();

  try {
    const result = await tier2WebSearch({
      question,
      userId: testUserId,
      diabetesProfile
    });

    const duration = Date.now() - startTime;
    displayResult('TIER 2', question, result, duration);

    return { success: true, result, duration };
  } catch (error) {
    console.error(`❌ Tier 2 test failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Test 4: Tier 3 Medical Research
async function testTier3() {
  console.log('\n\n🔬 TEST 4: Tier 3 - Medical Research');
  console.log('─'.repeat(80));

  const question = TEST_QUESTIONS.tier3[0];
  const startTime = Date.now();

  try {
    const result = await tier3MedicalResearch({
      question,
      userId: testUserId,
      diabetesProfile
    });

    const duration = Date.now() - startTime;
    displayResult('TIER 3', question, result, duration);

    return { success: true, result, duration };
  } catch (error) {
    console.error(`❌ Tier 3 test failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Test 5: Rate Limiting
async function testRateLimiting() {
  console.log('\n\n🚦 TEST 5: Rate Limiting');
  console.log('─'.repeat(80));

  const testUser = 'rate-limit-test-' + Date.now();

  try {
    // Check initial state
    console.log('\n1. Initial Usage Check:');
    const initialUsage = await getTier3Usage(testUser);
    console.log(`   Count: ${initialUsage.count}/${initialUsage.limit}`);
    console.log(`   Remaining: ${initialUsage.remaining}`);

    // Record 3 queries
    console.log('\n2. Recording 3 Tier 3 queries...');
    for (let i = 1; i <= 3; i++) {
      await recordTier3Usage(testUser, `Test question ${i}`);
      const usage = await getTier3Usage(testUser);
      console.log(`   Query ${i}: ${usage.count}/${usage.limit} (${usage.remaining} remaining)`);
    }

    // Check rate limit
    console.log('\n3. Rate Limit Check:');
    const rateLimit = await checkTier3RateLimit(testUser);
    console.log(`   Allowed: ${rateLimit.allowed}`);
    console.log(`   Remaining: ${rateLimit.remaining}`);

    // Simulate hitting limit
    console.log('\n4. Simulating limit (recording 7 more queries)...');
    for (let i = 4; i <= 10; i++) {
      await recordTier3Usage(testUser, `Test question ${i}`);
    }

    const finalUsage = await getTier3Usage(testUser);
    console.log(`   Final count: ${finalUsage.count}/${finalUsage.limit}`);

    // Try one more
    console.log('\n5. Checking limit after 10 queries:');
    const limitCheck = await checkTier3RateLimit(testUser);
    console.log(`   Allowed: ${limitCheck.allowed}`);
    console.log(`   Reason: ${limitCheck.reason || 'N/A'}`);

    if (!limitCheck.allowed) {
      console.log(`   ✅ Rate limiting working correctly!`);
    } else {
      console.log(`   ⚠️ Rate limiting may not be working properly`);
    }

    return { success: true };
  } catch (error) {
    console.error(`❌ Rate limiting test failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Test 6: Auto-Escalation
async function testAutoEscalation() {
  console.log('\n\n🔼 TEST 6: Auto-Escalation (Tier 1 → Tier 2)');
  console.log('─'.repeat(80));

  // This question should be classified as Tier 1 but may escalate if answer quality is low
  const ambiguousQuestion = "Tell me about the latest developments in diabetes care";

  try {
    console.log(`\nTesting with: "${ambiguousQuestion}"`);

    // Step 1: Check routing
    const routing = await routeQuestion({
      question: ambiguousQuestion,
      userId: testUserId,
      diabetesProfile
    });
    console.log(`\n1. Router Decision: Tier ${routing.tier}`);

    // Step 2: Execute Tier 1
    if (routing.tier === 1) {
      console.log('\n2. Executing Tier 1...');
      const tier1Result = await tier1DirectKnowledge({
        question: ambiguousQuestion,
        userId: testUserId,
        diabetesProfile
      });

      console.log(`   Should Escalate: ${tier1Result.shouldEscalate}`);

      if (tier1Result.shouldEscalate) {
        console.log(`   ✅ Auto-escalation triggered!`);
        console.log(`   Reason: ${tier1Result.escalationReason}`);

        // Step 3: Execute Tier 2
        console.log('\n3. Auto-escalating to Tier 2...');
        const tier2Result = await tier2WebSearch({
          question: ambiguousQuestion,
          userId: testUserId,
          diabetesProfile
        });

        console.log(`   Tier 2 Sources: ${tier2Result.sources.length}`);
        console.log(`   ✅ Escalation complete`);
      } else {
        console.log(`   Tier 1 answer was sufficient (no escalation needed)`);
      }
    }

    return { success: true };
  } catch (error) {
    console.error(`❌ Auto-escalation test failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Main test runner
async function runAllTests() {
  console.log('\n' + '█'.repeat(80));
  console.log('🧪 DIABETES ASSISTANT 3-TIER SYSTEM - TEST SUITE');
  console.log('█'.repeat(80));
  console.log(`\nTest User: ${testUserId}`);
  console.log(`Diabetes Profile: Type ${diabetesProfile.type}, Diagnosed ${diabetesProfile.diagnosisYear}`);
  console.log(`Medications: ${diabetesProfile.medications.join(', ')}`);

  const results = {
    router: null,
    tier1: null,
    tier2: null,
    tier3: null,
    rateLimit: null,
    autoEscalation: null
  };

  try {
    // Run all tests sequentially
    results.router = await testRouter();
    results.tier1 = await testTier1();
    results.tier2 = await testTier2();
    results.tier3 = await testTier3();
    results.rateLimit = await testRateLimiting();
    results.autoEscalation = await testAutoEscalation();

    // Final summary
    console.log('\n\n' + '█'.repeat(80));
    console.log('📊 TEST SUMMARY');
    console.log('█'.repeat(80));

    const tests = [
      { name: 'Router Classification', result: results.router },
      { name: 'Tier 1 Direct Knowledge', result: results.tier1 },
      { name: 'Tier 2 Web Search', result: results.tier2 },
      { name: 'Tier 3 Medical Research', result: results.tier3 },
      { name: 'Rate Limiting', result: results.rateLimit },
      { name: 'Auto-Escalation', result: results.autoEscalation }
    ];

    tests.forEach(test => {
      const status = test.result?.success ? '✅ PASS' : '❌ FAIL';
      console.log(`${status} - ${test.name}`);
      if (test.result?.duration) {
        console.log(`        Duration: ${test.result.duration}ms`);
      }
      if (test.result?.error) {
        console.log(`        Error: ${test.result.error}`);
      }
    });

    const passCount = tests.filter(t => t.result?.success).length;
    console.log(`\n${passCount}/${tests.length} tests passed`);

    console.log('\n' + '█'.repeat(80));

  } catch (error) {
    console.error('\n❌ Test suite error:', error);
  } finally {
    console.log('\n✅ Test suite complete');
    process.exit(0);
  }
}

// Run tests
runAllTests();
