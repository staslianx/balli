/**
 * Conversation State Extractor
 *
 * Extracts comprehensive conversation state from user-AI exchanges
 * using AI-powered analysis with heuristic fallback.
 */
import { ComprehensiveConversationState, StateExtractionResult } from './types/conversation-state';
/**
 * Extract conversation state using AI - PHASE 2: INCREMENTAL
 * Only processes NEW messages since last extraction for 10x speed improvement
 */
export declare function extractConversationState(messageHistory: Array<{
    role: string;
    content: string;
    turnNumber: number;
}>, previousState: ComprehensiveConversationState | null): Promise<StateExtractionResult>;
//# sourceMappingURL=conversation-state-extractor.d.ts.map