"use strict";
/**
 * Diversity Scorer
 *
 * Multi-dimensional diversity analysis beyond semantic similarity.
 * Ensures recipe variety across cuisine, protein, cooking methods, and ingredients.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateCuisineRotation = calculateCuisineRotation;
exports.calculateProteinVariety = calculateProteinVariety;
exports.calculateCookingMethodDiversity = calculateCookingMethodDiversity;
exports.calculateIngredientOverlap = calculateIngredientOverlap;
exports.calculateDiversityScore = calculateDiversityScore;
exports.buildDiversityConstraints = buildDiversityConstraints;
// ============================================================================
// SCORING WEIGHTS
// ============================================================================
const DIVERSITY_WEIGHTS = {
    similarity: 0.20, // Cosine similarity (secondary factor)
    cuisineVariety: 0.00, // IGNORE cuisine completely - user doesn't like international cuisines
    proteinDiversity: 0.20,
    cookingMethodVariety: 0.20,
    ingredientNovelty: 0.40, // PRIMARY factor - focus on ingredient variety within familiar cuisines
};
// Ensure weights sum to 1.0
const totalWeight = Object.values(DIVERSITY_WEIGHTS).reduce((a, b) => a + b, 0);
if (Math.abs(totalWeight - 1.0) > 0.001) {
    throw new Error(`Diversity weights must sum to 1.0, got ${totalWeight}`);
}
// ============================================================================
// CUISINE ROTATION SCORING
// ============================================================================
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
function calculateCuisineRotation(newRecipeCuisine, recentRecipes, windowSize = 10) {
    // If no cuisine specified, return neutral score
    if (!newRecipeCuisine) {
        return 0.5;
    }
    const recentCuisines = recentRecipes
        .slice(0, windowSize)
        .map((r) => r.metadata.cuisine)
        .filter((c) => c !== undefined);
    if (recentCuisines.length === 0) {
        return 1.0; // First recipe, perfect diversity
    }
    // Calculate recency-weighted penalty
    let recencyWeightedCount = 0;
    recentCuisines.forEach((c, index) => {
        if (c.toLowerCase() === newRecipeCuisine.toLowerCase()) {
            // More recent = higher penalty (exponential decay)
            const recencyWeight = Math.exp(-index / 3);
            recencyWeightedCount += recencyWeight;
        }
    });
    // Score: 1.0 if never seen, decreases with frequency
    // Most recent cuisines have higher penalty
    const rawScore = Math.max(0, 1.0 - recencyWeightedCount / 3);
    return rawScore;
}
// ============================================================================
// PROTEIN VARIETY SCORING
// ============================================================================
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
function calculateProteinVariety(newRecipeProtein, recentRecipes, windowSize = 8) {
    // If no protein specified, return neutral score
    if (!newRecipeProtein) {
        return 0.5;
    }
    const recentProteins = recentRecipes
        .slice(0, windowSize)
        .map((r) => r.metadata.primaryProtein)
        .filter((p) => p !== undefined);
    if (recentProteins.length === 0) {
        return 1.0; // First recipe
    }
    // Normalize protein names (e.g., "chicken" === "Chicken Breast")
    const normalizedNewProtein = normalizeProteinName(newRecipeProtein);
    // Count occurrences with recency weighting
    let recencyWeightedCount = 0;
    recentProteins.forEach((p, index) => {
        if (normalizeProteinName(p) === normalizedNewProtein) {
            const recencyWeight = Math.exp(-index / 2);
            recencyWeightedCount += recencyWeight;
        }
    });
    // Protein repetition is more tolerable than cuisine repetition
    const rawScore = Math.max(0, 1.0 - recencyWeightedCount / 4);
    return rawScore;
}
/**
 * Normalize protein names for comparison
 */
function normalizeProteinName(protein) {
    const normalized = protein.toLowerCase().trim();
    // Group similar proteins
    if (normalized.includes('chicken') || normalized.includes('tavuk')) {
        return 'chicken';
    }
    if (normalized.includes('beef') || normalized.includes('dana')) {
        return 'beef';
    }
    if (normalized.includes('fish') || normalized.includes('balık')) {
        return 'fish';
    }
    if (normalized.includes('pork') || normalized.includes('domuz')) {
        return 'pork';
    }
    if (normalized.includes('tofu') || normalized.includes('vegetarian') || normalized.includes('vejetaryen')) {
        return 'vegetarian';
    }
    if (normalized.includes('lamb') || normalized.includes('kuzu')) {
        return 'lamb';
    }
    return normalized;
}
// ============================================================================
// COOKING METHOD DIVERSITY SCORING
// ============================================================================
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
function calculateCookingMethodDiversity(newRecipeMethod, recentRecipes, windowSize = 12) {
    if (!newRecipeMethod) {
        return 0.5;
    }
    const recentMethods = recentRecipes
        .slice(0, windowSize)
        .map((r) => r.metadata.cookingMethod)
        .filter((m) => m !== undefined);
    if (recentMethods.length === 0) {
        return 1.0;
    }
    const normalizedNewMethod = normalizeCookingMethod(newRecipeMethod);
    let recencyWeightedCount = 0;
    recentMethods.forEach((m, index) => {
        if (normalizeCookingMethod(m) === normalizedNewMethod) {
            const recencyWeight = Math.exp(-index / 4);
            recencyWeightedCount += recencyWeight;
        }
    });
    // Cooking method repetition is most tolerable
    const rawScore = Math.max(0, 1.0 - recencyWeightedCount / 5);
    return rawScore;
}
/**
 * Normalize cooking method names
 */
