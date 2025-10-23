"use strict";
/**
 * Vector Utilities for Embedding Management
 *
 * Helper functions for:
 * - Generating and storing message embeddings
 * - Batch processing embeddings
 * - Managing embedding lifecycle
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateEmbedding = generateEmbedding;
exports.storeMessageWithEmbedding = storeMessageWithEmbedding;
exports.storeConversationPairWithEmbeddings = storeConversationPairWithEmbeddings;
exports.backfillEmbeddings = backfillEmbeddings;
exports.deleteOldChatMessages = deleteOldChatMessages;
exports.getEmbeddingStats = getEmbeddingStats;
const firestore_1 = require("firebase-admin/firestore");
const genkit_instance_1 = require("./genkit-instance");
const providers_1 = require("./providers");
/**
 * Generate embedding for text using gemini-embedding-001
 *
 * @param text - Text to generate embedding for
 * @returns 768-dimensional embedding vector (configurable via EMBEDDING_DIMENSIONS)
 */
async function generateEmbedding(text) {
    try {
        console.log(`🔮 [EMBEDDING] Using gemini-embedding-001 @ ${process.env.EMBEDDING_DIMENSIONS || 768}D`);
        const response = await genkit_instance_1.ai.embed({
            embedder: (0, providers_1.getEmbedder)(),
            content: text
        });
        // Extract the actual embedding vector from the response
        const embeddingVector = Array.isArray(response) ? response[0]?.embedding : response;
        const embedding = Array.isArray(embeddingVector) ? embeddingVector : [];
        if (embedding.length === 0) {
            throw new Error('Empty embedding generated');
        }
        return embedding;
    }
    catch (error) {
        console.error('❌ [EMBEDDING] Generation failed:', error);
        throw error;
    }
}
/**
 * Store message with embedding in Firestore (for vector search)
 *
 * This should be called asynchronously AFTER the response is sent to the user
 * to avoid blocking the streaming response.
 *
 * @param messageData - Message data to store
 * @returns Document ID of stored message
 */
async function storeMessageWithEmbedding(messageData) {
    try {
        const db = (0, firestore_1.getFirestore)();
        const startTime = Date.now();
        // Generate embedding if not provided
        let embedding = messageData.embedding;
        if (!embedding) {
            console.log(`🔮 [EMBEDDING] Generating for: "${messageData.text.substring(0, 50)}..."`);
            embedding = await generateEmbedding(messageData.text);
        }
        // Store message with embedding
        const docRef = await db.collection('chat_messages').add({
            text: messageData.text,
            userId: messageData.userId,
            isUser: messageData.isUser,
            sessionId: messageData.sessionId || null,
            timestamp: messageData.timestamp,
            embedding: embedding,
            embeddingDimensions: embedding.length,
            createdAt: new Date()
        });
        const duration = Date.now() - startTime;
        console.log(`✅ [EMBEDDING] Stored message ${docRef.id} with ${embedding.length}D embedding (${duration}ms)`);
        return docRef.id;
    }
    catch (error) {
        console.error('❌ [EMBEDDING] Failed to store message with embedding:', error);
        throw error;
    }
}
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
async function storeConversationPairWithEmbeddings(userId, sessionId, userMessage, aiMessage) {
    try {
        console.log(`💾 [EMBEDDING-PAIR] Storing conversation pair for session ${sessionId}`);
        const timestamp = new Date();
        // Store both messages in parallel for efficiency
        await Promise.all([
            storeMessageWithEmbedding({
                text: userMessage,
                userId,
                isUser: true,
                sessionId,
                timestamp
            }),
            storeMessageWithEmbedding({
                text: aiMessage,
                userId,
                isUser: false,
                sessionId,
                timestamp
            })
        ]);
        console.log(`✅ [EMBEDDING-PAIR] Successfully stored pair for session ${sessionId}`);
    }
    catch (error) {
        // Don't throw - this runs async and shouldn't fail the user's request
        console.error(`⚠️ [EMBEDDING-PAIR] Failed to store pair (session ${sessionId}):`, error);
    }
}
/**
 * Batch process existing messages to generate embeddings
 * Useful for backfilling embeddings for messages stored before vector search was enabled
 *
 * @param userId - User ID to process (optional, processes all if not specified)
 * @param batchSize - Number of messages to process at once
 * @returns Number of messages processed
 */
