"use strict";
/**
 * Conversation State Extractor
 *
 * Extracts comprehensive conversation state from user-AI exchanges
 * using AI-powered analysis with heuristic fallback.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractConversationState = extractConversationState;
const genkit_instance_1 = require("./genkit-instance");
const providers_1 = require("./providers");
const conversation_state_1 = require("./types/conversation-state");
/**
 * State extraction prompt for AI
 */
const STATE_EXTRACTION_PROMPT = `You are a conversation state analyzer for a Turkish diabetes health assistant.

Extract structured state from this exchange. Be PRECISE and MEDICAL-CONTEXT-AWARE.

OUTPUT ONLY VALID JSON matching this exact structure:
{
  "entities": {
    "medications": [{"name": "Novorapid", "salience": 1.0}],
    "foods": [{"name": "karbonhidrat", "salience": 0.9}],
    "measurements": [{"type": "kan şekeri", "value": 180, "unit": "mg/dL"}],
    "symptoms": [{"name": "titreme", "salience": 0.8}],
    "exercises": [],
    "medicalTerms": []
  },
  "discourse": {
    "currentTopic": "insülin dozajı",
    "lastQuestion": {
      "type": "how_much",
      "subject": "insülin dozu",
      "verb": "vurmalı"
    },
    "lastStatement": {
      "claim": "40 gram karbonhidrat dengeli",
      "by": "assistant"
    }
  },
  "aiOutputs": {
    "listsPresented": [{"items": ["yürüyüş", "yüzme"], "context": "egzersiz seçenekleri"}],
    "recommendations": [{"what": "50 gram karbonhidrat", "reason": "daha aktifsen"}],
    "proceduresExplained": [],
    "examples": []
  }
}

CRITICAL RULES:
1. Extract ONLY what's explicitly mentioned
2. Medical terms in Turkish or English (preserve language)
3. Salience 1.0 = most recent mention, decay for older
4. Empty arrays for missing data
5. NO explanations, ONLY JSON`;
/**
 * Extract conversation state using AI - PHASE 2: INCREMENTAL
 * Only processes NEW messages since last extraction for 10x speed improvement
 */
async function extractConversationState(messageHistory, previousState) {
    const startTime = Date.now();
    // PHASE 2: Calculate which messages are NEW
    const previousMessageCount = previousState?.messageCount || 0;
    const newMessages = messageHistory.slice(previousMessageCount);
    // OPTIMIZATION: If no new messages, return previous state immediately
    if (newMessages.length === 0) {
        console.log(`✅ [STATE] No new messages - returning cached state`);
        return {
            state: previousState || (0, conversation_state_1.initializeConversationState)('system'),
            extractionTime: 0,
            success: true,
            usedFallback: false
        };
    }
    console.log(`🔄 [STATE] Processing ${newMessages.length} new messages ` +
        `(total: ${messageHistory.length}, previous: ${previousMessageCount})`);
    try {
        // Build extraction prompt with ONLY new messages
        const newMessagesText = newMessages.map((m, i) => `[${m.role}, turn ${m.turnNumber}]: ${m.content}`).join('\n');
        const prompt = `${STATE_EXTRACTION_PROMPT}

PREVIOUS STATE (for continuity):
${previousState ? JSON.stringify(previousState, null, 2) : 'null'}

NEW MESSAGES TO PROCESS:
${newMessagesText}

Extract updated state as JSON (merge with previous state):`;
        // Call AI for extraction
        const response = await genkit_instance_1.ai.generate({
            model: (0, providers_1.getTier1Model)(),
            prompt,
            config: {
                temperature: 0.1, // Low temp for consistent extraction
                maxOutputTokens: 1500,
                thinkingConfig: {
                    thinkingBudget: 0
                }
            }
        });
        // Parse JSON response
        const extracted = parseExtractionResponse(response.text, previousState, messageHistory.length);
        if (extracted) {
            // PHASE 2: Ensure messageCount is set correctly
            extracted.messageCount = messageHistory.length;
            return {
                state: extracted,
                extractionTime: Date.now() - startTime,
                success: true,
                usedFallback: false
            };
        }
        // If parsing failed, use fallback
        console.warn('⚠️ [STATE] AI extraction parse failed, using fallback');
        return fallbackExtraction(messageHistory, previousState, startTime);
    }
    catch (error) {
        console.error('❌ [STATE] AI extraction failed:', error);
        return fallbackExtraction(messageHistory, previousState, startTime);
    }
}
/**
 * Parse AI extraction response
 */
