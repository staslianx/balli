"use strict";
/**
 * Query Refiner - Adaptive Query Refinement Between Rounds
 * Refines search queries based on gaps identified in reflection
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.refineQueryForGaps = refineQueryForGaps;
exports.generateQueryVariations = generateQueryVariations;
const genkit_instance_1 = require("../genkit-instance");
const v2_1 = require("firebase-functions/v2");
/**
 * Refine query based on identified knowledge gaps
 * Uses fast Flash model for quick query generation
 *
 * @param originalQuery - Original user query
 * @param gaps - Knowledge gaps identified in reflection
 * @param roundNumber - Current round number (for logging)
 * @returns Refined query focused on filling gaps
 */
async function refineQueryForGaps(originalQuery, gaps, roundNumber) {
    const startTime = Date.now();
    v2_1.logger.info(`🔄 [QUERY-REFINER] Refining query for Round ${roundNumber}: ` +
        `gaps=[${gaps.slice(0, 3).join(', ')}${gaps.length > 3 ? '...' : ''}]`);
    // If no gaps, return original query
    if (gaps.length === 0) {
        v2_1.logger.debug(`🔄 [QUERY-REFINER] No gaps identified, using original query`);
        return {
            original: originalQuery,
            refined: originalQuery,
            focusArea: 'general evidence',
            reasoning: 'No specific gaps to address'
        };
    }
    try {
        // Use primary gap for focus
        const primaryGap = gaps[0];
        const response = await genkit_instance_1.ai.generate({
            model: 'vertexai/gemini-2.5-flash',
            config: {
                temperature: 0.8, // Higher creativity for query variation
                maxOutputTokens: 512
            },
            system: `You are a medical research query optimizer. Refine search queries to target specific knowledge gaps.

REFINEMENT STRATEGIES:
1. Add temporal constraints: "recent studies 2024-2025", "latest research"
2. Add specificity: "randomized controlled trials", "systematic review", "meta-analysis"
3. Target gap directly: If gap is "safety data" → add "safety", "adverse events", "side effects"
4. Combine terms: Original query + gap-specific terms

EXAMPLES:
- Original: "metformin diabetes"
  Gap: "Limited long-term safety data"
  Refined: "metformin long-term safety cardiovascular outcomes diabetes"

- Original: "GLP-1 agonists"
  Gap: "No recent studies (past 2 years)"
  Refined: "GLP-1 agonists clinical trials 2024 2025 latest research"

- Original: "SGLT2 inhibitors heart failure"
  Gap: "Missing mechanism of action"
  Refined: "SGLT2 inhibitors heart failure mechanism action pathophysiology"

Return ONLY valid JSON (no markdown, no code blocks):
{
  "refined": "<refined query string>",
  "focusArea": "<brief description of focus>",
  "reasoning": "<why this refinement>"
}`,
            prompt: `Refine this medical research query to address knowledge gaps:

Original query: "${originalQuery}"

Knowledge gaps identified:
${gaps.map((g, i) => `${i + 1}. ${g}`).join('\n')}

Primary gap to address: "${primaryGap}"

Generate a refined search query that specifically targets these gaps while maintaining the original intent. The refined query will be used to search PubMed, arXiv, and clinical trial databases.

Return JSON with: refined, focusArea, reasoning`
        });
        const duration = Date.now() - startTime;
        // Parse response
        const text = response.text?.trim() || '';
        // Remove markdown code blocks if present
        let jsonText = text;
        if (text.startsWith('```json')) {
            jsonText = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
        }
        else if (text.startsWith('```')) {
            jsonText = text.replace(/```\n?/g, '').trim();
        }
        let refinement;
        try {
            refinement = JSON.parse(jsonText);
        }
        catch (parseError) {
            v2_1.logger.error(`❌ [QUERY-REFINER] Failed to parse JSON response. Raw: ${text.substring(0, 200)}`);
            // Fallback: Append primary gap to original query
            refinement = {
                refined: `${originalQuery} ${primaryGap}`,
                focusArea: primaryGap,
                reasoning: 'JSON parsing failed, using simple gap append strategy'
            };
        }
        const result = {
            original: originalQuery,
            refined: refinement.refined || originalQuery,
            focusArea: refinement.focusArea || primaryGap,
            reasoning: refinement.reasoning || 'Query refinement for identified gaps'
        };
        // Ensure refined query is not too long (API limits)
        if (result.refined.length > 200) {
            result.refined = result.refined.substring(0, 197) + '...';
        }
        v2_1.logger.info(`✅ [QUERY-REFINER] Query refined in ${duration}ms: ` +
            `"${result.refined.substring(0, 80)}${result.refined.length > 80 ? '...' : ''}" ` +
            `(focus: ${result.focusArea})`);
        return result;
    }
    catch (error) {
        const duration = Date.now() - startTime;
        v2_1.logger.error(`❌ [QUERY-REFINER] Refinement failed after ${duration}ms:`, error);
        // Fallback: Combine original query with primary gap
        const primaryGap = gaps[0];
        v2_1.logger.warn(`⚠️ [QUERY-REFINER] Using fallback gap append strategy`);
        return {
            original: originalQuery,
            refined: `${originalQuery} ${primaryGap}`,
            focusArea: primaryGap,
            reasoning: 'Refinement failed, appending primary gap to original query'
        };
    }
}
/**
 * Generate diverse query variations for initial round
 * Helps avoid getting stuck in narrow search space
 */
async function generateQueryVariations(originalQuery, count = 2) {
    v2_1.logger.debug(`🔄 [QUERY-REFINER] Generating ${count} query variations`);
    try {
        const response = await genkit_instance_1.ai.generate({
            model: 'vertexai/gemini-2.5-flash',
            config: {
                temperature: 0.9, // High creativity for variations
                maxOutputTokens: 512
            },
            system: `You are a medical search query generator. Create semantically similar but syntactically different query variations.

VARIATION STRATEGIES:
- Synonym substitution: "treatment" ↔ "therapy", "drug" ↔ "medication"
- Medical terminology: "heart attack" ↔ "myocardial infarction"
- Order changes: "diabetes medications" ↔ "medications for diabetes"
- Specificity changes: "insulin" ↔ "basal insulin therapy"

Return ONLY a JSON array of ${count} query strings (no markdown, no objects, just strings):
["variation 1", "variation 2", ...]`,
            prompt: `Generate ${count} variations of this medical query: "${originalQuery}"

Each variation should:
1. Maintain the core medical intent
2. Use different phrasing or terminology
3. Be suitable for searching medical databases

Return JSON array of ${count} query strings.`
        });
        const text = response.text?.trim() || '';
        // Remove markdown code blocks if present
        let jsonText = text;
        if (text.startsWith('```json')) {
            jsonText = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
        }
        else if (text.startsWith('```')) {
            jsonText = text.replace(/```\n?/g, '').trim();
        }
        try {
            const variations = JSON.parse(jsonText);
            if (Array.isArray(variations) && variations.length > 0) {
                v2_1.logger.debug(`✅ [QUERY-REFINER] Generated ${variations.length} variations`);
                return variations.slice(0, count);
            }
        }
        catch (parseError) {
            v2_1.logger.warn(`⚠️ [QUERY-REFINER] Failed to parse variations, using original`);
        }
    }
    catch (error) {
        v2_1.logger.error(`❌ [QUERY-REFINER] Variation generation failed:`, error);
    }
    // Fallback: Return original query
    return [originalQuery];
}
//# sourceMappingURL=query-refiner.js.map