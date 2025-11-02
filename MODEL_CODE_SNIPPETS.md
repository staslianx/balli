# Model Usage - Actual Code Snippets

This document shows the **actual code** where each Gemini model is used.

---

## 🎯 Model Configuration (`providers.ts`)

### Model Definition

```typescript
// functions/src/providers.ts:73-108

export function getModelReferences(): ModelReference {
  const useVertexAI = process.env.USE_VERTEX_AI === 'true';
  const embeddingDimensions = getEmbeddingDimensions();

  if (useVertexAI) {
    // Vertex AI - use Gemini 2.5 models
    return {
      chat: 'vertexai/gemini-2.5-flash',
      summary: 'vertexai/gemini-2.5-flash',
      embedder: vertexAI.embedder('gemini-embedding-001', {
        outputDimensionality: embeddingDimensions
      }),
      classifier: 'vertexai/gemini-2.5-flash',
      router: 'vertexai/gemini-2.5-flash-lite', // ← ROUTER MODEL (Fast/Cheap)
      tier1: 'vertexai/gemini-2.5-flash',       // ← T1 MODEL
      tier2: 'vertexai/gemini-2.5-flash',       // ← T2 MODEL
      tier3: 'vertexai/gemini-2.5-pro'          // ← T3 MODEL
    };
  } else {
    // Google AI - use stable model names
    return {
      chat: 'googleai/gemini-2.5-flash',
      summary: 'googleai/gemini-2.5-flash',
      embedder: googleAI.embedder('gemini-embedding-001', {
        outputDimensionality: embeddingDimensions
      }),
      classifier: 'googleai/gemini-2.5-flash',
      router: 'googleai/gemini-2.5-flash-lite', // ← ROUTER MODEL (Fast/Cheap)
      tier1: 'googleai/gemini-2.5-flash',       // ← T1 MODEL
      tier2: 'googleai/gemini-2.5-flash',       // ← T2 MODEL
      tier3: 'googleai/gemini-2.5-pro'          // ← T3 MODEL
    };
  }
}
```

**Key Point**: We use **DIFFERENT models for routing vs processing**:
- **Router**: `gemini-2.5-flash-lite` (fastest, cheapest for classification)
- **T1/T2**: `gemini-2.5-flash` (fast, good quality)
- **T3**: `gemini-2.5-pro` (best quality, slower)

---

## 🔀 Router (Tier Selection)

### Model: `gemini-2.5-flash-lite`

```typescript
// functions/src/flows/router-flow.ts:~100

const response = await ai.generate({
  model: getRouterModel(), // ← gemini-2.5-flash-lite
  config: {
    temperature: 0.1, // Very low for consistent classification
    maxOutputTokens: 256
  },
  system: SYSTEM_PROMPT,
  prompt: userPrompt
});
```

**Why Flash Lite?**
- ✅ 50% cheaper than regular Flash
- ✅ 2-3x faster (200-300ms)
- ✅ Good enough for simple classification
- ✅ Only needs to output: `{ tier: 1 | 2 | 3, reasoning: string }`

**CLI Display**: This is why your CLI shows "Gemini 2.0 Flash Lite" - it's showing the router's model during tier selection!

---

## 📊 Tier 1: Direct Model Response

### Model: `gemini-2.5-flash`

```typescript
// functions/src/diabetes-assistant-stream.ts:246-264

const { stream, response } = await ai.generateStream({
  model: getTier1Model(), // ← gemini-2.5-flash
  system: systemPrompt,
  prompt: prompt,
  config: {
    temperature: 0.1,
    maxOutputTokens: 2500,
    thinkingConfig: {
      thinkingBudget: 0 // Thinking disabled for cost
    },
    safetySettings: [
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
    ]
  }
});
```

**Usage**:
- Simple diabetes questions
- General knowledge from training data
- No research needed
- Fast: 1-2 seconds

---

## 🔍 Tier 2: Web Search

### Model: `gemini-2.5-flash`

```typescript
// functions/src/diabetes-assistant-stream.ts:431-449

const result = await ai.generateStream({
  model: getTier2Model(), // ← gemini-2.5-flash
  system: systemPrompt,
  prompt: userPrompt,
  config: {
    temperature: 0.2,
    maxOutputTokens: 3000,
    // No thinking config (thinking disabled for cost)
    safetySettings: [
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
    ]
  }
});
```

**Usage**:
- Questions needing current information
- After Exa search (15 web sources)
- Synthesizes web search results
- Medium: 3-5 seconds

---

## 🔬 Tier 3: Deep Research

### Model: `gemini-2.5-pro`

```typescript
// functions/src/diabetes-assistant-stream.ts:666-681

const { stream, response } = await ai.generateStream({
  model: getTier3Model(), // ← gemini-2.5-pro
  system: systemPrompt,
  prompt: userPrompt,
  config: {
    temperature: 0.15,
    maxOutputTokens: 12000, // Much larger output for comprehensive responses
    safetySettings: [
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
    ]
  }
});
```

