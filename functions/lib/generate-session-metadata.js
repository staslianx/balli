"use strict";
/**
 * Session Metadata Generation - LLM-powered title, summary, and key topics extraction
 *
 * Generates semantic metadata for completed research sessions using Gemini Flash.
 * Single LLM call produces all three fields (more efficient than 3 separate calls).
 *
 * Input: conversationHistory array (last 20 messages)
 * Output: { title, summary, keyTopics }
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateSessionMetadata = void 0;
const https_1 = require("firebase-functions/v2/https");
const genkit_instance_1 = require("./genkit-instance");
const providers_1 = require("./providers");
exports.generateSessionMetadata = (0, https_1.onRequest)({
    cors: true,
    maxInstances: 10,
    memory: '512MiB',
    timeoutSeconds: 60
}, async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        const { conversationHistory, userId } = req.body;
        // Validate input
        if (!conversationHistory || conversationHistory.length === 0) {
            res.status(400).json({
                success: false,
                error: 'Missing or empty conversationHistory'
            });
            return;
        }
        if (!userId) {
            res.status(400).json({
                success: false,
                error: 'Missing userId'
            });
            return;
        }
        // Limit to last 20 messages to prevent token overflow
        const limitedHistory = conversationHistory.slice(-20);
        console.log(`📝 [METADATA] Generating for user ${userId}, ${limitedHistory.length} messages`);
        // Format conversation for LLM
        const conversationText = limitedHistory
            .map((msg) => {
            const role = msg.role === 'user' ? 'Kullanıcı' : 'Asistan';
            return `${role}: ${msg.content}`;
        })
            .join('\n\n');
        // Structured prompt for metadata extraction
        const prompt = `Aşağıdaki tıbbi diyabet araştırma konuşmasını analiz et ve JSON formatında metadata oluştur:

${conversationText}

JSON formatı (SADECE bu JSON'ı döndür, başka açıklama YOK):
{
  "title": "Kısa, özlü başlık (max 60 karakter, Türkçe)",
  "summary": "2-3 cümlelik özet (ana bulgular ve sonuçlar, Türkçe)",
  "keyTopics": ["anahtar konu 1", "anahtar konu 2", "anahtar konu 3"]
}

Kurallar:
- Başlık tıbbi terimler içermeli (örn: "Dawn Phenomenon ve Kortizol İlişkisi")
- Özet: Kullanıcının ne öğrendiğini vurgula
- Key topics: 3-5 tane tıbbi kavram (Dawn phenomenon, insülin direnci, vs)
- SADECE JSON döndür, markdown ya da açıklama ekleme`;
        // Call Gemini Flash with low temperature for factual extraction
        const result = await genkit_instance_1.ai.generate({
            model: (0, providers_1.getFlashModel)(),
            config: {
                temperature: 0.2,
                maxOutputTokens: 512
            },
            prompt: prompt
        });
        // Parse JSON response (clean markdown code blocks if present)
        const cleanedText = result.text
            .replace(/```json\n?/g, '')
            .replace(/```\n?/g, '')
            .trim();
        let metadata;
        try {
            metadata = JSON.parse(cleanedText);
        }
        catch (parseError) {
            console.error('❌ [METADATA] Failed to parse LLM JSON:', cleanedText.substring(0, 200));
            throw new Error('Invalid JSON from LLM');
        }
        // Validate structure
        if (!metadata.title || !metadata.summary || !Array.isArray(metadata.keyTopics)) {
            console.error('❌ [METADATA] Invalid metadata structure:', metadata);
            throw new Error('Missing required metadata fields');
        }
        // Enforce constraints
        const processedMetadata = {
            title: metadata.title.substring(0, 60), // Enforce 60 char limit
            summary: metadata.summary,
            keyTopics: metadata.keyTopics.slice(0, 5) // Max 5 topics
        };
        console.log(`✅ [METADATA] Generated: "${processedMetadata.title}"`);
        console.log(`📝 [METADATA] Topics: ${processedMetadata.keyTopics.join(', ')}`);
        res.json({
            success: true,
            data: processedMetadata
        });
    }
    catch (error) {
        console.error('❌ [METADATA] Generation failed:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Metadata generation failed'
        });
    }
});
//# sourceMappingURL=generate-session-metadata.js.map