function parseExtractionResponse(response, previousState, turnNumber) {
    try {
        // Extract JSON from response (might have markdown code blocks)
        const jsonMatch = response.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            return null;
        }
        const parsed = JSON.parse(jsonMatch[0]);
        // Build full state from parsed extraction
        const baseState = previousState || (0, conversation_state_1.initializeConversationState)('unknown');
        return {
            entities: {
                medications: mergeEntityMentions(baseState.entities.medications, parsed.entities?.medications || [], turnNumber),
                foods: mergeEntityMentions(baseState.entities.foods, parsed.entities?.foods || [], turnNumber),
                measurements: mergeMeasurements(baseState.entities.measurements, parsed.entities?.measurements || [], turnNumber),
                symptoms: mergeEntityMentions(baseState.entities.symptoms, parsed.entities?.symptoms || [], turnNumber),
                exercises: mergeEntityMentions(baseState.entities.exercises, parsed.entities?.exercises || [], turnNumber),
                medicalTerms: mergeEntityMentions(baseState.entities.medicalTerms, parsed.entities?.medicalTerms || [], turnNumber)
            },
            discourse: {
                currentTopic: parsed.discourse?.currentTopic || baseState.discourse.currentTopic,
                previousTopic: baseState.discourse.currentTopic || null,
                lastQuestion: parsed.discourse?.lastQuestion ? {
                    ...parsed.discourse.lastQuestion,
                    fullQuestion: '',
                    turn: turnNumber
                } : baseState.discourse.lastQuestion,
                lastStatement: parsed.discourse?.lastStatement ? {
                    ...parsed.discourse.lastStatement,
                    turn: turnNumber
                } : baseState.discourse.lastStatement,
                openQuestions: baseState.discourse.openQuestions
            },
            aiOutputs: {
                listsPresented: [
                    ...baseState.aiOutputs.listsPresented,
                    ...(parsed.aiOutputs?.listsPresented || []).map((list) => ({
                        ...list,
                        turn: turnNumber
                    }))
                ].slice(-5), // Keep last 5 lists
                recommendations: [
                    ...baseState.aiOutputs.recommendations,
                    ...(parsed.aiOutputs?.recommendations || []).map((rec) => ({
                        ...rec,
                        turn: turnNumber
                    }))
                ].slice(-5),
                proceduresExplained: [
                    ...baseState.aiOutputs.proceduresExplained,
                    ...(parsed.aiOutputs?.proceduresExplained || []).map((proc) => ({
                        ...proc,
                        turn: turnNumber
                    }))
                ].slice(-3),
                examples: [
                    ...baseState.aiOutputs.examples,
                    ...(parsed.aiOutputs?.examples || []).map((ex) => ({
                        ...ex,
                        turn: turnNumber
                    }))
                ].slice(-5)
            },
            procedural: baseState.procedural,
            commitments: baseState.commitments,
            turnCount: turnNumber,
            lastUpdated: new Date(),
            userId: baseState.userId
        };
    }
    catch (error) {
        console.error('❌ [STATE] Parse error:', error);
        return null;
    }
}
/**
 * Merge entity mentions with salience decay
 */
function mergeEntityMentions(existing, newMentions, currentTurn) {
    const merged = new Map();
    // Add existing with decayed salience
    for (const entity of existing) {
        const decay = Math.max(0.3, 1.0 - (currentTurn - entity.mentionedTurn) * 0.1);
        merged.set(entity.name.toLowerCase(), {
            ...entity,
            salience: entity.salience * decay
        });
    }
    // Add/update new mentions
    for (const mention of newMentions) {
        merged.set(mention.name.toLowerCase(), {
            name: mention.name,
            mentionedTurn: currentTurn,
            mentionedBy: mention.by || 'assistant',
            salience: mention.salience || 1.0
        });
    }
    // Return sorted by salience, keep top 10
    return Array.from(merged.values())
        .sort((a, b) => b.salience - a.salience)
        .slice(0, 10);
}
/**
 * Merge measurements
 */
