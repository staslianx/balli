# Research View Analysis - Complete Documentation

This folder contains three comprehensive documents analyzing the Research/Medical Research feature in the Balli app:

## Documents Overview

### 1. **RESEARCH_FLOW_ANALYSIS.md** (Main Reference)
**Purpose:** Complete technical walkthrough of how AI responses flow from backend to screen

**Contents:**
- Executive summary
- 9-phase execution flow breakdown:
  1. User initiates search
  2. Stream connection & network layer
  3. SSE event parsing
  4. Stream parsing & buffering
  5. Callback chain & state updates
  6. SwiftUI state & rendering
  7. Text animation & display
  8. Markdown rendering & display
  9. Sources & citations
- Complete data flow visualization with ASCII diagrams
- Key design patterns (real-time tokens, deferred completion, multi-layer animation, etc.)
- Error handling & edge cases
- Performance characteristics
- Files summary table

**Best For:** Understanding the complete end-to-end architecture and data flow

### 2. **RESEARCH_ARCHITECTURE_DIAGRAM.md** (Visual Reference)
**Purpose:** Visual diagrams and flowcharts of the research system

**Contents:**
- High-level component architecture diagram
- Token flow through system with transitions
- Deep Research V2 (multi-round) event sequence timeline
- State coordination at various stages
- Thread safety & concurrency model
- Error handling flows for 4 key scenarios

**Best For:** Quick visual reference, understanding architecture at a glance

### 3. **This File (RESEARCH_ANALYSIS_README.md)**
**Purpose:** Index and quick reference guide

---

## Key Concepts at a Glance

### Architecture Layers
```
User Interface (SwiftUI Views)
     ↑
State Management (@MainActor ViewModel)
     ↑
Event Processing (@MainActor EventHandler)
     ↑
SSE Parsing & Streaming (Background async)
     ↑
Network (Firebase Cloud Function SSE)
```

### Critical Files

**UI Rendering:**
- `InformationRetrievalView.swift` - Main search screen
- `AnswerCardView.swift` - Individual answer container
- `TypewriterAnswerView.swift` - Animation controller
- `StreamingAnswerView.swift` - Content display
- `MarkdownText.swift` - Final markdown renderer

**State & Events:**
- `MedicalResearchViewModel.swift` - Main state holder (@MainActor)
- `ResearchEventHandler.swift` - Event processor
- `ResearchAnswerStateManager.swift` - Answer array management
- `ResearchStreamCallbacksBuilder.swift` - Callback factory

**Streaming & Parsing:**
- `ResearchStreamingAPIClient.swift` - Network client
- `ResearchStreamParser.swift` - Stream state (Actor)
- `ServerSentEventParser.swift` - SSE event decoder
- `ResearchNetworkService.swift` - HTTP request builder

**Animation:**
- `TypewriterAnimator.swift` - Character-by-character animation (Actor)

### Data Flow Summary

```
Token Arrives (Background)
     ↓
SSE Event Parsed → ResearchSSEEvent enum
     ↓
handleEvent() callback invoked
     ↓
Task { @MainActor in }  ← Cross thread boundary
     ↓
handleToken() appends to answer.content
     ↓
@Published property changes → SwiftUI detects
     ↓
TypewriterAnswerView.task(id:) fires
     ↓
TypewriterAnimator enqueues characters
     ↓
Characters delivered with delays (8ms base)
     ↓
displayedContent updated → rerender
     ↓
MarkdownText renders → text appears on screen
```

---

## Feature Capabilities

### Tier Support
- **T1 (MODEL):** Fast direct LLM response
- **T2 (HYBRID_RESEARCH):** Quick web search + synthesis
- **T3 (DEEP_RESEARCH):** Multi-round research with planning, reflection, optimization

### Streaming Events (20+ types)
**Token Events:**
- `.token(content)` - Individual token
- `.flushTokens` - All tokens sent
- `.complete(...)` - Final response

**Research Events (T3 only):**
- Planning: started → complete
- Rounds: started → complete (per round)
- Reflection: started → complete (per round)
- Source Selection → Synthesis Preparation → Synthesis Started

**Progress Events:**
- `.searching(source)` - Started source search
- `.searchComplete(count, source)` - Finished searching
- `.sourcesReady(sources)` - Sources available

