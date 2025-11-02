# Balli AI Model Usage Reference

Complete reference of all AI models used in Balli, including Gemini, Imagen, and third-party APIs.

---

## 🤖 Google Gemini Models

### 1. **Gemini 2.5 Flash** (`gemini-2.5-flash`)

**Used For**: Fast, cost-effective responses (main processing)

**Locations**:
- ✅ **T1 (Model Tier)** - Direct responses without research
  - File: `diabetes-assistant-stream.ts:246`
  - Function: `streamTier1()`
  - Temperature: 0.1
  - Max tokens: 2,500

- ✅ **T2 (Web Search Tier)** - Synthesis after Exa search
  - File: `diabetes-assistant-stream.ts:431`
  - Function: `streamTier2Hybrid()`
  - Temperature: 0.2
  - Max tokens: 3,000

- ✅ **Router** - Query analysis and tier selection
  - File: `flows/router-flow.ts`
  - Function: `routeQuestion()`
  - Temperature: 0.0
  - Max tokens: 300

- ✅ **Query Enricher** - Context-aware query expansion
  - File: `tools/query-enricher.ts`
  - Function: `enrichQuery()`
  - Temperature: 0.0
  - Max tokens: 150

- ✅ **Query Refiner** - Gap-targeted query refinement (T3)
  - File: `tools/query-refiner.ts`
  - Function: `refineQueryForGaps()`
  - Temperature: 0.0
  - Max tokens: 200

- ✅ **Source Ranker** - AI-powered source relevance scoring (T3)
  - File: `tools/source-ranker.ts`
  - Function: `rankSourcesByRelevance()`
  - Temperature: 0.0
  - Max tokens: 1,000

**Cost**: $0.15 per 1M input tokens, $0.60 per 1M output tokens
**Speed**: ~500ms typical response time
**Context Window**: 1M tokens

---

### 2. **Gemini 2.5 Flash Lite** (`gemini-2.5-flash-lite`)

**Used For**: Ultra-fast query routing and classification

**Locations**:
- ✅ **Router** - Tier selection (T1/T2/T3 decision)
  - File: `flows/router-flow.ts`
  - Function: `routeQuestion()`
  - Temperature: 0.0
  - Max tokens: 300
  - Purpose: Analyze query and select appropriate tier

**Cost**: ~$0.075 per 1M input tokens, ~$0.30 per 1M output tokens (50% cheaper than Flash)
**Speed**: ~200-300ms typical response time
**Why Flash Lite**: Router needs speed over quality - it's just classification

**CLI Display**: When the CLI shows "Gemini 2.0 Flash Lite" during routing, that's correct! The router uses Flash Lite, then the selected tier uses its own model (Flash or Pro).

---

### 3. **Gemini 2.5 Pro** (`gemini-2.5-pro`)

**Used For**: Deep research synthesis with high quality

**Locations**:
- ✅ **T3 (Deep Research Tier)** - Final synthesis after multi-round research
  - File: `diabetes-assistant-stream.ts:666`
  - Function: `streamDeepResearch()`
  - Temperature: 0.15
  - Max tokens: 12,000

- ✅ **Latents Planner** - Research strategy planning (T3)
  - File: `tools/latents-planner.ts`
  - Function: `planResearchStrategy()`
  - Temperature: 1.0
  - Thinking budget: 16,000 tokens
  - Max output tokens: 500

- ✅ **Latents Reflector** - Research quality analysis (T3)
  - File: `tools/latents-reflector.ts`
  - Function: `reflectOnResearchQuality()`
  - Temperature: 1.0
  - Thinking budget: 16,000 tokens
  - Max output tokens: 600

**Cost**: $2.50 per 1M input tokens, $10.00 per 1M output tokens
**Speed**: ~5-10s for synthesis
**Context Window**: 2M tokens
**Special**: Supports extended thinking mode (Latents)

---

### 3. **Gemini 2.0 Flash Thinking Experimental** (DEPRECATED)

**Status**: ❌ No longer used (thinking disabled for cost optimization)

**Previously Used For**:
- T1 responses with extended thinking
- T2 synthesis with reasoning

**Removed**: January 2025
**Reason**: Cost optimization - thinking added $0.02-0.05 per query

---

## 🎨 Google Imagen Models

### **Imagen 3** (`imagen-3.0-generate-001`)

**Used For**: Recipe image generation

**Location**:
- ✅ **Recipe Generator**
  - File: `flows/recipe-ai.ts`
  - Function: `generateRecipeImage()`
  - Parameters:
    - Aspect ratio: 1:1 (square)
    - Safety: BLOCK_MEDIUM_AND_ABOVE
    - Person generation: ALLOW_ADULT

**Cost**: $0.04 per image
**Quality**: High-quality food photography style
**Resolution**: 1024x1024

**Example Prompts**:
```
"Turkish home-style beef stew with vegetables, served in a traditional ceramic bowl,
professional food photography, warm lighting, rustic wooden table"
```

---

## 🔍 External APIs

### 1. **Exa API** (Web Search)

