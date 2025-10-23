# CROSS-CONVERSATION MEMORY - IMPLEMENTATION FROM SCRATCH

## GOAL
Enable users to recall and retrieve information from past research sessions. When user asks "what was that effect mixed with Dawn?" the system should find the relevant past conversation and answer directly using that context.

---

## DATABASE SCHEMA

### Research Sessions Table
```sql
CREATE TABLE research_sessions (
  session_id TEXT PRIMARY KEY,
  full_conversation TEXT NOT NULL,  -- JSON array of messages
  title TEXT NOT NULL,               -- 5-7 word summary in Turkish
  key_topics TEXT NOT NULL,          -- JSON array of main concepts
  summary TEXT NOT NULL,             -- 2-3 sentence summary in Turkish
  timestamp INTEGER NOT NULL,        -- Unix timestamp when created
  last_updated INTEGER NOT NULL,     -- Unix timestamp of last update
  status TEXT NOT NULL               -- 'active' or 'complete'
);

CREATE INDEX idx_status ON research_sessions(status);
CREATE INDEX idx_timestamp ON research_sessions(timestamp);
```

### FTS5 Search Table
```sql
CREATE VIRTUAL TABLE research_sessions_fts USING fts5(
  session_id UNINDEXED,
  title,
  key_topics,
  summary,
  tokenize='unicode61'  -- Supports Turkish characters
);
```

---

## WHEN TO SAVE SESSIONS

### During Active Session
- Auto-save every 2-3 messages to prevent data loss
- Status remains 'active'
- No metadata generation yet (title, summary, topics are empty)

### When Session Completes

**Triggers:**
- User explicitly starts new topic: "yeni konu", "başka bir şey soracağım"
- User closes app
- Inactivity timeout (e.g., 30 minutes)
- User satisfaction signals: "tamam yeter", "teşekkürler", "anladım"

**Actions:**
1. Mark session status as 'complete'
2. Generate metadata using LLM
3. Save to database with full metadata
4. Insert into FTS5 index for searchability

### Metadata Generation

**Generate Title (5-7 words):**
```
Prompt to LLM:
"Aşağıdaki araştırma konuşmasını 5-7 kelimeyle özetle. Sadece başlığı ver, başka açıklama yapma.

Konuşma:
[full conversation]"
```

**Generate Summary (2-3 sentences):**
```
Prompt to LLM:
"Aşağıdaki araştırma konuşmasının ana bulgularını ve sonuçlarını 2-3 cümleyle özetle.

Konuşma:
[full conversation]"
```

**Extract Key Topics:**
```
Prompt to LLM:
"Aşağıdaki konuşmada bahsedilen ana tıbbi/sağlık kavramlarını listele. Sadece kavram isimlerini ver, virgülle ayır.

Örnek: Dawn phenomenon, Somogyi etkisi, insülin direnci, kortizol

Konuşma:
[full conversation]"
```

