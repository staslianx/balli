# T2 Complete Terminal Output Example

## Query: "Metformin yan etkileri"

This shows the **complete terminal output** you'll see when running a T2 (Web Search) query through the CLI tool or viewing Cloud Functions logs.

---

```
╔════════════════════════════════════════════════════════════════════════════╗
║ 🔵 T2: WEB SEARCH RESEARCH PIPELINE                                       ║
╚════════════════════════════════════════════════════════════════════════════╝
📝 [T2] Query: "Metformin yan etkileri"
👤 [T2] User: user_abc123
🧠 [T2-MEMORY] Conversation history: 3 messages
📋 [T2] Profile: Type 1.5 (LADA)

┌─ STAGE 1: MEMORY CONTEXT ─────────────────────────────────────────────────┐
🧠 [T2-MEMORY] Cross-conversation memory loaded:
   • Facts: 8
   • Summaries: 2
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 2: SYSTEM PROMPT ──────────────────────────────────────────────────┐
📝 [T2] System prompt loaded: T2 Web Search
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 3: QUERY ENRICHMENT ───────────────────────────────────────────────┐
🔍 [T2-ENRICHMENT] Original: "Metformin yan etkileri"
🔍 [T2-ENRICHMENT] Enriched: "metformin side effects diabetes LADA management"
🔍 [T2-ENRICHMENT] Context used: conversation
⏱️  [T2-ENRICHMENT] Duration: 420ms
└───────────────────────────────────────────────────────────────────────────┘

┌─ STAGE 4: SOURCE FETCHING ────────────────────────────────────────────────┐
🌐 [T2-EXA] Starting Exa medical search...
   • Query: "metformin side effects diabetes LADA management"
   • Target count: 15 sources

┌─ EXA MEDICAL SEARCH ──────────────────────────────────────────────────────┐
🏥 [EXA-MEDICAL] Starting search...
   • Query: "metformin side effects diabetes LADA management"
   • Target results: 15
   • Search type: Neural (semantic)
   • Trusted domains: 18 domains
   • Text extraction: 500 chars max
   • Highlights: 3 sentences per result

✅ [EXA-MEDICAL] Search complete:
   • Results found: 14
   • Duration: 1340ms

📊 [EXA-MEDICAL] Source credibility breakdown:
   • Medical institutions ⭐⭐⭐: 5
   • Peer-reviewed ⭐⭐: 7
   • Expert-authored ⭐: 2

📚 [EXA-MEDICAL] Top results:
   1. Metformin Safety and Efficacy in LADA: A Comprehensive Review
      Domain: diabetes.org | Credibility: Peer-Reviewed ⭐⭐
      Published: 2024-03-15
   2. Managing Side Effects of Metformin in Type 1 Diabetes
      Domain: joslin.org | Credibility: Peer-Reviewed ⭐⭐
      Published: 2023-11-20
   3. Gastrointestinal Side Effects of Metformin: What Patients Need to Know
      Domain: mayoclinic.org | Credibility: Medical Institution ⭐⭐⭐
   4. Metformin and Vitamin B12 Deficiency: Evidence and Recommendations
      Domain: nih.gov | Credibility: Medical Institution ⭐⭐⭐
      Published: 2024-01-10
   5. Long-term Metformin Use in LADA: Benefits and Risks
      Domain: diabetesjournals.org | Credibility: Peer-Reviewed ⭐⭐
      Published: 2023-09-05
└───────────────────────────────────────────────────────────────────────────┘

✅ [T2-EXA] Fetch complete:
   • Sources found: 14
   • Duration: 1340ms
   • Success: YES

📚 [T2-EXA] Top 3 sources:
   1. Metformin Safety and Efficacy in LADA: A Comprehensive Review
      URL: https://diabetes.org/research/metformin-lada-review-2024
      Domain: diabetes.org
   2. Managing Side Effects of Metformin in Type 1 Diabetes
      URL: https://joslin.org/patient-care/diabetes-education/managing-metformin-side-effects
      Domain: joslin.org
   3. Gastrointestinal Side Effects of Metformin: What Patients Need to Know
      URL: https://mayoclinic.org/drugs-supplements/metformin/side-effects
      Domain: mayoclinic.org
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
   • Prompt length: 5847 chars

🔍 [T2-CHUNK-1] Length: 45, Starts: "Metformin, tip 2 diyabe", Ends: " yaygın kullanılan bir i"
📤 [T2-WORD] Sending: "Metformin,·" (length: 11)
📤 [T2-WORD] Sending: "tip·" (length: 4)
📤 [T2-WORD] Sending: "2·" (length: 2)
... [streaming continues] ...

✅ [T2-SYNTHESIS] Stream completed:
   • Response length: 3124 chars
   • Chunks streamed: 58
   • Estimated tokens: 3180
   • Finish reason: STOP
   • Last 50 chars: "doktorunuzla düzenli olarak görüşmeniz önemlidir."
└───────────────────────────────────────────────────────────────────────────┘

╔════════════════════════════════════════════════════════════════════════════╗
║ ✅ T2: WEB SEARCH RESEARCH COMPLETE                                       ║
╚════════════════════════════════════════════════════════════════════════════╝
📊 [T2-SUMMARY] Performance Metrics:
   • Total duration: 5.2s
   • Query enrichment: 0.42s (8.1%)
   • Exa API fetch: 1.34s (25.8%)
   • Synthesis: 66.1%

📚 [T2-SUMMARY] Sources:
   • Total sources: 14
   • Evidence quality: high
   • Exa medical sources: 14

💬 [T2-SUMMARY] Response:
   • Response length: 3124 chars
   • Token count: ~3180
   • Chunks streamed: 58

🎯 [T2-SUMMARY] Context:
   • Original query: "Metformin yan etkileri"
   • Enriched query: "metformin side effects diabetes LADA management"
   • Context used: conversation

╚════════════════════════════════════════════════════════════════════════════╝
```

