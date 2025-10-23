"use strict";
/**
 * Reference Pattern Detector
 *
 * Detects which of the 20 linguistic reference categories
 * are present in a user's message using pattern matching.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.detectReferences = detectReferences;
exports.getPrimaryReference = getPrimaryReference;
exports.getRequiredLayers = getRequiredLayers;
/**
 * Turkish pronoun patterns
 */
const PRONOUN_PATTERNS = {
    // Possessive pronouns (Category 1 indicators)
    possessive: /\b(bunların|onun|bunun|şunun|onu|bunu|şunu)\b/i,
    // Demonstrative (Category 2)
    demonstrative: /\b(bu|şu|o)\s+\w+/i,
    // Ordinal references (Category 6, 17)
    ordinal: /\b(ilki|ikincisi|üçüncüsü|sonuncusu|ilk\s+\w+|ikinci\s+\w+)\b/i
};
/**
 * Ellipsis patterns (Category 1)
 */
const ELLIPSIS_PATTERNS = {
    // Question word alone or with minimal context
    questionOnly: /^(ya|peki|nasıl|neden|ne\s+zaman|nerede)\??$/i,
    // Short questions without subject
    shortQuestion: /^(ne\s+kadar|kaç\s+(tane|birim|gram)|yeterli\s+mi|iyi\s+mi|olur\s+mu)\??$/i,
    // Modal without action
    modalOnly: /^(yapmalı\s+mıyım|gerekli\s+mi|zorunda\s+mıyım)\??$/i
};
/**
 * Comparative patterns (Category 3)
 */
const COMPARATIVE_PATTERNS = {
    more: /\b(daha\s+(fazla|az|çok|iyi|kötü))\b/i,
    comparison: /\b(farkı|fark|benzeri|alternatif)\b/i,
    other: /\b(başka|diğer|geri\s+kalan)\b/i
};
/**
 * Temporal patterns (Category 4)
 */
const TEMPORAL_PATTERNS = {
    before: /\b(daha\s+önce|geçen|önceki|önce)\b/i,
    after: /\b(sonra|sonraki|daha\s+sonra)\b/i,
    still: /\b(hala|hâlâ)\b/i,
    again: /\b(yine|tekrar)\b/i
};
/**
 * Discourse markers (Category 5)
 */
const DISCOURSE_MARKERS = {
    continuation: /^(peki|tamam|anladım|ama)/i,
    agreement: /\b(katılıyorum|aynen|doğru|öyle)\b/i,
    disagreement: /\b(öyle\s+değil|hayır|yanlış|aksine)\b/i
};
/**
 * AI output reference patterns (Category 6)
 */
const AI_OUTPUT_PATTERNS = {
    mentioned: /\b(söylediğin|dediğin|anlattığın|verdiğin|önerdiğin)\b/i,
    listed: /\b(ilk\s+seçenek|ikinci\s+yöntem|örnek)\b/i
};
/**
 * Causality patterns (Category 12)
 */
const CAUSALITY_PATTERNS = {
    why: /^(neden|niye|ne\s+için)\??$/i,
    cause: /\b(sebebi|nedeni|yüzünden)\b/i
};
/**
 * Evaluation patterns (Category 11)
 */
const EVALUATION_PATTERNS = {
    quality: /\b(iyi|kötü|zararlı|faydalı|etkili|güvenli)\s+mi\b/i,
    appropriateness: /\b(uygun|doğru|normal)\s+m[uıiü]\b/i
};
/**
 * Modal/necessity patterns (Category 13)
 */
const MODAL_PATTERNS = {
    obligation: /\b(gerekli|şart|zorunda|lazım)\s+m[ıiuü]\b/i,
    permission: /\b(olur\s+mu|yapabilir\s+miyim|izin\s+var\s+mı)\b/i
};
/**
 * Process/procedure patterns (Category 14)
 */
const PROCESS_PATTERNS = {
    how: /^nasıl\??$/i,
    steps: /\b(adım|önce|sonra|ilk\s+olarak)\b/i
};
/**
 * Memory recall patterns (Category 20)
 */
const MEMORY_PATTERNS = {
    remember: /\b(hatırlıyor\s+musun|hatırla|geçen\s+konuştuğumuz|hani)\b/i
};
/**
 * Detect reference patterns in user message
 */
