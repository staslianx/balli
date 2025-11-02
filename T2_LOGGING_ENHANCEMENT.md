# T2 (Web Search) Logging Enhancement

## Overview

T2 now has comprehensive logging and terminal output similar to T3 (Deep Research), making it easy to understand what's happening during web search research queries.

## New SSE Events

### T2-Specific Events

1. **`t2_query_enrichment_started`**
   - Emitted when query enrichment begins
   - Contains user-friendly message in Turkish

2. **`t2_query_enrichment_complete`**
   - Emitted when enrichment finishes
   - Fields:
     - `enrichedQuery`: The enriched search query string
     - `contextUsed`: Boolean indicating if conversation context was used

3. **`t2_source_analysis_started`**
   - Emitted when analyzing fetched sources
   - User-friendly message in Turkish

4. **`t2_source_analysis_complete`**
   - Emitted when source analysis is done
   - Fields:
     - `totalSources`: Total number of sources fetched
     - `breakdown`: Object with source type counts (e.g., `{ exa: 15 }`)

### Enhanced Existing Events

- **`api_started`** - Now includes `query` field showing the actual search query
- **`api_completed`** - Detailed completion info with duration and success status
- **`complete`** - Now includes `stageBreakdown` in metadata showing time spent in each stage

## Terminal Output Structure

### Stage-by-Stage Breakdown

```
╔════════════════════════════════════════════════════════════════════════════╗
║ 🔵 T2: WEB SEARCH RESEARCH PIPELINE                                       ║
╚════════════════════════════════════════════════════════════════════════════╝
📝 [T2] Query: "Metformin yan etkileri neler?"
👤 [T2] User: user123
🧠 [T2-MEMORY] Conversation history: 3 messages
📋 [T2] Profile: Type 1.5 (LADA)

┌─ STAGE 1: MEMORY CONTEXT ─────────────────────────────────────────────────┐
🧠 [T2-MEMORY] Cross-conversation memory loaded:
   • Facts: 12
   • Summaries: 3
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 2: SYSTEM PROMPT ──────────────────────────────────────────────────┐
📝 [T2] System prompt loaded: T2 Web Search
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 3: QUERY ENRICHMENT ───────────────────────────────────────────────┐
🔍 [T2-ENRICHMENT] Original: "yan etkileri"
🔍 [T2-ENRICHMENT] Enriched: "metformin side effects diabetes LADA"
🔍 [T2-ENRICHMENT] Context used: conversation
⏱️  [T2-ENRICHMENT] Duration: 340ms
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 4: SOURCE FETCHING ────────────────────────────────────────────────┐
🌐 [T2-EXA] Starting Exa medical search...
   • Query: "metformin side effects diabetes LADA"
   • Target count: 15 sources

✅ [T2-EXA] Fetch complete:
   • Sources found: 14
   • Duration: 1240ms
   • Success: YES

📚 [T2-EXA] Top 3 sources:
   1. Metformin Safety in Type 1 Diabetes: Comprehensive Review
      URL: https://example.com/article1
      Domain: diabetescare.org
   2. Understanding Metformin Side Effects
      URL: https://example.com/article2
      Domain: mayoclinic.org
   3. LADA and Metformin: What You Need to Know
      URL: https://example.com/article3
      Domain: joslin.org
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 5: SOURCE ANALYSIS ────────────────────────────────────────────────┐
📊 [T2-ANALYSIS] Source breakdown:
   • Total sources: 14
   • Exa web sources: 14
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 6: SYNTHESIS ──────────────────────────────────────────────────────┐
🤖 [T2-SYNTHESIS] Starting AI synthesis...
   • Model: Gemini 2.5 Flash
   • Temperature: 0.2
   • Max tokens: 3000
   • Prompt length: 4521 chars

✅ [T2-SYNTHESIS] Stream completed:
   • Response length: 2847 chars
   • Chunks streamed: 45
   • Estimated tokens: 2892
   • Finish reason: STOP
   • Last 50 chars: "...doktorunuzla görüşmeniz önemlidir."
└───────────────────────────────────────────────────────────────────────────┘

╔════════════════════════════════════════════════════════════════════════════╗
║ ✅ T2: WEB SEARCH RESEARCH COMPLETE                                       ║
╚════════════════════════════════════════════════════════════════════════════╝
📊 [T2-SUMMARY] Performance Metrics:
   • Total duration: 4.8s
   • Query enrichment: 0.34s (7.1%)
   • Exa API fetch: 1.24s (25.8%)
   • Synthesis: 67.1%

📚 [T2-SUMMARY] Sources:
   • Total sources: 14
   • Evidence quality: high
   • Exa medical sources: 14

💬 [T2-SUMMARY] Response:
   • Response length: 2847 chars
   • Token count: ~2892
   • Chunks streamed: 45

🎯 [T2-SUMMARY] Context:
   • Original query: "yan etkileri"
   • Enriched query: "metformin side effects diabetes LADA"
   • Context used: conversation

╚════════════════════════════════════════════════════════════════════════════╝
```

