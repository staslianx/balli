/**
 * Recipe Memory Service
 * Business logic for memory-aware recipe generation with similarity checking
 */

import {
  RecipeMemoryEntry,
  IngredientClassification,
  VarietySuggestions,
  SimilarityCheckResult
} from "../types/recipe-memory";
import { ai } from "../genkit-instance";
import { getRecipeModel } from "../providers";
import { z } from "zod";

// Re-export types for convenience
export { RecipeMemoryEntry, IngredientClassification, VarietySuggestions, SimilarityCheckResult };

/**
 * Common Turkish protein ingredients for classification
 */
const PROTEIN_INGREDIENTS = new Set([
  "tavuk", "tavuk göğsü", "tavuk but", "hindi",
  "somon", "ton balığı", "levrek", "çipura", "hamsi", "sardalya", "karides",
  "dana eti", "kuzu eti", "kıyma", "köfte",
  "yumurta", "beyaz peynir", "lor peyniri", "süzme yoğurt", "kefir",
  "tofu", "tempeh", "edamame",
  "kırmızı mercimek", "yeşil mercimek", "nohut", "fasulye", "barbunya"
]);

/**
 * Common Turkish vegetable ingredients for classification
 */
const VEGETABLE_INGREDIENTS = new Set([
  "brokoli", "karnabahar", "lahana", "brüksel lahanası",
  "ıspanak", "roka", "marul", "semizotu", "tere",
  "domates", "salatalık", "biber", "sivri biber", "çarliston biber",
  "patlıcan", "kabak", "bal kabağı",
  "havuç", "kereviz", "kereviz sapı",
  "mantar", "kestane mantarı", "portobello",
  "kuşkonmaz", "pırasa", "soğan", "yeşil soğan", "sarımsak",
  "bamya", "taze fasulye", "bezelye", "mısır"
]);

/**
 * Normalizes an ingredient name for consistent matching
 * - Converts to lowercase
 * - Trims whitespace
 * - Applies consistent naming conventions
 */
export function normalizeIngredient(ingredient: string): string {
  let normalized = ingredient
    .toLowerCase()
    .trim();

  // Apply consistent naming conventions for common variations
  const replacements: Record<string, string> = {
    "piliç": "tavuk",
    "hindi": "tavuk",  // Unless specifically turkey
    "peynir": "beyaz peynir",  // Be specific
    "domatesler": "domates",  // Singular
    "brokoliler": "brokoli"
  };

  if (replacements[normalized]) {
    normalized = replacements[normalized];
  }

  return normalized;
}

/**
 * Classifies an ingredient as protein, vegetable, or other
 */
export function classifyIngredient(ingredient: string): "protein" | "vegetable" | "other" {
  const normalized = normalizeIngredient(ingredient);

  if (PROTEIN_INGREDIENTS.has(normalized)) {
    return "protein";
  }

  // Check for protein keywords
  const proteinKeywords = ["et", "balık", "tavuk", "peynir", "yoğurt", "mercimek", "fasulye", "nohut"];
  if (proteinKeywords.some(keyword => normalized.includes(keyword))) {
    return "protein";
  }

  if (VEGETABLE_INGREDIENTS.has(normalized)) {
    return "vegetable";
  }

  return "other";
}

/**
 * Classifies a list of ingredients into proteins, vegetables, and other
 */
export function classifyIngredients(ingredients: string[]): IngredientClassification {
  const classification: IngredientClassification = {
    proteins: [],
    vegetables: [],
    other: []
  };

  for (const ingredient of ingredients) {
    const type = classifyIngredient(ingredient);
    classification[`${type}s` as keyof IngredientClassification].push(ingredient);
  }

  return classification;
}

/**
 * Analyzes ingredient frequency across memory entries
 * Returns ingredients sorted by usage (least-used first)
 */
export function analyzeIngredientFrequency(
  memoryEntries: RecipeMemoryEntry[]
): Record<string, number> {
  const frequencyMap: Record<string, number> = {};

  for (const entry of memoryEntries) {
    for (const ingredient of entry.mainIngredients) {
      const normalized = normalizeIngredient(ingredient);
      frequencyMap[normalized] = (frequencyMap[normalized] || 0) + 1;
    }
  }

  return frequencyMap;
}

/**
 * Gets least-used ingredients for variety suggestions
 */
export function getLeastUsedIngredients(
  memoryEntries: RecipeMemoryEntry[],
  proteinCount: number = 3,
  vegetableCount: number = 3
): VarietySuggestions {
  const frequencyMap = analyzeIngredientFrequency(memoryEntries);

  // Classify all ingredients by type
  const proteinFrequencies: [string, number][] = [];
  const vegetableFrequencies: [string, number][] = [];

  for (const [ingredient, count] of Object.entries(frequencyMap)) {
    const type = classifyIngredient(ingredient);
    if (type === "protein") {
      proteinFrequencies.push([ingredient, count]);
    } else if (type === "vegetable") {
      vegetableFrequencies.push([ingredient, count]);
    }
  }

  // Sort by frequency (ascending = least-used first)
  proteinFrequencies.sort((a, b) => a[1] - b[1]);
  vegetableFrequencies.sort((a, b) => a[1] - b[1]);

  return {
    leastUsedProteins: proteinFrequencies.slice(0, proteinCount).map(([ing]) => ing),
    leastUsedVegetables: vegetableFrequencies.slice(0, vegetableCount).map(([ing]) => ing),
    frequencyMap
  };
}

/**
 * Checks if two recipes are too similar (3+ ingredient overlap)
 */