**Usage**:
- Explicit deep research requests
- After multi-round research (25-60 sources)
- Complex synthesis requiring reasoning
- Slow: 20-60 seconds
- Expensive: Uses Pro model ($2.50/$10 per 1M tokens)

---

## 🧠 T3 Planning & Reflection (Latents Mode)

### Planner Model: `gemini-2.5-pro` with thinking

```typescript
// functions/src/tools/latents-planner.ts:~50

const result = await ai.generate({
  model: 'googleai/gemini-2.5-pro', // Hard-coded Pro for quality
  config: {
    temperature: 1.0, // Higher for creative planning
    maxOutputTokens: 500,
    thinkingConfig: {
      thinkingBudget: 16000 // ← EXTENDED THINKING ENABLED
    }
  },
  prompt: planningPrompt
});
```

### Reflector Model: `gemini-2.5-pro` with thinking

```typescript
// functions/src/tools/latents-reflector.ts:~70

const result = await ai.generate({
  model: 'googleai/gemini-2.5-pro', // Hard-coded Pro for quality
  config: {
    temperature: 1.0,
    maxOutputTokens: 600,
    thinkingConfig: {
      thinkingBudget: 16000 // ← EXTENDED THINKING ENABLED
    }
  },
  prompt: reflectionPrompt
});
```

**Why Thinking Mode Here?**
- ✅ Planning research strategy requires reasoning
- ✅ Gap analysis needs deep thinking
- ✅ Only used 2-4 times per T3 query (acceptable cost)
- ✅ Dramatically improves research quality

**Why NOT in T1/T2?**
- ❌ Adds $0.02-0.05 per query
- ❌ Slower (adds 1-2 seconds)
- ❌ Unnecessary for simple queries
- ❌ Cost optimization: disabled Jan 2025

---

## 🔍 Query Analysis (T2 & T3)

### Query Enricher Model: `gemini-2.5-flash`

```typescript
// functions/src/tools/query-enricher.ts:~60

const result = await ai.generate({
  model: 'googleai/gemini-2.5-flash',
  config: {
    temperature: 0.0, // Deterministic enrichment
    maxOutputTokens: 150
  },
  prompt: enrichmentPrompt
});
```

**Usage**:
- Takes vague queries like "yan etkileri" (side effects)
- Adds context: "metformin side effects diabetes LADA"
- Uses conversation history and user profile
- Fast: ~300-400ms

### Query Refiner Model: `gemini-2.5-flash`

```typescript
// functions/src/tools/query-refiner.ts:~50

const result = await ai.generate({
  model: 'googleai/gemini-2.5-flash',
  config: {
    temperature: 0.0,
    maxOutputTokens: 200
  },
  prompt: refinementPrompt
});
```

**Usage** (T3 only):
- After Round 1, finds gaps
- Refines query to target missing information
- Example: "metformin cardiovascular effects long-term"
- Used in Rounds 2-4

---

## 🎯 Source Ranking (T3 only)

### Model: `gemini-2.5-flash`

```typescript
// functions/src/tools/source-ranker.ts:~80

const result = await ai.generate({
  model: 'googleai/gemini-2.5-flash',
  config: {
    temperature: 0.0, // Deterministic scoring
    maxOutputTokens: 1000
  },
  prompt: rankingPrompt
});
```

**Usage**:
- Scores 25-60 sources by relevance
- Returns: `{ source_id: relevance_score_0_to_100 }`
- Enables intelligent source selection
- Fast: ~800-1000ms for 50 sources

---

## 📊 Complete Flow Example

### T2 Query: "Metformin yan etkileri"

```
1. ROUTER (gemini-2.5-flash-lite)
   ↓ "This is T2 - needs web search"

2. ENRICHER (gemini-2.5-flash)
   ↓ "metformin side effects diabetes LADA"

3. EXA API (not a model - external search)
   ↓ 15 web sources from trusted medical domains

4. SYNTHESIS (gemini-2.5-flash)
   ↓ Comprehensive response with citations
```

**Models Used**: 3 Gemini calls
- 1x Flash Lite (router)
- 2x Flash (enricher + synthesis)

**Cost**: ~$0.003
**Duration**: 3-5 seconds

---

### T3 Query: "Metformin yan etkileri derinlemesine araştır"