async function backfillEmbeddings(userId, batchSize = 100) {
    try {
        const db = (0, firestore_1.getFirestore)();
        console.log(`🔄 [BACKFILL] Starting embedding backfill (batchSize: ${batchSize})`);
        // Find messages without embeddings
        let query = db
            .collection('chat_messages')
            .where('embedding', '==', null)
            .limit(batchSize);
        if (userId) {
            query = query.where('userId', '==', userId);
        }
        const snapshot = await query.get();
        if (snapshot.empty) {
            console.log('✅ [BACKFILL] No messages need embeddings');
            return 0;
        }
        console.log(`📊 [BACKFILL] Processing ${snapshot.size} messages...`);
        // Process in parallel with concurrency limit
        const CONCURRENT_LIMIT = 10;
        let processed = 0;
        for (let i = 0; i < snapshot.docs.length; i += CONCURRENT_LIMIT) {
            const batch = snapshot.docs.slice(i, i + CONCURRENT_LIMIT);
            await Promise.all(batch.map(async (doc) => {
                try {
                    const data = doc.data();
                    const embedding = await generateEmbedding(data.text);
                    await doc.ref.update({
                        embedding,
                        embeddingDimensions: embedding.length,
                        backfilledAt: new Date()
                    });
                    processed++;
                }
                catch (error) {
                    console.error(`⚠️ [BACKFILL] Failed to process message ${doc.id}:`, error);
                }
            }));
            console.log(`📈 [BACKFILL] Progress: ${processed}/${snapshot.size}`);
        }
        console.log(`✅ [BACKFILL] Completed: ${processed} messages processed`);
        return processed;
    }
    catch (error) {
        console.error('❌ [BACKFILL] Backfill failed:', error);
        throw error;
    }
}
/**
 * Delete old chat messages with embeddings (for cleanup)
 *
 * @param userId - User ID to cleanup (required for security)
 * @param daysOld - Delete messages older than this many days
 * @returns Number of messages deleted
 */
async function deleteOldChatMessages(userId, daysOld = 90) {
    try {
        const db = (0, firestore_1.getFirestore)();
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - daysOld);
        console.log(`🧹 [CLEANUP] Deleting chat messages older than ${daysOld} days ` +
            `for user ${userId} (before ${cutoffDate.toISOString()})`);
        const oldMessages = await db
            .collection('chat_messages')
            .where('userId', '==', userId)
            .where('timestamp', '<', cutoffDate)
            .get();
        if (oldMessages.empty) {
            console.log('✅ [CLEANUP] No old messages to delete');
            return 0;
        }
        // Batch delete (max 500 per batch)
        const batch = db.batch();
        oldMessages.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`✅ [CLEANUP] Deleted ${oldMessages.size} old messages for user ${userId}`);
        return oldMessages.size;
    }
    catch (error) {
        console.error('❌ [CLEANUP] Cleanup failed:', error);
        throw error;
    }
}
/**
 * Get statistics about stored embeddings
 *
 * @param userId - User ID to get stats for (optional)
 * @returns Statistics object
 */
async function getEmbeddingStats(userId) {
    try {
        const db = (0, firestore_1.getFirestore)();
        let totalQuery = db.collection('chat_messages');
        let withEmbeddingsQuery = db.collection('chat_messages').where('embedding', '!=', null);
        if (userId) {
            totalQuery = totalQuery.where('userId', '==', userId);
            withEmbeddingsQuery = withEmbeddingsQuery.where('userId', '==', userId);
        }
        const [totalSnapshot, withEmbeddingsSnapshot] = await Promise.all([
            totalQuery.count().get(),
            withEmbeddingsQuery.count().get()
        ]);
        const total = totalSnapshot.data().count;
        const withEmbeddings = withEmbeddingsSnapshot.data().count;
        const missing = total - withEmbeddings;
        const coverage = total > 0 ? (withEmbeddings / total) * 100 : 0;
        return {
            totalMessages: total,
            messagesWithEmbeddings: withEmbeddings,
            messagesMissingEmbeddings: missing,
            coveragePercent: coverage
        };
    }
    catch (error) {
        console.error('❌ [STATS] Failed to get embedding stats:', error);
        return {
            totalMessages: 0,
            messagesWithEmbeddings: 0,
            messagesMissingEmbeddings: 0,
            coveragePercent: 0
        };
    }
}
//# sourceMappingURL=vector-utils.js.map