export function checkSimilarity(
  newIngredients: string[],
  existingEntry: RecipeMemoryEntry
): SimilarityCheckResult {
  const normalizedNew = new Set(newIngredients.map(normalizeIngredient));
  const normalizedExisting = new Set(existingEntry.mainIngredients.map(normalizeIngredient));

  const matchingIngredients: string[] = [];
  for (const ingredient of normalizedNew) {
    if (normalizedExisting.has(ingredient)) {
      matchingIngredients.push(ingredient);
    }
  }

  const matchCount = matchingIngredients.length;
  const isSimilar = matchCount >= 3;

  return {
    isSimilar,
    matchCount,
    matchingIngredients
  };
}

/**
 * Checks if new recipe is too similar to any of the last N recipes
 */
export function checkSimilarityAgainstRecent(
  newIngredients: string[],
  recentEntries: RecipeMemoryEntry[],
  checkLimit: number = 10
): SimilarityCheckResult {
  const entriesToCheck = recentEntries.slice(0, checkLimit);

  for (let i = 0; i < entriesToCheck.length; i++) {
    const result = checkSimilarity(newIngredients, entriesToCheck[i]);
    if (result.isSimilar) {
      return {
        ...result,
        matchedRecipeIndex: i
      };
    }
  }

  return {
    isSimilar: false,
    matchCount: 0,
    matchingIngredients: []
  };
}

/**
 * Extracts main ingredients from recipe content using Gemini
 * Returns 3-5 key ingredients in Turkish (normalized)
 */
export async function extractMainIngredients(
  recipeContent: string,
  recipeName: string
): Promise<string[]> {
  const extractionPrompt = ai.definePrompt(
    {
      name: "extractMainIngredients",
      description: "Extract main ingredients from Turkish recipe text",
      input: {
        schema: z.object({
          recipeContent: z.string(),
          recipeName: z.string()
        })
      },
      output: {
        schema: z.object({
          mainIngredients: z.array(z.string()).min(3).max(5).describe(
            "3-5 ana malzeme (Türkçe): birincil protein, 2-3 ana sebze, belirgin lezzet bileşeni. " +
            "SADECE malzeme adları, ölçü birimleri yok. Küçük harfle, tekil formda."
          )
        })
      }
    },
    async (input) => {
      return {
        messages: [
          {
            role: "user",
            content: [
              {
                text: `Tarif: ${input.recipeName}\n\nİçerik:\n${input.recipeContent}\n\n` +
                  `Bu tariften 3-5 ana malzemeyi çıkar:\n` +
                  `- Birincil protein (varsa): "tavuk göğsü", "somon", "tofu"\n` +
                  `- 2-3 ana sebze: "brokoli", "kabak", "biber"\n` +
                  `- Belirgin lezzet bileşeni: "sarımsak", "zencefil", "limon"\n\n` +
                  `KULLANMA: tuz, karabiber, zeytinyağı, su gibi yaygın baharatlar\n` +
                  `SADECE malzeme adlarını ver, ölçü birimleri yok.\n` +
                  `Küçük harfle ve tekil formda yaz.`
              }
            ]
          }
        ]
      };
    }
  );

  try {
    const result = await extractionPrompt(
      {
        recipeContent,
        recipeName
      },
      {
        model: getRecipeModel() // Use provider-specific model for extraction
      }
    );

    // Access the output from the prompt result
    const output = result.output;
    if (!output || !output.mainIngredients) {
      console.warn("No main ingredients extracted");
      return [];
    }

    // Normalize all extracted ingredients
    return output.mainIngredients.map(normalizeIngredient);
  } catch (error) {
    console.error("Failed to extract main ingredients:", error);
    // Fallback: return empty array, don't block recipe generation
    return [];
  }
}

/**
 * Builds variety suggestions text for recipe generation prompt
 */
export function buildVarietySuggestionsText(
  suggestions: VarietySuggestions
): string {
  const parts: string[] = [];

  if (suggestions.leastUsedProteins.length > 0) {
    parts.push(`Proteinler: ${suggestions.leastUsedProteins.join(", ")}`);
  }

  if (suggestions.leastUsedVegetables.length > 0) {
    parts.push(`Sebzeler: ${suggestions.leastUsedVegetables.join(", ")}`);
  }

  if (parts.length === 0) {
    return "";
  }

  return `Çeşitlilik için, iyi bir araya gelen bu malzemelerden bazılarını kullanmayı düşün:\n${parts.join("\n")}`;
}

/**
 * Gets subcategory context description for prompts
 */
export function getSubcategoryContext(subcategory: string): string {
  // Map styleType (which is now subcategory) to context
  const contexts: Record<string, string> = {
    "Kahvaltı": "Diyabet dostu kahvaltı",
    "Atıştırmalık": "Sağlıklı atıştırmalıklar",
    "Doyurucu salata": "Protein içeren ana yemek olarak servis edilen doyurucu bir salata",
    "Hafif salata": "Yan yemek olarak servis edilen hafif bir salata",
    "Karbonhidrat ve Protein Uyumu": "Dengeli karbonhidrat ve protein kombinasyonu içeren akşam yemeği",
    "Tam Buğday Makarna": "Tam buğday makarna çeşitleri",
    "Sana Özel Tatlılar": "Diyabet dostu tatlı versiyonları",
    "Dondurma": "Ninja Creami makinesi için diyabet dostu dondurma",
    "Meyve Salatası": "Diyabet yönetimine uygun meyve salatası"
  };

  return contexts[subcategory] || subcategory;
}
