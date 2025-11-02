```typescript
# Deep Research Observatory CLI Tool - System Prompt

You are building a CLI tool called "research-xray" that provides complete observability into Balli's deep research flow. The tool shows the journey from user query to final response with beautiful formatting, detailed insights, and debugging capabilities.

## Core Purpose

Create an X-ray view of the entire research pipeline that helps developers:
1. Debug source quality and selection
2. Verify citation authenticity
3. Understand routing decisions
4. Analyze cost and token usage
5. Inspect API call patterns
6. Validate gap detection logic
7. Track multi-round reasoning

## CLI Tool Specification

### User Experience Flow

```bash
$ research-xray

┌─────────────────────────────────────────────────────────────┐
│  🔬 Deep Research Observatory                                │
│  Balli Research Pipeline X-Ray Tool                         │
└─────────────────────────────────────────────────────────────┘

📝 Enter your research query (Turkish):
> Metformin yan etkileri derinlemesine araştır

🎯 Starting research journey...
```

### Visual Design Principles

**Color Palette:**

- 🔵 Blue: System stages (Router, Planner, Synthesizer)
- 🟢 Green: Success states (API calls successful, sources found)
- 🟡 Yellow: Decisions and reasoning (Gap detection, ranking logic)
- 🔴 Red: Errors or warnings (Failed calls, low quality sources)
- 🟣 Purple: Cost and metrics (Tokens, pricing, latency)
- ⚪ Gray: Metadata (Timestamps, IDs, technical details)
- 🟠 Orange: User input/output boundaries

**Visual Elements:**

- Use box drawing characters for sections: ┌─┐└─┘│─
- Progress bars for multi-step processes
- Tree views for hierarchical data (source rankings)
- Tables for structured comparisons
- Indentation for nested reasoning
- Icons/emojis for quick visual scanning

### Stage-by-Stage Breakdown

#### Stage 1: Query Input & Analysis

```
┌─ 📥 QUERY INPUT ─────────────────────────────────────────────┐
│ Query: "Metformin yan etkileri derinlemesine araştır"       │
│ Language: Turkish                                            │
│ Length: 48 chars                                             │
│ Timestamp: 2025-01-15 14:23:45                              │
└──────────────────────────────────────────────────────────────┘

┌─ 🧠 QUERY ANALYSIS ──────────────────────────────────────────┐
│ Model: gemini-2.0-flash-lite                                 │
│ Temperature: 0.0                                             │
│                                                               │
│ Detected Patterns:                                           │
│   ✓ Contains "derinlemesine araştır" → Deep research signal │
│   ✓ Medical topic (Metformin)                               │
│   ✓ Side effects focus                                      │
│                                                               │
│ Query Classification:                                        │
│   Category: drug_safety                                      │
│   Complexity: high                                           │
│   Requires: Multiple authoritative sources                   │
│                                                               │
│ 🟣 Tokens: 45 input | 120 output                            │
│ 🟣 Cost: $0.000008                                           │
│ ⏱️  Latency: 340ms                                           │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 2: Router Decision

```
┌─ 🎯 ROUTER DECISION ─────────────────────────────────────────┐
│ Model: gemini-2.0-flash-lite                                 │
│                                                               │
│ Tier Analysis:                                               │
│   Tier 0 (Recall): ❌ No past reference patterns            │
│   Tier 1 (Model): ❌ Explicit "araştır" keyword present     │
│   Tier 2 (Hybrid): ❌ Has "derinlemesine" modifier          │
│   Tier 3 (Deep): ✅ SELECTED                                │
│                                                               │
│ Reasoning:                                                   │
│   "Kullanıcı 'derinlemesine araştır' dedi, bu Pro model +   │
│    25 kaynak gerektiriyor. İlaç güvenliği konusu da         │
│    kapsamlı analiz gerektiren bir alan."                    │
│                                                               │
│ Decision Confidence: 1.0                                     │
│ Explicit Deep Request: true                                  │
│                                                               │
│ 🟣 Tokens: 85 input | 95 output                             │
│ 🟣 Cost: $0.000010                                           │
│ ⏱️  Latency: 420ms                                           │
└──────────────────────────────────────────────────────────────┘

🚀 Routing to Tier 3: Deep Research Pipeline
```

