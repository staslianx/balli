/**
 * Analytics Manager
 *
 * Aggregates diversity metrics and provides insights over time.
 * Helps users understand their recipe variety patterns.
 */
import { DiversityMetrics } from './types';
/**
 * Calculate diversity metrics for a user over a time window
 *
 * @param userId - User ID
 * @param windowDays - Number of days to analyze (default: 30)
 * @returns Comprehensive diversity metrics
 */
export declare function calculateDiversityMetrics(userId: string, windowDays?: number): Promise<DiversityMetrics>;
/**
 * Save diversity metrics to Firestore
 */
export declare function saveDiversityMetrics(metrics: DiversityMetrics): Promise<void>;
/**
 * Get latest diversity metrics for a user
 */
export declare function getLatestMetrics(userId: string): Promise<DiversityMetrics | null>;
/**
 * Generate human-readable insights from metrics
 */
export declare function generateInsights(metrics: DiversityMetrics): {
    summary: string;
    recommendations: string[];
    achievements: string[];
};
/**
 * Aggregate metrics for all active users (run as scheduled function)
 *
 * This could be triggered by a Cloud Scheduler job (e.g., weekly)
 */
export declare function aggregateAllUserMetrics(): Promise<{
    processed: number;
    errors: number;
}>;
/**
 * Get user's diversity summary (for iOS client)
 */
export declare function getUserDiversitySummary(userId: string): Promise<{
    metrics: DiversityMetrics | null;
    insights: {
        summary: string;
        recommendations: string[];
        achievements: string[];
    };
}>;
//# sourceMappingURL=analytics-manager.d.ts.map