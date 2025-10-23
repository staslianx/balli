"use strict";
/**
 * Comprehensive Conversation State Types
 *
 * Supports ALL 20 categories of Turkish linguistic references
 * for accurate discourse tracking in medical conversations.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeConversationState = initializeConversationState;
/**
 * Initialize empty conversation state
 */
function initializeConversationState(userId) {
    return {
        entities: {
            medications: [],
            foods: [],
            measurements: [],
            symptoms: [],
            exercises: [],
            medicalTerms: []
        },
        discourse: {
            currentTopic: '',
            previousTopic: null,
            lastQuestion: null,
            lastStatement: null,
            openQuestions: []
        },
        aiOutputs: {
            listsPresented: [],
            proceduresExplained: [],
            recommendations: [],
            examples: []
        },
        procedural: {
            currentProcedure: null,
            currentStep: null,
            totalSteps: null,
            stepDetails: {}
        },
        commitments: {
            userPlans: [],
            followUps: []
        },
        turnCount: 0,
        lastUpdated: new Date(),
        userId
    };
}
//# sourceMappingURL=conversation-state.js.map