---

## What You Can See Now

### 1. **Exa Search Details** (NEW!)
- **Configuration**: Neural search, 18 trusted domains, 500 char extraction
- **Timing**: Exact duration (1340ms in this example)
- **Credibility breakdown**: How many ⭐⭐⭐ vs ⭐⭐ vs ⭐ sources
- **Top 5 results**: Title, domain, credibility, publish date

### 2. **Query Enrichment Details**
- Original query vs enriched query
- Context source (conversation, profile, or none)
- Exact timing (420ms)

### 3. **Source Analysis**
- Total sources fetched
- Breakdown by type (Exa only for T2)

### 4. **Synthesis Details**
- Model configuration
- Prompt length
- Every chunk logged during streaming
- Final response stats (length, tokens, chunks)

### 5. **Performance Summary**
- Stage-by-stage timing with percentages
- Evidence quality assessment
- Context usage summary

---

## Comparison: T2 vs T3 Terminal Output

### T2 (Web Search) - Simpler but Detailed

**Stages**: 6 stages, linear flow
- Memory context
- System prompt
- Query enrichment
- **Single Exa search** (15 sources from 18 trusted domains)
- Source analysis
- Synthesis

**Key Features**:
- ✅ Credibility breakdown (⭐⭐⭐/⭐⭐/⭐)
- ✅ Top 5 source details
- ✅ Exact timing per stage
- ✅ Query enrichment visibility

**Duration**: 3-5 seconds
**Cost**: ~$0.003

---

### T3 (Deep Research) - More Complex

**Stages**: 8+ stages, adaptive flow
- Planning (Latents AI)
- Round 1: Initial broad search
  - **PubMed** (10-18 sources)
  - **medRxiv** (2-5 sources)
  - **Clinical Trials** (3-8 sources)
  - **Exa** (10 sources)
- Reflection (Latents AI analyzing gaps)
- Rounds 2-4: Gap-targeted searches (if needed)
  - **PubMed** refined queries
  - **medRxiv** specific topics
  - **Clinical Trials** targeted searches
  - **Exa** follow-up
- Source ranking (AI-powered relevance)
- Source selection (Top-P strategy)
- Synthesis preparation
- Synthesis (Gemini Pro)

**Key Features**:
- ✅ Multi-API parallel fetching
- ✅ Gap detection and adaptive search
- ✅ AI-powered source ranking
- ✅ Intelligent source selection
- ✅ Per-API timing and success rates

**Duration**: 20-60 seconds
**Cost**: ~$0.03-0.08

---

## Why T2 Doesn't Have "Multiple API Calls"

T2 is **deliberately simple and fast**:
- **Single API**: Only Exa (web search)
- **Single round**: No multi-round research
- **No reflection**: No gap analysis
- **No ranking**: Sources used as-is
- **Flash model**: Gemini 2.5 Flash (fast, cheap)

This design makes T2:
- ⚡ **90% faster** than T3
- 💰 **95% cheaper** than T3
- 🎯 **Perfect for**: Quick questions, current info, general queries

T3 is for deep research requiring:
- 📚 Academic papers (PubMed, medRxiv)
- 🏥 Clinical trials data
- 🔬 Multi-source verification
- 🧠 AI-driven quality control

---

## JSON Output Format (T2)

