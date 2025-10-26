"use strict";
/**
 * Recipe Memory Service
 * Business logic for memory-aware recipe generation with similarity checking
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeIngredient = normalizeIngredient;
exports.classifyIngredient = classifyIngredient;
exports.classifyIngredients = classifyIngredients;
exports.analyzeIngredientFrequency = analyzeIngredientFrequency;
exports.getLeastUsedIngredients = getLeastUsedIngredients;
exports.checkSimilarity = checkSimilarity;
exports.checkSimilarityAgainstRecent = checkSimilarityAgainstRecent;
exports.extractMainIngredients = extractMainIngredients;
exports.buildVarietySuggestionsText = buildVarietySuggestionsText;
exports.getSubcategoryContext = getSubcategoryContext;
const genkit_instance_1 = require("../genkit-instance");
const providers_1 = require("../providers");
const zod_1 = require("zod");
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
function normalizeIngredient(ingredient) {
    let normalized = ingredient
        .toLowerCase()
        .trim();
    // Apply consistent naming conventions for common variations
    const replacements = {
        "piliç": "tavuk",
        "hindi": "tavuk", // Unless specifically turkey
        "peynir": "beyaz peynir", // Be specific
        "domatesler": "domates", // Singular
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
function classifyIngredient(ingredient) {
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
function classifyIngredients(ingredients) {
    const classification = {
        proteins: [],
        vegetables: [],
        other: []
    };
    for (const ingredient of ingredients) {
        const type = classifyIngredient(ingredient);
        classification[`${type}s`].push(ingredient);
    }
    return classification;
}
/**
 * Analyzes ingredient frequency across memory entries
 * Returns ingredients sorted by usage (least-used first)
 */
function analyzeIngredientFrequency(memoryEntries) {
    const frequencyMap = {};
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
function getLeastUsedIngredients(memoryEntries, proteinCount = 3, vegetableCount = 3) {
    const frequencyMap = analyzeIngredientFrequency(memoryEntries);
    // Classify all ingredients by type
    const proteinFrequencies = [];
    const vegetableFrequencies = [];
    for (const [ingredient, count] of Object.entries(frequencyMap)) {
        const type = classifyIngredient(ingredient);
        if (type === "protein") {
            proteinFrequencies.push([ingredient, count]);
        }
        else if (type === "vegetable") {
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
function checkSimilarity(newIngredients, existingEntry) {
    const normalizedNew = new Set(newIngredients.map(normalizeIngredient));
    const normalizedExisting = new Set(existingEntry.mainIngredients.map(normalizeIngredient));
    const matchingIngredients = [];
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
function checkSimilarityAgainstRecent(newIngredients, recentEntries, checkLimit = 10) {
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
async function extractMainIngredients(recipeContent, recipeName) {
    const extractionPrompt = genkit_instance_1.ai.definePrompt({
        name: "extractMainIngredients",
        description: "Extract main ingredients from Turkish recipe text",
        input: {
            schema: zod_1.z.object({
                recipeContent: zod_1.z.string(),
                recipeName: zod_1.z.string()
            })
        },
        output: {
            schema: zod_1.z.object({
                mainIngredients: zod_1.z.array(zod_1.z.string()).min(3).max(5).describe("3-5 ana malzeme (Türkçe): birincil protein, 2-3 ana sebze, belirgin lezzet bileşeni. " +
                    "SADECE malzeme adları, ölçü birimleri yok. Küçük harfle, tekil formda.")
            })
        }
    }, async (input) => {
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
    });
    try {
        const result = await extractionPrompt({
            recipeContent,
            recipeName
        }, {
            model: (0, providers_1.getRecipeModel)() // Use provider-specific model for extraction
        });
        // Access the output from the prompt result
        const output = result.output;
        if (!output || !output.mainIngredients) {
            console.warn("No main ingredients extracted");
            return [];
        }
        // Normalize all extracted ingredients
        return output.mainIngredients.map(normalizeIngredient);
    }
    catch (error) {
        console.error("Failed to extract main ingredients:", error);
        // Fallback: return empty array, don't block recipe generation
        return [];
    }
}
/**
 * Builds variety suggestions text for recipe generation prompt
 */
function buildVarietySuggestionsText(suggestions) {
    const parts = [];
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
function getSubcategoryContext(subcategory) {
    // Map styleType (which is now subcategory) to context
    const contexts = {
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
//# sourceMappingURL=recipe-memory.js.map