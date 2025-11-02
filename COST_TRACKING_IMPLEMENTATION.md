# Cost Tracking Implementation Points - Quick Reference

## Where to Add Cost Tracking (File-by-File Guide)

### HIGH PRIORITY - Main Function Entry Points

#### 1. `/functions/src/index.ts` (6 functions to instrument)

**Function 1: `generateRecipeFromIngredients` (line 288)**
```
Cost tracking point:
- Capture: Input token count from Genkit
- Capture: Output token count from response
- Model: gemini-2.5-flash
- Calculate: (input_tokens * $0.075/1M) + (output_tokens * $0.3/1M)
- Log to Firestore collection: apiUsage/{timestamp}
```

**Function 2: `generateSpontaneousRecipe` (line 489)**
```
Same as above - uses identical flow
```

**Function 3: `generateRecipePhoto` (line 728)**
```
Cost tracking point:
- Capture: Image generation success/failure
- Model: vertexai/imagen-4.0-ultra-generate-001
- Cost per image: ~$0.0025 (needs verification from Vertex AI pricing)
- Log: image generation cost
```

**Function 4: `extractNutritionFromImage` (line 882)**
```
Cost tracking point:
- Located in nutrition-extractor.ts (see below)
- Model: gemini-2.5-flash (vision)
- Input: Image + prompt tokens
- Output: response tokens
```

**Function 5: `transcribeMeal` (line 959)**
```
Cost tracking point:
- Model: gemini-2.5-flash
- Capture input/output tokens from response
- Associate with meal entry
```

**Function 6: `calculateRecipeNutrition` (line 1086)**
```
Cost tracking point:
- Model: gemini-2.5-pro (highest cost)
- Capture input/output tokens (line 1122)
- Calculate: (input * $3/1M) + (output * $12/1M)
- Log with HIGH cost tier flag
```

---

#### 2. `/functions/src/diabetes-assistant-stream.ts` (Most complex)

**Function: `diabetesAssistantStream` (line 1048)**

**Three tier paths to instrument:**

**Tier 1 Path (Flash-Lite):**
- Location: Around tier 1 response generation
- Model: gemini-2.5-flash-lite
- Cost: VERY LOW
- Add: Token extraction from response

**Tier 2 Path (Flash + Web Search):**
- Location: Around exa search + synthesis
- Model: gemini-2.5-flash
- Cost: LOW
- Add: Token extraction + Exa API call cost tracking

**Tier 3 Path (Pro + Deep Research):**
- Location: Around deep-research-v2 call
- Model: gemini-2.5-pro
- Cost: HIGH (token cost)
- Currently: Partially tracked (lines 985-992)
- Enhance: Full token extraction, categorize by research round

**Token extraction example (already exists):**
```typescript
// Line 985-992 in diabetes-assistant-stream.ts
const outputTokens = usageMetadata?.candidatesTokenCount || 0;
const inputTokens = usageMetadata?.promptTokenCount || 0;
const totalTokens = usageMetadata?.totalTokenCount || 0;
```

---

#### 3. `/functions/src/nutrition-extractor.ts`

**Direct API implementation to track:**
```typescript
// Line 9 area: GoogleGenerativeAI client
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

// Need to add wrapper:
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
const result = await model.generateContent(...);

// Extract usage:
const usage = result.response.usageMetadata;
// Log usage to Firestore
```

---

#### 4. `/functions/src/flows/deep-research-v2.ts`

**Multiple cost tracking points:**

1. **Planning phase (latents-planner call)**
   - Cost: Tier 3 (Pro model)
   - Tokens: Need to capture from planner response

2. **Research fetch rounds (parallel-research-fetcher)**
   - Cost: Multiple API calls (free except Exa)
   - Track: Number of rounds, sources fetched

3. **Reflection phase (latents-reflector call)**
   - Cost: Tier 3 (Pro model)
   - Tokens: Need to capture

4. **Synthesis phase**
   - Cost: Tier 3 (Pro model)
   - Tokens: Need to capture

---

### MEDIUM PRIORITY - Research API Tools

#### 5. `/functions/src/tools/exa-search.ts`
```
Cost tracking:
- API: Exa (paid service)
- Track: Number of queries, results count
- Store: API call metadata
```

#### 6. `/functions/src/tools/parallel-research-fetcher.ts`
```
Cost tracking:
- Calls: exa, pubmed, medrxiv, clinical-trials in parallel
- Track: Total time per source, result count
- Calculate: Cost only for Exa (others free)
```

#### 7. `/functions/src/tools/pubmed-search.ts`
```
Cost tracking:
- API: PubMed (free)
- Track: Number of queries (for usage monitoring)
```

---

### LOW PRIORITY - Utilities & Support

#### 8. `/functions/src/utils/error-logger.ts`

**Enhance ErrorContext to include cost:**
```typescript
interface ErrorContext {
  // existing fields...
  costMetadata?: {
    modelUsed: string;
    tier: 'low' | 'medium' | 'high';
    tokensUsed?: number;
    estimatedCost?: number;
  };
}
```

#### 9. `/functions/src/utils/rate-limiter.ts`

**Current implementation:**
```typescript
// Line: checkTier3RateLimit() exists
// This is already cost-aware (Tier 3 = expensive)
// Enhance to track: How many times limit was hit
```

---

## Firestore Schema Design

### Collection: `apiUsage` (Per-request log)