#### Stage 3: Query Enrichment (if needed)

```
┌─ 🔍 QUERY ENRICHMENT ────────────────────────────────────────┐
│ Original: "yan etkileri"                                     │
│ Enriched: "metformin side effects diabetes type 1 lada"     │
│                                                               │
│ Context Used:                                                │
│   • Recent conversation: Metformin discussion                │
│   • User profile: LADA diabetes                              │
│                                                               │
│ Reasoning:                                                   │
│   "Query vague ('yan etkileri'). Added drug name and        │
│    diabetes context from conversation history."             │
│                                                               │
│ 🟣 Tokens: 120 input | 80 output                            │
│ 🟣 Cost: $0.000006                                           │
│ ⏱️  Latency: 380ms                                           │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 4: Source Distribution Planning

```
┌─ 📊 SOURCE DISTRIBUTION PLANNING ────────────────────────────┐
│ Model: gemini-2.0-flash-lite                                 │
│                                                               │
│ Query Category: drug_safety                                  │
│ Target Sources: 25                                           │
│                                                               │
│ API Distribution:                                            │
│   📚 PubMed:          18 sources (72%) ████████████████▓▓▓▓  │
│   🔬 medRxiv:          2 sources (8%)  ██▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │
│   🏥 ClinicalTrials:   5 sources (20%) █████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │
│                                                               │
│ Reasoning:                                                   │
│   "Drug safety requires peer-reviewed literature (high       │
│    PubMed). Clinical trial data adds real-world safety      │
│    evidence. Limited medRxiv since pre-prints less reliable  │
│    for safety data."                                         │
│                                                               │
│ Confidence: 0.95                                             │
│                                                               │
│ 🟣 Tokens: 95 input | 110 output                            │
│ 🟣 Cost: $0.000009                                           │
│ ⏱️  Latency: 390ms                                           │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 5: Multi-Round Source Gathering

