"use strict";
/**
 * Query Translator - Translate Turkish medical queries to English
 * for PubMed, arXiv, and ClinicalTrials.gov searches
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.translateToEnglishForAPIs = translateToEnglishForAPIs;
const genkit_instance_1 = require("../genkit-instance");
const v2_1 = require("firebase-functions/v2");
/**
 * Translate Turkish medical query to English
 * Uses fast Flash model for quick translation
 *
 * @param turkishQuery - User's query in Turkish
 * @returns English translation optimized for medical databases
 */
async function translateToEnglishForAPIs(turkishQuery) {
    // CRITICAL LOGGING: Always log entry with console for visibility
    console.log(`🌍 [TRANSLATOR] ENTRY - Query length: ${turkishQuery.length}, First 80 chars: "${turkishQuery.substring(0, 80)}"`);
    // Skip if query is already in English
    if (isLikelyEnglish(turkishQuery)) {
        console.log(`🌍 [TRANSLATOR] Query appears to be English (no Turkish chars), skipping translation`);
        v2_1.logger.info(`🌍 [TRANSLATOR] Query appears to be English, skipping translation`);
        return turkishQuery;
    }
    const startTime = Date.now();
    console.log(`🌍 [TRANSLATOR] Starting translation for Turkish query...`);
    v2_1.logger.info(`🌍 [TRANSLATOR] Translating Turkish query to English: "${turkishQuery.substring(0, 80)}..."`);
    try {
        const response = await genkit_instance_1.ai.generate({
            model: 'vertexai/gemini-2.5-flash',
            config: {
                temperature: 0.3, // Low for consistent translation
                maxOutputTokens: 256
            },
            system: `You are a medical translator. Translate Turkish diabetes/health queries to English medical terminology suitable for searching PubMed, arXiv, and ClinicalTrials.gov.

IMPORTANT RULES:
1. Keep medical terminology precise (e.g., "kan şekeri" → "blood glucose" not "blood sugar")
2. Use standard medical terms (e.g., "retinopathy", "neuropathy", "hyperglycemia")
3. Remove conversational elements (e.g., "araştırmalara göre" → omit)
4. Focus on core medical concepts
5. Return ONLY the English translation, no explanations

EXAMPLES:
Turkish: "Yüksek şekerin göze zararları nelerdir?"
English: "high blood glucose retinopathy diabetic eye complications"

Turkish: "Metformin yan etkileri nelerdir?"
English: "metformin side effects adverse reactions"

Turkish: "Diyabet komplikasyonları ne kadar sürede oluşur?"
English: "diabetes complications onset duration timeline"`,
            prompt: `Translate this Turkish medical query to English for academic database search:

"${turkishQuery}"

Return only the English translation.`
        });
        const translated = response.text.trim();
        const duration = Date.now() - startTime;
        // CRITICAL: Check for empty translation
        if (!translated || translated.length === 0) {
            console.error(`❌ [TRANSLATOR] EMPTY TRANSLATION - response.text was empty! Falling back to original query`);
            v2_1.logger.error(`❌ [TRANSLATOR] Empty translation received, using original query`);
            return turkishQuery;
        }
        console.log(`✅ [TRANSLATOR] SUCCESS in ${duration}ms - Translated: "${translated}"`);
        v2_1.logger.info(`✅ [TRANSLATOR] Translated in ${duration}ms: "${translated}"`);
        return translated;
    }
    catch (error) {
        console.error(`❌ [TRANSLATOR] FAILED: ${error.message} - Falling back to original query`);
        v2_1.logger.error(`❌ [TRANSLATOR] Translation failed: ${error.message}`);
        // Fallback: use original query
        return turkishQuery;
    }
}
/**
 * Simple heuristic to detect if query is likely English
 * Checks for Turkish-specific characters
 */
function isLikelyEnglish(text) {
    // Turkish-specific characters
    const turkishChars = /[çÇğĞıİöÖşŞüÜ]/;
    // If contains Turkish chars, it's Turkish
    if (turkishChars.test(text)) {
        return false;
    }
    // If no Turkish chars, assume English
    return true;
}
//# sourceMappingURL=query-translator.js.map