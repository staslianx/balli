"use strict";
//
// validate-gemini-nutrition.ts
// Tests Gemini's nutrition calculation accuracy for cooked ingredients
// Direct comparison to EDAMAM cooking state test
//
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
// Load environment variables
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const generative_ai_1 = require("@google/generative-ai");
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
if (!GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY not configured');
}
const genAI = new generative_ai_1.GoogleGenerativeAI(GEMINI_API_KEY);
// Test dataset - same as cooking state validation
const TEST_INGREDIENTS = [
    {
        name: 'Red Lentils',
        input: 'red lentils, cooked',
        expected_state: 'cooked',
        usda_cooked: {
            calories: 116,
            carbs: 20.1,
            protein: 9.0,
            fat: 0.4
        },
        usda_raw: {
            calories: 358,
            carbs: 63.4,
            protein: 24.6,
            fat: 1.1
        }
    },
    {
        name: 'Whole Wheat Pasta',
        input: 'whole wheat pasta, cooked',
        expected_state: 'cooked',
        usda_cooked: {
            calories: 124,
            carbs: 26.5,
            protein: 5.3,
            fat: 1.4
        },
        usda_raw: {
            calories: 348,
            carbs: 75.0,
            protein: 14.6,
            fat: 2.5
        }
    },
    {
        name: 'Chicken Breast',
        input: 'chicken breast, grilled',
        expected_state: 'grilled',
        usda_cooked: {
            calories: 165,
            carbs: 0,
            protein: 31.0,
            fat: 3.6
        },
        usda_raw: {
            calories: 120,
            carbs: 0,
            protein: 22.5,
            fat: 2.6
        }
    },
    {
        name: 'White Rice',
        input: 'white rice, cooked',
        expected_state: 'cooked',
        usda_cooked: {
            calories: 130,
            carbs: 28.2,
            protein: 2.7,
            fat: 0.3
        },
        usda_raw: {
            calories: 365,
            carbs: 80.0,
            protein: 7.1,
            fat: 0.7
        }
    },
    {
        name: 'Salmon',
        input: 'salmon, cooked',
        expected_state: 'cooked',
        usda_cooked: {
            calories: 206,
            carbs: 0,
            protein: 25.4,
            fat: 10.5
        },
        usda_raw: {
            calories: 142,
            carbs: 0,
            protein: 19.8,
            fat: 6.3
        }
    },
    {
        name: 'Turkey Breast',
        input: 'turkey breast, grilled',
        expected_state: 'grilled',
        usda_cooked: {
            calories: 135,
            carbs: 0,
            protein: 30.1,
            fat: 0.7
        },
        usda_raw: {
            calories: 111,
            carbs: 0,
            protein: 24.0,
            fat: 1.7
        }
    }
];
/**
 * Ask Gemini to calculate nutrition for an ingredient
 */
async function askGemini(ingredientInput) {
    console.log(`🤖 Asking Gemini: ${ingredientInput}`);
    const prompt = `Calculate precise nutrition values per 100g for: ${ingredientInput}.

IMPORTANT: The ingredient is ${ingredientInput}. Make sure you calculate for the EXACT state specified (cooked, grilled, etc.), not raw.

Show your calculation work step by step.

Return in this exact JSON format:
{
  "calories": <number>,
  "carbs": <number>,
  "protein": <number>,
  "fat": <number>,
  "fiber": <number>,
  "calculation_notes": "<brief explanation of how you calculated this>"
}`;
    try {
        const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp' });
        const result = await model.generateContent(prompt);
        const response = result.response;
        const text = response.text();
        console.log(`📝 Gemini response:\n${text}\n`);
        // Try to extract JSON from response
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            console.error('❌ Could not extract JSON from response');
            return {
                success: false,
                nutrition: null,
                raw_response: text,
                calculation_shown: text.includes('calculation') || text.includes('step')
            };
        }
        const parsed = JSON.parse(jsonMatch[0]);
        const nutrition = {
            calories: Math.round(parsed.calories || 0),
            carbs: Math.round(parsed.carbs || parsed.carbohydrates || 0),
            protein: Math.round(parsed.protein || 0),
            fat: Math.round(parsed.fat || 0),
            fiber: parsed.fiber ? Math.round(parsed.fiber) : undefined
        };
        console.log(`✅ Parsed nutrition:`, nutrition);
        return {
            success: true,
            nutrition,
            raw_response: text,
            calculation_shown: !!parsed.calculation_notes || text.includes('calculation')
        };
    }
    catch (error) {
        console.error(`❌ Error calling Gemini:`, error);
        return {
            success: false,
            nutrition: null,
            raw_response: error instanceof Error ? error.message : String(error),
            calculation_shown: false
        };
    }
}
/**
 * Determine if Gemini returned cooked or raw values
 */
