import { RecipeMemory, RecipeJson } from './types';
/**
 * Get recent recipes for a user within a time window
 */
export declare function getRecentRecipes(userId: string, windowDays?: number): Promise<RecipeMemory[]>;
/**
 * Save a new recipe to memory with embedding
 */
export declare function saveRecipeMemory(params: {
    userId: string;
    conversationId: string;
    recipe: RecipeJson;
    embedding: number[];
    generationAttempt: number;
    wasRetried: boolean;
    similarityScore?: number;
}): Promise<string>;
/**
 * Get a specific recipe by ID
 */
export declare function getRecipeById(recipeId: string): Promise<RecipeMemory | null>;
/**
 * Cleanup old recipes (data retention policy)
 * Can be called by a scheduled function
 */
export declare function cleanupOldRecipes(userId: string, retentionDays?: number): Promise<number>;
//# sourceMappingURL=memory-store.d.ts.map