function normalizeCookingMethod(method) {
    const normalized = method.toLowerCase().trim();
    if (normalized.includes('bak') || normalized.includes('fırın')) {
        return 'baking';
    }
    if (normalized.includes('grill') || normalized.includes('ızgara')) {
        return 'grilling';
    }
    if (normalized.includes('stir') || normalized.includes('sote')) {
        return 'stir-fry';
    }
    if (normalized.includes('boil') || normalized.includes('haşla')) {
        return 'boiling';
    }
    if (normalized.includes('steam') || normalized.includes('buğu')) {
        return 'steaming';
    }
    if (normalized.includes('fry') || normalized.includes('kızart')) {
        return 'frying';
    }
    return normalized;
}
// ============================================================================
// INGREDIENT NOVELTY SCORING
// ============================================================================
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
function calculateIngredientOverlap(newRecipe, recentRecipes, windowSize = 5) {
    // Extract ingredient names from structured format
    const newIngredients = new Set(newRecipe.ingredients
        .map((ing) => ing?.item || ing) // Handle both structured {item, quantity} and legacy string formats
        .filter((item) => item && typeof item === 'string') // Ensure it's a valid string
        .map((item) => normalizeIngredient(item))
        .filter((item) => !isCommonIngredient(item)));
    if (newIngredients.size === 0) {
        return 0.5; // Only common ingredients
    }
    const recentWindow = recentRecipes.slice(0, windowSize);
    if (recentWindow.length === 0) {
        return 1.0; // First recipe
    }
    // Calculate average overlap with recent recipes
    let totalOverlap = 0;
    recentWindow.forEach((recentRecipe) => {
        const recentIngredients = new Set(recentRecipe.fullRecipeJson.ingredients
            .map((ing) => ing?.item || ing) // Handle both structured {item, quantity} and legacy string formats
            .filter((item) => item && typeof item === 'string') // Ensure it's a valid string
            .map((item) => normalizeIngredient(item))
            .filter((item) => !isCommonIngredient(item)));
        // Jaccard similarity (intersection / union)
        const newIngredientsArray = Array.from(newIngredients);
        const recentIngredientsArray = Array.from(recentIngredients);
        const intersection = new Set(newIngredientsArray.filter((x) => recentIngredientsArray.includes(x)));
        const union = new Set([...newIngredientsArray, ...recentIngredientsArray]);
        if (union.size > 0) {
            const overlap = intersection.size / union.size;
            totalOverlap += overlap;
        }
    });
    const avgOverlap = totalOverlap / recentWindow.length;
    // High overlap = low novelty score
    const noveltyScore = Math.max(0, 1.0 - avgOverlap * 2);
    return noveltyScore;
}
/**
 * Normalize ingredient names for comparison
 */
function normalizeIngredient(ingredient) {
    return ingredient.toLowerCase().trim().replace(/[^a-zçğıöşü]/g, '');
}
/**
 * Check if ingredient is common (e.g., salt, water, oil)
 * Common ingredients don't count toward novelty
 */
function isCommonIngredient(ingredient) {
    const commonIngredients = new Set([
        'salt', 'tuz', 'pepper', 'biber', 'water', 'su',
        'oil', 'yağ', 'olive', 'zeytin', 'butter', 'tereyağ',
        'sugar', 'şeker', 'flour', 'un',
    ]);
    return commonIngredients.has(ingredient.toLowerCase());
}
// ============================================================================
// COMPOSITE DIVERSITY SCORE
// ============================================================================
/**
 * Calculate comprehensive diversity score combining all factors
 *
 * @param newRecipe - Candidate recipe
 * @param recentRecipes - Recent recipe history
 * @param cosineSimilarity - Cosine similarity score (from existing checker)
 * @returns Comprehensive diversity score with detailed breakdown
 */
