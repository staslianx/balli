"use strict";
/**
 * Diabetes Research Assistant - NEW 2-Tier Architecture
 *
 * Smart routing system that optimizes cost and quality:
 * - Tier 1 (FLASH): Gemini 2.5 Flash with optional Exa search - $0.0001-0.003
 * - Tier 2 (PRO_RESEARCH): Gemini 2.5 Pro + comprehensive research - $0.015-0.030
 *
 * Uses Gemini 2.5 Flash Lite for fast, accurate routing with few-shot prompting
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTier3UsageStats = exports.diabetesAssistantHealth = exports.diabetesAssistant = void 0;
const https_1 = require("firebase-functions/v2/https");
const router_flow_1 = require("./flows/router-flow");
const flash_flow_1 = require("./flows/flash-flow");
const pro_research_flow_1 = require("./flows/pro-research-flow");
const rate_limiter_1 = require("./utils/rate-limiter");
const error_logger_1 = require("./utils/error-logger");
/**
 * Main diabetes assistant function
 */
exports.diabetesAssistant = (0, https_1.onCall)({
    region: 'us-central1',
    maxInstances: 10,
    timeoutSeconds: 300, // 5 minutes for Tier 3 queries
    memory: '512MiB'
}, async (request) => {
    const startTime = Date.now();
    try {
        // Validate input
        if (!request.data.question || typeof request.data.question !== 'string') {
            const error = new https_1.HttpsError('invalid-argument', 'Question is required and must be a string');
            (0, error_logger_1.logError)(error_logger_1.ErrorType.VALIDATION, error, {
                userId: request.data?.userId,
                operation: 'input validation'
            });
            throw error;
        }
        if (!request.data.userId || typeof request.data.userId !== 'string') {
            const error = new https_1.HttpsError('invalid-argument', 'User ID is required');
            (0, error_logger_1.logError)(error_logger_1.ErrorType.VALIDATION, error, {
                operation: 'input validation'
            });
            throw error;
        }
        const { question, userId, diabetesProfile } = request.data;
        // Log operation start
        (0, error_logger_1.logOperationStart)('diabetes assistant query', {
            userId,
            query: question
        });
        console.log(`🩺 [DIABETES-ASSISTANT] New query from user ${userId}`);
        console.log(`📝 [DIABETES-ASSISTANT] Question: "${question.substring(0, 100)}..."`);
        // Step 1: Route the question
        console.log(`🔀 [DIABETES-ASSISTANT] Step 1: Routing question...`);
        const routerInput = {
            question,
            userId,
            diabetesProfile
        };
        const routing = await (0, router_flow_1.routeQuestion)(routerInput);
        console.log(`✅ [DIABETES-ASSISTANT] Routed to Tier ${routing.tier} (${routing.confidence.toFixed(2)} confidence)`);
        console.log(`💡 [DIABETES-ASSISTANT] Reasoning: ${routing.reasoning}`);
        // Step 2: Check rate limiting for Pro tier
        if (routing.tier === 2) {
            const rateLimit = await (0, rate_limiter_1.checkTier3RateLimit)(userId);
            if (!rateLimit.allowed) {
                console.log(`🚫 [DIABETES-ASSISTANT] Pro tier rate limit exceeded for user ${userId}`);
                // Get usage stats
                const usage = await (0, rate_limiter_1.getTier3Usage)(userId);
                throw new https_1.HttpsError('resource-exhausted', rateLimit.reason || 'Daily medical research query limit reached', {
                    remaining: usage.remaining,
                    limit: usage.limit,
                    resetAt: usage.resetAt.toISOString()
                });
            }
            console.log(`✅ [DIABETES-ASSISTANT] Rate limit check passed (${rateLimit.remaining} remaining)`);
        }
        // Step 3: Execute appropriate tier
        let answer;
        let sources;
        let researchSummary = undefined;
        let modelUsed;
        let costTier;
        let toolsUsed = [];
        let processingTier = 'MODEL';
        let thinkingSummary;
        const tierInput = {
            question,
            userId,
            diabetesProfile
        };
        if (routing.tier === 1) {
            console.log(`⚡ [DIABETES-ASSISTANT] Step 2: Executing FLASH tier...`);
            const result = await (0, flash_flow_1.flashTier)(tierInput);
            // Check if Flash recommends escalation to Pro
            if (result.shouldEscalate) {
                console.log(`🔼 [DIABETES-ASSISTANT] Flash recommends escalation: ${result.escalationReason}`);
                console.log(`🔬 [DIABETES-ASSISTANT] Auto-escalating to Pro Research...`);
                // Auto-escalate to Pro tier
                const proResult = await (0, pro_research_flow_1.proResearchTier)(tierInput);
                answer = proResult.answer;
                sources = proResult.sources;
                researchSummary = proResult.researchSummary;
                toolsUsed = proResult.toolsUsed;
                modelUsed = 'gemini-2.5-pro + comprehensive research (auto-escalated from Flash)';
                costTier = 'high';
                processingTier = 'RESEARCH'; // Map old DEEP_RESEARCH to new RESEARCH
                thinkingSummary = proResult.thinkingSummary;
                // Record Pro usage for rate limiting
                await (0, rate_limiter_1.recordTier3Usage)(userId, question);
            }
            else {
                answer = result.answer;
                sources = result.sources;
                toolsUsed = result.toolsUsed;
                // Map old flash tier names to new 3-tier system
                const oldTier = result.processingTier;
                if (oldTier === 'WEB_SEARCH' || oldTier === 'MODEL_WITH_SEARCH') {
                    processingTier = 'SEARCH';
                    modelUsed = 'gemini-2.5-flash + Exa';
                    costTier = 'medium';
                }
                else {
                    processingTier = 'MODEL';
                    modelUsed = 'gemini-2.5-flash';
                    costTier = 'low';
                }
                thinkingSummary = result.thinkingSummary;
            }
        }
        else {
            // Tier 2 or 3: Pro Research
            console.log(`🔬 [DIABETES-ASSISTANT] Step 2: Executing Pro Research tier...`);
            const result = await (0, pro_research_flow_1.proResearchTier)(tierInput);
            answer = result.answer;
            sources = result.sources;
            researchSummary = result.researchSummary;
            toolsUsed = result.toolsUsed;
            modelUsed = 'gemini-2.5-pro + comprehensive research (Exa + PubMed + Arxiv + ClinicalTrials)';
            costTier = 'high';
            processingTier = 'RESEARCH'; // Map old DEEP_RESEARCH to new RESEARCH
            thinkingSummary = result.thinkingSummary;
            // Record Pro tier usage for rate limiting
            await (0, rate_limiter_1.recordTier3Usage)(userId, question);
        }
        // Step 4: Build response
        const totalDuration = ((Date.now() - startTime) / 1000).toFixed(2);
        const response = {
            answer,
            tier: routing.tier,
            processingTier: processingTier ?? 'MODEL',
            thinkingSummary,
            routing: {
                selectedTier: routing.tier,
                reasoning: routing.reasoning,
                confidence: routing.confidence
            },
            sources,
            metadata: {
                processingTime: `${totalDuration}s`,
                modelUsed,
                costTier,
                toolsUsed: toolsUsed.length > 0 ? toolsUsed : undefined
            }
        };
        // Add research summary for Pro tier
        if (researchSummary) {
            response.researchSummary = researchSummary;
        }
        // Add rate limit info for Pro tier
        if (routing.tier === 2) {
            const usage = await (0, rate_limiter_1.getTier3Usage)(userId);
            response.rateLimitInfo = {
                remaining: usage.remaining,
                resetAt: usage.resetAt.toISOString()
            };
        }
        // Log success (totalDuration already calculated above at line 234)
        (0, error_logger_1.logOperationSuccess)('diabetes assistant query', Date.now() - startTime, {
            userId,
            tier: routing.tier,
            additionalData: {
                costTier,
                modelUsed,
                sourcesCount: sources.length
            }
        });
        console.log(`✅ [DIABETES-ASSISTANT] Completed in ${totalDuration}s`);
        console.log(`💰 [DIABETES-ASSISTANT] Cost tier: ${costTier}, Model: ${modelUsed}`);
        console.log(`📊 [DIABETES-ASSISTANT] Sources: ${sources.length}, Tools used: ${toolsUsed.join(', ') || 'none'}`);
        return response;
    }
    catch (error) {
        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        console.error(`❌ [DIABETES-ASSISTANT] Error after ${duration}s:`, error);
        // Extract context from request data
        const errorContext = {
            userId: request.data?.userId,
            operation: 'diabetes assistant query',
            query: request.data?.question
        };
        // Re-throw HttpsErrors (already logged)
        if (error instanceof https_1.HttpsError) {
            // Log if not already logged (e.g., from flows)
            if (error.code !== 'invalid-argument') {
                (0, error_logger_1.logError)(undefined, error, errorContext);
            }
            throw error;
        }
        // Log unknown errors with structured context
        (0, error_logger_1.logError)(error_logger_1.ErrorType.INTERNAL, error, errorContext);
        // Get user-friendly message (don't expose internal details)
        const userMessage = (0, error_logger_1.getUserFriendlyMessage)(error);
        // Wrap other errors with user-friendly message
        throw new https_1.HttpsError('internal', userMessage, { originalError: error instanceof Error ? error.message : String(error) });
    }
});
/**
 * Health check endpoint
 */
exports.diabetesAssistantHealth = (0, https_1.onCall)({ region: 'us-central1' }, async () => {
    return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        architecture: '2-tier system',
        tiers: {
            flash: 'gemini-2.5-flash (with optional Exa search)',
            proResearch: 'gemini-2.5-pro + Exa (medical) + PubMed + Arxiv + ClinicalTrials'
        },
        router: 'gemini-2.5-flash-lite',
        rateLimits: {
            proResearchDailyLimit: 10
        }
    };
});
/**
 * Get user's Tier 3 usage stats
 */
exports.getTier3UsageStats = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    if (!request.data.userId) {
        throw new https_1.HttpsError('invalid-argument', 'User ID is required');
    }
    const usage = await (0, rate_limiter_1.getTier3Usage)(request.data.userId);
    return {
        count: usage.count,
        limit: usage.limit,
        remaining: usage.remaining,
        resetAt: usage.resetAt.toISOString()
    };
});
//# sourceMappingURL=diabetes-assistant.js.map