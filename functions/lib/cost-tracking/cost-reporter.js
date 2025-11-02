"use strict";
/**
 * Cost Reporting Functions
 * Query and aggregate cost data for analysis
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCostReport = getCostReport;
exports.getTodayCostReport = getTodayCostReport;
exports.getWeeklyCostReport = getWeeklyCostReport;
exports.getMonthlyCostReport = getMonthlyCostReport;
exports.getLastNDaysCostReport = getLastNDaysCostReport;
exports.getUsageLogsForDate = getUsageLogsForDate;
exports.getFeatureComparisonReport = getFeatureComparisonReport;
exports.getMostExpensiveFeature = getMostExpensiveFeature;
exports.formatCostReport = formatCostReport;
const admin = __importStar(require("firebase-admin"));
/**
 * Get cost report for a specific date range
 */
async function getCostReport(startDate, // YYYY-MM-DD
endDate // YYYY-MM-DD
) {
    const summariesRef = admin
        .firestore()
        .collection("cost_tracking")
        .doc("daily_summaries")
        .collection("summaries");
    const snapshot = await summariesRef
        .where("date", ">=", startDate)
        .where("date", "<=", endDate)
        .get();
    let totalCost = 0;
    let requestCount = 0;
    const byFeature = {};
    const byModel = {};
    snapshot.forEach((doc) => {
        const summary = doc.data();
        totalCost += summary.totalCost;
        requestCount += summary.requestCount;
        // Aggregate by feature
        Object.entries(summary.byFeature).forEach(([feature, cost]) => {
            byFeature[feature] = (byFeature[feature] || 0) + cost;
        });
        // Aggregate by model
        Object.entries(summary.byModel).forEach(([model, cost]) => {
            byModel[model] = (byModel[model] || 0) + cost;
        });
    });
    return {
        period: "custom",
        startDate,
        endDate,
        totalCost,
        byFeature,
        byModel,
        requestCount,
        averageCostPerRequest: requestCount > 0 ? totalCost / requestCount : 0,
    };
}
/**
 * Get today's cost report
 */
async function getTodayCostReport() {
    const today = new Date().toISOString().split("T")[0];
    return getCostReport(today, today);
}
/**
 * Get this week's cost report (Mon-Sun)
 */
async function getWeeklyCostReport() {
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 = Sunday, 1 = Monday, etc.
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const monday = new Date(now);
    monday.setDate(now.getDate() - daysToMonday);
    const startDate = monday.toISOString().split("T")[0];
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    const endDate = sunday.toISOString().split("T")[0];
    const report = await getCostReport(startDate, endDate);
    return {
        ...report,
        period: "weekly",
    };
}
/**
 * Get this month's cost report
 */
async function getMonthlyCostReport() {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    const startDate = new Date(year, month, 1).toISOString().split("T")[0];
    const endDate = new Date(year, month + 1, 0).toISOString().split("T")[0];
    const report = await getCostReport(startDate, endDate);
    return {
        ...report,
        period: "monthly",
    };
}
/**
 * Get last N days cost report
 */
async function getLastNDaysCostReport(days) {
    const endDate = new Date().toISOString().split("T")[0];
    const startDateObj = new Date();
    startDateObj.setDate(startDateObj.getDate() - days + 1);
    const startDate = startDateObj.toISOString().split("T")[0];
    const report = await getCostReport(startDate, endDate);
    return {
        ...report,
        period: `last_${days}_days`,
    };
}
/**
 * Get detailed usage logs for a specific date
 */
async function getUsageLogsForDate(date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    const logsRef = admin
        .firestore()
        .collection("cost_tracking")
        .doc("usage_logs")
        .collection("logs");
    const snapshot = await logsRef
        .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
        .where("timestamp", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
        .orderBy("timestamp", "desc")
        .limit(100) // Limit to most recent 100
        .get();
    return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
    }));
}
/**
 * Get feature comparison report
 */
async function getFeatureComparisonReport(days = 7) {
    const report = await getLastNDaysCostReport(days);
    const features = Object.entries(report.byFeature).map(([feature, cost]) => {
        // Count requests for this feature from logs
        // For now, we'll estimate based on total requests
        const estimatedRequests = Math.round((cost / report.totalCost) * report.requestCount);
        return {
            feature,
            totalCost: cost,
            requestCount: estimatedRequests,
            averageCostPerRequest: estimatedRequests > 0 ? cost / estimatedRequests : 0,
            percentOfTotal: report.totalCost > 0 ? (cost / report.totalCost) * 100 : 0,
        };
    });
    // Sort by cost descending
    return features.sort((a, b) => b.totalCost - a.totalCost);
}
/**
 * Get most expensive feature
 */
async function getMostExpensiveFeature(days = 7) {
    const comparison = await getFeatureComparisonReport(days);
    return comparison.length > 0 ? comparison[0].feature : null;
}
/**
 * Format cost report as human-readable string
 */
function formatCostReport(report) {
    const lines = [];
    lines.push(`=== Cost Report (${report.period}) ===`);
    lines.push(`Period: ${report.startDate} to ${report.endDate}`);
    lines.push(`Total Cost: $${report.totalCost.toFixed(4)}`);
    lines.push(`Total Requests: ${report.requestCount}`);
    lines.push(`Average Cost/Request: $${report.averageCostPerRequest.toFixed(6)}`);
    lines.push("");
    lines.push("By Feature:");
    Object.entries(report.byFeature)
        .sort(([, a], [, b]) => b - a)
        .forEach(([feature, cost]) => {
        const percent = report.totalCost > 0 ?
            ((cost / report.totalCost) * 100).toFixed(1) :
            "0.0";
        lines.push(`  ${feature}: $${cost.toFixed(4)} (${percent}%)`);
    });
    lines.push("");
    lines.push("By Model:");
    Object.entries(report.byModel)
        .sort(([, a], [, b]) => b - a)
        .forEach(([model, cost]) => {
        const percent = report.totalCost > 0 ?
            ((cost / report.totalCost) * 100).toFixed(1) :
            "0.0";
        lines.push(`  ${model}: $${cost.toFixed(4)} (${percent}%)`);
    });
    return lines.join("\n");
}
//# sourceMappingURL=cost-reporter.js.map