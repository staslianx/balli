# Quick Start Guide - Deep Research Observatory

Get up and running with the Research X-Ray CLI tool in under 5 minutes!

## Prerequisites

- Node.js 18+ installed
- Firebase Functions emulator running (or access to production)
- Terminal/command line access

## Step 1: Install Dependencies

```bash
cd cli-tool
npm install
npm run build
```

## Step 2: Start Firebase Emulator

In a separate terminal:

```bash
cd ../functions
npm run serve
```

You should see:
```
✔  functions: Emulator started at http://127.0.0.1:5001
✔  functions[us-central1-diabetesAssistantStream]: http function initialized
```

## Step 3: Run Your First Research

```bash
npm run dev
```

When prompted, enter a research query in Turkish:
```
📝 Enter your research query (Turkish): Metformin yan etkileri nelerdir?
```

## Step 4: Watch the Magic

You'll see real-time progress:

```
┌────────────────────────────────────────────────────┐
│                                                    │
│   🔬 Deep Research Observatory                     │
│   Balli Research Pipeline X-Ray Tool               │
│                                                    │
└────────────────────────────────────────────────────┘

✓ Tier 1 selected (confidence: 0.92)
✓ Research complete!
```

## Step 5: Explore Results

After research completes, use interactive commands:

- Press `v` to view the full response
- Press `s` to see all sources
- Press `t` for token/cost breakdown
- Press `q` to quit

## What You'll See

### Router Decision
```
┌─ 🎯 ROUTER DECISION ─────────────────────────────────────┐
│ Model: gemini-2.0-flash-lite                              │
│                                                            │
│ Tier Analysis:                                            │
│   Tier 1 (Model): ✅ SELECTED                            │
│                                                            │
│ Reasoning:                                                │
│   "Temel tanım sorusu. Model doğrudan cevaplayabilir."   │
│                                                            │
│ 📊 Tokens: 45 input | 120 output                         │
│ 💰 Cost: $0.000008                                        │
│ ⏱️  Latency: 340ms                                        │
└────────────────────────────────────────────────────────────┘
```

### Final Summary
```
┌─ 📊 RESEARCH JOURNEY COMPLETE ───────────────────────────┐
│                                                            │
│ Pipeline Performance:                                     │
│   ⏱️  Total time: 2.4s                                    │
│   🔄 Rounds: 1                                            │
│   📚 Sources: 0 (model-only response)                     │
│                                                            │
│ Cost Breakdown:                                           │
│   💰 Total: $0.001234                                     │
│                                                            │
│ Token Usage:                                              │
│   📥 Input: 150 tokens                                    │
│   📤 Output: 420 tokens                                   │
│   📊 Total: 570 tokens                                    │
└────────────────────────────────────────────────────────────┘
```

## Testing Deep Research (Tier 3)

To trigger deep research, use the keyword "derinleş":

```bash
npm run dev -- --query "Metformin yan etkileri derinlemesine araştır"
```

This will:
1. Route to Tier 3 (Deep Research)
2. Execute 2-4 rounds of research
3. Fetch 25-60+ sources from PubMed, medRxiv, ClinicalTrials, Exa
4. Show gap analysis between rounds
5. Provide comprehensive synthesis

## Saved Reports

All research sessions are automatically saved to `./research-logs/`:

```
research-logs/
├── research_2025-01-31_14-23-45.json      # Complete data
└── research_2025-01-31_14-23-45.md        # Human-readable report
```

## Replay Past Sessions

```bash
npm run dev -- replay ./research-logs/research_2025-01-31_14-23-45.json
```

## Troubleshooting

### "Connection Refused" Error

**Problem:** Cannot connect to Firebase emulator

**Solution:**
1. Check if emulator is running: `lsof -i :5001`
2. Start emulator: `cd ../functions && npm run serve`
3. Wait for "functions initialized" message

### "Module not found" Error

**Problem:** Missing dependencies

**Solution:**
```bash
npm install
npm run build
```

### Emulator Shows Wrong URL

**Problem:** Default config points to wrong emulator URL

**Solution:** Create `research-xray.config.json`:
```json
{
  "firebaseFunctions": {
    "emulator": true,
    "emulatorUrl": "http://127.0.0.1:5001/YOUR-PROJECT/us-central1/diabetesAssistantStream"
  }
}
```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Explore [CLI-TOOL.md](../CLI-TOOL.md) for the complete specification
- Try different query types to see different tiers in action
- Experiment with verbose mode: `npm run dev -- --verbose`

## Common Query Examples

### Tier 1 (Model-only)
- "A1C nedir?"
- "İnsülin nasıl çalışır?"
- "Diyabetik tiramisu tarifi"

### Tier 2 (Web Search)
- "Metformin yan etkilerini araştır"
- "SGLT2 inhibitörleri araştır"
- "Bu bilgiyi internetten araştır"

### Tier 3 (Deep Research)
- "Metformin yan etkileri derinlemesine araştır"
- "GLP-1 agonistleri kapsamlı araştır"
- "Beta hücre rejenerasyonu dikkatlice araştır"

## Support

For issues or questions:
1. Check the [README.md](README.md) troubleshooting section
2. Review Firebase Functions logs: `cd ../functions && npm run logs`
3. Enable verbose mode for more details: `npm run dev -- --verbose`

---

**Ready to debug the research pipeline? Let's go! 🚀**