```
┌─ 🔄 ROUND 1: INITIAL BROAD SEARCH ──────────────────────────┐
│                                                               │
│ 📚 PubMed API Call #1                                        │
│ ├─ Query: "metformin side effects diabetes"                 │
│ ├─ Filters: last_5_years=true, article_type=clinical_trial  │
│ ├─ Max results: 10                                           │
│ ├─ Status: 🟢 SUCCESS                                        │
│ ├─ Found: 47 results                                         │
│ ├─ Retrieved: 10 (top ranked)                               │
│ └─ ⏱️ Latency: 1240ms                                        │
│                                                               │
│ Top 3 Results:                                               │
│ 1. ⭐⭐⭐⭐⭐ (Score: 0.94)                                    │
│    Title: "Metformin Safety in Type 1 Diabetes: 5-Year..."  │
│    Authors: Zhang et al.                                     │
│    Journal: Diabetes Care (IF: 18.9)                         │
│    Year: 2023                                                │
│    Citations: 234                                            │
│    Relevance: Direct match - T1D + safety + long-term       │
│                                                               │
│ 2. ⭐⭐⭐⭐ (Score: 0.87)                                      │
│    Title: "Gastrointestinal Effects of Metformin..."        │
│    Authors: Kumar et al.                                     │
│    Journal: JAMA (IF: 56.3)                                  │
│    Year: 2024                                                │
│    Citations: 89                                             │
│    Relevance: High impact + recent + specific side effects  │
│                                                               │
│ 3. ⭐⭐⭐⭐ (Score: 0.85)                                      │
│    Title: "Lactic Acidosis Risk with Metformin..."          │
│    Authors: Smith et al.                                     │
│    Journal: NEJM (IF: 91.2)                                  │
│    Year: 2023                                                │
│    Citations: 445                                            │
│    Relevance: Addresses rare but serious side effect        │
│                                                               │
│ ... (7 more results)                                         │
│                                                               │
├─ 🔬 medRxiv API Call #1                                      │
│ ├─ Query: "metformin adverse events"                        │
│ ├─ Date range: last_12_months                                │
│ ├─ Max results: 2                                            │
│ ├─ Status: 🟢 SUCCESS                                        │
│ ├─ Found: 12 results                                         │
│ ├─ Retrieved: 2 (most recent, high quality)                 │
│ └─ ⏱️ Latency: 890ms                                         │
│                                                               │
├─ 🏥 ClinicalTrials API Call #1                               │
│ ├─ Query: "metformin safety"                                │
│ ├─ Filters: completed_trials=true, has_results=true         │
│ ├─ Max results: 5                                            │
│ ├─ Status: 🟢 SUCCESS                                        │
│ ├─ Found: 156 trials                                         │
│ ├─ Retrieved: 5 (largest, most recent)                      │
│ └─ ⏱️ Latency: 1580ms                                        │
│                                                               │
│ Round 1 Summary:                                             │
│   Sources gathered: 17 / 25 target                          │
│   Quality distribution:                                      │
│     ⭐⭐⭐⭐⭐: 4 sources                                      │
│     ⭐⭐⭐⭐: 8 sources                                        │
│     ⭐⭐⭐: 5 sources                                          │
│                                                               │
│   ⏱️ Total latency: 3710ms                                   │
└──────────────────────────────────────────────────────────────┘

┌─ 🧩 GAP DETECTION: Round 1 → 2 ─────────────────────────────┐
│ Model: gemini-2.0-flash-lite                                 │
│                                                               │
│ Analyzing coverage gaps...                                   │
│                                                               │
│ ✅ Well Covered:                                             │
│   • Gastrointestinal side effects (8 sources)               │
│   • Lactic acidosis risk (3 sources)                        │
│   • General safety profile (12 sources)                     │
│                                                               │
│ 🟡 Partially Covered:                                        │
│   • Vitamin B12 deficiency (2 sources, need more)           │
│   • Renal function impact (1 source, need 2-3 more)         │
│                                                               │
│ 🔴 Not Covered:                                              │
│   • Long-term cardiovascular effects                         │
│   • Interaction with insulin therapy                         │
│   • Dosage-dependent side effects                            │
│                                                               │
│ Gap Score: 0.68 (target: >0.85)                             │
│                                                               │
│ Decision: PROCEED TO ROUND 2                                 │
│ Reason: Critical gaps in CV effects and insulin interaction │
│         for LADA patient context                             │
│                                                               │
│ 🟣 Tokens: 450 input | 180 output                           │
│ 🟣 Cost: $0.000022                                           │
│ ⏱️  Latency: 620ms                                           │
└──────────────────────────────────────────────────────────────┘

┌─ 🔄 ROUND 2: GAP-TARGETED SEARCH ───────────────────────────┐
│                                                               │
│ 📚 PubMed API Call #2                                        │
│ ├─ Query: "metformin cardiovascular effects long-term"      │
│ ├─ Refined focus: Addressing CV gap                         │
│ ├─ Max results: 4                                            │
│ ├─ Status: 🟢 SUCCESS                                        │
│ ├─ Retrieved: 4 high-quality sources                        │
│ └─ ⏱️ Latency: 980ms                                         │
│                                                               │
│ 📚 PubMed API Call #3                                        │
│ ├─ Query: "metformin insulin combination therapy type 1"    │
│ ├─ Refined focus: Insulin interaction for LADA context      │
│ ├─ Max results: 4                                            │
│ ├─ Status: 🟢 SUCCESS                                        │
│ ├─ Retrieved: 4 sources (3 high quality, 1 moderate)        │
│ └─ ⏱️ Latency: 1120ms                                        │
│                                                               │
│ Round 2 Summary:                                             │
│   Sources gathered: 25 / 25 target ✅                        │
│   New high-impact finds:                                     │
│     • REMOVAL trial (CV outcomes) - NEJM 2024               │
│     • T1D+Metformin meta-analysis - Lancet 2023             │
│                                                               │
│   ⏱️ Total latency: 2100ms                                   │
└──────────────────────────────────────────────────────────────┘

┌─ 🧩 FINAL GAP ANALYSIS ──────────────────────────────────────┐
│                                                               │
│ Coverage Status: 🟢 COMPREHENSIVE                            │
│ Gap Score: 0.91 (target: >0.85) ✅                           │
│                                                               │
│ All critical aspects covered:                                │
│   ✅ GI side effects (9 sources)                            │
│   ✅ Lactic acidosis (3 sources)                            │
│   ✅ B12 deficiency (4 sources)                             │
│   ✅ Renal function (3 sources)                             │
│   ✅ Cardiovascular effects (4 sources)                     │
│   ✅ Insulin interaction (4 sources)                        │
│                                                               │
│ Decision: STOP SEARCHING, PROCEED TO RANKING                 │
│                                                               │
│ 🟣 Tokens: 520 input | 140 output                           │
│ 🟣 Cost: $0.000018                                           │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 6: Source Ranking & Selection

```
┌─ 🏆 SOURCE RANKING ──────────────────────────────────────────┐
│ Model: gemini-2.0-flash-lite                                 │
│                                                               │
│ Ranking Criteria (weights):                                  │
│   📊 Journal Impact Factor:     25%                          │
│   📅 Recency:                   20%                          │
│   🎯 Relevance Score:           30%                          │
│   📖 Citation Count:            15%                          │
│   🔬 Study Design Quality:      10%                          │
│                                                               │
│ Total sources evaluated: 25                                  │
│                                                               │
│ Top 10 Selected Sources:                                     │
│                                                               │
│ 1. ⭐⭐⭐⭐⭐ (Overall: 0.96)                                  │
│    └─ Zhang et al. (2023) - Diabetes Care                   │
│       ├─ IF: 18.9 → Score: 0.89                              │
│       ├─ Recency: 2023 → Score: 0.95                         │
│       ├─ Relevance: T1D+Safety+Long-term → Score: 1.0       │
│       ├─ Citations: 234 → Score: 0.92                        │
│       └─ Design: 5-year RCT → Score: 1.0                     │
│                                                               │
│ 2. ⭐⭐⭐⭐⭐ (Overall: 0.94)                                  │
│    └─ Kumar et al. (2024) - JAMA                            │
│       ├─ IF: 56.3 → Score: 1.0                               │
│       ├─ Recency: 2024 → Score: 1.0                          │
│       ├─ Relevance: GI effects specific → Score: 0.88       │
│       ├─ Citations: 89 → Score: 0.75                         │
│       └─ Design: Meta-analysis → Score: 0.95                 │
│                                                               │
│ 3-10. [Similar detailed breakdown]                           │
│                                                               │
│ Sources excluded (too low quality):                          │
│   • 3 sources: IF < 2.0                                      │
│   • 2 sources: Pre-print, no peer review                     │
│   • 1 source: Outdated (>10 years)                           │
│                                                               │
│ Final source count: 19 high-quality sources                  │
│                                                               │
│ 🟣 Tokens: 1200 input | 340 output                          │
│ 🟣 Cost: $0.000045                                           │
│ ⏱️  Latency: 890ms                                           │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 7: Response Generation

