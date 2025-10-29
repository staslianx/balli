/**
 * Test-only endpoint for validating Gemini's per-100g nutrition calculations
 *
 * This endpoint is specifically designed for automated testing.
 * It calculates nutrition values for a given recipe without creative generation.
 */
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
export declare const testNutritionCalculation: import("firebase-functions/v2/https").HttpsFunction;
//# sourceMappingURL=test-nutrition-endpoint.d.ts.map