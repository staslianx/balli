/**
 * Parse ingredients from Gemini's markdown recipe content
 * Extracts ingredient list from "## Malzemeler" section
 *
 * @param recipeContent - Full markdown recipe content from Gemini
 * @returns Array of ingredient strings
 */
export declare function parseIngredientsFromMarkdown(recipeContent: string): string[];
/**
 * Format ingredients for EDAMAM Nutrition Analysis API
 * EDAMAM expects an array of ingredient strings
 *
 * @param ingredients - Array of ingredient strings
 * @returns Formatted ingredients ready for EDAMAM API
 */
export declare function formatIngredientsForEdamam(ingredients: string[]): string[];
/**
 * Extract nutrition values from Gemini recipe output for comparison
 *
 * @param geminiRecipe - Recipe object from Gemini
 * @returns Nutrition object with standardized format
 */
export interface GeminiNutrition {
    calories: number;
    carbohydrates: number;
    protein: number;
    fat: number;
    fiber: number;
    sugar: number;
    glycemicLoad: number;
}
export declare function extractGeminiNutrition(geminiRecipe: any): GeminiNutrition;
/**
 * Analyze ingredient for Turkish language and fractional measurements
 *
 * @param ingredient - Single ingredient string
 * @returns Analysis result
 */
export interface IngredientAnalysis {
    original: string;
    hasTurkishCharacters: boolean;
    hasFractionalMeasurement: boolean;
    hasTurkishMeasurement: boolean;
    measurements: string[];
}
export declare function analyzeIngredient(ingredient: string): IngredientAnalysis;
/**
 * Calculate accuracy percentage between Gemini and EDAMAM nutrition values
 *
 * @param gemini - Gemini nutrition value
 * @param edamam - EDAMAM nutrition value
 * @returns Accuracy percentage (0-100)
 */
export declare function calculateAccuracy(gemini: number, edamam: number): number;
/**
 * Analyze overall test results for Turkish compatibility
 *
 * @param ingredients - Array of ingredient analyses
 * @returns Summary statistics
 */
export interface CompatibilitySummary {
    totalIngredients: number;
    turkishIngredientsCount: number;
    fractionalMeasurementsCount: number;
    turkishMeasurementsCount: number;
    turkishRecognitionRate: number;
}
export declare function analyzeCompatibility(ingredients: IngredientAnalysis[]): CompatibilitySummary;
//# sourceMappingURL=edamam-parser.d.ts.map