"use strict";
/**
 * Intent Classification System for Diabetes Assistant
 *
 * Classifies user messages to determine what type of context is needed:
 * - immediate: Last few messages in current conversation
 * - session: Current session context
 * - historical: Previous sessions and long-term memory
 * - vectorSearch: Semantic similarity search across all messages
 *
 * This optimization reduces costs by only retrieving relevant context.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifyMessageIntent = classifyMessageIntent;
const genkit_instance_1 = require("./genkit-instance");
const providers_1 = require("./providers");
/**
 * Classify user message to determine intent and required context
 * Uses Gemini Flash Lite for fast, cost-effective classification
 *
 * @param message - User's message to classify
 * @returns MessageIntent with category and context requirements
 */
async function classifyMessageIntent(message) {
    try {
        const classifierModel = (0, providers_1.getClassifierModel)();
        const classificationPrompt = `Sen bir mesaj analiz uzmanısın. Kullanıcı mesajını analiz ederek hangi tür yanıt ve bağlam gerektirdiğini belirle.

Mesaj: "${message}"

Aşağıdaki kategorilerden birini seç:
1. "greeting" - Basit selamlaşma (Günaydın, Merhaba, Nasılsın, vb.)
2. "health_query" - Sağlık/diyabet ile ilgili soru veya bilgi talebi
3. "memory_recall" - Geçmiş konuşmaları hatırlatma ("hatırlıyor musun", "daha önce konuştuk", vb.)
4. "follow_up" - Mevcut konuya devam etme ("peki ya", "bir de", "ayrıca", vb.)
5. "general" - Diğer genel konuşma

JSON formatında yanıt ver:
{
  "category": "kategori_adı",
  "confidence": 0.95,
  "keywords": ["anahtar", "kelimeler"],
  "contextNeeded": {
    "immediate": true,
    "session": false,
    "historical": false,
    "vectorSearch": false
  },
  "reasoning": "Kısa açıklama"
}

Kurallar:
- Selamlaşmalar (kısa, tek kelime) → immediate: true, session: false
- YENİ sağlık sorusu (farklı konu, bağımsız soru, "nedir?", "nasıl?" gibi) → immediate: true, session: false, vectorSearch: true
- DEVAM EDEN sağlık sorusu (aynı konuda devam, "peki", "ayrıca", "bir de" gibi bağlayıcılar) → immediate: true, session: true, vectorSearch: false
- Hatırlama istekleri ("hatırlıyor musun", "daha önce", "geçen") → session: true, historical: true, vectorSearch: true
- Genel konuşma → immediate: true, session: true

ÖNEMLİ: Emin değilsen YENİ konu olarak işaretle (session: false). Yanlış bağlam aktarımı yapmaktansa yeni başlamak daha iyi.

Sadece JSON yanıt ver, başka bir şey yazma.`;
        const response = await genkit_instance_1.ai.generate({
            model: classifierModel,
            prompt: classificationPrompt,
            config: {
                temperature: 0.1,
                maxOutputTokens: 300
            }
        });
        const responseText = response.text.trim();
        console.log(`🔍 [CLASSIFY] Raw response for "${message.substring(0, 50)}...": ${responseText.substring(0, 100)}...`);
        // Parse JSON response
        try {
            const intent = JSON.parse(responseText);
            console.log(`🎯 [CLASSIFY] Message: "${message.substring(0, 50)}..." → ` +
                `Category: ${intent.category} (confidence: ${intent.confidence.toFixed(2)}), ` +
                `Context: ${JSON.stringify(intent.contextNeeded)}`);
            return intent;
        }
        catch (parseError) {
            console.warn(`⚠️ [CLASSIFY] Failed to parse JSON, using fallback for "${message.substring(0, 50)}..."`, parseError);
            return createFallbackIntent(message);
        }
    }
    catch (error) {
        console.error(`❌ [CLASSIFY] Intent classification failed for "${message.substring(0, 50)}...":`, error);
        return createFallbackIntent(message);
    }
}
/**
 * Create fallback intent using simple keyword matching
 * Used when LLM classification fails
 *
 * @param message - User's message
 * @returns MessageIntent with basic classification
 */
function createFallbackIntent(message) {
    // Simple fallback logic based on keywords
    const lowerMessage = message.toLowerCase().trim();
    // Turkish greetings (keep short to avoid false positives)
    const turkishGreetings = ['günaydın', 'merhaba', 'selam', 'nasılsın', 'naber', 'iyi misin'];
    // Memory recall keywords
    const memoryKeywords = ['hatırla', 'daha önce', 'geçen', 'konuştuk', 'söylemiştim'];
    // Health/diabetes keywords
    const healthKeywords = ['şeker', 'kan', 'insülin', 'diyabet', 'glikoz', 'ölçüm', 'kahvaltı', 'yemek'];
    // Check for greetings (must be short to be a greeting)
    if (turkishGreetings.some(greeting => lowerMessage.includes(greeting) && lowerMessage.length < 15)) {
        return {
            category: 'greeting',
            confidence: 0.8,
            keywords: [lowerMessage],
            contextNeeded: {
                immediate: true,
                session: false,
                historical: false,
                vectorSearch: false
            },
            reasoning: 'Basit selamlaşma tespit edildi (fallback)'
        };
    }
    // Check for memory recall
    if (memoryKeywords.some(keyword => lowerMessage.includes(keyword))) {
        return {
            category: 'memory_recall',
            confidence: 0.7,
            keywords: memoryKeywords.filter(k => lowerMessage.includes(k)),
            contextNeeded: {
                immediate: true,
                session: true,
                historical: true,
                vectorSearch: true
            },
            reasoning: 'Hafıza hatırlatma anahtar kelimesi bulundu (fallback)'
        };
    }
    // Check for health queries
    if (healthKeywords.some(keyword => lowerMessage.includes(keyword))) {
        // CRITICAL: Default to NEW topic (session: false) for safety
        // This prevents context bleeding - better to err on side of fresh session
        return {
            category: 'health_query',
            confidence: 0.7,
            keywords: healthKeywords.filter(k => lowerMessage.includes(k)),
            contextNeeded: {
                immediate: true,
                session: false, // ✅ CHANGED: Default to new topic to prevent context bleeding
                historical: false,
                vectorSearch: true
            },
            reasoning: 'Sağlık anahtar kelimesi bulundu (fallback, yeni konu varsayıldı)'
        };
    }
    // Default: general conversation
    return {
        category: 'general',
        confidence: 0.5,
        keywords: [],
        contextNeeded: {
            immediate: true,
            session: true,
            historical: false,
            vectorSearch: false
        },
        reasoning: 'Genel kategori (fallback)'
    };
}
//# sourceMappingURL=intent-classifier.js.map