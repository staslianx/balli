/**
 * Genkit Instance - Shared AI instance
 * Separated to avoid circular imports during Firebase deployment
 *
 * NOTE: Using genkit/beta for Chat Session API support
 * The beta package includes all stable APIs plus chat sessions
 */

// Load environment variables from .env file
// Firebase Functions don't auto-load .env, so we need dotenv package
import * as dotenv from 'dotenv';
dotenv.config();

import { genkit } from 'genkit/beta';
import { getProviderConfig } from './providers';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';

// Verify critical environment variables are loaded
console.log('🔧 [ENV] Loading environment configuration...');
console.log(`🔧 [ENV] USE_VERTEX_AI: ${process.env.USE_VERTEX_AI}`);
console.log(`🔧 [ENV] EMBEDDING_DIMENSIONS: ${process.env.EMBEDDING_DIMENSIONS || '768 (default)'}`);
console.log(`🔧 [ENV] GOOGLE_CLOUD_PROJECT_ID: ${process.env.GOOGLE_CLOUD_PROJECT_ID || 'balli-project (default)'}`);

// Initialize Firebase Admin first (guard against duplicate initialization)
if (!admin.apps.length) {
  initializeApp();
  console.log('🔥 [FIREBASE] Admin SDK initialized in genkit-instance');
}

// Export ai instance for use across all flows and endpoints
// Chat API (sessions, multi-turn) available through beta import
export const ai = genkit({
  plugins: [getProviderConfig()],
  promptDir: './prompts'
});

// Export Firestore instance for database operations (safe now after initialization)
export const db = getFirestore();
