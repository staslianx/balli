"use strict";
/**
 * Smart Embedding Strategy - PHASE 3
 * Reduces embedding calls by 80-85% while maintaining cross-session memory
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.shouldGenerateEmbedding = shouldGenerateEmbedding;
exports.logEmbeddingDecision = logEmbeddingDecision;
/**
 * Decide if embedding should be generated for this message
 * Goal: Skip intra-session references, generate only for cross-session memory
 */
function shouldGenerateEmbedding(message, messageCount) {
    const messageLower = message.toLowerCase().trim();
    // ============================================
    // CATEGORY 1: ALWAYS SKIP (Trivial)
    // ============================================
    // Greetings
    if (/^(merhaba|selam|hey|hi|günaydın|iyi günler)/i.test(messageLower)) {
        return { shouldGenerate: false, reason: 'greeting' };
    }
    // Acknowledgments
    if (/^(tamam|ok|peki|anladım|teşekkür|sağol|eyvallah)/i.test(messageLower)) {
        return { shouldGenerate: false, reason: 'acknowledgment' };
    }
    // Very short messages
    if (message.length < 10) {
        return { shouldGenerate: false, reason: 'too short' };
    }
    // Simple yes/no
    if (/^(evet|hayır|yok|var)\s*$/i.test(messageLower)) {
        return { shouldGenerate: false, reason: 'simple yes/no' };
    }
    // ============================================
    // CATEGORY 2: ALWAYS SKIP (Intra-session refs)
    // ============================================
    // Turkish pronouns/references - resolved via conversation state
    const intraSessionPatterns = [
        /bunlar/i, // these (plural)
        /onlar/i, // they/those
        /^bu /i, // this
        /^o /i, // that
        /^şu /i, // that (demonstrative)
        /ilk (iki|üç|dört)/i, // first (two|three|four)
        /son (iki|üç)/i, // last (two|three)
        /hangisi/i, // which one
        /bunların/i, // of these
        /onların/i // of those
    ];
    for (const pattern of intraSessionPatterns) {
        if (pattern.test(messageLower)) {
            return { shouldGenerate: false, reason: 'intra-session reference' };
        }
    }
    // ============================================
    // CATEGORY 3: ALWAYS GENERATE (High value)
    // ============================================
    // Explicit cross-session recall
    const recallPatterns = [
        /hatırlıyor musun/i, // do you remember
        /hatırla/i, // remember
        /daha önce/i, // earlier/before
        /geçen (sefer|gün|hafta|ay)/i, // last (time|day|week|month)
        /önceki/i, // previous
        /dün/i, // yesterday
        /söylediğin/i, // what you said
        /söyledim/i // what I said
    ];
    for (const pattern of recallPatterns) {
        if (pattern.test(messageLower)) {
            return { shouldGenerate: true, reason: 'cross-session recall' };
        }
    }
    // Medical data (important for history)
    const medicalPatterns = [
        /\d+\s*(mg\/dl|mmol)/i, // Blood sugar
        /\d+\s*ünite/i, // Insulin units
        /\d+\s*(gram|gr)\s*karbonhidrat/i, // Carb counts
        /a1c.*\d+/i, // A1C values
        /\d+\s*(dakika|saat)\s*(önce|sonra)/i // Timing
    ];
    for (const pattern of medicalPatterns) {
        if (pattern.test(messageLower)) {
            return { shouldGenerate: true, reason: 'medical data' };
        }
    }
    // Medication mentions (critical for history)
    const medicationPatterns = [
        /novorapid/i, /lantus/i, /metformin/i, /insülin/i,
        /ilaç/i, /hap/i, /enjekte/i
    ];
    for (const pattern of medicationPatterns) {
        if (pattern.test(messageLower)) {
            return { shouldGenerate: true, reason: 'medication mention' };
        }
    }
    // ============================================
    // CATEGORY 4: MILESTONE EMBEDDINGS
    // ============================================
    // Every 10th message (snapshot)
    if (messageCount > 0 && messageCount % 10 === 0) {
        return { shouldGenerate: true, reason: `milestone (${messageCount}th message)` };
    }
    // First message of session
    if (messageCount === 1) {
        return { shouldGenerate: true, reason: 'first message' };
    }
    // ============================================
    // DEFAULT: SKIP (most messages)
    // ============================================
    return { shouldGenerate: false, reason: 'regular intra-session message' };
}
/**
 * Log embedding decision for monitoring
 */
function logEmbeddingDecision(decision, message) {
    const preview = message.length > 50 ? message.substring(0, 50) + '...' : message;
    if (decision.shouldGenerate) {
        console.log(`✅ [EMBED-DECISION] GENERATE: "${preview}" (${decision.reason})`);
    }
    else {
        console.log(`⏭️ [EMBED-DECISION] SKIP: "${preview}" (${decision.reason})`);
    }
}
//# sourceMappingURL=embedding-strategy.js.map