## PHASE 1: Cost Optimization (Do This First)

### 1.1 Remove Extended Thinking from Tier 1 and Tier 2

**Current Problem:** Extended thinking is enabled for simple tasks that don’t need reasoning.

**Instructions:**

```other
In Tier 1 (Flash Direct) and Tier 2 (Flash + Search):
- Remove the thinking configuration entirely, OR
- Change from "extended" to "basic" with maxThinkingTokens: 2048

Current config:
thinking: { mode: "extended", maxThinkingTokens: 8192 }

New config:
thinking: null
// OR if basic thinking is helpful:
thinking: { mode: "basic", maxThinkingTokens: 2048 }
```

**Expected savings:** ~40% cost reduction on T1 and T2 queries

---

### 1.2 Replace Source Ranking with Embeddings

**Current Problem:** Making 60 separate API calls to rank sources costs $0.006 per query and takes 10+ seconds.

**Instructions:**

```other
Replace the batch ranking system in the source ranking phase with
embedding-based similarity scoring.

Current approach (REMOVE THIS):
- Loop through sources in batches of 10
- Call Flash model to score each batch
- Aggregate scores

New approach (IMPLEMENT THIS):
1. Import Genkit's embed() function
2. Get embedding for the user's question
3. Get embeddings for all source contents (can batch these)
4. Calculate cosine similarity between question embedding and each source embedding
5. Sort sources by similarity score (highest first)
6. Return top 30 sources

Use the text-embedding-004 model (it's fast and cheap).

Remove these parameters from the ranking config:
- temperature: 0.1
- maxOutputTokens: 300
- batchSize: 10

The new ranking should be purely algorithmic (no LLM calls).
```

**Expected savings:** ~$0.006 per T3 query, 5-8 seconds faster

**Example implementation request:**

```typescript
// Replace the rankSourcesByRelevance function with this approach:
async function rankSourcesByEmbedding(query: string, sources: Source[]) {
  // 1. Get query embedding
  const queryEmbedding = await embed(query);

  // 2. Get source embeddings (can batch)
  const sourceEmbeddings = await Promise.all(
    sources.map(s => embed(s.content.substring(0, 2000))) // Limit content length
  );

  // 3. Calculate cosine similarity
  const rankedSources = sources.map((source, i) => ({
    source,
    score: cosineSimilarity(queryEmbedding, sourceEmbeddings[i]) * 100 // Scale to 0-100
  }));

  // 4. Sort by score
  return rankedSources.sort((a, b) => b.score - a.score);
}
```

---

## PHASE 2: Temperature Adjustments

### 2.1 Tier 1 Temperature

**Current:** 0.3
**New:** 0.1

**Reasoning:** Medical facts should be consistent. Allow slight variation for natural language, but keep it deterministic.

```other
Tier 1 (Flash Direct):
temperature: 0.1
```

---

### 2.2 Tier 2 Temperature

**Current:** 0.3
**New:** 0.2

**Reasoning:** Web synthesis benefits from slight creativity in how sources are combined, but medical accuracy matters more than variety.

```other
Tier 2 (Flash + Search):
temperature: 0.2
```

---

### 2.3 Planning Phase Temperature

**Current:** 0.4
**New:** 0.2

**Reasoning:** Research strategies should be consistent. Same question tomorrow shouldn’t randomly plan 2 rounds vs 4 rounds.

```other
Tier 3 Planning (Latents Planner):
temperature: 0.2
```

---

### 2.4 Reflection Phase Temperature

**Current:** 0.2
**New:** 0.2 (no change)

**Reasoning:** Already correct.

```other
Tier 3 Reflection (Latents Reflector):
temperature: 0.2  // Keep this
```

---

### 2.5 Synthesis Phase Temperature

**Current:** 0.2
**New:** 0.15

**Reasoning:** Final medical synthesis should be highly conservative. Accuracy matters more than fluency variation.

```other
Tier 3 Synthesis (Gemini Pro):
temperature: 0.15
```

---

## PHASE 3: Token Budget Adjustments

### 3.1 Tier 1 Token Budget

**Current:** 4096
**New:** 2500

**Reasoning:** Simple questions don’t need 4000 tokens. This allows thorough explanations without being excessive.

```other
Tier 1 (Flash Direct):
maxOutputTokens: 2500
```

---

### 3.2 Tier 2 Token Budget

**Current:** 4096
**New:** 3000

**Reasoning:** T2 answers should be comprehensive but shorter than T3 deep research reports.

```other
Tier 2 (Flash + Search):
maxOutputTokens: 3000
```

---

### 3.3 Planning Phase Token Budget

**Current:** 2048
**New:** 2048 (no change)

**Reasoning:** Already appropriate for structured plan output.

```other
Tier 3 Planning:
maxOutputTokens: 2048  // Keep this
```

---

### 3.4 Reflection Phase Token Budget

**Current:** 1024
**New:** 1024 (no change)

**Reasoning:** Concise reflection doesn’t need more.

```other
Tier 3 Reflection:
maxOutputTokens: 1024  // Keep this
```

---

### 3.5 Synthesis Phase Token Budget

**Current:** 8192
**New:** 8192 (no change)

**Reasoning:** Comprehensive research reports need this space.

```other
Tier 3 Synthesis:
maxOutputTokens: 8192  // Keep this
```

