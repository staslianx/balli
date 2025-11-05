/**
 * Latents Reflector - Reflection Phase with Extended Thinking
 * Uses Gemini 2.0 Flash Thinking (Latents) to evaluate evidence quality
 */

import { ai } from '../genkit-instance';
import { ResearchReflection, RoundResult } from '../flows/deep-research-v2-types';
import { logger } from 'firebase-functions/v2';

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
export async function reflectOnResearchQuality(
  question: string,
  roundNumber: number,
  currentRound: RoundResult,
  allPreviousRounds: RoundResult[],
  maxRounds: number
): Promise<ResearchReflection> {
  const startTime = Date.now();

  const allRounds = [...allPreviousRounds, currentRound];
  const totalSources = allRounds.reduce((sum, r) => sum + r.sourceCount, 0);

  logger.info(
    `🧠 [LATENTS-REFLECTOR] Starting reflection for Round ${roundNumber}: ` +
    `${currentRound.sourceCount} sources this round, ${totalSources} total`
  );

  try {
    // Build summary of what we've found so far
    const roundsSummary = allRounds.map(r => {
      const sources = r.sources;
      return `Round ${r.roundNumber}: ${r.sourceCount} sources (PubMed: ${sources.pubmed.length}, medRxiv: ${sources.medrxiv.length}, Trials: ${sources.clinicalTrials.length}, Exa: ${sources.exa.length})`;
    }).join('\n');

    // Extract source details for evaluation
    const sourceDetails: string[] = [];
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

    const response = await ai.generate({
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
IMPORTANT: For Tier 3 (DEEP_RESEARCH), we aim for comprehensive evidence gathering across multiple rounds.

SOURCE QUANTITY REQUIREMENTS (Tier 3):
- Round 1: Even with 9+ high-quality sources, CONTINUE if < 20 sources (incomplete coverage)
- Round 2+: CONTINUE if < 30 total sources AND gaps exist AND evidence not "high"
- Only STOP early if: 30+ sources gathered OR (high quality AND no gaps AND 15+ sources)

STOPPING CONDITIONS (ALL must be true to stop before max rounds):
1. Evidence quality = "high" (authoritative medical sources)
2. AND total sources >= 15 (minimum comprehensive threshold for T3)
3. AND no critical gaps identified
4. OR max rounds reached
5. OR no new sources found (diminishing returns)

CONTINUE if ANY of these:
- Total sources < 15 (not comprehensive enough for T3)
- Evidence quality = "low"/"medium" (need better sources)
- Critical gaps exist (missing key information)
- Round 1 and sources < 20 (T3 should do multiple rounds)

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

**CRITICAL CONTEXT FOR DECISION:**
- Current round: ${roundNumber}/${maxRounds}
- Total sources collected: ${totalSources}
- This is TIER 3 (DEEP_RESEARCH) - we aim for comprehensive multi-round research
- Minimum threshold: 15 sources (stop early only if quality high + no gaps + 15+ sources)
- Target threshold: 20-30 sources for comprehensive coverage
- Round 1 with < 20 sources: SHOULD CONTINUE (T3 needs multiple rounds)

Assess:
1. Evidence quality (low/medium/high) - based on source types and coverage
2. Knowledge gaps still present - what SPECIFIC diabetes-relevant information is missing?
3. Should we continue research? - MUST consider:
   - If Round 1 and < 20 sources → CONTINUE (T3 needs comprehensive coverage)
   - If < 15 total sources → CONTINUE (below minimum threshold)
   - If high quality + no gaps + 15+ sources → CAN STOP
   - If medium/low quality → CONTINUE (need better evidence)
4. Reasoning - explain decision based on source quantity, quality, and gaps

Return JSON with: evidenceQuality, gapsIdentified[], shouldContinue, reasoning`
    });

    const duration = Date.now() - startTime;

    // Parse response
    const text = response.text?.trim() || '';

    // Remove markdown code blocks if present
    let jsonText = text;
    if (text.startsWith('```json')) {
      jsonText = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    } else if (text.startsWith('```')) {
      jsonText = text.replace(/```\n?/g, '').trim();
    }

    let reflection: ResearchReflection;

    try {
      reflection = JSON.parse(jsonText);
    } catch (parseError) {
      logger.error(`❌ [LATENTS-REFLECTOR] Failed to parse JSON response. Raw: ${text.substring(0, 200)}`);
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

    // SAFETY OVERRIDE 1: Never continue past max rounds
    if (roundNumber >= maxRounds) {
      reflection.shouldContinue = false;
      reflection.reasoning += ` (Max rounds ${maxRounds} reached)`;
    }

    // SAFETY OVERRIDE 2: Stop if no sources found this round (diminishing returns)
    if (currentRound.sourceCount === 0) {
      reflection.shouldContinue = false;
      reflection.reasoning += ' (No new sources found)';
    }

    // SAFETY OVERRIDE 3: Force continue if Round 1 with < 20 sources (T3 needs comprehensive coverage)
    if (roundNumber === 1 && totalSources < 20 && roundNumber < maxRounds) {
      reflection.shouldContinue = true;
      reflection.reasoning = `Round 1 with only ${totalSources} sources - continuing for comprehensive T3 research. ` + reflection.reasoning;
      logger.info(
        `⚠️ [LATENTS-REFLECTOR] OVERRIDE: Forcing continue for Round 1 with ${totalSources} sources (T3 minimum: 20)`
      );
    }

    // SAFETY OVERRIDE 4: Force continue if < 15 total sources (below minimum threshold)
    if (totalSources < 15 && roundNumber < maxRounds && currentRound.sourceCount > 0) {
      reflection.shouldContinue = true;
      reflection.reasoning = `Only ${totalSources} sources collected - below T3 minimum threshold (15). ` + reflection.reasoning;
      logger.info(
        `⚠️ [LATENTS-REFLECTOR] OVERRIDE: Forcing continue with ${totalSources} sources (T3 minimum: 15)`
      );
    }

    logger.info(
      `✅ [LATENTS-REFLECTOR] Reflection complete in ${duration}ms: ` +
      `quality=${reflection.evidenceQuality}, continue=${reflection.shouldContinue}, ` +
      `gaps=[${reflection.gapsIdentified.slice(0, 3).join(', ')}${reflection.gapsIdentified.length > 3 ? '...' : ''}]`
    );

    return reflection;

  } catch (error: any) {
    const duration = Date.now() - startTime;
    logger.error(`❌ [LATENTS-REFLECTOR] Reflection failed after ${duration}ms:`, error);

    // Fallback: Continue if under max rounds, otherwise stop
    logger.warn(`⚠️ [LATENTS-REFLECTOR] Using fallback reflection logic`);
    return {
      evidenceQuality: 'medium',
      gapsIdentified: ['Reflection evaluation failed'],
      shouldContinue: roundNumber < maxRounds && currentRound.sourceCount > 0,
      reasoning: `Reflection failed due to error. Continuing: ${roundNumber < maxRounds && currentRound.sourceCount > 0}`
    };
  }
}
