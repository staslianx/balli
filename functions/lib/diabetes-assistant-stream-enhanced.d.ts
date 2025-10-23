/**
 * Enhanced Tier 1 Streaming with Comprehensive Reference Resolution
 *
 * This is the enhanced version of streamTier1 that integrates:
 * - Reference detection (20 linguistic categories)
 * - Conversation state extraction (multi-layer)
 * - Reference resolution with explicit guidance
 *
 * TO INTEGRATE: Replace streamTier1 function in diabetes-assistant-stream.ts
 */
import { Response } from 'express';
/**
 * Stream Tier 1 response with COMPREHENSIVE reference resolution
 */
export declare function streamTier1Enhanced(res: Response, question: string, userId: string, sessionId: string | undefined, writeSSE: (res: Response, event: any) => boolean, diabetesProfile?: any): Promise<{
    sessionId: string;
}>;
/**
 * Usage Notes:
 *
 * To integrate into diabetes-assistant-stream.ts:
 *
 * 1. Import the new modules at the top:
 *    import { detectReferences, getPrimaryReference } from './reference-detector';
 *    import { resolveReferences, buildContextGuidance } from './reference-resolver';
 *    import { extractConversationState } from './conversation-state-extractor';
 *    import { ComprehensiveConversationState, initializeConversationState } from './types/conversation-state';
 *
 * 2. Update ChatState interface to EnhancedChatState
 *
 * 3. Replace the streamTier1 function body with the logic from streamTier1Enhanced
 *
 * 4. Repeat for streamProResearch function
 *
 * 5. Build and test:
 *    cd functions
 *    npm run build
 *    npm test
 */
//# sourceMappingURL=diabetes-assistant-stream-enhanced.d.ts.map