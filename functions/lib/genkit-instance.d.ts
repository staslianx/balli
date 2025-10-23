/**
 * Genkit Instance - Shared AI instance
 * Separated to avoid circular imports during Firebase deployment
 *
 * NOTE: Using genkit/beta for Chat Session API support
 * The beta package includes all stable APIs plus chat sessions
 */
import * as admin from 'firebase-admin';
export declare const ai: import("genkit/beta").GenkitBeta;
export declare const db: admin.firestore.Firestore;
//# sourceMappingURL=genkit-instance.d.ts.map