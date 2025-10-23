/**
 * Comprehensive Conversation State Types
 *
 * Supports ALL 20 categories of Turkish linguistic references
 * for accurate discourse tracking in medical conversations.
 */
/**
 * Entity mention with turn tracking
 */
export interface EntityMention {
    name: string;
    mentionedTurn: number;
    mentionedBy: 'user' | 'assistant';
    salience: number;
}
/**
 * Measurement with context
 */
export interface MeasurementEntry {
    type: string;
    value: number;
    unit: string;
    timestamp: string;
    turn: number;
}
/**
 * LAYER 1: Entity Tracking
 * Tracks concrete entities mentioned in conversation
 */
export interface EntityLayer {
    medications: EntityMention[];
    foods: EntityMention[];
    measurements: MeasurementEntry[];
    symptoms: EntityMention[];
    exercises: EntityMention[];
    medicalTerms: EntityMention[];
}
/**
 * Last question asked with full context
 */
export interface LastQuestionContext {
    type: 'what' | 'how' | 'why' | 'when' | 'where' | 'which' | 'how_much' | 'how_many' | 'is_it';
    subject: string;
    verb: string;
    fullQuestion: string;
    turn: number;
}
/**
 * Last statement with attribution
 */
export interface LastStatementContext {
    claim: string;
    by: 'user' | 'assistant';
    turn: number;
}
/**
 * LAYER 2: Discourse State
 * Tracks conversation flow, topics, and Q&A patterns
 */
export interface DiscourseLayer {
    currentTopic: string;
    previousTopic: string | null;
    lastQuestion: LastQuestionContext | null;
    lastStatement: LastStatementContext | null;
    openQuestions: Array<{
        question: string;
        turn: number;
    }>;
}
/**
 * List presented by AI
 */
export interface ListPresented {
    items: string[];
    context: string;
    turn: number;
}
/**
 * Procedure explained by AI
 */
export interface ProcedureExplained {
    steps: string[];
    procedureName: string;
    turn: number;
}
/**
 * Recommendation made by AI
 */
export interface Recommendation {
    what: string;
    reason: string;
    turn: number;
}
/**
 * Example given by AI
 */
export interface ExampleGiven {
    example: string;
    illustrating: string;
    turn: number;
}
/**
 * LAYER 3: AI Output Tracking
 * Tracks what the AI itself has said/recommended/listed
 */
export interface AIOutputLayer {
    listsPresented: ListPresented[];
    proceduresExplained: ProcedureExplained[];
    recommendations: Recommendation[];
    examples: ExampleGiven[];
}
/**
 * LAYER 4: Procedural Context
 * Tracks multi-step processes being discussed
 */
export interface ProceduralLayer {
    currentProcedure: string | null;
    currentStep: number | null;
    totalSteps: number | null;
    stepDetails: Record<number, string>;
}
/**
 * User's stated plan or commitment
 */
export interface UserPlan {
    action: string;
    when: string;
    turn: number;
}
/**
 * Follow-up item for future conversation
 */
export interface FollowUp {
    topic: string;
    when: string;
    turn: number;
}
/**
 * LAYER 5: Commitment Tracking
 * Tracks user plans and follow-up items
 */
export interface CommitmentLayer {
    userPlans: UserPlan[];
    followUps: FollowUp[];
}
/**
 * Complete Conversation State with all layers
 */
export interface ComprehensiveConversationState {
    entities: EntityLayer;
    discourse: DiscourseLayer;
    aiOutputs: AIOutputLayer;
    procedural: ProceduralLayer;
    commitments: CommitmentLayer;
    turnCount: number;
    lastUpdated: Date;
    userId: string;
    messageCount?: number;
}
/**
 * Reference type detected in user message
 * Maps to the 20 linguistic categories
 */
export type ReferenceType = 'ellipsis' | 'definite' | 'comparative' | 'temporal' | 'discourse_marker' | 'ai_output' | 'conditional' | 'quantifier' | 'attribution' | 'negation' | 'evaluation' | 'causality' | 'modal' | 'process' | 'location' | 'confirmation' | 'preference' | 'repetition' | 'agreement' | 'memory_recall' | 'none';
/**
 * Detected reference with resolution context
 */
export interface DetectedReference {
    type: ReferenceType;
    pattern: string;
    requiresLayers: Array<'entities' | 'discourse' | 'aiOutputs' | 'procedural' | 'commitments'>;
    confidence: number;
}
/**
 * Resolved reference with context guidance
 */
export interface ResolvedReference {
    originalPattern: string;
    resolvedTo: string;
    contextGuidance: string;
    sourceLayer: 'entities' | 'discourse' | 'aiOutputs' | 'procedural' | 'commitments' | 'multiple';
}
/**
 * State extraction result
 */
export interface StateExtractionResult {
    state: ComprehensiveConversationState;
    extractionTime: number;
    success: boolean;
    usedFallback: boolean;
}
/**
 * Initialize empty conversation state
 */
export declare function initializeConversationState(userId: string): ComprehensiveConversationState;
//# sourceMappingURL=conversation-state.d.ts.map