### Save to Database
```javascript
function saveCompletedSession(session, title, summary, keyTopics) {
  // Save to main table
  db.execute(
    `INSERT OR REPLACE INTO research_sessions
    (session_id, full_conversation, title, key_topics, summary, timestamp, last_updated, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      session.sessionId,
      JSON.stringify(session.conversationHistory),
      title,
      JSON.stringify(keyTopics),
      summary,
      session.createdAt,
      Date.now(),
      'complete'
    ]
  )

  // Insert into FTS5 for searchability
  db.execute(
    `INSERT INTO research_sessions_fts (session_id, title, key_topics, summary)
    VALUES (?, ?, ?, ?)`,
    [
      session.sessionId,
      title,
      keyTopics.join(', '),
      summary
    ]
  )
}
```

---

## RECALL INTENT DETECTION

### Turkish Language Patterns

Add this as the **first check** in your router, before routing to research tiers.

**Past Tense Verb Forms:**
- "neydi", "ne konuşmuştuk", "ne araştırmıştık", "ne bulmuştuk"
- "ne öğrenmiştik", "ne demiştik", "ne çıkmıştı", "nasıldı"

**Memory/Recall Phrases:**
- "hatırlıyor musun", "hatırla", "hatırlat bana", "hatırlamıyorum"
- "daha önce", "geçen sefer", "o zaman", "geçenlerde"

**Reference Phrases:**
- "o şey", "şu konu", "o araştırma", "o bilgi"
- "şu [topic] ile ilgili olan"

**Implicit Recall (past tense questions):**
- "Dawn ile karışan etki neydi?" (NOT "nedir?")
- "O gece ne olmuştu?" (NOT "ne olur?")
- "Hangi hormon etkiliyordu?" (NOT "etkiler?")

**Key Indicators:**
- Past tense suffixes: -dı, -di, -du, -dü, -tı, -ti, -tu, -tü
- Time references: "daha önce", "geçen", "o zaman"
- Demonstrative pronouns with past context: "o", "şu" + past tense

### Intent Detection Function
```javascript
function detectRecallIntent(userMessage) {
  const pastTensePatterns = [
    /neydi/i, /ne.*muştuk/i, /ne.*mıştık/i,
    /nasıldı/i, /ne.*çıkmıştı/i
  ]

  const memoryPhrases = [
    /hatırlıyor musun/i, /hatırla/i, /hatırlat/i,
    /daha önce/i, /geçen/i, /o zaman/i
  ]

  const referencePhrases = [
    /o şey/i, /şu konu/i, /o araştırma/i,
    /o bilgi/i
  ]

  // Check for any pattern match
  const hasRecallPattern = [
    ...pastTensePatterns,
    ...memoryPhrases,
    ...referencePhrases
  ].some(pattern => pattern.test(userMessage))

  return hasRecallPattern
}
```

---

## SEARCH AND RETRIEVAL

### Extract Search Terms
```javascript
function extractSearchTerms(userMessage) {
  // Remove filler words
  const fillerWords = [
    'o şey', 'şu', 'neydi', 'nasıldı',
    'hatırlıyor musun', 'hatırla', 'hatırlat',
    'daha önce', 'geçen', 'o zaman'
  ]

  let cleanedMessage = userMessage
  fillerWords.forEach(filler => {
    cleanedMessage = cleanedMessage.replace(new RegExp(filler, 'gi'), '')
  })

  // Extract meaningful terms (medical terms, nouns)
  // This could be enhanced with NLP, but simple cleaning works well
  return cleanedMessage.trim()
}
```

### Search FTS5
```javascript
function searchPastSessions(searchTerms) {
  const query = `
    SELECT
      r.session_id,
      r.full_conversation,
      r.title,
      r.summary,
      r.timestamp,
      fts.rank
    FROM research_sessions r
    JOIN research_sessions_fts fts ON r.session_id = fts.session_id
    WHERE research_sessions_fts MATCH ?
    ORDER BY rank, r.timestamp DESC
    LIMIT 5
  `

  const results = db.query(query, [searchTerms])
  return results
}
```

### Ranking and Relevance
- FTS5 provides automatic relevance ranking via `rank`
- More recent sessions used as tiebreaker (timestamp DESC)
- Return top 5 matches maximum
- Set minimum relevance threshold to avoid poor matches

---

## ANSWERING WITH PAST RESEARCH

### When Recall Intent Detected

**Flow:**
1. Extract search terms from user query
2. Search FTS5 index
3. Get top matching session(s)
4. Retrieve full conversation
5. Feed to LLM with special prompt
6. LLM answers directly using past research context

### LLM Prompt Template
```javascript
function buildRecallPrompt(userQuery, pastSession) {
  const conversationText = pastSession.full_conversation
    .map(msg => `${msg.role === 'user' ? 'Kullanıcı' : 'Asistan'}: ${msg.content}`)
    .join('\n\n')

  const formattedDate = formatDate(pastSession.timestamp)

  return `Kullanıcı daha önce yaptığı bir araştırmayı hatırlamaya çalışıyor. İşte o araştırmanın tam konuşması:

Araştırma Başlığı: ${pastSession.title}
Tarih: ${formattedDate}

Önceki Konuşma:
${conversationText}

Kullanıcının Şu Anki Sorusu: ${userQuery}

Yukarıdaki araştırma konuşmasından kullanıcının sorusunu cevaplayacak bilgiyi bul ve özetle. Hangi tarihte bu araştırmayı yaptığını da belirt. Doğrudan cevap ver, kullanıcının eski konuşmaya gitmesine gerek yok.`
}
```

### Handle Different Search Results

**Single Strong Match:**
```javascript
if (searchResults.length === 1 || searchResults[0].rank >> searchResults[1].rank) {
  const topMatch = searchResults[0]
  const prompt = buildRecallPrompt(userQuery, topMatch)
  const answer = await llm.generate(prompt)
  return answer
}
```

**Multiple Good Matches:**
```javascript
if (searchResults.length > 1 && similarRanks(searchResults)) {
  const sessionList = searchResults.map((s, i) =>
    `${i+1}) ${s.title} - ${formatDate(s.timestamp)}`
  ).join('\n')

  return `Bu konuda birkaç araştırman var:\n${sessionList}\n\nHangisinden bahsediyorsun?`

  // Wait for user clarification, then retrieve specific session
}
```

**No Good Match:**
```javascript
if (searchResults.length === 0 || searchResults[0].rank < RELEVANCE_THRESHOLD) {
  return `Bu konuda daha önce bir araştırma kaydı bulamadım. Şimdi araştırayım mı?`

  // If user confirms, proceed to normal research routing
}
```

---

## EDGE CASES

### Ambiguous Queries

**Query:** "Dawn phenomenon hakkında bilgi ver"
- Could be asking to recall past research OR requesting new research
- **Action:** Search past research first

```javascript
if (hasAmbiguousIntent(userQuery)) {
  const results = searchPastSessions(extractSearchTerms(userQuery))

  if (results.length > 0 && results[0].rank > GOOD_MATCH_THRESHOLD) {
    const topMatch = results[0]
    return `Bu konuyu ${formatDate(topMatch.timestamp)}'de araştırmıştın. İşte o zaman bulduklarımız:

${topMatch.summary}

Yeni araştırma yapmamı ister misin?`
  } else {
    // No good past match, do new research
    return routeToResearch(userQuery)
  }
}
```

### User Wants New Research Despite Past Results
**Phrases:** "yeni araştır", "tekrar araştır", "güncel bilgi", "fresh research"

```javascript
if (userWantsNewResearch(userQuery)) {
  // Bypass recall completely
  return routeToResearch(userQuery)
}
```

### Past Research Doesn't Fully Answer Current Query
```javascript
// After retrieving and showing past research
// LLM can detect if it's insufficient

