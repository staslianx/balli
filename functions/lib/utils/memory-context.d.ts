/**
 * Memory Context Helper
 *
 * Retrieves and formats cross-conversation memory for injection into prompts
 * Includes user facts, conversation summaries, and relevant preferences
 */
/**
 * User fact from memory
 */
export interface UserFact {
    fact: string;
    category: string;
    confidence: number;
    createdAt: Date;
    lastAccessedAt: Date;
    source: string;
}
/**
 * Conversation summary from memory
 */
export interface ConversationSummary {
    summary: string;
    startTime: Date;
    endTime: Date;
    messageCount: number;
    tier: string;
}
/**
 * Memory context bundle
 */
export interface MemoryContext {
    userFacts: UserFact[];
    recentSummaries: ConversationSummary[];
    factCount: number;
    summaryCount: number;
}
/**
 * Get complete memory context for a user
 */
export declare function getMemoryContext(userId: string): Promise<MemoryContext>;
/**
 * Format memory context for prompt injection
 * Returns formatted string ready to be added to system prompt or user prompt
 */
export declare function formatMemoryContext(memory: MemoryContext): string;
/**
 * Check if memory context is available for user
 */
export declare function hasMemoryContext(userId: string): Promise<boolean>;
//# sourceMappingURL=memory-context.d.ts.map