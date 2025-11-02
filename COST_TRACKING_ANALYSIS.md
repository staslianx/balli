# Firebase Cloud Functions Codebase Analysis - Cost Tracking Implementation Guide

## Executive Summary
The Balli diabetes assistant codebase uses a multi-tier LLM architecture with Genkit orchestration, featuring recipe generation, medical research, image generation, and nutrition analysis. Token tracking is partially implemented but lacks comprehensive cost attribution and historical analytics.

---

## 1. Current Cloud Functions Setup

### Exported Functions (8 total)

#### Recipe Generation Functions:
1. **`generateRecipeFromIngredients`** (onRequest)
   - Input: ingredients array, meal type, style type, userId
   - Model: `gemini-2.5-flash` (via `getRecipeModel()`)
   - Flow: `generateRecipeFromIngredientsFlow` (ai.defineFlow)
   - Output: Recipe JSON with markdown content
   - Timeout: 300s, Memory: 512MiB, Concurrency: 2

2. **`generateSpontaneousRecipe`** (onRequest)
   - Input: meal type, style type (no ingredients)
   - Model: `gemini-2.5-flash`
   - Flow: Uses same flow as above
   - Timeout: 300s, Memory: 512MiB

3. **`generateRecipePhoto`** (onRequest)
   - Input: recipe details, aspect ratio, quality level, resolution
   - Model: `vertexai/imagen-4.0-ultra-generate-001`
   - Image resolution: 2048x2048 (2K max)
   - Prompt file: `/prompts/recipe_photo_generation.prompt`
   - Config: No watermark, 95% JPEG quality, single sample
   - Timeout: 60s, Memory: 256MiB

#### Research & Chat Functions:
4. **`diabetesAssistantStream`** (onRequest)
   - Entry point for 3-tier diabetes assistant
   - Routes questions to Tier 1 (Flash), Tier 2 (Flash), or Tier 3 (Pro)
   - Streaming via Server-Sent Events (SSE)
   - Timeout: 540s, Memory: 512MiB

#### Nutrition & Analysis Functions:
5. **`extractNutritionFromImage`** (onRequest)
   - Input: Base64 food image
   - Method: Direct Gemini API with ResponseSchema
   - Model: `gemini-2.5-flash` (vision-enabled)
   - Output: JSON nutrition data (calories, macros, etc.)
   - Timeout: 60s, Memory: 512MiB

6. **`transcribeMeal`** (onRequest)
   - Input: Audio transcript of meal entry
   - Model: `gemini-2.5-flash`
   - Timeout: 60s, Memory: 256MiB

7. **`calculateRecipeNutrition`** (onRequest)
   - Input: recipe name, markdown content, servings
   - Model: `gemini-2.5-pro` (via `getTier3Model()`)
   - Output: Detailed nutrition analysis (medical-grade)
   - Timeout: 90s, Memory: 512MiB
   - Prompt file: `/prompts/recipe_nutrition_calculator.prompt`

#### Utility Functions:
8. **Additional utility flows** defined but not directly exported:
   - `generateRecipeFromIngredientsFlow`
   - `generateRecipePhotoFlow`

---

## 2. Genkit Flows Architecture

### Flow Definitions:
- **Location**: `functions/src/flows/`
- **Main flows**:
  - `deep-research-v2.ts` - Multi-round research with planning & reflection
  - `router-flow.ts` - Query routing to tier selection

### Key Genkit Features:
- **Prompts library**: Uses `ai.prompt()` for templated prompts
- **Prompt files**: Located in `functions/prompts/` and `functions/lib/prompts/`
- **Model configuration**: Provider-agnostic via abstraction layer
- **Streaming support**: SSE-based token streaming

---

## 3. Model Usage Patterns

