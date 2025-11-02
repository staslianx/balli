/**
 * Cost Tracking Service
 * Tracks API usage costs and stores them in Firestore
 */
import * as admin from "firebase-admin";
import { FeatureName } from "./model-pricing";
export interface UsageLog {
    featureName: string;
    modelName: string;
    inputTokens: number;
    outputTokens: number;
    costUSD: number;
    timestamp: admin.firestore.Timestamp;
    userId?: string;
    metadata?: Record<string, unknown>;
}
export interface DailySummary {
    date: string;
    totalCost: number;
    byFeature: Record<string, number>;
    byModel: Record<string, number>;
    requestCount: number;
    lastUpdated: admin.firestore.Timestamp;
}
/**
 * Log token-based API usage
 */
export declare function logTokenUsage(params: {
    featureName: FeatureName | string;
    modelName: string;
    inputTokens: number;
    outputTokens: number;
    userId?: string;
    metadata?: Record<string, unknown>;
}): Promise<void>;
/**
 * Log image generation usage
 */
export declare function logImageUsage(params: {
    featureName: FeatureName | string;
    modelName: string;
    imageCount?: number;
    userId?: string;
    metadata?: Record<string, unknown>;
}): Promise<void>;
/**
 * Helper to extract token counts from Genkit response
 */
export declare function extractTokenCounts(response: any): {
    inputTokens: number;
    outputTokens: number;
};
//# sourceMappingURL=cost-tracker.d.ts.map