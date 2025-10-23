/**
 * User Preferences Manager
 *
 * Manages user dietary preferences, restrictions, and customizations
 * for personalized recipe generation.
 */
import { UserPreferences } from './types';
/**
 * Get user preferences from Firestore
 *
 * @param userId - User ID
 * @returns User preferences or default preferences if not found
 */
export declare function getUserPreferences(userId: string): Promise<UserPreferences>;
/**
 * Update user preferences in Firestore
 *
 * @param userId - User ID
 * @param preferences - Updated preferences (partial update supported)
 */
export declare function updatePreferences(userId: string, preferences: Partial<Omit<UserPreferences, 'userId' | 'createdAt'>>): Promise<void>;
/**
 * Delete user preferences from Firestore
 *
 * @param userId - User ID
 */
export declare function deletePreferences(userId: string): Promise<void>;
/**
 * Apply user preferences to recipe generation prompt
 *
 * Enhances prompt with dietary restrictions, allergens, and preferences
 *
 * @param basePrompt - Original recipe prompt
 * @param preferences - User preferences
 * @returns Enhanced prompt with preference constraints
 */
export declare function applyPreferencesToPrompt(basePrompt: string, preferences: UserPreferences): string;
/**
 * Check if a recipe violates user preferences
 *
 * Used for post-generation validation
 *
 * @param recipeJson - Generated recipe
 * @param preferences - User preferences
 * @returns Validation result with violations
 */
export declare function validateRecipeAgainstPreferences(recipeJson: any, preferences: UserPreferences): {
    isValid: boolean;
    violations: string[];
};
/**
 * Get preference summary for logging/debugging
 */
export declare function getPreferenceSummary(preferences: UserPreferences): string;
/**
 * Merge preferences (useful for partial updates)
 */
export declare function mergePreferences(existing: UserPreferences, updates: Partial<UserPreferences>): UserPreferences;
//# sourceMappingURL=preferences-manager.d.ts.map