# Detailed File Structure & Purposes

## Cloud Functions Source Directory (`/functions/src/`)

### ROOT LEVEL FILES (Core Configuration & Entry Points)

1. **`index.ts`** (39.6 KB, 1146 lines)
   - MAIN ENTRY POINT for all Cloud Functions
   - Defines 8 exported HTTP functions:
     - `generateRecipeFromIngredients` (line 288)
     - `generateSpontaneousRecipe` (line 489)
     - `generateRecipePhoto` (line 728)
     - `extractNutritionFromImage` (line 882)
     - `transcribeMeal` (line 959)
     - `calculateRecipeNutrition` (line 1086)
   - Defines 2 internal Genkit flows:
     - `generateRecipeFromIngredientsFlow` (line 83)
     - `generateRecipePhotoFlow` (line 165)
   - CORS configuration
   - Firebase Admin initialization

2. **`genkit-instance.ts`** (1.7 KB)
   - Initializes Genkit instance
   - Loads provider plugin
   - Registers prompts
   - DO NOT EXPORT ai instance (causes circular references in deployment)

3. **`providers.ts`** (6.4 KB, 206 lines)
   - Provider abstraction layer (Google AI vs Vertex AI)
   - Model reference getter functions
   - Environment-based provider selection (USE_VERTEX_AI flag)
   - Model definitions:
     - `getRouterModel()` → Gemini 2.5 Flash-Lite
     - `getTier1Model()` → Gemini 2.5 Flash
     - `getTier2Model()` → Gemini 2.5 Flash
     - `getTier3Model()` → Gemini 2.5 Pro
     - `getRecipeModel()` → Gemini 2.5 Flash
     - `getChatModel()`, `getSummaryModel()`, etc.
   - Embedding dimension configuration (768, 1536, or 3072)
   - Context caching detection

4. **`cache-manager.ts`** (9.5 KB)
   - In-memory cache for frequently used data
   - Warm-up caches on cold start
   - Cache invalidation strategies

### FLOW DEFINITIONS (`/flows/` directory)

1. **`deep-research-v2.ts`** (21.5 KB)
   - Multi-round research orchestration
   - Flow stages:
     1. Planning phase (Latents) → ResearchPlan
     2. Round 1: Initial fetch → Sources
     3. Reflection phase (Latents) → ResearchReflection
     4. Decision: Continue or synthesize?
     5. Rounds 2-4: Refined fetches
     6. Final synthesis
   - Handles SSE event emission for iOS app
   - Calls other tools for planning, reflection, source ranking

2. **`deep-research-v2-types.ts`** (2.5 KB)
   - TypeScript interfaces for deep research flow
   - `ResearchPlan`, `ResearchReflection`, `RoundResult`, `DeepResearchResults`

3. **`router-flow.ts`** (13.7 KB)
   - Query routing to tier selection
   - Routes questions to appropriate tier based on complexity
   - Uses Flash-Lite for classification

### PROMPTS (`/prompts/` directory)

1. **`recipe_chef_assistant.prompt`** (12.8 KB)
   - Model: `vertexai/gemini-2.5-flash`
   - Config: temperature=0.7, topP=0.85, maxOutputTokens=8192, thinkingBudget=0
   - Input schema: mealType, styleType, ingredients, spontaneous, recentRecipes, diversityConstraints
   - Output schema: JSON with name, servings, prepTime, cookTime, metadata, notes, recipeContent
   - Turkish-language prompt for recipe generation
   - Handles diversity constraints, portion sizing, markdown formatting

2. **`recipe_photo_generation.prompt`** (2.0 KB)
   - Model: `vertexai/imagen-4.0-ultra-generate-001`
   - Config: No watermark, 95% JPEG quality, 2048x2048 resolution
   - Input: recipeName, ingredients, directions, mealType, aspectRatio
   - Output: media (JPEG image)
   - Professional food photography prompt

3. **`recipe_nutrition_calculator.prompt`** (17.4 KB)
   - Model: Not specified in header (uses Gemini 2.5 Pro)
   - Input: recipeName, recipeContent (markdown), servings
   - Output: JSON with detailed nutrition (calories, macros, glycemic load)
   - Medical-grade nutrition analysis

4. **`memory_aware_diabetes_assistant.prompt`** (18.8 KB)
   - Context-aware diabetes assistant prompt
   - Incorporates memory context from previous conversations

### PROMPTS AS TYPESCRIPT (`/prompts/` as TypeScript)

1. **`fast-prompt-t1.ts`** (12.5 KB)
   - Tier 1 system prompt (Flash model)
   - Direct knowledge answers, no research
   - Turkish-language persona for Dilara (diabetes patient)
   - Context: LADA diabetes, CGM (Dexcom G7), insulin ratios
   - Output style: Conversational prose (no bullet points or headers)

2. **`research-prompt-t2.ts`** (16.7 KB)
   - Tier 2 system prompt (Flash model with web search)
   - Research-based answers
   - Turkish-language persona
   - Includes communication style rules

3. **`deep-research-prompt-t3.ts`** (15.6 KB)
   - Tier 3 system prompt (Pro model with medical research)
   - Deep medical research answers
   - Turkish-language persona
   - Most comprehensive prompt

### TOOLS (`/tools/` directory) - 19 files

#### Search Tools:
1. **`exa-search.ts`** (9.5 KB)
   - Exa API web search
   - Used in T2 and T3 flows
   - Formats results for AI consumption
   - Requires Exa API key

2. **`pubmed-search.ts`** (7.1 KB)
   - PubMed API integration
   - Medical literature search
   - Used in T3 (deep research)

3. **`medrxiv-search.ts`** (3.8 KB)
   - MedRxiv preprint server search
   - Free medical research papers

