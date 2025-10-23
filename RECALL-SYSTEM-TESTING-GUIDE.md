# Cross-Conversation Recall System - End-to-End Testing Guide

## Overview
This guide provides step-by-step instructions for testing the complete cross-conversation memory system from iOS client through to backend LLM answer generation.

**System Status**: ✅ Fully Deployed to Production
**Deployment Date**: 2025-01-20

---

## Production Endpoints

### Backend Cloud Function
**URL**: `https://us-central1-balli-project.cloudfunctions.net/recallFromPastSessions`
**Method**: POST
**Memory**: 512MB
**Timeout**: 60 seconds
**Runtime**: Node.js 20

### iOS Configuration
**Base URL**: Configured in `NetworkConfiguration.swift`
**Default**: `https://us-central1-balli-project.cloudfunctions.net`
**Override**: Can be changed via UserDefaults key `balli.customBaseURL`

---

## Test Scenarios

### Scenario 1: Complete Recall Flow (Happy Path)

**Prerequisites**:
- Fresh install or cleared SwiftData storage
- User logged in with valid Firebase Auth

**Steps**:

1. **Create a Research Session**
   ```
   User Query: "Dawn phenomenon nedir?"
   Expected:
   - Router detects Tier 2 (HYBRID_RESEARCH)
   - Performs PubMed + Exa search
   - Streams answer with sources
   - Session auto-starts
   - Message saved to SwiftData
   ```

2. **Continue the Conversation**
   ```
   User Query: "Somogyi etkisi ile farkı nedir?"
   Expected:
   - Same session continues
   - Inactivity timer resets
   - Second message added to session
   ```

3. **End the Session**
   ```
   User Query: "teşekkürler yeter"
   Expected:
   - shouldEndSession() detects satisfaction signal
   - Session marked as complete
   - Metadata generated (title, summary, topics)
   - Session saved to SwiftData with status=complete
   ```

4. **Attempt Recall**
   ```
   User Query: "Dawn ile karışan etki neydi?"
   Expected Flow:
   a. shouldAttemptRecall() detects "neydi" past-tense pattern
   b. handleRecallRequest() called
   c. RecallSearchRepository searches completed sessions
   d. Finds single strong match (relevance > 0.3)
   e. loadSessionConversation() extracts full conversation
   f. RecallService calls backend with:
      - question: "Dawn ile karışan etki neydi?"
      - userId: current user ID
      - matchedSessions: [session with full conversation history]
   g. Backend generates answer using Gemini Flash
   h. iOS displays:
      📚 Geçmiş Araştırma ([date])
      [LLM-generated answer referencing past conversation]
      *Kaynak: [session title]*
   ```

**Verification**:
- Check Xcode console for log sequence:
  ```
  📚 [RecallSearch] Recall request detected
  📚 [RecallSearch] Found 1 matching session(s)
  📚 [RecallService] Generating recall answer
  📥 [RecallService] Received response with status: 200
  ✅ [RecallService] Recall answer generated successfully
  ```

---

### Scenario 2: Multiple Matches Disambiguation

**Steps**:

1. Create two similar sessions:
   ```
   Session 1: "Dawn phenomenon nedir?"
   Session 2: "Dawn phenomenon tedavisi"
   ```

2. End both sessions with "tamam yeter"

3. Recall query:
   ```
   User Query: "Dawn phenomenon neydi?"
   Expected:
   - Finds 2 sessions with close relevance scores (difference < 0.15)
   - Displays list of sessions:
     "📚 Birden Fazla Araştırma Bulundu:
     1. [Session 1 title] - [date]
     2. [Session 2 title] - [date]
     Hangisini kastettiniz?"
   ```

**Verification**:
- Check that both sessions appear
- Verify dates are formatted in Turkish
- User can select one to get full answer

---

### Scenario 3: No Matches (Graceful Degradation)

**Steps**:

1. Recall query about never-researched topic:
   ```
   User Query: "keto diyeti neydi?"
   Expected (if keto diet never researched):
   - RecallSearchRepository returns empty array
   - handleNoRecallMatches() called
   - Displays:
     "Bu konuda daha önce bir araştırma kaydı bulamadım.
     Şimdi araştırayım mı?"
   ```

**Verification**:
- No crash or error
- Offers to perform new research
- If user says "evet", triggers normal research flow

---

### Scenario 4: Topic Change Detection

**Steps**:

1. Start session about insulin:
   ```
   User Query: "insülin direnci nedir?"
   Expected: Session starts
   ```

2. Ask completely different topic:
   ```
   User Query: "metformin dozajı nedir?"
   Expected:
   - detectTopicChange() returns true (keyword overlap < 20%)
   - Previous session auto-completes
   - New session starts for metformin
   ```

**Verification**:
- Check SwiftData shows 2 separate completed sessions
- First session has insulin-related keywords
- Second session starts fresh

---

### Scenario 5: Inactivity Timeout

**Steps**:

1. Start session:
   ```
   User Query: "A1C nedir?"
   Expected: Session starts, inactivity timer starts (30 min)
   ```

2. Wait 30+ minutes (or modify timeout constant for testing)

