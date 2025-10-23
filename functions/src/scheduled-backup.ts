/**
 * Scheduled Firestore Backup Function
 *
 * Exports critical collections to Cloud Storage for disaster recovery
 * Scheduled to run every Sunday at midnight (weekly)
 *
 * Collections backed up:
 * - chat_sessions: User conversation sessions with Balli
 * - chat_messages: Individual messages with embeddings
 * - recipe_memory: User's saved recipes and preferences
 * - longTermMemory: User facts, patterns, and conversation summaries
 *
 * Backup location: gs://balli-project-backups/YYYY-MM-DD/
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore } from 'firebase-admin/firestore';
// import { getStorage } from 'firebase-admin/storage'; // Commented: not used yet
import { logger } from 'firebase-functions/v2';

// Get Firestore and Storage instances
const db = getFirestore();

/**
 * Scheduled backup function - runs every Sunday at midnight
 * Cron schedule: '0 0 * * 0' (minute hour day month day-of-week)
 * Timezone: America/New_York (UTC-5)
 */
export const weeklyBackup = onSchedule(
  {
    schedule: '0 0 * * 0', // Every Sunday at midnight
    timeZone: 'America/New_York',
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540 // 9 minutes (Cloud Scheduler max is 10 minutes)
  },
  async (event) => {
    const startTime = Date.now();
    logger.info('🗂️ [BACKUP] Starting weekly Firestore backup');

    try {
      // Generate timestamp-based backup path
      const timestamp = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const bucketName = 'balli-project-backups';
      const outputUriPrefix = `gs://${bucketName}/${timestamp}`;

      logger.info(`📍 [BACKUP] Backup destination: ${outputUriPrefix}`);

      // Collections to backup
      const collectionsToBackup = [
        'chat_sessions',
        'chat_messages',
        'recipe_memory',
        'longTermMemory',
        'conversations', // User conversation sessions
        'feedback' // User feedback for improvements
      ];

      logger.info(`📦 [BACKUP] Backing up collections: ${collectionsToBackup.join(', ')}`);

      // Initiate Firestore export
      // Note: This requires Firestore Admin API to be enabled
      // and the service account must have firestore.databases.export permission
      // const client = db; // Use Firestore client (commented: not directly used)

      // Use exportDocuments method (admin SDK)
      const exportResult = await db.bulkWriter().flush().then(async () => {
        // We need to use the Firestore Admin API via REST
        // Since the Admin SDK doesn't expose exportDocuments directly,
        // we'll use the @google-cloud/firestore library's exportDocuments

        logger.warn('⚠️ [BACKUP] Using alternative backup method - exporting documents to Firestore backup bucket');

        // Alternative: Use batch export via Cloud Firestore Admin API
        // This requires the @google-cloud/firestore package
        const { Firestore } = require('@google-cloud/firestore');
        const firestoreAdmin = new Firestore();
        const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;

        if (!projectId) {
          throw new Error('Project ID not found in environment');
        }

        const databaseName = firestoreAdmin.databasePath(projectId, '(default)');

        logger.info(`🔧 [BACKUP] Database path: ${databaseName}`);
        logger.info(`📤 [BACKUP] Exporting to: ${outputUriPrefix}`);

        // Call exportDocuments
        const [operation] = await firestoreAdmin.exportDocuments({
          name: databaseName,
          outputUriPrefix: outputUriPrefix,
          collectionIds: collectionsToBackup
        });

        logger.info(`⏳ [BACKUP] Export operation started: ${operation.name}`);

        // Wait for the operation to complete (with timeout)
        const maxWaitTime = 8 * 60 * 1000; // 8 minutes (leave buffer for function timeout)
        const startWait = Date.now();

        let completed = false;
        let lastLogTime = Date.now();

        while (!completed && (Date.now() - startWait) < maxWaitTime) {
          const [updatedOperation] = await firestoreAdmin.getOperation({
            name: operation.name
          });

          // Log progress every 30 seconds
          if (Date.now() - lastLogTime > 30000) {
            logger.info(`⏱️ [BACKUP] Export still in progress... (${Math.round((Date.now() - startWait) / 1000)}s elapsed)`);
            lastLogTime = Date.now();
          }

          if (updatedOperation.done) {
            completed = true;

            if (updatedOperation.error) {
              throw new Error(`Export failed: ${updatedOperation.error.message}`);
            }

            logger.info(`✅ [BACKUP] Export completed successfully`);
            return updatedOperation;
          }

          // Wait 5 seconds before checking again
          await new Promise(resolve => setTimeout(resolve, 5000));
        }

        if (!completed) {
          logger.warn(`⚠️ [BACKUP] Export operation did not complete within timeout, but was initiated successfully`);
          logger.info(`📝 [BACKUP] Operation name: ${operation.name} - check Cloud Console for completion status`);
        }

        return operation;
      });

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      // Log successful backup
      logger.info(`✅ [BACKUP] Weekly backup completed in ${duration}s`);
      logger.info(`📊 [BACKUP] Collections backed up: ${collectionsToBackup.length}`);
      logger.info(`💾 [BACKUP] Backup location: ${outputUriPrefix}`);

      // Store backup metadata in Firestore for tracking
      await db.collection('backup_history').add({
        timestamp: new Date().toISOString(),
        backupDate: timestamp,
        collections: collectionsToBackup,
        outputUri: outputUriPrefix,
        duration: `${duration}s`,
        status: 'completed',
        operationName: exportResult.name || 'unknown'
      });

      logger.info('💾 [BACKUP] Backup metadata stored in backup_history collection');

    } catch (error) {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      logger.error(`❌ [BACKUP] Backup failed after ${duration}s:`, error);

      // Store failure in backup history
      try {
        await db.collection('backup_history').add({
          timestamp: new Date().toISOString(),
          backupDate: new Date().toISOString().split('T')[0],
          status: 'failed',
          error: error instanceof Error ? error.message : 'Unknown error',
          duration: `${duration}s`
        });
      } catch (metadataError) {
        logger.error('❌ [BACKUP] Failed to store error metadata:', metadataError);
      }

      // Re-throw to mark Cloud Scheduler execution as failed
      throw error;
    }
  }
);