4. **`clinical-trials.ts`** (4.7 KB)
   - Clinical trials search
   - NIH API integration

#### Research Processing:
5. **`query-analyzer.ts`** (10.5 KB)
   - Analyzes query complexity
   - Calculates needed source counts per tier

6. **`query-enricher.ts`** (5.7 KB)
   - Enriches queries with context

7. **`query-refiner.ts`** (7.5 KB)
   - Refines queries based on reflection

8. **`query-translator.ts`** (3.8 KB)
   - Translates Turkish queries for English APIs

9. **`latents-planner.ts`** (4.7 KB)
   - Creates research plan using extended thinking

10. **`latents-reflector.ts`** (8.1 KB)
    - Reflects on research quality using extended thinking

11. **`stopping-condition-evaluator.ts`** (5.7 KB)
    - Determines if research is complete

12. **`source-deduplicator.ts`** (5.7 KB)
    - Removes duplicate sources across APIs

13. **`source-ranker.ts`** (8.9 KB)
    - Ranks sources by relevance

14. **`source-selector.ts`** (15.5 KB)
    - Selects best sources for synthesis

15. **`parallel-research-fetcher.ts`** (19.4 KB)
    - Fetches from all research APIs in parallel
    - Progress callbacks for iOS app
    - Main orchestrator for research

#### Test Files:
16-18. **`__tests__/`** subdirectory
    - Unit tests for tools

### SERVICES (`/services/` directory)

1. **`recipe-memory.ts`** (Not fully visible)
   - Memory management for recipe generation
   - Extracts main ingredients
   - Tracks diversity constraints
   - Used for recipe caching/optimization

### UTILITIES (`/utils/` directory)

1. **`error-logger.ts`** (10.1 KB)
   - Centralized error logging
   - `logError()` function
   - `getUserFriendlyMessage()` conversion
   - `ErrorContext` type definition

2. **`rate-limiter.ts`** (5.3 KB)
   - `checkTier3RateLimit()` for Tier 3 cost control

3. **`research-helpers.ts`** (8.5 KB)
   - Source formatting helpers
   - `formatSourcesWithTypes()`

4. **`memory-context.ts`** (4.6 KB)
   - `getMemoryContext()` - retrieves user memory
   - `formatMemoryContext()` - formats for prompt

5. **`retry-handler.ts`** (8.6 KB)
   - Retry logic with exponential backoff

6. **`response-cleaner.ts`** (1.9 KB)
   - Cleans AI responses

7. **`edamam-parser.ts`** (5.7 KB)
   - Parses Edamam nutrition API responses

8. **`usda-client.ts`** (6.5 KB)
   - USDA FoodData Central API client

9. **`statistical-analysis.ts`** (11.6 KB)
   - Statistical analysis for nutrition data

### OTHER CORE FILES

1. **`diabetes-assistant-stream.ts`** (49 KB)
   - Streaming chat endpoint for diabetes questions
   - Tier routing and selection
   - SSE (Server-Sent Events) implementation
   - Token usage tracking (lines 985-992)
   - Research SSE events
   - Response metadata with token counts

2. **`nutrition-extractor.ts`** (3.0 KB)
   - Direct Gemini API calls (not Genkit)
   - Vision-based nutrition extraction from images
   - Uses ResponseSchema for JSON reliability

3. **`transcribeMeal.ts`** (11.2 KB)
   - Speech-to-text meal entry
   - Processes audio transcripts

4. **`memory-sync.ts`** (21.5 KB)
   - Syncs iOS SwiftData to Firestore
   - Batch write operations
   - Timestamp conversion utilities

5. **`extract-nutrition-data.ts`** (3.0 KB)
   - Nutrition data extraction utilities

6. **`generate-session-metadata.ts`** (4.5 KB)
   - Session metadata generation

### TEST FILES (`/__tests__/` directory)

1. **`__tests__/intent-classifier.test.ts`** - DELETED (removed in recent commit)
2. **`__tests__/pronoun-resolution.test.ts`** - DELETED
3. Various tool tests in `/tools/__tests__/`

### SCRIPTS (`/scripts/` directory)

Contains utility scripts (not detailed in exploration)

### TYPES (`/types/` directory)

1. **`recipe-memory.ts`** (3.0 KB)
   - Types for memory-aware recipe generation
   - 9 meal subcategories for diversity tracking

---

## Compiled Output (`/lib/` directory)

Same structure as `/src/` but compiled to JavaScript with type definitions:
- `lib/index.d.ts.map`, `lib/index.js.map`
- `lib/diabetes-assistant-stream.d.ts.map`, `lib/diabetes-assistant-stream.js.map`
- All other files compiled equivalently

---

## Configuration Files

1. **`package.json`**
   - Dependencies: genkit@1.19.2, @genkit-ai/google-genai, @genkit-ai/vertexai
   - Scripts: `genkit:start`, build, test commands

2. **`tsconfig.json`**
   - TypeScript compilation config

3. **`jest.config.js`**
   - Testing configuration

---

## Prompt Files (Both Compiled & Source)

**Locations:**
- Source: `/functions/prompts/`
- Compiled: `/functions/lib/prompts/`

**Files:**
1. `recipe_chef_assistant.prompt`
2. `recipe_photo_generation.prompt`
3. `recipe_nutrition_calculator.prompt`
4. `memory_aware_diabetes_assistant.prompt`

---

## Key Statistics

- **Total TypeScript files in src/**: 28+ files
- **Total lines in index.ts**: 1146 lines
- **Total prompts**: 4 (in .prompt format) + 3 (as TypeScript)
- **Total research tools**: 15+ files
- **Exported Cloud Functions**: 8
- **Defined Genkit Flows**: 2 (in index.ts) + router flow
- **Supported Models**: 6-8 depending on provider