function determineCookingState(gemini, cooked, raw) {
    // Calculate distance from cooked values
    const distanceToCooked = Math.sqrt(Math.pow(gemini.carbs - cooked.carbs, 2) +
        Math.pow(gemini.protein - cooked.protein, 2) +
        Math.pow(gemini.fat - cooked.fat, 2));
    // Calculate distance from raw values
    const distanceToRaw = Math.sqrt(Math.pow(gemini.carbs - raw.carbs, 2) +
        Math.pow(gemini.protein - raw.protein, 2) +
        Math.pow(gemini.fat - raw.fat, 2));
    console.log(`   Distance to cooked: ${distanceToCooked.toFixed(1)}`);
    console.log(`   Distance to raw: ${distanceToRaw.toFixed(1)}`);
    // If both distances are very large, it's unknown
    if (distanceToCooked > 50 && distanceToRaw > 50) {
        return 'UNKNOWN';
    }
    // Return whichever is closer
    return distanceToCooked < distanceToRaw ? 'COOKED' : 'RAW';
}
/**
 * Calculate error percentages
 */
function calculateErrors(gemini, groundTruth) {
    const calcError = (actual, expected) => {
        if (expected === 0)
            return actual === 0 ? 0 : 100;
        return ((actual - expected) / expected) * 100;
    };
    return {
        carbs: calcError(gemini.carbs, groundTruth.carbs),
        protein: calcError(gemini.protein, groundTruth.protein),
        fat: calcError(gemini.fat, groundTruth.fat)
    };
}
/**
 * Run the Gemini validation test
 */