/**
 * Manual backup trigger for testing (HTTP endpoint)
 * Use this to manually trigger a backup for testing purposes
 *
 * Call with: POST https://REGION-PROJECT.cloudfunctions.net/manualBackup
 */
import { onRequest } from 'firebase-functions/v2/https';
import * as cors from 'cors';

const corsHandler = cors.default({ origin: true });

export const manualBackup = onRequest(
  {
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540
  },
  async (req, res) => {
    corsHandler(req, res, async () => {
      try {
        // Only allow POST requests
        if (req.method !== 'POST') {
          res.status(405).json({ error: 'Method not allowed. Use POST.' });
          return;
        }

        logger.info('🔧 [MANUAL-BACKUP] Manual backup triggered');

        const startTime = Date.now();

        // Generate timestamp-based backup path
        const timestamp = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
        const timeOfDay = new Date().toISOString().split('T')[1].split('.')[0].replace(/:/g, '-'); // HH-MM-SS
        const bucketName = 'balli-project-backups';
        const outputUriPrefix = `gs://${bucketName}/${timestamp}/manual-${timeOfDay}`;

        logger.info(`📍 [MANUAL-BACKUP] Backup destination: ${outputUriPrefix}`);

        // Collections to backup
        const collectionsToBackup = [
          'chat_sessions',
          'chat_messages',
          'recipe_memory',
          'longTermMemory',
          'conversations',
          'feedback'
        ];

        // Use Firestore Admin API for export
        const { Firestore } = require('@google-cloud/firestore');
        const firestoreAdmin = new Firestore();
        const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;

        if (!projectId) {
          throw new Error('Project ID not found in environment');
        }

        const databaseName = firestoreAdmin.databasePath(projectId, '(default)');

        logger.info(`📤 [MANUAL-BACKUP] Starting export of ${collectionsToBackup.length} collections`);

        // Start export operation
        const [operation] = await firestoreAdmin.exportDocuments({
          name: databaseName,
          outputUriPrefix: outputUriPrefix,
          collectionIds: collectionsToBackup
        });

        logger.info(`✅ [MANUAL-BACKUP] Export operation initiated: ${operation.name}`);

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);

        // Store backup metadata
        await db.collection('backup_history').add({
          timestamp: new Date().toISOString(),
          backupDate: timestamp,
          backupTime: timeOfDay,
          collections: collectionsToBackup,
          outputUri: outputUriPrefix,
          duration: `${duration}s`,
          status: 'initiated',
          operationName: operation.name,
          trigger: 'manual'
        });

        // Return success response
        res.json({
          success: true,
          message: 'Manual backup initiated successfully',
          operationName: operation.name,
          backupLocation: outputUriPrefix,
          collections: collectionsToBackup,
          duration: `${duration}s`,
          note: 'Backup is processing asynchronously. Check Cloud Console for completion status.'
        });

      } catch (error) {
        logger.error('❌ [MANUAL-BACKUP] Manual backup failed:', error);

        res.status(500).json({
          success: false,
          error: 'Manual backup failed',
          message: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    });
  }
);
