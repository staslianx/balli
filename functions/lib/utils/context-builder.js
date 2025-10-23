"use strict";
/**
 * Context Builder - PHASE 4
 * Builds context using CORRECTED fallback chain for Turkish pronoun resolution
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildContextFromSources = buildContextFromSources;
/**
 * Build context using corrected fallback chain:
 * Priority 1: Conversation State (structured entities for pronouns)
 * Priority 2: Raw Messages (when state lacks detail)
 * Priority 3: Vector Search (cross-session only, if provided)
 */
function buildContextFromSources(conversationState, messageHistory, vectorContext) {
    const contextParts = [];
    // ============================================
    // PRIORITY 1: CONVERSATION STATE (Best for Turkish pronouns)
    // ============================================
    if (conversationState && hasUsefulState(conversationState)) {
        contextParts.push('## 📊 STRUCTURED CONVERSATION CONTEXT\n');
        // Current topic
        if (conversationState.discourse.currentTopic) {
            contextParts.push(`**Current Topic:** ${conversationState.discourse.currentTopic}\n`);
        }
        // Medications (for "bunların" resolution)
        if (conversationState.entities.medications.length > 0) {
            contextParts.push('\n### 💊 Medications Discussed:');
            conversationState.entities.medications
                .sort((a, b) => b.salience - a.salience) // Most salient first
                .slice(0, 5) // Top 5
                .forEach((med, i) => {
                contextParts.push(`${i + 1}. **${med.name}** (turn ${med.mentionedTurn})`);
            });
        }
        // Foods (for "bunların" resolution)
        if (conversationState.entities.foods.length > 0) {
            contextParts.push('\n### 🍽️ Foods Discussed:');
            conversationState.entities.foods
                .sort((a, b) => b.salience - a.salience)
                .slice(0, 5)
                .forEach((food, i) => {
                contextParts.push(`${i + 1}. **${food.name}** (turn ${food.mentionedTurn})`);
            });
        }
        // Measurements
        if (conversationState.entities.measurements.length > 0) {
            contextParts.push('\n### 📊 Recent Measurements:');
            conversationState.entities.measurements
                .slice(-3) // Last 3
                .forEach((m, i) => {
                contextParts.push(`${i + 1}. **${m.type}**: ${m.value} ${m.unit} (turn ${m.turn})`);
            });
        }
        // AI outputs (for "ilk ikisi" resolution)
        if (conversationState.aiOutputs.listsPresented.length > 0) {
            const latestList = conversationState.aiOutputs.listsPresented[conversationState.aiOutputs.listsPresented.length - 1];
            contextParts.push('\n### 📝 Most Recent List I Presented:');
            contextParts.push(`**Context:** ${latestList.context}`);
            latestList.items.slice(0, 5).forEach((item, i) => {
                contextParts.push(`${i + 1}. ${item}`);
            });
        }
        // CRITICAL: Turkish pronoun resolution rules
        contextParts.push('\n### 🔍 REFERENCE RESOLUTION RULES:');
        contextParts.push('- **"bunların" (these)** → Most recent plural entities (foods/medications from above numbered lists)');
        contextParts.push('- **"ilk ikisi" (first two)** → Items 1-2 from most recent list');
        contextParts.push('- **"o" (that)** → Most recent singular entity (highest salience)');
        contextParts.push('- **"onlar" (those)** → All entities from current topic');
        contextParts.push('- **"hangisi" (which one)** → Compare by salience, ask for clarification if ambiguous');
    }
    // ============================================
    // PRIORITY 2: RAW MESSAGES (Fallback for details)
    // ============================================
    // Always include recent messages for continuity
    const recentMessages = messageHistory.slice(-3); // Last 3 messages
    if (recentMessages.length > 0) {
        contextParts.push('\n## 💬 RECENT CONVERSATION:');
        recentMessages.forEach((msg) => {
            const role = msg.role === 'user' ? '👤 USER' : '🤖 ASSISTANT';
            const preview = msg.content.length > 150
                ? msg.content.substring(0, 150) + '...'
                : msg.content;
            contextParts.push(`\n**${role}** (turn ${msg.turnNumber}):\n${preview}`);
        });
    }
    // ============================================
    // PRIORITY 3: VECTOR SEARCH (Cross-session if provided)
    // ============================================
    if (vectorContext && vectorContext.trim().length > 0) {
        contextParts.push('\n## 🔍 FROM PREVIOUS SESSIONS:');
        contextParts.push(vectorContext);
    }
    // ============================================
    // EDGE CASE: NO CONTEXT AVAILABLE
    // ============================================
    if (contextParts.length === 0) {
        return '## ⚠️ NO CONTEXT AVAILABLE\nThis appears to be the first message. Treat as standalone question.';
    }
    return contextParts.join('\n');
}
/**
 * Check if conversation state has useful information
 */
function hasUsefulState(state) {
    return (state.entities.medications.length > 0 ||
        state.entities.foods.length > 0 ||
        state.entities.measurements.length > 0 ||
        state.aiOutputs.listsPresented.length > 0 ||
        (state.discourse.currentTopic !== '' && state.discourse.currentTopic !== 'genel sohbet'));
}
//# sourceMappingURL=context-builder.js.map