async function runTest() {
    console.log('='.repeat(70));
    console.log('🤖 GEMINI NUTRITION CALCULATION VALIDATION TEST');
    console.log('Testing Gemini 2.0 Flash accuracy for cooked ingredients');
    console.log('='.repeat(70));
    console.log();
    const results = [];
    for (const ingredient of TEST_INGREDIENTS) {
        console.log('-'.repeat(70));
        console.log(`Testing: ${ingredient.name}`);
        console.log(`Input: "${ingredient.input}"`);
        console.log();
        const geminiResponse = await askGemini(ingredient.input);
        if (!geminiResponse.success || !geminiResponse.nutrition) {
            results.push({
                ingredient: ingredient.name,
                input: ingredient.input,
                recognized: false,
                gemini_per_100g: null,
                gemini_raw_response: geminiResponse.raw_response,
                usda_ground_truth_cooked: ingredient.usda_cooked,
                usda_ground_truth_raw: ingredient.usda_raw,
                cooking_state_recognized: 'UNKNOWN',
                error_percent: null,
                status: '❌ FAILED - Gemini could not provide nutrition data'
            });
            continue;
        }
        // Determine if it returned cooked or raw values
        const cookingState = determineCookingState(geminiResponse.nutrition, ingredient.usda_cooked, ingredient.usda_raw);
        // Calculate errors against expected cooked values
        const errors = calculateErrors(geminiResponse.nutrition, ingredient.usda_cooked);
        // Determine status
        let status;
        if (cookingState === 'COOKED') {
            const maxError = Math.max(Math.abs(errors.carbs), Math.abs(errors.protein));
            if (maxError < 20) {
                status = `✅ SUCCESS - Returned cooked values (${maxError.toFixed(0)}% error)`;
            }
            else {
                status = `⚠️ PARTIAL - Cooked but ${maxError.toFixed(0)}% error`;
            }
        }
        else if (cookingState === 'RAW') {
            const carbMultiplier = ingredient.usda_cooked.carbs > 0
                ? (geminiResponse.nutrition.carbs / ingredient.usda_cooked.carbs).toFixed(1)
                : 'N/A';
            status = `❌ FAILED - Returned raw values (${carbMultiplier}× too high)`;
        }
        else {
            status = '⚠️ UNKNOWN - Values don\'t match either state';
        }
        console.log(`   Status: ${status}`);
        console.log();
        results.push({
            ingredient: ingredient.name,
            input: ingredient.input,
            recognized: true,
            gemini_per_100g: geminiResponse.nutrition,
            gemini_raw_response: geminiResponse.raw_response,
            usda_ground_truth_cooked: ingredient.usda_cooked,
            usda_ground_truth_raw: ingredient.usda_raw,
            cooking_state_recognized: cookingState,
            error_percent: errors,
            status
        });
        // Small delay between requests to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 3000));
    }
    // Calculate summary
    const totalTests = results.length;
    const recognizedCount = results.filter(r => r.recognized).length;
    const cookedCorrect = results.filter(r => r.cooking_state_recognized === 'COOKED').length;
    const rawWrong = results.filter(r => r.cooking_state_recognized === 'RAW').length;
    const successRate = ((cookedCorrect / totalTests) * 100).toFixed(0);
    // Calculate average errors for cooked items
    const cookedResults = results.filter(r => r.cooking_state_recognized === 'COOKED' && r.error_percent);
    const avgErrors = cookedResults.length > 0 ? {
        carbs: cookedResults.reduce((sum, r) => sum + Math.abs(r.error_percent.carbs), 0) / cookedResults.length,
        protein: cookedResults.reduce((sum, r) => sum + Math.abs(r.error_percent.protein), 0) / cookedResults.length,
        fat: cookedResults.reduce((sum, r) => sum + Math.abs(r.error_percent.fat), 0) / cookedResults.length
    } : null;
    // Compare to EDAMAM
    const edamamSuccessRate = 33; // From previous test
    const geminiVsEdamam = parseInt(successRate) - edamamSuccessRate;
    const comparison = geminiVsEdamam > 0 ? `+${geminiVsEdamam}%` : `${geminiVsEdamam}%`;
    // Determine decision
    let decision;
    let recommendation;
    if (cookedCorrect >= totalTests * 0.85) {
        decision = 'SHIP_GEMINI';
        recommendation = '🚀 GEMINI WINS - Use Gemini for nutrition calculations';
    }
    else if (cookedCorrect >= totalTests * 0.60) {
        decision = 'GEMINI_BETTER';
        recommendation = '✅ GEMINI BETTER THAN EDAMAM - Use with disclaimers';
    }
    else if (cookedCorrect > edamamSuccessRate / 100 * totalTests) {
        decision = 'GEMINI_SLIGHTLY_BETTER';
        recommendation = '⚠️ GEMINI SLIGHTLY BETTER - Both are poor';
    }
    else {
        decision = 'BOTH_POOR';
        recommendation = '❌ BOTH POOR - Need alternative solution';
    }
    const report = {
        test_date: new Date().toISOString(),
        test_type: 'Gemini 2.0 Flash Nutrition Calculation Validation',
        model: 'gemini-2.0-flash-exp',
        results,
        summary: {
            total_tests: totalTests,
            recognized: recognizedCount,
            cooking_state_correct: cookedCorrect,
            cooking_state_wrong: rawWrong,
            success_rate: `${successRate}%`,
            average_errors_for_cooked: avgErrors,
            decision
        },
        comparison_to_edamam: {
            edamam_success_rate: `${edamamSuccessRate}%`,
            gemini_success_rate: `${successRate}%`,
            difference: comparison,
            winner: parseInt(successRate) > edamamSuccessRate ? 'GEMINI' : 'EDAMAM'
        },
        recommendation
    };
    // Print summary
    console.log('='.repeat(70));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(70));
    console.log(`Model: Gemini 2.0 Flash Experimental`);
    console.log(`Total Tests: ${totalTests}`);
    console.log(`Recognized: ${recognizedCount}/${totalTests}`);
    console.log(`Cooking State Correct: ${cookedCorrect}/${totalTests}`);
    console.log(`Cooking State Wrong (Raw): ${rawWrong}/${totalTests}`);
    console.log(`Success Rate: ${successRate}%`);
    console.log();
    if (avgErrors) {
        console.log(`Average Errors (for cooked items):`);
        console.log(`  Carbs: ${avgErrors.carbs.toFixed(1)}%`);
        console.log(`  Protein: ${avgErrors.protein.toFixed(1)}%`);
        console.log(`  Fat: ${avgErrors.fat.toFixed(1)}%`);
        console.log();
    }
    console.log('='.repeat(70));
    console.log('🆚 COMPARISON TO EDAMAM');
    console.log('='.repeat(70));
    console.log(`EDAMAM Success Rate: ${edamamSuccessRate}%`);
    console.log(`Gemini Success Rate: ${successRate}%`);
    console.log(`Difference: ${comparison}`);
    console.log(`Winner: ${report.comparison_to_edamam.winner}`);
    console.log();
    console.log(`Decision: ${decision}`);
    console.log(`Recommendation: ${recommendation}`);
    console.log('='.repeat(70));
    // Save report
    const outputPath = path.join(__dirname, '..', 'gemini_nutrition_validation.json');
    fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
    console.log(`\n📁 Full report saved to: ${outputPath}`);
}
// Run the test
runTest().catch(console.error);
//# sourceMappingURL=validate-gemini-nutrition.js.map