## Comparison: T2 vs T3 Logging

### T2 (Web Search) - 6 Stages
1. **Memory Context** - Cross-conversation memory lookup
2. **System Prompt** - T2-specific prompt loading
3. **Query Enrichment** - Context-aware query expansion
4. **Source Fetching** - Single Exa API call (15 sources)
5. **Source Analysis** - Quick source breakdown
6. **Synthesis** - AI response generation

### T3 (Deep Research) - 8+ Stages
1. **Planning** - Multi-round strategy planning
2. **Round 1** - Initial broad search (multiple APIs)
3. **Reflection** - Gap analysis
4. **Round 2-4** - Gap-targeted searches (if needed)
5. **Source Ranking** - AI-powered relevance scoring
6. **Source Selection** - Top-P intelligent selection
7. **Synthesis Preparation** - Context assembly
8. **Synthesis** - AI response generation

## Key Differences

### T2 Advantages
- **Faster**: 3-5 seconds typical (vs 20-60s for T3)
- **Simpler**: Single search round, no reflection loops
- **Cost-effective**: ~$0.003 per query (vs ~$0.03-0.08 for T3)
- **Predictable**: Consistent 6-stage flow

### T3 Advantages
- **Comprehensive**: 25-60 sources across multiple APIs
- **Adaptive**: Multi-round with gap detection
- **Quality-focused**: AI ranking and intelligent selection
- **Evidence-rich**: Higher quality sources from academic APIs

## Log Levels by Component

### Console Logs (Firebase Cloud Functions)
- `🔵 [T2]` - Main pipeline stages
- `🧠 [T2-MEMORY]` - Memory context operations
- `🔍 [T2-ENRICHMENT]` - Query enrichment details
- `🌐 [T2-EXA]` - Exa API interactions
- `📊 [T2-ANALYSIS]` - Source analysis
- `🤖 [T2-SYNTHESIS]` - AI synthesis operations
- `✅ [T2-SUMMARY]` - Final summary report

### SSE Events (Client-side)
- All events available for real-time UI updates
- Progressive disclosure of research stages
- Detailed metadata for debugging

## CLI Tool Support

The CLI tool can now parse T2 SSE events and display:
- Stage-by-stage progress
- Timing breakdowns
- Source details
- Query enrichment info
- Performance metrics

### Example CLI Output Format

```bash
$ research-xray

📝 Enter your research query:
> yan etkileri

🎯 Router selected: Tier 2 (Web Search)
   Reasoning: Simple query needing current web sources

┌─ Query Enrichment ─────────────────────────────────────────┐
│ Original:  "yan etkileri"                                   │
│ Enriched:  "metformin side effects diabetes LADA"          │
│ Context:   conversation history (3 messages)               │
│ Duration:  340ms                                            │
└─────────────────────────────────────────────────────────────┘

┌─ Source Fetching ──────────────────────────────────────────┐
│ API: Exa                                                    │
│ Query: "metformin side effects diabetes LADA"              │
│ Found: 14 sources                                           │
│ Duration: 1.24s                                             │
│                                                             │
│ Top sources:                                                │
│   1. Metformin Safety in Type 1 Diabetes                   │
│      diabetescare.org                                       │
│   2. Understanding Metformin Side Effects                   │
│      mayoclinic.org                                         │
│   3. LADA and Metformin: What You Need to Know             │
│      joslin.org                                             │
└─────────────────────────────────────────────────────────────┘

┌─ Synthesis ────────────────────────────────────────────────┐
│ Model: Gemini 2.5 Flash                                     │
│ Temperature: 0.2                                            │
│ Response length: 2847 chars                                 │
│ Chunks: 45                                                  │
│ Duration: 3.2s                                              │
└─────────────────────────────────────────────────────────────┘

✅ Complete in 4.8s
   Evidence quality: high
   Total cost: $0.003

💾 Report saved: ./research-logs/20250115_142345_t2.json
```

