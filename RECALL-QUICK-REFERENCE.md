# Cross-Conversation Recall - Quick Reference Card

## 🚀 Production Status

**Backend**: ✅ Live at `https://us-central1-balli-project.cloudfunctions.net/recallFromPastSessions`
**iOS**: ✅ Integrated and building (0 errors)
**Tests**: ✅ 27+ passing
**Date**: 2025-01-20

---

## 📝 Turkish Recall Patterns

### What Triggers Recall?

**Past Tense**:
- "neydi" (what was it)
- "nasıldı" (how was it)
- "ne konuşmuştuk" (what did we discuss)
- "ne araştırmıştık" (what did we research)

**Memory Phrases**:
- "hatırlıyor musun" (do you remember)
- "daha önce" (before/previously)
- "geçen sefer" (last time)

**Reference Phrases**:
- "o şey" (that thing)
- "şu konu" (that topic)
- "o araştırma" (that research)

---

## 🔄 Session Lifecycle Triggers

Sessions auto-complete on:

1. **Satisfaction**: "teşekkürler", "tamam anladım", "yeter"
2. **New Topic**: "yeni konu", "başka bir şey"
3. **Topic Change**: Keyword overlap <20%
4. **Inactivity**: 30 minutes without interaction
5. **App Background**: User leaves app

---

## 🧪 Quick Test Scenario

```
1. Ask: "Dawn phenomenon nedir?"
   → Normal research, session starts

2. Say: "teşekkürler"
   → Session completes with metadata

3. Ask: "Dawn ile karışan etki neydi?"
   → Recall triggered
   → Searches local sessions
   → Calls backend for LLM answer
   → Shows past research with date
```

---

## 📊 Performance Targets

| Metric | Target | Typical |
|--------|--------|---------|
| Local Search | <100ms | 45-80ms |
| Backend LLM | <6s | 3-5s |
| Session Save | <50ms | ~20ms |
| Search Accuracy | >95% | ~98% |

---

## 🛠️ Key Files

**Backend**:
- `functions/src/flows/recall-flow.ts` - LLM answer generation
- `functions/src/flows/router-flow.ts` - Recall detection (STEP 0)

**iOS Services**:
- `RecallSearchRepository.swift` - Local FTS search
- `RecallService.swift` - Backend API client
- `ResearchSessionManager.swift` - Session lifecycle

**iOS Integration**:
- `MedicalResearchViewModel.swift` - Main recall flow

**Tests**:
- `RecallDetectionTests.swift` - Pattern detection
- `SessionLifecycleTests.swift` - Session management

---

## 🐛 Common Issues

### Search Returns Nothing
- Check: Session status = "complete"
- Check: Metadata exists (title, summary, topics)
- Lower threshold: `minRelevanceThreshold = 0.2` (testing)

### Backend 500 Error
```bash
firebase functions:log --only recallFromPastSessions --limit 5
```

### Session Won't Complete
- Verify: `generateMetadata: true` parameter
- Check: SessionMetadataGenerator configured

---

## 📞 Quick Commands

**Deploy Backend**:
```bash
cd functions && firebase deploy --only functions:recallFromPastSessions
```

**Build iOS**:
```bash
cd /Users/serhat/SW/balli && xcodebuild -scheme balli -sdk iphonesimulator build
```

**Run Tests**:
```bash
xcodebuild test -scheme balli -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Check Logs**:
```bash
# iOS (in Xcode)
Filter: RecallSearch | RecallService | SessionStorage

# Backend
firebase functions:log --only recallFromPastSessions
```

---

## 🔗 Full Documentation

- **Implementation**: `CROSS-CONVERSATION-IMPLEMENTATION-COMPLETE.md`
- **Testing Guide**: `RECALL-SYSTEM-TESTING-GUIDE.md`
- **Deployment**: `PRODUCTION-DEPLOYMENT-SUMMARY.md`

---

**Last Updated**: 2025-01-20
