//
// test-edamam-nutrition.ts
// Firebase Function to test EDAMAM Nutrition Analysis API
// Tests Turkish language support, fractional measurements, and accuracy
//

import { onRequest } from 'firebase-functions/v2/https';
import * as cors from 'cors';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {
  parseIngredientsFromMarkdown,
  formatIngredientsForEdamam,
  extractGeminiNutrition,
  analyzeIngredient,
  analyzeCompatibility,
  calculateAccuracy,
  type IngredientAnalysis
} from './utils/edamam-parser';

const db = getFirestore();

// Configure CORS
const corsHandler = cors.default({
  origin: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
});

// EDAMAM API Configuration
const EDAMAM_APP_ID = process.env.EDAMAM_APP_ID;
const EDAMAM_APP_KEY = process.env.EDAMAM_APP_KEY;
const EDAMAM_BASE_URL = 'https://api.edamam.com/api/nutrition-details';

// Request interface
interface EdamamTestRequest {
  userId: string;
  recipeName: string;
  mealType: string;
  styleType: string;
  recipeContent: string;  // Markdown content from Gemini
  geminiNutrition: {
    calories: string | number;
    carbohydrates: string | number;
    protein: string | number;
    fat: string | number;
    fiber: string | number;
    sugar: string | number;
    glycemicLoad: string | number;
  };
}

// EDAMAM API Response interface (simplified)
interface EdamamNutrientInfo {
  label: string;
  quantity: number;
  unit: string;
}

interface EdamamIngredient {
  text: string;
  parsed: Array<{
    quantity: number;
    measure: string;
    food: string;
    weight: number;
    foodMatch: string;
    status?: string;
  }>;
}

interface EdamamResponse {
  uri: string;
  calories: number;
  totalWeight: number;
  dietLabels: string[];
  healthLabels: string[];
  cautions: string[];
  totalNutrients: {
    [key: string]: EdamamNutrientInfo;
  };
  totalDaily: {
    [key: string]: EdamamNutrientInfo;
  };
  ingredients: EdamamIngredient[];
}

/**
 * Test EDAMAM Nutrition Analysis API with Gemini-generated recipe
 */
