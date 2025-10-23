/**
 * Recipe Memory System Types
 * Types for memory-aware recipe generation with diversity tracking
 */
/**
 * Represents a single recipe memory entry
 * Stores minimal data: main ingredients, timestamp, and subcategory
 */
export interface RecipeMemoryEntry {
    /** 3-5 key ingredients in Turkish (normalized: lowercase, trimmed, singular) */
    mainIngredients: string[];
    /** ISO8601 timestamp when recipe was generated */
    dateGenerated: string;
    /** The subcategory this recipe belongs to */
    subcategory: string;
    /** Optional recipe name for debugging/analytics */
    recipeName?: string;
}
/**
 * The 9 independent meal subcategories for recipe memory tracking
 */
export declare enum RecipeSubcategory {
    KAHVALTI = "Kahvalt\u0131",
    DOYURUCU_SALATA = "Doyurucu salata",
    HAFIF_SALATA = "Hafif salata",
    KARBONHIDRAT_PROTEIN = "Karbonhidrat ve Protein Uyumu",
    TAM_TAHIL_MAKARNA = "Tam tah\u0131l makarna \u00E7e\u015Fitleri",
    SANA_OZEL_TATLILAR = "Sana \u00F6zel tatl\u0131lar",
    DONDURMA = "Dondurma",
    MEYVE_SALATASI = "Meyve salatas\u0131",
    ATISTIRMALIKLAR = "At\u0131\u015Ft\u0131rmal\u0131klar"
}
/**
 * Memory limits per subcategory based on realistic variety potential
 */
export declare const MEMORY_LIMITS: Record<RecipeSubcategory, number>;
/**
 * Context descriptions for recipe generation prompts
 */
export declare const SUBCATEGORY_CONTEXTS: Record<RecipeSubcategory, string>;
/**
 * Request payload for memory-aware recipe generation
 */
export interface RecipeGenerationRequest {
    /** Parent meal type for context (e.g., "Salatalar", "Akşam Yemeği") */
    mealType: string;
    /** Specific subcategory (e.g., "Doyurucu salata") */
    styleType: string;
    /** User ID for personalization */
    userId?: string;
    /** Enable streaming response */
    streamingEnabled?: boolean;
    /** Recent recipe memory entries for this subcategory (last 10) */
    memoryEntries?: RecipeMemoryEntry[];
}
/**
 * Response from recipe generation with extracted ingredients
 */
export interface RecipeGenerationResponse {
    recipeName: string;
    prepTime: string;
    cookTime: string;
    ingredients: string[];
    directions: string[];
    notes: string;
    recipeContent?: string;
    calories: string;
    carbohydrates: string;
    fiber: string;
    protein: string;
    fat: string;
    sugar: string;
    glycemicLoad: string;
    extractedIngredients?: string[];
    wasRegenerated?: boolean;
}
/**
 * Ingredient classification for variety suggestions
 */
export interface IngredientClassification {
    proteins: string[];
    vegetables: string[];
    other: string[];
}
/**
 * Variety suggestions for prompt building
 */
export interface VarietySuggestions {
    leastUsedProteins: string[];
    leastUsedVegetables: string[];
    frequencyMap: Record<string, number>;
}
/**
 * Similarity check result
 */
export interface SimilarityCheckResult {
    isSimilar: boolean;
    matchCount: number;
    matchingIngredients: string[];
    matchedRecipeIndex?: number;
}
//# sourceMappingURL=recipe-memory.d.ts.map