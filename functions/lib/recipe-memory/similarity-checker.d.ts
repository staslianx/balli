import { RecipeMemory, SimilarityCheckResult } from './types';
/**
 * Calculate cosine similarity between two vectors
 * Returns value between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite)
 */
export declare function cosineSimilarity(vecA: number[], vecB: number[]): number;
/**
 * Check if a new recipe embedding is too similar to recent recipes
 * Returns the maximum similarity found and whether it exceeds the threshold
 */
export declare function checkRecipeSimilarity(newEmbedding: number[], recentRecipes: RecipeMemory[], threshold?: number): SimilarityCheckResult;
/**
 * Advanced: Check similarity with temporal decay weighting (Phase 3 optional)
 * Recent recipes have higher weight than older recipes
 */
export declare function checkRecipeSimilarityWithDecay(newEmbedding: number[], recentRecipes: RecipeMemory[], threshold?: number, decayFactor?: number): SimilarityCheckResult;
//# sourceMappingURL=similarity-checker.d.ts.map