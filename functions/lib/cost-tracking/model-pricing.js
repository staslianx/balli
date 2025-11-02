"use strict";
/**
 * Model Pricing Configuration
 * Prices as of November 2024 from Google Cloud Vertex AI pricing
 * All prices in USD per 1M tokens
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.FeatureName = exports.IMAGEN_PRICING = exports.MODEL_PRICING = void 0;
exports.calculateTokenCost = calculateTokenCost;
exports.calculateImageCost = calculateImageCost;
exports.MODEL_PRICING = {
    // Gemini 2.5 Flash
    "gemini-2.0-flash-exp": {
        inputPricePer1M: 0, // Free during preview
        outputPricePer1M: 0,
    },
    "gemini-2.5-flash": {
        inputPricePer1M: 0.075, // $0.075 per 1M input tokens
        outputPricePer1M: 0.30, // $0.30 per 1M output tokens
    },
    "gemini-2.5-flash-latest": {
        inputPricePer1M: 0.075,
        outputPricePer1M: 0.30,
    },
    // Gemini 2.5 Flash-Lite (Router)
    "gemini-2.5-flash-lite": {
        inputPricePer1M: 0.0375, // Half of Flash
        outputPricePer1M: 0.15,
    },
    // Gemini 2.5 Pro
    "gemini-2.5-pro": {
        inputPricePer1M: 1.25, // $1.25 per 1M input tokens
        outputPricePer1M: 5.00, // $5.00 per 1M output tokens
    },
    "gemini-2.5-pro-latest": {
        inputPricePer1M: 1.25,
        outputPricePer1M: 5.00,
    },
    // Gemini 1.5 Flash (legacy)
    "gemini-1.5-flash": {
        inputPricePer1M: 0.075,
        outputPricePer1M: 0.30,
    },
    "gemini-1.5-flash-001": {
        inputPricePer1M: 0.075,
        outputPricePer1M: 0.30,
    },
    "gemini-1.5-flash-002": {
        inputPricePer1M: 0.075,
        outputPricePer1M: 0.30,
    },
    // Gemini 1.5 Pro (legacy)
    "gemini-1.5-pro": {
        inputPricePer1M: 1.25,
        outputPricePer1M: 5.00,
    },
    "gemini-1.5-pro-001": {
        inputPricePer1M: 1.25,
        outputPricePer1M: 5.00,
    },
    "gemini-1.5-pro-002": {
        inputPricePer1M: 1.25,
        outputPricePer1M: 5.00,
    },
    // Embedding models
    "text-embedding-004": {
        inputPricePer1M: 0.00002, // $0.00002 per 1K tokens = $0.02 per 1M
        outputPricePer1M: 0, // Embeddings have no output tokens
    },
    "textembedding-gecko": {
        inputPricePer1M: 0.00002,
        outputPricePer1M: 0,
    },
    // Imagen models (priced per image, not tokens)
    "imagen-3.0-generate-001": {
        inputPricePer1M: 0, // Handled separately
        outputPricePer1M: 0,
    },
    "imagen-4.0-ultra": {
        inputPricePer1M: 0, // Handled separately
        outputPricePer1M: 0,
    },
};
/**
 * Imagen pricing per image (not token-based)
 */
exports.IMAGEN_PRICING = {
    "imagen-3.0-generate-001": {
        perImage: 0.02, // $0.02 per image
    },
    "imagen-4.0-ultra": {
        perImage: 0.04, // $0.04 per image (estimated, check current pricing)
    },
};
/**
 * Calculate cost for token-based models
 */
function calculateTokenCost(modelName, inputTokens, outputTokens) {
    const pricing = exports.MODEL_PRICING[modelName];
    if (!pricing) {
        console.warn(`Unknown model: ${modelName}, returning $0 cost`);
        return 0;
    }
    const inputCost = (inputTokens / 1_000_000) * pricing.inputPricePer1M;
    const outputCost = (outputTokens / 1_000_000) * pricing.outputPricePer1M;
    return inputCost + outputCost;
}
/**
 * Calculate cost for Imagen image generation
 */
function calculateImageCost(modelName, imageCount = 1) {
    const pricing = exports.IMAGEN_PRICING[modelName];
    if (!pricing) {
        console.warn(`Unknown Imagen model: ${modelName}, returning $0 cost`);
        return 0;
    }
    return pricing.perImage * imageCount;
}
/**
 * Feature name constants for consistent tracking
 */
var FeatureName;
(function (FeatureName) {
    FeatureName["RECIPE_GENERATION"] = "recipe_generation";
    FeatureName["NUTRITION_CALCULATION"] = "nutrition_calculation";
    FeatureName["IMAGE_GENERATION"] = "image_generation";
    FeatureName["CHAT_ASSISTANT"] = "chat_assistant";
    FeatureName["VOICE_MEAL_LOGGING"] = "voice_meal_logging";
    FeatureName["RESEARCH_FAST"] = "research_fast_t1";
    FeatureName["RESEARCH_STANDARD"] = "research_standard_t2";
    FeatureName["RESEARCH_DEEP"] = "research_deep_t3";
    FeatureName["EMBEDDING_GENERATION"] = "embedding_generation";
})(FeatureName || (exports.FeatureName = FeatureName = {}));
//# sourceMappingURL=model-pricing.js.map