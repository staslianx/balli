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
/**
 * Scheduled backup function - runs every Sunday at midnight
 * Cron schedule: '0 0 * * 0' (minute hour day month day-of-week)
 * Timezone: America/New_York (UTC-5)
 */
export declare const weeklyBackup: import("firebase-functions/v2/scheduler").ScheduleFunction;
export declare const manualBackup: import("firebase-functions/v2/https").HttpsFunction;
//# sourceMappingURL=scheduled-backup.d.ts.map