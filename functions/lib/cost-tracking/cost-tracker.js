"use strict";
/**
 * Cost Tracking Service
 * Tracks API usage costs and stores them in Firestore
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
exports.logTokenUsage = logTokenUsage;
exports.logImageUsage = logImageUsage;
exports.extractTokenCounts = extractTokenCounts;
const admin = __importStar(require("firebase-admin"));
const model_pricing_1 = require("./model-pricing");
/**
 * Log token-based API usage
 */
async function logTokenUsage(params) {
    try {
        const cost = (0, model_pricing_1.calculateTokenCost)(params.modelName, params.inputTokens, params.outputTokens);
        const usageLog = {
            featureName: params.featureName,
            modelName: params.modelName,
            inputTokens: params.inputTokens,
            outputTokens: params.outputTokens,
            costUSD: cost,
            timestamp: admin.firestore.Timestamp.now(),
            userId: params.userId,
            metadata: params.metadata,
        };
        // Store individual usage log
        await admin
            .firestore()
            .collection("cost_tracking")
            .doc("usage_logs")
            .collection("logs")
            .add(usageLog);
        // Update daily summary
        await updateDailySummary(params.featureName, params.modelName, cost);
        console.log(`Cost tracked: ${params.featureName} - $${cost.toFixed(6)} ` +
            `(${params.inputTokens} in, ${params.outputTokens} out)`);
    }
    catch (error) {
        console.error("Failed to log token usage:", error);
        // Don't throw - cost tracking should not break main functionality
    }
}
/**
 * Log image generation usage
 */
async function logImageUsage(params) {
    try {
        const cost = (0, model_pricing_1.calculateImageCost)(params.modelName, params.imageCount || 1);
        const usageLog = {
            featureName: params.featureName,
            modelName: params.modelName,
            inputTokens: 0,
            outputTokens: 0,
            costUSD: cost,
            timestamp: admin.firestore.Timestamp.now(),
            userId: params.userId,
            metadata: {
                ...params.metadata,
                imageCount: params.imageCount || 1,
            },
        };
        // Store individual usage log
        await admin
            .firestore()
            .collection("cost_tracking")
            .doc("usage_logs")
            .collection("logs")
            .add(usageLog);
        // Update daily summary
        await updateDailySummary(params.featureName, params.modelName, cost);
        console.log(`Cost tracked: ${params.featureName} - $${cost.toFixed(6)} ` +
            `(${params.imageCount || 1} image(s))`);
    }
    catch (error) {
        console.error("Failed to log image usage:", error);
        // Don't throw - cost tracking should not break main functionality
    }
}
/**
 * Update daily summary with new usage
 */
async function updateDailySummary(featureName, modelName, cost) {
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const summaryRef = admin
        .firestore()
        .collection("cost_tracking")
        .doc("daily_summaries")
        .collection("summaries")
        .doc(today);
    await admin.firestore().runTransaction(async (transaction) => {
        const summaryDoc = await transaction.get(summaryRef);
        if (!summaryDoc.exists) {
            // Create new daily summary
            const newSummary = {
                date: today,
                totalCost: cost,
                byFeature: { [featureName]: cost },
                byModel: { [modelName]: cost },
                requestCount: 1,
                lastUpdated: admin.firestore.Timestamp.now(),
            };
            transaction.set(summaryRef, newSummary);
        }
        else {
            // Update existing summary
            transaction.update(summaryRef, {
                totalCost: admin.firestore.FieldValue.increment(cost),
                [`byFeature.${featureName}`]: admin.firestore.FieldValue.increment(cost),
                [`byModel.${modelName}`]: admin.firestore.FieldValue.increment(cost),
                requestCount: admin.firestore.FieldValue.increment(1),
                lastUpdated: admin.firestore.Timestamp.now(),
            });
        }
    });
}
/**
 * Helper to extract token counts from Genkit response
 */
function extractTokenCounts(response) {
    // Genkit stores usage in response.usage or response.metadata.usage
    const usage = response?.usage || response?.metadata?.usage;
    if (usage) {
        return {
            inputTokens: usage.inputTokens || usage.promptTokens || 0,
            outputTokens: usage.outputTokens || usage.candidatesTokens || 0,
        };
    }
    // Fallback: try to estimate from text length if usage not available
    // (Very rough estimate: ~4 chars per token)
    const outputText = response?.text || response?.output || "";
    const estimatedOutputTokens = Math.ceil(outputText.length / 4);
    console.warn("Token usage not found in response, using rough estimate:", estimatedOutputTokens);
    return {
        inputTokens: 0, // Can't estimate input without the prompt
        outputTokens: estimatedOutputTokens,
    };
}
//# sourceMappingURL=cost-tracker.js.map