if (pastResearchIncomplete) {
  return `${answerFromPastResearch}

Bu bilgi tam olarak sorunuzu cevaplamıyor gibi. Daha detaylı yeni bir araştırma yapmamı ister misin?`
}
```

---

## INTEGRATION WITH ROUTER

### Router Logic with Recall

```javascript
function router(userMessage, conversationHistory) {
  // STEP 1: Check for recall intent (FIRST PRIORITY)
  if (detectRecallIntent(userMessage)) {
    const searchTerms = extractSearchTerms(userMessage)
    const results = searchPastSessions(searchTerms)

    if (results.length > 0) {
      return {
        action: "recall",
        matchedSessions: results
      }
    } else {
      // No matches found, ask if they want new research
      return {
        action: "recall_not_found",
        message: "Bu konuda daha önce bir araştırma bulamadım. Şimdi araştırayım mı?"
      }
    }
  }

  // STEP 2: Check for topic change (end current session)
  if (conversationHistory.length > 0 && detectTopicChange(userMessage, conversationHistory)) {
    endCurrentSession()
    startNewSession()
  }

  // STEP 3: Route to research tiers
  if (needsResearch(userMessage)) {
    const complexity = assessComplexity(userMessage, conversationHistory)
    return {
      action: "research",
      tier: complexity  // Hızlı, Araştırma, or Derin Araştırma
    }
  }

  // STEP 4: General knowledge
  return {
    action: "answer",
    context: conversationHistory
  }
}
```

---

## PERFORMANCE OPTIMIZATION

### FTS5 Configuration
```sql
-- Create FTS5 with optimal settings for Turkish
CREATE VIRTUAL TABLE research_sessions_fts USING fts5(
  session_id UNINDEXED,
  title,
  key_topics,
  summary,
  tokenize='unicode61 remove_diacritics 0'
);