---

## PHASE 4: Thinking Mode Optimization

### 4.1 Tier 1 Thinking Mode

**Current:** Extended (8192 tokens)
**New:** None or Basic (2048 tokens)

```other
Tier 1:
thinking: null
// OR
thinking: { mode: "basic", maxThinkingTokens: 2048 }
```

---

### 4.2 Tier 2 Thinking Mode

**Current:** Extended (8192 tokens)
**New:** None

**Reasoning:** Synthesis doesn’t need reasoning chains. Remove entirely.

```other
Tier 2:
thinking: null
```

---

### 4.3 Planning Thinking Mode

**Current:** Extended (8192 tokens)
**New:** Extended (8192 tokens) - no change

**Reasoning:** Planning needs deep reasoning. Keep this.

```other
Tier 3 Planning:
thinking: { mode: "extended", maxThinkingTokens: 8192 }  // Keep this
```

---

### 4.4 Reflection Thinking Mode

**Current:** Extended (8192 tokens)
**New:** Extended (4096 tokens)

**Reasoning:** Reflection needs reasoning but not as much as planning.

```other
Tier 3 Reflection:
thinking: { mode: "extended", maxThinkingTokens: 4096 }
```

---

### 4.5 Synthesis Thinking Mode

**Current:** None (Pro doesn’t support it)
**New:** None - no change

**Reasoning:** Pro doesn’t support thinking mode yet.

```other
Tier 3 Synthesis:
// No thinking mode available
```

---

## Complete Configuration Summary

Here’s the full spec in one place for easy reference:

```typescript
// TIER 1: Flash Direct (Model Knowledge)
{
  model: 'gemini-flash-latest',
  temperature: 0.1,           // Changed from 0.3
  maxOutputTokens: 2500,      // Changed from 4096
  thinking: null              // Changed from extended 8192
  // OR: thinking: { mode: "basic", maxThinkingTokens: 2048 }
}

// TIER 2: Flash + Search (Web Research)
{
  model: 'gemini-flash-latest',
  temperature: 0.2,           // Changed from 0.3
  maxOutputTokens: 3000,      // Changed from 4096
  thinking: null              // Changed from extended 8192
}

// TIER 3 PLANNING: Latents Planner
{
  model: 'gemini-flash-latest',
  temperature: 0.2,           // Changed from 0.4
  maxOutputTokens: 2048,      // No change
  thinking: {                 // No change
    mode: "extended",
    maxThinkingTokens: 8192
  }
}

// TIER 3 REFLECTION: Latents Reflector
{
  model: 'gemini-flash-latest',
  temperature: 0.2,           // No change
  maxOutputTokens: 1024,      // No change
  thinking: {                 // Reduced from 8192
    mode: "extended",
    maxThinkingTokens: 4096
  }
}

// TIER 3 RANKING: Source Ranker
// REPLACE ENTIRE FUNCTION with embedding-based similarity
// No LLM calls needed
// Use: text-embedding-004 model with cosine similarity

// TIER 3 SYNTHESIS: Gemini Pro
{
  model: 'gemini-pro-latest',
  temperature: 0.15,          // Changed from 0.2
  maxOutputTokens: 8192       // No change
  // No thinking mode (not supported)
}
```

---

## Implementation Instructions for Claude Code

**Step 1: Apply Phase 1 (Cost Optimization)**

```other
Update the following model configurations in the codebase:

1. Find the Tier 1 (getTier1ThinkingModel) configuration
2. Find the Tier 2 (Flash + Search) configuration
3. Find the Source Ranking function (rankSourcesByRelevance)

Apply these changes:
- T1: Remove extended thinking, set temp to 0.1, tokens to 2500
- T2: Remove extended thinking, set temp to 0.2, tokens to 3000
- Ranking: Replace entire function with embedding-based similarity

Show me the files you'll modify before making changes.
```

**Step 2: Apply Phase 2 & 3 (Temperature and Tokens)**

```other
Update remaining temperature and token settings:

Planning: temp 0.2
Reflection: temp 0.2, thinking tokens 4096
Synthesis: temp 0.15

Show me a diff of the changes before applying.
```

**Step 3: Test Each Tier**

```other
After applying changes, test each tier:

T1 test query: "What is LADA diabetes?"
T2 test query: "Latest insulin pump technologies?"
T3 test query: "Should I switch from Lantus to Tresiba?"

Verify:
- T1 and T2 complete faster (no extended thinking overhead)
- T3 ranking completes in <2 seconds (embedding-based)
- All answers maintain quality
- Total cost per T3 query reduced by ~30%
```

---

## Expected Results

### Performance Improvements

- **T1 latency:** 2-3 seconds → 1-2 seconds
- **T2 latency:** 4-6 seconds → 3-4 seconds
- **T3 ranking:** 8-12 seconds → 1-2 seconds
- **T3 total:** 30-45 seconds → 20-35 seconds

### Cost Improvements

- **T1 cost:** $0.000075 → $0.000025 (67% reduction)
- **T2 cost:** $0.003 → $0.001 (67% reduction)
- **T3 cost:** $0.021 → $0.015 (30% reduction)

### Quality

- **No degradation expected** - these are optimizations, not compromises
- Answers should remain accurate and comprehensive
- Streaming experience should feel smoother (faster tokens)
