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

import { onRequest } from 'firebase-functions/v2/https';
import { Response } from 'express';
import { routeQuestion } from './flows/router-flow';
import { getTier1Model, getTier2Model, getTier3Model } from './providers';
import { ai } from './genkit-instance';
import { checkTier3RateLimit } from './utils/rate-limiter';
import {
  logError,
  getUserFriendlyMessage,
  type ErrorContext
} from './utils/error-logger';
import { logTokenUsage } from './cost-tracking/cost-tracker';
import { FeatureName } from './cost-tracking/model-pricing';

// Tier-specific prompts
import { buildTier1Prompt } from './prompts/fast-prompt-t1';
import { buildTier2Prompt } from './prompts/research-prompt-t2';
import { buildTier3PromptImproved } from './prompts/deep-research-prompt-t3';

// Research helper functions
import { formatSourcesWithTypes } from './utils/research-helpers';

// Memory context helper
import { getMemoryContext, formatMemoryContext } from './utils/memory-context';

// Phase 2 imports: Query analyzer and parallel research fetcher
// NOTE: These imports are currently unused (kept for future reference)
// import { analyzeQuery, calculateSourceCounts } from './tools/query-analyzer';
// import { fetchAllResearchSources, createT2Config } from './tools/parallel-research-fetcher';

/**
 * SSE Event Types - Enhanced with granular research progress tracking
 */
