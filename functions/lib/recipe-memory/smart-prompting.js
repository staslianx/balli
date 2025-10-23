"use strict";
/**
 * Smart Prompting System
 *
 * Enhances recipe generation prompts with intelligent suggestions based on:
 * - User history and diversity gaps
 * - Seasonal ingredient availability
 * - Contextual hints for better AI generation
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.PROMPT_TEMPLATES = void 0;
exports.getSeasonalIngredients = getSeasonalIngredients;
exports.addSeasonalHints = addSeasonalHints;
exports.generateSurpriseMePrompt = generateSurpriseMePrompt;
exports.generateSurpriseMeOptions = generateSurpriseMeOptions;
exports.addContextualHints = addContextualHints;
exports.addDiabetesFriendlyHints = addDiabetesFriendlyHints;
exports.applyTemplate = applyTemplate;
exports.getTimeBasedSuggestions = getTimeBasedSuggestions;
exports.enhancePrompt = enhancePrompt;
const diversity_scorer_1 = require("./diversity-scorer");
// ============================================================================
// SEASONAL AWARENESS
// ============================================================================
/**
 * Get seasonal ingredients for the current month
 *
 * @param month - Month number (1-12)
 * @param region - Region for seasonal variation (default: 'mediterranean')
 * @returns Array of seasonal ingredients
 */
function getSeasonalIngredients(month, region = 'mediterranean') {
    // Mediterranean/Turkish seasonal calendar
    const seasonalMap = {
        1: ['kale', 'brussels sprouts', 'citrus fruits', 'pomegranate', 'leeks'],
        2: ['cabbage', 'cauliflower', 'broccoli', 'oranges', 'spinach'],
        3: ['asparagus', 'artichokes', 'peas', 'radishes', 'spring onions'],
        4: ['strawberries', 'lettuce', 'new potatoes', 'fava beans', 'mint'],
        5: ['cherries', 'green beans', 'zucchini', 'basil', 'apricots'],
        6: ['tomatoes', 'cucumbers', 'bell peppers', 'melons', 'eggplant'],
        7: ['peaches', 'corn', 'watermelon', 'summer squash', 'berries'],
        8: ['figs', 'grapes', 'plums', 'okra', 'hot peppers'],
        9: ['apples', 'pears', 'pumpkin', 'mushrooms', 'sweet potatoes'],
        10: ['quince', 'chestnuts', 'pomegranate', 'kale', 'cabbage'],
        11: ['citrus', 'persimmons', 'Brussels sprouts', 'celery', 'fennel'],
        12: ['winter squash', 'root vegetables', 'kale', 'tangerines', 'leeks'],
    };
    return seasonalMap[month] || [];
}
/**
 * Add seasonal hints to prompt
 */
function addSeasonalHints(prompt, currentMonth) {
    const month = currentMonth || new Date().getMonth() + 1; // 1-12
    const seasonalIngredients = getSeasonalIngredients(month);
    if (seasonalIngredients.length === 0) {
        return prompt;
    }
    const seasonalHint = `\n\nSEASONAL SUGGESTION: It's ${getSeasonName(month)}. Consider using seasonal ingredients like: ${seasonalIngredients.slice(0, 5).join(', ')}.`;
    return prompt + seasonalHint;
}
/**
 * Get season name from month
 */
function getSeasonName(month) {
    if (month >= 3 && month <= 5)
        return 'spring';
    if (month >= 6 && month <= 8)
        return 'summer';
    if (month >= 9 && month <= 11)
        return 'fall';
    return 'winter';
}
// ============================================================================
// "SURPRISE ME" MODE
// ============================================================================
/**
 * Generate a "surprise me" prompt that fills diversity gaps
 *
 * Analyzes user history and suggests underrepresented options
 *
 * @param recentRecipes - User's recent recipe history
 * @param basePrompt - Original prompt (optional)
 * @returns Enhanced prompt with diversity suggestions
 */
