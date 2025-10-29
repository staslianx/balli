/**
 * Nutrition data structure (per 100g)
 */
export interface USDANutrition {
    calories: number;
    carbohydrates: number;
    protein: number;
    fat: number;
    fiber: number;
    sugar: number;
}
/**
 * Search for food in USDA database by English term
 *
 * @param searchTerm - English food name (e.g., "chicken breast cooked")
 * @returns USDA nutrition data per 100g, or null if not found
 */
export declare function searchUSDAFood(searchTerm: string): Promise<USDANutrition | null>;
/**
 * Batch search for multiple foods (with rate limiting)
 *
 * @param searches - Map of Turkish name to English search term
 * @returns Map of Turkish name to USDA nutrition data
 */
export declare function batchSearchUSDA(searches: Map<string, string>): Promise<Map<string, USDANutrition | null>>;
//# sourceMappingURL=usda-client.d.ts.map