/**
 * Vector Utilities for Embedding Management
 *
 * Helper functions for:
 * - Generating and storing message embeddings
 * - Batch processing embeddings
 * - Managing embedding lifecycle
 */
/**
 * Message data for storage with embedding
 */
export interface MessageData {
    text: string;
    userId: string;
    isUser: boolean;
    sessionId?: string;
    timestamp: Date;
    embedding?: number[];
}
/**
 * Generate embedding for text using gemini-embedding-001
 *
 * @param text - Text to generate embedding for
 * @returns 768-dimensional embedding vector (configurable via EMBEDDING_DIMENSIONS)
 */
export declare function generateEmbedding(text: string): Promise<number[]>;
/**
 * Store message with embedding in Firestore (for vector search)
 *
 * This should be called asynchronously AFTER the response is sent to the user
 * to avoid blocking the streaming response.
 *
 * @param messageData - Message data to store
 * @returns Document ID of stored message
 */
export declare function storeMessageWithEmbedding(messageData: MessageData): Promise<string>;
/**
 * Store a conversation message pair (user question + AI response) with embeddings
 *
 * This is the main function to call after a conversation exchange completes.
 * It runs asynchronously and doesn't block the response to the user.
 *
 * @param userId - User ID
 * @param sessionId - Session ID for this conversation
 * @param userMessage - User's question
 * @param aiMessage - AI's response
 */
export declare function storeConversationPairWithEmbeddings(userId: string, sessionId: string, userMessage: string, aiMessage: string): Promise<void>;
/**
 * Batch process existing messages to generate embeddings
 * Useful for backfilling embeddings for messages stored before vector search was enabled
 *
 * @param userId - User ID to process (optional, processes all if not specified)
 * @param batchSize - Number of messages to process at once
 * @returns Number of messages processed
 */
export declare function backfillEmbeddings(userId?: string, batchSize?: number): Promise<number>;
/**
 * Delete old chat messages with embeddings (for cleanup)
 *
 * @param userId - User ID to cleanup (required for security)
 * @param daysOld - Delete messages older than this many days
 * @returns Number of messages deleted
 */
export declare function deleteOldChatMessages(userId: string, daysOld?: number): Promise<number>;
/**
 * Get statistics about stored embeddings
 *
 * @param userId - User ID to get stats for (optional)
 * @returns Statistics object
 */
export declare function getEmbeddingStats(userId?: string): Promise<{
    totalMessages: number;
    messagesWithEmbeddings: number;
    messagesMissingEmbeddings: number;
    coveragePercent: number;
}>;
//# sourceMappingURL=vector-utils.d.ts.map