function calculateDiversityScore(newRecipe, recentRecipes, cosineSimilarity) {
    // Use metadata from recipe (Gemini generates this directly)
    const metadata = newRecipe.metadata || {};
    // Calculate component scores
    const cuisineScore = calculateCuisineRotation(metadata.cuisine, recentRecipes);
    const proteinScore = calculateProteinVariety(metadata.primaryProtein, recentRecipes);
    const methodScore = calculateCookingMethodDiversity(metadata.cookingMethod, recentRecipes);
    const ingredientScore = calculateIngredientOverlap(newRecipe, recentRecipes);
    // Semantic similarity score (inverted: low similarity = high diversity)
    const semanticScore = 1.0 - cosineSimilarity;
    // Calculate weighted composite score
    const overallScore = semanticScore * DIVERSITY_WEIGHTS.similarity +
        cuisineScore * DIVERSITY_WEIGHTS.cuisineVariety +
        proteinScore * DIVERSITY_WEIGHTS.proteinDiversity +
        methodScore * DIVERSITY_WEIGHTS.cookingMethodVariety +
        ingredientScore * DIVERSITY_WEIGHTS.ingredientNovelty;
    // Generate feedback
    const strengths = [];
    const weaknesses = [];
    if (cuisineScore >= 0.7) {
        strengths.push(`Cuisine variety (${metadata.cuisine || 'N/A'})`);
    }
    else if (cuisineScore < 0.4) {
        weaknesses.push('Cuisine repetition');
    }
    if (proteinScore >= 0.7) {
        strengths.push(`Protein variety (${metadata.primaryProtein || 'N/A'})`);
    }
    else if (proteinScore < 0.4) {
        weaknesses.push('Protein repetition');
    }
    if (methodScore >= 0.7) {
        strengths.push(`Cooking method (${metadata.cookingMethod || 'N/A'})`);
    }
    if (ingredientScore >= 0.7) {
        strengths.push('Novel ingredients');
    }
    else if (ingredientScore < 0.4) {
        weaknesses.push('Similar ingredients');
    }
    if (semanticScore >= 0.7) {
        strengths.push('Unique concept');
    }
    else if (semanticScore < 0.3) {
        weaknesses.push('Similar to recent recipe');
    }
    // Default messages if empty
    if (strengths.length === 0) {
        strengths.push('Acceptable variety');
    }
    if (weaknesses.length === 0 && overallScore < 0.6) {
        weaknesses.push('Could be more diverse');
    }
    return {
        cuisineVariety: cuisineScore,
        proteinDiversity: proteinScore,
        cookingMethodVariety: methodScore,
        ingredientNovelty: ingredientScore,
        overallScore: Math.max(0, Math.min(1, overallScore)),
        strengths,
        weaknesses,
    };
}
// ============================================================================
// DIVERSITY CONSTRAINTS BUILDER
// ============================================================================
/**
 * Build diversity constraints from recent recipe history
 * Used to guide next recipe generation toward more diverse choices
 *
 * @param recentRecipes - Recent recipe history
 * @param windowSize - How many recent recipes to analyze (default: 10)
 * @returns Constraints for prompt enhancement
 */
function buildDiversityConstraints(recentRecipes, windowSize = 10) {
    const window = recentRecipes.slice(0, windowSize);
    // Count frequencies
    const cuisineCounts = new Map();
    const proteinCounts = new Map();
    const methodCounts = new Map();
    window.forEach((recipe) => {
        if (recipe.metadata.cuisine) {
            cuisineCounts.set(recipe.metadata.cuisine, (cuisineCounts.get(recipe.metadata.cuisine) || 0) + 1);
        }
        if (recipe.metadata.primaryProtein) {
            const normalized = normalizeProteinName(recipe.metadata.primaryProtein);
            proteinCounts.set(normalized, (proteinCounts.get(normalized) || 0) + 1);
        }
        if (recipe.metadata.cookingMethod) {
            const normalized = normalizeCookingMethod(recipe.metadata.cookingMethod);
            methodCounts.set(normalized, (methodCounts.get(normalized) || 0) + 1);
        }
    });
    // Find overused categories (appear in >40% of recent recipes)
    const threshold = window.length * 0.4;
    // CUISINE: Don't constrain - user prefers Turkish/familiar cuisines, diversity comes from ingredients/methods
    const avoidCuisines = [];
    const avoidProteins = Array.from(proteinCounts.entries())
        .filter(([, count]) => count >= threshold)
        .map(([protein]) => protein);
    const avoidMethods = Array.from(methodCounts.entries())
        .filter(([, count]) => count >= threshold)
        .map(([method]) => method);
    // Suggest underrepresented categories
    // CUISINE: Empty - don't push international cuisines user doesn't like
    // Focus diversity on proteins and methods within familiar cuisines
    const suggestCuisines = [];
    const allProteins = ['chicken', 'fish', 'beef', 'vegetarian', 'lamb'];
    const suggestProteins = allProteins.filter((p) => !proteinCounts.has(p) || proteinCounts.get(p) < 2);
    return {
        avoidCuisines,
        avoidProteins,
        avoidMethods,
        suggestCuisines,
        suggestProteins,
    };
}
//# sourceMappingURL=diversity-scorer.js.map