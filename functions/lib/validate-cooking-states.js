"use strict";
//
// validate-cooking-states.ts
// Tests if EDAMAM recognizes cooking states with English terms
// Critical test to determine if Turkish "pişmiş/ızgara" issue is fixable
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
// EDAMAM API Configuration
const EDAMAM_APP_ID = process.env.EDAMAM_APP_ID;
const EDAMAM_APP_KEY = process.env.EDAMAM_APP_KEY;
const EDAMAM_BASE_URL = 'https://api.edamam.com/api/nutrition-details';
// Test dataset with known USDA ground truth values
const TEST_INGREDIENTS = [
    {
        name: 'Red Lentils',
        input: '200g red lentils, cooked',
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
        input: '200g whole wheat pasta, cooked',
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
        input: '200g chicken breast, grilled',
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
        input: '200g white rice, cooked',
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
        input: '200g salmon, cooked',
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
        input: '200g turkey breast, grilled',
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
 * Test single ingredient with EDAMAM
 */
async function testWithEdamam(ingredientInput) {
    if (!EDAMAM_APP_ID || !EDAMAM_APP_KEY) {
        throw new Error('EDAMAM credentials not configured');
    }
    console.log(`🧪 Testing: ${ingredientInput}`);
    try {
        const edamamUrl = `${EDAMAM_BASE_URL}?app_id=${EDAMAM_APP_ID}&app_key=${EDAMAM_APP_KEY}`;
        const response = await fetch(edamamUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept-Language': 'en'
            },
            body: JSON.stringify({
                title: 'Test Recipe',
                ingr: [ingredientInput]
            })
        });
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`❌ Error ${response.status}: ${errorText}`);
            return null;
        }
        const data = await response.json();
        // Calculate per 100g nutrition
        const totalWeight = data.totalWeight || 1;
        const per100gFactor = 100 / totalWeight;
        const nutrition = {
            calories: Math.round((data.calories || 0) * per100gFactor),
            carbs: Math.round((data.totalNutrients?.CHOCDF?.quantity || 0) * per100gFactor),
            protein: Math.round((data.totalNutrients?.PROCNT?.quantity || 0) * per100gFactor),
            fat: Math.round((data.totalNutrients?.FAT?.quantity || 0) * per100gFactor)
        };
        console.log(`✅ Result:`, nutrition);
        return nutrition;
    }
    catch (error) {
        console.error(`❌ Exception:`, error);
        return null;
    }
}
/**
 * Determine if EDAMAM returned cooked or raw values
 * Uses distance metric to compare against both ground truths
 */