type SSEEvent =
  | { type: 'routing'; message: string }
  | { type: 'tier_selected'; tier: number; reasoning: string; confidence: number }
  | { type: 'searching_memory'; message: string }
  | { type: 'searching'; source: 'exa' | 'pubmed' | 'clinicaltrials' }
  | { type: 'search_complete'; count: number; source: string }
  | { type: 'sources_ready'; sources: any[] }
  | { type: 'extracting_keywords' }
  | { type: 'keywords_extracted'; keywords: string }
  // NEW: Granular research progress events
  | { type: 'research_stage'; stage: 'starting' | 'scanning' | 'fetching' | 'synthesizing'; message: string }
  | { type: 'api_started'; api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa'; count: number; message: string; query?: string }
  | { type: 'api_completed'; api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa'; count: number; duration: number; message: string; success: boolean; searchQuery?: string; topSources?: Array<{index: number; title: string; url: string; domain: string}> }
  | { type: 'research_progress'; fetched: number; total: number; message: string }
  | { type: 'synthesis_started'; totalRounds: number; totalSources: number; sequence: number }
  // T2-specific events for detailed tracking
  | { type: 't2_query_enrichment_started'; message: string }
  | { type: 't2_query_enrichment_complete'; enrichedQuery: string; contextUsed: boolean; originalQuery?: string; duration?: number }
  | { type: 't2_translation_started'; message: string }
  | { type: 't2_translation_complete'; originalQuery: string; translatedQuery: string; duration: number }
  | { type: 't2_source_analysis_started'; message: string }
  | { type: 't2_source_analysis_complete'; totalSources: number; breakdown: { exa: number } }
  | { type: 'generating'; message: string }
  | { type: 'token'; content: string }
  | { type: 'complete'; sources: any[]; metadata: any; researchSummary?: any; processingTier?: string; thinkingSummary?: string }
  | { type: 'error'; message: string };

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

function extractReasoningFromGenerateResponse(response: any): string | undefined {
  if (!response) return undefined;

  const primary = typeof response?.reasoning === 'string' ? response.reasoning.trim() : '';
  if (primary) {
    return primary;
  }

  const collected: string[] = [];

  const inspectParts = (parts: any) => {
    if (!Array.isArray(parts)) return;
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
function writeSSE(res: Response, event: SSEEvent): boolean {
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
  if (typeof (res as any).flush === 'function') {
    (res as any).flush();
    console.log(`💧 [SSE-FLUSH] Forced flush after writing ${bytes} bytes`);
  }

  return true;
}

/**
 * Keep-alive mechanism to prevent connection timeout
 */
let keepAliveInterval: NodeJS.Timeout | null = null;

function startKeepAlive(res: Response): void {
  // Send comment every 15 seconds to keep connection alive
  keepAliveInterval = setInterval(() => {
    res.write(': keepalive\n\n');
  }, 15000);
}

function stopKeepAlive(): void {
  if (keepAliveInterval) {
    clearInterval(keepAliveInterval);
    keepAliveInterval = null;
  }
}

/**
 * Stream Tier 1 response with conversation history
 */
async function streamTier1(
  res: Response,
  question: string,
  userId: string,
  diabetesProfile?: any,
  conversationHistory?: Array<{ role: string; content: string; imageBase64?: string }>
): Promise<void> {
  console.log(`🔵 [TIER1] Processing question for user ${userId}`);

  if (conversationHistory && conversationHistory.length > 0) {
    console.log(`🧠 [TIER1-MEMORY] Using conversation history: ${conversationHistory.length} messages`);
  }

  // Extract image from current query (last message in history or current question)
  let imageBase64: string | undefined;
  if (conversationHistory && conversationHistory.length > 0) {
    // Check the last user message for an image
    const lastUserMessage = [...conversationHistory].reverse().find(msg => msg.role === 'user');
    if (lastUserMessage?.imageBase64) {
      imageBase64 = lastUserMessage.imageBase64;
      console.log(`🖼️ [TIER1-IMAGE] Found image attachment in conversation history`);
    }
  }

  // ===== STEP 1: Fetch cross-conversation memory context =====
  writeSSE(res, { type: 'searching_memory', message: 'Önceki konuşmalar kontrol ediliyor...' });
  const memoryContext = await getMemoryContext(userId);
  const formattedMemory = formatMemoryContext(memoryContext);

  if (formattedMemory) {
    console.log(`🧠 [TIER1-MEMORY] Using cross-conversation memory: ${memoryContext.factCount} facts, ${memoryContext.summaryCount} summaries`);
  }

  // ===== STEP 2: Build system prompt =====
  let systemPrompt = buildTier1Prompt();

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
  // Build generate request with optional image
  // FIX: Genkit requires multimodal prompts as array with media + text objects
  let promptContent;
  if (imageBase64) {
    // Multimodal: array format with media object first, then text
    promptContent = [
      { media: { url: `data:image/jpeg;base64,${imageBase64}` } },
      { text: prompt }
    ];
    console.log(`🖼️ [TIER1-IMAGE] Including image in multimodal array format`);
  } else {
    // Text-only: simple string
    promptContent = prompt;
  }

  const generateRequest: any = {
    model: getTier1Model(),
    system: systemPrompt,
    prompt: promptContent,
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
  };

  const { stream, response } = await ai.generateStream(generateRequest);

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
  const finishReason = (finalResponse as any)?.candidates?.[0]?.finishReason || 'unknown';
  const finishMessage = (finalResponse as any)?.candidates?.[0]?.finishMessage || 'none';

  // Extract and track token usage for cost tracking
  const rawResponse = (finalResponse as any).raw || (finalResponse as any).response;
  const usageMetadata = rawResponse?.usageMetadata || (finalResponse as any).usageMetadata;
  const inputTokens = usageMetadata?.promptTokenCount || 0;
  const outputTokens = usageMetadata?.candidatesTokenCount || 0;

  // Track cost for Tier 1 fast response
  await logTokenUsage({
    featureName: FeatureName.RESEARCH_FAST,
    modelName: getTier1Model(),
    inputTokens,
    outputTokens,
    userId,
    metadata: {
      hasImage: !!imageBase64,
      conversationLength: conversationHistory?.length || 0,
      memoryFactCount: memoryContext?.factCount || 0
    }
  });

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
async function streamTier2Hybrid(
  res: Response,
  question: string,
  userId: string,
  diabetesProfile?: any,
  conversationHistory?: Array<{ role: string; content: string; imageBase64?: string }>
): Promise<void> {
  const startTime = Date.now();

  console.log(`╔════════════════════════════════════════════════════════════════════════════╗`);
  console.log(`║ 🔵 T2: WEB SEARCH RESEARCH PIPELINE                                       ║`);
  console.log(`╚════════════════════════════════════════════════════════════════════════════╝`);
  console.log(`📝 [T2] Query: "${question.substring(0, 80)}${question.length > 80 ? '...' : ''}"`);
  console.log(`👤 [T2] User: ${userId}`);

  if (conversationHistory && conversationHistory.length > 0) {
    console.log(`🧠 [T2-MEMORY] Conversation history: ${conversationHistory.length} messages`);
  }

  // Extract image from current query (last message in history)
  let imageBase64: string | undefined;
  if (conversationHistory && conversationHistory.length > 0) {
    const lastUserMessage = [...conversationHistory].reverse().find(msg => msg.role === 'user');
    if (lastUserMessage?.imageBase64) {
      imageBase64 = lastUserMessage.imageBase64;
      console.log(`🖼️ [T2-IMAGE] Found image attachment in conversation history`);
    }
  }

  if (diabetesProfile) {
    console.log(`📋 [T2] Profile: ${diabetesProfile.type || 'Unknown type'}`);
  }

  // ===== STEP 0.5: Fetch cross-conversation memory context =====
  console.log(`\n┌─ STAGE 1: MEMORY CONTEXT ─────────────────────────────────────────────────┐`);
  writeSSE(res, { type: 'searching_memory', message: 'Önceki konuşmalar kontrol ediliyor...' });
  const memoryContext = await getMemoryContext(userId);
  const formattedMemory = formatMemoryContext(memoryContext);

  if (formattedMemory) {
    console.log(`🧠 [T2-MEMORY] Cross-conversation memory loaded:`);
    console.log(`   • Facts: ${memoryContext.factCount}`);
    console.log(`   • Summaries: ${memoryContext.summaryCount}`);
  } else {
    console.log(`🧠 [T2-MEMORY] No prior conversation memory found`);
  }
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  // ===== STEP 1: Build static system prompt =====
  console.log(`\n┌─ STAGE 2: SYSTEM PROMPT ──────────────────────────────────────────────────┐`);
  const systemPrompt = buildTier2Prompt();
  console.log(`📝 [T2] System prompt loaded: T2 Web Search`);
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  // ===== STEP 1.5: Enrich query with conversation context =====
  console.log(`\n┌─ STAGE 3: QUERY ENRICHMENT ───────────────────────────────────────────────┐`);
  writeSSE(res, {
    type: 't2_query_enrichment_started',
    message: 'Sorgu bağlama göre zenginleştiriliyor...'
  });

  const { enrichQuery } = await import('./tools/query-enricher');
  const enrichmentStartTime = Date.now();
  const enrichedQueryResult = await enrichQuery({
    currentQuestion: question,
    conversationHistory,
    diabetesProfile
  });
  const enrichmentDuration = Date.now() - enrichmentStartTime;

  const searchQuery = enrichedQueryResult.enriched;
  console.log(`🔍 [T2-ENRICHMENT] Original: "${question}"`);
  console.log(`🔍 [T2-ENRICHMENT] Enriched: "${searchQuery}"`);
  console.log(`🔍 [T2-ENRICHMENT] Context used: ${enrichedQueryResult.contextUsed}`);
  console.log(`⏱️  [T2-ENRICHMENT] Duration: ${enrichmentDuration}ms`);
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  writeSSE(res, {
    type: 't2_query_enrichment_complete',
    enrichedQuery: searchQuery,
    contextUsed: enrichedQueryResult.contextUsed,
    originalQuery: question, // ADD: So CLI can show comparison
    duration: enrichmentDuration // ADD: Show timing
  });

  // ===== STEP 2: Translate query to English for better Exa results =====
  console.log(`\n┌─ STAGE 4: TRANSLATION ────────────────────────────────────────────────────┐`);
  writeSSE(res, {
    type: 't2_translation_started',
    message: 'Sorgu İngilizce\'ye çevriliyor...'
  });

  const { translateToEnglishForAPIs } = await import('./tools/query-translator');
  const translationStartTime = Date.now();
  const englishQuery = await translateToEnglishForAPIs(searchQuery);
  const translationDuration = Date.now() - translationStartTime;

  console.log(`🌍 [T2-TRANSLATION] Translation complete:`);
  console.log(`   • Original (Turkish): "${searchQuery}"`);
  console.log(`   • Translated (English): "${englishQuery}"`);
  console.log(`   • Duration: ${translationDuration}ms`);
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  writeSSE(res, {
    type: 't2_translation_complete',
    originalQuery: searchQuery,
    translatedQuery: englishQuery,
    duration: translationDuration
  });

  // ===== STEP 3: Fetch Exa web sources with translated English query =====
  console.log(`\n┌─ STAGE 5: SOURCE FETCHING ────────────────────────────────────────────────┐`);
  const exaStartTime = Date.now();

  writeSSE(res, {
    type: 'api_started',
    api: 'exa',
    count: 15,
    message: 'Web kaynaklarından arama yapılıyor...',
    query: englishQuery
  });

  console.log(`🌐 [T2-EXA] Starting Exa medical search...`);
  console.log(`   • Query (English): "${englishQuery}"`);
  console.log(`   • Target count: 15 sources`);

  const { searchMedicalSources, formatExaForAI } = await import('./tools/exa-search');

  const exaResults = await searchMedicalSources(englishQuery, 15).catch(() => []);
  const totalSources = exaResults.length;
  const exaDuration = Date.now() - exaStartTime;

  // Send detailed top sources to CLI
  const topSources = exaResults.slice(0, 5).map((result, idx) => ({
    index: idx + 1,
    title: result.title,
    url: result.url,
    domain: result.domain || new URL(result.url).hostname
  }));

  writeSSE(res, {
    type: 'api_completed',
    api: 'exa',
    count: totalSources,
    duration: exaDuration,
    message: `Exa: ${totalSources} kaynak bulundu ✓ (${(exaDuration / 1000).toFixed(1)}s)`,
    success: totalSources > 0,
    searchQuery: englishQuery, // FIXED: Show English query that was actually searched
    topSources: topSources // ADD: Show top sources found
  });

  console.log(`✅ [T2-EXA] Fetch complete:`);
  console.log(`   • Sources found: ${totalSources}`);
  console.log(`   • Duration: ${exaDuration}ms`);
  console.log(`   • Success: ${totalSources > 0 ? 'YES' : 'NO'}`);

  // Log top 3 sources
  if (exaResults.length > 0) {
    console.log(`\n📚 [T2-EXA] Top 3 sources:`);
    exaResults.slice(0, 3).forEach((result, idx) => {
      console.log(`   ${idx + 1}. ${result.title}`);
      console.log(`      URL: ${result.url}`);
      console.log(`      Domain: ${result.domain || new URL(result.url).hostname}`);
    });
  }
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  // ===== STEP 2.5: Source analysis =====
  console.log(`\n┌─ STAGE 5: SOURCE ANALYSIS ────────────────────────────────────────────────┐`);
  writeSSE(res, {
    type: 't2_source_analysis_started',
    message: 'Kaynaklar analiz ediliyor...'
  });

  writeSSE(res, {
    type: 't2_source_analysis_complete',
    totalSources,
    breakdown: {
      exa: exaResults.length
    }
  });

  console.log(`📊 [T2-ANALYSIS] Source breakdown:`);
  console.log(`   • Total sources: ${totalSources}`);
  console.log(`   • Exa web sources: ${exaResults.length}`);
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  // ===== STEP 3: Format sources =====
  const formattedSources = formatSourcesWithTypes(exaResults, [], [], []);

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

  console.log(`\n┌─ STAGE 6: SYNTHESIS ──────────────────────────────────────────────────────┐`);
  console.log(`🤖 [T2-SYNTHESIS] Starting AI synthesis...`);
  console.log(`   • Model: Gemini 2.5 Flash`);
  console.log(`   • Temperature: 0.2`);
  console.log(`   • Max tokens: 3000`);
  console.log(`   • Prompt length: ${userPrompt.length} chars`);

  writeSSE(res, { type: 'generating', message: 'Web araştırma sentezleniyor...' });

  // ===== STEP 6: Call ai.generate() with full conversation context =====
  let stream, response;
  try {
    // Build generate request with optional image
    // FIX: Genkit requires multimodal prompts as array with media + text objects
    let promptContent;
    if (imageBase64) {
      // Multimodal: array format with media object first, then text
      promptContent = [
        { media: { url: `data:image/jpeg;base64,${imageBase64}` } },
        { text: userPrompt }
      ];
      console.log(`🖼️ [T2-IMAGE] Including image in multimodal array format`);
    } else {
      // Text-only: simple string
      promptContent = userPrompt;
    }

    const generateRequest: any = {
      model: getTier2Model(),
      system: systemPrompt,
      prompt: promptContent,
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
    };

    const result = await ai.generateStream(generateRequest);
    stream = result.stream;
    response = result.response;
  } catch (genError: any) {
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
  const finishReason = (finalResponse as any)?.candidates?.[0]?.finishReason || 'unknown';
  const finishMessage = (finalResponse as any)?.candidates?.[0]?.finishMessage || 'none';

  // Extract and track token usage for cost tracking
  const rawResponse = (finalResponse as any).raw || (finalResponse as any).response;
  const usageMetadata = rawResponse?.usageMetadata || (finalResponse as any).usageMetadata;
  const inputTokens = usageMetadata?.promptTokenCount || 0;
  const outputTokens = usageMetadata?.candidatesTokenCount || 0;

  // Track cost for Tier 2 research with web search
  await logTokenUsage({
    featureName: FeatureName.RESEARCH_STANDARD,
    modelName: getTier2Model(),
    inputTokens,
    outputTokens,
    userId,
    metadata: {
      sourceCount: exaResults.length,
      hasImage: !!imageBase64,
      conversationLength: conversationHistory?.length || 0,
      enrichmentDuration: enrichmentDuration,
      exaDuration: exaDuration
    }
  });

  console.log(`✅ [T2-SYNTHESIS] Stream completed:`);
  console.log(`   • Response length: ${fullText.length} chars`);
  console.log(`   • Chunks streamed: ${chunkCount}`);
  console.log(`   • Estimated tokens: ${tokenCount}`);
  console.log(`   • Finish reason: ${finishReason}`);
  if (finishReason !== 'STOP') {
    console.log(`   ⚠️  Abnormal finish: ${finishMessage}`);
  }
  console.log(`   • Last 50 chars: "${fullText.slice(-50)}"`);
  console.log(`└───────────────────────────────────────────────────────────────────────────┘`);

  // If not natural stop, log warning
  if (finishReason !== 'STOP') {
    console.error(`🚨 [T2-ABNORMAL] Stream ended with reason: ${finishReason} - ${finishMessage}`);
  }

  // Flush tokens before complete event
  res.write(': flush-tokens\n\n');
  await new Promise<void>((resolve) => {
    setTimeout(() => resolve(), 200);
  });

  const duration = ((Date.now() - startTime) / 1000).toFixed(2);

  // ===== STEP 8: clientSources already sent earlier in sources_ready event =====

  const evidenceQuality =
    exaResults.length >= 10 ? 'high' :
    exaResults.length >= 7 ? 'moderate' :
    exaResults.length >= 4 ? 'limited' : 'insufficient';

  // Calculate detailed metrics
  const enrichmentTimePercent = ((enrichmentDuration / (Date.now() - startTime)) * 100).toFixed(1);
  const exaTimePercent = ((exaDuration / (Date.now() - startTime)) * 100).toFixed(1);
  const synthesisTimePercent = (100 - parseFloat(enrichmentTimePercent) - parseFloat(exaTimePercent)).toFixed(1);

  // ===== STEP 9: Send complete event (no sessionId) =====
  writeSSE(res, {
    type: 'complete',
    sources: clientSources,
    metadata: {
      processingTime: `${duration}s`,
      modelUsed: 'Gemini 2.5 Flash (Web Araştırma)',
      costTier: 'low',
      stageBreakdown: {
        enrichment: `${(enrichmentDuration / 1000).toFixed(2)}s (${enrichmentTimePercent}%)`,
        exaFetch: `${(exaDuration / 1000).toFixed(2)}s (${exaTimePercent}%)`,
        synthesis: `${synthesisTimePercent}%`
      }
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

  // ===== COMPREHENSIVE SUMMARY LOG =====
  console.log(`\n╔════════════════════════════════════════════════════════════════════════════╗`);
  console.log(`║ ✅ T2: WEB SEARCH RESEARCH COMPLETE                                       ║`);
  console.log(`╚════════════════════════════════════════════════════════════════════════════╝`);
  console.log(`📊 [T2-SUMMARY] Performance Metrics:`);
  console.log(`   • Total duration: ${duration}s`);
  console.log(`   • Query enrichment: ${(enrichmentDuration / 1000).toFixed(2)}s (${enrichmentTimePercent}%)`);
  console.log(`   • Exa API fetch: ${(exaDuration / 1000).toFixed(2)}s (${exaTimePercent}%)`);
  console.log(`   • Synthesis: ${synthesisTimePercent}%`);
  console.log(`\n📚 [T2-SUMMARY] Sources:`);
  console.log(`   • Total sources: ${totalSources}`);
  console.log(`   • Evidence quality: ${evidenceQuality}`);
  console.log(`   • Exa medical sources: ${exaResults.length}`);
  console.log(`\n💬 [T2-SUMMARY] Response:`);
  console.log(`   • Response length: ${fullText.length} chars`);
  console.log(`   • Token count: ~${tokenCount}`);
  console.log(`   • Chunks streamed: ${chunkCount}`);
  console.log(`\n🎯 [T2-SUMMARY] Context:`);
  console.log(`   • Original query: "${question.substring(0, 60)}${question.length > 60 ? '...' : ''}"`);
  console.log(`   • Enriched query: "${searchQuery.substring(0, 60)}${searchQuery.length > 60 ? '...' : ''}"`);
  console.log(`   • Context used: ${enrichedQueryResult.contextUsed}`);
  console.log(`\n╚════════════════════════════════════════════════════════════════════════════╝\n`);
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
async function streamDeepResearch(
  res: Response,
  question: string,
  userId: string,
  diabetesProfile?: any,
  conversationHistory?: Array<{ role: string; content: string; imageBase64?: string }>
): Promise<void> {
  const startTime = Date.now();

  console.log(`🔵 [T3] Processing deep research for user ${userId}`);

  if (conversationHistory && conversationHistory.length > 0) {
    console.log(`🧠 [T3-MEMORY] Using conversation history: ${conversationHistory.length} messages`);
  }

  // Extract image from current query (last message in history)
  let imageBase64: string | undefined;
  if (conversationHistory && conversationHistory.length > 0) {
    const lastUserMessage = [...conversationHistory].reverse().find(msg => msg.role === 'user');
    if (lastUserMessage?.imageBase64) {
      imageBase64 = lastUserMessage.imageBase64;
      console.log(`🖼️ [T3-IMAGE] Found image attachment in conversation history`);
    }
  }

  // ===== STEP 0.5: Fetch cross-conversation memory context =====
  writeSSE(res, { type: 'searching_memory', message: 'Önceki konuşmalar kontrol ediliyor...' });
  const memoryContext = await getMemoryContext(userId);
  const formattedMemory = formatMemoryContext(memoryContext);

  if (formattedMemory) {
    console.log(`🧠 [T3-MEMORY] Using cross-conversation memory: ${memoryContext.factCount} facts, ${memoryContext.summaryCount} summaries`);
  }

  // ===== STEP 1: Execute deep research V2 =====
  const { executeDeepResearchV2, formatResearchForSynthesis } = await import('./flows/deep-research-v2');

  const researchResults = await executeDeepResearchV2(question, res);

  console.log(
    `✅ [T3-STATELESS] Research complete: ${researchResults.rounds.length} rounds, ` +
    `${researchResults.totalSources} sources`
  );

  // ===== STEP 2: Build system prompt with source count =====
  const systemPrompt = buildTier3PromptImproved(researchResults.totalSources);

  // ===== STEP 3: Format sources =====
  const formattedSources = formatSourcesWithTypes(
    researchResults.allSources.exa,
    researchResults.allSources.pubmed,
    researchResults.allSources.medrxiv,
    researchResults.allSources.clinicalTrials
  );

  // ===== STEP 3.5: Emit synthesis_started event before building prompt =====
  // This signals the final research stage to the iOS app
  writeSSE(res, {
    type: 'synthesis_started',
    totalRounds: researchResults.rounds.length,
    totalSources: researchResults.totalSources,
    sequence: 220
  });

  console.log(
    `🎯 [T3-SYNTHESIS] Starting synthesis: ${researchResults.rounds.length} rounds, ` +
    `${researchResults.totalSources} sources`
  );

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
  // Build generate request with optional image
  // FIX: Genkit requires multimodal prompts as array with media + text objects
  let promptContent;
  if (imageBase64) {
    // Multimodal: array format with media object first, then text
    promptContent = [
      { media: { url: `data:image/jpeg;base64,${imageBase64}` } },
      { text: userPrompt }
    ];
    console.log(`🖼️ [T3-IMAGE] Including image in multimodal array format`);
  } else {
    // Text-only: simple string
    promptContent = userPrompt;
  }

  const generateRequest: any = {
    model: getTier3Model(),
    system: systemPrompt,
    prompt: promptContent,
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
  };

  const { stream, response } = await ai.generateStream(generateRequest);

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
  const finishReason = (finalT3Response as any)?.candidates?.[0]?.finishReason || 'unknown';
  const finishMessage = (finalT3Response as any)?.candidates?.[0]?.finishMessage || 'none';

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
  await new Promise<void>((resolve) => {
    setTimeout(() => resolve(), 200);
  });

  const finalResponse = await response;
  const thinkingSummary = extractReasoningFromGenerateResponse(finalResponse);

  // Extract token usage
  const rawResponse = (finalResponse as any).raw || (finalResponse as any).response;
  const usageMetadata = rawResponse?.usageMetadata || (finalResponse as any).usageMetadata;

  const outputTokens = usageMetadata?.candidatesTokenCount || 0;
  const inputTokens = usageMetadata?.promptTokenCount || 0;
  const totalTokens = usageMetadata?.totalTokenCount || 0;

  // Track cost for Tier 3 deep research
  await logTokenUsage({
    featureName: FeatureName.RESEARCH_DEEP,
    modelName: getTier3Model(),
    inputTokens,
    outputTokens,
    userId: question, // Using question as identifier since no userId provided
    metadata: {
      rounds: researchResults.rounds.length,
      estimatedRounds: researchResults.plan.estimatedRounds,
      strategy: researchResults.plan.strategy
    }
  });

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
export const diabetesAssistantStream = onRequest(
  {
    region: 'us-central1',
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 540, // 9 minutes - Required for T3 Deep Research (5-7 min processing time)
    memory: '1GiB' // Increased for deep research with 25+ sources
  },
  async (req, res) => {
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

      const routing = await routeQuestion({
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
        const canProceed = await checkTier3RateLimit(userId);
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
      } else if (routing.tier === 2) {
        // Tier 2: Web Search with conversation history
        await streamTier2Hybrid(res, question, userId, diabetesProfile, conversationHistory);
        // Complete event already sent inside streamTier2Hybrid
      } else {
        // Tier 3: Deep Research with conversation history
        await streamDeepResearch(res, question, userId, diabetesProfile, conversationHistory);
        // Complete event already sent inside streamDeepResearch
      }

      // Stop keep-alive
      stopKeepAlive();

      // ✅ FIX: Ensure ALL data is flushed before closing
      console.log(`🔍 [STREAM-FIX] Starting graceful shutdown sequence - totalBytes: ${totalBytes}`);

      // Force flush
      if (typeof (res as any).flush === 'function') {
        (res as any).flush();
        console.log(`💧 [STREAM-FIX] Forced final flush before shutdown`);
      }

      // Write padding
      res.write('\n\n\n\n');
      console.log(`🔍 [STREAM-FIX] Padding newlines written`);

      // Send end comment
      res.write(': stream-end\n\n');
      console.log(`🔍 [STREAM-FIX] End-of-stream comment sent`);

      // Force flush again
      if (typeof (res as any).flush === 'function') {
        (res as any).flush();
        console.log(`💧 [STREAM-FIX] Forced flush after padding`);
      }

      console.log(`✅ [STREAM-STATELESS] Completed. Size: ${(totalBytes / 1024).toFixed(2)} KB`);
      console.log(`📤 [STREAM-STATELESS] Waiting for network buffers to drain...`);

      // Wait for buffers to drain
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          console.log(`🔒 [STREAM-FIX] 1000ms grace period complete - closing connection`);
          res.end();
          console.log(`🔒 [STREAM-FIX] res.end() called - connection closed gracefully`);
          resolve();
        }, 1000);
      });

      console.log(`✅ [STREAM-FIX] Graceful shutdown complete`);

    } catch (error: any) {
      console.error('❌ [STREAM-STATELESS] Error:', error);
      stopKeepAlive();

      // Log error with structured context
      const errorContext: ErrorContext = {
        userId: req.body?.userId,
        operation: 'streaming endpoint',
        query: req.body?.question
      };

      logError(undefined, error, errorContext);

      // Get user-friendly error message (don't expose internal details)
      const userMessage = getUserFriendlyMessage(error);

      writeSSE(res, {
        type: 'error',
        message: userMessage
      });
      res.end();
    }
  }
);
