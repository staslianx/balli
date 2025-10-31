# Usage Examples - Deep Research Observatory

Real-world examples of using the Research X-Ray CLI tool for different scenarios.

## Example 1: Basic Tier 1 Query (Model-only)

### Command
```bash
npm run dev -- --query "A1C nedir?"
```

### Expected Output
```
┌─ 🎯 ROUTER DECISION ─────────────────────────────────────┐
│ Tier 1 (Model): ✅ SELECTED                              │
│ Reasoning: "Temel tanım sorusu. Model doğrudan          │
│            cevaplayabilir."                               │
│ 📊 Tokens: 35 input | 95 output                          │
│ 💰 Cost: $0.000005                                        │
│ ⏱️  Latency: 280ms                                        │
└────────────────────────────────────────────────────────────┘

┌─ 📊 RESEARCH JOURNEY COMPLETE ───────────────────────────┐
│ Pipeline Performance:                                     │
│   ⏱️  Total time: 1.8s                                    │
│   🔄 Rounds: 0                                            │
│   📚 Sources: 0 (model knowledge)                         │
│   💰 Total: $0.000005                                     │
└────────────────────────────────────────────────────────────┘
```

### Use Case
- Quick definition questions
- General diabetes knowledge
- Fast responses without research needed

---

## Example 2: Tier 2 Query (Web Search)

### Command
```bash
npm run dev -- --query "Metformin 2024 güncel kılavuzları araştır"
```

### Expected Output
```
┌─ 🎯 ROUTER DECISION ─────────────────────────────────────┐
│ Tier 2 (Hybrid): ✅ SELECTED                             │
│ Reasoning: "Kullanıcı açıkça 'araştır' dedi - web       │
│            kaynaklarından güncel bilgi getirilmeli"      │
└────────────────────────────────────────────────────────────┘

┌─ 🔄 ROUND 1: WEB SEARCH ─────────────────────────────────┐
│ 🌐 EXA API Call                                          │
│ ├─ Query: "metformin 2024 guidelines diabetes"          │
│ ├─ Status: ✅ SUCCESS                                     │
│ ├─ Found: 15 results                                     │
│ └─ ⏱️ Latency: 890ms                                     │
│                                                            │
│ Round 1 Summary:                                          │
│   Sources gathered: 15 / 15 target                       │
│   ⏱️  Total latency: 1.2s                                 │
└────────────────────────────────────────────────────────────┘

┌─ 📊 RESEARCH JOURNEY COMPLETE ───────────────────────────┐
│ Pipeline Performance:                                     │
│   ⏱️  Total time: 4.5s                                    │
│   🔄 Rounds: 1                                            │
│   📚 Sources: 15                                          │
│   💰 Total: $0.003200                                     │
└────────────────────────────────────────────────────────────┘
```

### Use Case
- Current guidelines and updates
- Recent research findings
- Verification of information online

---

## Example 3: Tier 3 Query (Deep Research)

### Command
```bash
npm run dev -- --query "Metformin kardiyovasküler etkileri derinlemesine araştır"
```

