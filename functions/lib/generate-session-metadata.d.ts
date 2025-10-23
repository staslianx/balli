/**
 * Session Metadata Generation - LLM-powered title, summary, and key topics extraction
 *
 * Generates semantic metadata for completed research sessions using Gemini Flash.
 * Single LLM call produces all three fields (more efficient than 3 separate calls).
 *
 * Input: conversationHistory array (last 20 messages)
 * Output: { title, summary, keyTopics }
 */
export declare const generateSessionMetadata: import("firebase-functions/v2/https").HttpsFunction;
//# sourceMappingURL=generate-session-metadata.d.ts.map