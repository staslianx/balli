"use strict";
/**
 * Router Flow - Decides between T1, T2, and T3
 *
 * NEW 3-TIER SYSTEM:
 * - T1 (tier 1): Model-only responses with Flash (40% of queries)
 * - T2 (tier 2): Hybrid Research with Flash + thinking + 10 sources (40% of queries)
 * - T3 (tier 3): Deep Research with Pro + 25+ sources - USER CONTROLLED ONLY (20% of queries)
 *
 * Uses Gemini 2.5 Flash Lite for fast, accurate routing
 * Cost: $0.0001 per call
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.routeQuestion = routeQuestion;
const providers_1 = require("../providers");
const genkit_instance_1 = require("../genkit-instance");
// Router configuration for 3-tier system
// T1 is the default tier - T2 only activates when user says "araştır"
// RECALL DETECTION PATTERNS (Turkish language patterns for past conversation retrieval)
// These patterns detect when user is asking about previous research sessions
const RECALL_PATTERNS = {
    // Past tense verb forms
    pastTense: [
        /neydi/i, /ne\s+konuşmuştuk/i, /ne\s+araştırmıştık/i, /ne\s+bulmuştuk/i,
        /ne\s+öğrenmiştik/i, /ne\s+demiştik/i, /ne\s+çıkmıştı/i, /nasıldı/i
    ],
    // Memory/recall phrases
    memoryPhrases: [
        /hatırlıyor\s+musun/i, /hatırla/i, /hatırlat\s+bana/i, /hatırlamıyorum/i,
        /daha\s+önce/i, /geçen\s+sefer/i, /o\s+zaman/i, /geçenlerde/i
    ],
    // Reference phrases (demonstratives with past context)
    referencePhrases: [
        /o\s+şey/i, /şu\s+konu/i, /o\s+araştırma/i, /o\s+bilgi/i,
        /şu\s+.*\s+ile\s+ilgili\s+olan/i
    ]
};
// Filler words to remove when extracting search terms
const FILLER_WORDS = [
    'o şey', 'şu', 'neydi', 'nasıldı',
    'hatırlıyor musun', 'hatırla', 'hatırlat',
    'daha önce', 'geçen', 'o zaman'
];
// T2 Hybrid Research triggers (safety, side effects, interactions, current guidelines)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const T2_TRIGGER_PATTERNS = [
    // Safety / decision language
    /meli miyim/i, /güvenli mi/i, /ne yapmalıyım/i, /yapmalı mıyım/i, /should i/i, /is it safe/i,
    // Medical reasoning
    /neden/i, /sebebi ne/i, /yan etki/i, /etkileş(ir|imi)/i, /doz(\s|\w)*değiş(im|tirmek)/i,
    // Medication and treatment terms (common Turkish + brand names)
    /insülin/i, /metformin/i, /sglt2/i, /glp-1/i, /lantus/i, /tresiba/i, /novorapid/i,
    /doz/i, /dosing/i, /contraindication/i, /kontrendike/i,
    // Clinical research language (but not explicit deep research)
    /clinical trial/i, /klinik deneme/i, /\btrial(s)?\b/i,
    /beta cell/i, /beta hücre/i,
    /araştır/i, /araştırma/i, /çalışma/i, /son gelişme/i, /güncel/i,
    /202[4-6]/i, /latest/i,
    // Verification requests (NEW: triggers T2 for fact-checking)
    /kontrol\s+(et|eder)/i, /bir\s+kontrol/i,
    /internetten.*bak/i, /internetten.*bakar/i, /internetten.*baksana/i,
    /doğru\s+mu/i, /kontrol\s+eder\s+misin/i
];
// T3 Deep Research triggers - disabled while T3 is deactivated
// const T3_EXPLICIT_TRIGGERS: RegExp[] = [
//   /derinlemesine\s+araştır/i,
//   /derinlemesine\s+.*araştırma/i,
//   /dikkatlice\s+araştır/i,
//   /kapsamlı\s+araştır/i,
//   /kapsamlı\s+.*araştırma/i,
//   /detaylı\s+araştır/i,
//   /detaylı\s+.*araştırma/i,
//   /thoroughly\s+research/i,
//   /comprehensive\s+research/i,
//   /in-depth\s+research/i,
//   /deep\s+research/i,
//   /deep\s+dive/i
// ];
/**
 * Detects if user query is asking about past research sessions
 * Checks for Turkish past-tense patterns, memory phrases, and reference words
 */