```json
{
  "tier": 2,
  "query": {
    "original": "Metformin yan etkileri",
    "enriched": "metformin side effects diabetes LADA management",
    "enrichmentDuration": 420,
    "contextUsed": true
  },
  "exaSearch": {
    "configuration": {
      "searchType": "neural",
      "targetResults": 15,
      "trustedDomains": 18,
      "textExtraction": "500 chars max",
      "highlights": "3 sentences per result"
    },
    "results": {
      "found": 14,
      "duration": 1340,
      "credibilityBreakdown": {
        "medical_institution": 5,
        "peer_reviewed": 7,
        "expert_authored": 2,
        "general": 0
      }
    },
    "topSources": [
      {
        "title": "Metformin Safety and Efficacy in LADA: A Comprehensive Review",
        "domain": "diabetes.org",
        "credibility": "peer_reviewed",
        "publishedDate": "2024-03-15",
        "url": "https://diabetes.org/research/metformin-lada-review-2024"
      },
      {
        "title": "Managing Side Effects of Metformin in Type 1 Diabetes",
        "domain": "joslin.org",
        "credibility": "peer_reviewed",
        "publishedDate": "2023-11-20",
        "url": "https://joslin.org/patient-care/diabetes-education/managing-metformin-side-effects"
      }
    ]
  },
  "synthesis": {
    "model": "gemini-2.5-flash",
    "temperature": 0.2,
    "responseLength": 3124,
    "chunks": 58,
    "estimatedTokens": 3180,
    "duration": 3440,
    "finishReason": "STOP"
  },
  "performance": {
    "totalDuration": 5200,
    "stageBreakdown": {
      "enrichment": { "duration": 420, "percentage": 8.1 },
      "exaFetch": { "duration": 1340, "percentage": 25.8 },
      "synthesis": { "duration": 3440, "percentage": 66.1 }
    }
  },
  "metadata": {
    "evidenceQuality": "high",
    "estimatedCost": 0.003,
    "userId": "user_abc123",
    "timestamp": "2025-01-15T14:23:45Z"
  }
}
```

---

## CLI Tool Display

When you run the CLI tool, you'll see:

```bash
$ research-xray

📝 Enter your research query:
> Metformin yan etkileri

🎯 Router selected: Tier 2 (Web Search)
   Confidence: 0.85
   Reasoning: "Query seeks current side effect information, best served by web search"

═══════════════════════════════════════════════════════════════

⏱️  STAGE 1: Memory Context (45ms)
   ✓ Loaded 8 facts, 2 summaries from past conversations

⏱️  STAGE 2: System Prompt (5ms)
   ✓ T2 Web Search prompt loaded

⏱️  STAGE 3: Query Enrichment (420ms)
   Original:  "Metformin yan etkileri"
   Enriched:  "metformin side effects diabetes LADA management"
   Context:   conversation (3 prior messages)

⏱️  STAGE 4: Exa Medical Search (1340ms)
   Configuration:
     • Neural semantic search
     • 18 trusted medical domains
     • 500 char text extraction
     • 3 sentence highlights

   Results: 14 sources found
   Credibility:
     ⭐⭐⭐ Medical institutions: 5
     ⭐⭐  Peer-reviewed:        7
     ⭐   Expert-authored:      2

   Top 3:
     1. Metformin Safety and Efficacy in LADA
        diabetes.org • 2024-03-15
     2. Managing Side Effects of Metformin
        joslin.org • 2023-11-20
     3. GI Side Effects: What Patients Need to Know
        mayoclinic.org

⏱️  STAGE 5: Source Analysis (35ms)
   ✓ 14 total sources analyzed

⏱️  STAGE 6: AI Synthesis (3440ms)
   Model: Gemini 2.5 Flash
   Temperature: 0.2
   Response: 3,124 chars (58 chunks)

   [Streaming response shown here...]

═══════════════════════════════════════════════════════════════

✅ Research Complete in 5.2s

📊 Performance:
   Enrichment:  420ms (8%)
   Exa Fetch:   1340ms (26%)
   Synthesis:   3440ms (66%)

📚 Quality:
   Evidence: High
   Sources: 14 (all from trusted medical domains)
   Credibility: 86% highly credible (⭐⭐⭐ or ⭐⭐)

💰 Cost: $0.003

💾 Report saved:
   ./research-logs/20250115_142345_t2.json
   ./research-logs/20250115_142345_t2.md

Commands:
  [v] View full response
  [s] Show all 14 sources
  [r] Run another query
  [q] Quit
```

---

## Summary

**T2 now has comprehensive logging showing**:
- ✅ Exa API configuration details (neural search, trusted domains)
- ✅ Credibility breakdown of sources (⭐⭐⭐/⭐⭐/⭐)
- ✅ Top 5 source details with domains and dates
- ✅ Exact timing for each stage
- ✅ Query enrichment process
- ✅ Synthesis streaming details
- ✅ Performance summary with percentages

**What makes T2 different from T3**:
- T2 uses **1 API** (Exa) vs T3's **4 APIs** (PubMed, medRxiv, Clinical Trials, Exa)
- T2 is **single-round** vs T3's **multi-round with reflection**
- T2 is **90% faster and 95% cheaper**
- T2 is for **quick, current info** vs T3's **deep academic research**

Both now have equivalent logging quality! 🎉
