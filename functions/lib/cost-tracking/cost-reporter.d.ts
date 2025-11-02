/**
 * Cost Reporting Functions
 * Query and aggregate cost data for analysis
 */
export interface CostReport {
    period: string;
    startDate: string;
    endDate: string;
    totalCost: number;
    byFeature: Record<string, number>;
    byModel: Record<string, number>;
    requestCount: number;
    averageCostPerRequest: number;
}
/**
 * Get cost report for a specific date range
 */
export declare function getCostReport(startDate: string, // YYYY-MM-DD
endDate: string): Promise<CostReport>;
/**
 * Get today's cost report
 */
export declare function getTodayCostReport(): Promise<CostReport>;
/**
 * Get this week's cost report (Mon-Sun)
 */
export declare function getWeeklyCostReport(): Promise<CostReport>;
/**
 * Get this month's cost report
 */
export declare function getMonthlyCostReport(): Promise<CostReport>;
/**
 * Get last N days cost report
 */
export declare function getLastNDaysCostReport(days: number): Promise<CostReport>;
/**
 * Get detailed usage logs for a specific date
 */
export declare function getUsageLogsForDate(date: string): Promise<{
    id: string;
}[]>;
/**
 * Get feature comparison report
 */
export declare function getFeatureComparisonReport(days?: number): Promise<{
    feature: string;
    totalCost: number;
    requestCount: number;
    averageCostPerRequest: number;
    percentOfTotal: number;
}[]>;
/**
 * Get most expensive feature
 */
export declare function getMostExpensiveFeature(days?: number): Promise<string | null>;
/**
 * Format cost report as human-readable string
 */
export declare function formatCostReport(report: CostReport): string;
//# sourceMappingURL=cost-reporter.d.ts.map