**Used For**: Semantic web search for medical sources

**Locations**:
- ✅ **T2 (Web Search)** - Primary source
  - File: `tools/exa-search.ts`
  - Function: `searchMedicalSources()`
  - Results: 15 sources
  - Type: Neural semantic search
  - Domains: 18 trusted medical domains

- ✅ **T3 (Deep Research)** - Supplementary source
  - File: `flows/deep-research-v2.ts`
  - Round 1: 10 sources
  - Rounds 2-4: 5 sources each

**Configuration**:
- Search type: Neural (semantic)
- Text extraction: 500 chars
- Highlights: 3 sentences
- Trusted domains: See `TRUSTED_MEDICAL_DOMAINS`

**Trusted Domains** (18 total):
- Medical institutions: `mayoclinic.org`, `clevelandclinic.org`, `hopkinsmedicine.org`, `cdc.gov`, `nih.gov`, `who.int`
- Diabetes-specific: `diabetes.org`, `joslin.org`, `jdrf.org`, `diabetesed.net`, `beyondtype1.org`, `diatribe.org`
- International: `idf.org`, `easd.org`
- Journals: `diabetesjournals.org`, `endocrine.org`
- Evidence synthesis: `cochranelibrary.com`

**Cost**: ~$1 per 1,000 searches
**Speed**: 1-2 seconds per search

---

### 2. **PubMed API** (Academic Papers)

**Used For**: Peer-reviewed medical research papers

**Location**:
- ✅ **T3 (Deep Research)** - Primary academic source
  - File: `tools/pubmed-search.ts`
  - Function: `searchPubMed()`
  - Round 1: 10-18 sources
  - Rounds 2-4: 4 sources each

**Configuration**:
- API endpoint: `eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi`
- Filters: Last 5 years, clinical trials/RCTs preferred
- Fields: Title, abstract, authors, journal, PMID, publication date

**Cost**: Free (NCBI public API)
**Speed**: 1-2 seconds per search
**Rate Limit**: 3 requests/second (without API key), 10/second (with key)

---

### 3. **medRxiv API** (Preprints)

**Used For**: Cutting-edge unpublished medical research

**Location**:
- ✅ **T3 (Deep Research)** - Recent findings
  - File: `tools/medrxiv-search.ts`
  - Function: `searchMedRxiv()`
  - Round 1: 2-5 sources
  - Rounds 2-4: 2 sources each

**Configuration**:
- API endpoint: `medrxiv.org/search`
- Filters: Last 12 months
- Fields: Title, abstract, authors, DOI, date

**Cost**: Free (medRxiv public API)
**Speed**: 1-2 seconds per search

---

### 4. **ClinicalTrials.gov API**

**Used For**: Clinical trial data and real-world evidence

**Location**:
- ✅ **T3 (Deep Research)** - Trial evidence
  - File: `tools/clinical-trials.ts`
  - Function: `searchClinicalTrials()`
  - Round 1: 3-8 sources
  - Rounds 2-4: 3 sources each

**Configuration**:
- API endpoint: `clinicaltrials.gov/api/v2/studies`
- Filters: Completed trials with results
- Fields: NCT ID, title, description, sponsor, status, dates

**Cost**: Free (NIH public API)
**Speed**: 2-3 seconds per search

---

## 📊 Model Usage by Tier

### **Tier 0: Memory Recall** (Not implemented)
- No models used
- Direct database lookup

---

### **Tier 1: Model Direct**

**Total Models**: 1
- Gemini 2.5 Flash (response generation)

**Cost per Query**: ~$0.001
**Duration**: 1-2 seconds

**Flow**:
1. Flash: Route → T1
2. Flash: Generate response (with conversation history)

---

### **Tier 2: Web Search**

**Total Models**: 2 Gemini + 1 Exa
- Gemini 2.5 Flash (router, enricher, synthesis)
- Exa (web search)

**Cost per Query**: ~$0.003
**Duration**: 3-5 seconds

**Flow**:
1. Flash: Route → T2
2. Flash: Enrich query (context-aware)
3. Exa: Search 15 medical sources
4. Flash: Synthesize response

---

### **Tier 3: Deep Research**

**Total Models**: 2 Gemini + 4 APIs
- Gemini 2.5 Flash (router, planner reflector, ranker, enricher, refiner)
- Gemini 2.5 Pro (final synthesis with Latents thinking)
- Exa (10-25 sources across rounds)
- PubMed (10-30 sources across rounds)
- medRxiv (2-10 sources across rounds)
- ClinicalTrials (3-15 sources across rounds)

**Cost per Query**: ~$0.03-0.08
**Duration**: 20-60 seconds

**Flow**:
1. Flash: Route → T3
2. **Planning**: Pro + Latents: Plan research strategy
3. **Round 1**:
   - Exa: 10 sources
   - PubMed: 10-18 sources
   - medRxiv: 2-5 sources
   - ClinicalTrials: 3-8 sources
