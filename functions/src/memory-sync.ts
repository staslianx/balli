/**
 * Memory Sync Cloud Functions
 *
 * HTTP endpoints for syncing iOS SwiftData memory to Firestore
 * Supports:
 * - User Facts (health, preferences, lifestyle)
 * - Conversation Summaries (session summaries)
 * - Recipe Preferences (saved recipes)
 * - Glucose Patterns (meal → glucose response)
 * - User Preferences (key-value settings)
 *
 * Conflict Resolution: Last-write-wins based on timestamps
 * Authentication: Hardcoded userId validation (2-user app)
 */

import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logError, logOperationStart, logOperationSuccess, ErrorType } from './utils/error-logger';
import { retryWithBackoff } from './utils/retry-handler';
import * as cors from 'cors';

const db = getFirestore();

// Configure CORS for iOS app
const corsHandler = cors.default({
  origin: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
});

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Authenticate user (simple validation for 2-user app)
 */
function authenticateUser(userId: string | undefined): boolean {
  if (!userId) return false;
  // For now, just validate that userId exists
  // In production, implement proper Firebase Auth
  return userId === 'current-user' || userId.length > 0;
}

/**
 * Convert embedding from base64 to number array
 */
function decodeEmbedding(embeddingBase64: string | null | undefined): number[] | undefined {
  if (!embeddingBase64) return undefined;

  try {
    const buffer = Buffer.from(embeddingBase64, 'base64');
    const float32Array = new Float32Array(buffer.buffer, buffer.byteOffset, buffer.byteLength / 4);
    return Array.from(float32Array);
  } catch (error) {
    console.warn('⚠️ [SYNC] Failed to decode embedding:', error);
    return undefined;
  }
}

/**
 * Encode embedding number array to base64
 */
function encodeEmbedding(embedding: number[] | null | undefined): string | undefined {
  if (!embedding || embedding.length === 0) return undefined;

  try {
    const float32Array = new Float32Array(embedding);
    const buffer = Buffer.from(float32Array.buffer);
    return buffer.toString('base64');
  } catch (error) {
    console.warn('⚠️ [SYNC] Failed to encode embedding:', error);
    return undefined;
  }
}

/**
 * Convert ISO date string to Firestore Timestamp
 */
function toTimestamp(dateString: string | Date): Timestamp {
  const date = typeof dateString === 'string' ? new Date(dateString) : dateString;
  return Timestamp.fromDate(date);
}

/**
 * Convert Firestore Timestamp to ISO string
 */
function fromTimestamp(timestamp: Timestamp): string {
  return timestamp.toDate().toISOString();
}

/**
 * Batch write documents to Firestore with retry
 */
async function batchWriteDocuments(
  collectionPath: string,
  documents: any[],
  userId: string
): Promise<number> {
  const batch = db.batch();
  let count = 0;

  for (const doc of documents) {
    const docRef = db.collection(collectionPath).doc(doc.id);

    // Convert dates to Timestamps
    const firestoreDoc: any = {
      ...doc,
      lastModifiedAt: Timestamp.now()
    };

    // Only add embedding if it exists
    const embedding = decodeEmbedding(doc.embedding);
    if (embedding) {
      firestoreDoc.embedding = embedding;
    } else {
      delete firestoreDoc.embedding; // Remove undefined embedding field
    }

    // Convert date fields to Timestamps
    if (firestoreDoc.createdAt) {
      firestoreDoc.createdAt = toTimestamp(firestoreDoc.createdAt);
    }
    if (firestoreDoc.lastAccessedAt) {
      firestoreDoc.lastAccessedAt = toTimestamp(firestoreDoc.lastAccessedAt);
    }
    if (firestoreDoc.startTime) {
      firestoreDoc.startTime = toTimestamp(firestoreDoc.startTime);
    }
    if (firestoreDoc.endTime) {
      firestoreDoc.endTime = toTimestamp(firestoreDoc.endTime);
    }
    if (firestoreDoc.savedAt) {
      firestoreDoc.savedAt = toTimestamp(firestoreDoc.savedAt);
    }
    if (firestoreDoc.observedAt) {
      firestoreDoc.observedAt = toTimestamp(firestoreDoc.observedAt);
    }
    if (firestoreDoc.expiresAt) {
      firestoreDoc.expiresAt = toTimestamp(firestoreDoc.expiresAt);
    }
    if (firestoreDoc.updatedAt) {
      firestoreDoc.updatedAt = toTimestamp(firestoreDoc.updatedAt);
    }
    if (firestoreDoc.dateValue) {
      firestoreDoc.dateValue = toTimestamp(firestoreDoc.dateValue);
    }

    batch.set(docRef, firestoreDoc, { merge: true });
    count++;
  }

  await retryWithBackoff(
    () => batch.commit(),
    `Batch write ${documents.length} documents to ${collectionPath}`,
    { maxRetries: 3, baseDelay: 1000 }
  );

  return count;
}