```
1. ROUTER (gemini-2.5-flash-lite)
   ↓ "Explicit deep research request - T3"

2. PLANNER (gemini-2.5-pro + thinking 16K tokens)
   ↓ ResearchPlan: 2 rounds, focus [side effects, safety]

3. ENRICHER (gemini-2.5-flash)
   ↓ "metformin side effects safety profile diabetes"

4. ROUND 1: Fetch 25 sources
   - Exa: 10 sources
   - PubMed: 10 sources
   - medRxiv: 2 sources
   - ClinicalTrials: 3 sources

5. REFLECTOR (gemini-2.5-pro + thinking 16K tokens)
   ↓ Gap identified: "cardiovascular effects missing"

6. REFINER (gemini-2.5-flash)
   ↓ "metformin cardiovascular effects long-term"

7. ROUND 2: Fetch 15 more sources
   - Exa: 5 sources
   - PubMed: 4 sources
   - medRxiv: 2 sources
   - ClinicalTrials: 4 sources

8. RANKER (gemini-2.5-flash)
   ↓ Score all 40 sources by relevance

9. SELECTOR (algorithm, not a model)
   ↓ Top 25 sources selected

10. SYNTHESIS (gemini-2.5-pro)
    ↓ Comprehensive response with 25 sources
```

**Models Used**: 7 Gemini calls
- 1x Flash Lite (router)
- 4x Flash (enricher, refiner, ranker, planner helper)
- 2x Pro with thinking (planner, reflector)
- 1x Pro (final synthesis)

**Cost**: ~$0.03-0.08
**Duration**: 20-60 seconds

---

## 🎨 Recipe Image Generation

### Model: `imagen-3.0-generate-001`

```typescript
// functions/src/flows/recipe-ai.ts:~200

const imageRequest = {
  prompt: imagePrompt,
  number_of_images: 1,
  aspect_ratio: '1:1', // Square images for recipes
  safety_filter_level: 'block_medium_and_above',
  person_generation: 'allow_adult'
};

const [response] = await imagenModel.generateImages(imageRequest);
```

**Usage**:
- Generates recipe images
- Turkish food photography style
- 1024x1024 resolution
- $0.04 per image

---

## 🏷️ Summary Table

| Component | Model | Cost (per 1M tokens) | Speed | Thinking |
|-----------|-------|---------------------|-------|----------|
| **Router** | `gemini-2.5-flash-lite` | $0.075 / $0.30 | 200-300ms | ❌ |
| **T1 Synthesis** | `gemini-2.5-flash` | $0.15 / $0.60 | 1-2s | ❌ |
| **T2 Enricher** | `gemini-2.5-flash` | $0.15 / $0.60 | 300-400ms | ❌ |
| **T2 Synthesis** | `gemini-2.5-flash` | $0.15 / $0.60 | 3-5s | ❌ |
| **T3 Planner** | `gemini-2.5-pro` | $2.50 / $10.00 | 2-3s | ✅ 16K |
| **T3 Enricher** | `gemini-2.5-flash` | $0.15 / $0.60 | 300-400ms | ❌ |
| **T3 Reflector** | `gemini-2.5-pro` | $2.50 / $10.00 | 2-3s | ✅ 16K |
| **T3 Refiner** | `gemini-2.5-flash` | $0.15 / $0.60 | 400-500ms | ❌ |
| **T3 Ranker** | `gemini-2.5-flash` | $0.15 / $0.60 | 800-1000ms | ❌ |
| **T3 Synthesis** | `gemini-2.5-pro` | $2.50 / $10.00 | 10-20s | ❌ |
| **Recipe Images** | `imagen-3.0` | $0.04/image | 3-5s | N/A |

---

## ❓ FAQ

### Q: Why does the CLI show "Gemini 2.0 Flash Lite"?

**A**: The CLI is showing the **router's model** (`gemini-2.5-flash-lite`). This is correct! The router uses Flash Lite to quickly decide which tier to use, then that tier uses its own model:
- T1 uses `gemini-2.5-flash`
- T2 uses `gemini-2.5-flash`
- T3 uses `gemini-2.5-pro`

### Q: Why use different models for router vs processing?

**A**: Cost and speed optimization:
- **Router**: Just needs to classify query → Use cheapest/fastest (Flash Lite)
- **Processing**: Needs quality synthesis → Use appropriate model (Flash or Pro)

### Q: Why is thinking disabled in T1/T2?

**A**: Cost optimization (Jan 2025):
- Thinking adds $0.02-0.05 per query
- Not needed for simple queries (T1) or web synthesis (T2)
- Still enabled in T3 planning/reflection where it's valuable

### Q: Can I change which models are used?

**A**: Yes! Edit `functions/src/providers.ts` and change the model references:

```typescript
// Line 86-89 (or 102-105 for Google AI)
router: 'vertexai/gemini-2.5-flash-lite',  // Change this
tier1: 'vertexai/gemini-2.5-flash',        // Change this
tier2: 'vertexai/gemini-2.5-flash',        // Change this
tier3: 'vertexai/gemini-2.5-pro'           // Change this
```

Then rebuild: `npm run build`