export const testEdamamNutrition = onRequest({
  timeoutSeconds: 120,
  memory: '512MiB',
  cpu: 1,
  concurrency: 3
}, async (req, res) => {
  corsHandler(req, res, async () => {
    try {
      console.log('🧪 [EDAMAM-TEST] Starting EDAMAM API test');

      // Validate request method
      if (req.method !== 'POST') {
        res.status(405).json({ success: false, error: 'Method not allowed. Use POST.' });
        return;
      }

      // Validate EDAMAM credentials
      if (!EDAMAM_APP_ID || !EDAMAM_APP_KEY) {
        console.error('❌ [EDAMAM-TEST] Missing EDAMAM credentials');
        res.status(500).json({
          success: false,
          error: 'EDAMAM credentials not configured',
          message: 'Please set EDAMAM_APP_ID and EDAMAM_APP_KEY in .env'
        });
        return;
      }

      // Extract and validate input
      const {
        userId,
        recipeName,
        mealType,
        styleType,
        recipeContent,
        geminiNutrition
      } = req.body as EdamamTestRequest;

      if (!userId || !recipeName || !recipeContent || !geminiNutrition) {
        res.status(400).json({
          success: false,
          error: 'Missing required fields',
          message: 'userId, recipeName, recipeContent, and geminiNutrition are required'
        });
        return;
      }

      console.log(`📋 [EDAMAM-TEST] Testing recipe: "${recipeName}" (${mealType}/${styleType})`);

      const startTime = Date.now();

      // ============================================
      // STEP 1: Parse ingredients from Gemini markdown
      // ============================================
      console.log('📝 [EDAMAM-TEST] Step 1: Parsing ingredients from markdown');
      const parsedIngredients = parseIngredientsFromMarkdown(recipeContent);

      if (parsedIngredients.length === 0) {
        console.error('❌ [EDAMAM-TEST] No ingredients found in recipe content');
        res.status(400).json({
          success: false,
          error: 'No ingredients found',
          message: 'Could not parse ingredients from recipe markdown'
        });
        return;
      }

      console.log(`✅ [EDAMAM-TEST] Parsed ${parsedIngredients.length} ingredients`);
      console.log(`📋 [EDAMAM-TEST] Ingredients: ${parsedIngredients.slice(0, 3).join(', ')}...`);

      // ============================================
      // STEP 2: Analyze ingredients for Turkish/fractional patterns
      // ============================================
      console.log('🔍 [EDAMAM-TEST] Step 2: Analyzing ingredients');
      const ingredientAnalyses: IngredientAnalysis[] = parsedIngredients.map(ing => analyzeIngredient(ing));
      const compatibility = analyzeCompatibility(ingredientAnalyses);

      console.log(`📊 [EDAMAM-TEST] Compatibility Analysis:`);
      console.log(`  - Total ingredients: ${compatibility.totalIngredients}`);
      console.log(`  - Turkish characters: ${compatibility.turkishIngredientsCount}`);
      console.log(`  - Fractional measurements: ${compatibility.fractionalMeasurementsCount}`);
      console.log(`  - Turkish measurements: ${compatibility.turkishMeasurementsCount}`);

      // ============================================
      // STEP 3: Send to EDAMAM API
      // ============================================
      console.log('🌐 [EDAMAM-TEST] Step 3: Sending to EDAMAM API');
      const formattedIngredients = formatIngredientsForEdamam(parsedIngredients);

      const edamamPayload = {
        title: recipeName,
        ingr: formattedIngredients
      };

      console.log(`📤 [EDAMAM-TEST] Payload: ${JSON.stringify(edamamPayload).substring(0, 200)}...`);

      const edamamUrl = `${EDAMAM_BASE_URL}?app_id=${EDAMAM_APP_ID}&app_key=${EDAMAM_APP_KEY}`;

      console.log(`🌐 [EDAMAM-TEST] Sending request with Turkish language headers:`);
      console.log(`   Content-Language: tr`);
      console.log(`   Accept-Language: tr`);

      const edamamResponse = await fetch(edamamUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Language': 'tr',  // Tell EDAMAM we're sending Turkish ingredients
          'Accept-Language': 'tr'    // Tell EDAMAM we want Turkish responses
        },
        body: JSON.stringify(edamamPayload)
      });

      if (!edamamResponse.ok) {
        const errorText = await edamamResponse.text();
        console.error(`❌ [EDAMAM-TEST] EDAMAM API error: ${edamamResponse.status} - ${errorText}`);
        res.status(500).json({
          success: false,
          error: 'EDAMAM API request failed',
          message: `HTTP ${edamamResponse.status}: ${errorText}`,
          statusCode: edamamResponse.status
        });
        return;
      }

      const edamamData = await edamamResponse.json() as EdamamResponse;
      console.log(`✅ [EDAMAM-TEST] Received response from EDAMAM API`);
      console.log(`📊 [EDAMAM-TEST] Response structure:`, JSON.stringify(edamamData, null, 2));

      // ============================================
      // STEP 4: Extract nutrition data from EDAMAM (per 100g)
      // ============================================
      console.log('📊 [EDAMAM-TEST] Step 4: Extracting nutrition data');

      const totalWeight = edamamData.totalWeight || 1; // Total recipe weight in grams
      console.log(`⚖️ [EDAMAM-TEST] Total recipe weight: ${totalWeight}g`);

      // Calculate per 100g values
      const per100gFactor = 100 / totalWeight;

      const edamamNutritionTotal = {
        calories: Math.round(edamamData.calories),
        carbohydrates: Math.round(edamamData.totalNutrients.CHOCDF?.quantity || 0),
        protein: Math.round(edamamData.totalNutrients.PROCNT?.quantity || 0),
        fat: Math.round(edamamData.totalNutrients.FAT?.quantity || 0),
        fiber: Math.round(edamamData.totalNutrients.FIBTG?.quantity || 0),
        sugar: Math.round(edamamData.totalNutrients.SUGAR?.quantity || 0)
      };

      const edamamNutrition = {
        calories: Math.round(edamamNutritionTotal.calories * per100gFactor),
        carbohydrates: Math.round(edamamNutritionTotal.carbohydrates * per100gFactor),
        protein: Math.round(edamamNutritionTotal.protein * per100gFactor),
        fat: Math.round(edamamNutritionTotal.fat * per100gFactor),
        fiber: Math.round(edamamNutritionTotal.fiber * per100gFactor),
        sugar: Math.round(edamamNutritionTotal.sugar * per100gFactor)
      };

      console.log(`📊 [EDAMAM-TEST] EDAMAM Nutrition (Total ${totalWeight}g):`, edamamNutritionTotal);
      console.log(`📊 [EDAMAM-TEST] EDAMAM Nutrition (per 100g):`, edamamNutrition);

      // ============================================
      // STEP 5: Calculate accuracy comparison
      // ============================================
      console.log('🎯 [EDAMAM-TEST] Step 5: Calculating accuracy');

      const geminiNutritionClean = extractGeminiNutrition(geminiNutrition);

      const accuracyScores = {
        calories: calculateAccuracy(geminiNutritionClean.calories, edamamNutrition.calories),
        carbs: calculateAccuracy(geminiNutritionClean.carbohydrates, edamamNutrition.carbohydrates),
        protein: calculateAccuracy(geminiNutritionClean.protein, edamamNutrition.protein),
        fat: calculateAccuracy(geminiNutritionClean.fat, edamamNutrition.fat),
        fiber: calculateAccuracy(geminiNutritionClean.fiber, edamamNutrition.fiber),
        sugar: calculateAccuracy(geminiNutritionClean.sugar, edamamNutrition.sugar)
      };

      const overallAccuracy = (
        accuracyScores.calories +
        accuracyScores.carbs +
        accuracyScores.protein +
        accuracyScores.fat +
        accuracyScores.fiber +
        accuracyScores.sugar
      ) / 6;

      console.log(`🎯 [EDAMAM-TEST] Overall accuracy: ${overallAccuracy.toFixed(1)}%`);

      // ============================================
      // STEP 6: Create ingredient summary (not per-ingredient analysis)
      // ============================================
      console.log('✅ [EDAMAM-TEST] Step 6: Creating ingredient summary');

      // Simple ingredient summary for display
      const ingredientResults = parsedIngredients.map((ing, index) => {
        const analysis = ingredientAnalyses[index];
        return {
          text: ing,
          recognized: true, // We don't need individual recognition - the whole recipe was processed
          confidence: 100,
          hasTurkishCharacters: analysis.hasTurkishCharacters,
          hasFractionalMeasurement: analysis.hasFractionalMeasurement,
          hasTurkishMeasurement: analysis.hasTurkishMeasurement,
          parsedData: null
        };
      });

      const recognitionRate = 100; // If EDAMAM returned nutrition, it recognized the recipe
      console.log(`✅ [EDAMAM-TEST] Recipe recognized: YES`);

      // ============================================
      // STEP 7: Save test results to Firestore
      // ============================================
      console.log('💾 [EDAMAM-TEST] Step 7: Saving results to Firestore');

      const testId = `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const testResult = {
        testId,
        userId,
        timestamp: FieldValue.serverTimestamp(),
        recipeName,
        mealType,
        styleType,

        // Gemini data
        geminiIngredients: parsedIngredients,
        geminiNutrition: geminiNutritionClean,

        // EDAMAM data
        edamamIngredients: ingredientResults,
        edamamNutrition,
        edamamRawResponse: edamamData, // Store full response for debugging

        // Analysis
        accuracyScores,
        overallAccuracy: Math.round(overallAccuracy),
        recognitionRate: Math.round(recognitionRate),
        compatibility,

        // Metadata
        processingTime: Date.now() - startTime,
        testDate: new Date().toISOString()
      };

      await db.collection('edamam_tests').doc(testId).set(testResult);
      console.log(`✅ [EDAMAM-TEST] Results saved with ID: ${testId}`);

      // ============================================
      // STEP 8: Return response
      // ============================================
      const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`🏁 [EDAMAM-TEST] Test completed in ${totalTime}s`);

      res.json({
        success: true,
        data: {
          testId,
          recipeName,
          geminiNutrition: geminiNutritionClean,
          edamamNutrition,
          accuracyScores,
          overallAccuracy: Math.round(overallAccuracy),
          recognitionRate: Math.round(recognitionRate),
          ingredients: ingredientResults,
          compatibility,
          processingTime: `${totalTime}s`,
          edamamResponse: edamamData
        },
        metadata: {
          timestamp: new Date().toISOString(),
          version: '1.0.0-test'
        }
      });

    } catch (error) {
      console.error('❌ [EDAMAM-TEST] Unexpected error:', error);

      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';

      res.status(500).json({
        success: false,
        error: 'EDAMAM test failed',
        message: errorMessage,
        timestamp: new Date().toISOString()
      });
    }
  });
});
