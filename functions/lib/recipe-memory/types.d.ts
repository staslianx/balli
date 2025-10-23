import { Timestamp } from 'firebase-admin/firestore';
/**
 * Recipe metadata for diversity analysis
 */
export interface RecipeMetadata {
    cuisine?: string;
    primaryProtein?: string;
    cookingMethod?: string;
    mealType?: string;
    dietaryTags?: string[];
    prepTime?: number;
    difficulty?: string;
}
/**
 * Recipe JSON structure returned from Gemini
 * MUST match iOS RecipeMemory format exactly
 */
export interface RecipeJson {
    name: string;
    description?: string;
    aiNotes: string;
    ingredients: Array<{
        item: string;
        quantity: string;
    }>;
    instructions: string[];
    servings: number;
    prepTime: number;
    cookTime: number;
    calories?: number;
    carbohydrates?: number;
    fiber?: number;
    sugar?: number;
    protein?: number;
    fat?: number;
    glycemicLoad?: number;
    metadata?: RecipeMetadata;
}
/**
 * Recipe memory stored in Firestore
 */
export interface RecipeMemory {
    recipeId: string;
    userId: string;
    conversationId: string;
    recipeName: string;
    recipeDescription: string;
    fullRecipeJson: RecipeJson;
    embedding: number[];
    embeddingModel: string;
    metadata: RecipeMetadata;
    createdAt: Timestamp;
    lastAccessedAt: Timestamp;
    generationAttempt: number;
    wasRetried: boolean;
    similarityScore?: number;
}
/**
 * Request to generate recipe with memory
 */
export interface GenerateRecipeRequest {
    mealType: string;
    styleType: string;
    userId: string;
    conversationId: string;
    maxRetries?: number;
    similarityThreshold?: number;
    temporalWindowDays?: number;
}
/**
 * Response from recipe generation
 */
export interface GenerateRecipeResponse {
    success: boolean;
    recipe?: RecipeJson;
    recipeId?: string;
    metadata: {
        wasRetried: boolean;
        attempts: number;
        similarityScore?: number;
        latencyMs: number;
        recentRecipesChecked: number;
    };
    error?: string;
}
/**
 * Diversity constraints extracted from recent recipes
 */
export interface DiversityConstraints {
    avoidCuisines: string[];
    avoidProteins: string[];
    avoidMethods: string[];
    exploreCategories: string[];
}
/**
 * Result of similarity check
 */
export interface SimilarityCheckResult {
    isSimilar: boolean;
    maxSimilarity: number;
    similarRecipe?: {
        name: string;
        recipeId: string;
        similarity: number;
    };
}
/**
 * Multi-dimensional diversity score (0-1 scale)
 */
export interface DiversityScore {
    cuisineVariety: number;
    proteinDiversity: number;
    cookingMethodVariety: number;
    ingredientNovelty: number;
    overallScore: number;
    strengths: string[];
    weaknesses: string[];
}
/**
 * User dietary preferences and constraints
 */
export interface UserPreferences {
    userId: string;
    dietaryRestrictions: string[];
    allergens: string[];
    dislikedIngredients: string[];
    favoriteCuisines: string[];
    favoriteProteins: string[];
    preferredCookingMethods: string[];
    healthGoals?: string[];
    calorieTarget?: number;
    createdAt: Timestamp;
    updatedAt: Timestamp;
}
/**
 * Diversity metrics for analytics (rolling window)
 */
export interface DiversityMetrics {
    userId: string;
    windowStartDate: Timestamp;
    windowEndDate: Timestamp;
    cuisineDistribution: Record<string, number>;
    proteinDistribution: Record<string, number>;
    cookingMethodDistribution: Record<string, number>;
    averageDiversityScore: number;
    diversityTrend: 'improving' | 'declining' | 'stable';
    underrepresentedCuisines: string[];
    underrepresentedProteins: string[];
    suggestedCookingMethods: string[];
    totalRecipes: number;
    uniqueCuisines: number;
    uniqueProteins: number;
    calculatedAt: Timestamp;
}
/**
 * Enhanced request with diversity constraints
 */
export interface GenerateRecipeWithDiversityRequest extends GenerateRecipeRequest {
    diversityThreshold?: number;
    enableDiversityScoring?: boolean;
    userPreferences?: UserPreferences;
    enableSeasonalSuggestions?: boolean;
    currentMonth?: number;
}
/**
 * Enhanced response with diversity metadata
 */
export interface GenerateRecipeWithDiversityResponse extends GenerateRecipeResponse {
    diversityScore?: DiversityScore;
    appliedConstraints?: DiversityConstraints;
    seasonalIngredients?: string[];
}
//# sourceMappingURL=types.d.ts.map