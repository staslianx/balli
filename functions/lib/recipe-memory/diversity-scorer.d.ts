/**
 * Diversity Scorer
 *
 * Multi-dimensional diversity analysis beyond semantic similarity.
 * Ensures recipe variety across cuisine, protein, cooking methods, and ingredients.
 */
import { RecipeMemory, DiversityScore } from './types';
/**
 * Calculate cuisine variety score based on recent recipe history
 *
 * Penalizes repeated cuisines, rewards exploring new ones
 *
 * @param newRecipeCuisine - Cuisine of candidate recipe
 * @param recentRecipes - Recent recipe history
 * @param windowSize - How many recent recipes to consider (default: 10)
 * @returns Score 0-1 (1 = very diverse, 0 = highly repetitive)
 */
export declare function calculateCuisineRotation(newRecipeCuisine: string | undefined, recentRecipes: RecipeMemory[], windowSize?: number): number;
/**
 * Calculate protein diversity score
 *
 * Ensures rotation across different protein sources
 *
 * @param newRecipeProtein - Primary protein of candidate recipe
 * @param recentRecipes - Recent recipe history
 * @param windowSize - How many recent recipes to consider (default: 8)
 * @returns Score 0-1 (1 = very diverse, 0 = highly repetitive)
 */
export declare function calculateProteinVariety(newRecipeProtein: string | undefined, recentRecipes: RecipeMemory[], windowSize?: number): number;
/**
 * Calculate cooking method variety score
 *
 * Encourages trying different cooking techniques
 *
 * @param newRecipeMethod - Cooking method of candidate recipe
 * @param recentRecipes - Recent recipe history
 * @param windowSize - How many recent recipes to consider (default: 12)
 * @returns Score 0-1 (1 = very diverse, 0 = highly repetitive)
 */
export declare function calculateCookingMethodDiversity(newRecipeMethod: string | undefined, recentRecipes: RecipeMemory[], windowSize?: number): number;
/**
 * Calculate ingredient novelty score
 *
 * Detects excessive ingredient overlap with recent recipes
 *
 * @param newRecipe - Candidate recipe
 * @param recentRecipes - Recent recipe history
 * @param windowSize - How many recent recipes to consider (default: 5)
 * @returns Score 0-1 (1 = very novel, 0 = highly overlapping)
 */
export declare function calculateIngredientOverlap(newRecipe: any, recentRecipes: RecipeMemory[], windowSize?: number): number;
/**
 * Calculate comprehensive diversity score combining all factors
 *
 * @param newRecipe - Candidate recipe
 * @param recentRecipes - Recent recipe history
 * @param cosineSimilarity - Cosine similarity score (from existing checker)
 * @returns Comprehensive diversity score with detailed breakdown
 */
export declare function calculateDiversityScore(newRecipe: any, recentRecipes: RecipeMemory[], cosineSimilarity: number): DiversityScore;
/**
 * Build diversity constraints from recent recipe history
 * Used to guide next recipe generation toward more diverse choices
 *
 * @param recentRecipes - Recent recipe history
 * @param windowSize - How many recent recipes to analyze (default: 10)
 * @returns Constraints for prompt enhancement
 */
export declare function buildDiversityConstraints(recentRecipes: RecipeMemory[], windowSize?: number): {
    avoidCuisines: string[];
    avoidProteins: string[];
    avoidMethods: string[];
    suggestCuisines: string[];
    suggestProteins: string[];
};
//# sourceMappingURL=diversity-scorer.d.ts.map