## JSON Report Format

```json
{
  "tier": 2,
  "query": {
    "original": "yan etkileri",
    "enriched": "metformin side effects diabetes LADA",
    "enrichmentDuration": 340,
    "contextUsed": true
  },
  "sources": {
    "total": 14,
    "breakdown": {
      "exa": 14
    },
    "fetchDuration": 1240,
    "topSources": [
      {
        "title": "Metformin Safety in Type 1 Diabetes",
        "url": "https://example.com/article1",
        "domain": "diabetescare.org"
      }
    ]
  },
  "synthesis": {
    "model": "gemini-2.5-flash",
    "temperature": 0.2,
    "responseLength": 2847,
    "chunks": 45,
    "duration": 3200,
    "finishReason": "STOP"
  },
  "performance": {
    "totalDuration": 4800,
    "stageBreakdown": {
      "enrichment": { "duration": 340, "percentage": 7.1 },
      "fetch": { "duration": 1240, "percentage": 25.8 },
      "synthesis": { "duration": 3220, "percentage": 67.1 }
    }
  },
  "metadata": {
    "evidenceQuality": "high",
    "estimatedCost": 0.003,
    "userId": "user123",
    "timestamp": "2025-01-15T14:23:45Z"
  }
}
```

## Markdown Report Format

````markdown
# T2 Web Search Research Report

**Query**: yan etkileri
**Tier**: 2 (Web Search)
**Date**: 2025-01-15 14:23:45
**Duration**: 4.8s
**Cost**: $0.003

---

## Query Enrichment

- **Original**: "yan etkileri"
- **Enriched**: "metformin side effects diabetes LADA"
- **Context Used**: Conversation history
- **Duration**: 340ms

---

## Source Gathering

### Exa Web Search
- **Query**: "metformin side effects diabetes LADA"
- **Sources Found**: 14
- **Duration**: 1.24s
- **Success**: ✅

#### Top Sources

1. **Metformin Safety in Type 1 Diabetes**
   - Domain: diabetescare.org
   - URL: https://example.com/article1

2. **Understanding Metformin Side Effects**
   - Domain: mayoclinic.org
   - URL: https://example.com/article2

3. **LADA and Metformin: What You Need to Know**
   - Domain: joslin.org
   - URL: https://example.com/article3

---

## Synthesis

- **Model**: Gemini 2.5 Flash
- **Temperature**: 0.2
- **Response Length**: 2,847 characters
- **Chunks Streamed**: 45
- **Duration**: 3.2s
- **Finish Reason**: STOP

---

## Performance Summary

| Stage | Duration | Percentage |
|-------|----------|------------|
| Query Enrichment | 340ms | 7.1% |
| Source Fetching | 1,240ms | 25.8% |
| AI Synthesis | 3,220ms | 67.1% |
| **Total** | **4,800ms** | **100%** |

---

## Quality Metrics

- **Evidence Quality**: High
- **Total Sources**: 14
- **Exa Medical Sources**: 14
- **Estimated Cost**: $0.003

---
````

## Next Steps

1. ✅ Enhanced SSE events for T2
2. ✅ Comprehensive console logging
3. ⏳ Update CLI tool to parse T2 events
4. ⏳ Add JSON/MD report generation to CLI
5. ⏳ Test with sample queries

## Testing

To test T2 enhanced logging:

```bash
# From CLI tool
$ research-xray
> [enter a T2-appropriate query like "metformin yan etkileri"]

# Verify:
# 1. All 6 stages appear in terminal
# 2. Performance breakdown is accurate
# 3. Source details are shown
# 4. Summary includes all metrics
```

## Benefits

1. **Debugging**: Clear visibility into each stage
2. **Performance**: Easy to identify bottlenecks
3. **Cost tracking**: Track enrichment, fetch, and synthesis costs
4. **Quality assessment**: Evidence quality scoring visible
5. **User feedback**: SSE events enable real-time UI updates
6. **Monitoring**: Production logs are now actionable
7. **Comparability**: T2 and T3 now have similar logging structures
