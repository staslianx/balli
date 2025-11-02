# Classifier vs Router - What's the Difference?

Both are AI models that classify user input, but they serve **completely different purposes**.

---

## 🎯 Quick Comparison

| Feature | **Classifier** | **Router** |
|---------|----------------|------------|
| **Model** | `gemini-2.5-flash` | `gemini-2.5-flash-lite` |
| **Purpose** | Determines **what context is needed** | Determines **which tier to use** |
| **Used For** | Memory/context optimization | Tier selection (T1/T2/T3) |
| **Input** | User message | User question |
| **Output** | Intent + context requirements | Tier number (1/2/3) + reasoning |
| **When Called** | Before retrieving context (optional) | Every query (required) |
| **Cost** | ~$0.0002/call | ~$0.0001/call |
| **Speed** | 300-500ms | 200-300ms |
| **Status** | 🟡 Defined but not actively used | ✅ Actively used in every query |

---

## 📋 Classifier: Intent & Context Analysis

### Purpose
**Determines what kind of conversation context is needed** to answer the user's message efficiently.

### Model
```typescript
classifier: 'googleai/gemini-2.5-flash'  // Better quality for nuanced intent detection
```

### What It Does
Analyzes user messages to determine:
1. **Category**: `greeting` | `health_query` | `memory_recall` | `follow_up` | `general`
2. **Context Needed**:
   - `immediate`: Last 2-3 messages (almost always true)
   - `session`: Current session context (true for follow-ups)
   - `historical`: Previous sessions (true for recall requests)
   - `vectorSearch`: Semantic similarity search (true for complex queries)

### Example Input
```
"Hatırlıyor musun, geçen hafta metformin hakkında konuşmuştuk?"
(Do you remember, we talked about metformin last week?)
```

### Example Output
```json
{
  "category": "memory_recall",
  "confidence": 0.95,
  "keywords": ["hatırlıyor musun", "geçen hafta", "metformin"],
  "contextNeeded": {
    "immediate": true,
    "session": true,
    "historical": true,
    "vectorSearch": true
  },
  "reasoning": "Kullanıcı geçmiş konuşmayı hatırlatma istiyor"
}
```

### Where Used
```typescript
// functions/src/intent-classifier.ts:39-80
export async function classifyMessageIntent(message: string): Promise<MessageIntent> {
  const classifierModel = getClassifierModel(); // gemini-2.5-flash

  const response = await ai.generate({
    model: classifierModel,
    config: {
      temperature: 0.1,
      maxOutputTokens: 300
    },
    prompt: classificationPrompt
  });
}
```

### Why It Exists
**Cost optimization**: Instead of loading all conversation history for every query, the classifier determines what context is actually needed:
- Greeting? Only need immediate context (cheap)
- Health query? Need vectorSearch (moderate cost)
- Memory recall? Need historical + vectorSearch (expensive but necessary)

### Current Status
🟡 **Defined but not actively used** - The infrastructure exists but it's not called in the main flow yet. It was designed for future context optimization.

---

## 🔀 Router: Tier Selection

### Purpose
**Determines which processing tier (T1/T2/T3)** should handle the user's question.

### Model
```typescript
router: 'googleai/gemini-2.5-flash-lite'  // Faster/cheaper for simple classification
```

### What It Does
Analyzes user questions to determine:
1. **Tier**: `0` (recall) | `1` (model) | `2` (web search) | `3` (deep research)
2. **Reasoning**: Why this tier was selected
3. **Confidence**: How confident the router is (0-1)
4. **Flags**: `explicitDeepRequest`, `isRecallRequest`

### Tier Decision Logic

**Tier 0 (RECALL)** - Not implemented yet
- User explicitly asking about past conversations
- Examples: "Hatırlıyor musun", "Daha önce ne konuşmuştuk"

**Tier 1 (MODEL)** - 40% of queries
- Simple questions answerable from model's knowledge
- No research needed
- Examples: "Diyabet nedir?", "A1C ne demek?"

**Tier 2 (WEB SEARCH)** - 40% of queries
- Needs current information
- Contains "araştır" keyword (but NOT "derinlemesine araştır")
- Examples: "Metformin yan etkileri araştır", "SGLT2 ilaçları araştır"

**Tier 3 (DEEP RESEARCH)** - 20% of queries (user-controlled)
- User explicitly requests deep research: "derinlemesine araştır"
- Complex medical queries requiring multi-source verification
- Examples: "Metformin yan etkileri derinlemesine araştır"

### Example Input
```
"Metformin yan etkileri araştır"
(Research metformin side effects)
```

### Example Output
```json
{
  "tier": 2,
  "reasoning": "User explicitly requested research with 'araştır' keyword. Not deep research (no 'derinlemesine'), so T2 web search is appropriate.",
  "confidence": 0.9,
  "explicitDeepRequest": false
}
```

### Where Used
```typescript
// functions/src/flows/router-flow.ts:306
export async function routeQuestion(input: RouterInput): Promise<RouterOutput> {
  const response = await ai.generate({
    model: getRouterModel(), // gemini-2.5-flash-lite
    config: {
      temperature: 0.1,
      maxOutputTokens: 256
    },
    system: SYSTEM_PROMPT,
    prompt: userPrompt
  });
}
```

### Current Status
✅ **Actively used** - Called for **every single query** in the diabetes assistant. This is the critical decision point that determines the entire processing path.

---

## 🔍 Detection Patterns