```
┌─ ✍️  RESPONSE SYNTHESIS ────────────────────────────────────┐
│ Model: gemini-2.0-pro-exp                                    │
│ Temperature: 0.3                                             │
│                                                               │
│ System Prompt:                                               │
│   • Tier 3 Deep Research                                     │
│   • Balli personality (friendly, knowledgeable)              │
│   • Turkish language                                         │
│   • LADA context for personalization                         │
│                                                               │
│ Input Context:                                               │
│   • Original query                                           │
│   • 19 ranked sources (full text excerpts)                   │
│   • User profile (Dilara context)                            │
│                                                               │
│ Streaming response...                                        │
│                                                               │
│ [Response preview shown in real-time]                        │
│                                                               │
│ 🟣 Tokens: 15,420 input | 3,840 output                      │
│ 🟣 Cost: $0.18                                               │
│ ⏱️  Latency: 18,500ms (streaming)                           │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 8: Citation Authenticity Verification

```
┌─ ✅ CITATION VERIFICATION ───────────────────────────────────┐
│                                                               │
│ Analyzing citation accuracy...                               │
│                                                               │
│ Total sentences with citations: 47                           │
│ Total citation instances: 89                                 │
│                                                               │
│ Verification Method:                                         │
│   1. Extract each cited sentence                             │
│   2. Find corresponding source text                          │
│   3. Compare semantic similarity                             │
│   4. Check for direct quotes vs paraphrasing                 │
│   5. Validate citation index correctness                     │
│                                                               │
│ ┌─ Example Check #1 ────────────────────────────────────┐   │
│ │ Sentence:                                              │   │
│ │ "Metformin GI yan etkileri hastaların %30'unda        │   │
│ │  görülüyor[2][5]."                                     │   │
│ │                                                         │   │
│ │ Citation [2]: Kumar et al. JAMA 2024                  │   │
│ │ Source text:                                            │   │
│ │ "...gastrointestinal adverse events occurred in 28-32% │   │
│ │  of metformin-treated patients..."                     │   │
│ │                                                         │   │
│ │ Semantic similarity: 0.94 ✅                           │   │
│ │ Accuracy: ACCURATE (paraphrased correctly)            │   │
│ │                                                         │   │
│ │ Citation [5]: Johnson et al. Diabetologia 2023        │   │
│ │ Source text:                                            │   │
│ │ "...GI side effects were reported by 29.8% of         │   │
│ │  participants..."                                      │   │
│ │                                                         │   │
│ │ Semantic similarity: 0.97 ✅                           │   │
│ │ Accuracy: ACCURATE (supports claim)                   │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                               │
│ ┌─ Example Check #2 (ISSUE DETECTED) ──────────────────┐   │
│ │ Sentence:                                              │   │
│ │ "B12 eksikliği riski uzun süreli kullanımda artıyor   │   │
│ │  [7]."                                                 │   │
│ │                                                         │   │
│ │ Citation [7]: Chen et al. Endocrine Rev 2023          │   │
│ │ Source text:                                            │   │
│ │ "...vitamin B12 deficiency may occur with prolonged   │   │
│ │  metformin use, but evidence is inconsistent..."      │   │
│ │                                                         │   │
│ │ Semantic similarity: 0.78 ⚠️                          │   │
│ │ Issue: SOURCE NUANCE LOST                             │   │
│ │ Details: Original source mentions "evidence           │   │
│ │          inconsistent" but response states as fact    │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                               │
│ Overall Citation Health:                                     │
│   ✅ Accurate: 82 citations (92%)                           │
│   ⚠️  Nuance lost: 5 citations (6%)                         │
│   ❌ Inaccurate: 2 citations (2%)                           │
│                                                               │
│ Authenticity Score: 0.92 / 1.0                              │
│                                                               │
│ Issues Found:                                                │
│   1. Sentence #23: Overstated certainty (source was         │
│      equivocal)                                              │
│   2. Sentence #41: Wrong citation index (should be [12]     │
│      not [11])                                               │
│                                                               │
│ 🟣 Verification cost: $0.04                                  │
│ ⏱️  Latency: 4200ms                                         │
└──────────────────────────────────────────────────────────────┘
```

#### Stage 9: Final Summary

```
┌─ 📊 RESEARCH JOURNEY COMPLETE ───────────────────────────────┐
│                                                               │
│ Query: "Metformin yan etkileri derinlemesine araştır"       │
│                                                               │
│ Pipeline Performance:                                        │
│   ⏱️  Total time: 32.4 seconds                              │
│   🔄 API rounds: 2                                           │
│   📚 Sources gathered: 25 → Selected: 19                    │
│   ✅ Citation accuracy: 92%                                 │
│   📏 Response length: 3,840 tokens                          │
│                                                               │
│ Cost Breakdown:                                              │
│   🔵 Router: $0.000010                                      │
│   🔵 Query analysis: $0.000008                              │
│   🔵 Enrichment: $0.000006                                  │
│   🔵 Distribution planning: $0.000009                       │
│   🔵 Gap detection (2 rounds): $0.000040                    │
│   🔵 Source ranking: $0.000045                              │
│   🟣 Response synthesis (Pro): $0.180000                    │
│   🟣 Citation verification: $0.040000                        │
│   ──────────────────────────                                 │
│   💰 Total: $0.220118                                        │
│                                                               │
│ Token Usage:                                                 │
│   📥 Total input: 17,935 tokens                             │
│   📤 Total output: 4,705 tokens                             │
│   📊 Total: 22,640 tokens                                   │
│                                                               │
│ Quality Metrics:                                             │
│   📊 Source quality avg: 4.3 / 5.0                          │
│   🎯 Gap coverage: 91%                                       │
│   ✅ Citation authenticity: 92%                             │
│   📖 Journal IF avg: 22.4                                    │
│                                                               │
│ Bottlenecks Detected:                                        │
│   ⚠️  PubMed API: 1240ms (slowest call)                    │
│   ⚠️  Pro model synthesis: 18.5s (76% of total time)       │
│                                                               │
│ Recommendations:                                             │
│   • Consider caching common queries                          │
│   • PubMed timeout could be reduced to 1000ms               │
│   • 2 citation errors - review synthesis prompt             │
│                                                               │
└──────────────────────────────────────────────────────────────┘