function generateSurpriseMePrompt(recentRecipes, basePrompt) {
    // Build diversity constraints from history
    const constraints = (0, diversity_scorer_1.buildDiversityConstraints)(recentRecipes, 15);
    // Pick an underrepresented cuisine
    const suggestedCuisine = constraints.suggestCuisines.length > 0
        ? pickRandom(constraints.suggestCuisines)
        : 'Mediterranean';
    // Pick an underrepresented protein
    const suggestedProtein = constraints.suggestProteins.length > 0
        ? pickRandom(constraints.suggestProteins)
        : 'fish';
    // Get seasonal ingredients
    const month = new Date().getMonth() + 1;
    const seasonalIngredients = getSeasonalIngredients(month);
    const seasonalPick = pickRandom(seasonalIngredients);
    // Build surprise prompt
    const surprisePrompt = `Create a ${suggestedCuisine} recipe featuring ${suggestedProtein}`;
    // Add seasonal ingredient if available
    const finalPrompt = seasonalPick
        ? `${surprisePrompt}, incorporating seasonal ${seasonalPick}.`
        : `${surprisePrompt}.`;
    // Add context about why these were chosen
    const context = `\n\nCONTEXT: This recipe fills diversity gaps in your recent history:
- You haven't tried ${suggestedCuisine} cuisine recently
- ${suggestedProtein} is underrepresented in your protein rotation${seasonalPick ? `\n- ${seasonalPick} is in season this month` : ''}`;
    return basePrompt ? `${basePrompt}\n\n${finalPrompt}${context}` : `${finalPrompt}${context}`;
}
/**
 * Generate multiple "surprise me" options for user to choose from
 */
function generateSurpriseMeOptions(recentRecipes, count = 3) {
    const constraints = (0, diversity_scorer_1.buildDiversityConstraints)(recentRecipes, 15);
    const options = [];
    // Generate multiple diverse options
    for (let i = 0; i < count; i++) {
        const cuisine = pickRandom(constraints.suggestCuisines) || 'Mediterranean';
        const protein = pickRandom(constraints.suggestProteins) || 'chicken';
        options.push({
            prompt: `Create a ${cuisine} recipe featuring ${protein}`,
            cuisine,
            protein,
            description: `${cuisine} cuisine with ${protein} (underexplored in your history)`,
        });
    }
    return options;
}
// ============================================================================
// CONTEXTUAL ENHANCEMENTS
// ============================================================================
/**
 * Add contextual hints to improve AI generation quality
 *
 * Adds hints about:
 * - Meal timing (breakfast needs quick prep, dinner allows complexity)
 * - Portion context (for diabetes management)
 * - Cooking skill level
 */
function addContextualHints(prompt, context) {
    const hints = [];
    if (context?.mealType) {
        const mealTypeHints = {
            breakfast: 'Keep it quick and energizing (15-20 min prep)',
            lunch: 'Make it satisfying but not too heavy',
            dinner: 'Can be more elaborate, aim for balanced nutrition',
            snack: 'Keep it light and portion-controlled',
        };
        const hint = mealTypeHints[context.mealType.toLowerCase()];
        if (hint) {
            hints.push(hint);
        }
    }
    if (context?.skillLevel) {
        const skillHints = {
            beginner: 'Use simple techniques and common ingredients',
            intermediate: 'Can include multiple cooking steps',
            advanced: 'Feel free to use advanced techniques',
        };
        hints.push(skillHints[context.skillLevel]);
    }
    if (context?.timeConstraint) {
        const timeHints = {
            quick: 'Total time under 30 minutes',
            moderate: 'Total time 30-60 minutes',
            relaxed: 'Can take over an hour if needed',
        };
        hints.push(timeHints[context.timeConstraint]);
    }
    if (context?.servings && context.servings !== 4) {
        hints.push(`Recipe for ${context.servings} servings`);
    }
    if (hints.length === 0) {
        return prompt;
    }
    return `${prompt}\n\nGUIDANCE: ${hints.join('. ')}.`;
}
// ============================================================================
// HEALTH-AWARE PROMPTING (for Diabetes Management)
// ============================================================================
/**
 * Add diabetes-friendly constraints to prompt
 */
