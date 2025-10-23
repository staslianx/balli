"use strict";
/**
 * Firestore-based Session Storage for Genkit Chat API
 *
 * Implements SessionStore interface for persistent chat sessions with:
 * - Automatic message history management
 * - Message truncation (keep last 10 exchanges = 20 messages)
 * - Metadata tracking (userId, timestamps, message counts)
 * - Session cleanup utilities
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.FirestoreSessionStore = void 0;
const firestore_1 = require("firebase-admin/firestore");
/**
 * Firestore-based session storage for Genkit Chat API
 * Stores conversation history and custom state in chat_sessions collection
 *
 * @template S - Custom state type (default: any)
 */
class FirestoreSessionStore {
    db = (0, firestore_1.getFirestore)();
    collectionName = 'chat_sessions';
    MAX_MESSAGES = 20; // Keep last 10 exchanges (20 messages)
    /**
     * Load session data from Firestore
     * @param sessionId - Unique session identifier
     * @returns Session data or undefined if not found
     */
    async get(sessionId) {
        try {
            const docRef = this.db.collection(this.collectionName).doc(sessionId);
            const doc = await docRef.get();
            if (!doc.exists) {
                console.log(`📭 [SESSION] No session found: ${sessionId}`);
                return undefined;
            }
            const data = doc.data(); // Firestore raw data
            console.log(`✅ [SESSION] Loaded session: ${sessionId}, ` +
                `messages: ${data.messages?.length || 0}, ` +
                `state keys: ${data.state ? Object.keys(data.state).length : 0}`);
            // Return properly typed SessionData
            // Cast through unknown to avoid type mismatch (SessionData structure from Genkit)
            return {
                messages: data.messages || [],
                state: data.state
            };
        }
        catch (error) {
            console.error(`❌ [SESSION] Error loading session ${sessionId}:`, error);
            // Return undefined to trigger new session creation
            return undefined;
        }
    }
    /**
     * Save session data to Firestore with message truncation
     * @param sessionId - Unique session identifier
     * @param sessionData - Session data to save (messages + state)
     */
    async save(sessionId, sessionData) {
        try {
            const docRef = this.db.collection(this.collectionName).doc(sessionId);
            // Truncate messages to last N to control context size and costs
            const sessionDataAny = sessionData;
            let messagesToSave = sessionDataAny.messages || [];
            if (messagesToSave.length > this.MAX_MESSAGES) {
                messagesToSave = messagesToSave.slice(-this.MAX_MESSAGES);
                console.log(`✂️ [SESSION] Truncated session ${sessionId} to last ${this.MAX_MESSAGES} messages`);
            }
            // Clean state by removing undefined values (Firestore doesn't accept undefined)
            const cleanState = this.removeUndefinedValues(sessionDataAny.state || {});
            // Build document with metadata
            const dataToSave = {
                messages: messagesToSave,
                state: cleanState,
                updatedAt: new Date(),
                messageCount: messagesToSave.length,
                // Preserve userId from state for security rules
                userId: sessionDataAny.state?.userId || null
            };
            await docRef.set(dataToSave, { merge: true });
            console.log(`✅ [SESSION] Saved session: ${sessionId}, ` +
                `messages: ${dataToSave.messageCount}, ` +
                `size: ${JSON.stringify(dataToSave).length} bytes`);
        }
        catch (error) {
            console.error(`❌ [SESSION] Error saving session ${sessionId}:`, error);
            throw error; // Re-throw to let caller handle
        }
    }
    /**
     * Remove undefined values from an object recursively
     * Firestore doesn't accept undefined values, they must be null or omitted
     * @param obj - Object to clean
     * @returns Object with undefined values removed
     */
    removeUndefinedValues(obj) {
        if (obj === null || obj === undefined) {
            return {};
        }
        if (Array.isArray(obj)) {
            return obj.map(item => this.removeUndefinedValues(item));
        }
        if (typeof obj === 'object') {
            const cleaned = {};
            for (const [key, value] of Object.entries(obj)) {
                // Skip undefined values entirely (don't include them)
                if (value !== undefined) {
                    // Recursively clean nested objects
                    cleaned[key] = typeof value === 'object' && value !== null
                        ? this.removeUndefinedValues(value)
                        : value;
                }
            }
            return cleaned;
        }
        return obj;
    }
    /**
     * Delete sessions older than specified days (for scheduled cleanup)
     * @param daysOld - Delete sessions older than this many days
     * @returns Number of sessions deleted
     */
    async deleteOldSessions(daysOld = 30) {
        try {
            const cutoffDate = new Date();
            cutoffDate.setDate(cutoffDate.getDate() - daysOld);
            console.log(`🧹 [SESSION] Cleaning up sessions older than ${daysOld} days (before ${cutoffDate.toISOString()})`);
            const oldSessions = await this.db
                .collection(this.collectionName)
                .where('updatedAt', '<', cutoffDate)
                .get();
            if (oldSessions.empty) {
                console.log('✅ [SESSION] No old sessions to clean up');
                return 0;
            }
            // Batch delete for efficiency (max 500 per batch)
            const batch = this.db.batch();
            oldSessions.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            console.log(`✅ [SESSION] Cleaned up ${oldSessions.size} old sessions`);
            return oldSessions.size;
        }
        catch (error) {
            console.error('❌ [SESSION] Error during cleanup:', error);
            throw error;
        }
    }
    /**
     * Get session statistics for monitoring
     * @param userId - Optional: filter by user ID
     * @returns Session statistics
     */
    async getStats(userId) {
        try {
            let query = this.db.collection(this.collectionName);
            if (userId) {
                query = query.where('userId', '==', userId);
            }
            const snapshot = await query.get();
            let totalMessages = 0;
            snapshot.docs.forEach(doc => {
                const data = doc.data();
                totalMessages += data.messageCount || 0;
            });
            return {
                totalSessions: snapshot.size,
                totalMessages,
                avgMessagesPerSession: snapshot.size > 0 ? totalMessages / snapshot.size : 0
            };
        }
        catch (error) {
            console.error('❌ [SESSION] Error getting stats:', error);
            return {
                totalSessions: 0,
                totalMessages: 0,
                avgMessagesPerSession: 0
            };
        }
    }
}
exports.FirestoreSessionStore = FirestoreSessionStore;
//# sourceMappingURL=session-store.js.map