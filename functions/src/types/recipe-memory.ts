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
export enum RecipeSubcategory {
  KAHVALTI = "Kahvaltı",
  DOYURUCU_SALATA = "Doyurucu salata",
  HAFIF_SALATA = "Hafif salata",
  KARBONHIDRAT_PROTEIN = "Karbonhidrat ve Protein Uyumu",
  TAM_TAHIL_MAKARNA = "Tam tahıl makarna çeşitleri",
  SANA_OZEL_TATLILAR = "Sana özel tatlılar",
  DONDURMA = "Dondurma",
  MEYVE_SALATASI = "Meyve salatası",
  ATISTIRMALIKLAR = "Atıştırmalıklar"
}

/**
 * Memory limits per subcategory based on realistic variety potential
 */
export const MEMORY_LIMITS: Record<RecipeSubcategory, number> = {
  [RecipeSubcategory.KAHVALTI]: 25,
  [RecipeSubcategory.DOYURUCU_SALATA]: 30,
  [RecipeSubcategory.HAFIF_SALATA]: 20,
  [RecipeSubcategory.KARBONHIDRAT_PROTEIN]: 30,
  [RecipeSubcategory.TAM_TAHIL_MAKARNA]: 25,
  [RecipeSubcategory.SANA_OZEL_TATLILAR]: 15,
  [RecipeSubcategory.DONDURMA]: 10,
  [RecipeSubcategory.MEYVE_SALATASI]: 10,
  [RecipeSubcategory.ATISTIRMALIKLAR]: 20
};

/**
 * Context descriptions for recipe generation prompts
 */
export const SUBCATEGORY_CONTEXTS: Record<RecipeSubcategory, string> = {
  [RecipeSubcategory.KAHVALTI]: "Diyabet dostu kahvaltı",
  [RecipeSubcategory.DOYURUCU_SALATA]: "Protein içeren ana yemek olarak servis edilen doyurucu bir salata",
  [RecipeSubcategory.HAFIF_SALATA]: "Yan yemek olarak servis edilen hafif bir salata",
  [RecipeSubcategory.KARBONHIDRAT_PROTEIN]: "Dengeli karbonhidrat ve protein kombinasyonu içeren akşam yemeği",
  [RecipeSubcategory.TAM_TAHIL_MAKARNA]: "Tam tahıllı makarna çeşitleri",
  [RecipeSubcategory.SANA_OZEL_TATLILAR]: "Diyabet dostu tatlı versiyonları",
  [RecipeSubcategory.DONDURMA]: "Ninja Creami makinesi için diyabet dostu dondurma",
  [RecipeSubcategory.MEYVE_SALATASI]: "Diyabet yönetimine uygun meyve salatası",
  [RecipeSubcategory.ATISTIRMALIKLAR]: "Sağlıklı atıştırmalıklar"
};

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
  ingredients: string[];  // Legacy format
  directions: string[];   // Legacy format
  notes: string;
  recipeContent?: string;  // Modern markdown format

  // Nutrition information
  calories: string;
  carbohydrates: string;
  fiber: string;
  protein: string;
  fat: string;
  sugar: string;
  glycemicLoad: string;

  // NEW: Extracted main ingredients for memory system
  extractedIngredients?: string[];

  // NEW: Similarity flag (was this a regeneration?)
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
