# Cost Tracking Implementation - Complete Analysis & Index

**Analysis Date**: November 2, 2025
**Project**: Balli - Diabetes Assistant with Recipe & Medical Research
**Scope**: Firebase Cloud Functions cost tracking system design

---

## Document Index

This analysis consists of 4 comprehensive documents that form a complete implementation guide:

### 1. **COST_TRACKING_SUMMARY.md** (START HERE)
- High-level overview of findings
- Key statistics and architecture
- What's missing (gap analysis)
- 4-week implementation roadmap
- Quick reference for function locations
- **Best for**: Getting a quick understanding of the entire system

### 2. **COST_TRACKING_ANALYSIS.md** (COMPREHENSIVE REFERENCE)
- Detailed current Cloud Functions setup (8 functions)
- Complete model usage patterns
- Provider configuration (Google AI vs Vertex AI)
- Current logging & monitoring implementation
- Firestore structure
- Model pricing reference
- Complete implementation roadmap
- **Best for**: Deep dive into architecture and design

### 3. **CLOUD_FUNCTIONS_FILE_STRUCTURE.md** (DETAILED FILE GUIDE)
- Complete directory structure
- Purpose and size of each file
- Key statistics
- Compiled output structure
- Configuration files
- **Best for**: Understanding which file does what and where to find it

### 4. **COST_TRACKING_IMPLEMENTATION.md** (EXECUTION GUIDE)
- Exact line numbers for modifications
- File-by-file implementation points
- Firestore schema designs with full structure
- Model pricing table (ready to hardcode)
- Budget limits configuration
- Code snippets and examples
- Testing strategy
- **Best for**: Actually implementing the cost tracking system

---

## Quick Facts

### Current State
- 8 exported Cloud Functions
- 3 Genkit flows
- 15+ research tools
- Partial token tracking exists (Tier 3 only)
- No persistent cost database
- No cost attribution or dashboards
- No budget alerts

### What We Need
- Comprehensive cost tracking for all functions
- Firestore collections for storage
- Daily aggregation
- Budget monitoring
- Cost dashboard endpoint

### Key Files to Modify
1. `/functions/src/index.ts` (6 functions)
2. `/functions/src/diabetes-assistant-stream.ts` (streaming chat)
3. `/functions/src/nutrition-extractor.ts` (vision API)

### New Files to Create
1. `/functions/src/services/cost-tracker.ts`
2. `/functions/src/types/cost-tracking.ts`
3. `/functions/src/utils/cost-monitor.ts`

---

## Implementation Timeline

### Week 1: Foundation
- Create cost-tracker.ts service
- Define Firestore schemas
- Add console logging

### Week 2: Core Functions
- Instrument 6 functions in index.ts
- Implement Firestore writes
- Basic testing

### Week 3: Complex Functions
- Instrument diabetes-assistant-stream.ts
- Enhance deep-research-v2.ts tracking
- Track Exa API costs

### Week 4: Monitoring
- Cost dashboard endpoint
- Daily aggregation
- Budget alerts
- Reporting tools

---

## Key Findings

### Models in Use
- **Tier 1**: Gemini 2.5 Flash-Lite (classification)
- **Tier 1-2**: Gemini 2.5 Flash (knowledge + search)
- **Tier 3**: Gemini 2.5 Pro (medical research)
- **Vision**: Gemini 2.5 Flash (image analysis)
- **Image Gen**: Imagen 4.0 Ultra (recipe photos)
- **Embedding**: Gemini Embedding 001 (768-3072D)

### Current Costs (Estimated)
- Flash models: $0.075/1M input, $0.3/1M output
- Pro model: $3/1M input, $12/1M output
- Imagen: ~$0.0025 per 2K image
- Embedding: $0.00002 per 1K embeddings