💾 Full report saved to: ./research-logs/20250115_142345.json
📄 Markdown report: ./research-logs/20250115_142345.md

🔍 Commands:
  - Press 'v' to view full response
  - Press 's' to see all sources
  - Press 'c' to inspect citations
  - Press 'r' to run another query
  - Press 'q' to quit
```

## Technical Implementation Requirements

### Data Structures

```typescript
interface ResearchJourney {
  query: {
    original: string;
    enriched?: string;
    timestamp: string;
    language: string;
  };

  routing: {
    tier: 0 | 1 | 2 | 3;
    reasoning: string;
    confidence: number;
    explicitDeepRequest: boolean;
    model: string;
    tokens: { input: number; output: number };
    cost: number;
    latency: number;
  };

  planning: {
    category: string;
    distribution: {
      pubmed: number;
      medrxiv: number;
      clinicalTrials: number;
    };
    reasoning: string;
    model: string;
    tokens: { input: number; output: number };
    cost: number;
    latency: number;
  };

  rounds: Array<{
    roundNumber: number;
    purpose: 'initial' | 'gap_fill';
    apiCalls: Array<{
      api: 'pubmed' | 'medrxiv' | 'clinicalTrials';
      query: string;
      filters: Record<string, any>;
      maxResults: number;
      found: number;
      retrieved: number;
      status: 'success' | 'failure';
      error?: string;
      latency: number;
      results: Array<{
        id: string;
        title: string;
        authors: string;
        journal?: string;
        year: number;
        citations?: number;
        impactFactor?: number;
        relevanceScore: number;
        qualityRating: number;
      }>;
    }>;
    gapAnalysis?: {
      wellCovered: string[];
      partiallyCovered: string[];
      notCovered: string[];
      gapScore: number;
      decision: 'continue' | 'stop';
      reasoning: string;
      model: string;
      tokens: { input: number; output: number };
      cost: number;
      latency: number;
    };
  }>;

