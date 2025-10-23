/**
 * Recipe Memory Service
 * Business logic for memory-aware recipe generation with similarity checking
 */
import { RecipeMemoryEntry, IngredientClassification, VarietySuggestions, SimilarityCheckResult } from "../types/recipe-memory";
export { RecipeMemoryEntry, IngredientClassification, VarietySuggestions, SimilarityCheckResult };
/**
 * Normalizes an ingredient name for consistent matching
 * - Converts to lowercase
 * - Trims whitespace
 * - Applies consistent naming conventions
 */
export declare function normalizeIngredient(ingredient: string): string;
/**
 * Classifies an ingredient as protein, vegetable, or other
 */
export declare function classifyIngredient(ingredient: string): "protein" | "vegetable" | "other";
/**
 * Classifies a list of ingredients into proteins, vegetables, and other
 */
export declare function classifyIngredients(ingredients: string[]): IngredientClassification;
/**
 * Analyzes ingredient frequency across memory entries
 * Returns ingredients sorted by usage (least-used first)
 */
export declare function analyzeIngredientFrequency(memoryEntries: RecipeMemoryEntry[]): Record<string, number>;
/**
 * Gets least-used ingredients for variety suggestions
 */
export declare function getLeastUsedIngredients(memoryEntries: RecipeMemoryEntry[], proteinCount?: number, vegetableCount?: number): VarietySuggestions;
/**
 * Checks if two recipes are too similar (3+ ingredient overlap)
 */
export declare function checkSimilarity(newIngredients: string[], existingEntry: RecipeMemoryEntry): SimilarityCheckResult;
/**
 * Checks if new recipe is too similar to any of the last N recipes
 */
export declare function checkSimilarityAgainstRecent(newIngredients: string[], recentEntries: RecipeMemoryEntry[], checkLimit?: number): SimilarityCheckResult;
/**
 * Extracts main ingredients from recipe content using Gemini
 * Returns 3-5 key ingredients in Turkish (normalized)
 */
export declare function extractMainIngredients(recipeContent: string, recipeName: string): Promise<string[]>;
/**
 * Builds variety suggestions text for recipe generation prompt
 */
export declare function buildVarietySuggestionsText(suggestions: VarietySuggestions): string;
/**
 * Gets subcategory context description for prompts
 */
export declare function getSubcategoryContext(subcategory: string): string;
//# sourceMappingURL=recipe-memory.d.ts.map