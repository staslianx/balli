/**
 * Firestore-based Session Storage for Genkit Chat API
 *
 * Implements SessionStore interface for persistent chat sessions with:
 * - Automatic message history management
 * - Message truncation (keep last 10 exchanges = 20 messages)
 * - Metadata tracking (userId, timestamps, message counts)
 * - Session cleanup utilities
 */
import type { SessionData, SessionStore } from 'genkit/beta';
/**
 * Firestore-based session storage for Genkit Chat API
 * Stores conversation history and custom state in chat_sessions collection
 *
 * @template S - Custom state type (default: any)
 */
export declare class FirestoreSessionStore<S = any> implements SessionStore<S> {
    private db;
    private collectionName;
    private readonly MAX_MESSAGES;
    /**
     * Load session data from Firestore
     * @param sessionId - Unique session identifier
     * @returns Session data or undefined if not found
     */
    get(sessionId: string): Promise<SessionData<S> | undefined>;
    /**
     * Save session data to Firestore with message truncation
     * @param sessionId - Unique session identifier
     * @param sessionData - Session data to save (messages + state)
     */
    save(sessionId: string, sessionData: SessionData<S>): Promise<void>;
    /**
     * Remove undefined values from an object recursively
     * Firestore doesn't accept undefined values, they must be null or omitted
     * @param obj - Object to clean
     * @returns Object with undefined values removed
     */
    private removeUndefinedValues;
    /**
     * Delete sessions older than specified days (for scheduled cleanup)
     * @param daysOld - Delete sessions older than this many days
     * @returns Number of sessions deleted
     */
    deleteOldSessions(daysOld?: number): Promise<number>;
    /**
     * Get session statistics for monitoring
     * @param userId - Optional: filter by user ID
     * @returns Session statistics
     */
    getStats(userId?: string): Promise<{
        totalSessions: number;
        totalMessages: number;
        avgMessagesPerSession: number;
    }>;
}
//# sourceMappingURL=session-store.d.ts.map