/**
 * Reference Resolver
 *
 * Resolves detected references to specific entities/concepts
 * using conversation state and builds explicit guidance for AI.
 */
import { ComprehensiveConversationState, DetectedReference, ResolvedReference } from './types/conversation-state';
/**
 * Resolve all detected references using conversation state
 */
export declare function resolveReferences(message: string, references: DetectedReference[], state: ComprehensiveConversationState): ResolvedReference[];
/**
 * Build comprehensive context guidance from all resolved references
 */
export declare function buildContextGuidance(resolved: ResolvedReference[]): string;
//# sourceMappingURL=reference-resolver.d.ts.map