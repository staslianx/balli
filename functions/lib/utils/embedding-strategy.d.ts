/**
 * Smart Embedding Strategy - PHASE 3
 * Reduces embedding calls by 80-85% while maintaining cross-session memory
 */
export interface EmbeddingDecision {
    shouldGenerate: boolean;
    reason: string;
}
/**
 * Decide if embedding should be generated for this message
 * Goal: Skip intra-session references, generate only for cross-session memory
 */
export declare function shouldGenerateEmbedding(message: string, messageCount: number): EmbeddingDecision;
/**
 * Log embedding decision for monitoring
 */
export declare function logEmbeddingDecision(decision: EmbeddingDecision, message: string): void;
//# sourceMappingURL=embedding-strategy.d.ts.map