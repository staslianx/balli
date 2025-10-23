# IN-CONVERSATION MEMORY - IMPLEMENTATION FROM SCRATCH

## GOAL
Implement reliable, consistent memory within a single research session. Every message must be remembered and available as context for all subsequent messages in that session.

---

## SESSION STRUCTURE

### Active Session Object
```javascript
{
  sessionId: string (UUID),
  conversationHistory: [
    {role: "user", content: string, timestamp: number},
    {role: "assistant", content: string, timestamp: number}
  ],
  status: "active" | "complete",
  createdAt: number (unix timestamp),
  lastUpdated: number (unix timestamp)
}
```

### Where to Store
- **In-memory** for current active session (fast access, no DB overhead during conversation)
- **Persist to database** periodically (every 2-3 messages) as backup
- **Write to database** when session completes

---

## MESSAGE FLOW

### 1. USER SENDS MESSAGE

**Step 1: Append to conversation history**
```javascript
activeSession.conversationHistory.push({
  role: "user",
  content: userMessage,
  timestamp: Date.now()
})
activeSession.lastUpdated = Date.now()
```

**Step 2: Build context for LLM**
```javascript
llmMessages = [
  {role: "system", content: "Sen Türkçe konuşan bir araştırma asistanısın..."},
  ...activeSession.conversationHistory  // ALL previous messages
]
```

**Step 3: Send to Router with full context**
- Router receives: userMessage + full conversationHistory
- Router makes decision: recall intent / research tier / general knowledge
- Router has access to full conversation context for better routing decisions

### 2. LLM PROCESSES REQUEST

**For Research:**
- Research tier (Hızlı/Araştırma/Derin) receives full conversation history
- Can reference earlier questions/answers in current session
- Generates response with full context awareness

**For Recall:**
- Search engine finds past sessions
- LLM answers using past session + current conversation context
- Can connect current conversation to past research

### 3. ASSISTANT RESPONDS

**Step 1: Get response from LLM/Research tier**

**Step 2: Append to conversation history**
```javascript
activeSession.conversationHistory.push({
  role: "assistant",
  content: assistantResponse,
  timestamp: Date.now()
})
activeSession.lastUpdated = Date.now()
```

**Step 3: Display response to user**

**Step 4: Auto-save to database (every 2-3 messages)**
```javascript
if (activeSession.conversationHistory.length % 4 === 0) {
  saveSessionToDatabase(activeSession)
}
```

---

## SESSION LIFECYCLE

### START NEW SESSION
**Trigger:** User starts app, or previous session was marked complete

```javascript
activeSession = {
  sessionId: generateUUID(),
  conversationHistory: [],
  status: "active",
  createdAt: Date.now(),
  lastUpdated: Date.now()
}
```

### CONTINUE SESSION
- User sends follow-up messages
- Each message appends to conversationHistory
- Full history always passed to LLM
- Session remains "active"

### END SESSION

**Triggers:**
- User explicitly starts new topic: "yeni konu", "başka bir şey soracağım"
- User closes app
- Inactivity timeout (e.g., 30 minutes of no messages)
- User explicitly says: "tamam yeter", "teşekkürler" (satisfaction signals)

**Actions when session ends:**
```javascript
// 1. Mark session as complete
activeSession.status = "complete"

// 2. Generate metadata using LLM
title = await generateTitle(activeSession.conversationHistory)
summary = await generateSummary(activeSession.conversationHistory)
keyTopics = await extractKeyTopics(activeSession.conversationHistory)

// 3. Save to database
INSERT INTO research_sessions (
  session_id,
  full_conversation,
  title,
  key_topics,
  summary,
  timestamp,
  last_updated,
  status
) VALUES (
  activeSession.sessionId,
  JSON.stringify(activeSession.conversationHistory),
  title,
  JSON.stringify(keyTopics),
  summary,
  activeSession.createdAt,
  activeSession.lastUpdated,
  'complete'
)

// 4. Update FTS5 index for searchability

// 5. Clear active session
activeSession = null
```

