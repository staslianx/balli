"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cosineSimilarity = cosineSimilarity;
exports.checkRecipeSimilarity = checkRecipeSimilarity;
exports.checkRecipeSimilarityWithDecay = checkRecipeSimilarityWithDecay;
/**
 * Calculate cosine similarity between two vectors
 * Returns value between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite)
 */
function cosineSimilarity(vecA, vecB) {
    if (vecA.length !== vecB.length) {
        throw new Error(`Vector dimension mismatch: ${vecA.length} vs ${vecB.length}`);
    }
    if (vecA.length === 0) {
        return 0;
    }
    let dotProduct = 0;
    let normA = 0;
    let normB = 0;
    for (let i = 0; i < vecA.length; i++) {
        dotProduct += vecA[i] * vecB[i];
        normA += vecA[i] * vecA[i];
        normB += vecB[i] * vecB[i];
    }
    const denominator = Math.sqrt(normA) * Math.sqrt(normB);
    if (denominator === 0) {
        return 0;
    }
    return dotProduct / denominator;
}
/**
 * Check if a new recipe embedding is too similar to recent recipes
 * Returns the maximum similarity found and whether it exceeds the threshold
 */
function checkRecipeSimilarity(newEmbedding, recentRecipes, threshold = 0.85) {
    if (recentRecipes.length === 0) {
        return {
            isSimilar: false,
            maxSimilarity: 0,
        };
    }
    let maxSimilarity = 0;
    let mostSimilarRecipe;
    for (const recipe of recentRecipes) {
        try {
            const similarity = cosineSimilarity(newEmbedding, recipe.embedding);
            if (similarity > maxSimilarity) {
                maxSimilarity = similarity;
                mostSimilarRecipe = recipe;
            }
        }
        catch (error) {
            console.error(`Error computing similarity for recipe ${recipe.recipeId}:`, error);
            // Continue checking other recipes
        }
    }
    const isSimilar = maxSimilarity >= threshold;
    return {
        isSimilar,
        maxSimilarity,
        similarRecipe: mostSimilarRecipe
            ? {
                name: mostSimilarRecipe.recipeName,
                recipeId: mostSimilarRecipe.recipeId,
                similarity: maxSimilarity,
            }
            : undefined,
    };
}
/**
 * Advanced: Check similarity with temporal decay weighting (Phase 3 optional)
 * Recent recipes have higher weight than older recipes
 */
function checkRecipeSimilarityWithDecay(newEmbedding, recentRecipes, threshold = 0.85, decayFactor = 0.95 // Exponential decay per day
) {
    if (recentRecipes.length === 0) {
        return {
            isSimilar: false,
            maxSimilarity: 0,
        };
    }
    const now = Date.now();
    let maxWeightedSimilarity = 0;
    let mostSimilarRecipe;
    for (const recipe of recentRecipes) {
        try {
            const similarity = cosineSimilarity(newEmbedding, recipe.embedding);
            // Apply temporal decay
            const ageInDays = (now - recipe.createdAt.toMillis()) / (1000 * 60 * 60 * 24);
            const temporalWeight = Math.pow(decayFactor, ageInDays);
            const weightedSimilarity = similarity * temporalWeight;
            if (weightedSimilarity > maxWeightedSimilarity) {
                maxWeightedSimilarity = weightedSimilarity;
                mostSimilarRecipe = recipe;
            }
        }
        catch (error) {
            console.error(`Error computing similarity for recipe ${recipe.recipeId}:`, error);
        }
    }
    const isSimilar = maxWeightedSimilarity >= threshold;
    return {
        isSimilar,
        maxSimilarity: maxWeightedSimilarity,
        similarRecipe: mostSimilarRecipe
            ? {
                name: mostSimilarRecipe.recipeName,
                recipeId: mostSimilarRecipe.recipeId,
                similarity: maxWeightedSimilarity,
            }
            : undefined,
    };
}
//# sourceMappingURL=similarity-checker.js.map