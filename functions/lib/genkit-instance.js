"use strict";
/**
 * Genkit Instance - Shared AI instance
 * Separated to avoid circular imports during Firebase deployment
 *
 * NOTE: Using genkit/beta for Chat Session API support
 * The beta package includes all stable APIs plus chat sessions
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.db = exports.ai = void 0;
// Load environment variables from .env file
// Firebase Functions don't auto-load .env, so we need dotenv package
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const beta_1 = require("genkit/beta");
const providers_1 = require("./providers");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
// Verify critical environment variables are loaded
console.log('🔧 [ENV] Loading environment configuration...');
console.log(`🔧 [ENV] USE_VERTEX_AI: ${process.env.USE_VERTEX_AI}`);
console.log(`🔧 [ENV] EMBEDDING_DIMENSIONS: ${process.env.EMBEDDING_DIMENSIONS || '768 (default)'}`);
console.log(`🔧 [ENV] GOOGLE_CLOUD_PROJECT_ID: ${process.env.GOOGLE_CLOUD_PROJECT_ID || 'balli-project (default)'}`);
// Initialize Firebase Admin first (guard against duplicate initialization)
if (!admin.apps.length) {
    (0, app_1.initializeApp)();
    console.log('🔥 [FIREBASE] Admin SDK initialized in genkit-instance');
}
// Export ai instance for use across all flows and endpoints
// Chat API (sessions, multi-turn) available through beta import
exports.ai = (0, beta_1.genkit)({
    plugins: [(0, providers_1.getProviderConfig)()],
    promptDir: './prompts' // Works in both dev (src/genkit-instance.ts) and prod (lib/genkit-instance.js with lib/prompts/)
});
// Export Firestore instance for database operations (safe now after initialization)
exports.db = (0, firestore_1.getFirestore)();
//# sourceMappingURL=genkit-instance.js.map