function detectRecallIntent(question) {
    const allPatterns = [
        ...RECALL_PATTERNS.pastTense,
        ...RECALL_PATTERNS.memoryPhrases,
        ...RECALL_PATTERNS.referencePhrases
    ];
    return allPatterns.some(pattern => pattern.test(question));
}
/**
 * Extracts meaningful search terms by removing filler words
 * Returns cleaned query for FTS search
 */
function extractSearchTerms(question) {
    let cleanedQuery = question;
    // Remove filler words
    FILLER_WORDS.forEach(filler => {
        const regex = new RegExp(filler, 'gi');
        cleanedQuery = cleanedQuery.replace(regex, '');
    });
    // Trim and return
    return cleanedQuery.trim();
}
// T2 trigger matching - kept for potential future use
// Currently not used since T2 is the default tier
// function matchesT2Triggers(text: string): boolean {
//   return T2_TRIGGER_PATTERNS.some((re) => re.test(text));
// }
// T3 trigger matching - disabled while T3 is deactivated
// function matchesT3Triggers(text: string): boolean {
//   return T3_EXPLICIT_TRIGGERS.some((re) => re.test(text));
// }
/**
 * Few-shot examples for 3-tier classification (Turkish examples)
 * Based on TIER_SYSTEM_REDESIGN_PLAN.md specification
 */