```typescript
// Document: {timestamp}_{functionName}_{requestId}
{
  timestamp: Timestamp,
  userId: string,
  functionName: string, // 'generateRecipeFromIngredients', etc.
  model: string, // 'gemini-2.5-flash', 'imagen-4.0-ultra', etc.
  tier: string, // 'tier1', 'tier2', 'tier3', 'image', 'nutrition'
  
  // Token usage (for text models)
  tokens: {
    input: number,
    output: number,
    total: number
  },
  
  // Cost calculation
  cost: {
    amount: number, // in USD
    currency: 'USD',
    breakdown?: {
      inputCost: number,
      outputCost: number
    }
  },
  
  // Metadata
  metadata: {
    duration: number, // milliseconds
    success: boolean,
    errorMessage?: string,
    
    // For image generation
    imageCount?: number,
    resolution?: string,
    
    // For research
    sourcesCount?: number,
    roundNumber?: number,
    
    // For recipe
    mealType?: string,
    recipeCount?: number
  },
  
  // For cost tracking
  costTier: 'low' | 'medium' | 'high',
  estimatedMonthly?: number
}
```

### Collection: `costMetrics` (Daily aggregates)

```typescript
// Document: {YYYY-MM-DD}
{
  date: string, // ISO format
  totalCost: number,
  totalTokens: number,
  breakdown: {
    tier1Cost: number,
    tier1Tokens: number,
    tier2Cost: number,
    tier2Tokens: number,
    tier3Cost: number,
    tier3Tokens: number,
    imageCost: number,
    imageCount: number
  },
  byFunction: {
    generateRecipeFromIngredients: { cost, count, tokens },
    generateSpontaneousRecipe: { cost, count, tokens },
    generateRecipePhoto: { cost, count },
    diabetesAssistantStream: { cost, count, tokens },
    extractNutritionFromImage: { cost, count, tokens },
    calculateRecipeNutrition: { cost, count, tokens }
  },
  requestCount: number,
  averageCostPerRequest: number
}
```

### Collection: `costAlerts` (Budget violations)

```typescript
{
  timestamp: Timestamp,
  alertType: 'daily_limit_exceeded' | 'monthly_limit_exceeded' | 'tier3_overuse',
  currentAmount: number,
  limitAmount: number,
  percentage: number, // 150 = 150% of limit
  affectedFunctions: string[]
}
```

---

## Model Pricing Reference (Hardcode in cost-tracker.ts)

```typescript
export const MODEL_PRICING = {
  'gemini-2.5-flash-lite': {
    inputCostPerMillion: 0.075,
    outputCostPerMillion: 0.3
  },
  'gemini-2.5-flash': {
    inputCostPerMillion: 0.075,
    outputCostPerMillion: 0.3
  },
  'gemini-2.5-pro': {
    inputCostPerMillion: 3,
    outputCostPerMillion: 12
  },
  'gemini-embedding-001': {
    costPer1kEmbeddings: 0.00002
  },
  'imagen-4.0-ultra': {
    costPer2kImage: 0.0025, // at 2K resolution
    costPer1kImage: 0.0016
  }
};

export const TIER_COST_MAPPING = {
  tier1: 'gemini-2.5-flash',
  tier2: 'gemini-2.5-flash',
  tier3: 'gemini-2.5-pro',
  router: 'gemini-2.5-flash-lite',
  image: 'imagen-4.0-ultra'
};

export const BUDGET_LIMITS = {
  dailyLimit: process.env.DAILY_COST_LIMIT || '50.00', // USD
  monthlyLimit: process.env.MONTHLY_COST_LIMIT || '1000.00',
  tier3DailyLimit: process.env.TIER3_DAILY_LIMIT || '20.00'
};
```

---

## Implementation Order (Recommended)

### Week 1 - Foundation
1. Create `cost-tracker.ts` service (pricing tables, calculation functions)
2. Create `cost-tracking.ts` type definitions (Firestore schemas)
3. Add simple console logging with cost calculation for index.ts functions

### Week 2 - Basic Integration
4. Wrap all 6 functions in index.ts with cost tracking
5. Add Firestore write to `apiUsage` collection
6. Test with sample requests

### Week 3 - Complex Functions
7. Instrument `diabetes-assistant-stream.ts` (3 tiers)
8. Enhance token extraction from deep-research-v2
9. Track `exa-search.ts` API costs

### Week 4 - Monitoring & Analysis
10. Create `/functions/src/endpoints/getCostMetrics.ts` (cost dashboard endpoint)
11. Add daily aggregation function (Cloud Scheduler triggered)
12. Implement budget alert logic
13. Create sample dashboards/reports

---

## Sample Cost Tracking Code Snippet

```typescript
// In cost-tracker.ts
export async function trackApiUsage(
  functionName: string,
  model: string,
  tokens: { input: number; output: number },
  metadata: any,
  userId?: string
) {
  const pricing = MODEL_PRICING[model];
  if (!pricing) {
    console.warn(`Unknown model for pricing: ${model}`);
    return;
  }

  const inputCost = (tokens.input / 1_000_000) * pricing.inputCostPerMillion;
  const outputCost = (tokens.output / 1_000_000) * pricing.outputCostPerMillion;
  const totalCost = inputCost + outputCost;

  // Log to Firestore
  const db = getFirestore();
  await db.collection('apiUsage').add({
    timestamp: admin.firestore.Timestamp.now(),
    userId: userId || 'anonymous',
    functionName,
    model,
    tokens,
    cost: {
      amount: totalCost,
      currency: 'USD',
      breakdown: { inputCost, outputCost }
    },
    metadata
  });

  console.log(`💰 [COST] ${functionName}: $${totalCost.toFixed(4)}`);
}
```

---

## Testing Strategy

1. **Unit tests** for cost calculation functions
2. **Integration tests** with mock Firestore
3. **End-to-end test** with one real API call per tier
4. **Validation** against actual GCP billing (monthly)

