/**
 * Rate Limiting for Tier 3 Medical Research Queries
 *
 * Implements Firestore-based daily query limits per user
 * Limit: 10 Tier 3 queries per user per day
 */
export interface RateLimitResult {
    allowed: boolean;
    remaining: number;
    resetAt: Date;
    reason?: string;
}
export interface UsageRecord {
    userId: string;
    tier3Count: number;
    date: string;
    lastQueryAt: Date;
    queries: Array<{
        timestamp: Date;
        question: string;
    }>;
}
/**
 * Check if user can make a Tier 3 query
 */
export declare function checkTier3RateLimit(userId: string): Promise<RateLimitResult>;
/**
 * Record a Tier 3 query usage
 */
export declare function recordTier3Usage(userId: string, question: string): Promise<void>;
/**
 * Get user's current usage stats
 */
export declare function getTier3Usage(userId: string): Promise<{
    count: number;
    limit: number;
    remaining: number;
    resetAt: Date;
}>;
/**
 * Admin function: Reset user's daily limit (for testing or support)
 */
export declare function resetUserLimit(userId: string): Promise<void>;
//# sourceMappingURL=rate-limiter.d.ts.map