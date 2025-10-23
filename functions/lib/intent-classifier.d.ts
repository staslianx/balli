/**
 * Intent Classification System for Diabetes Assistant
 *
 * Classifies user messages to determine what type of context is needed:
 * - immediate: Last few messages in current conversation
 * - session: Current session context
 * - historical: Previous sessions and long-term memory
 * - vectorSearch: Semantic similarity search across all messages
 *
 * This optimization reduces costs by only retrieving relevant context.
 */
/**
 * Message intent classification result
 */
export interface MessageIntent {
    category: 'greeting' | 'health_query' | 'memory_recall' | 'follow_up' | 'general';
    confidence: number;
    keywords: string[];
    contextNeeded: {
        immediate: boolean;
        session: boolean;
        historical: boolean;
        vectorSearch: boolean;
    };
    reasoning: string;
}
/**
 * Classify user message to determine intent and required context
 * Uses Gemini Flash Lite for fast, cost-effective classification
 *
 * @param message - User's message to classify
 * @returns MessageIntent with category and context requirements
 */
export declare function classifyMessageIntent(message: string): Promise<MessageIntent>;
//# sourceMappingURL=intent-classifier.d.ts.map