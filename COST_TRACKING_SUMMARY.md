# Firebase Cloud Functions Codebase Exploration - Complete Summary

**Date**: November 2, 2025
**Project**: Balli - Diabetes Assistant iOS App
**Focus**: Cloud Functions architecture and cost tracking implementation planning

---

## Key Findings

### 1. Architecture Overview
The Balli Cloud Functions use a **multi-tier LLM architecture** powered by Google Genkit with support for both Google AI and Vertex AI providers. The system includes:

- **8 exported Cloud Functions**
- **3 internal Genkit flows**
- **15+ research and utility tools**
- **4 prompt files** for specialized tasks
- **Multi-tier routing system** (Tier 1: Fast, Tier 2: Web Search, Tier 3: Deep Medical Research)

### 2. Models in Use
```
Provider: Google AI or Vertex AI (configurable via USE_VERTEX_AI env var)

Router:      Gemini 2.5 Flash-Lite  (classification, very low cost)
Tier 1:      Gemini 2.5 Flash       (direct knowledge)
Tier 2:      Gemini 2.5 Flash       (web search)
Tier 3:      Gemini 2.5 Pro         (medical research, highest cost)
Vision:      Gemini 2.5 Flash       (nutrition extraction)
Nutrition:   Gemini 2.5 Pro         (medical-grade analysis)
Image Gen:   Imagen 4.0 Ultra       (recipe photos)
Embedding:   Gemini Embedding 001   (768D, 1536D, or 3072D)
```

### 3. Main Functions & Their Costs

| Function | Model | Token Cost | Image Cost | File | Line |
|----------|-------|-----------|-----------|------|------|
| generateRecipeFromIngredients | Flash | $0.000075/1k input | - | index.ts | 288 |
| generateSpontaneousRecipe | Flash | $0.000075/1k input | - | index.ts | 489 |
| generateRecipePhoto | Imagen | - | ~$0.0025 | index.ts | 728 |
| extractNutritionFromImage | Flash-Vision | $0.000075/1k input | - | index.ts | 882 |
| transcribeMeal | Flash | $0.000075/1k input | - | index.ts | 959 |
| calculateRecipeNutrition | Pro | $0.003/1k input | - | index.ts | 1086 |
| diabetesAssistantStream | Flash/Pro | Variable | - | diabetes-assistant-stream.ts | 1048 |

### 4. Current Logging & Monitoring
- Console logging with emoji prefixes (emoji categories: recipe 🍳, photo 📸, nutrition 🍽️)
- **Partial token tracking** in Tier 3 responses (lines 985-992 of diabetes-assistant-stream.ts)
- **No persistent cost tracking** to database
- **No cost attribution** by user or feature

### 5. Existing Implementation Details

**Token Usage Extraction** (already in code):
```typescript
// Line 985-992 in diabetes-assistant-stream.ts
const usageMetadata = rawResponse?.usageMetadata || (finalResponse as any).usageMetadata;
const outputTokens = usageMetadata?.candidatesTokenCount || 0;
const inputTokens = usageMetadata?.promptTokenCount || 0;
const totalTokens = usageMetadata?.totalTokenCount || 0;
```

**SSE Response Metadata**:
```typescript
tokenUsage: {
  input: inputTokens,
  output: outputTokens,
  total: totalTokens
}
```

### 6. File Structure Summary

**Core Files**:
- `index.ts` (1,146 lines) - Main entry point, 6 functions + 2 flows
- `diabetes-assistant-stream.ts` (49 KB) - Streaming chat with SSE
- `genkit-instance.ts` - Genkit initialization
- `providers.ts` - Model provider abstraction
- `nutrition-extractor.ts` - Direct Gemini API calls

**Flows**:
- `flows/deep-research-v2.ts` - Multi-round medical research orchestration
- `flows/router-flow.ts` - Tier selection

**Tools** (15 files):
- Search: exa-search, pubmed-search, medrxiv-search, clinical-trials
- Processing: query-analyzer, query-refiner, latents-planner, latents-reflector
- Ranking: source-ranker, source-selector, source-deduplicator
- Research: parallel-research-fetcher, stopping-condition-evaluator

**Utilities** (9 files):
- error-logger, rate-limiter, research-helpers, memory-context
- retry-handler, response-cleaner, edamam-parser, ussa-client, statistical-analysis

**Prompts**:
- recipe_chef_assistant.prompt - Recipe generation
- recipe_photo_generation.prompt - Image generation (Imagen)
- recipe_nutrition_calculator.prompt - Nutrition analysis (Pro)
- Memory-aware diabetes assistant prompt

---

## Cost Tracking Gap Analysis

### What's Missing:
1. No persistent cost tracking to Firestore
2. No per-request cost attribution
3. No daily/monthly cost aggregation
4. No budget alerts or limits
5. No cost dashboard/reporting
6. Token extraction incomplete for some functions
7. Image generation costs not tracked