4. **Reflection**: Pro + Latents: Analyze gaps
5. **Rounds 2-4** (if needed):
   - Flash: Refine query for gaps
   - Exa: 5 sources
   - PubMed: 4 sources
   - medRxiv: 2 sources
   - ClinicalTrials: 3 sources
6. **Ranking**: Flash: Score all sources by relevance
7. **Selection**: Select top 25-30 sources
8. **Synthesis**: Pro: Generate comprehensive response

---

## 💰 Cost Breakdown

### Per Query Costs

| Tier | Models | APIs | Total Cost | Duration |
|------|--------|------|------------|----------|
| T1   | 1 Flash | 0 | $0.001 | 1-2s |
| T2   | 2 Flash | 1 (Exa) | $0.003 | 3-5s |
| T3   | Flash + Pro | 4 (Exa + PubMed + medRxiv + Trials) | $0.03-0.08 | 20-60s |

### Cost per Model Operation

**Gemini 2.5 Flash**:
- Router: ~$0.0001
- Enricher: ~$0.0001
- Refiner: ~$0.0001
- Ranker: ~$0.001
- T1 synthesis: ~$0.001
- T2 synthesis: ~$0.002

**Gemini 2.5 Pro**:
- Planner (with thinking): ~$0.005-0.01
- Reflector (with thinking): ~$0.005-0.01
- T3 synthesis: ~$0.02-0.05

**External APIs**:
- Exa search: ~$0.001 per search
- PubMed: Free
- medRxiv: Free
- ClinicalTrials: Free

---

## 🎯 Model Selection Rationale

### Why Gemini 2.5 Flash for T1/T2?
- ✅ **Fast**: 500ms response time
- ✅ **Cheap**: $0.15/$0.60 per 1M tokens (15x cheaper than Pro)
- ✅ **Sufficient**: Good for straightforward queries
- ✅ **Large context**: 1M tokens for conversation history

### Why Gemini 2.5 Pro for T3?
- ✅ **Quality**: Better reasoning and synthesis
- ✅ **Thinking mode**: Latents for complex analysis
- ✅ **Long output**: Up to 12,000 tokens for comprehensive answers
- ✅ **Worth the cost**: Only for user-requested deep research

### Why Multiple APIs for T3?
- ✅ **PubMed**: Gold standard peer-reviewed research
- ✅ **medRxiv**: Cutting-edge pre-publication findings
- ✅ **ClinicalTrials**: Real-world trial evidence
- ✅ **Exa**: Current web information and guidelines

---

## 📝 Configuration Files

### Model Configuration
**File**: `functions/src/providers.ts`

```typescript
export const getTier1Model = () => 'gemini-2.0-flash-exp';
export const getTier2Model = () => 'gemini-2.0-flash-exp';
export const getTier3Model = () => 'gemini-2.0-pro-exp';
```

### API Keys (Environment Variables)
```bash
GOOGLE_GENAI_API_KEY=...     # Gemini models
EXA_API_KEY=...              # Exa search
# PubMed, medRxiv, ClinicalTrials are public APIs (no key needed)
```

---

## 🔄 Model Updates

### Recent Changes

**January 2025**:
- ❌ Removed thinking mode from T1/T2 (cost optimization)
- ✅ Upgraded to Gemini 2.5 Pro for T3 synthesis
- ✅ Added Latents thinking to T3 planning/reflection only

**December 2024**:
- ✅ Switched from Gemini 1.5 to Gemini 2.0
- ✅ Added source ranking with Flash

### Future Considerations

**Potential Upgrades**:
- Gemini 2.5 Flash with thinking for T2 (if cost improves)
- Gemini Ultra (when available) for T3
- Additional medical APIs (Cochrane, UpToDate)

**Cost Watch**:
- Monitor Flash → Pro cost ratio
- Evaluate thinking mode ROI
- Track API rate limits

---

## 📚 Additional Resources

- [Gemini API Pricing](https://ai.google.dev/pricing)
- [Imagen Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [Exa API Docs](https://docs.exa.ai/)
- [PubMed API Guide](https://www.ncbi.nlm.nih.gov/books/NBK25501/)
- [ClinicalTrials.gov API](https://clinicaltrials.gov/data-api/api)

---

## Summary

**Total Models/APIs**: 2 Gemini models + 1 Imagen + 4 external APIs

**Gemini Models**:
1. Gemini 2.5 Flash - Fast/cheap operations (router, enricher, T1, T2)
2. Gemini 2.5 Pro - High-quality synthesis (T3 only)

**Imagen**:
1. Imagen 3 - Recipe image generation

**External APIs**:
1. Exa - Web search (T2, T3)
2. PubMed - Academic papers (T3)
3. medRxiv - Preprints (T3)
4. ClinicalTrials - Trial data (T3)

**Cost Efficiency**:
- T1: $0.001/query (Flash only)
- T2: $0.003/query (Flash + Exa)
- T3: $0.03-0.08/query (Flash + Pro + 4 APIs)

**Speed**:
- T1: 1-2 seconds
- T2: 3-5 seconds
- T3: 20-60 seconds
