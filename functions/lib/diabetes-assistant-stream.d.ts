/**
 * Diabetes Assistant - Streaming Version with SSE (Stateless)
 *
 * Provides token-by-token streaming for real-time user feedback
 * Uses Server-Sent Events (SSE) for progressive response delivery
 *
 * STATELESS DESIGN:
 * - Each request is completely independent
 * - No conversation history or session tracking
 * - No vector search or embeddings
 * - Pure request-response model
 */
/**
 * Main streaming endpoint
 */
export declare const diabetesAssistantStream: import("firebase-functions/v2/https").HttpsFunction;
//# sourceMappingURL=diabetes-assistant-stream.d.ts.map