function determineCookingState(edamam, cooked, raw) {
    // Calculate distance from cooked values
    const distanceToCooked = Math.sqrt(Math.pow(edamam.carbs - cooked.carbs, 2) +
        Math.pow(edamam.protein - cooked.protein, 2) +
        Math.pow(edamam.fat - cooked.fat, 2));
    // Calculate distance from raw values
    const distanceToRaw = Math.sqrt(Math.pow(edamam.carbs - raw.carbs, 2) +
        Math.pow(edamam.protein - raw.protein, 2) +
        Math.pow(edamam.fat - raw.fat, 2));
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
function calculateErrors(edamam, groundTruth) {
    const calcError = (actual, expected) => {
        if (expected === 0)
            return actual === 0 ? 0 : 100;
        return ((actual - expected) / expected) * 100;
    };
    return {
        carbs: calcError(edamam.carbs, groundTruth.carbs),
        protein: calcError(edamam.protein, groundTruth.protein),
        fat: calcError(edamam.fat, groundTruth.fat)
    };
}
/**
 * Run the cooking state validation test
 */
async function runTest() {
    console.log('='.repeat(70));
    console.log('🧪 EDAMAM COOKING STATE VALIDATION TEST');
    console.log('Testing if English cooking terms are recognized correctly');
    console.log('='.repeat(70));
    console.log();
    const results = [];
    for (const ingredient of TEST_INGREDIENTS) {
        console.log('-'.repeat(70));
        console.log(`Testing: ${ingredient.name}`);
        console.log(`Input: "${ingredient.input}"`);
        const edamam = await testWithEdamam(ingredient.input);
        if (!edamam) {
            results.push({
                ingredient: ingredient.name,
                input: ingredient.input,
                recognized: false,
                edamam_per_100g: null,
                usda_ground_truth_cooked: ingredient.usda_cooked,
                usda_ground_truth_raw: ingredient.usda_raw,
                cooking_state_recognized: 'UNKNOWN',
                error_percent: null,
                status: '❌ FAILED - Not recognized by EDAMAM'
            });
            continue;
        }
        // Determine if it returned cooked or raw values
        const cookingState = determineCookingState(edamam, ingredient.usda_cooked, ingredient.usda_raw);
        // Calculate errors against expected cooked values
        const errors = calculateErrors(edamam, ingredient.usda_cooked);
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
            const carbMultiplier = (edamam.carbs / ingredient.usda_cooked.carbs).toFixed(1);
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
            edamam_per_100g: edamam,
            usda_ground_truth_cooked: ingredient.usda_cooked,
            usda_ground_truth_raw: ingredient.usda_raw,
            cooking_state_recognized: cookingState,
            error_percent: errors,
            status
        });
        // Small delay between requests
        await new Promise(resolve => setTimeout(resolve, 2000));
    }
    // Calculate summary
    const totalTests = results.length;
    const recognizedCount = results.filter(r => r.recognized).length;
    const cookedCorrect = results.filter(r => r.cooking_state_recognized === 'COOKED').length;
    const rawWrong = results.filter(r => r.cooking_state_recognized === 'RAW').length;
    const successRate = ((cookedCorrect / totalTests) * 100).toFixed(0);
    // Determine decision
    let decision;
    let recommendation;
    if (cookedCorrect >= totalTests * 0.85) {
        decision = 'FIXABLE';
        recommendation = '🚀 BUILD TRANSLATION LAYER - English works, Turkish doesn\'t';
    }
    else if (cookedCorrect >= totalTests * 0.60) {
        decision = 'CONDITIONAL';
        recommendation = '⚠️ MIXED RESULTS - Translation helps but not perfect';
    }
    else {
        decision = 'UNFIXABLE';
        recommendation = '❌ DO NOT SHIP - EDAMAM cooking state recognition fundamentally broken';
    }
    const report = {
        test_date: new Date().toISOString(),
        test_type: 'English Cooking Terms Validation',
        results,
        summary: {
            total_tests: totalTests,
            recognized: recognizedCount,
            cooking_state_correct: cookedCorrect,
            cooking_state_wrong: rawWrong,
            success_rate: `${successRate}%`,
            decision
        },
        decision_logic: {
            if_english_success_rate_above_85: 'SHIP - Build Turkish→English translation layer',
            if_english_success_rate_60_to_85: 'CONDITIONAL - Translation helps but not perfect',
            if_english_success_rate_below_60: 'DO NOT SHIP - Edamam cooking state recognition fundamentally broken'
        },
        recommendation
    };
    // Print summary
    console.log('='.repeat(70));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Tests: ${totalTests}`);
    console.log(`Recognized: ${recognizedCount}/${totalTests}`);
    console.log(`Cooking State Correct: ${cookedCorrect}/${totalTests}`);
    console.log(`Cooking State Wrong (Raw): ${rawWrong}/${totalTests}`);
    console.log(`Success Rate: ${successRate}%`);
    console.log();
    console.log(`Decision: ${decision}`);
    console.log(`Recommendation: ${recommendation}`);
    console.log('='.repeat(70));
    // Save report
    const outputPath = path.join(__dirname, '..', 'edamam_cooking_state_validation.json');
    fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
    console.log(`\n📁 Full report saved to: ${outputPath}`);
}
// Run the test
runTest().catch(console.error);
//# sourceMappingURL=validate-cooking-states.js.map