/**
 * Memory Sync Cloud Functions
 *
 * HTTP endpoints for syncing iOS SwiftData memory to Firestore
 * Supports:
 * - User Facts (health, preferences, lifestyle)
 * - Conversation Summaries (session summaries)
 * - Recipe Preferences (saved recipes)
 * - Glucose Patterns (meal → glucose response)
 * - User Preferences (key-value settings)
 *
 * Conflict Resolution: Last-write-wins based on timestamps
 * Authentication: Hardcoded userId validation (2-user app)
 */
/**
 * User Facts Sync Endpoint
 * POST: Upload local facts to Firestore
 * GET: Download facts from Firestore
 */
export declare const syncUserFacts: import("firebase-functions/v2/https").HttpsFunction;
/**
 * Conversation Summaries Sync Endpoint
 */
export declare const syncConversationSummaries: import("firebase-functions/v2/https").HttpsFunction;
/**
 * Recipe Preferences Sync Endpoint
 */
export declare const syncRecipePreferences: import("firebase-functions/v2/https").HttpsFunction;
/**
 * Glucose Patterns Sync Endpoint
 */
export declare const syncGlucosePatterns: import("firebase-functions/v2/https").HttpsFunction;
/**
 * User Preferences Sync Endpoint
 */
export declare const syncUserPreferences: import("firebase-functions/v2/https").HttpsFunction;
/**
 * Unified Sync All Endpoint
 * Syncs all memory types in a single request
 */
export declare const syncAllMemory: import("firebase-functions/v2/https").HttpsFunction;
//# sourceMappingURL=memory-sync.d.ts.map