  ranking: {
    criteria: Record<string, number>; // weights
    totalEvaluated: number;
    selected: number;
    excluded: Array<{
      reason: string;
      count: number;
    }>;
    topSources: Array<{
      rank: number;
      source: any;
      overallScore: number;
      breakdown: Record<string, number>;
    }>;
    model: string;
    tokens: { input: number; output: number };
    cost: number;
    latency: number;
  };

  synthesis: {
    model: string;
    temperature: number;
    systemPromptVersion: string;
    sourcesProvided: number;
    responseLength: number;
    streaming: boolean;
    tokens: { input: number; output: number };
    cost: number;
    latency: number;
    response: string;
  };

  citationVerification: {
    totalSentences: number;
    totalCitations: number;
    checks: Array<{
      sentence: string;
      citations: Array<{
        index: number;
        sourceTitle: string;
        sourceText: string;
        similarity: number;
        accurate: boolean;
        issue?: string;
      }>;
    }>;
    overallScore: number;
    summary: {
      accurate: number;
      nuanceLost: number;
      inaccurate: number;
    };
    cost: number;
    latency: number;
  };

  summary: {
    totalTime: number;
    totalCost: number;
    totalTokens: { input: number; output: number };
    qualityMetrics: {
      sourceQualityAvg: number;
      gapCoverage: number;
      citationAuthenticity: number;
      journalIFAvg: number;
    };
    bottlenecks: Array<{
      stage: string;
      latency: number;
      percentage: number;
    }>;
    recommendations: string[];
  };
}
```

### CLI Framework

Use these libraries:

- `chalk` for colors
- `boxen` for boxes
- `cli-table3` for tables
- `ora` for spinners
- `inquirer` for interactive prompts
- `cli-progress` for progress bars
- `gradient-string` for gradient text effects

### File Outputs

Generate two output files per query:

1. **JSON file**: Complete raw data for programmatic analysis
1. **Markdown file**: Human-readable report with formatting

### Interactive Commands

After showing results, provide interactive commands:

- `v`: View full response
- `s`: Show all sources with details
- `c`: Inspect all citations with verification
- `t`: Show token/cost breakdown by stage
- `a`: Show API call details
- `g`: Show gap detection reasoning
- `r`: Run another query
- `e`: Export to different format (JSON, HTML, PDF)
- `q`: Quit

### Configuration

Support a `research-xray.config.json`:

```json
{
  "apiKeys": {
    "gemini": "...",
    "pubmed": "...",
    "clinicalTrials": "..."
  },
  "display": {
    "colorScheme": "default" | "light" | "dark",
    "verbosity": "minimal" | "normal" | "verbose",
    "showTimestamps": true,
    "showCosts": true
  },
  "export": {
    "autoSave": true,
    "outputDir": "./research-logs",
    "formats": ["json", "markdown"]
  }
}
```

## Critical Features for Debugging

1. **API Call Replay**: Save all API calls with responses, allow replay for debugging
1. **Source Comparison**: Side-by-side view of multiple sources on same topic
1. **Citation Diff**: Show original source text vs. paraphrased text with highlighting
1. **Gap Evolution**: Track how gaps change across rounds
1. **Ranking Sensitivity**: Show how changing weights affects source selection
1. **Cost What-If**: Calculate cost if different tier was chosen
1. **Quality Trends**: Graph quality metrics over multiple queries
1. **Error Tracking**: Detailed error logs with stack traces for failed API calls

## Success Criteria

The tool should help answer these debug questions:

1. Why did router choose this tier?
1. Why only 2 rounds instead of 3?
1. Why was source X excluded?
1. Is citation [5] actually accurate?
1. Where are the bottlenecks?
1. How can I reduce costs?
1. Which APIs are underperforming?
1. Are gaps being detected correctly?
1. Is ranking logic working as intended?
1. Is the response using the best sources?

Build this tool to be the definitive X-ray for understanding and debugging the deep research pipeline.

```
This prompt gives you:
1. **Complete visual specification** - showing exactly how each stage should look
2. **Data structures** - for capturing all the debug information
3. **Technical stack** - specific libraries for beautiful CLI rendering
4. **Interactive features** - commands for deep inspection
5. **Debug focus** - answers all your key questions about the pipeline
6. **Export capabilities** - save everything for later analysis

The tool would let you see every decision, every API call, every ranking, and every citation verification in a beautifully formatted, easy-to-navigate interface.​​​​​​​​​​​​​​​​
```