### Expected Output
```
┌─ 🎯 ROUTER DECISION ─────────────────────────────────────┐
│ Tier 3 (Deep): ✅ SELECTED                               │
│ Reasoning: "Kullanıcı 'derinlemesine araştır' dedi -    │
│            Pro model + 25 kaynak gerektiriyor"           │
└────────────────────────────────────────────────────────────┘

┌─ 📊 RESEARCH PLANNING ───────────────────────────────────┐
│ Strategy: comprehensive_medical_review                    │
│ Estimated Rounds: 2                                       │
│ Focus Areas:                                              │
│   • Cardiovascular outcomes studies                       │
│   • Meta-analyses and systematic reviews                  │
│   • Long-term safety data                                 │
└────────────────────────────────────────────────────────────┘

┌─ 🔄 ROUND 1: INITIAL BROAD SEARCH ──────────────────────┐
│ 📚 PubMed API Call                                       │
│ ├─ Query: "metformin cardiovascular effects diabetes"   │
│ ├─ Status: ✅ SUCCESS                                     │
│ ├─ Found: 234 results                                    │
│ ├─ Retrieved: 10 (top ranked)                           │
│ └─ ⏱️ Latency: 1,240ms                                   │
│                                                            │
│ 🔬 medRxiv API Call                                      │
│ ├─ Query: "metformin cardiovascular adverse events"     │
│ ├─ Status: ✅ SUCCESS                                     │
│ ├─ Retrieved: 2 sources                                  │
│ └─ ⏱️ Latency: 890ms                                     │
│                                                            │
│ 🏥 ClinicalTrials API Call                               │
│ ├─ Query: "metformin cardiovascular safety"             │
│ ├─ Status: ✅ SUCCESS                                     │
│ ├─ Retrieved: 5 trials                                   │
│ └─ ⏱️ Latency: 1,580ms                                   │
│                                                            │
│ 🌐 Exa API Call                                          │
│ ├─ Query: "metformin heart health diabetes"             │
│ ├─ Status: ✅ SUCCESS                                     │
│ ├─ Retrieved: 10 sources                                 │
│ └─ ⏱️ Latency: 950ms                                     │
│                                                            │
│ Round 1 Summary:                                          │
│   Sources gathered: 27 / 25 target                       │
│   ⏱️  Total latency: 4.7s                                 │
└────────────────────────────────────────────────────────────┘

┌─ 🧩 GAP DETECTION: Round 1 ──────────────────────────────┐
│ ✅ Well Covered:                                          │
│   • General cardiovascular outcomes                       │
│   • Meta-analyses and RCTs                                │
│                                                            │
│ 🔴 Not Covered:                                           │
│   • Heart failure specific outcomes                       │
│   • Subgroup analyses (elderly, CKD)                      │
│                                                            │
│ Gap Score: 0.72 (target: >0.85)                          │
│ Decision: PROCEED TO ROUND 2                              │
└────────────────────────────────────────────────────────────┘

┌─ 🔄 ROUND 2: GAP-TARGETED SEARCH ────────────────────────┐
│ 📚 PubMed API Call                                       │
│ ├─ Query: "metformin heart failure elderly"             │
│ ├─ Status: ✅ SUCCESS                                     │
│ ├─ Retrieved: 6 sources                                  │
│ └─ ⏱️ Latency: 980ms                                     │
│                                                            │
│ Round 2 Summary:                                          │
│   Sources gathered: 33 / 40 estimated                     │
│   ⏱️  Total latency: 2.1s                                 │
└────────────────────────────────────────────────────────────┘

┌─ ✍️  RESPONSE SYNTHESIS ─────────────────────────────────┐
│ Model: gemini-2.5-pro-exp                                 │
│ Sources Provided: 30 (top-ranked)                         │
│ 📊 Tokens: 15,420 input | 3,840 output                   │
│ 💰 Cost: $0.180000                                        │
│ ⏱️  Latency: 18.5s (streaming)                           │
└────────────────────────────────────────────────────────────┘

┌─ 📊 RESEARCH JOURNEY COMPLETE ───────────────────────────┐
│ Pipeline Performance:                                     │
│   ⏱️  Total time: 32.4s                                   │
│   🔄 Rounds: 2                                            │
│   📚 Sources: 33                                          │
│   💰 Total: $0.220118                                     │
│                                                            │
│ Bottlenecks Detected:                                     │
│   ⚠️  Pro model synthesis: 18.5s (57% of total time)    │
│   ⚠️  PubMed API: 1.24s (slowest API call)              │
└────────────────────────────────────────────────────────────┘
```

### Use Case
- Comprehensive research questions
- Multi-faceted medical topics
- When 25+ high-quality sources are needed
- Complex queries requiring gap analysis

---

## Example 4: Verbose Mode

### Command
```bash
npm run dev -- --query "GLP-1 agonistleri araştır" --verbose
```

### Additional Output
Shows top 3 results from each API call:

```
│ 📚 PubMed API Call                                       │
│ ├─ Top Results:                                          │
│    1. GLP-1 Receptor Agonists in Type 2 Diabetes...     │
│       Authors: Zhang et al.                               │
│    2. Cardiovascular Benefits of GLP-1 Agonists...      │
│       Authors: Kumar et al.                               │
│    3. Weight Loss Effects of Semaglutide...              │
│       Authors: Smith et al.                               │
```

---

## Example 5: Replay Mode

### Command
```bash
npm run dev -- replay ./research-logs/research_2025-01-31_14-23-45.json
```

### Use Case
- Re-analyze past research sessions
- Share research journeys with team members
- Compare different runs of the same query
- Debug issues after the fact

---

## Example 6: Interactive Commands

After any research completes:

### View Full Response
```
🔍 Commands: v, s, t, r, e, q
Enter command: v

📄 Full Response:
────────────────────────────────────────────────────────────
Metformin, tip 2 diyabet tedavisinde kullanılan birinci
seçenek oral antidiyabetik ilaçtır[1][2]. İnsülin
direncini azaltarak, karaciğerde glukoz üretimini
baskılayarak ve barsaklarda glukoz emilimini yavaşlatarak
etki eder[3][4]...
────────────────────────────────────────────────────────────
```

