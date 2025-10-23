/**
 * Recall Flow - Answers user queries from past research sessions
 *
 * When router detects recall intent (tier: 0), this flow:
 * 1. Receives matched sessions from iOS FTS search
 * 2. Ranks sessions by relevance
 * 3. Uses LLM to answer from past conversation context
 * 4. Returns direct answer with session reference
 */
export interface RecallInput {
    question: string;
    userId: string;
    matchedSessions: MatchedSession[];
}
export interface MatchedSession {
    sessionId: string;
    title?: string;
    summary?: string;
    keyTopics: string[];
    createdAt: string;
    conversationHistory: Array<{
        role: string;
        content: string;
    }>;
    relevanceScore: number;
}
export interface RecallOutput {
    success: boolean;
    answer?: string;
    sessionReference?: {
        sessionId: string;
        title: string;
        date: string;
    };
    multipleMatches?: {
        sessions: Array<{
            sessionId: string;
            title: string;
            date: string;
            summary: string;
        }>;
        message: string;
    };
    noMatch?: {
        message: string;
        suggestNewResearch: boolean;
    };
}
/**
 * Handles recall requests - answers from past research sessions
 */
export declare function handleRecall(input: RecallInput): Promise<RecallOutput>;
//# sourceMappingURL=recall-flow.d.ts.map