### Provider Configuration (`providers.ts`)
```
Environment: Supports both Google AI and Vertex AI
Active provider: Determined by USE_VERTEX_AI=true/false

MODEL ASSIGNMENTS:

Google AI Provider (if USE_VERTEX_AI !== 'true'):
- router: googleai/gemini-2.5-flash-lite (classification)
- tier1: googleai/gemini-2.5-flash (direct knowledge)
- tier2: googleai/gemini-2.5-flash (web search)
- tier3: googleai/gemini-2.5-pro (medical research)
- chat: googleai/gemini-2.5-flash
- embedder: googleai/gemini-embedding-001 (768D default)

Vertex AI Provider (if USE_VERTEX_AI === 'true'):
- router: vertexai/gemini-2.5-flash-lite
- tier1: vertexai/gemini-2.5-flash
- tier2: vertexai/gemini-2.5-flash
- tier3: vertexai/gemini-2.5-pro
- chat: vertexai/gemini-2.5-flash
- embedder: vertexai/gemini-embedding-001 (768D, 1536D, or 3072D)
```

### Model Usage by Feature:

#### Recipe Generation:
- **Model**: Gemini 2.5 Flash (via `getRecipeModel()`)
- **Prompt**: `recipe_chef_assistant.prompt` (12.7 KB)
- **Config**: temperature=0.7, topP=0.85, maxOutputTokens=8192, thinkingBudget=0
- **Output format**: JSON (name, prepTime, cookTime, ingredients, directions, notes, recipeContent)

#### Recipe Photo Generation:
- **Model**: Imagen 4.0 Ultra (Vertex AI only)
- **Prompt**: `recipe_photo_generation.prompt` (2.0 KB)
- **Output**: JPEG image, 2048x2048, 95% quality
- **Special handling**: Base64 conversion for iOS

#### Nutrition Extraction from Image:
- **Model**: Gemini 2.5 Flash (vision)
- **Method**: Direct Google AI SDK with ResponseSchema
- **API**: `@google/generative-ai` (not Genkit)
- **Output format**: Strict JSON schema (calories, macros, fiber, sugars, vitamins)

#### Nutrition Calculation:
- **Model**: Gemini 2.5 Pro (via Genkit)
- **Prompt**: `recipe_nutrition_calculator.prompt` (17.4 KB)
- **Tier**: Tier 3 (medical-grade analysis)
- **Output**: Per 100g nutrition values + glycemic load

#### Diabetes Assistant:
- **Tier 1 (Fast)**: Gemini 2.5 Flash-Lite (quick answers, no research)
  - Prompt: `fast-prompt-t1.ts` (12.5 KB)
  - Cost tier: LOW
  - Use case: Direct knowledge questions

- **Tier 2 (Search)**: Gemini 2.5 Flash (web search)
  - Prompt: `research-prompt-t2.ts` (16.7 KB)
  - Cost tier: LOW
  - Use case: Questions requiring current research
  - Research sources: Exa (web), PubMed

- **Tier 3 (Deep Research)**: Gemini 2.5 Pro (multi-round medical research)
  - Prompt: `deep-research-prompt-t3.ts` (15.6 KB)
  - Cost tier: HIGH
  - Use case: Complex medical questions
  - Research sources: PubMed, MedRxiv, Clinical Trials, Exa
  - Flow: `deep-research-v2.ts` (21.5 KB)
  - Features: Planning phase, reflection loops, source ranking

---

## 4. API Call Locations

### Vertex AI Imagen (Image Generation):
- **File**: `functions/src/index.ts`
- **Function**: `generateRecipePhoto` (line 728+)
- **Calls**: Via Genkit prompt (`recipe_photo_generation`)
- **Model**: `vertexai/imagen-4.0-ultra-generate-001`
- **Frequency tracking**: Logged via console.log, not tracked to DB

### Gemini API Calls (Vision for Nutrition):
- **File**: `functions/src/nutrition-extractor.ts`
- **Direct API usage**: `GoogleGenerativeAI` client
- **Model**: `models/gemini-2.5-flash`
- **Method**: Direct JSON response schema
- **Reason for direct API**: 99%+ JSON parsing reliability vs Genkit