function mergeMeasurements(existing, newMeasurements, currentTurn) {
    const all = [
        ...existing,
        ...newMeasurements.map(m => ({
            type: m.type,
            value: m.value,
            unit: m.unit,
            timestamp: new Date().toISOString(),
            turn: currentTurn
        }))
    ];
    // Keep last 10 measurements
    return all.slice(-10);
}
/**
 * Fallback extraction using regex patterns
 */
function fallbackExtraction(messageHistory, previousState, startTime) {
    const baseState = previousState || (0, conversation_state_1.initializeConversationState)('unknown');
    // PHASE 2: Extract from NEW messages only
    const previousMessageCount = previousState?.messageCount || 0;
    const newMessages = messageHistory.slice(previousMessageCount);
    const allNewText = newMessages.map(m => m.content).join(' ');
    const latestTurn = newMessages.length > 0 ? newMessages[newMessages.length - 1].turnNumber : 0;
    // Simple regex-based entity extraction
    const medications = extractMedications(allNewText);
    const foods = extractFoods(allNewText);
    const measurements = extractMeasurements(allNewText);
    const state = {
        entities: {
            medications: mergeEntityMentions(baseState.entities.medications, medications, latestTurn),
            foods: mergeEntityMentions(baseState.entities.foods, foods, latestTurn),
            measurements: mergeMeasurements(baseState.entities.measurements, measurements, latestTurn),
            symptoms: baseState.entities.symptoms,
            exercises: baseState.entities.exercises,
            medicalTerms: baseState.entities.medicalTerms
        },
        discourse: baseState.discourse,
        aiOutputs: baseState.aiOutputs,
        procedural: baseState.procedural,
        commitments: baseState.commitments,
        turnCount: latestTurn,
        lastUpdated: new Date(),
        userId: baseState.userId,
        messageCount: messageHistory.length // PHASE 2: Track processed messages
    };
    return {
        state,
        extractionTime: Date.now() - startTime,
        success: true,
        usedFallback: true
    };
}
/**
 * Extract medications using patterns
 */
function extractMedications(text) {
    const medications = [];
    const patterns = [
        /\b(novorapid|lantus|humalog|apidra|tresiba|levemir|toujeo)\b/gi,
        /\b(metformin|glukofaj|januvia|jardiance|forxiga)\b/gi
    ];
    for (const pattern of patterns) {
        const matches = text.match(pattern);
        if (matches) {
            for (const match of matches) {
                medications.push({ name: match, salience: 1.0, by: 'user' });
            }
        }
    }
    return medications;
}
/**
 * Extract foods using patterns
 */
function extractFoods(text) {
    const foods = [];
    const patterns = [
        /\b(karbonhidrat|protein|yağ|lif)\b/gi,
        /\b(pilav|ekmek|makarna|patates|meyve|sebze)\b/gi,
        /\b(badem\s+unu|pirinç|buğday|yulaf)\b/gi
    ];
    for (const pattern of patterns) {
        const matches = text.match(pattern);
        if (matches) {
            for (const match of matches) {
                foods.push({ name: match, salience: 1.0, by: 'user' });
            }
        }
    }
    return foods;
}
/**
 * Extract measurements using patterns
 */
function extractMeasurements(text) {
    const measurements = [];
    // Blood sugar readings
    const bgPattern = /(\d+)\s*(mg\/dl|mg\/dL)?/g;
    let match;
    while ((match = bgPattern.exec(text)) !== null) {
        const value = parseInt(match[1]);
        if (value >= 40 && value <= 600) { // Realistic blood sugar range
            measurements.push({
                type: 'kan şekeri',
                value,
                unit: 'mg/dL'
            });
        }
    }
    // A1C values
    const a1cPattern = /A1[Cc]\s*[:=]?\s*(\d+\.?\d*)/g;
    while ((match = a1cPattern.exec(text)) !== null) {
        measurements.push({
            type: 'A1C',
            value: parseFloat(match[1]),
            unit: '%'
        });
    }
    return measurements;
}
//# sourceMappingURL=conversation-state-extractor.js.map