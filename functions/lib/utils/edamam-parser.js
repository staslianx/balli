"use strict";
//
// edamam-parser.ts
// Utility functions for parsing Gemini recipe output and preparing for EDAMAM API
//
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseIngredientsFromMarkdown = parseIngredientsFromMarkdown;
exports.formatIngredientsForEdamam = formatIngredientsForEdamam;
exports.extractGeminiNutrition = extractGeminiNutrition;
exports.analyzeIngredient = analyzeIngredient;
exports.calculateAccuracy = calculateAccuracy;
exports.analyzeCompatibility = analyzeCompatibility;
/**
 * Parse ingredients from Gemini's markdown recipe content
 * Extracts ingredient list from "## Malzemeler" section
 *
 * @param recipeContent - Full markdown recipe content from Gemini
 * @returns Array of ingredient strings
 */
function parseIngredientsFromMarkdown(recipeContent) {
    // Find the "## Malzemeler" section (Turkish for "Ingredients")
    const ingredientsMatch = recipeContent.match(/## Malzemeler[\s\S]*?(?=\n##|$)/i);
    if (!ingredientsMatch) {
        console.warn('⚠️ [EDAMAM-PARSER] No "## Malzemeler" section found in recipe content');
        return [];
    }
    const ingredientsSection = ingredientsMatch[0];
    // Extract bullet points (lines starting with -)
    const bulletRegex = /^[\s]*-\s+(.+)$/gm;
    const ingredients = [];
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
function formatIngredientsForEdamam(ingredients) {
    return ingredients.map(ing => {
        // Clean up any markdown formatting that might have slipped through
        return ing
            .replace(/\*\*/g, '') // Remove bold **
            .replace(/\*/g, '') // Remove italic *
            .replace(/_/g, '') // Remove underscores
            .trim();
    });
}
function extractGeminiNutrition(geminiRecipe) {
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
function analyzeIngredient(ingredient) {
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
    const hasTurkishMeasurement = turkishMeasurements.some(unit => ingredient.toLowerCase().includes(unit));
    // Extract all measurement-like patterns
    const measurements = [];
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
function calculateAccuracy(gemini, edamam) {
    if (gemini === 0 && edamam === 0)
        return 100;
    if (gemini === 0 || edamam === 0)
        return 0;
    const difference = Math.abs(gemini - edamam);
    const average = (gemini + edamam) / 2;
    const errorPercentage = (difference / average) * 100;
    return Math.max(0, 100 - errorPercentage);
}
function analyzeCompatibility(ingredients) {
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
//# sourceMappingURL=edamam-parser.js.map