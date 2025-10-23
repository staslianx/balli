"use strict";
/**
 * Latents Reflector - Reflection Phase with Extended Thinking
 * Uses Gemini 2.0 Flash Thinking (Latents) to evaluate evidence quality
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.reflectOnResearchQuality = reflectOnResearchQuality;
const genkit_instance_1 = require("../genkit-instance");
const v2_1 = require("firebase-functions/v2");
/**
 * Use Latents to evaluate evidence quality and decide if more research is needed
 *
 * @param question - Original research query
 * @param roundNumber - Current round number
 * @param currentRound - Results from current round
 * @param allPreviousRounds - Results from all previous rounds
 * @param maxRounds - Maximum rounds allowed
 * @returns ResearchReflection with quality assessment and continuation decision
 */
async function reflectOnResearchQuality(question, roundNumber, currentRound, allPreviousRounds, maxRounds) {
    const startTime = Date.now();
    const allRounds = [...allPreviousRounds, currentRound];
    const totalSources = allRounds.reduce((sum, r) => sum + r.sourceCount, 0);
    v2_1.logger.info(`🧠 [LATENTS-REFLECTOR] Starting reflection for Round ${roundNumber}: ` +
        `${currentRound.sourceCount} sources this round, ${totalSources} total`);
    try {
        // Build summary of what we've found so far
        const roundsSummary = allRounds.map(r => {
            const sources = r.sources;
            return `Round ${r.roundNumber}: ${r.sourceCount} sources (PubMed: ${sources.pubmed.length}, medRxiv: ${sources.medrxiv.length}, Trials: ${sources.clinicalTrials.length}, Exa: ${sources.exa.length})`;
        }).join('\n');
        // Extract source details for evaluation
        const sourceDetails = [];
        for (const round of allRounds) {
            for (const article of round.sources.pubmed) {
                sourceDetails.push(`PubMed: "${article.title}" (PMID: ${article.pmid || 'unknown'})`);
            }
            for (const paper of round.sources.medrxiv) {
                sourceDetails.push(`medRxiv: "${paper.title}" (${paper.doi || 'preprint'})`);
            }
            for (const trial of round.sources.clinicalTrials) {
                sourceDetails.push(`Trial: "${trial.title}" (${trial.status || 'unknown status'})`);
            }
            for (const exa of round.sources.exa) {
                sourceDetails.push(`Web: "${exa.title}" (${new URL(exa.url).hostname})`);
            }
        }
        const sourceSample = sourceDetails.slice(0, 15).join('\n'); // Limit for prompt size
        const response = await genkit_instance_1.ai.generate({
            model: 'vertexai/gemini-2.5-flash',
            config: {
                temperature: 0.2, // Reduced from 0.7 for deterministic evidence evaluation
                maxOutputTokens: 4096
            },
            system: `You are a medical research quality evaluator for a DIABETES SUPPORT APP. Assess evidence quality from research rounds and decide if more research is needed.

CRITICAL APP CONTEXT:
- This is a diabetes management app (balli)
- Users ask diabetes-related questions
- When users ask about general medical topics (e.g., "What is ketoacidosis?"), focusing on DIABETIC-SPECIFIC aspects is CORRECT and EXPECTED
- Do NOT penalize research for being "too focused" on diabetic conditions - that's exactly what users need
- Example: For "Ketoasidoz nedir?" focusing on diabetic ketoacidosis (DKA) is appropriate, not a limitation

EVIDENCE QUALITY LEVELS:
- "high": Multiple peer-reviewed studies, clinical trials, authoritative medical sources. Comprehensive coverage of the topic IN THE CONTEXT OF DIABETES.
- "medium": Some peer-reviewed evidence, but gaps exist. Mix of high-quality and general sources.
- "low": Mostly general web sources, limited peer-reviewed evidence, or outdated information.

CONTINUATION DECISION LOGIC:
- STOP if: Evidence quality = "high" OR all key aspects covered FOR DIABETES CONTEXT OR max rounds reached
- STOP if: No new sources found (diminishing returns)
- CONTINUE if: Evidence quality = "low"/"medium" AND gaps exist AND rounds < max

KNOWLEDGE GAPS: Identify specific missing information types (DIABETES-RELEVANT):
- "Limited peer-reviewed evidence"
- "No recent studies (past 2 years)"
- "Missing safety/efficacy data for diabetes patients"
- "Incomplete mechanism of action in diabetes context"
- "No clinical trial data for diabetic patients"
- "Lack of long-term outcome studies in diabetes"

IMPORTANT: Do NOT identify as gaps:
- "Not enough non-diabetic ketoacidosis information" (when user asks about ketoacidosis in a diabetes app)
- "Too focused on diabetes" (this IS a diabetes app)
- Missing information about conditions unrelated to diabetes management

Return ONLY valid JSON (no markdown, no code blocks):
{
  "evidenceQuality": "<low|medium|high>",
  "gapsIdentified": ["<gap1>", "<gap2>", ...],
  "shouldContinue": <true|false>,
  "reasoning": "<brief explanation>"
}`,
            prompt: `Evaluate research quality for Round ${roundNumber}/${maxRounds}:

Query: "${question}"

${roundsSummary}

Sample sources found (first 15):
${sourceSample}

Total sources so far: ${totalSources}

Assess:
1. Evidence quality (low/medium/high) - based on source types and coverage
2. Knowledge gaps still present - what specific information is missing?
3. Should we continue research? - consider quality, gaps, and rounds remaining
4. Reasoning - why continue or stop?

Return JSON with: evidenceQuality, gapsIdentified[], shouldContinue, reasoning`
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
        let reflection;
        try {
            reflection = JSON.parse(jsonText);
        }
        catch (parseError) {
            v2_1.logger.error(`❌ [LATENTS-REFLECTOR] Failed to parse JSON response. Raw: ${text.substring(0, 200)}`);
            // Fallback reflection - continue if under max rounds and evidence not high
            reflection = {
                evidenceQuality: 'medium',
                gapsIdentified: ['Unable to evaluate specific gaps'],
                shouldContinue: roundNumber < maxRounds && totalSources < 15,
                reasoning: 'Reflection parsing failed, using heuristic: continue if under max rounds and sources < 15'
            };
        }
        // Validate evidence quality
        if (!['low', 'medium', 'high'].includes(reflection.evidenceQuality)) {
            reflection.evidenceQuality = 'medium';
        }
        // Ensure gapsIdentified is array
        if (!Array.isArray(reflection.gapsIdentified)) {
            reflection.gapsIdentified = [];
        }
        // Override: Never continue past max rounds
        if (roundNumber >= maxRounds) {
            reflection.shouldContinue = false;
            reflection.reasoning += ` (Max rounds ${maxRounds} reached)`;
        }
        // Override: Stop if no sources found this round
        if (currentRound.sourceCount === 0) {
            reflection.shouldContinue = false;
            reflection.reasoning += ' (No new sources found)';
        }
        v2_1.logger.info(`✅ [LATENTS-REFLECTOR] Reflection complete in ${duration}ms: ` +
            `quality=${reflection.evidenceQuality}, continue=${reflection.shouldContinue}, ` +
            `gaps=[${reflection.gapsIdentified.slice(0, 3).join(', ')}${reflection.gapsIdentified.length > 3 ? '...' : ''}]`);
        return reflection;
    }
    catch (error) {
        const duration = Date.now() - startTime;
        v2_1.logger.error(`❌ [LATENTS-REFLECTOR] Reflection failed after ${duration}ms:`, error);
        // Fallback: Continue if under max rounds, otherwise stop
        v2_1.logger.warn(`⚠️ [LATENTS-REFLECTOR] Using fallback reflection logic`);
        return {
            evidenceQuality: 'medium',
            gapsIdentified: ['Reflection evaluation failed'],
            shouldContinue: roundNumber < maxRounds && currentRound.sourceCount > 0,
            reasoning: `Reflection failed due to error. Continuing: ${roundNumber < maxRounds && currentRound.sourceCount > 0}`
        };
    }
}
//# sourceMappingURL=latents-reflector.js.map