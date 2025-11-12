"use strict";
//
// validate-edamam.ts
// EDAMAM API Validation Script
// Validates EDAMAM accuracy against USDA ground truth
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
// Load environment variables from .env file
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const usda_client_1 = require("./utils/usda-client");
const statistical_analysis_1 = require("./utils/statistical-analysis");
// EDAMAM API Configuration
const EDAMAM_APP_ID = process.env.EDAMAM_APP_ID;
const EDAMAM_APP_KEY = process.env.EDAMAM_APP_KEY;
const EDAMAM_BASE_URL = 'https://api.edamam.com/api/nutrition-details';
/**
 * Core ingredients test dataset (15 ingredients)
 * From EDAMAM-VALIDATION-SPEC.md Section 2.1
 */
const CORE_INGREDIENTS = [
    // Carbohydrate Sources
    { turkish: '200g kırmızı mercimek, pişmiş', english: 'Lentils, pink or red, raw', category: 'carb' },
    { turkish: '200g bulgur, pişmiş', english: 'Bulgur, cooked', category: 'carb' },
    { turkish: '200g beyaz pirinç, pişmiş', english: 'Rice, white, long-grain, regular, cooked', category: 'carb' },
    { turkish: '200g kinoa, pişmiş', english: 'Quinoa, cooked', category: 'carb' },
    { turkish: '200g tam buğday makarna, pişmiş', english: 'Pasta, whole grain, 51% to 99% whole wheat, cooked', category: 'carb' },
    // Protein Sources (NOTE: turkey, shrimp, lobster excluded per user preference)
    { turkish: '200g tavuk göğsü, ızgara', english: 'Chicken, broilers or fryers, breast, skinless, boneless, meat only, cooked, grilled', category: 'protein' },
    { turkish: '200g somon balığı, pişmiş', english: 'Fish, salmon, Atlantic, wild, cooked, dry heat', category: 'protein' },
    { turkish: '200g yağsız dana eti, ızgara', english: 'Beef, loin, top sirloin cap steak, boneless, separable lean only, trimmed to 1/8" fat, all grades, cooked, grilled', category: 'protein' },
    { turkish: '200g tofu', english: 'Tofu, raw, regular, prepared with calcium sulfate', category: 'protein' },
    // Fat Sources
    { turkish: '2 yemek kaşığı zeytinyağı', english: 'Oil, olive, salad or cooking', category: 'fat' },
    { turkish: '50g fındık, çiğ', english: 'Nuts, hazelnuts or filberts', category: 'fat' },
    { turkish: '50g badem, çiğ', english: 'Nuts, almonds', category: 'fat' },
    { turkish: '1/4 avokado', english: 'Avocados, raw, all commercial varieties', category: 'fat' },
    { turkish: '2 yemek kaşığı fıstık ezmesi', english: 'Peanut butter, smooth style, with salt', category: 'fat' }
];
/**
 * Proof-of-concept test dataset (3 ingredients)
 */
const PROOF_OF_CONCEPT_INGREDIENTS = [
    { turkish: '200g tavuk göğsü, ızgara', english: 'Chicken, broilers or fryers, breast, skinless, boneless, meat only, cooked, grilled', category: 'protein' },
    { turkish: '200g bulgur, pişmiş', english: 'Bulgur, cooked', category: 'carb' },
    { turkish: '2 yemek kaşığı zeytinyağı', english: 'Oil, olive, salad or cooking', category: 'fat' }
];
/**
 * Test single ingredient with EDAMAM API
 */