3. Expected:
   - resetInactivityTimer() Task expires
   - Session auto-completes with metadata
   - Logged: "⏰ Session ended due to inactivity timeout"

**Testing Shortcut**:
Temporarily modify `ResearchSessionManager.swift`:
```swift
private let inactivityTimeout: TimeInterval = 60 // 1 minute for testing
```

---

### Scenario 6: App Backgrounding

**Steps**:

1. Start session:
   ```
   User Query: "karbonhidrat sayımı nasıl yapılır?"
   Expected: Session active
   ```

2. Background the app:
   - Swipe up to home screen (iOS)
   - Or press home button

3. Expected Flow:
   ```
   scenePhase changes to .background
   → balliApp.swift detects phase change
   → AppLifecycleCoordinator.handleBackgroundTransition()
   → completeActiveResearchSession()
   → NotificationCenter posts "CompleteActiveResearchSession"
   → MedicalResearchViewModel receives notification
   → endCurrentSession() called
   → Session marked complete with metadata
   ```

**Verification**:
- Check Xcode console:
  ```
  🧠 [AppLifecycle] Completing active research session due to app backgrounding
  🧠 [SessionManager] Session ended due to app backgrounding
  ```
- Reopen app, verify session is complete in SwiftData

---

## API Testing with curl

### Test Backend Recall Endpoint Directly

```bash
curl -X POST \
  https://us-central1-balli-project.cloudfunctions.net/recallFromPastSessions \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Dawn phenomenon ile Somogyi etkisi arasındaki fark neydi?",
    "userId": "test-user-123",
    "matchedSessions": [
      {
        "sessionId": "test-session-uuid",
        "title": "Dawn Phenomenon vs Somogyi Etkisi",
        "summary": "Dawn phenomenon sabah erken saatlerde şekerin yükselmesi, Somogyi etkisi ise gece hipoglisemisine rebound yanıt",
        "keyTopics": ["Dawn phenomenon", "Somogyi etkisi", "sabah hiperglisemi"],
        "createdAt": "2025-01-15T10:30:00Z",
        "conversationHistory": [
          {
            "role": "user",
            "content": "Dawn phenomenon nedir?"
          },
          {
            "role": "model",
            "content": "Dawn phenomenon sabah erken saatlerde (genellikle 2-8 arası) şeker seviyesinin yükselmesidir..."
          },
          {
            "role": "user",
            "content": "Somogyi etkisi ile farkı nedir?"
          },
          {
            "role": "model",
            "content": "Somogyi etkisi gece hipoglisemisine yanıt olarak sabah hiperglisemi görülmesidir..."
          }
        ],
        "relevanceScore": 0.85
      }
    ]
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "answer": "15 Ocak'ta Dawn phenomenon ile Somogyi etkisi arasındaki farkı araştırmıştın. Dawn phenomenon sabah erken saatlerde şeker seviyesinin doğal olarak yükselmesidir. Somogyi etkisi ise gece hipoglisemisine rebound yanıt olarak sabah hiperglisemi görülmesidir. Temel fark: Dawn phenomenon hormonal, Somogyi etkisi reaktiftir.",
  "sessionReference": {
    "sessionId": "test-session-uuid",
    "title": "Dawn Phenomenon vs Somogyi Etkisi",
    "date": "15 Ocak 2025"
  }
}
```

---

## Performance Benchmarks

### Expected Performance Metrics:

**Local Search** (RecallSearchRepository):
- Search time: < 100ms for 100 completed sessions
- Search time: < 250ms for 1000 completed sessions
- Memory: ~2KB per session metadata

**Backend API Call** (RecallService):
- Network latency: 200-500ms (typical)
- LLM generation: 2-5 seconds (Gemini Flash)
- Total time: < 6 seconds from iOS tap to answer display

**Session Completion**:
- Without metadata: < 50ms
- With metadata generation: 2-4 seconds (LLM call)
- SwiftData save: < 50ms

---

## Common Issues and Solutions

### Issue 1: "Session not found" Error

**Symptoms**: RecallService throws `noConversationHistory`

**Diagnosis**:
```bash
# Check SwiftData sessions in Xcode debugger
po ResearchSessionModelContainer.shared.container
# Verify status = "complete"
# Verify metadata (title, summary, topics) exists
```

**Fix**:
- Ensure sessions are ended with `generateMetadata: true`
- Verify SessionMetadataGenerator is configured
- Check that session isn't still active

### Issue 2: Search Returns No Results

**Symptoms**: RecallSearchRepository returns empty array

**Diagnosis**:
- Check relevance threshold (default: 0.3)
- Verify search terms aren't empty after cleaning
- Check Turkish character handling

**Debug**:
```swift
// Add breakpoint in RecallSearchRepository.searchSessions()
let searchTerms = prepareSearchTerms(query)
print("Search terms: \(searchTerms)")  // Should not be empty

let sessions = try modelContext.fetch(fetchDescriptor)
print("Total completed sessions: \(sessions.count)")  // Should be > 0
```

**Fix**:
- Lower `minRelevanceThreshold` temporarily for testing
- Verify sessions have metadata populated
- Check that search isn't stripping all keywords

