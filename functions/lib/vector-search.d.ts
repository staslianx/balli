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
/**
 * Vector search configuration options
 */
export interface VectorSearchOptions {
    /** User ID to filter results (security/privacy) */
    userId: string;
    /** Query embedding vector (768 dimensions for text-embedding-004) */
    queryEmbedding: number[];
    /** Maximum number of results to return */
    limit?: number;
    /** Distance measure for similarity calculation */
    distanceMeasure?: 'COSINE' | 'EUCLIDEAN' | 'DOT_PRODUCT';
    /** Minimum similarity threshold (0-1 for COSINE, lower is more similar) */
    minSimilarity?: number;
    /** If true, throw error when index not available instead of returning [] */
    throwOnIndexError?: boolean;
}
/**
 * Vector search result with similarity score
 */
export interface VectorSearchResult {
    /** Message ID in Firestore */
    id: string;
    /** Message text content */
    text: string;
    /** Whether message is from user (true) or assistant (false) */
    isUser: boolean;
    /** Message timestamp */
    timestamp: string;
    /** Distance score (lower = more similar for COSINE) */
    distance: number;
    /** Normalized similarity score (0-1, higher = more similar) */
    similarity: number;
    /** Session ID this message belongs to */
    sessionId?: string;
}
/**
 * Find semantically similar messages using Firestore native vector search
 *
 * This uses Firestore's built-in KNN search which is much faster and more
 * scalable than manual cosine similarity calculation in application code.
 *
 * @param options - Vector search configuration
 * @returns Array of similar messages with similarity scores
 */
export declare function findSemanticallySimilarMessages(options: VectorSearchOptions): Promise<VectorSearchResult[]>;
/**
 * Check if vector search is available (index exists and ready)
 *
 * @param userId - User ID to test with
 * @returns true if vector search is available, false otherwise
 */
export declare function isVectorSearchAvailable(userId: string): Promise<boolean>;
/**
 * Format vector search results as context text for LLM prompt
 *
 * @param results - Vector search results
 * @param maxLength - Maximum length per message (characters)
 * @returns Formatted context string
 */
export declare function formatVectorContextForPrompt(results: VectorSearchResult[], maxLength?: number): string;
//# sourceMappingURL=vector-search.d.ts.map