### Show All Sources
```
Enter command: s

📚 All Sources:
────────────────────────────────────────────────────────────

Round 1:
  1. Metformin Safety in Type 1 Diabetes: 5-Year Study
     Type: PubMed
     Authors: Zhang et al.
     Journal: Diabetes Care (IF: 18.9)
     Year: 2023
     URL: https://pubmed.ncbi.nlm.nih.gov/37123456/

  2. Gastrointestinal Effects of Metformin: Meta-analysis
     Type: PubMed
     Authors: Kumar et al.
     Journal: JAMA (IF: 56.3)
     Year: 2024
     URL: https://pubmed.ncbi.nlm.nih.gov/37234567/
...
```

### Token/Cost Breakdown
```
Enter command: t

💰 Token & Cost Breakdown:
────────────────────────────────────────────────────────────

Routing:
  Tokens: 45 input | 95 output
  Cost: $0.000008

Planning:
  Tokens: 120 input | 180 output
  Cost: $0.000015

Round 1 Gap Analysis:
  Tokens: 450 input | 180 output
  Cost: $0.000022

Round 2 Gap Analysis:
  Tokens: 520 input | 140 output
  Cost: $0.000018

Synthesis:
  Tokens: 15,420 input | 3,840 output
  Cost: $0.180000

Total:
  Tokens: 16,555 input | 4,435 output
  Total Tokens: 20,990
  Total Cost: $0.220063
```

---

## Example 7: Custom Configuration

### Create config file
```bash
cat > research-xray.config.json << EOF
{
  "firebaseFunctions": {
    "emulator": false,
    "productionUrl": "https://us-central1-balli-health.cloudfunctions.net/diabetesAssistantStream"
  },
  "display": {
    "verbosity": "verbose",
    "showCosts": false
  },
  "export": {
    "formats": ["json"]
  }
}
EOF
```

### Run with custom config
```bash
npm run dev -- --config ./research-xray.config.json
```

---

## Example 8: Batch Testing

Test multiple queries in sequence:

```bash
#!/bin/bash
queries=(
  "A1C nedir?"
  "Metformin yan etkileri araştır"
  "GLP-1 agonistleri derinlemesine araştır"
)

for query in "${queries[@]}"; do
  echo "Testing: $query"
  npm run dev -- --query "$query"
  sleep 2
done
```

---

## Analyzing Output

### Key Metrics to Watch

1. **Tier Selection**
   - Tier 0: Recall from past conversations
   - Tier 1: Model-only (fastest, cheapest)
   - Tier 2: Web search (moderate cost)
   - Tier 3: Deep research (comprehensive, expensive)

2. **Latency Breakdown**
   - Routing: <500ms ideal
   - API calls: <2s per call ideal
   - Synthesis: Varies by tier (T1: <2s, T2: <5s, T3: <20s)

3. **Cost Optimization**
   - T1: ~$0.001 per query
   - T2: ~$0.003 per query
   - T3: ~$0.03-0.08 per query

4. **Source Quality**
   - PubMed: Highest quality (peer-reviewed)
   - Clinical Trials: Real-world evidence
   - medRxiv: Recent but pre-print
   - Exa: General medical web sources

---

## Troubleshooting Scenarios

### Scenario: Research Takes Too Long

**Symptoms:** T3 research taking >60 seconds

**Diagnosis Steps:**
1. Check bottlenecks in summary
2. Look for slow API calls
3. Identify if many rounds executed

**Example Output:**
```
Bottlenecks Detected:
  ⚠️  PubMed API: 3.5s (API timeout issue)
  ⚠️  Synthesis: 45s (too many sources)

Recommendations:
  • PubMed timeout could be reduced to 2000ms
  • Consider reducing source count from 30 to 25
```

### Scenario: Unexpected Tier Selection

**Symptoms:** Expected T3 but got T1

**Diagnosis:**
Look at router reasoning:
```
│ Reasoning: "Kullanıcı 'derinleş' demedi - T1 yeterli"  │
```

**Solution:** Add trigger keyword "derinleş" to query

---

## Best Practices

1. **Start with T1** - Test basic queries first
2. **Use verbose mode** - When debugging source selection
3. **Save sessions** - Enable autoSave for analysis
4. **Compare runs** - Use replay mode to compare different queries
5. **Monitor costs** - Check token breakdown regularly
6. **Test incrementally** - T1 → T2 → T3 progression

---

**Need more examples? Check the [README.md](README.md) for complete documentation!**