/**
 * Fetch documents from Firestore collection
 */
async function fetchDocuments(
  collectionPath: string,
  userId: string
): Promise<any[]> {
  const snapshot = await retryWithBackoff(
    () => db.collection(collectionPath).get(),
    `Fetch documents from ${collectionPath}`,
    { maxRetries: 3, baseDelay: 500 }
  );

  return snapshot.docs.map(doc => {
    const data = doc.data();

    // Convert Timestamps to ISO strings
    return {
      ...data,
      embedding: encodeEmbedding(data.embedding),
      createdAt: data.createdAt ? fromTimestamp(data.createdAt) : undefined,
      lastAccessedAt: data.lastAccessedAt ? fromTimestamp(data.lastAccessedAt) : undefined,
      startTime: data.startTime ? fromTimestamp(data.startTime) : undefined,
      endTime: data.endTime ? fromTimestamp(data.endTime) : undefined,
      savedAt: data.savedAt ? fromTimestamp(data.savedAt) : undefined,
      observedAt: data.observedAt ? fromTimestamp(data.observedAt) : undefined,
      expiresAt: data.expiresAt ? fromTimestamp(data.expiresAt) : undefined,
      updatedAt: data.updatedAt ? fromTimestamp(data.updatedAt) : undefined,
      dateValue: data.dateValue ? fromTimestamp(data.dateValue) : undefined,
      lastModifiedAt: data.lastModifiedAt ? fromTimestamp(data.lastModifiedAt) : undefined
    };
  });
}

// ============================================
// SYNC ENDPOINTS
// ============================================

/**
 * User Facts Sync Endpoint
 * POST: Upload local facts to Firestore
 * GET: Download facts from Firestore
 */