### Deep Research V2 Timeline
Typical 1-round research takes 40-60 seconds:
- 0-2s: Planning
- 2-15s: Research round 1 (multiple API calls)
- 15-20s: Reflection & decision making
- 20-24s: Source selection & synthesis prep
- 24-60s: Synthesis (token streaming)

---

## Performance Characteristics

### Latency
- Token appearance: 50-150ms from backend creation
- First visible character: ~100ms after first token
- Full answer: 30-90s depending on tier

### Memory
- Per active stream: ~2-3MB
- Tokenized buffers: ~100KB (animation)
- Stream state: ~10KB

### Network
- Chunk batching: 256 bytes or event boundary
- Total timeout: 360 seconds
- Idle detection: 120 seconds
- Connection retries: 3 attempts with exponential backoff

---

## Testing & Debugging

### Key Breakpoints
1. **Token Reception:** Mock SSE token event
2. **Content Update:** Verify answer.content mutation
3. **Animation Start:** Check TypewriterAnimator queue
4. **Display Update:** See displayedContent change
5. **Completion:** Mock complete event
6. **Error Recovery:** Simulate network failure

### Debugging Logs
Enable verbose logging to see:
- Stream lifecycle: connections, bytes, events
- Token flow: reception, buffering, emission
- Animation state: queuing, delivery, completion
- State mutations: before/after values
- Thread crossings: background ↔ main transitions

---

## Common Issues & Solutions

### Issue: Text appears delayed after first token
**Root Cause:** TypewriterAnimator queue stalled
**Solution:** Check animator.enqueueText() being called, verify deliver callback firing

### Issue: Animation continues after stream complete
**Root Cause:** Stale animation task not cancelled
**Solution:** Ensure onChange(of: answerId) cancels old tasks

### Issue: Sources not appearing
**Root Cause:** sourcesReady event not processed or merged incorrectly
**Solution:** Verify event callback invoked, check URL deduplication logic

### Issue: Memory leak during streaming
**Root Cause:** Retained references in callbacks
**Solution:** Use [weak self] in all Task { @MainActor } closures

---

## Extension Points

### Adding New Event Types
1. Add case to `ResearchSSEEvent` enum in `ServerSentEventParser.swift`
2. Add parsing logic in `ResearchSSEParser.parseEvent()`
3. Add handler callback in `ResearchStreamCallbacksBuilder.buildCallbacks()`
4. Add handler method in `ResearchEventHandler`
5. Wire up in `MedicalResearchViewModel.handleXxx()`

### Customizing Animation
Edit `TypewriterAnimator`:
- `baseDelay` (8ms) - regular character delay
- `spaceDelay` (5ms) - space character delay
- `punctuationDelay` (50ms) - pause after punctuation

### Modifying Sources Display
Edit `AnswerCardView` and `SourcePillsView` to change:
- Source count display
- Source order/filtering
- Visual styling
- Interaction behavior

---

## Related Systems

### Session Management
- `ResearchSessionManager` - Maintains conversation history
- `ResearchPersistenceManager` - Saves/loads sessions
- `ResearchSessionCoordinator` - Lifecycle management

### Stage Coordination (Deep Research V2)
- `ResearchStageCoordinator` - Research progress UI
- `ResearchStageDisplayManager` - Stage message formatting
- `ResearchProgressCalculator` - Progress tracking

### Network Resilience
- `ResearchConnectionRetrier` - Automatic retry logic
- `ResearchStreamCallbacksBuilder` - Callback marshalling
- Error recovery with exponential backoff

---

## File Statistics

**Total Research Feature Files:** ~40 files
**Lines of Code (approx):** 15,000+ LOC
**Main Components:** 6 major coordinators/managers
**SSE Events:** 20+ event types

---

## Revision History

**Last Updated:** 2025-11-12
**Created:** Analysis of complete research view feature
**Scope:** From user search to text rendering on screen

---

## Quick Links to Documents

- [RESEARCH_FLOW_ANALYSIS.md](./RESEARCH_FLOW_ANALYSIS.md) - Detailed phase-by-phase breakdown
- [RESEARCH_ARCHITECTURE_DIAGRAM.md](./RESEARCH_ARCHITECTURE_DIAGRAM.md) - Visual diagrams and flowcharts