async function testWithEdamam(turkishIngredient) {
    if (!EDAMAM_APP_ID || !EDAMAM_APP_KEY) {
        throw new Error('EDAMAM credentials not configured');
    }
    console.log(`🧪 [EDAMAM] Testing: ${turkishIngredient}`);
    try {
        const edamamUrl = `${EDAMAM_BASE_URL}?app_id=${EDAMAM_APP_ID}&app_key=${EDAMAM_APP_KEY}`;
        const response = await fetch(edamamUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Language': 'tr',
                'Accept-Language': 'tr'
            },
            body: JSON.stringify({
                title: 'Test Recipe',
                ingr: [turkishIngredient]
            })
        });
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`❌ [EDAMAM] Error ${response.status}: ${errorText}`);
            return null;
        }
        const data = await response.json();
        // Calculate per 100g nutrition
        const totalWeight = data.totalWeight || 1;
        const per100gFactor = 100 / totalWeight;
        const nutrition = {
            calories: Math.round((data.calories || 0) * per100gFactor),
            carbohydrates: Math.round((data.totalNutrients.CHOCDF?.quantity || 0) * per100gFactor),
            protein: Math.round((data.totalNutrients.PROCNT?.quantity || 0) * per100gFactor),
            fat: Math.round((data.totalNutrients.FAT?.quantity || 0) * per100gFactor),
            fiber: Math.round((data.totalNutrients.FIBTG?.quantity || 0) * per100gFactor),
            sugar: Math.round((data.totalNutrients.SUGAR?.quantity || 0) * per100gFactor)
        };
        console.log(`✅ [EDAMAM] Result:`, nutrition);
        return nutrition;
    }
    catch (error) {
        console.error(`❌ [EDAMAM] Exception:`, error);
        return null;
    }
}
/**
 * Calculate errors between ground truth and EDAMAM
 */
function calculateErrors(groundTruth, edamam) {
    return {
        calories: edamam.calories - groundTruth.calories,
        carbs: edamam.carbohydrates - groundTruth.carbohydrates,
        protein: edamam.protein - groundTruth.protein,
        fat: edamam.fat - groundTruth.fat
    };
}
/**
 * Run validation test
 */
async function runValidation(testIngredients, testType) {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`🧪 EDAMAM VALIDATION TEST: ${testType}`);
    console.log(`${'='.repeat(70)}\n`);
    const results = [];
    // Step 1: Fetch ground truth from USDA
    console.log(`📊 Step 1: Fetching ground truth from USDA (${testIngredients.length} ingredients)`);
    const usdaSearches = new Map(testIngredients.map(ing => [ing.turkish, ing.english]));
    const usdaResults = await (0, usda_client_1.batchSearchUSDA)(usdaSearches);
    // Step 2: Test with EDAMAM
    console.log(`\n🧪 Step 2: Testing with EDAMAM (Turkish ingredients)`);
    for (const ingredient of testIngredients) {
        console.log(`\n${'-'.repeat(70)}`);
        console.log(`Testing: ${ingredient.turkish}`);
        const groundTruth = usdaResults.get(ingredient.turkish) || null;
        const edamam = await testWithEdamam(ingredient.turkish);
        const result = {
            ingredient: ingredient.turkish,
            turkishName: ingredient.turkish,
            englishName: ingredient.english,
            category: ingredient.category,
            groundTruth,
            edamam,
            recognized: edamam !== null
        };
        if (groundTruth && edamam) {
            result.errors = calculateErrors(groundTruth, edamam);
            console.log(`📊 Errors:`, result.errors);
        }
        results.push(result);
        // Small delay between requests (be nice to EDAMAM API)
        await new Promise(resolve => setTimeout(resolve, 2000));
    }
    // Step 3: Statistical validation
    console.log(`\n📈 Step 3: Statistical Validation`);
    // Prepare data points for each nutrient type
    const validResults = results.filter(r => r.groundTruth && r.edamam);
    const carbsData = validResults.map(r => ({
        groundTruth: r.groundTruth.carbohydrates,
        edamam: r.edamam.carbohydrates,
        ingredient: r.ingredient
    }));
    const proteinData = validResults.map(r => ({
        groundTruth: r.groundTruth.protein,
        edamam: r.edamam.protein,
        ingredient: r.ingredient
    }));
    const fatData = validResults.map(r => ({
        groundTruth: r.groundTruth.fat,
        edamam: r.edamam.fat,
        ingredient: r.ingredient
    }));
    const statisticalValidation = {
        carbs: (0, statistical_analysis_1.performStatisticalValidation)(carbsData, 'carbs'),
        protein: (0, statistical_analysis_1.performStatisticalValidation)(proteinData, 'protein'),
        fat: (0, statistical_analysis_1.performStatisticalValidation)(fatData, 'fat')
    };
    // Step 4: Ship/Don't Ship Decision
    console.log(`\n🎯 Step 4: Ship/Don't Ship Decision`);
    const decision = makeShipDecision(results, statisticalValidation, testType);
    // Calculate metadata
    const usdaSuccessCount = results.filter(r => r.groundTruth !== null).length;
    const edamamRecognitionCount = results.filter(r => r.recognized).length;
    const report = {
        metadata: {
            testDate: new Date().toISOString(),
            testType,
            totalIngredients: testIngredients.length,
            usdaSuccessRate: (usdaSuccessCount / testIngredients.length) * 100,
            edamamRecognitionRate: (edamamRecognitionCount / testIngredients.length) * 100
        },
        ingredients: results,
        statisticalValidation,
        decision
    };
    return report;
}
/**
 * Make ship/don't ship decision based on validation results
 */