### Where to Add Tracking:
1. **High Priority**: 6 main functions in index.ts
2. **High Priority**: diabetes-assistant-stream.ts (3 tier paths)
3. **High Priority**: nutrition-extractor.ts (direct API)
4. **Medium Priority**: deep-research-v2.ts (planning, reflection, synthesis phases)
5. **Medium Priority**: exa-search.ts (paid external API)
6. **Low Priority**: Research tools and utilities

---

## Recommended Firestore Collections

### 1. `apiUsage/{timestamp}_{function}_{id}`
Track every API call with:
- Function name, model, tier
- Input/output tokens
- Cost (USD)
- Duration, success status
- User ID, metadata

### 2. `costMetrics/{YYYY-MM-DD}`
Daily aggregates:
- Total cost by tier
- Cost by function
- Token counts
- Request counts
- Per-user breakdown

### 3. `costAlerts/{alertId}`
Budget violations:
- Alert type (daily limit, monthly limit, tier3 overuse)
- Current vs. limit amount
- Affected functions

---

## Implementation Roadmap

**Phase 1 (Week 1)**: Foundation
- Create cost-tracker.ts service
- Create cost-tracking.ts types
- Basic console logging

**Phase 2 (Week 2)**: Core Functions
- Instrument all 6 functions in index.ts
- Firestore write setup
- Simple testing

**Phase 3 (Week 3)**: Complex Functions
- Instrument diabetes-assistant-stream.ts (3 tiers)
- Enhance deep-research-v2.ts tracking
- Track Exa API costs

**Phase 4 (Week 4)**: Monitoring
- Cost dashboard endpoint
- Daily aggregation (Cloud Scheduler)
- Budget alert logic
- Reporting tools

---

## Key Model Pricing (Nov 2024)

**Text Models**:
- Flash-Lite/Flash: $0.075/1M input, $0.3/1M output
- Pro: $3/1M input, $12/1M output

**Vision**: Same as text + per-image overhead

**Images**: Imagen 4.0 Ultra ~$0.0025 per 2K image

**Embedding**: $0.00002 per 1K embeddings

**External APIs**: PubMed, MedRxiv, Clinical Trials (free)

---

## Critical Files for Cost Implementation

**Must Modify**:
1. `/functions/src/index.ts` - 6 functions
2. `/functions/src/diabetes-assistant-stream.ts` - streaming chat
3. `/functions/src/nutrition-extractor.ts` - vision API

**Must Create**:
1. `/functions/src/services/cost-tracker.ts` - pricing & calculation
2. `/functions/src/types/cost-tracking.ts` - Firestore schemas
3. `/functions/src/utils/cost-monitor.ts` - budget alerts

**Should Enhance**:
1. `/functions/src/flows/deep-research-v2.ts` - multi-phase tracking
2. `/functions/src/tools/exa-search.ts` - external API costs
3. `/functions/src/utils/error-logger.ts` - ErrorContext type

---

## Quick Reference: Function Locations

```
generateRecipeFromIngredients        →  index.ts:288
generateSpontaneousRecipe            →  index.ts:489
generateRecipePhoto                  →  index.ts:728
extractNutritionFromImage            →  index.ts:882
transcribeMeal                       →  index.ts:959
calculateRecipeNutrition             →  index.ts:1086
diabetesAssistantStream              →  diabetes-assistant-stream.ts:1048

Token extraction (existing)           →  diabetes-assistant-stream.ts:985-992
Rate limiting (existing)             →  utils/rate-limiter.ts
Cost-aware logging (existing)        →  Partial in index.ts, diabetes-assistant-stream.ts
```

---

## Summary Statistics

- **Total TypeScript files in src/**: 28+
- **Total source lines of code**: 30,000+
- **Exported Cloud Functions**: 8
- **Genkit flows defined**: 3+
- **Research tools**: 15+
- **Prompt files**: 4 (+ 3 as TypeScript)
- **Supported providers**: 2 (Google AI, Vertex AI)
- **Supported models**: 8+ different models

---

## Deliverables from This Analysis

1. **Comprehensive cost-tracking-analysis.md** - Architecture overview
2. **Detailed file listing with purposes** - Complete file guide
3. **Implementation points guide** - Exact code locations
4. **Firestore schema designs** - Collections structure
5. **Model pricing reference** - All current pricing
6. **4-week implementation roadmap** - Phased approach

---

## Next Steps

1. Review the cost-tracking-implementation-points.md for exact line numbers
2. Create cost-tracker.ts service with MODEL_PRICING table
3. Start with index.ts functions (6 functions, highest ROI)
4. Integrate with Firestore collections
5. Set up daily aggregation
6. Create monitoring dashboard

---

**All files ready in `/tmp/` for delivery**:
- cost_tracking_report.md (comprehensive analysis)
- detailed_file_listing.md (file structure)
- cost_tracking_implementation_points.md (implementation guide)