### Issue 3: Backend Returns 500 Error

**Symptoms**: RecallService throws `httpError(statusCode: 500)`

**Diagnosis**:
```bash
# Check Firebase Functions logs
firebase functions:log --only recallFromPastSessions --limit 10
```

**Common Causes**:
- Malformed request JSON
- Missing conversationHistory
- Genkit model initialization failure

**Fix**:
- Verify request body matches RecallRequest structure
- Ensure conversationHistory is not empty
- Check Gemini API quota/credentials

### Issue 4: Inactivity Timer Not Firing

**Symptoms**: Session doesn't complete after 30 minutes

**Diagnosis**:
```swift
// Add logging in ResearchSessionManager
func resetInactivityTimer() {
    logger.debug("Inactivity timer reset - will fire in \(inactivityTimeout)s")
    // ...
}
```

**Common Causes**:
- Timer cancelled prematurely
- Timer Task not persisting across user interactions
- Wrong timeout constant

**Fix**:
- Verify `resetInactivityTimer()` called on EVERY user message
- Check that timer isn't cancelled except on session end
- Confirm timeout constant (1800 seconds = 30 minutes)

### Issue 5: App Backgrounding Doesn't Complete Session

**Symptoms**: Session still active after backgrounding

**Diagnosis**:
```swift
// Check notification flow
// In AppLifecycleCoordinator:
logger.info("🧠 Posted session completion notification")

// In MedicalResearchViewModel init:
NotificationCenter.default.addObserver(...) { _ in
    logger.info("🧠 Received session completion notification")
    // ...
}
```

**Common Causes**:
- NotificationCenter observer not set up
- Notification posted to wrong thread
- Observer deallocated before notification

**Fix**:
- Verify observer setup in `init()`
- Ensure notification uses `.main` queue
- Check that ViewModel isn't deallocated on background

---

## Debugging Tools

### Enable Verbose Logging

In `Info.plist`:
```xml
<key>OSLogEnabled</key>
<true/>
<key>OSLogLevel</key>
<string>debug</string>
```

### Key Log Categories to Monitor:

1. **RecallSearch**:
   ```
   📚 [RecallSearch] Recall request detected
   📚 [RecallSearch] Found N matching session(s)
   ```

2. **RecallService**:
   ```
   📚 [RecallService] Generating recall answer
   📤 [RecallService] Sending recall request
   📥 [RecallService] Received response with status: 200
   ✅ [RecallService] Recall answer generated successfully
   ```

3. **SessionStorage**:
   ```
   [SessionStorage] Loaded N messages from session
   [SessionStorage] Session saved successfully
   ```

4. **SessionManager**:
   ```
   🧠 [SessionManager] Session ended due to [reason]
   ⏰ [SessionManager] Session ended due to inactivity timeout
   ```

5. **AppLifecycle**:
   ```
   🧠 [AppLifecycle] Completing active research session
   🧠 [AppLifecycle] Posted session completion notification
   ```

---

## Success Criteria

A successful end-to-end test should achieve:

✅ **Functional Requirements**:
- Turkish recall patterns detected with 100% accuracy
- Local search completes in < 100ms
- Backend generates contextual answers from past conversations
- Sessions auto-complete on all 5 triggers
- No crashes or data loss

✅ **Performance Requirements**:
- App launch: < 2 seconds
- Search response: < 100ms
- Backend recall: < 6 seconds total
- No memory leaks (verify with Instruments)

✅ **Code Quality**:
- iOS app builds with 0 errors
- Backend builds with 0 errors/warnings
- All tests pass (25+ test cases)
- Swift 6 strict concurrency compliant

✅ **User Experience**:
- No manual navigation required
- Clear session references with dates
- Graceful degradation on no matches
- Turkish date/language formatting

---

## Production Monitoring

### Key Metrics to Track:

1. **Recall Request Success Rate**:
   - Target: > 95%
   - Monitor: Backend logs, error rates

2. **Average Response Time**:
   - Target: < 6 seconds end-to-end
   - Monitor: Firebase performance monitoring

3. **Session Completion Rate**:
   - Target: 100% of sessions eventually complete
   - Monitor: SwiftData analytics, active vs complete ratio

4. **Search Relevance Quality**:
   - Target: Users find expected sessions > 80% of time
   - Monitor: User feedback, retry rates

---

## Next Steps After Testing

Once testing is complete:

1. **Production Release**:
   - Archive for TestFlight/App Store
   - Update version notes with recall feature
   - Monitor crash reports for first week

2. **User Education**:
   - Add onboarding tooltip for recall feature
   - Document Turkish recall patterns in help section
   - Provide example queries

3. **Optimization**:
   - Monitor query patterns
   - Tune relevance scoring based on user behavior
   - Consider SQLite FTS5 if session count > 1000

4. **Future Enhancements**:
   - Session browsing UI
   - Cross-device sync via Firestore
   - Proactive recall hints

---

**Last Updated**: 2025-01-20
**Tested By**: [Your Name]
**Status**: ✅ Ready for Production Testing
