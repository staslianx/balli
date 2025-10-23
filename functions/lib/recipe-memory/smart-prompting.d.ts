/**
 * Smart Prompting System
 *
 * Enhances recipe generation prompts with intelligent suggestions based on:
 * - User history and diversity gaps
 * - Seasonal ingredient availability
 * - Contextual hints for better AI generation
 */
import { RecipeMemory } from './types';
/**
 * Get seasonal ingredients for the current month
 *
 * @param month - Month number (1-12)
 * @param region - Region for seasonal variation (default: 'mediterranean')
 * @returns Array of seasonal ingredients
 */
export declare function getSeasonalIngredients(month: number, region?: 'mediterranean' | 'tropical' | 'temperate'): string[];
/**
 * Add seasonal hints to prompt
 */
export declare function addSeasonalHints(prompt: string, currentMonth?: number): string;
/**
 * Generate a "surprise me" prompt that fills diversity gaps
 *
 * Analyzes user history and suggests underrepresented options
 *
 * @param recentRecipes - User's recent recipe history
 * @param basePrompt - Original prompt (optional)
 * @returns Enhanced prompt with diversity suggestions
 */
export declare function generateSurpriseMePrompt(recentRecipes: RecipeMemory[], basePrompt?: string): string;
/**
 * Generate multiple "surprise me" options for user to choose from
 */
export declare function generateSurpriseMeOptions(recentRecipes: RecipeMemory[], count?: number): Array<{
    prompt: string;
    cuisine: string;
    protein: string;
    description: string;
}>;
/**
 * Add contextual hints to improve AI generation quality
 *
 * Adds hints about:
 * - Meal timing (breakfast needs quick prep, dinner allows complexity)
 * - Portion context (for diabetes management)
 * - Cooking skill level
 */
export declare function addContextualHints(prompt: string, context?: {
    mealType?: string;
    skillLevel?: 'beginner' | 'intermediate' | 'advanced';
    timeConstraint?: 'quick' | 'moderate' | 'relaxed';
    servings?: number;
}): string;
/**
 * Add diabetes-friendly constraints to prompt
 */
export declare function addDiabetesFriendlyHints(prompt: string, targetGlycemicLoad?: 'low' | 'moderate'): string;
/**
 * Pre-built prompt templates for common scenarios
 */
export declare const PROMPT_TEMPLATES: {
    quickBreakfast: string;
    balancedDinner: string;
    lowCarbMeal: string;
    mealPrep: string;
    comfortFood: string;
    onePot: string;
    vegetarianProtein: string;
    familyFriendly: string;
};
/**
 * Apply a template to a base prompt
 */
export declare function applyTemplate(templateKey: keyof typeof PROMPT_TEMPLATES, additionalContext?: string): string;
/**
 * Get time-of-day appropriate suggestions
 */
export declare function getTimeBasedSuggestions(): {
    mealType: string;
    suggestions: string[];
};
/**
 * Enhance any prompt with all smart features
 */
export declare function enhancePrompt(basePrompt: string, options?: {
    addSeasonal?: boolean;
    addContextual?: boolean;
    addDiabetesFriendly?: boolean;
    context?: {
        mealType?: string;
        skillLevel?: 'beginner' | 'intermediate' | 'advanced';
        timeConstraint?: 'quick' | 'moderate' | 'relaxed';
        servings?: number;
    };
    targetGlycemicLoad?: 'low' | 'moderate';
}): string;
//# sourceMappingURL=smart-prompting.d.ts.map