const FEW_SHOT_EXAMPLES = `
T1 (MODEL) ÖRNEKLER - Varsayılan tier, çoğu soru için:
Soru: "A1C nedir?"
Tier: 1
Gerekçe: Temel tanım sorusu. Model doğrudan cevaplayabilir.

Soru: "İnsülin nasıl çalışır?"
Tier: 1
Gerekçe: Zamansız bilgi, model bilgisiyle cevaplanır.

Soru: "Diyabetik tiramisu tarifi"
Tier: 1
Gerekçe: Tarif sorusu, model birçok tarif bilir.

Soru: "Badem unu şekeri ne kadar yükseltir?"
Tier: 1
Gerekçe: Genel beslenme bilgisi, model bilgisiyle cevaplanır.

Soru: "Lantus'tan Tresiba'ya geçmeli miyim?"
Tier: 1
Gerekçe: İlaç sorusu ama kullanıcı "araştır" demedi - model bilgisiyle cevaplanır.

Soru: "Sabah şekerim neden hep yüksek oluyor?"
Tier: 1
Gerekçe: Kullanıcı "araştır" demedi - model genel bilgisiyle cevaplayabilir.

Soru: "Metformin yan etkileri nelerdir?"
Tier: 1
Gerekçe: Genel soru, kullanıcı "araştır" demedi - model cevaplayabilir.

T2 (HYBRID RESEARCH) ÖRNEKLER - SADECE "araştır" kelimesi kullanılırsa:
Soru: "Yulaf ekmeği tarifi araştır"
Tier: 2
Gerekçe: Kullanıcı açıkça "araştır" dedi - T2 ile web kaynaklarından araştırma yapılmalı.

Soru: "Metformin yan etkilerini araştır"
Tier: 2
Gerekçe: "araştır" kelimesi var - hybrid research ile güncel kaynaklardan bilgi getirilmeli.

Soru: "SGLT2 inhibitörleri araştır"
Tier: 2
Gerekçe: "araştır" kelimesi kullanıldı - web araştırması yapılmalı.

Soru: "Bu bilgiyi internetten araştır"
Tier: 2
Gerekçe: Kullanıcı web araştırması talep etti - T2 ile kaynak kontrolü yapılmalı.

T3 (DEEP RESEARCH) ÖRNEKLER - SADECE explicit kullanıcı isteği:
Soru: "Metformin yan etkileri derinlemesine araştır"
Tier: 3
ExplicitDeepRequest: true
Gerekçe: Kullanıcı açıkça "derinlemesine araştır" istedi - 25 kaynaklı deep research.

Soru: "GLP-1 agonistleri kapsamlı araştır"
Tier: 3
ExplicitDeepRequest: true
Gerekçe: Kullanıcı açıkça "kapsamlı araştır" istedi - Pro model + 25 kaynak.

Soru: "Beta hücre rejenerasyonu dikkatlice araştır"
Tier: 3
ExplicitDeepRequest: true
Gerekçe: Kullanıcı açıkça "dikkatlice araştır" istedi - maksimum deep research.

Soru: "İnsülin rezistansı hakkında derinlemesine bir araştırma yap"
Tier: 3
ExplicitDeepRequest: true
Gerekçe: "derinlemesine bir araştırma" ifadesi T3 tetikleyici - comprehensive research.

Soru: "SGLT2 inhibitörleri hakkında detaylı araştırma yap"
Tier: 3
ExplicitDeepRequest: true
Gerekçe: "detaylı araştırma" ifadesi açık bir deep research isteği.
`;
const SYSTEM_PROMPT = `You are routing a diabetes question for Dilara using the 2-TIER SYSTEM.

TIER SELECTION LOGIC (T3 CURRENTLY DISABLED):

T1 (MODEL - DEFAULT):
- Definitions, facts, how things work
- Food, recipes, cooking methods
- Lifestyle tips (exercise, travel, stress)
- General diabetes education
- Simple practical questions
- Model: Gemini 2.5 Flash

T2 (HYBRID RESEARCH - Only when user explicitly says "araştır"):
- When user explicitly says "araştır" (research/investigate)
- User wants current web sources and evidence
- User asks to verify information online
- Model: Gemini 2.5 Flash + thinking + 10 sources (5 Exa + 5 API)

NOTE: T3 (DEEP RESEARCH) is currently DISABLED. Do NOT select tier 3 - only choose tier 1 or tier 2.

KEY PRINCIPLE: Default to T1 (MODEL) for all questions. ONLY use T2 when user explicitly says "araştır" or clearly requests web research.

${FEW_SHOT_EXAMPLES}

Respond with ONLY valid JSON in this format:
{
  "tier": 1 or 2 (DO NOT USE 3 - T3 is disabled),
  "reasoning": "Why you chose this tier (Turkish)",
  "confidence": 0.0 to 1.0
}`;
async function routeQuestion(input) {
    console.log(`🔀 [ROUTER] Classifying question for user ${input.userId}`);
    // Note: T2_TRIGGER_PATTERNS kept for documentation (shows "araştır" and related keywords)
    if (false) {
        console.log('T2 triggers available:', T2_TRIGGER_PATTERNS.length);
    }
    // Log conversation history if present
    if (input.conversationHistory && input.conversationHistory.length > 0) {
        console.log(`🧠 [ROUTER-MEMORY] Conversation history available: ${input.conversationHistory.length} messages`);
    }
    const startTime = Date.now();
    // STEP 0: Check for recall intent (FIRST PRIORITY - before tier routing)
    // Detects queries like "Dawn ile karışan etki neydi?" (past research recall)
    if (detectRecallIntent(input.question)) {
        const searchTerms = extractSearchTerms(input.question);
        console.log(`📚 [ROUTER] RECALL DETECTED - search terms: "${searchTerms}"`);
        return {
            tier: 0, // Special tier for recall
            reasoning: 'Kullanıcı geçmiş bir araştırmayı hatırlamaya çalışıyor',
            confidence: 1.0,
            isRecallRequest: true,
            searchTerms: searchTerms
        };
    }
    try {
        // Create user prompt with diabetes profile context if available
        let userPrompt = `Question: "${input.question}"`;
        if (input.diabetesProfile) {
            userPrompt += `\n\nUser Context:
- Diabetes Type: ${input.diabetesProfile.type}`;
            if (input.diabetesProfile.medications && input.diabetesProfile.medications.length > 0) {
                userPrompt += `\n- Medications: ${input.diabetesProfile.medications.join(', ')}`;
            }
        }
        // Add conversation context summary if available
        if (input.conversationHistory && input.conversationHistory.length > 0) {
            const lastUserMessage = input.conversationHistory
                .slice()
                .reverse()
                .find(msg => msg.role === 'user');
            if (lastUserMessage) {
                userPrompt += `\n\nPrevious Question: "${lastUserMessage.content}"`;
            }
        }
        userPrompt += `\n\nClassify this question and respond with JSON.`;
        const result = await genkit_instance_1.ai.generate({
            model: (0, providers_1.getRouterModel)(),
            config: {
                temperature: 0.1, // Very low for consistent classification
                maxOutputTokens: 256
            },
            system: SYSTEM_PROMPT,
            prompt: userPrompt
        });
        const responseText = result.text;
        console.log(`📊 [ROUTER] Raw response: ${responseText}`);
        // Parse JSON response
        let classification;
        try {
            // Clean markdown code blocks if present
            const cleanedText = responseText
                .replace(/```json\n?/g, '')
                .replace(/```\n?/g, '')
                .trim();
            classification = JSON.parse(cleanedText);
        }
        catch (parseError) {
            console.error('❌ [ROUTER] JSON parse failed, using fallback to Tier 1 (MODEL)');
            classification = {
                tier: 1,
                reasoning: 'Classification failed, defaulting to MODEL tier',
                confidence: 0.5
            };
        }
        // Validate tier value (1 = MODEL, 2 = HYBRID_RESEARCH, 3 = DEEP_RESEARCH)
        if (![1, 2, 3].includes(classification.tier)) {
            console.warn(`⚠️ [ROUTER] Invalid tier ${classification.tier}, defaulting to 1 (MODEL)`);
            classification.tier = 1;
        }
        // Guardrail 1: T3 DEACTIVATED - Always downgrade to T2
        // T3 code remains for future reactivation but is currently disabled
        if (classification.tier === 3) {
            console.log('🔽 [ROUTER] T3 DEACTIVATED: Downgrading T3 → T2 (T3 currently disabled)');
            classification.tier = 2;
            classification.explicitDeepRequest = false;
            // Original T3 logic (commented for future reactivation):
            // const hasExplicitTrigger = matchesT3Triggers(input.question);
            // if (!hasExplicitTrigger) {
            //   console.log('🔽 [ROUTER] Downgrading T3 → T2: No explicit deep research request found');
            //   classification.tier = 2;
            //   classification.explicitDeepRequest = false;
            // } else {
            //   classification.explicitDeepRequest = true;
            //   console.log('✅ [ROUTER] T3 approved: Explicit deep research request detected');
            // }
        }
        // Guardrail 2: Downgrade T2 to T1 if user didn't say "araştır"
        // Only activate T2 if user explicitly requests research
        const hasArastirKeyword = /araştır/i.test(input.question);
        if (classification.tier === 2 && !hasArastirKeyword) {
            console.log('🔽 [ROUTER] Downgrading T2 → T1: User did not say "araştır"');
            classification.tier = 1;
        }
        const duration = Date.now() - startTime;
        console.log(`✅ [ROUTER] Classified as Tier ${classification.tier} (${classification.confidence.toFixed(2)} confidence) in ${duration}ms`);
        return classification;
    }
    catch (error) {
        console.error('❌ [ROUTER] Classification error:', error);
        // Safe fallback to Tier 1 (MODEL)
        return {
            tier: 1,
            reasoning: 'Router error occurred, using MODEL tier as default',
            confidence: 0.5
        };
    }
}
//# sourceMappingURL=router-flow.js.map