### START NEXT SESSION
- Create fresh session object
- Empty conversation history
- Previous session now searchable via cross-conversation memory

---

## TOKEN LIMIT HANDLING

### Context Window Management
- Claude has large context window (200K tokens)
- For personal use, unlikely to hit limits in single session
- But implement smart truncation as safety measure

### If Approaching Token Limit

**Strategy 1 - Rolling Window (simple):**
```javascript
if (estimateTokens(conversationHistory) > 150000) {
  // Keep last 20 message pairs (40 messages total)
  conversationHistory = conversationHistory.slice(-40)
}
```

**Strategy 2 - Summarize + Keep Recent (better):**
```javascript
if (estimateTokens(conversationHistory) > 150000) {
  // Take first half of conversation
  oldMessages = conversationHistory.slice(0, conversationHistory.length / 2)

  // Summarize old messages
  summary = await summarizeConversation(oldMessages)

  // Keep recent messages
  recentMessages = conversationHistory.slice(conversationHistory.length / 2)

  // Rebuild history
  conversationHistory = [
    {role: "assistant", content: `Bu konuşmanın önceki kısmında şunları konuştuk: ${summary}`},
    ...recentMessages
  ]
}
```

**Strategy 3 - Never truncate, end session (safest):**
```javascript
if (estimateTokens(conversationHistory) > 150000) {
  // This is a very long conversation, end it gracefully
  endSession(activeSession)
  startNewSession()
  responseToUser = "Çok uzun bir konuşma yaptık. Yeni bir oturum başlatıyorum ama önceki araştırman kaydedildi, istersen 'daha önce konuştuklarımız' diyerek ulaşabilirsin."
}
```

**Token Estimation:**
```javascript
function estimateTokens(conversationHistory) {
  // Rough estimate: 1 token ≈ 4 characters for Turkish
  totalChars = conversationHistory.reduce((sum, msg) => sum + msg.content.length, 0)
  return totalChars / 4
}
```

---

## INTEGRATION WITH ROUTER

### Router Receives Full Context
```javascript
function router(userMessage, conversationHistory) {
  // Router has access to full conversation
  // Can make better decisions based on context

  // Example: detect topic change
  if (conversationHistory.length > 0) {
    previousTopic = extractTopic(conversationHistory)
    currentTopic = extractTopic(userMessage)

    if (topicsAreDifferent(previousTopic, currentTopic)) {
      // User changed topic, might want to end current session
      suggestNewSession()
    }
  }

  // Check for recall intent
  if (isRecallIntent(userMessage)) {
    return {action: "recall", searchTerms: extractSearchTerms(userMessage)}
  }

  // Route to research tier
  if (needsResearch(userMessage, conversationHistory)) {
    complexity = assessComplexity(userMessage, conversationHistory)
    return {action: "research", tier: complexity}
  }

  // General knowledge
  return {action: "answer", context: conversationHistory}
}
```

### Research Tiers Receive Full Context
```javascript
function performResearch(tier, userMessage, conversationHistory) {
  // Research function has full conversation context
  // Can reference earlier questions/findings

  llmMessages = [
    {role: "system", content: systemPrompt},
    ...conversationHistory  // Full context
  ]

  // Perform research with context awareness
  result = await researchWithContext(tier, llmMessages)

  return result
}
```

---

## PERSISTENCE TO DATABASE

### Auto-save During Active Session
Saves work-in-progress in case of crash/closure. Not for cross-conversation search (only completed sessions are searchable).

```javascript
function autoSaveSession(activeSession) {
  // Check if session exists in DB
  existing = db.query(
    "SELECT session_id FROM research_sessions WHERE session_id = ?",
    activeSession.sessionId
  )

  if (existing) {
    // Update existing record
    db.execute(
      "UPDATE research_sessions SET full_conversation = ?, last_updated = ?, status = ? WHERE session_id = ?",
      [
        JSON.stringify(activeSession.conversationHistory),
        activeSession.lastUpdated,
        activeSession.status,
        activeSession.sessionId
      ]
    )
  } else {
    // Insert new record
    db.execute(
      "INSERT INTO research_sessions (session_id, full_conversation, timestamp, last_updated, status) VALUES (?, ?, ?, ?, ?)",
      [
        activeSession.sessionId,
        JSON.stringify(activeSession.conversationHistory),
        activeSession.createdAt,
        activeSession.lastUpdated,
        activeSession.status
      ]
    )
  }
}
```

