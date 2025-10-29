//
// usda-client.ts
// USDA FoodData Central API Client
// Fetches ground truth nutrition data for validation
//

// Load environment variables
import * as dotenv from 'dotenv';
dotenv.config();

const USDA_API_BASE_URL = 'https://api.nal.usda.gov/fdc/v1';
const USDA_API_KEY = process.env.USDA_API_KEY;

// Rate limiting: 1,000 requests/hour = 16.67 req/min ≈ 1 req every 3.6 seconds
const RATE_LIMIT_DELAY = 4000; // 4 seconds between requests for safety
let lastRequestTime = 0;

/**
 * Nutrition data structure (per 100g)
 */
export interface USDANutrition {
  calories: number;          // kcal per 100g
  carbohydrates: number;     // g per 100g
  protein: number;           // g per 100g
  fat: number;               // g per 100g
  fiber: number;             // g per 100g
  sugar: number;             // g per 100g
}

/**
 * USDA API search response (simplified)
 */
interface USDASearchResponse {
  foods: Array<{
    fdcId: number;
    description: string;
    dataType: string;
    brandOwner?: string;
    foodNutrients: Array<{
      nutrientId: number;
      nutrientName: string;
      nutrientNumber: string;
      unitName: string;
      value: number;
    }>;
  }>;
  totalHits: number;
}

/**
 * USDA nutrient IDs (from FoodData Central documentation)
 */
const NUTRIENT_IDS = {
  ENERGY: 1008,           // Energy (kcal)
  CARBOHYDRATE: 1005,     // Carbohydrate, by difference (g)
  PROTEIN: 1003,          // Protein (g)
  FAT: 1004,              // Total lipid (fat) (g)
  FIBER: 1079,            // Fiber, total dietary (g)
  SUGAR: 2000             // Total sugars (g)
};

/**
 * Rate-limited delay to respect USDA API limits
 */
async function rateLimitDelay(): Promise<void> {
  const now = Date.now();
  const timeSinceLastRequest = now - lastRequestTime;

  if (timeSinceLastRequest < RATE_LIMIT_DELAY) {
    const delayNeeded = RATE_LIMIT_DELAY - timeSinceLastRequest;
    console.log(`⏱️ [USDA] Rate limiting: waiting ${delayNeeded}ms`);
    await new Promise(resolve => setTimeout(resolve, delayNeeded));
  }

  lastRequestTime = Date.now();
}

/**
 * Search for food in USDA database by English term
 *
 * @param searchTerm - English food name (e.g., "chicken breast cooked")
 * @returns USDA nutrition data per 100g, or null if not found
 */
export async function searchUSDAFood(searchTerm: string): Promise<USDANutrition | null> {
  if (!USDA_API_KEY) {
    throw new Error('USDA_API_KEY not configured in environment variables');
  }

  console.log(`🔍 [USDA] Searching for: "${searchTerm}"`);

  // Rate limiting
  await rateLimitDelay();

  // Search for food
  const searchUrl = `${USDA_API_BASE_URL}/foods/search`;
  const searchParams = new URLSearchParams({
    api_key: USDA_API_KEY,
    query: searchTerm,
    dataType: 'Survey (FNDDS),Foundation,SR Legacy', // Prefer high-quality data
    pageSize: '5', // Get top 5 results to find best match
    pageNumber: '1',
    sortBy: 'dataType.keyword', // Prioritize Foundation/SR Legacy
    sortOrder: 'asc'
  });

  const response = await fetch(`${searchUrl}?${searchParams.toString()}`);

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`USDA API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json() as USDASearchResponse;

  if (!data.foods || data.foods.length === 0) {
    console.warn(`⚠️ [USDA] No results found for: "${searchTerm}"`);
    return null;
  }

  // Find best match (prefer Foundation/SR Legacy, avoid branded foods)
  const bestMatch = data.foods.find(food =>
    food.dataType === 'Foundation' || food.dataType === 'SR Legacy'
  ) || data.foods[0]; // Fallback to first result if no Foundation/SR Legacy

  console.log(`✅ [USDA] Found: "${bestMatch.description}" (${bestMatch.dataType})`);

  // Extract nutrition data
  const nutrition = extractNutrition(bestMatch.foodNutrients);

  if (!nutrition) {
    console.warn(`⚠️ [USDA] Incomplete nutrition data for: "${searchTerm}"`);
    return null;
  }

  return nutrition;
}

/**
 * Extract and normalize nutrition data from USDA food nutrients
 *
 * @param nutrients - Array of USDA food nutrients
 * @returns Normalized nutrition per 100g, or null if incomplete
 */
function extractNutrition(
  nutrients: Array<{
    nutrientId: number;
    nutrientName: string;
    value: number;
    unitName: string;
  }>
): USDANutrition | null {
  // Helper to find nutrient value by ID
  const getNutrient = (nutrientId: number): number => {
    const nutrient = nutrients.find(n => n.nutrientId === nutrientId);
    return nutrient ? nutrient.value : 0;
  };

  const nutrition: USDANutrition = {
    calories: getNutrient(NUTRIENT_IDS.ENERGY),
    carbohydrates: getNutrient(NUTRIENT_IDS.CARBOHYDRATE),
    protein: getNutrient(NUTRIENT_IDS.PROTEIN),
    fat: getNutrient(NUTRIENT_IDS.FAT),
    fiber: getNutrient(NUTRIENT_IDS.FIBER),
    sugar: getNutrient(NUTRIENT_IDS.SUGAR)
  };

  // Validate that we have at least the core macros
  if (nutrition.calories === 0 && nutrition.carbohydrates === 0 &&
      nutrition.protein === 0 && nutrition.fat === 0) {
    return null; // No useful nutrition data
  }

  // USDA data is already per 100g, so no conversion needed
  console.log(`📊 [USDA] Nutrition (per 100g):`, nutrition);

  return nutrition;
}

/**
 * Batch search for multiple foods (with rate limiting)
 *
 * @param searches - Map of Turkish name to English search term
 * @returns Map of Turkish name to USDA nutrition data
 */
export async function batchSearchUSDA(
  searches: Map<string, string>
): Promise<Map<string, USDANutrition | null>> {
  const results = new Map<string, USDANutrition | null>();

  console.log(`🔍 [USDA] Batch searching ${searches.size} foods...`);

  for (const [turkishName, englishTerm] of searches.entries()) {
    console.log(`\n📝 [USDA] Processing: ${turkishName} → "${englishTerm}"`);

    try {
      const nutrition = await searchUSDAFood(englishTerm);
      results.set(turkishName, nutrition);

      if (nutrition) {
        console.log(`✅ [USDA] Success: ${turkishName}`);
      } else {
        console.warn(`⚠️ [USDA] No data: ${turkishName}`);
      }
    } catch (error) {
      console.error(`❌ [USDA] Error for ${turkishName}:`, error);
      results.set(turkishName, null);
    }
  }

  const successCount = Array.from(results.values()).filter(n => n !== null).length;
  console.log(`\n✅ [USDA] Batch complete: ${successCount}/${searches.size} successful`);

  return results;
}
