/**
 * Context Builder - PHASE 4
 * Builds context using CORRECTED fallback chain for Turkish pronoun resolution
 */
import { ComprehensiveConversationState } from '../types/conversation-state';
/**
 * Build context using corrected fallback chain:
 * Priority 1: Conversation State (structured entities for pronouns)
 * Priority 2: Raw Messages (when state lacks detail)
 * Priority 3: Vector Search (cross-session only, if provided)
 */
export declare function buildContextFromSources(conversationState: ComprehensiveConversationState | null, messageHistory: Array<{
    role: string;
    content: string;
    turnNumber: number;
}>, vectorContext: string | null): string;
//# sourceMappingURL=context-builder.d.ts.map