export const syncUserFacts = onRequest({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
  cors: true
}, async (req, res) => {
  corsHandler(req, res, async () => {
    const startTime = Date.now();

    try {
      const userId = req.body.userId || req.query.userId;

      if (!authenticateUser(userId)) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      logOperationStart('syncUserFacts', { userId, operation: 'syncUserFacts' });

      const collectionPath = `users/${userId}/user_facts`;

      if (req.method === 'POST') {
        // Upload local facts to Firestore
        const facts: any[] = req.body.facts || [];

        if (facts.length === 0) {
          res.json({ success: true, synced: 0, message: 'No facts to sync' });
          return;
        }

        const syncedCount = await batchWriteDocuments(collectionPath, facts, userId);

        logOperationSuccess('syncUserFacts', Date.now() - startTime, {
          userId,
          operation: 'upload',
          additionalData: { count: syncedCount }
        });

        res.json({
          success: true,
          synced: syncedCount,
          timestamp: new Date().toISOString()
        });

      } else if (req.method === 'GET') {
        // Download facts from Firestore
        const facts = await fetchDocuments(collectionPath, userId);

        logOperationSuccess('syncUserFacts', Date.now() - startTime, {
          userId,
          operation: 'download',
          additionalData: { count: facts.length }
        });

        res.json({
          success: true,
          facts,
          count: facts.length,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
      }

    } catch (error) {
      logError(ErrorType.INTERNAL, error, {
        operation: 'syncUserFacts',
        userId: req.body.userId || req.query.userId
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

/**
 * Conversation Summaries Sync Endpoint
 */
export const syncConversationSummaries = onRequest({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
  cors: true
}, async (req, res) => {
  corsHandler(req, res, async () => {
    const startTime = Date.now();

    try {
      const userId = req.body.userId || req.query.userId;

      if (!authenticateUser(userId)) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      logOperationStart('syncConversationSummaries', { userId });

      const collectionPath = `users/${userId}/conversation_summaries`;

      if (req.method === 'POST') {
        const summaries: any[] = req.body.summaries || [];

        if (summaries.length === 0) {
          res.json({ success: true, synced: 0, message: 'No summaries to sync' });
          return;
        }

        const syncedCount = await batchWriteDocuments(collectionPath, summaries, userId);

        logOperationSuccess('syncConversationSummaries', Date.now() - startTime, {
          userId,
          operation: 'upload',
          additionalData: { count: syncedCount }
        });

        res.json({
          success: true,
          synced: syncedCount,
          timestamp: new Date().toISOString()
        });

      } else if (req.method === 'GET') {
        const summaries = await fetchDocuments(collectionPath, userId);

        logOperationSuccess('syncConversationSummaries', Date.now() - startTime, {
          userId,
          operation: 'download',
          additionalData: { count: summaries.length }
        });

        res.json({
          success: true,
          summaries,
          count: summaries.length,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
      }

    } catch (error) {
      logError(ErrorType.INTERNAL, error, {
        operation: 'syncConversationSummaries',
        userId: req.body.userId || req.query.userId
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

/**
 * Recipe Preferences Sync Endpoint
 */
export const syncRecipePreferences = onRequest({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
  cors: true
}, async (req, res) => {
  corsHandler(req, res, async () => {
    const startTime = Date.now();

    try {
      const userId = req.body.userId || req.query.userId;

      if (!authenticateUser(userId)) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      logOperationStart('syncRecipePreferences', { userId });

      const collectionPath = `users/${userId}/recipe_preferences`;

      if (req.method === 'POST') {
        const recipes: any[] = req.body.recipes || [];

        if (recipes.length === 0) {
          res.json({ success: true, synced: 0, message: 'No recipes to sync' });
          return;
        }

        const syncedCount = await batchWriteDocuments(collectionPath, recipes, userId);

        logOperationSuccess('syncRecipePreferences', Date.now() - startTime, {
          userId,
          operation: 'upload',
          additionalData: { count: syncedCount }
        });

        res.json({
          success: true,
          synced: syncedCount,
          timestamp: new Date().toISOString()
        });

      } else if (req.method === 'GET') {
        const recipes = await fetchDocuments(collectionPath, userId);

        logOperationSuccess('syncRecipePreferences', Date.now() - startTime, {
          userId,
          operation: 'download',
          additionalData: { count: recipes.length }
        });

        res.json({
          success: true,
          recipes,
          count: recipes.length,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
      }

    } catch (error) {
      logError(ErrorType.INTERNAL, error, {
        operation: 'syncRecipePreferences',
        userId: req.body.userId || req.query.userId
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

/**
 * Glucose Patterns Sync Endpoint
 */
export const syncGlucosePatterns = onRequest({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
  cors: true
}, async (req, res) => {
  corsHandler(req, res, async () => {
    const startTime = Date.now();

    try {
      const userId = req.body.userId || req.query.userId;

      if (!authenticateUser(userId)) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      logOperationStart('syncGlucosePatterns', { userId });

      const collectionPath = `users/${userId}/glucose_patterns`;

      if (req.method === 'POST') {
        const patterns: any[] = req.body.patterns || [];

        if (patterns.length === 0) {
          res.json({ success: true, synced: 0, message: 'No patterns to sync' });
          return;
        }

        const syncedCount = await batchWriteDocuments(collectionPath, patterns, userId);

        logOperationSuccess('syncGlucosePatterns', Date.now() - startTime, {
          userId,
          operation: 'upload',
          additionalData: { count: syncedCount }
        });

        res.json({
          success: true,
          synced: syncedCount,
          timestamp: new Date().toISOString()
        });

      } else if (req.method === 'GET') {
        const patterns = await fetchDocuments(collectionPath, userId);

        logOperationSuccess('syncGlucosePatterns', Date.now() - startTime, {
          userId,
          operation: 'download',
          additionalData: { count: patterns.length }
        });

        res.json({
          success: true,
          patterns,
          count: patterns.length,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
      }

    } catch (error) {
      logError(ErrorType.INTERNAL, error, {
        operation: 'syncGlucosePatterns',
        userId: req.body.userId || req.query.userId
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

/**
 * User Preferences Sync Endpoint
 */
export const syncUserPreferences = onRequest({
  region: 'us-central1',
  memory: '512MiB',
  timeoutSeconds: 60,
  cors: true
}, async (req, res) => {
  corsHandler(req, res, async () => {
    const startTime = Date.now();

    try {
      const userId = req.body.userId || req.query.userId;

      if (!authenticateUser(userId)) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      logOperationStart('syncUserPreferences', { userId });

      const collectionPath = `users/${userId}/user_preferences`;

      if (req.method === 'POST') {
        const preferences: any[] = req.body.preferences || [];

        if (preferences.length === 0) {
          res.json({ success: true, synced: 0, message: 'No preferences to sync' });
          return;
        }

        const syncedCount = await batchWriteDocuments(collectionPath, preferences, userId);

        logOperationSuccess('syncUserPreferences', Date.now() - startTime, {
          userId,
          operation: 'upload',
          additionalData: { count: syncedCount }
        });

        res.json({
          success: true,
          synced: syncedCount,
          timestamp: new Date().toISOString()
        });

      } else if (req.method === 'GET') {
        const preferences = await fetchDocuments(collectionPath, userId);

        logOperationSuccess('syncUserPreferences', Date.now() - startTime, {
          userId,
          operation: 'download',
          additionalData: { count: preferences.length }
        });

        res.json({
          success: true,
          preferences,
          count: preferences.length,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
      }

    } catch (error) {
      logError(ErrorType.INTERNAL, error, {
        operation: 'syncUserPreferences',
        userId: req.body.userId || req.query.userId
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

/**
 * Unified Sync All Endpoint
 * Syncs all memory types in a single request
 */
export const syncAllMemory = onRequest({
  region: 'us-central1',
  memory: '1GiB',
  timeoutSeconds: 120,
  cors: true
}, async (req, res) => {
  corsHandler(req, res, async () => {
    const startTime = Date.now();

    try {
      const userId = req.body.userId || req.query.userId;

      if (!authenticateUser(userId)) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      logOperationStart('syncAllMemory', { userId });

      if (req.method === 'POST') {
        // Upload phase
        const { facts, summaries, recipes, patterns, preferences } = req.body.upload || {};

        const results = {
          facts: 0,
          summaries: 0,
          recipes: 0,
          patterns: 0,
          preferences: 0
        };

        // Batch write all types
        if (facts && facts.length > 0) {
          results.facts = await batchWriteDocuments(`users/${userId}/user_facts`, facts, userId);
        }
        if (summaries && summaries.length > 0) {
          results.summaries = await batchWriteDocuments(`users/${userId}/conversation_summaries`, summaries, userId);
        }
        if (recipes && recipes.length > 0) {
          results.recipes = await batchWriteDocuments(`users/${userId}/recipe_preferences`, recipes, userId);
        }
        if (patterns && patterns.length > 0) {
          results.patterns = await batchWriteDocuments(`users/${userId}/glucose_patterns`, patterns, userId);
        }
        if (preferences && preferences.length > 0) {
          results.preferences = await batchWriteDocuments(`users/${userId}/user_preferences`, preferences, userId);
        }

        const totalSynced = Object.values(results).reduce((sum, count) => sum + count, 0);

        logOperationSuccess('syncAllMemory', Date.now() - startTime, {
          userId,
          operation: 'upload',
          additionalData: { totalSynced, breakdown: results }
        });

        res.json({
          success: true,
          synced: results,
          totalSynced,
          timestamp: new Date().toISOString()
        });

      } else if (req.method === 'GET') {
        // Download phase - fetch all types in parallel
        const [facts, summaries, recipes, patterns, preferences] = await Promise.all([
          fetchDocuments(`users/${userId}/user_facts`, userId),
          fetchDocuments(`users/${userId}/conversation_summaries`, userId),
          fetchDocuments(`users/${userId}/recipe_preferences`, userId),
          fetchDocuments(`users/${userId}/glucose_patterns`, userId),
          fetchDocuments(`users/${userId}/user_preferences`, userId)
        ]);

        const totalFetched = facts.length + summaries.length + recipes.length + patterns.length + preferences.length;

        logOperationSuccess('syncAllMemory', Date.now() - startTime, {
          userId,
          operation: 'download',
          additionalData: {
            totalFetched,
            breakdown: {
              facts: facts.length,
              summaries: summaries.length,
              recipes: recipes.length,
              patterns: patterns.length,
              preferences: preferences.length
            }
          }
        });

        res.json({
          success: true,
          data: {
            facts,
            summaries,
            recipes,
            patterns,
            preferences
          },
          counts: {
            facts: facts.length,
            summaries: summaries.length,
            recipes: recipes.length,
            patterns: patterns.length,
            preferences: preferences.length,
            total: totalFetched
          },
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
      }

    } catch (error) {
      logError(ErrorType.INTERNAL, error, {
        operation: 'syncAllMemory',
        userId: req.body.userId || req.query.userId
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});
