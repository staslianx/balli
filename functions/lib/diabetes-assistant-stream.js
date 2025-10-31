"use strict";
/**
 * Diabetes Assistant - Streaming Version with SSE (Stateless)
 *
 * Provides token-by-token streaming for real-time user feedback
 * Uses Server-Sent Events (SSE) for progressive response delivery
 *
 * STATELESS DESIGN:
 * - Each request is completely independent
 * - No conversation history or session tracking
 * - No vector search or embeddings
 * - Pure request-response model
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.diabetesAssistantStream = void 0;
const https_1 = require("firebase-functions/v2/https");
const router_flow_1 = require("./flows/router-flow");
const providers_1 = require("./providers");
const genkit_instance_1 = require("./genkit-instance");
const rate_limiter_1 = require("./utils/rate-limiter");
const error_logger_1 = require("./utils/error-logger");
// Tier-specific prompts
const fast_prompt_t1_1 = require("./prompts/fast-prompt-t1");
const research_prompt_t2_1 = require("./prompts/research-prompt-t2");
const deep_research_prompt_t3_1 = require("./prompts/deep-research-prompt-t3");
// Research helper functions
const research_helpers_1 = require("./utils/research-helpers");
// Memory context helper
const memory_context_1 = require("./utils/memory-context");
// ===== THINKING TRIGGERS (Currently Disabled for Cost Optimization) =====
// These patterns were used to conditionally enable extended thinking for complex queries
// Commenting out since thinking is now disabled across all tiers for cost savings
// Can be re-enabled if needed by uncommenting and using in Tier 1 configuration
// const STREAM_T3_TRIGGERS: RegExp[] = [
//   /meli miyim/i,
//   /güvenli mi/i,
//   /ne yapmalıyım/i,
//   /yapmalı mıyım/i,
//   /should i/i,
//   /is it safe/i,
//   /yan etki/i,
//   /etkileş(ir|imi)/i,
//   /doz(\s|\w)*değiş(im|tirmek)/i,
//   /gebelik|hamilelik|ameliyat|komplikasyon/i
// ];
// const STREAM_T2_PLUS_TRIGGERS: RegExp[] = [
//   /dawn phenomenon|şafak fenomeni|sabah hiper/i,
//   /trend okları|trend arrows|alarm ayarları|alarm settings/i,
//   /rehber|guideline|güncel mi|değişti mi|son durum|en son|latest/i,
//   /202[4-6]/i,
//   /hangi(si)? daha (iyi|uygun)/i,
//   /(vs\.?|karşılaştır|comparison)/i,
//   /fiyat/i,
//   /nereden|nerede|bulabilirim|satın al|stok/i,
//   /yorum|inceleme|review/i,
//   /etiket|içindekiler|besin değeri/i,
//   /genel bilgi|kavramsal açıklama/i
// ];
// function matchesAny(patterns: RegExp[], text: string): boolean {
//   return patterns.some((re) => re.test(text));
// }
function extractReasoningFromGenerateResponse(response) {
    if (!response)
        return undefined;
    const primary = typeof response?.reasoning === 'string' ? response.reasoning.trim() : '';
    if (primary) {
        return primary;
    }
    const collected = [];
    const inspectParts = (parts) => {
        if (!Array.isArray(parts))
            return;
        for (const part of parts) {
            const reasoningText = typeof part?.reasoning === 'string' ? part.reasoning.trim() : '';
            if (reasoningText) {
                collected.push(reasoningText);
            }
        }
    };
    if (Array.isArray(response?.messages)) {
        for (const message of response.messages) {
            inspectParts(message?.content);
        }
    }
    if (response?.message) {
        inspectParts(response.message.content);
    }
    if (collected.length > 0) {
        return collected.join(' ').trim();
    }
    return undefined;
}
/**
 * Response size tracking (Cloud Run has 10 MB limit for streaming)
 */
let totalBytes = 0;
const MAX_STREAM_SIZE = 9.5 * 1024 * 1024; // 9.5 MB safety margin
/**
 * Helper to write SSE events with size tracking
 */