-- This preserves Turkish characters (ı, ş, ğ, ü, ö, ç)
```

### Search Performance
- FTS5 search should complete in <1 second
- Limit results to top 5
- Use prepared statements
- Consider caching frequent searches

### Token Usage Optimization
- Only retrieve full_conversation when needed
- For listing multiple matches, only show title + summary
- Only pass full conversation to LLM when user selects specific session

---

## TESTING CHECKLIST

- ☐ Save a research session and verify it's searchable
- ☐ Test recall with exact keywords from past research
- ☐ Test recall with synonyms or different wording
- ☐ Test Turkish past-tense detection ("neydi", "konuşmuştuk")
- ☐ Test ambiguous queries (should search first, then offer new research)
- ☐ Test "no matches found" scenario
- ☐ Test multiple matches scenario (user needs to clarify)
- ☐ Verify search performance (<1 second)
- ☐ Test Turkish character handling in FTS5 (ı, ş, ğ, etc.)
- ☐ Test that past research answers are accurate and relevant
- ☐ Test user saying "yeni araştır" to bypass recall
- ☐ Verify completed sessions are searchable but active ones are not

---

## EXAMPLE FLOWS

### Example 1: Clear Recall
**User:** "Dawn ile karışan etki neydi?"

→ Router detects: past tense "neydi", recall intent
→ Extract search terms: "Dawn", "etki"
→ Search FTS5
→ Find match: Session from Oct 5 titled "Dawn Phenomenon vs Somogyi Etkisi"
→ Retrieve full conversation
→ Build prompt with past conversation + current query
→ LLM generates answer

**Response:**
```
5 Ekim'de Dawn phenomenon ile Somogyi etkisini araştırmıştın.

Somogyi etkisi, gece yaşanan hipoglisemiye karşı vücudun aşırı glikoz üretmesiyle sabah yüksek şeker seviyelerine yol açar. Dawn phenomenon'dan temel farkı, Somogyi'de gece düşük şeker vardır ve vücut buna tepki olarak sabah yüksek şeker üretir. Dawn phenomenon'da ise gece hiposu olmadan, sabah hormonlarının doğal etkisiyle şeker yükselir.

O araştırmada kortizol ve büyüme hormonunun her iki durumda da rol oynadığını öğrenmiştik.
```

### Example 2: Ambiguous Query
**User:** "Dawn phenomenon nedir?"

→ Router: could be recall or new research
→ Search past sessions first
→ Find match from Oct 5

**Response:**
```
Bu konuyu 5 Ekim'de araştırmıştın. İşte o zaman öğrendiklerin:

Dawn phenomenon, sabah erken saatlerde (genellikle 4-8 arası) kan şekerinin doğal hormonların etkisiyle yükselmesidir. Kortizol, büyüme hormonu ve glukagon bu duruma neden olur. İnsülin ihtiyacı bu saatlerde artar.

Yeni araştırma yapmamı ister misin?
```

**User:** "Hayır yeter"
→ Conversation continues or ends

**OR**

**User:** "Evet yeni araştır"
→ Bypass recall, route to research tier

### Example 3: No Match
**User:** "Beta hücre rejenerasyonu hakkında ne konuşmuştuk?"

→ Router detects recall intent
→ Search returns no good matches

**Response:**
```
Beta hücre rejenerasyonu hakkında daha önce bir araştırma kaydı bulamadım. Şimdi araştırayım mı?
```

**User:** "Evet"
→ Route to research tier (probably Araştırma or Derin Araştırma based on complexity)

### Example 4: Multiple Matches
**User:** "İnsülin direnci araştırması"

→ Router detects potential recall
→ Search finds 3 sessions about insulin resistance from different times

**Response:**
```
İnsülin direnci hakkında birkaç araştırman var:

1) İnsülin Direnci ve Metformin Kullanımı - 15 Eylül 2024
2) İnsülin Direnci ve Egzersiz İlişkisi - 3 Ekim 2024
3) Tip 2 Diyabet ve İnsülin Direnci - 18 Ekim 2024

Hangisinden bahsediyorsun veya yeni araştırma mı yapmamı istersin?
```

**User:** "İkinci"
→ Retrieve Oct 3 session
→ Answer using that conversation

---

## KEY PRINCIPLES

1. **Recall is first priority**: Check for recall intent before routing to research
2. **Search before asking**: Always search past sessions for ambiguous queries
3. **Direct answers**: Don't make user navigate to old sessions, answer directly
4. **Turkish language support**: Proper handling of Turkish grammar and characters
5. **Graceful degradation**: If no match, offer new research instead
6. **Clear session boundaries**: Only completed sessions are searchable
7. **Performance matters**: Search must be fast (<1 second)
8. **Context preservation**: Past research + current query = complete answer

This system makes past research easily accessible through natural language queries in Turkish, without requiring the user to manually browse or remember exact session titles.
