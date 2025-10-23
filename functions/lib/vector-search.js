"use strict";
/**
 * Firestore Native Vector Search for Semantic Message Retrieval
 *
 * Uses Firestore's built-in KNN (K-Nearest Neighbor) vector search to find
 * semantically similar messages across all user conversations.
 *
 * Requires:
 * - Firestore vector index on 'chat_messages' collection, 'embedding' field
 * - text-embedding-004 embeddings (768 dimensions)
 *
 * Setup index with:
 * ```
 * gcloud firestore indexes composite create \
 *   --collection-group=chat_messages \
 *   --query-scope=COLLECTION \
 *   --field-config=field-path=userId,order=ASCENDING \
 *   --field-config=field-path=embedding,vector-config='{"dimension":"768","flat":"{}"}'
 * ```
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.findSemanticallySimilarMessages = findSemanticallySimilarMessages;
exports.isVectorSearchAvailable = isVectorSearchAvailable;
exports.formatVectorContextForPrompt = formatVectorContextForPrompt;
const firestore_1 = require("firebase-admin/firestore");
/**
 * Find semantically similar messages using Firestore native vector search
 *
 * This uses Firestore's built-in KNN search which is much faster and more
 * scalable than manual cosine similarity calculation in application code.
 *
 * @param options - Vector search configuration
 * @returns Array of similar messages with similarity scores
 */
async function findSemanticallySimilarMessages(options) {
    const { userId, queryEmbedding, limit = 5, distanceMeasure = 'COSINE', minSimilarity = 0.5, throwOnIndexError = false } = options;
    try {
        console.log(`🎯 [VECTOR-SEARCH] Searching for ${limit} similar messages ` +
            `(userId: ${userId}, dimension: ${queryEmbedding.length}, ` +
            `measure: ${distanceMeasure})`);
        const db = (0, firestore_1.getFirestore)();
        const startTime = Date.now();
        // NOTE: Firestore vector search API - this requires the vector index to be built
        // If index doesn't exist, this will throw an error
        const results = await db
            .collection('chat_messages')
            .where('userId', '==', userId)
            .findNearest('embedding', queryEmbedding, {
            limit,
            distanceMeasure
        })
            .get();
        const duration = Date.now() - startTime;
        if (results.empty) {
            console.log(`📭 [VECTOR-SEARCH] No messages found for user ${userId} (${duration}ms)`);
            return [];
        }
        // Process results and calculate normalized similarity scores
        const similarMessages = results.docs.map(doc => {
            const data = doc.data();
            const distance = data._distance || 0;
            // Normalize distance to similarity score (0-1, higher is more similar)
            // For COSINE: distance is 1 - cosine_similarity, so similarity = 1 - distance
            // For EUCLIDEAN: convert to similarity using exponential decay
            let similarity;
            if (distanceMeasure === 'COSINE') {
                similarity = 1 - distance;
            }
            else if (distanceMeasure === 'DOT_PRODUCT') {
                // DOT_PRODUCT distance is negative dot product, convert to similarity
                similarity = Math.max(0, -distance);
            }
            else {
                // EUCLIDEAN: use exponential decay
                similarity = Math.exp(-distance / 2);
            }
            return {
                id: doc.id,
                text: data.text,
                isUser: data.isUser,
                timestamp: data.timestamp,
                distance,
                similarity,
                sessionId: data.sessionId
            };
        });
        // Filter by minimum similarity threshold
        const filteredMessages = similarMessages.filter(m => m.similarity >= minSimilarity);
        // CRITICAL: Sort by SIMILARITY first, then RECENCY as tiebreaker
        // This ensures semantic relevance is prioritized, but within similar results,
        // we show the most recent conversation
        filteredMessages.sort((a, b) => {
            // Primary sort: similarity (higher is better)
            const similarityDiff = b.similarity - a.similarity;
            // If similarity is very close (within 0.05), use recency as tiebreaker
            if (Math.abs(similarityDiff) < 0.05) {
                // Secondary sort: timestamp (more recent is better)
                const aTime = new Date(a.timestamp).getTime();
                const bTime = new Date(b.timestamp).getTime();
                return bTime - aTime;
            }
            return similarityDiff;
        });
        console.log(`✅ [VECTOR-SEARCH] Found ${filteredMessages.length}/${results.size} messages ` +
            `above threshold ${minSimilarity} (${duration}ms), sorted by similarity→recency`);
        if (filteredMessages.length > 0) {
            console.log(`📊 [VECTOR-SEARCH] Top result: similarity=${filteredMessages[0].similarity.toFixed(3)}, ` +
                `text="${filteredMessages[0].text.substring(0, 60)}..."`);
        }
        return filteredMessages;
    }
    catch (error) {
        // Handle specific error for missing vector index
        if (error.message?.includes('index') || error.code === 9) {
            console.error(`❌ [VECTOR-SEARCH] Vector index not found! ` +
                `Please create Firestore vector index on chat_messages.embedding field. ` +
                `See setup instructions in vector-search.ts header.`);
            if (throwOnIndexError) {
                // Throw error for availability checking
                throw new Error('Vector index not available');
            }
            // Graceful fallback for production use
            console.error(`❌ [VECTOR-SEARCH] Falling back to empty results.`);
            return [];
        }
        console.error(`❌ [VECTOR-SEARCH] Error during vector search for user ${userId}:`, error);
        throw error;
    }
}
/**
 * Check if vector search is available (index exists and ready)
 *
 * @param userId - User ID to test with
 * @returns true if vector search is available, false otherwise
 */
async function isVectorSearchAvailable(userId) {
    try {
        // Try a minimal vector search to test if index exists
        // Use throwOnIndexError=true to detect index availability
        const testVector = new Array(768).fill(0);
        await findSemanticallySimilarMessages({
            userId,
            queryEmbedding: testVector,
            limit: 1,
            throwOnIndexError: true
        });
        return true;
    }
    catch (error) {
        console.warn('⚠️ [VECTOR-SEARCH] Vector search not available:', error);
        return false;
    }
}
/**
 * Format vector search results as context text for LLM prompt
 *
 * @param results - Vector search results
 * @param maxLength - Maximum length per message (characters)
 * @returns Formatted context string
 */
function formatVectorContextForPrompt(results, maxLength = 150) {
    if (results.length === 0) {
        return '';
    }
    const contextLines = results.map((result, index) => {
        const truncatedText = result.text.length > maxLength
            ? result.text.substring(0, maxLength) + '...'
            : result.text;
        const speaker = result.isUser ? 'Kullanıcı' : 'Asistan';
        const similarityPercent = (result.similarity * 100).toFixed(0);
        return `${index + 1}. [${speaker}, ${similarityPercent}% benzerlik] ${truncatedText}`;
    });
    return `İlgili geçmiş konuşmalar:\n${contextLines.join('\n')}`;
}
//# sourceMappingURL=vector-search.js.map