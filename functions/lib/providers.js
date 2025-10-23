"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProviderConfig = getProviderConfig;
exports.getProviderName = getProviderName;
exports.getModelReferences = getModelReferences;
exports.getChatModel = getChatModel;
exports.getSummaryModel = getSummaryModel;
exports.getEmbedder = getEmbedder;
exports.getClassifierModel = getClassifierModel;
exports.getRecipeModel = getRecipeModel;
exports.getFlashModel = getFlashModel;
exports.getRouterModel = getRouterModel;
exports.getTier1Model = getTier1Model;
exports.getTier2Model = getTier2Model;
exports.getTier3Model = getTier3Model;
exports.supportsContextCaching = supportsContextCaching;
exports.getProviderSpecificConfig = getProviderSpecificConfig;
exports.getProviderError = getProviderError;
exports.logProviderSwitch = logProviderSwitch;
//
// Provider Abstraction Layer for Genkit
// Supports both Google AI and Vertex AI providers with feature flags
//
const google_genai_1 = require("@genkit-ai/google-genai");
const vertexai_1 = require("@genkit-ai/vertexai");
// Environment-based provider selection
function getProviderConfig() {
    const useVertexAI = process.env.USE_VERTEX_AI === 'true';
    const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID;
    if (useVertexAI) {
        console.log('🔄 Using Vertex AI provider');
        return (0, vertexai_1.vertexAI)({
            projectId: projectId || 'balli-project',
            location: 'us-central1'
        });
    }
    else {
        console.log('🔄 Using Google AI provider');
        return (0, google_genai_1.googleAI)();
    }
}
// Get provider name for logging and monitoring
function getProviderName() {
    return process.env.USE_VERTEX_AI === 'true' ? 'vertexai' : 'googleai';
}
/**
 * Get and validate embedding dimensions for gemini-embedding-001
 * Supports 768, 1536, or 3072 dimensions via Matryoshka Representation Learning
 * Using 768D for optimal balance of quality and performance
 */
function getEmbeddingDimensions() {
    const dimStr = process.env.EMBEDDING_DIMENSIONS;
    const dim = dimStr ? parseInt(dimStr) : 768; // Default to 768 for Vertex AI
    // Validate dimension range for gemini-embedding-001
    // Supports 768, 1536, or 3072 via Matryoshka Representation Learning
    const validDimensions = [768, 1536, 3072];
    if (!validDimensions.includes(dim)) {
        console.error(`❌ [EMBEDDING] Invalid dimension ${dim}. ` +
            `gemini-embedding-001 supports 768, 1536, or 3072. Using 768.`);
        return 768;
    }
    console.log(`✅ [EMBEDDING] Configured for ${dim} dimensions`);
    return dim;
}
// Unified model reference getter
function getModelReferences() {
    const useVertexAI = process.env.USE_VERTEX_AI === 'true';
    const embeddingDimensions = getEmbeddingDimensions(); // Use validated dimensions
    if (useVertexAI) {
        // Vertex AI - use Gemini 2.5 models (1.5 versions deprecated)
        return {
            chat: 'vertexai/gemini-2.5-flash',
            summary: 'vertexai/gemini-2.5-flash',
            embedder: vertexai_1.vertexAI.embedder('gemini-embedding-001', {
                outputDimensionality: embeddingDimensions
            }),
            classifier: 'vertexai/gemini-2.5-flash',
            router: 'vertexai/gemini-2.5-flash-lite', // Fast, cheap for classification
            tier1: 'vertexai/gemini-2.5-flash', // Direct knowledge
            tier2: 'vertexai/gemini-2.5-flash', // Web search
            tier3: 'vertexai/gemini-2.5-pro' // Medical research
        };
    }
    else {
        // Google AI - use stable model names from Google AI API
        // Available models: gemini-2.5-flash-lite, gemini-2.5-flash, gemini-2.5-pro
        // Model list: https://generativelanguage.googleapis.com/v1beta/models
        return {
            chat: 'googleai/gemini-2.5-flash',
            summary: 'googleai/gemini-2.5-flash',
            embedder: google_genai_1.googleAI.embedder('gemini-embedding-001', {
                outputDimensionality: embeddingDimensions
            }),
            classifier: 'googleai/gemini-2.5-flash',
            router: 'googleai/gemini-2.5-flash-lite', // Fast, cheap for classification
            tier1: 'googleai/gemini-2.5-flash', // Direct knowledge
            tier2: 'googleai/gemini-2.5-flash', // Web search
            tier3: 'googleai/gemini-2.5-pro' // Medical research
        };
    }
}
// Individual model getters for convenience
function getChatModel() {
    return getModelReferences().chat;
}
function getSummaryModel() {
    return getModelReferences().summary;
}
function getEmbedder() {
    return getModelReferences().embedder;
}
function getClassifierModel() {
    return getModelReferences().classifier;
}
function getRecipeModel() {
    // Use the same model as chat for recipe generation
    return getModelReferences().chat;
}
function getFlashModel() {
    // Alias for getTier1Model for backward compatibility
    return getModelReferences().tier1;
}
// 3-Tier diabetes assistant model getters
function getRouterModel() {
    return getModelReferences().router;
}
function getTier1Model() {
    return getModelReferences().tier1;
}
function getTier2Model() {
    return getModelReferences().tier2;
}
function getTier3Model() {
    return getModelReferences().tier3;
}
// Context caching support detection
function supportsContextCaching() {
    const useVertexAI = process.env.USE_VERTEX_AI === 'true';
    return useVertexAI; // Only Vertex AI supports context caching as of September 2025
}
// Provider-specific configuration
function getProviderSpecificConfig() {
    const useVertexAI = process.env.USE_VERTEX_AI === 'true';
    const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID || 'balli-project';
    if (useVertexAI) {
        return {
            type: 'vertexai',
            projectId,
            location: 'us-central1',
            supportsCache: true
        };
    }
    else {
        return {
            type: 'googleai',
            apiKey: process.env.GEMINI_API_KEY,
            supportsCache: false
        };
    }
}
// Helper for provider-aware error messages
function getProviderError(error) {
    const provider = getProviderName();
    const config = getProviderSpecificConfig();
    let errorContext = `Provider: ${provider}`;
    if (provider === 'vertexai') {
        errorContext += `, Project: ${config.projectId}, Location: ${config.location}`;
    }
    return `${errorContext} - ${error.message || error}`;
}
// Migration utilities
function logProviderSwitch() {
    const provider = getProviderName();
    const config = getProviderSpecificConfig();
    console.log(`🔧 [PROVIDER] Active provider: ${provider}`);
    console.log(`🔧 [PROVIDER] Context caching: ${supportsContextCaching() ? '✅ Available' : '❌ Not available'}`);
    if (provider === 'vertexai') {
        console.log(`🔧 [PROVIDER] Project: ${config.projectId}, Location: ${config.location}`);
    }
}
//# sourceMappingURL=providers.js.map