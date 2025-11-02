/**
 * Cost Tracking Service
 * Tracks API usage costs and stores them in Firestore
 */

import * as admin from "firebase-admin";
import {
  calculateTokenCost,
  calculateImageCost,
  FeatureName,
} from "./model-pricing";

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
  date: string; // YYYY-MM-DD
  totalCost: number;
  byFeature: Record<string, number>;
  byModel: Record<string, number>;
  requestCount: number;
  lastUpdated: admin.firestore.Timestamp;
}

/**
 * Log token-based API usage
 */
export async function logTokenUsage(params: {
  featureName: FeatureName | string;
  modelName: string;
  inputTokens: number;
  outputTokens: number;
  userId?: string;
  metadata?: Record<string, unknown>;
}): Promise<void> {
  try {
    const cost = calculateTokenCost(
      params.modelName,
      params.inputTokens,
      params.outputTokens
    );

    const usageLog: UsageLog = {
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
    await updateDailySummary(
      params.featureName,
      params.modelName,
      cost
    );

    console.log(
      `Cost tracked: ${params.featureName} - $${cost.toFixed(6)} ` +
      `(${params.inputTokens} in, ${params.outputTokens} out)`
    );
  } catch (error) {
    console.error("Failed to log token usage:", error);
    // Don't throw - cost tracking should not break main functionality
  }
}

/**
 * Log image generation usage
 */
export async function logImageUsage(params: {
  featureName: FeatureName | string;
  modelName: string;
  imageCount?: number;
  userId?: string;
  metadata?: Record<string, unknown>;
}): Promise<void> {
  try {
    const cost = calculateImageCost(params.modelName, params.imageCount || 1);

    const usageLog: UsageLog = {
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
    await updateDailySummary(
      params.featureName,
      params.modelName,
      cost
    );

    console.log(
      `Cost tracked: ${params.featureName} - $${cost.toFixed(6)} ` +
      `(${params.imageCount || 1} image(s))`
    );
  } catch (error) {
    console.error("Failed to log image usage:", error);
    // Don't throw - cost tracking should not break main functionality
  }
}

/**
 * Update daily summary with new usage
 */
async function updateDailySummary(
  featureName: string,
  modelName: string,
  cost: number
): Promise<void> {
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
      const newSummary: DailySummary = {
        date: today,
        totalCost: cost,
        byFeature: { [featureName]: cost },
        byModel: { [modelName]: cost },
        requestCount: 1,
        lastUpdated: admin.firestore.Timestamp.now(),
      };
      transaction.set(summaryRef, newSummary);
    } else {
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
export function extractTokenCounts(response: any): {
  inputTokens: number;
  outputTokens: number;
} {
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

  console.warn(
    "Token usage not found in response, using rough estimate:",
    estimatedOutputTokens
  );

  return {
    inputTokens: 0, // Can't estimate input without the prompt
    outputTokens: estimatedOutputTokens,
  };
}