### Classifier Patterns
```typescript
// Detects conversation intent
- "Merhaba" → greeting (immediate context only)
- "Diyabet nedir?" → health_query (new topic, vectorSearch)
- "Peki insülin?" → follow_up (session context)
- "Hatırlıyor musun?" → memory_recall (historical + vectorSearch)
```

### Router Patterns
```typescript
// Detects processing tier
RECALL_PATTERNS:
- /hatırlıyor\s+musun/i
- /daha\s+önce/i
- /geçen\s+sefer/i

RESEARCH_PATTERNS (T2):
- /araştır/i
- /incele/i
- /bul/i

DEEP_RESEARCH_PATTERNS (T3):
- /derinlemesine\s+araştır/i
- /detaylı\s+araştır/i
- /kapsamlı\s+araştır/i
```

---

## 📊 Usage Flow

### Complete Query Flow (Both Systems)

```
USER: "Hatırlıyor musun, metformin araştırmıştık?"

┌─────────────────────────────────────────────┐
│ 1. CLASSIFIER (Optional, not used currently)│
│    Model: gemini-2.5-flash                  │
└─────────────────────────────────────────────┘
         ↓ (if implemented)
   {
     category: "memory_recall",
     contextNeeded: {
       immediate: true,
       session: true,
       historical: true,
       vectorSearch: true
     }
   }
         ↓ (load appropriate context)

┌─────────────────────────────────────────────┐
│ 2. ROUTER (Always called)                   │
│    Model: gemini-2.5-flash-lite             │
└─────────────────────────────────────────────┘
         ↓
   {
     tier: 0,  // RECALL tier
     reasoning: "User asking about past research",
     isRecallRequest: true,
     searchTerms: "metformin"
   }
         ↓

┌─────────────────────────────────────────────┐
│ 3. TIER 0 Handler (Recall)                  │
│    Search past conversations for "metformin" │
└─────────────────────────────────────────────┘
```

---

## 💰 Cost Comparison

### Classifier
```typescript
Input:  "Hatırlıyor musun, geçen hafta metformin hakkında konuşmuştuk?"
Tokens: ~25 input, ~100 output = 125 tokens
Cost:   125 / 1,000,000 * ($0.15 + $0.60) = $0.0001
```

### Router
```typescript
Input:  "Metformin yan etkileri derinlemesine araştır"
Tokens: ~15 input, ~80 output = 95 tokens
Cost:   95 / 1,000,000 * ($0.075 + $0.30) = $0.00004
```

**Router is 2.5x cheaper** because it uses Flash Lite instead of Flash.

---

## 🤔 Why Two Different Systems?

### Different Optimization Goals

**Classifier** (not currently used):
- **Goal**: Reduce context retrieval costs
- **Problem**: Loading full conversation history for every query is expensive
- **Solution**: Determine minimum context needed (immediate vs session vs historical)
- **Benefit**: Could save 50-80% on context retrieval costs
- **Model**: Flash (better quality for nuanced intent detection)

**Router** (actively used):
- **Goal**: Select optimal processing tier
- **Problem**: Every query needs different level of processing
- **Solution**: Route to T1 (cheap, fast) vs T2 (moderate) vs T3 (expensive, thorough)
- **Benefit**: 90% cost savings on simple queries
- **Model**: Flash Lite (speed over quality for classification)

---

## 🎯 Key Differences Summary

### Classifier
- **Answers**: "What **context** do I need to load?"
- **Input**: User message (conversational)
- **Output**: Intent + context flags (immediate/session/historical/vectorSearch)
- **Goal**: Optimize **memory retrieval** costs
- **Model**: Flash (needs quality for intent detection)
- **Status**: Infrastructure exists but not actively used

### Router
- **Answers**: "Which **tier** should process this?"
- **Input**: User question (query)
- **Output**: Tier number (0/1/2/3) + reasoning
- **Goal**: Optimize **processing** path
- **Model**: Flash Lite (speed matters, simple classification)
- **Status**: Used in every single query

---

## 🔮 Future Plans

### Classifier Activation
The classifier could be activated to optimize context retrieval:

```typescript
// Current: Always load full context (expensive)
const context = await loadAllConversationHistory(userId);

// Future: Load only what's needed (cheap)
const intent = await classifyMessageIntent(message);
if (intent.contextNeeded.immediate) {
  context = await loadLastFewMessages(userId, 3);
}
if (intent.contextNeeded.historical) {
  context += await loadPastSessions(userId, intent.keywords);
}
```

This could reduce context loading costs by 50-80%.

### Combined Usage
Both systems working together:

```typescript
1. Classifier → Determines what context to load
2. Load appropriate context (optimized)
3. Router → Determines which tier to use
4. Process query with selected tier
```

---

## 📝 Code Locations

### Classifier
- **Definition**: `functions/src/providers.ts:85,101`
- **Implementation**: `functions/src/intent-classifier.ts`
- **Usage**: `functions/src/index.ts:1225` (not in main flow yet)

### Router
- **Definition**: `functions/src/providers.ts:86,102`
- **Implementation**: `functions/src/flows/router-flow.ts`
- **Usage**: `functions/src/diabetes-assistant-stream.ts:862` (every query)

---

## 🎓 In Simple Terms

**Classifier** = "What memories do I need to remember to answer this?"
- Do I need to remember the last 3 messages? ✓
- Do I need to remember this entire conversation? ✓
- Do I need to search through all past conversations? ✓
- Not currently active

**Router** = "How deeply should I research this question?"
- Just answer from knowledge (T1) ✓
- Quick web search (T2) ✓
- Deep multi-source research (T3) ✓
- Used for every query

Both are **classification models**, but they classify **different things** for **different optimization goals**.