function makeShipDecision(results, stats, testType) {
    const reasoning = [];
    const conditions = [];
    let failureCount = 0;
    // Check carbohydrates (CRITICAL for diabetes)
    if (!stats.carbs.passesValidation) {
        failureCount++;
        reasoning.push(`❌ Carbohydrates FAILED validation`);
        stats.carbs.failureReasons.forEach(reason => reasoning.push(`   - ${reason}`));
    }
    else {
        reasoning.push(`✅ Carbohydrates PASSED validation (MAE: ${stats.carbs.mae.toFixed(1)}g, MAPE: ${stats.carbs.mape.toFixed(1)}%)`);
    }
    // Check protein
    if (!stats.protein.passesValidation) {
        failureCount++;
        reasoning.push(`⚠️ Protein FAILED validation`);
        stats.protein.failureReasons.forEach(reason => reasoning.push(`   - ${reason}`));
    }
    else {
        reasoning.push(`✅ Protein PASSED validation (MAPE: ${stats.protein.mape.toFixed(1)}%)`);
    }
    // Check fat
    if (!stats.fat.passesValidation) {
        failureCount++;
        reasoning.push(`⚠️ Fat FAILED validation`);
        stats.fat.failureReasons.forEach(reason => reasoning.push(`   - ${reason}`));
    }
    else {
        reasoning.push(`✅ Fat PASSED validation (MAPE: ${stats.fat.mape.toFixed(1)}%)`);
    }
    // Check recognition rate
    const recognitionRate = results.filter(r => r.recognized).length / results.length;
    if (recognitionRate < 0.85) {
        reasoning.push(`⚠️ Recognition rate ${(recognitionRate * 100).toFixed(0)}% below 85% threshold`);
        conditions.push('Monitor Turkish ingredient recognition in production');
    }
    // Proof-of-concept has lower requirements
    if (testType === 'proof-of-concept') {
        if (failureCount === 0) {
            return {
                recommendation: 'SHIP',
                confidence: 'MEDIUM',
                reasoning: [
                    ...reasoning,
                    '',
                    '✅ Proof-of-concept passed! Ready for full validation with 15 core ingredients.'
                ]
            };
        }
        else {
            return {
                recommendation: 'DO_NOT_SHIP',
                confidence: 'HIGH',
                reasoning: [
                    ...reasoning,
                    '',
                    '❌ Proof-of-concept failed. EDAMAM not suitable for production use.'
                ]
            };
        }
    }
    // Full validation decision logic
    if (failureCount === 0) {
        return {
            recommendation: 'SHIP',
            confidence: 'HIGH',
            reasoning: [
                ...reasoning,
                '',
                '🚀 RECOMMENDATION: SHIP TO PRODUCTION',
                '   All validation criteria passed. EDAMAM meets diabetes-specific accuracy requirements.'
            ],
            conditions: conditions.length > 0 ? conditions : undefined
        };
    }
    else if (failureCount === 1 && stats.carbs.passesValidation) {
        // If only protein or fat failed, but carbs passed (most critical for diabetes)
        return {
            recommendation: 'CONDITIONAL_SHIP',
            confidence: 'MEDIUM',
            reasoning: [
                ...reasoning,
                '',
                '⚠️ RECOMMENDATION: CONDITIONAL SHIP',
                '   Carbohydrate accuracy meets requirements (critical for insulin dosing).',
                '   Non-critical nutrients show room for improvement.'
            ],
            conditions: [
                ...conditions,
                'Add user disclaimer about protein/fat estimates',
                'Monitor and log nutrition calculation accuracy in production',
                'Consider user feedback mechanism for nutrition accuracy'
            ]
        };
    }
    else {
        return {
            recommendation: 'DO_NOT_SHIP',
            confidence: 'HIGH',
            reasoning: [
                ...reasoning,
                '',
                '❌ RECOMMENDATION: DO NOT SHIP',
                '   Critical validation failures detected. EDAMAM does not meet requirements.',
                failureCount > 1 ? '   Multiple nutrients failed validation.' : '',
                !stats.carbs.passesValidation ? '   Carbohydrate accuracy insufficient for insulin dosing.' : ''
            ].filter(Boolean)
        };
    }
}
/**
 * Main execution
 */