function addDiabetesFriendlyHints(prompt, targetGlycemicLoad) {
    const glHints = {
        low: 'Focus on low glycemic load (GL < 10): use whole grains, legumes, non-starchy vegetables',
        moderate: 'Aim for moderate glycemic load (GL 10-20): balanced portions of carbs with protein and fiber',
    };
    const baseHints = [
        'Include adequate protein and healthy fats',
        'Limit added sugars',
        'Prefer high-fiber ingredients',
        'Provide portion guidance',
    ];
    const glHint = targetGlycemicLoad ? glHints[targetGlycemicLoad] : null;
    const allHints = glHint ? [glHint, ...baseHints] : baseHints;
    return `${prompt}\n\nDIABETES-FRIENDLY: ${allHints.join('. ')}.`;
}
// ============================================================================
// PROMPT TEMPLATES
// ============================================================================
/**
 * Pre-built prompt templates for common scenarios
 */
exports.PROMPT_TEMPLATES = {
    quickBreakfast: 'A quick and healthy breakfast that takes under 20 minutes',
    balancedDinner: 'A balanced dinner with protein, vegetables, and complex carbs',
    lowCarbMeal: 'A satisfying low-carb meal under 30g net carbs per serving',
    mealPrep: 'A recipe perfect for meal prep that reheats well',
    comfortFood: 'A healthier version of a comfort food classic',
    onePot: 'A one-pot meal that minimizes cleanup',
    vegetarianProtein: 'A vegetarian recipe rich in plant-based protein',
    familyFriendly: 'A family-friendly recipe that kids and adults will enjoy',
};
/**
 * Apply a template to a base prompt
 */
function applyTemplate(templateKey, additionalContext) {
    const template = exports.PROMPT_TEMPLATES[templateKey];
    return additionalContext ? `${template}. ${additionalContext}` : template;
}
// ============================================================================
// UTILITIES
// ============================================================================
/**
 * Pick random item from array
 */
function pickRandom(array) {
    if (array.length === 0)
        return undefined;
    return array[Math.floor(Math.random() * array.length)];
}
/**
 * Get time-of-day appropriate suggestions
 */
function getTimeBasedSuggestions() {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 11) {
        return {
            mealType: 'breakfast',
            suggestions: ['Quick energy boost', 'Protein-rich start', 'Light and fresh'],
        };
    }
    else if (hour >= 11 && hour < 15) {
        return {
            mealType: 'lunch',
            suggestions: ['Balanced nutrition', 'Sustained energy', 'Not too heavy'],
        };
    }
    else if (hour >= 15 && hour < 17) {
        return {
            mealType: 'snack',
            suggestions: ['Light pick-me-up', 'Protein snack', 'Energy boost'],
        };
    }
    else {
        return {
            mealType: 'dinner',
            suggestions: ['Comfort and satisfaction', 'Family meal', 'Balanced plate'],
        };
    }
}
// ============================================================================
// EXPORT CONVENIENCE FUNCTIONS
// ============================================================================
/**
 * Enhance any prompt with all smart features
 */
function enhancePrompt(basePrompt, options) {
    let enhanced = basePrompt;
    if (options?.addSeasonal) {
        enhanced = addSeasonalHints(enhanced);
    }
    if (options?.addContextual && options.context) {
        enhanced = addContextualHints(enhanced, options.context);
    }
    if (options?.addDiabetesFriendly) {
        enhanced = addDiabetesFriendlyHints(enhanced, options.targetGlycemicLoad);
    }
    return enhanced;
}
//# sourceMappingURL=smart-prompting.js.map