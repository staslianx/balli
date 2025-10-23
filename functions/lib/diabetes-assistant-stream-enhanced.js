"use strict";
/**
 * Enhanced Tier 1 Streaming with Comprehensive Reference Resolution
 *
 * This is the enhanced version of streamTier1 that integrates:
 * - Reference detection (20 linguistic categories)
 * - Conversation state extraction (multi-layer)
 * - Reference resolution with explicit guidance
 *
 * TO INTEGRATE: Replace streamTier1 function in diabetes-assistant-stream.ts
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.streamTier1Enhanced = streamTier1Enhanced;
const genkit_instance_1 = require("./genkit-instance");
const providers_1 = require("./providers");
const session_store_1 = require("./session-store");
const intent_classifier_1 = require("./intent-classifier");
const vector_search_1 = require("./vector-search");
const vector_utils_1 = require("./vector-utils");
// NEW IMPORTS for reference resolution
const reference_detector_1 = require("./reference-detector");
const reference_resolver_1 = require("./reference-resolver");
const conversation_state_extractor_1 = require("./conversation-state-extractor");
const conversation_state_1 = require("./types/conversation-state");
/**
 * Stream Tier 1 response with COMPREHENSIVE reference resolution
 */
async function streamTier1Enhanced(res, question, userId, sessionId, writeSSE, diabetesProfile) {
    // ===== STEP 1: Classify intent =====
    const intent = await (0, intent_classifier_1.classifyMessageIntent)(question);
    console.log(`📋 [ENHANCED] Intent: ${intent.category}, session needed: ${intent.contextNeeded.session}`);
    // ===== STEP 2: Load or create session =====
    const sessionStore = new session_store_1.FirestoreSessionStore();
    let session;
    const shouldLoadExistingSession = sessionId && intent.contextNeeded.session;
    if (shouldLoadExistingSession) {
        try {
            session = await genkit_instance_1.ai.loadSession(sessionId, { store: sessionStore });
            // Security check
            if (session && session.state?.userId !== userId) {
                throw new Error('Unauthorized session access');
            }
            if (session) {
                console.log(`📖 [ENHANCED] Loaded session ${sessionId}`);
            }
        }
        catch (error) {
            console.warn(`⚠️ [ENHANCED] Session load failed:`, error);
            session = null;
        }
    }
    if (!session) {
        session = genkit_instance_1.ai.createSession({
            store: sessionStore,
            initialState: {
                userId,
                diabetesProfile,
                conversationStartedAt: new Date(),
                conversationState: (0, conversation_state_1.initializeConversationState)(userId)
            }
        });
        console.log(`🆕 [ENHANCED] Created new session: ${session.id}`);
    }
    // ===== STEP 3: Get or initialize conversation state =====
    let conversationState = session.state?.conversationState || (0, conversation_state_1.initializeConversationState)(userId);
    console.log(`💭 [ENHANCED] State turn count: ${conversationState.turnCount}`);
    // ===== STEP 4: DETECT REFERENCES in user's message =====
    const detectedReferences = (0, reference_detector_1.detectReferences)(question);
    const primaryReference = (0, reference_detector_1.getPrimaryReference)(detectedReferences);
    console.log(`🔍 [ENHANCED] Detected ${detectedReferences.length} reference patterns`);
    if (primaryReference.type !== 'none') {
        console.log(`🎯 [ENHANCED] Primary reference: ${primaryReference.type} (${primaryReference.pattern})`);
    }
    // ===== STEP 5: RESOLVE REFERENCES using conversation state =====
    const resolvedReferences = (0, reference_resolver_1.resolveReferences)(question, detectedReferences, conversationState);
    const referenceGuidance = (0, reference_resolver_1.buildContextGuidance)(resolvedReferences);
    if (referenceGuidance) {
        console.log(`✅ [ENHANCED] Built reference guidance (${referenceGuidance.length} chars)`);
    }
    // ===== STEP 6: Vector search if needed =====
    let vectorContext = '';
    if (intent.contextNeeded.vectorSearch) {
        try {
            writeSSE(res, { type: 'searching_memory', message: 'Geçmiş konuşmalar aranıyor...' });
            const questionEmbedding = await (0, vector_utils_1.generateEmbedding)(question);
            const similarMessages = await (0, vector_search_1.findSemanticallySimilarMessages)({
                userId,
                queryEmbedding: questionEmbedding,
                limit: 5,
                minSimilarity: 0.5
            });
            if (similarMessages.length > 0) {
                vectorContext = (0, vector_search_1.formatVectorContextForPrompt)(similarMessages, 150) + '\n\n';
                console.log(`🎯 [ENHANCED] Found ${similarMessages.length} similar messages`);
            }
        }
        catch (error) {
            console.warn('⚠️ [ENHANCED] Vector search failed:', error);
        }
    }
    // ===== STEP 7: Build ENHANCED system prompt with reference guidance =====
    const systemPrompt = `<identity>
Senin adın Balli. Dilara'nın diyabet ve beslenme konusunda bilgili, yakın bir arkadaşısın.
Dilara 32 yaşında, Kimya bölümü mezunu. Eşi Serhat seni ona yardımcı olman için geliştirdi.

Dilara Profili:
- Diyabet Türü: LADA (Erişkin Tip 1)
- İnsülin: Novorapid ve Lantus
- CGM: Dexcom G7 kullanıyor
- Öğün: Günde 2 öğün (Kahvaltı, Akşam Yemeği)
- Karbonhidrat: Her öğün 40-50gr
- Karbonhidrat/İnsülin Oranı: Kahvaltı 1:15, Akşam 1:10
</identity>

<communication_style>
- Samimi ve sıcak bir arkadaş gibi konuş, asistan gibi değil
- Doğal Türkçe kullan, gereksiz açıklamalar yapma
- "Canım" kelimesini çok sık kullanma
- Empati yap ama patronize etme
- Kısa ve öz cevaplar ver
- Zengin markdown kullan
</communication_style>

<critical_rules>
- İnsülin hesaplaması YAPMA, sen doktor değilsin
- Öğün atlama veya doz değiştirme önerme
- Bilmediğin konularda "Bu konuda bilgim yok" de
</critical_rules>

${vectorContext ? '<memory_context>\nDaha önce konuştuklarımızdan ilgili bilgiler:\n' + vectorContext + '</memory_context>\n\n' : ''}

${referenceGuidance ? '<reference_guidance>\n' + referenceGuidance + '</reference_guidance>\n\n' : ''}

<response_approach>
1. ÖNCE reference_guidance'ı oku - kullanıcının mesajındaki gizli referansları çöz
2. Her cevabı doğrudan bilginden yanıtla
3. Cevapları kısa tut, detay istenmedikçe
4. Her zaman Dilara'nın durumuna göre özelleştir
</response_approach>`;
    // ===== STEP 8: Create chat and stream response =====
    const chat = session.chat({
        model: (0, providers_1.getTier1Model)(),
        system: systemPrompt,
        config: {
            temperature: 0.7,
            maxOutputTokens: 2048,
            thinkingConfig: {
                thinkingBudget: 0
            }
        }
    });
    writeSSE(res, { type: 'generating', message: 'Yanıt oluşturuluyor...' });
    const stream = await chat.sendStream(question);
    let fullText = '';
    for await (const chunk of stream.stream) {
        if (chunk.text) {
            const words = chunk.text.split(/(\s+)/);
            for (const word of words) {
                if (word) {
                    writeSSE(res, { type: 'token', content: word });
                    fullText += word;
                }
            }
        }
    }
    // ===== STEP 9: EXTRACT CONVERSATION STATE from this exchange =====
    const turnNumber = conversationState.turnCount + 1;
    console.log(`📊 [ENHANCED] Extracting conversation state for turn ${turnNumber}...`);
    setImmediate(async () => {
        try {
            // Extract state (AI-powered with fallback) - Updated for PHASE 2
            const messageHistory = [
                { role: 'user', content: question, turnNumber },
                { role: 'model', content: fullText, turnNumber }
            ];
            const stateResult = await (0, conversation_state_extractor_1.extractConversationState)(messageHistory, conversationState);
            console.log(`✅ [ENHANCED] State extracted in ${stateResult.extractionTime}ms (fallback: ${stateResult.usedFallback})`);
            // Update session with new state
            if (session && session.state) {
                session.state.conversationState = stateResult.state;
                // Genkit will auto-save the session with updated state
                console.log(`💾 [ENHANCED] Updated session state (turn ${turnNumber})`);
            }
            // Also store embeddings
            await (0, vector_utils_1.storeConversationPairWithEmbeddings)(userId, session.id, question, fullText);
        }
        catch (error) {
            console.error('❌ [ENHANCED] State extraction failed:', error);
        }
    });
    return { sessionId: session.id };
}
/**
 * Usage Notes:
 *
 * To integrate into diabetes-assistant-stream.ts:
 *
 * 1. Import the new modules at the top:
 *    import { detectReferences, getPrimaryReference } from './reference-detector';
 *    import { resolveReferences, buildContextGuidance } from './reference-resolver';
 *    import { extractConversationState } from './conversation-state-extractor';
 *    import { ComprehensiveConversationState, initializeConversationState } from './types/conversation-state';
 *
 * 2. Update ChatState interface to EnhancedChatState
 *
 * 3. Replace the streamTier1 function body with the logic from streamTier1Enhanced
 *
 * 4. Repeat for streamProResearch function
 *
 * 5. Build and test:
 *    cd functions
 *    npm run build
 *    npm test
 */
//# sourceMappingURL=diabetes-assistant-stream-enhanced.js.map