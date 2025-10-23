/**
 * Latents Planner - Planning Phase with Extended Thinking
 * Uses Gemini 2.0 Flash Thinking (Latents) for strategic research planning
 */

import { ai } from '../genkit-instance';
import { ResearchPlan } from '../flows/deep-research-v2-types';
import { logger } from 'firebase-functions/v2';

/**
 * Use Latents (extended thinking) to analyze query and plan research strategy
 *
 * @param question - User's research query
 * @returns ResearchPlan with estimated rounds, strategy, and focus areas
 */
export async function planResearchStrategy(question: string): Promise<ResearchPlan> {
  const startTime = Date.now();

  logger.info(`🧠 [LATENTS-PLANNER] Starting research planning for query: "${question.substring(0, 100)}..."`);

  try {
    // Use Gemini 2.5 Pro for strategic planning (per spec)
    // Pro model provides deep medical reasoning for optimal research strategy
    const response = await ai.generate({
      model: 'vertexai/gemini-2.5-pro',
      config: {
        temperature: 0.2, // Reduced from 0.7 for consistent research strategies
        maxOutputTokens: 4096
      },
      system: `You are a medical research strategist. Analyze health/medical research queries and plan optimal multi-round research strategies.

Your goal: Determine how many research rounds are needed (1-4) and what strategy to use.

QUERY COMPLEXITY GUIDELINES:
- Simple (1-2 rounds): Well-defined single topic, basic factual questions
  Examples: "What is metformin?", "Normal blood sugar ranges"

- Moderate (2-3 rounds): Multi-faceted questions, comparisons, recent updates
  Examples: "Ozempic vs Mounjaro for weight loss", "Latest CGM technology 2025"

- Complex (3-4 rounds): Cutting-edge research, multiple conditions, comprehensive analysis
  Examples: "Emerging treatments for LADA diabetes", "Drug interactions with immunotherapy"

RESEARCH STRATEGIES:
- "Broad initial scan": Start wide, then narrow based on findings
- "Targeted deep dive": Focus immediately on specific high-quality sources
- "Comparative analysis": Fetch sources for each item being compared in parallel
- "Temporal synthesis": Prioritize recent studies, then historical context

FOCUS AREAS: Specific topics/aspects to investigate (max 5)

Return ONLY valid JSON (no markdown, no code blocks):
{
  "estimatedRounds": <number 1-4>,
  "strategy": "<strategy description>",
  "focusAreas": ["<area1>", "<area2>", ...]
}`,
      prompt: `Analyze this health/medical research query: "${question}"

Determine:
1. Query complexity (simple/moderate/complex)
2. Estimated rounds needed (1-4)
3. Research strategy (broad scan vs. targeted dive vs. comparative vs. temporal)
4. Focus areas to prioritize (specific topics to investigate)

Return JSON with: estimatedRounds, strategy, focusAreas[]`
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

    let plan: ResearchPlan;

    try {
      plan = JSON.parse(jsonText);
    } catch (parseError) {
      logger.error(`❌ [LATENTS-PLANNER] Failed to parse JSON response. Raw: ${text.substring(0, 200)}`);
      // Fallback plan
      plan = {
        estimatedRounds: 2,
        strategy: 'Broad initial scan followed by targeted deep dive',
        focusAreas: ['clinical evidence', 'safety data', 'mechanism of action']
      };
    }

    // Validate and constrain
    plan.estimatedRounds = Math.max(1, Math.min(4, plan.estimatedRounds));

    if (!Array.isArray(plan.focusAreas) || plan.focusAreas.length === 0) {
      plan.focusAreas = ['medical evidence', 'clinical outcomes'];
    }

    // Limit focus areas to 5
    plan.focusAreas = plan.focusAreas.slice(0, 5);

    logger.info(
      `✅ [LATENTS-PLANNER] Planning complete in ${duration}ms: ` +
      `${plan.estimatedRounds} rounds, strategy="${plan.strategy}", ` +
      `focus=[${plan.focusAreas.join(', ')}]`
    );

    return plan;

  } catch (error: any) {
    const duration = Date.now() - startTime;
    logger.error(`❌ [LATENTS-PLANNER] Planning failed after ${duration}ms:`, error);

    // Return fallback plan
    logger.warn(`⚠️ [LATENTS-PLANNER] Using fallback 2-round plan`);
    return {
      estimatedRounds: 2,
      strategy: 'Standard two-round research with initial broad scan and targeted follow-up',
      focusAreas: ['primary evidence', 'clinical data', 'safety information']
    };
  }
}
