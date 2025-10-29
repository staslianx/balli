"use strict";
/**
 * Test-only endpoint for validating Gemini's per-100g nutrition calculations
 *
 * This endpoint is specifically designed for automated testing.
 * It calculates nutrition values for a given recipe without creative generation.
 */
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
exports.testNutritionCalculation = void 0;
const https_1 = require("firebase-functions/v2/https");
const cors = __importStar(require("cors"));
const genkit_instance_1 = require("./genkit-instance");
const providers_1 = require("./providers");
// Configure CORS
const corsHandler = cors.default({
    origin: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
});
/**
 * Test Nutrition Calculation Endpoint
 *
 * Input:
 * {
 *   recipeName: "Plain White Rice",
 *   ingredients: ["200g white rice (raw)", "500ml water"],
 *   totalCookedWeight: 500,  // grams (optional - Gemini will estimate if not provided)
 *   mealType: "Akşam Yemeği"
 * }
 *
 * Output:
 * {
 *   success: true,
 *   data: {
 *     calories: 130,      // per 100g
 *     carbohydrates: 28,  // per 100g
 *     protein: 2.7,       // per 100g
 *     fat: 0.3,           // per 100g
 *     fiber: 0.4,         // per 100g
 *     sugar: 0.1          // per 100g
 *   }
 * }
 */
exports.testNutritionCalculation = (0, https_1.onRequest)({
    timeoutSeconds: 60,
    memory: '512MiB',
    cpu: 1,
    concurrency: 5
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed' });
                return;
            }
            const { recipeName, ingredients, totalCookedWeight, mealType } = req.body;
            if (!recipeName || !ingredients || !Array.isArray(ingredients)) {
                res.status(400).json({
                    error: 'recipeName and ingredients (array) are required'
                });
                return;
            }
            console.log(`🧪 [TEST-NUTRITION] Calculating nutrition for: ${recipeName}`);
            console.log(`🧪 [TEST-NUTRITION] Ingredients: ${ingredients.join(', ')}`);
            // Build focused prompt for nutrition calculation only
            const nutritionPrompt = `Sen bir besin değerleri uzmanısın. Verilen tarif için SADECE 100 gram başına besin değerlerini hesapla.

**KRİTİK KURAL: TÜM besin değerleri MUTLAKA pişmiş yemeğin 100 GRAMI için hesaplanmalı**

Tarif: ${recipeName}
Öğün tipi: ${mealType || 'Genel'}

Malzemeler:
${ingredients.map(ing => `- ${ing}`).join('\n')}

${totalCookedWeight ? `Toplam pişmiş ağırlık: ${totalCookedWeight}g` : ''}

**HESAPLAMA YÖNTEMİ (ZORUNLU):**

1. Her malzemenin toplam besin değerlerini hesapla (çiğ ağırlıklar için USDA verilerini kullan)
2. Pişme sırasında ağırlık değişimini hesapla:
   - Pirinç/bulgur: çiğ ağırlık × 2.5-3 (su emer)
   - Et: çiğ ağırlık × 0.75 (25% su kaybı)
   - Sebze: çiğ ağırlık × 0.9 (10% su kaybı)
   - Yağ/sos: eklenen miktar (değişmez)
3. Toplam pişmiş ağırlığı hesapla
4. Her besin değerini (toplam pişmiş ağırlık / 100) ile böl

**ÖRNEK:**
Malzemeler: 200g pirinç (çiğ), 500ml su
- Pirinç (çiğ): 200g → 680 kcal, 151g karbonhidrat, 23.8g protein, 3.3g yağ, 26g lif
- Pişmiş ağırlık: 200g × 2.5 = 500g
- 100g başına: 680/5 = 136 kcal, 151/5 = 30.2g karbonhidrat, vb.

Sadece JSON formatında yanıt ver, başka açıklama ekleme:

{
  "calories": [sayı],
  "carbohydrates": [sayı],
  "protein": [sayı],
  "fat": [sayı],
  "fiber": [sayı],
  "sugar": [sayı],
  "calculationNotes": "Kısa hesaplama açıklaması"
}`;
            // Call Gemini for nutrition calculation
            const response = await genkit_instance_1.ai.generate({
                model: (0, providers_1.getRecipeModel)(),
                prompt: nutritionPrompt,
                output: { format: 'json' },
                config: {
                    temperature: 0.1, // Very low for consistent calculations
                    maxOutputTokens: 1024
                }
            });
            // Parse response
            let nutritionData;
            try {
                nutritionData = JSON.parse(response.text);
            }
            catch (parseError) {
                // Try to extract JSON
                const jsonMatch = response.text.match(/\{[\s\S]*\}/);
                if (jsonMatch) {
                    nutritionData = JSON.parse(jsonMatch[0]);
                }
                else {
                    throw new Error('Failed to parse nutrition JSON');
                }
            }
            console.log(`✅ [TEST-NUTRITION] Calculated: ${nutritionData.calories} kcal/100g`);
            console.log(`✅ [TEST-NUTRITION] Notes: ${nutritionData.calculationNotes || 'N/A'}`);
            res.json({
                success: true,
                data: {
                    recipeName,
                    ingredients,
                    totalCookedWeight: totalCookedWeight || 'estimated',
                    nutrition: {
                        calories: parseFloat(nutritionData.calories) || 0,
                        carbohydrates: parseFloat(nutritionData.carbohydrates) || 0,
                        protein: parseFloat(nutritionData.protein) || 0,
                        fat: parseFloat(nutritionData.fat) || 0,
                        fiber: parseFloat(nutritionData.fiber) || 0,
                        sugar: parseFloat(nutritionData.sugar) || 0
                    },
                    calculationNotes: nutritionData.calculationNotes || '',
                    timestamp: new Date().toISOString()
                }
            });
        }
        catch (error) {
            console.error('❌ [TEST-NUTRITION] Calculation failed:', error);
            res.status(500).json({
                success: false,
                error: 'Nutrition calculation failed',
                message: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    });
});
//# sourceMappingURL=test-nutrition-endpoint.js.map