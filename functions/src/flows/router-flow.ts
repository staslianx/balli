/**
 * Router Flow - Decides between T1, T2, and T3
 *
 * NEW 3-TIER SYSTEM:
 * - T1 (tier 1): Model-only responses with Flash (40% of queries)
 * - T2 (tier 2): Hybrid Research with Flash + thinking + 10 sources (40% of queries)
 * - T3 (tier 3): Deep Research with Pro + 25+ sources - USER CONTROLLED ONLY (20% of queries)
 *
 * Uses simple string matching for tier determination:
 * - Contains "derinleş" → T3 (Deep Research)
 * - Contains "araştır" → T2 (Hybrid Research)
 * - Everything else → T1 (Model-only)
 */

export interface RouterInput {
  question: string;
  userId: string;
  diabetesProfile?: {
    type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
    medications?: string[];
  };
  conversationHistory?: Array<{ role: string; content: string }>;
}

export interface RouterOutput {
  tier: 0 | 1 | 2 | 3; // 0 = RECALL, 1 = MODEL, 2 = HYBRID_RESEARCH, 3 = DEEP_RESEARCH
  reasoning: string;
  confidence: number;
  explicitDeepRequest?: boolean; // NEW: Flag for user-requested T3
  isRecallRequest?: boolean; // NEW: Flag for recall from past sessions
  searchTerms?: string; // NEW: Extracted search terms for recall queries
}

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


/**
 * Detects if user query is asking about past research sessions
 * Checks for Turkish past-tense patterns, memory phrases, and reference words
 */
function detectRecallIntent(question: string): boolean {
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
function extractSearchTerms(question: string): string {
  let cleanedQuery = question;

  // Remove filler words
  FILLER_WORDS.forEach(filler => {
    const regex = new RegExp(filler, 'gi');
    cleanedQuery = cleanedQuery.replace(regex, '');
  });

  // Trim and return
  return cleanedQuery.trim();
}


export async function routeQuestion(input: RouterInput): Promise<RouterOutput> {
    console.log(`🔀 [ROUTER] Classifying question for user ${input.userId}`);

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

    // STEP 1: Simple string matching for tier determination (case-insensitive)
    const questionLower = input.question.toLowerCase();
    let tier: 0 | 1 | 2 | 3 = 1; // Default to T1
    let reasoning = 'Default tier - model-only response';
    let explicitDeepRequest = false;

    // Check for T3 (Deep Research) - highest priority
    if (questionLower.includes('derinleş')) {
      tier = 3;
      reasoning = 'Kullanıcı "derinleş" kelimesini kullandı - deep research';
      explicitDeepRequest = true;
      console.log('✅ [ROUTER] T3 detected: User said "derinleş" - activating deep research');
    }
    // Check for T2 (Hybrid Research) - if not T3
    else if (questionLower.includes('araştır')) {
      tier = 2;
      reasoning = 'Kullanıcı "araştır" kelimesini kullandı - hybrid research';
      console.log('✅ [ROUTER] T2 detected: User said "araştır" - activating hybrid research');
    }
    // Default T1 (Model-only)
    else {
      console.log('✅ [ROUTER] T1 (default): No research keywords found - model-only response');
    }

    const duration = Date.now() - startTime;
    console.log(`✅ [ROUTER] Classified as Tier ${tier} in ${duration}ms`);

    return {
      tier,
      reasoning,
      confidence: 1.0, // Simple string matching has perfect confidence
      explicitDeepRequest: explicitDeepRequest || undefined
    };
}

