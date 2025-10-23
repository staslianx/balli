"use strict";
/**
 * User Preferences Manager
 *
 * Manages user dietary preferences, restrictions, and customizations
 * for personalized recipe generation.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getUserPreferences = getUserPreferences;
exports.updatePreferences = updatePreferences;
exports.deletePreferences = deletePreferences;
exports.applyPreferencesToPrompt = applyPreferencesToPrompt;
exports.validateRecipeAgainstPreferences = validateRecipeAgainstPreferences;
exports.getPreferenceSummary = getPreferenceSummary;
exports.mergePreferences = mergePreferences;
const firestore_1 = require("firebase-admin/firestore");
const genkit_instance_1 = require("../genkit-instance");
// ============================================================================
// FIRESTORE OPERATIONS
// ============================================================================
/**
 * Get user preferences from Firestore
 *
 * @param userId - User ID
 * @returns User preferences or default preferences if not found
 */
async function getUserPreferences(userId) {
    try {
        const docRef = genkit_instance_1.db.collection('user_preferences').doc(userId);
        const doc = await docRef.get();
        if (doc.exists) {
            const data = doc.data();
            console.log(`✅ [PREFS] Loaded preferences for user ${userId}`);
            return data;
        }
        // Return default preferences if not found
        console.log(`📝 [PREFS] No preferences found for user ${userId}, using defaults`);
        return getDefaultPreferences(userId);
    }
    catch (error) {
        console.error(`❌ [PREFS] Error loading preferences for user ${userId}:`, error);
        return getDefaultPreferences(userId);
    }
}
/**
 * Update user preferences in Firestore
 *
 * @param userId - User ID
 * @param preferences - Updated preferences (partial update supported)
 */
async function updatePreferences(userId, preferences) {
    try {
        const docRef = genkit_instance_1.db.collection('user_preferences').doc(userId);
        const doc = await docRef.get();
        if (doc.exists) {
            // Update existing preferences
            await docRef.update({
                ...preferences,
                updatedAt: firestore_1.Timestamp.now(),
            });
            console.log(`✅ [PREFS] Updated preferences for user ${userId}`);
        }
        else {
            // Create new preferences document
            const defaults = getDefaultPreferences(userId);
            const newPreferences = {
                ...defaults,
                ...preferences,
                userId,
                createdAt: defaults.createdAt,
                updatedAt: firestore_1.Timestamp.now(),
            };
            await docRef.set(newPreferences);
            console.log(`✅ [PREFS] Created preferences for user ${userId}`);
        }
    }
    catch (error) {
        console.error(`❌ [PREFS] Error updating preferences for user ${userId}:`, error);
        throw new Error(`Failed to update preferences: ${error}`);
    }
}
/**
 * Delete user preferences from Firestore
 *
 * @param userId - User ID
 */
async function deletePreferences(userId) {
    try {
        await genkit_instance_1.db.collection('user_preferences').doc(userId).delete();
        console.log(`✅ [PREFS] Deleted preferences for user ${userId}`);
    }
    catch (error) {
        console.error(`❌ [PREFS] Error deleting preferences for user ${userId}:`, error);
        throw new Error(`Failed to delete preferences: ${error}`);
    }
}
// ============================================================================
// DEFAULT PREFERENCES
// ============================================================================
/**
 * Get default user preferences
 */
function getDefaultPreferences(userId) {
    return {
        userId,
        dietaryRestrictions: [],
        allergens: [],
        dislikedIngredients: [],
        favoriteCuisines: [],
        favoriteProteins: [],
        preferredCookingMethods: [],
        healthGoals: [],
        calorieTarget: undefined,
        createdAt: firestore_1.Timestamp.now(),
        updatedAt: firestore_1.Timestamp.now(),
    };
}
// ============================================================================
// PROMPT ENHANCEMENT
// ============================================================================
/**
 * Apply user preferences to recipe generation prompt
 *
 * Enhances prompt with dietary restrictions, allergens, and preferences
 *
 * @param basePrompt - Original recipe prompt
 * @param preferences - User preferences
 * @returns Enhanced prompt with preference constraints
 */