### Genkit-based Calls:
- **Files**: `index.ts` (recipe, nutrition, transcribe)
- **Files**: `diabetes-assistant-stream.ts` (chat routing & streaming)
- **Prompts**: Via `ai.prompt()` from genkit instance

### Research API Calls:
- **PubMed**: `tools/pubmed-search.ts`
- **MedRxiv**: `tools/medrxiv-search.ts`
- **Clinical Trials**: `tools/clinical-trials.ts`
- **Exa Web Search**: `tools/exa-search.ts` (requires API key)

---

## 5. Current Logging & Monitoring Patterns

### Existing Logging:
```typescript
// Console logging with emoji prefixes:
console.log(`🍳 [RECIPE] Generating recipe from ingredients...`);
console.log(`📸 [PHOTO] Generating ${qualityLevel} quality photo...`);
console.log(`🍽️ [NUTRITION-CALC] Analyzing nutrition...`);
console.log(`🔍 [PHOTO] Original image URL format...`);

// Error logging:
console.error('❌ Recipe generation from ingredients failed:', error);

// Token tracking (partial):
const outputTokens = usageMetadata?.candidatesTokenCount || 0;
const inputTokens = usageMetadata?.promptTokenCount || 0;
const totalTokens = usageMetadata?.totalTokenCount || 0;

// In SSE response metadata:
tokenUsage: {
  input: inputTokens,
  output: outputTokens,
  total: totalTokens
}

// Cost tier classification:
costTier: 'low'  // Tier 1-2
costTier: 'high' // Tier 3
```

### Current Firestore Usage:
- **File**: `memory-sync.ts`
- **Usage**: Syncs iOS SwiftData memory to Firestore
- **Collections**: Custom memory collections (not defined in this analysis)
- **No existing cost tracking collections**

### Token Usage Extraction:
- **Location**: `diabetes-assistant-stream.ts` (lines 985-992)
- **Source**: `usageMetadata` from response object
- **Captured fields**:
  - `promptTokenCount` → input tokens
  - `candidatesTokenCount` → output tokens
  - `totalTokenCount` → total tokens
- **Limitation**: Only captured for Tier 3, not for other functions

---

## 6. Firestore Structure & Storage Patterns

### Existing Collections:
```
users/{userId}
conversations/{conversationId}
  messages (subcollection)
meals/{mealId}
recipes/{recipeId}
research/{researchId}
```

### No existing cost tracking collection

---

## 7. Key Files for Cost Tracking Implementation

### Files to Modify/Create:

#### **A. Core Cost Tracking Service** (NEW)
- **Path**: `functions/src/services/cost-tracker.ts`
- **Purpose**: Centralized cost calculation and logging
- **Will contain**: Model pricing table, token -> cost conversion, usage recording

#### **B. Firestore Schema** (NEW)
- **Path**: `functions/src/types/cost-tracking.ts`
- **Collections**:
  - `costMetrics/{date}` - Daily aggregated costs
  - `apiUsage/{timestamp}` - Individual API call logs
  - `costAlerts/{alertId}` - Budget threshold violations

#### **C. Modified Files** (For instrumentation):

1. **`functions/src/index.ts`** (7 functions)
   - Line 288+: `generateRecipeFromIngredients`
   - Line 489+: `generateSpontaneousRecipe`
   - Line 728+: `generateRecipePhoto`
   - Line 882+: `extractNutritionFromImage`
   - Line 959+: `transcribeMeal`
   - Line 1086+: `calculateRecipeNutrition`
   - Add cost tracking wrapper for each

2. **`functions/src/diabetes-assistant-stream.ts`** (streaming chat)
   - Line 1048+: `diabetesAssistantStream`
   - Enhance token extraction logic
   - Track per-tier costs

3. **`functions/src/nutrition-extractor.ts`** (vision API)
   - Direct Google AI SDK calls
   - Add usage tracking wrapper