### Existing Token Extraction
Located in `/functions/src/diabetes-assistant-stream.ts` (lines 985-992):
```typescript
const outputTokens = usageMetadata?.candidatesTokenCount || 0;
const inputTokens = usageMetadata?.promptTokenCount || 0;
const totalTokens = usageMetadata?.totalTokenCount || 0;
```

---

## How to Use These Documents

### For Project Managers
1. Read: COST_TRACKING_SUMMARY.md (full overview)
2. Focus on: Implementation roadmap section
3. Timeline: 4 weeks, phased approach

### For Implementation Engineers
1. Read: COST_TRACKING_SUMMARY.md (context)
2. Reference: COST_TRACKING_IMPLEMENTATION.md (line numbers, code)
3. Navigate: COST_TRACKING_ANALYSIS.md (detailed info)
4. Organize: CLOUD_FUNCTIONS_FILE_STRUCTURE.md (file map)

### For Code Review
1. Check: COST_TRACKING_IMPLEMENTATION.md (what should be modified)
2. Verify: All 4 documents for completeness
3. Validate: Model pricing and Firestore schemas match

### For Troubleshooting
1. Location: CLOUD_FUNCTIONS_FILE_STRUCTURE.md (find the file)
2. Implementation: COST_TRACKING_IMPLEMENTATION.md (exact changes)
3. Details: COST_TRACKING_ANALYSIS.md (deep dive)

---

## Key Statistics

- **Total TypeScript files in src/**: 28+
- **Total source lines of code**: 30,000+
- **Exported Cloud Functions**: 8
- **Genkit flows defined**: 3+
- **Research tools**: 15+
- **Prompt files**: 4 (.prompt) + 3 (TypeScript)
- **Supported providers**: 2 (Google AI, Vertex AI)
- **Supported models**: 8+ different models

---

## Critical Implementation Points

### High Priority
1. **index.ts** (6 functions) - Main revenue drivers
2. **diabetes-assistant-stream.ts** - Most complex, highest value
3. **nutrition-extractor.ts** - Direct API, easy to instrument

### Medium Priority
1. **deep-research-v2.ts** - Multi-phase tracking
2. **exa-search.ts** - External paid API
3. **rate-limiter.ts** - Already cost-aware

### Low Priority
1. Research tools (pubmed, medrxiv, etc.) - Free APIs
2. Utilities - Support functions

---

## Success Criteria

After implementation, the system should:

✓ Track cost for every API call
✓ Store data in Firestore for 12+ months
✓ Provide daily cost summaries
✓ Alert when budgets are exceeded
✓ Enable per-user cost attribution
✓ Support cost analysis by feature
✓ Calculate ROI for each tier
✓ Identify optimization opportunities

---

## Expected Outcomes

### Cost Visibility
- Daily cost breakdowns by tier
- Cost per function
- Cost per user
- Cost trends over time

### Budget Control
- Alert at 80% of daily budget
- Block at 100% of daily budget
- Monthly summary reports
- Anomaly detection

### Optimization Data
- Which functions are most expensive
- Tier distribution (T1 vs T2 vs T3 usage)
- Token efficiency metrics
- Response time vs cost correlation

---

## References

- Google Cloud Pricing: https://cloud.google.com/generative-ai/pricing
- Genkit Documentation: https://cloud.google.com/genkit/docs
- Firebase Firestore: https://firebase.google.com/docs/firestore

---

## Next Steps

1. Read COST_TRACKING_SUMMARY.md for overview
2. Review COST_TRACKING_IMPLEMENTATION.md for exact code locations
3. Create cost-tracker.ts service
4. Instrument index.ts functions (Week 1-2)
5. Test with sample requests
6. Gradually add complex functions (Week 3+)

---

**All analysis documents are in the project root directory:**
- `COST_TRACKING_SUMMARY.md`
- `COST_TRACKING_ANALYSIS.md`
- `CLOUD_FUNCTIONS_FILE_STRUCTURE.md`
- `COST_TRACKING_IMPLEMENTATION.md`
- `COST_TRACKING_INDEX.md` (this file)

