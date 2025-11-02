/**
 * Model Pricing Configuration
 * Prices as of November 2024 from Google Cloud Vertex AI pricing
 * All prices in USD per 1M tokens
 */
export interface ModelPricing {
    inputPricePer1M: number;
    outputPricePer1M: number;
}
export declare const MODEL_PRICING: Record<string, ModelPricing>;
/**
 * Imagen pricing per image (not token-based)
 */
export declare const IMAGEN_PRICING: {
    "imagen-3.0-generate-001": {
        perImage: number;
    };
    "imagen-4.0-ultra": {
        perImage: number;
    };
};
/**
 * Calculate cost for token-based models
 */
export declare function calculateTokenCost(modelName: string, inputTokens: number, outputTokens: number): number;
/**
 * Calculate cost for Imagen image generation
 */
export declare function calculateImageCost(modelName: string, imageCount?: number): number;
/**
 * Feature name constants for consistent tracking
 */
export declare enum FeatureName {
    RECIPE_GENERATION = "recipe_generation",
    NUTRITION_CALCULATION = "nutrition_calculation",
    IMAGE_GENERATION = "image_generation",
    CHAT_ASSISTANT = "chat_assistant",
    VOICE_MEAL_LOGGING = "voice_meal_logging",
    RESEARCH_FAST = "research_fast_t1",
    RESEARCH_STANDARD = "research_standard_t2",
    RESEARCH_DEEP = "research_deep_t3",
    EMBEDDING_GENERATION = "embedding_generation"
}
//# sourceMappingURL=model-pricing.d.ts.map