### When Session Completes
- Generate title, summary, key_topics
- Update database record with metadata
- Insert into FTS5 for searchability
- Session now available for cross-conversation recall

---

## ERROR HANDLING

### App Crash During Session
Auto-saved session exists in database with status = "active"

```javascript
onAppStart() {
  activeSessions = db.query("SELECT * FROM research_sessions WHERE status = 'active'")

  if (activeSessions.length > 0) {
    // Show user: "Yarım kalan bir araştırman var, devam etmek ister misin?"
    // If yes: load that session as activeSession
    // If no: mark as complete, generate metadata, make searchable
  }
}
```

### LLM Request Fails
- Don't lose user's message
- Message already appended to conversationHistory
- Retry LLM request with same context
- If retry fails, inform user but keep history intact

### Database Write Fails
- Keep activeSession in memory
- Retry on next auto-save opportunity
- On session end, must succeed or show error to user

---

## TESTING CHECKLIST

- ☐ Send 10+ back-and-forth messages in same topic
- ☐ Verify each response references earlier messages when relevant
- ☐ Ask follow-up question referencing something said 5 messages ago
- ☐ Change topic mid-conversation, verify session ends properly
- ☐ Close app during conversation, reopen, verify recovery
- ☐ Test with very long conversation (30+ messages)
- ☐ Test token limit handling (if implemented)
- ☐ Verify auto-save happens periodically
- ☐ Verify completed session becomes searchable
- ☐ Test that router has access to full conversation context

---

## EXAMPLE FLOW

**User starts app:**
→ New session created, empty conversationHistory

**User: "Diyabette Dawn phenomenon nedir?"**
→ Appended to history
→ Router: needs research
→ Research tier (Araştırma) with full context
→ Assistant: [detailed explanation]
→ Appended to history
→ Auto-save to DB

**User: "Peki Somogyi etkisi ne?"**
→ Appended to history (now 2 user, 1 assistant message)
→ Router: related follow-up, needs research
→ Research tier receives FULL conversation (knows Dawn was just discussed)
→ Assistant: [explains Somogyi, can reference Dawn from context]
→ Appended to history
→ Auto-save to DB

**User: "İkisinin farkı ne?"**
→ Appended to history (now 3 user, 2 assistant messages)
→ Router: follow-up question
→ LLM has full context, knows "ikisi" refers to Dawn and Somogyi
→ Assistant: [compares the two]
→ Appended to history

**User: "Tamam anladım, teşekkürler"**
→ Router detects: satisfaction signal, session should end
→ Generate title: "Dawn Phenomenon ve Somogyi Etkisi Karşılaştırması"
→ Generate summary: "Dawn phenomenon ve Somogyi etkisi arasındaki farklar araştırıldı..."
→ Extract key topics: ["Dawn phenomenon", "Somogyi etkisi", "sabah hiperglisemisi"]
→ Save completed session to DB
→ Update FTS5 index
→ Clear activeSession
→ Session now searchable via cross-conversation memory

**User: "Şimdi beta hücre rejenerasyonu araştıralım"**
→ New topic detected
→ New session created
→ Fresh conversationHistory starts

---

## KEY PRINCIPLES

1. **Never lose context**: Every message stays in conversationHistory until session ends
2. **Always pass full history**: Every LLM call gets complete conversation context
3. **Simple data structure**: Just an array of messages, nothing fancy
4. **Clear session boundaries**: Know when to end and start sessions
5. **Fail-safe persistence**: Auto-save prevents data loss
6. **Context-aware routing**: Router and research tiers use conversation history for better decisions

This gives you reliable in-conversation memory that "just works" - no inconsistency, no sudden forgetting.