function applyPreferencesToPrompt(basePrompt, preferences) {
    const constraints = [];
    // Dietary restrictions (HARD constraints)
    if (preferences.dietaryRestrictions.length > 0) {
        const restrictionsStr = preferences.dietaryRestrictions.join(', ');
        constraints.push(`ÖNEMLI: ${restrictionsStr} diyetine uygun olmalı`);
    }
    // Allergens (HARD constraints)
    if (preferences.allergens.length > 0) {
        const allergensStr = preferences.allergens.join(', ');
        constraints.push(`ALERJEN UYARI: ${allergensStr} içermemeli`);
    }
    // Disliked ingredients (SOFT constraints)
    if (preferences.dislikedIngredients.length > 0) {
        const dislikedStr = preferences.dislikedIngredients.join(', ');
        constraints.push(`Mümkünse ${dislikedStr} kullanma`);
    }
    // Health goals (SOFT constraints)
    if (preferences.healthGoals && preferences.healthGoals.length > 0) {
        const goalsStr = preferences.healthGoals.join(', ');
        constraints.push(`Sağlık hedefi: ${goalsStr}`);
    }
    // Calorie target (SOFT constraint)
    if (preferences.calorieTarget) {
        constraints.push(`Hedef kalori: yaklaşık ${preferences.calorieTarget} kcal/porsiyon`);
    }
    // Combine prompt with constraints
    if (constraints.length === 0) {
        return basePrompt;
    }
    return `${basePrompt}

Kullanıcı tercihleri:
${constraints.map((c, i) => `${i + 1}. ${c}`).join('\n')}`;
}
/**
 * Check if a recipe violates user preferences
 *
 * Used for post-generation validation
 *
 * @param recipeJson - Generated recipe
 * @param preferences - User preferences
 * @returns Validation result with violations
 */
function validateRecipeAgainstPreferences(recipeJson, preferences) {
    const violations = [];
    // Extract ingredients from recipe
    const ingredientsList = recipeJson.ingredients || [];
    const ingredientNames = ingredientsList
        .map((ing) => (typeof ing === 'string' ? ing : ing.item || ''))
        .map((name) => name.toLowerCase());
    // Check allergens (CRITICAL - must not be present)
    preferences.allergens.forEach((allergen) => {
        const allergenLower = allergen.toLowerCase();
        ingredientNames.forEach((ingredient) => {
            if (ingredient.includes(allergenLower)) {
                violations.push(`Alerjen tespit edildi: ${allergen} (${ingredient})`);
            }
        });
    });
    // Check dietary restrictions
    preferences.dietaryRestrictions.forEach((restriction) => {
        const restrictionLower = restriction.toLowerCase();
        if (restrictionLower.includes('vegetarian') || restrictionLower.includes('vejetaryen')) {
            // Check for meat products
            const meatKeywords = ['chicken', 'beef', 'pork', 'fish', 'lamb', 'tavuk', 'et', 'balık'];
            ingredientNames.forEach((ingredient) => {
                meatKeywords.forEach((meat) => {
                    if (ingredient.includes(meat)) {
                        violations.push(`Vejetaryen diyetine uygun değil: ${ingredient}`);
                    }
                });
            });
        }
        if (restrictionLower.includes('vegan')) {
            // Check for animal products
            const animalProducts = [
                'milk', 'cheese', 'egg', 'butter', 'honey',
                'süt', 'peynir', 'yumurta', 'tereyağı', 'bal',
            ];
            ingredientNames.forEach((ingredient) => {
                animalProducts.forEach((product) => {
                    if (ingredient.includes(product)) {
                        violations.push(`Vegan diyetine uygun değil: ${ingredient}`);
                    }
                });
            });
        }
        if (restrictionLower.includes('gluten-free') || restrictionLower.includes('glutensiz')) {
            // Check for gluten-containing ingredients
            const glutenSources = ['wheat', 'flour', 'bread', 'pasta', 'buğday', 'un', 'ekmek', 'makarna'];
            ingredientNames.forEach((ingredient) => {
                glutenSources.forEach((gluten) => {
                    if (ingredient.includes(gluten)) {
                        violations.push(`Glutensiz diyetine uygun değil: ${ingredient}`);
                    }
                });
            });
        }
    });
    return {
        isValid: violations.length === 0,
        violations,
    };
}
// ============================================================================
// PREFERENCE HELPERS
// ============================================================================
/**
 * Get preference summary for logging/debugging
 */
function getPreferenceSummary(preferences) {
    const parts = [];
    if (preferences.dietaryRestrictions.length > 0) {
        parts.push(`Dietary: ${preferences.dietaryRestrictions.join(', ')}`);
    }
    if (preferences.allergens.length > 0) {
        parts.push(`Allergens: ${preferences.allergens.join(', ')}`);
    }
    if (preferences.dislikedIngredients.length > 0) {
        parts.push(`Dislikes: ${preferences.dislikedIngredients.join(', ')}`);
    }
    if (preferences.healthGoals && preferences.healthGoals.length > 0) {
        parts.push(`Goals: ${preferences.healthGoals.join(', ')}`);
    }
    return parts.length > 0 ? parts.join(' | ') : 'No preferences set';
}
/**
 * Merge preferences (useful for partial updates)
 */
function mergePreferences(existing, updates) {
    return {
        ...existing,
        ...updates,
        userId: existing.userId, // Never change userId
        createdAt: existing.createdAt, // Never change createdAt
        updatedAt: firestore_1.Timestamp.now(),
    };
}
//# sourceMappingURL=preferences-manager.js.map