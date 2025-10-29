import 'dotenv/config';
export declare const generateRecipeFromIngredients: import("firebase-functions/v2/https").HttpsFunction;
export declare const generateSpontaneousRecipe: import("firebase-functions/v2/https").HttpsFunction;
export declare const generateRecipePhoto: import("firebase-functions/v2/https").HttpsFunction;
export declare const extractNutritionFromImage: import("firebase-functions/v2/https").HttpsFunction;
export declare const transcribeMeal: import("firebase-functions/v2/https").HttpsFunction;
export { diabetesAssistantStream } from './diabetes-assistant-stream';
export { generateSessionMetadata } from './generate-session-metadata';
export { syncUserFacts, syncConversationSummaries, syncRecipePreferences, syncGlucosePatterns, syncUserPreferences } from './memory-sync';
export { testEdamamNutrition } from './test-edamam-nutrition';
export declare const recallFromPastSessions: import("firebase-functions/v2/https").HttpsFunction;
export declare const calculateRecipeNutrition: import("firebase-functions/v2/https").HttpsFunction;
//# sourceMappingURL=index.d.ts.map