4. **`functions/src/utils/error-logger.ts`**
   - Extend ErrorContext type to include cost metadata

5. **`functions/src/tools/` (research tools)**
   - Add cost tracking for:
     - `parallel-research-fetcher.ts`
     - `exa-search.ts`
     - `pubmed-search.ts`
     - `medrxiv-search.ts`
     - `clinical-trials.ts`

#### **D. Monitoring & Dashboard** (NEW)
- **Path**: `functions/src/utils/cost-monitor.ts`
- **Features**: Budget alerts, daily limits, cost summaries

---

## 8. Model Pricing Reference (as of Nov 2024)

### Text Models:
- **Gemini 2.5 Flash-Lite**: $0.075/1M input, $0.3/1M output
- **Gemini 2.5 Flash**: $0.075/1M input, $0.3/1M output
- **Gemini 2.5 Pro**: $3/1M input, $12/1M output

### Vision Models:
- **Gemini 2.5 Flash (vision)**: Same as Flash + per-image overhead

### Image Generation:
- **Imagen 4.0 Ultra**: $0.0025 per image at 2K resolution

### Embedding:
- **Gemini Embedding 001**: $0.00002/1K embeddings

### Research APIs (external):
- **PubMed**: Free
- **MedRxiv**: Free
- **Clinical Trials**: Free
- **Exa**: Requires API key (custom pricing)

---

## 9. Recommended Cost Tracking Implementation

### Phase 1: Foundation (Week 1)
1. Create `cost-tracker.ts` service
2. Add Firestore collections schema
3. Instrument main functions with basic logging

### Phase 2: Integration (Week 2)
1. Wrap all API calls with cost tracking
2. Extract and store token counts
3. Implement cost calculation

### Phase 3: Monitoring (Week 3)
1. Create cost dashboard endpoints
2. Implement budget alerts
3. Add daily/monthly summaries

### Phase 4: Analysis (Week 4)
1. Per-feature cost attribution
2. Usage pattern analysis
3. Optimization recommendations

---

## 10. Summary Table

| Feature | Model | API | Tokenization | Cost Tier | File Location |
|---------|-------|-----|--------------|-----------|----------------|
| Recipe Generation | Gemini 2.5 Flash | Genkit | Yes (partial) | LOW | index.ts:83-141 |
| Recipe Photo | Imagen 4.0 Ultra | Genkit | N/A (images) | MEDIUM | index.ts:165-277 |
| Nutrition Extract | Gemini 2.5 Flash | Direct SDK | No | LOW | nutrition-extractor.ts |
| Nutrition Calc | Gemini 2.5 Pro | Genkit | Yes (partial) | HIGH | index.ts:1086+ |
| Chat Tier 1 | Gemini 2.5 Flash-Lite | Genkit | Yes (partial) | VERY LOW | diabetes-assistant-stream.ts |
| Chat Tier 2 | Gemini 2.5 Flash | Genkit | Yes (partial) | LOW | diabetes-assistant-stream.ts |
| Chat Tier 3 | Gemini 2.5 Pro | Genkit | Yes (full) | HIGH | diabetes-assistant-stream.ts |
| Research APIs | Various | Direct | N/A | VARIES | tools/*.ts |

---

## 11. Notes for Implementation

### Important Considerations:
1. **Token extraction**: Currently only partial for streaming responses
2. **Image costs**: Imagen is estimated at $0.0025/image (needs verification)
3. **Streaming overhead**: SSE responses don't get full token counts until complete
4. **Batch operations**: Consider aggregating costs daily vs per-request
5. **Provider costs**: Vertex AI vs Google AI may have different pricing
6. **User attribution**: Need userId to associate costs with users for multi-user scenarios

### Codebase Patterns:
- Uses feature-based folder structure (Features/, Core/, Shared/)
- Strong separation of concerns (Views, ViewModels, Services)
- Comprehensive error handling with custom error types
- Swift 6 concurrency (iOS app) - not directly relevant to Functions
- Firestore as primary database

