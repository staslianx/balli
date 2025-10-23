/**
 * Query Enricher - Adds conversation context to search queries
 *
 * Solves the "when should I do tests?" → HIV results problem
 * by enriching vague queries with conversation context
 */

import { ai } from '../genkit-instance';
import { getRouterModel } from '../providers';

export interface QueryEnrichmentInput {
  currentQuestion: string;
  conversationHistory?: Array<{ role: string; content: string }>;
  diabetesProfile?: {
    type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
    medications?: string[];
  };
}

export interface EnrichedQuery {
  original: string;
  enriched: string;
  reasoning: string;
  contextUsed: boolean;
}

const ENRICHMENT_PROMPT = `You are a query enrichment expert for medical search.

Your job: Take a vague user question and add medical context to make it searchable.

EXAMPLES:

Conversation:
User: "What is ketoacidosis?"
Assistant: "Ketoacidosis is a serious diabetes complication..."
User: "When should I do tests?"

Original Query: "when should I do tests"
Enriched Query: "ketoacidosis testing when to test diabetes type 1"
Reasoning: User is asking about testing in the context of their previous ketoacidosis question.

---

Conversation:
User: "Tell me about metformin"
Assistant: "Metformin is a diabetes medication..."
User: "What are the side effects?"

Original Query: "what are the side effects"
Enriched Query: "metformin side effects diabetes"
Reasoning: User is asking about side effects of metformin from previous context.

---

Conversation:
User: "Should I switch to Tresiba?"
Assistant: "Tresiba is a long-acting insulin..."
User: "Is it safe?"

Original Query: "is it safe"
Enriched Query: "tresiba safety switching from basal insulin diabetes type 1"
Reasoning: User asking about safety of Tresiba insulin switch from previous context.

---

RULES:
1. If question is already specific (has medical terms), return it unchanged
2. If question is vague ("it", "this", "that", "tests", "when", pronouns), add context from conversation
3. Always add diabetes context if diabetes profile is available
4. Keep enriched query concise (5-10 words max)
5. Don't add unnecessary words - only essential medical context

Respond with ONLY valid JSON:
{
  "enriched": "the enriched search query",
  "reasoning": "why you enriched it this way",
  "contextUsed": true or false
}`;

/**
 * Enrich a search query with conversation context
 */
export async function enrichQuery(input: QueryEnrichmentInput): Promise<EnrichedQuery> {
  const startTime = Date.now();

  // Quick check: if question is already specific (has medical terms), skip enrichment
  const hasMedicalTerms = /\b(diabetes|insulin|metformin|ketoacidosis|a1c|glucose|blood sugar|medication|drug|side effect|sglt2|glp-1|basal|bolus)\b/i.test(input.currentQuestion);

  if (hasMedicalTerms && input.currentQuestion.split(' ').length >= 4) {
    console.log('⚡ [QUERY-ENRICHER] Query already specific, skipping enrichment');
    return {
      original: input.currentQuestion,
      enriched: input.currentQuestion,
      reasoning: 'Query already contains medical terms and is sufficiently specific',
      contextUsed: false
    };
  }

  // Build context summary
  let contextSummary = '';

  if (input.conversationHistory && input.conversationHistory.length > 0) {
    // Get last 3 exchanges (6 messages max)
    const recentHistory = input.conversationHistory.slice(-6);
    contextSummary += '\n\nRecent Conversation:\n';
    for (const msg of recentHistory) {
      const role = msg.role === 'user' ? 'User' : 'Assistant';
      // Truncate long messages
      const content = msg.content.length > 150
        ? msg.content.substring(0, 150) + '...'
        : msg.content;
      contextSummary += `${role}: ${content}\n`;
    }
  }

  if (input.diabetesProfile) {
    contextSummary += `\n\nUser Profile: Type ${input.diabetesProfile.type} Diabetes`;
    if (input.diabetesProfile.medications && input.diabetesProfile.medications.length > 0) {
      contextSummary += `, Medications: ${input.diabetesProfile.medications.join(', ')}`;
    }
  }

  const userPrompt = `${contextSummary}

Current Question: "${input.currentQuestion}"

Enrich this query for medical search. Respond with JSON only.`;

  try {
    console.log(`🔍 [QUERY-ENRICHER] Enriching vague query: "${input.currentQuestion}"`);

    const result = await ai.generate({
      model: getRouterModel(), // Fast Flash model
      config: {
        temperature: 0.1,
        maxOutputTokens: 150
      },
      system: ENRICHMENT_PROMPT,
      prompt: userPrompt
    });

    const responseText = result.text;

    // Parse JSON
    let parsed: { enriched: string; reasoning: string; contextUsed: boolean };
    try {
      const cleaned = responseText
        .replace(/```json\n?/g, '')
        .replace(/```\n?/g, '')
        .trim();
      parsed = JSON.parse(cleaned);
    } catch (parseError) {
      console.error('❌ [QUERY-ENRICHER] JSON parse failed, using original query');
      return {
        original: input.currentQuestion,
        enriched: input.currentQuestion,
        reasoning: 'Enrichment failed, using original',
        contextUsed: false
      };
    }

    const duration = Date.now() - startTime;
    console.log(
      `✅ [QUERY-ENRICHER] "${input.currentQuestion}" → "${parsed.enriched}" (${duration}ms)\n` +
      `   Reasoning: ${parsed.reasoning}`
    );

    return {
      original: input.currentQuestion,
      enriched: parsed.enriched,
      reasoning: parsed.reasoning,
      contextUsed: parsed.contextUsed
    };

  } catch (error: any) {
    console.error('❌ [QUERY-ENRICHER] Enrichment error:', error.message);
    return {
      original: input.currentQuestion,
      enriched: input.currentQuestion,
      reasoning: 'Error occurred, using original query',
      contextUsed: false
    };
  }
}