function writeSSE(res, event) {
    const data = `data: ${JSON.stringify(event)}\n\n`;
    const bytes = Buffer.byteLength(data, 'utf8');
    totalBytes += bytes;
    if (totalBytes > MAX_STREAM_SIZE) {
        console.error(`⚠️ [SSE] Response size exceeded 10MB limit: ${(totalBytes / 1024 / 1024).toFixed(2)} MB`);
        res.write(`data: ${JSON.stringify({
            type: 'error',
            message: 'Yanıt çok uzun, lütfen soruyu daha spesifik hale getirin'
        })}\n\n`);
        return false;
    }
    res.write(data);
    // 🔧 CRITICAL FIX: Force immediate flush after each write
    // Cloud Run aggressively buffers responses, causing 10-minute delays
    // This forces the data to be sent immediately
    if (typeof res.flush === 'function') {
        res.flush();
        console.log(`💧 [SSE-FLUSH] Forced flush after writing ${bytes} bytes`);
    }
    return true;
}
/**
 * Keep-alive mechanism to prevent connection timeout
 */
let keepAliveInterval = null;
function startKeepAlive(res) {
    // Send comment every 15 seconds to keep connection alive
    keepAliveInterval = setInterval(() => {
        res.write(': keepalive\n\n');
    }, 15000);
}
function stopKeepAlive() {
    if (keepAliveInterval) {
        clearInterval(keepAliveInterval);
        keepAliveInterval = null;
    }
}
/**
 * Stream Tier 1 response with conversation history
 */
