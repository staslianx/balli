```
Create a CLI tool in my Firebase functions project that compares Tier 3 research responses between gemini-2.5-pro and gemini-2.5-flash.

Requirements:

1. **Location**: `/functions/src/scripts/compare-t3-models.ts`

2. **Functionality**:
   - Accept a diabetes research query as CLI argument
   - Run the FULL T3 research flow twice in parallel:
     * Once with gemini-2.5-pro (current production)
     * Once with gemini-2.5-flash (test)
   - Use the SAME 25 research sources for both (fetch once, use twice)
   - Use identical system prompts, temperature (0.15), max output tokens,and user message construction
   - Only difference: the model

3. **Output comparison**:
   - Side-by-side markdown file showing:
     * Query
     * Sources used (list once, shared)
     * Pro response (full text)
     * Flash response (full text)
     * Timing: Pro latency vs Flash latency
     * Cost estimate: Pro cost vs Flash cost
     * Subjective notes section (empty for me to fill in)
   - Save to `/functions/test-results/t3-comparison-YYYY-MM-DD-HHmm.md`

4. **Integration**:
   - Import actual research flow functions from production code
   - Use real API calls (PubMed, medRxiv, ClinicalTrials)
   - Don't mock anything - this is production testing
   - Reuse: query analyzer, source fetcher, prompt builders

5. **NPM script**:
   - Add to package.json: `"compare-t3": "ts-node src/scripts/compare-t3-models.ts"`

6. **Usage**:
   ```bash
   cd functions
   npm run compare-t3 "Ketoasidoz nedir?Nasıl önlerim? derinleş"
   npm run compare-t3 "Ketoasidoz nedir?Nasıl önlerim? derinleş"
   ```

7. **Important**: Wire into ACTUAL production T3 flow, don't rebuild it. Import and reuse existing functions.

Project structure context:
- Research flow is in `/functions/src/flows/`
- Source fetching is in `/functions/src/tools/`
- System prompts are in `/functions/src/research-prompts.ts`
- Model configs are in `/functions/src/config/providers.ts`
```