function detectReferences(message) {
    const detected = [];
    const lowerMessage = message.toLowerCase();
    // Category 1: Ellipsis
    if (ELLIPSIS_PATTERNS.questionOnly.test(lowerMessage) ||
        ELLIPSIS_PATTERNS.shortQuestion.test(lowerMessage) ||
        ELLIPSIS_PATTERNS.modalOnly.test(lowerMessage)) {
        detected.push({
            type: 'ellipsis',
            pattern: message,
            requiresLayers: ['discourse'],
            confidence: 0.9
        });
    }
    // Category 2/6: Pronouns (could be definite or AI output reference)
    const pronounMatch = PRONOUN_PATTERNS.possessive.exec(lowerMessage);
    if (pronounMatch) {
        detected.push({
            type: 'definite',
            pattern: pronounMatch[0],
            requiresLayers: ['entities', 'discourse'],
            confidence: 0.85
        });
    }
    // Category 3: Comparative
    if (COMPARATIVE_PATTERNS.more.test(lowerMessage) ||
        COMPARATIVE_PATTERNS.comparison.test(lowerMessage) ||
        COMPARATIVE_PATTERNS.other.test(lowerMessage)) {
        const match = COMPARATIVE_PATTERNS.more.exec(lowerMessage) ||
            COMPARATIVE_PATTERNS.comparison.exec(lowerMessage) ||
            COMPARATIVE_PATTERNS.other.exec(lowerMessage);
        detected.push({
            type: 'comparative',
            pattern: match ? match[0] : 'comparative',
            requiresLayers: ['entities', 'discourse'],
            confidence: 0.8
        });
    }
    // Category 4: Temporal
    if (TEMPORAL_PATTERNS.before.test(lowerMessage) ||
        TEMPORAL_PATTERNS.after.test(lowerMessage) ||
        TEMPORAL_PATTERNS.still.test(lowerMessage)) {
        const match = TEMPORAL_PATTERNS.before.exec(lowerMessage) ||
            TEMPORAL_PATTERNS.after.exec(lowerMessage) ||
            TEMPORAL_PATTERNS.still.exec(lowerMessage);
        detected.push({
            type: 'temporal',
            pattern: match ? match[0] : 'temporal',
            requiresLayers: ['discourse', 'entities'],
            confidence: 0.85
        });
    }
    // Category 5: Discourse markers
    if (DISCOURSE_MARKERS.continuation.test(lowerMessage) ||
        DISCOURSE_MARKERS.agreement.test(lowerMessage)) {
        detected.push({
            type: 'discourse_marker',
            pattern: 'discourse_marker',
            requiresLayers: ['discourse'],
            confidence: 0.75
        });
    }
    // Category 6: AI output references
    if (AI_OUTPUT_PATTERNS.mentioned.test(lowerMessage) ||
        AI_OUTPUT_PATTERNS.listed.test(lowerMessage) ||
        PRONOUN_PATTERNS.ordinal.test(lowerMessage)) {
        const match = AI_OUTPUT_PATTERNS.mentioned.exec(lowerMessage) ||
            AI_OUTPUT_PATTERNS.listed.exec(lowerMessage) ||
            PRONOUN_PATTERNS.ordinal.exec(lowerMessage);
        detected.push({
            type: 'ai_output',
            pattern: match ? match[0] : 'ai_output',
            requiresLayers: ['aiOutputs', 'discourse'],
            confidence: 0.9
        });
    }
    // Category 11: Evaluation
    if (EVALUATION_PATTERNS.quality.test(lowerMessage) ||
        EVALUATION_PATTERNS.appropriateness.test(lowerMessage)) {
        const match = EVALUATION_PATTERNS.quality.exec(lowerMessage) ||
            EVALUATION_PATTERNS.appropriateness.exec(lowerMessage);
        detected.push({
            type: 'evaluation',
            pattern: match ? match[0] : 'evaluation',
            requiresLayers: ['discourse', 'entities'],
            confidence: 0.85
        });
    }
    // Category 12: Causality
    if (CAUSALITY_PATTERNS.why.test(lowerMessage) ||
        CAUSALITY_PATTERNS.cause.test(lowerMessage)) {
        const match = CAUSALITY_PATTERNS.why.exec(lowerMessage) ||
            CAUSALITY_PATTERNS.cause.exec(lowerMessage);
        detected.push({
            type: 'causality',
            pattern: match ? match[0] : 'causality',
            requiresLayers: ['discourse'],
            confidence: 0.9
        });
    }
    // Category 13: Modal/Necessity
    if (MODAL_PATTERNS.obligation.test(lowerMessage) ||
        MODAL_PATTERNS.permission.test(lowerMessage)) {
        const match = MODAL_PATTERNS.obligation.exec(lowerMessage) ||
            MODAL_PATTERNS.permission.exec(lowerMessage);
        detected.push({
            type: 'modal',
            pattern: match ? match[0] : 'modal',
            requiresLayers: ['discourse', 'entities'],
            confidence: 0.8
        });
    }
    // Category 14: Process/Procedure
    if (PROCESS_PATTERNS.how.test(lowerMessage) ||
        PROCESS_PATTERNS.steps.test(lowerMessage)) {
        detected.push({
            type: 'process',
            pattern: 'process',
            requiresLayers: ['procedural', 'discourse'],
            confidence: 0.85
        });
    }
    // Category 20: Memory Recall
    if (MEMORY_PATTERNS.remember.test(lowerMessage)) {
        const match = MEMORY_PATTERNS.remember.exec(lowerMessage);
        detected.push({
            type: 'memory_recall',
            pattern: match ? match[0] : 'memory_recall',
            requiresLayers: ['commitments', 'entities', 'aiOutputs'],
            confidence: 0.95
        });
    }
    // If no specific patterns detected, return 'none'
    if (detected.length === 0) {
        detected.push({
            type: 'none',
            pattern: '',
            requiresLayers: [],
            confidence: 1.0
        });
    }
    return detected;
}
/**
 * Get the most salient (highest confidence) reference type
 */
function getPrimaryReference(references) {
    if (references.length === 0) {
        return {
            type: 'none',
            pattern: '',
            requiresLayers: [],
            confidence: 1.0
        };
    }
    // Sort by confidence descending
    return references.sort((a, b) => b.confidence - a.confidence)[0];
}
/**
 * Determine which state layers are needed based on detected references
 */
function getRequiredLayers(references) {
    const layers = new Set();
    for (const ref of references) {
        for (const layer of ref.requiresLayers) {
            layers.add(layer);
        }
    }
    return layers;
}
//# sourceMappingURL=reference-detector.js.map