async function main() {
    const args = process.argv.slice(2);
    const isProofOfConcept = args.includes('--proof-of-concept') || args.includes('--poc');
    const isCoreIngredients = args.includes('--core-ingredients') || args.includes('--full');
    let testIngredients;
    let testType;
    let outputFileName;
    if (isProofOfConcept) {
        testIngredients = PROOF_OF_CONCEPT_INGREDIENTS;
        testType = 'proof-of-concept';
        outputFileName = 'edamam_validation_proof_of_concept.json';
    }
    else if (isCoreIngredients) {
        testIngredients = CORE_INGREDIENTS;
        testType = 'core-ingredients';
        outputFileName = 'edamam_validation_core_ingredients.json';
    }
    else {
        // Default to proof-of-concept
        testIngredients = PROOF_OF_CONCEPT_INGREDIENTS;
        testType = 'proof-of-concept';
        outputFileName = 'edamam_validation_proof_of_concept.json';
    }
    try {
        const report = await runValidation(testIngredients, testType);
        // Save report to JSON file
        const outputPath = path.join(__dirname, '..', outputFileName);
        fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
        // Print summary
        console.log(`\n${'='.repeat(70)}`);
        console.log(`📊 VALIDATION COMPLETE`);
        console.log(`${'='.repeat(70)}\n`);
        console.log(`Test Type: ${testType}`);
        console.log(`Ingredients Tested: ${report.metadata.totalIngredients}`);
        console.log(`USDA Success Rate: ${report.metadata.usdaSuccessRate.toFixed(0)}%`);
        console.log(`EDAMAM Recognition Rate: ${report.metadata.edamamRecognitionRate.toFixed(0)}%`);
        console.log(`\nStatistical Validation:`);
        console.log(`  Carbs:   MAE=${report.statisticalValidation.carbs.mae.toFixed(1)}g, MAPE=${report.statisticalValidation.carbs.mape.toFixed(1)}%, r=${report.statisticalValidation.carbs.pearsonR.toFixed(2)}`);
        console.log(`  Protein: MAE=${report.statisticalValidation.protein.mae.toFixed(1)}g, MAPE=${report.statisticalValidation.protein.mape.toFixed(1)}%, r=${report.statisticalValidation.protein.pearsonR.toFixed(2)}`);
        console.log(`  Fat:     MAE=${report.statisticalValidation.fat.mae.toFixed(1)}g, MAPE=${report.statisticalValidation.fat.mape.toFixed(1)}%, r=${report.statisticalValidation.fat.pearsonR.toFixed(2)}`);
        console.log(`\n📋 DECISION:`);
        console.log(`Recommendation: ${report.decision.recommendation}`);
        console.log(`Confidence: ${report.decision.confidence}`);
        console.log(`\nReasoning:`);
        report.decision.reasoning.forEach(line => console.log(line));
        if (report.decision.conditions) {
            console.log(`\nConditions:`);
            report.decision.conditions.forEach(condition => console.log(`  - ${condition}`));
        }
        console.log(`\n📁 Full report saved to: ${outputPath}`);
        console.log(`${'='.repeat(70)}\n`);
    }
    catch (error) {
        console.error(`❌ Validation failed:`, error);
        process.exit(1);
    }
}
// Run if executed directly
if (require.main === module) {
    main();
}
//# sourceMappingURL=validate-edamam.js.map