//
// edamam-parser.ts
// Utility functions for parsing Gemini recipe output and preparing for EDAMAM API
//

/**
 * Parse ingredients from Gemini's markdown recipe content
 * Extracts ingredient list from "## Malzemeler" section
 *
 * @param recipeContent - Full markdown recipe content from Gemini
 * @returns Array of ingredient strings
 */
export function parseIngredientsFromMarkdown(recipeContent: string): string[] {
  // Find the "## Malzemeler" section (Turkish for "Ingredients")
  const ingredientsMatch = recipeContent.match(/## Malzemeler[\s\S]*?(?=\n##|$)/i);

  if (!ingredientsMatch) {
    console.warn('⚠️ [EDAMAM-PARSER] No "## Malzemeler" section found in recipe content');
    return [];
  }

  const ingredientsSection = ingredientsMatch[0];

  // Extract bullet points (lines starting with -)
  const bulletRegex = /^[\s]*-\s+(.+)$/gm;
  const ingredients: string[] = [];

  let match;
  while ((match = bulletRegex.exec(ingredientsSection)) !== null) {
    const ingredient = match[1].trim();
    if (ingredient) {
      ingredients.push(ingredient);
    }
  }

  console.log(`📋 [EDAMAM-PARSER] Parsed ${ingredients.length} ingredients from markdown`);
  return ingredients;
}

/**
 * Format ingredients for EDAMAM Nutrition Analysis API
 * EDAMAM expects an array of ingredient strings
 *
 * @param ingredients - Array of ingredient strings
 * @returns Formatted ingredients ready for EDAMAM API
 */
export function formatIngredientsForEdamam(ingredients: string[]): string[] {
  return ingredients.map(ing => {
    // Clean up any markdown formatting that might have slipped through
    return ing
      .replace(/\*\*/g, '') // Remove bold **
      .replace(/\*/g, '')   // Remove italic *
      .replace(/_/g, '')    // Remove underscores
      .trim();
  });
}

/**
 * Extract nutrition values from Gemini recipe output for comparison
 *
 * @param geminiRecipe - Recipe object from Gemini
 * @returns Nutrition object with standardized format
 */
export interface GeminiNutrition {
  calories: number;
  carbohydrates: number;
  protein: number;
  fat: number;
  fiber: number;
  sugar: number;
  glycemicLoad: number;
}

export function extractGeminiNutrition(geminiRecipe: any): GeminiNutrition {
  return {
    calories: Number(geminiRecipe.calories) || 0,
    carbohydrates: Number(geminiRecipe.carbohydrates) || 0,
    protein: Number(geminiRecipe.protein) || 0,
    fat: Number(geminiRecipe.fat) || 0,
    fiber: Number(geminiRecipe.fiber) || 0,
    sugar: Number(geminiRecipe.sugar) || 0,
    glycemicLoad: Number(geminiRecipe.glycemicLoad) || 0,
  };
}

/**
 * Analyze ingredient for Turkish language and fractional measurements
 *
 * @param ingredient - Single ingredient string
 * @returns Analysis result
 */
export interface IngredientAnalysis {
  original: string;
  hasTurkishCharacters: boolean;
  hasFractionalMeasurement: boolean;
  hasTurkishMeasurement: boolean;
  measurements: string[];
}

export function analyzeIngredient(ingredient: string): IngredientAnalysis {
  // Turkish characters: ç, ğ, ı, ö, ş, ü
  const turkishCharacters = /[çğıöşüÇĞİÖŞÜ]/;
  const hasTurkishCharacters = turkishCharacters.test(ingredient);

  // Fractional measurements: 1/2, 1/4, 3/4, etc.
  const fractionalPattern = /\d+\/\d+/;
  const hasFractionalMeasurement = fractionalPattern.test(ingredient);

  // Turkish measurement units
  const turkishMeasurements = [
    'çay bardağı', 'çay kaşığı', 'yemek kaşığı',
    'su bardağı', 'kahve fincanı', 'adet', 'diş'
  ];
  const hasTurkishMeasurement = turkishMeasurements.some(unit =>
    ingredient.toLowerCase().includes(unit)
  );

  // Extract all measurement-like patterns
  const measurements: string[] = [];
  const measurementPattern = /(\d+(?:\/\d+)?)\s*(\w+)/g;
  let match;
  while ((match = measurementPattern.exec(ingredient)) !== null) {
    measurements.push(`${match[1]} ${match[2]}`);
  }

  return {
    original: ingredient,
    hasTurkishCharacters,
    hasFractionalMeasurement,
    hasTurkishMeasurement,
    measurements
  };
}

/**
 * Calculate accuracy percentage between Gemini and EDAMAM nutrition values
 *
 * @param gemini - Gemini nutrition value
 * @param edamam - EDAMAM nutrition value
 * @returns Accuracy percentage (0-100)
 */
export function calculateAccuracy(gemini: number, edamam: number): number {
  if (gemini === 0 && edamam === 0) return 100;
  if (gemini === 0 || edamam === 0) return 0;

  const difference = Math.abs(gemini - edamam);
  const average = (gemini + edamam) / 2;
  const errorPercentage = (difference / average) * 100;

  return Math.max(0, 100 - errorPercentage);
}

/**
 * Analyze overall test results for Turkish compatibility
 *
 * @param ingredients - Array of ingredient analyses
 * @returns Summary statistics
 */
export interface CompatibilitySummary {
  totalIngredients: number;
  turkishIngredientsCount: number;
  fractionalMeasurementsCount: number;
  turkishMeasurementsCount: number;
  turkishRecognitionRate: number;
}

export function analyzeCompatibility(ingredients: IngredientAnalysis[]): CompatibilitySummary {
  const totalIngredients = ingredients.length;
  const turkishIngredientsCount = ingredients.filter(i => i.hasTurkishCharacters).length;
  const fractionalMeasurementsCount = ingredients.filter(i => i.hasFractionalMeasurement).length;
  const turkishMeasurementsCount = ingredients.filter(i => i.hasTurkishMeasurement).length;

  const turkishRecognitionRate = totalIngredients > 0
    ? (turkishIngredientsCount / totalIngredients) * 100
    : 0;

  return {
    totalIngredients,
    turkishIngredientsCount,
    fractionalMeasurementsCount,
    turkishMeasurementsCount,
    turkishRecognitionRate
  };
}