async function streamTier1(res, question, userId, diabetesProfile, conversationHistory) {
    console.log(`🔵 [TIER1] Processing question for user ${userId}`);
    if (conversationHistory && conversationHistory.length > 0) {
        console.log(`🧠 [TIER1-MEMORY] Using conversation history: ${conversationHistory.length} messages`);
    }
    // ===== STEP 1: Fetch cross-conversation memory context =====
    writeSSE(res, { type: 'searching_memory', message: 'Önceki konuşmalar kontrol ediliyor...' });
    const memoryContext = await (0, memory_context_1.getMemoryContext)(userId);
    const formattedMemory = (0, memory_context_1.formatMemoryContext)(memoryContext);
    if (formattedMemory) {
        console.log(`🧠 [TIER1-MEMORY] Using cross-conversation memory: ${memoryContext.factCount} facts, ${memoryContext.summaryCount} summaries`);
    }
    // ===== STEP 2: Build system prompt =====
    let systemPrompt = (0, fast_prompt_t1_1.buildTier1Prompt)();
    // ===== STEP 3: Build prompt with memory + conversation history =====
    let prompt = '';
    // Add cross-conversation memory first (long-term context)
    if (formattedMemory) {
        prompt += formattedMemory;
    }
    // Add in-conversation history (session context)
    if (conversationHistory && conversationHistory.length > 0) {
        prompt += '\n--- ŞU ANKİ KONUŞMA ---\n';
        for (const msg of conversationHistory) {
            const roleLabel = msg.role === 'user' ? 'Kullanıcı' : 'Asistan';
            prompt += `\n${roleLabel}: ${msg.content}\n`;
        }
        prompt += '\n--- YENİ SORU ---\n';
    }
    // Add current question
    prompt += question;
    writeSSE(res, { type: 'generating', message: 'Yanıt oluşturuluyor...' });
    // ===== STEP 3: Call ai.generate() with full conversation context =====
    const { stream, response } = await genkit_instance_1.ai.generateStream({
        model: (0, providers_1.getTier1Model)(),
        system: systemPrompt,
        prompt: prompt,
        config: {
            temperature: 0.1,
            maxOutputTokens: 2500,
            thinkingConfig: {
                thinkingBudget: 0
            },
            // CRITICAL: Allow medical content for diabetes health assistant
            safetySettings: [
                { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
            ]
        }
    });
    // ===== STEP 3: Stream response word-by-word =====
    let fullText = '';
    let chunkCount = 0;
    for await (const chunk of stream) {
        if (chunk.text) {
            chunkCount++;
            // LOG EVERY CHUNK from Gemini
            console.log(`🔍 [T1-CHUNK-${chunkCount}] Length: ${chunk.text.length}, Starts: "${chunk.text.slice(0, 20)}", Ends: "${chunk.text.slice(-20)}"`);
            const words = chunk.text.split(/(\s+)/);
            for (const word of words) {
                if (word.length > 0) {
                    const debugWord = word.replace(/ /g, '·').replace(/\n/g, '⏎\n').replace(/\t/g, '→');
                    console.log(`📤 [TIER1-WORD] Sending: "${debugWord}" (length: ${word.length})`);
                    writeSSE(res, { type: 'token', content: word });
                    fullText += word;
                }
            }
        }
    }
    // AFTER stream completes - CHECK FINISH REASON
    const finalResponse = await response;
    const finishReason = finalResponse?.candidates?.[0]?.finishReason || 'unknown';
    const finishMessage = finalResponse?.candidates?.[0]?.finishMessage || 'none';
    console.log(`✅ [TIER1-STATELESS] Completed. Response: ${fullText.length} chars, Chunks: ${chunkCount}`);
    console.log(`🔍 [TIER1-FINISH] Finish Reason: ${finishReason}`);
    console.log(`🔍 [TIER1-FINISH] Finish Message: ${finishMessage}`);
    console.log(`🔍 [TIER1-FINISH] Last 100 chars: "${fullText.slice(-100)}"`);
    // If not natural stop, log warning
    if (finishReason !== 'STOP') {
        console.error(`🚨 [TIER1-ABNORMAL] Stream ended with reason: ${finishReason} - ${finishMessage}`);
    }
}
/**
 * Stream Tier 2 Web Search response with conversation history
 *
 * SIMPLIFIED T2:
 * - Model: Gemini 2.5 Flash (cost-efficient)
 * - Sources: 15 Exa web search results ONLY
 * - Cost: ~$0.003/query (90% cheaper than T3)
 * - Target: 3-5 seconds processing time
 */
async function streamTier2Hybrid(res, question, userId, diabetesProfile, conversationHistory) {
    const startTime = Date.now();
    console.log(`🔵 [T2] Processing web search for user ${userId}`);
    if (conversationHistory && conversationHistory.length > 0) {
        console.log(`🧠 [T2-MEMORY] Using conversation history: ${conversationHistory.length} messages`);
    }
    // ===== STEP 0.5: Fetch cross-conversation memory context =====
    writeSSE(res, { type: 'searching_memory', message: 'Önceki konuşmalar kontrol ediliyor...' });
    const memoryContext = await (0, memory_context_1.getMemoryContext)(userId);
    const formattedMemory = (0, memory_context_1.formatMemoryContext)(memoryContext);
    if (formattedMemory) {
        console.log(`🧠 [T2-MEMORY] Using cross-conversation memory: ${memoryContext.factCount} facts, ${memoryContext.summaryCount} summaries`);
    }
    // ===== STEP 1: Build static system prompt =====
    const systemPrompt = (0, research_prompt_t2_1.buildTier2Prompt)();
    // ===== STEP 1.5: Enrich query with conversation context =====
    const { enrichQuery } = await Promise.resolve().then(() => __importStar(require('./tools/query-enricher')));
    const enrichedQueryResult = await enrichQuery({
        currentQuestion: question,
        conversationHistory,
        diabetesProfile
    });
    const searchQuery = enrichedQueryResult.enriched;
    console.log(`🔍 [T2] Search query: "${searchQuery}" (context: ${enrichedQueryResult.contextUsed})`);
    // ===== STEP 2: Fetch Exa web sources with enriched query =====
    writeSSE(res, { type: 'searching', source: 'exa' });
    const { searchMedicalSources, formatExaForAI } = await Promise.resolve().then(() => __importStar(require('./tools/exa-search')));
    const exaResults = await searchMedicalSources(searchQuery, 15).catch(() => []);
    const totalSources = exaResults.length;
    writeSSE(res, {
        type: 'search_complete',
        count: totalSources,
        source: 'exa_web_search'
    });
    console.log(`✅ [T2-STATELESS] Fetched ${totalSources} Exa sources`);
    // ===== STEP 3: Format sources =====
    const formattedSources = (0, research_helpers_1.formatSourcesWithTypes)(exaResults, [], [], []);
    // ===== STEP 3.5: Send sources immediately (like T3) so they appear while text streams =====
    const clientSources = formattedSources.map(source => ({
        title: source.title,
        url: source.url,
        type: source.type,
        authors: source.authors,
        journal: source.journal,
        year: source.year,
        snippet: source.snippet
    }));
    writeSSE(res, {
        type: 'sources_ready',
        sources: clientSources
    });
    // ===== STEP 4: Build research context =====
    let researchContext = '# WEB SEARCH RESULTS (15 sources)\n\n';
    if (exaResults.length > 0) {
        researchContext += formatExaForAI(exaResults, true) + '\n\n';
    }
    // ===== STEP 5: Build prompt with memory + research context + conversation history =====
    let userPrompt = '';
    // Add cross-conversation memory first (long-term context)
    if (formattedMemory) {
        userPrompt += formattedMemory;
    }
    // If conversation history exists, prepend it
    if (conversationHistory && conversationHistory.length > 0) {
        userPrompt += '\n--- ŞU ANKİ KONUŞMA ---\n';
        for (const msg of conversationHistory) {
            const roleLabel = msg.role === 'user' ? 'Kullanıcı' : 'Asistan';
            userPrompt += `\n${roleLabel}: ${msg.content}\n`;
        }
        userPrompt += '\n--- CURRENT QUESTION WITH RESEARCH ---\n\n';
    }
    // Add research context
    userPrompt += researchContext;
    userPrompt += `\n---\n\nKullanıcı Sorusu: "${question}"\n\n`;
    if (diabetesProfile) {
        userPrompt += `Diyabet Profili: ${diabetesProfile.type}`;
        if (diabetesProfile.medications) {
            userPrompt += `, İlaçlar: ${diabetesProfile.medications.join(', ')}`;
        }
        userPrompt += '\n\n';
    }
    userPrompt += `Yukarıdaki web araştırma kaynaklarını sentezle ve soruya kapsamlı bir yanıt oluştur.
ÖNEMLI: Inline [1][2][3] sitasyonları kullan. Sonuna "## Kaynaklar" bölümü ekleme.`;
    writeSSE(res, { type: 'generating', message: 'Web araştırma sentezleniyor...' });
    // ===== STEP 6: Call ai.generate() with full conversation context =====
    let stream, response;
    try {
        const result = await genkit_instance_1.ai.generateStream({
            model: (0, providers_1.getTier2Model)(),
            system: systemPrompt,
            prompt: userPrompt,
            config: {
                temperature: 0.2,
                maxOutputTokens: 3000,
                // FIX: Don't specify thinkingConfig at all if thinking is disabled
                // Setting thinkingBudget: 0 with includeThoughts: true causes 400 error
                // CRITICAL: Allow medical content for diabetes health assistant
                // This is a medical app providing health information (not medical advice)
                safetySettings: [
                    { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
                    { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
                    { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
                    { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
                ]
            }
        });
        stream = result.stream;
        response = result.response;
    }
    catch (genError) {
        console.error('❌ [T2-STATELESS] Gemini generation error:', genError);
        console.error('❌ [T2-STATELESS] Error message:', genError.message);
        console.error('❌ [T2-STATELESS] Error code:', genError.code);
        console.error('❌ [T2-STATELESS] Error details:', JSON.stringify(genError, null, 2));
        // Check if it's a safety/content filter issue
        if (genError.message?.includes('SAFETY') || genError.message?.includes('BLOCK')) {
            console.error('🚨 [T2-STATELESS] Content blocked by Gemini safety filters');
            writeSSE(res, {
                type: 'error',
                message: 'İçerik güvenlik filtreleri tarafından engellendi. Lütfen farklı bir soru deneyin.'
            });
            return;
        }
        // Re-throw to be handled by outer catch
        throw genError;
    }
    // ===== STEP 7: Stream the synthesis =====
    let fullText = '';
    let tokenCount = 0;
    let chunkCount = 0;
    for await (const chunk of stream) {
        if (chunk.text) {
            chunkCount++;
            // LOG EVERY CHUNK from Gemini
            console.log(`🔍 [T2-CHUNK-${chunkCount}] Length: ${chunk.text.length}, Starts: "${chunk.text.slice(0, 20)}", Ends: "${chunk.text.slice(-20)}"`);
            const words = chunk.text.split(/(\s+)/);
            for (const word of words) {
                if (word.length > 0) {
                    tokenCount += word.length;
                    const debugWord = word.replace(/ /g, '·').replace(/\n/g, '⏎\n').replace(/\t/g, '→');
                    console.log(`📤 [T2-WORD] Sending: "${debugWord}" (length: ${word.length})`);
                    if (!writeSSE(res, { type: 'token', content: word })) {
                        console.error(`❌ [T2-STATELESS] Stream stopped due to size limit`);
                        break;
                    }
                    fullText += word;
                }
            }
        }
    }
    const finalResponse = await response;
    const thinkingSummary = extractReasoningFromGenerateResponse(finalResponse);
    // CHECK FINISH REASON (using existing finalResponse variable)
    const finishReason = finalResponse?.candidates?.[0]?.finishReason || 'unknown';
    const finishMessage = finalResponse?.candidates?.[0]?.finishMessage || 'none';
    console.log(`✅ [T2-STATELESS] Stream completed. Response: ${fullText.length} chars, Chunks: ${chunkCount}, Tokens: ${tokenCount}`);
    console.log(`🔍 [T2-FINISH] Finish Reason: ${finishReason}`);
    console.log(`🔍 [T2-FINISH] Finish Message: ${finishMessage}`);
    console.log(`🔍 [T2-FINISH] Last 100 chars: "${fullText.slice(-100)}"`);
    // If not natural stop, log warning
    if (finishReason !== 'STOP') {
        console.error(`🚨 [T2-ABNORMAL] Stream ended with reason: ${finishReason} - ${finishMessage}`);
    }
    // Flush tokens before complete event
    res.write(': flush-tokens\n\n');
    await new Promise((resolve) => {
        setTimeout(() => resolve(), 200);
    });
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    // ===== STEP 8: clientSources already sent earlier in sources_ready event =====
    const evidenceQuality = exaResults.length >= 10 ? 'high' :
        exaResults.length >= 7 ? 'moderate' :
            exaResults.length >= 4 ? 'limited' : 'insufficient';
    // ===== STEP 9: Send complete event (no sessionId) =====
    writeSSE(res, {
        type: 'complete',
        sources: clientSources,
        metadata: {
            processingTime: `${duration}s`,
            modelUsed: 'Gemini 2.5 Flash (Web Araştırma)',
            costTier: 'low'
        },
        researchSummary: {
            totalStudies: clientSources.length,
            pubmedArticles: 0,
            clinicalTrials: 0,
            medrxivPapers: 0,
            exaMedicalSources: exaResults.length,
            evidenceQuality
        },
        processingTier: 'SEARCH',
        thinkingSummary
    });
    console.log(`✅ [T2-STATELESS] Completed. Duration: ${duration}s`);
}
// NOTE: streamTier2 function removed - no longer needed in 2-tier system
/**
 * Stream Deep Research response (Tier 3) with conversation history
 *
 * SIMPLIFIED DEEP RESEARCH:
 * - Multi-round research with V2 orchestrator
 * - Model: Gemini 2.5 Pro for synthesis
 * - Sources: 15-60+ (adaptive based on query complexity)
 * - Cost: ~$0.03-0.08/query (premium tier, user-controlled only)
 * - Target: 20-60 seconds processing time
 * - Trigger: ONLY when user explicitly requests deep research
 */
async function streamDeepResearch(res, question, userId, diabetesProfile, conversationHistory) {
    const startTime = Date.now();
    console.log(`🔵 [T3] Processing deep research for user ${userId}`);
    if (conversationHistory && conversationHistory.length > 0) {
        console.log(`🧠 [T3-MEMORY] Using conversation history: ${conversationHistory.length} messages`);
    }
    // ===== STEP 0.5: Fetch cross-conversation memory context =====
    writeSSE(res, { type: 'searching_memory', message: 'Önceki konuşmalar kontrol ediliyor...' });
    const memoryContext = await (0, memory_context_1.getMemoryContext)(userId);
    const formattedMemory = (0, memory_context_1.formatMemoryContext)(memoryContext);
    if (formattedMemory) {
        console.log(`🧠 [T3-MEMORY] Using cross-conversation memory: ${memoryContext.factCount} facts, ${memoryContext.summaryCount} summaries`);
    }
    // ===== STEP 1: Build static system prompt =====
    const systemPrompt = (0, deep_research_prompt_t3_1.buildTier3Prompt)();
    // ===== STEP 2: Execute deep research V2 =====
    const { executeDeepResearchV2, formatResearchForSynthesis } = await Promise.resolve().then(() => __importStar(require('./flows/deep-research-v2')));
    const researchResults = await executeDeepResearchV2(question, res);
    console.log(`✅ [T3-STATELESS] Research complete: ${researchResults.rounds.length} rounds, ` +
        `${researchResults.totalSources} sources`);
    // ===== STEP 3: Format sources =====
    const formattedSources = (0, research_helpers_1.formatSourcesWithTypes)(researchResults.allSources.exa, researchResults.allSources.pubmed, researchResults.allSources.medrxiv, researchResults.allSources.clinicalTrials);
    // ===== STEP 4: Build prompt with memory + research context + conversation history =====
    const researchContext = formatResearchForSynthesis(researchResults);
    let userPrompt = '';
    // Add cross-conversation memory first (long-term context)
    if (formattedMemory) {
        userPrompt += formattedMemory;
    }
    // If conversation history exists, prepend it
    if (conversationHistory && conversationHistory.length > 0) {
        userPrompt += '\n--- ŞU ANKİ KONUŞMA ---\n';
        for (const msg of conversationHistory) {
            const roleLabel = msg.role === 'user' ? 'Kullanıcı' : 'Asistan';
            userPrompt += `\n${roleLabel}: ${msg.content}\n`;
        }
        userPrompt += '\n--- CURRENT QUESTION WITH DEEP RESEARCH ---\n\n';
    }
    // Add research context
    userPrompt += researchContext;
    userPrompt += `\n---\n\nKullanıcı Sorusu: "${question}"\n\n`;
    if (diabetesProfile) {
        userPrompt += `Diyabet Profili: ${diabetesProfile.type}`;
        if (diabetesProfile.medications) {
            userPrompt += `, İlaçlar: ${diabetesProfile.medications.join(', ')}`;
        }
        userPrompt += '\n\n';
    }
    userPrompt += `Yukarıdaki tüm araştırma kaynaklarını sentezle ve soruya kapsamlı bir yanıt oluştur.
ÖNEMLI: Inline [1][2][3] sitasyonları kullan. Sonuna "## Kaynaklar" bölümü ekleme.`;
    // ===== STEP 5: Call ai.generate() with full conversation context =====
    const { stream, response } = await genkit_instance_1.ai.generateStream({
        model: (0, providers_1.getTier3Model)(),
        system: systemPrompt,
        prompt: userPrompt,
        config: {
            temperature: 0.15,
            maxOutputTokens: 12000,
            // CRITICAL: Allow medical content for diabetes health assistant
            safetySettings: [
                { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
            ]
        }
    });
    // ===== STEP 6: Stream the synthesis =====
    let fullText = '';
    let tokenCount = 0;
    let firstChunk = true;
    let chunkCount = 0;
    for await (const chunk of stream) {
        if (chunk.text) {
            chunkCount++;
            // LOG EVERY CHUNK from Gemini
            console.log(`🔍 [T3-CHUNK-${chunkCount}] Length: ${chunk.text.length}, Starts: "${chunk.text.slice(0, 20)}", Ends: "${chunk.text.slice(-20)}"`);
            if (firstChunk) {
                writeSSE(res, { type: 'generating', message: 'Derinlemesine araştırma sentezleniyor...' });
                firstChunk = false;
            }
            const words = chunk.text.split(/(\s+)/);
            for (const word of words) {
                if (word.length > 0) {
                    tokenCount += word.length;
                    const debugWord = word.replace(/ /g, '·').replace(/\n/g, '⏎\n').replace(/\t/g, '→');
                    console.log(`📤 [T3-WORD] Sending: "${debugWord}" (length: ${word.length})`);
                    const writeSuccess = writeSSE(res, { type: 'token', content: word });
                    if (!writeSuccess) {
                        console.error(`❌ [T3-STATELESS] Stream stopped due to size limit at ${tokenCount} tokens`);
                        break;
                    }
                    fullText += word;
                }
            }
        }
    }
    // CHECK FINISH REASON (await response to get finish reason)
    const finalT3Response = await response;
    const finishReason = finalT3Response?.candidates?.[0]?.finishReason || 'unknown';
    const finishMessage = finalT3Response?.candidates?.[0]?.finishMessage || 'none';
    console.log(`✅ [T3-STATELESS] Stream completed. Response: ${fullText.length} chars, Chunks: ${chunkCount}, Tokens: ${tokenCount}`);
    console.log(`🔍 [T3-FINISH] Finish Reason: ${finishReason}`);
    console.log(`🔍 [T3-FINISH] Finish Message: ${finishMessage}`);
    console.log(`🔍 [T3-FINISH] Last 100 chars: "${fullText.slice(-100)}"`);
    // If not natural stop, log warning
    if (finishReason !== 'STOP') {
        console.error(`🚨 [T3-ABNORMAL] Stream ended with reason: ${finishReason} - ${finishMessage}`);
    }
    // Flush tokens before complete event
    res.write(': flush-tokens\n\n');
    await new Promise((resolve) => {
        setTimeout(() => resolve(), 200);
    });
    const finalResponse = await response;
    const thinkingSummary = extractReasoningFromGenerateResponse(finalResponse);
    // Extract token usage
    const rawResponse = finalResponse.raw || finalResponse.response;
    const usageMetadata = rawResponse?.usageMetadata || finalResponse.usageMetadata;
    const outputTokens = usageMetadata?.candidatesTokenCount || 0;
    const inputTokens = usageMetadata?.promptTokenCount || 0;
    const totalTokens = usageMetadata?.totalTokenCount || 0;
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    // ===== STEP 7: Build sources array for client =====
    const clientSources = formattedSources.map(source => ({
        title: source.title,
        url: source.url,
        type: source.type,
        authors: source.authors,
        journal: source.journal,
        year: source.year,
        snippet: source.snippet
    }));
    const lastRound = researchResults.rounds[researchResults.rounds.length - 1];
    const evidenceQuality = lastRound?.reflection?.evidenceQuality || 'moderate';
    // ===== STEP 8: Send complete event (no sessionId) =====
    writeSSE(res, {
        type: 'complete',
        sources: clientSources,
        metadata: {
            processingTime: `${duration}s`,
            modelUsed: 'Gemini 2.5 Pro (Deep Research V2)',
            costTier: 'high',
            researchVersion: 'v2',
            rounds: researchResults.rounds.length,
            estimatedRounds: researchResults.plan.estimatedRounds,
            strategy: researchResults.plan.strategy,
            tokenUsage: {
                input: inputTokens,
                output: outputTokens,
                total: totalTokens
            }
        },
        researchSummary: {
            totalStudies: clientSources.length,
            pubmedArticles: researchResults.allSources.pubmed.length,
            clinicalTrials: researchResults.allSources.clinicalTrials.length,
            medrxivPapers: researchResults.allSources.medrxiv.length,
            exaMedicalSources: researchResults.allSources.exa.length,
            evidenceQuality,
            rounds: researchResults.rounds.length,
            focusAreas: researchResults.plan.focusAreas
        },
        processingTier: 'DEEP_RESEARCH',
        thinkingSummary
    });
    console.log(`✅ [T3-STATELESS] Completed. Duration: ${duration}s`);
}
/**
 * Main streaming endpoint
 */
exports.diabetesAssistantStream = (0, https_1.onRequest)({
    region: 'us-central1',
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 540, // 9 minutes - Required for T3 Deep Research (5-7 min processing time)
    memory: '1GiB' // Increased for deep research with 25+ sources
}, async (req, res) => {
    // Set SSE headers with ALL critical streaming headers
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // CRITICAL: Disable nginx buffering
    res.setHeader('Transfer-Encoding', 'chunked'); // Explicit chunked encoding
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    // Handle preflight
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }
    // Reset response size tracking for this request
    totalBytes = 0;
    try {
        const { question, userId, diabetesProfile, conversationHistory } = req.body;
        // Validate
        if (!question || !userId) {
            writeSSE(res, {
                type: 'error',
                message: 'Soru ve kullanıcı kimliği gereklidir'
            });
            res.end();
            return;
        }
        console.log(`🌊 [STREAM] New streaming request from ${userId}`);
        console.log(`📝 [STREAM] Question: "${question.substring(0, 100)}..."`);
        // Log conversation history if present
        if (conversationHistory && conversationHistory.length > 0) {
            console.log(`🧠 [MEMORY] Conversation history: ${conversationHistory.length} messages`);
        }
        // Start keep-alive heartbeat
        startKeepAlive(res);
        // Step 1: Route the question
        writeSSE(res, { type: 'routing', message: 'Soru analiz ediliyor...' });
        const routing = await (0, router_flow_1.routeQuestion)({
            question,
            userId,
            diabetesProfile,
            conversationHistory
        });
        writeSSE(res, {
            type: 'tier_selected',
            tier: routing.tier,
            reasoning: routing.reasoning,
            confidence: routing.confidence
        });
        // Check rate limit for T3 Deep Research tier (tier 3)
        if (routing.tier === 3) {
            const canProceed = await (0, rate_limiter_1.checkTier3RateLimit)(userId);
            if (!canProceed) {
                writeSSE(res, {
                    type: 'error',
                    message: 'Günlük derinlemesine araştırma limitine ulaştınız (10/gün). Lütfen yarın tekrar deneyin.'
                });
                stopKeepAlive();
                res.end();
                return;
            }
        }
        // Step 2: Stream based on tier (3-TIER SYSTEM WITH IN-CONVERSATION MEMORY)
        const tierStart = Date.now();
        if (routing.tier === 1) {
            // Tier 1: Flash with conversation history
            await streamTier1(res, question, userId, diabetesProfile, conversationHistory);
            const tier1Duration = ((Date.now() - tierStart) / 1000).toFixed(2);
            // Send complete event for Tier 1
            const sources = [{ title: 'Genel Diyabet Bilgi Tabanı', type: 'knowledge_base' }];
            writeSSE(res, {
                type: 'complete',
                sources,
                metadata: {
                    processingTime: `${tier1Duration}s`,
                    modelUsed: 'Gemini 2.5 Flash',
                    costTier: 'low'
                },
                processingTier: 'MODEL'
            });
        }
        else if (routing.tier === 2) {
            // Tier 2: Web Search with conversation history
            await streamTier2Hybrid(res, question, userId, diabetesProfile, conversationHistory);
            // Complete event already sent inside streamTier2Hybrid
        }
        else {
            // Tier 3: Deep Research with conversation history
            await streamDeepResearch(res, question, userId, diabetesProfile, conversationHistory);
            // Complete event already sent inside streamDeepResearch
        }
        // Stop keep-alive
        stopKeepAlive();
        // ✅ FIX: Ensure ALL data is flushed before closing
        console.log(`🔍 [STREAM-FIX] Starting graceful shutdown sequence - totalBytes: ${totalBytes}`);
        // Force flush
        if (typeof res.flush === 'function') {
            res.flush();
            console.log(`💧 [STREAM-FIX] Forced final flush before shutdown`);
        }
        // Write padding
        res.write('\n\n\n\n');
        console.log(`🔍 [STREAM-FIX] Padding newlines written`);
        // Send end comment
        res.write(': stream-end\n\n');
        console.log(`🔍 [STREAM-FIX] End-of-stream comment sent`);
        // Force flush again
        if (typeof res.flush === 'function') {
            res.flush();
            console.log(`💧 [STREAM-FIX] Forced flush after padding`);
        }
        console.log(`✅ [STREAM-STATELESS] Completed. Size: ${(totalBytes / 1024).toFixed(2)} KB`);
        console.log(`📤 [STREAM-STATELESS] Waiting for network buffers to drain...`);
        // Wait for buffers to drain
        await new Promise((resolve) => {
            setTimeout(() => {
                console.log(`🔒 [STREAM-FIX] 1000ms grace period complete - closing connection`);
                res.end();
                console.log(`🔒 [STREAM-FIX] res.end() called - connection closed gracefully`);
                resolve();
            }, 1000);
        });
        console.log(`✅ [STREAM-FIX] Graceful shutdown complete`);
    }
    catch (error) {
        console.error('❌ [STREAM-STATELESS] Error:', error);
        stopKeepAlive();
        // Log error with structured context
        const errorContext = {
            userId: req.body?.userId,
            operation: 'streaming endpoint',
            query: req.body?.question
        };
        (0, error_logger_1.logError)(undefined, error, errorContext);
        // Get user-friendly error message (don't expose internal details)
        const userMessage = (0, error_logger_1.getUserFriendlyMessage)(error);
        writeSSE(res, {
            type: 'error',
            message: userMessage
        });
        res.end();
    }
});
//# sourceMappingURL=diabetes-assistant-stream.js.map