//
// Provider Abstraction Layer for Genkit
// Supports both Google AI and Vertex AI providers with feature flags
//
import { googleAI } from '@genkit-ai/google-genai';
import { vertexAI } from '@genkit-ai/vertexai';

// Provider configuration interface
interface ProviderConfig {
  plugin: any;
  name: 'googleai' | 'vertexai';
}

// Model reference interface for consistency
interface ModelReference {
  chat: any;
  summary: any;
  embedder: any;
  classifier: any; // For intent classification
  router: any; // For tier routing (Flash Lite)
  tier1: any; // For direct knowledge (Flash)
  tier2: any; // For web search (Flash)
  tier3: any; // For medical research (Flash with thinking)
  nutritionCalculator: any; // For nutrition calculation (Pro)
}

// Environment-based provider selection
export function getProviderConfig(): ProviderConfig['plugin'] {
  const useVertexAI = process.env.USE_VERTEX_AI === 'true';
  const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID;

  if (useVertexAI) {
    console.log('🔄 Using Vertex AI provider');
    return vertexAI({
      projectId: projectId || 'balli-project',
      location: 'us-central1'
    });
  } else {
    console.log('🔄 Using Google AI provider');
    return googleAI();
  }
}

// Get provider name for logging and monitoring
export function getProviderName(): 'googleai' | 'vertexai' {
  return process.env.USE_VERTEX_AI === 'true' ? 'vertexai' : 'googleai';
}

// Unified model reference getter
export function getModelReferences(): ModelReference {
  const useVertexAI = process.env.USE_VERTEX_AI === 'true';

  if (useVertexAI) {
    // Vertex AI - use Gemini 2.5 models (stable GA versions, no version suffix needed)
    return {
      chat: 'vertexai/gemini-2.5-flash',
      summary: 'vertexai/gemini-2.5-flash',
      embedder: vertexAI.embedder('gemini-embedding-001', {
        outputDimensionality: 768  // Default 768 dimensions (not actively used)
      }),
      classifier: 'vertexai/gemini-2.5-flash',
      router: 'vertexai/gemini-2.5-flash-lite', // Fast, cheap for classification
      tier1: 'vertexai/gemini-2.5-flash', // Direct knowledge with context caching support
      tier2: 'vertexai/gemini-2.5-flash', // Web search with context caching support
      tier3: 'vertexai/gemini-2.5-flash', // Medical research with thinking mode + context caching
      nutritionCalculator: 'vertexai/gemini-2.5-pro' // Nutrition calculation with context caching
    };
  } else {
    // Google AI - use stable model names from Google AI API
    // Available models: gemini-2.5-flash-lite, gemini-2.5-flash, gemini-2.5-pro
    // Model list: https://generativelanguage.googleapis.com/v1beta/models
    return {
      chat: 'googleai/gemini-2.5-flash',
      summary: 'googleai/gemini-2.5-flash',
      embedder: googleAI.embedder('gemini-embedding-001', {
        outputDimensionality: 768  // Default 768 dimensions (not actively used)
      }),
      classifier: 'googleai/gemini-2.5-flash',
      router: 'googleai/gemini-2.5-flash-lite', // Fast, cheap for classification
      tier1: 'googleai/gemini-2.5-flash', // Direct knowledge
      tier2: 'googleai/gemini-2.5-flash', // Web search
      tier3: 'googleai/gemini-2.5-flash', // Medical research with thinking mode
      nutritionCalculator: 'googleai/gemini-2.5-pro' // Nutrition calculation (stays Pro)
    };
  }
}

// Individual model getters for convenience
export function getChatModel() {
  return getModelReferences().chat;
}

export function getSummaryModel() {
  return getModelReferences().summary;
}

export function getEmbedder() {
  return getModelReferences().embedder;
}

export function getClassifierModel() {
  return getModelReferences().classifier;
}

export function getRecipeModel() {
  // Use the same model as chat for recipe generation
  return getModelReferences().chat;
}

export function getFlashModel() {
  // Alias for getTier1Model for backward compatibility
  return getModelReferences().tier1;
}

// 3-Tier diabetes assistant model getters
export function getRouterModel() {
  return getModelReferences().router;
}

export function getTier1Model() {
  return getModelReferences().tier1;
}

export function getTier2Model() {
  return getModelReferences().tier2;
}

export function getTier3Model() {
  return getModelReferences().tier3;
}

export function getNutritionCalculatorModel() {
  return getModelReferences().nutritionCalculator;
}

// Context caching support detection
export function supportsContextCaching(): boolean {
  const useVertexAI = process.env.USE_VERTEX_AI === 'true';
  return useVertexAI; // Only Vertex AI supports context caching as of September 2025
}

// Provider-specific configuration
export function getProviderSpecificConfig() {
  const useVertexAI = process.env.USE_VERTEX_AI === 'true';
  const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID || 'balli-project';

  if (useVertexAI) {
    return {
      type: 'vertexai' as const,
      projectId,
      location: 'us-central1',
      supportsCache: true
    };
  } else {
    return {
      type: 'googleai' as const,
      apiKey: process.env.GEMINI_API_KEY,
      supportsCache: false
    };
  }
}

// Helper for provider-aware error messages
export function getProviderError(error: any): string {
  const provider = getProviderName();
  const config = getProviderSpecificConfig();

  let errorContext = `Provider: ${provider}`;

  if (provider === 'vertexai') {
    errorContext += `, Project: ${config.projectId}, Location: ${config.location}`;
  }

  return `${errorContext} - ${error.message || error}`;
}

// Migration utilities
export function logProviderSwitch() {
  const provider = getProviderName();
  const config = getProviderSpecificConfig();

  console.log(`🔧 [PROVIDER] Active provider: ${provider}`);
  console.log(`🔧 [PROVIDER] Context caching: ${supportsContextCaching() ? '✅ Available' : '❌ Not available'}`);

  if (provider === 'vertexai') {
    console.log(`🔧 [PROVIDER] Project: ${config.projectId}, Location: ${config.location}`);
  }
}