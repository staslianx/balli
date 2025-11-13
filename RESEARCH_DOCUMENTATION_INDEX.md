# Research View Documentation Index

**Created:** November 12, 2025
**Total Documentation:** 2,087 lines across 3 files
**Scope:** Complete flow from user search to text display

---

## Quick Start Guide

### I need to understand the architecture
**→ Start with:** `RESEARCH_ANALYSIS_README.md`
- 5-minute overview of the system
- Key concepts and layers
- Critical files list
- Quick reference

### I need to understand how tokens become text
**→ Read:** `RESEARCH_FLOW_ANALYSIS.md` - Phases 1-9
- Token arrival and SSE parsing
- State updates and rendering
- Animation and display
- Complete data flow with code examples

### I need to see the architecture visually
**→ Look at:** `RESEARCH_ARCHITECTURE_DIAGRAM.md`
- Component architecture diagram
- Token flow visualization
- Multi-round research timeline
- Thread safety diagram
- Error handling flowcharts

### I need to debug a specific issue
**→ Check:** `RESEARCH_ANALYSIS_README.md` - Common Issues section
- Text appears delayed
- Animation continues after completion
- Sources not appearing
- Memory leaks

### I need to add a new feature
**→ Reference:** `RESEARCH_ANALYSIS_README.md` - Extension Points section
- Adding new event types (5 steps)
- Customizing animation delays
- Modifying sources display

---

## File Structure & Locations

```
/Users/serhat/SW/balli/
├── RESEARCH_ANALYSIS_README.md          ← START HERE (273 lines)
│   ├── Architecture layers diagram
│   ├── Critical files list (13 files)
│   ├── Data flow summary
│   ├── Feature capabilities
│   ├── Performance characteristics
│   ├── Testing & debugging guide
│   ├── Common issues & solutions (4 issues)
│   └── Extension points (3 areas)
│
├── RESEARCH_FLOW_ANALYSIS.md            ← DETAILED REFERENCE (1,132 lines)
│   ├── Executive summary
│   ├── Phase 1: User initiates search
│   ├── Phase 2: Stream connection & network layer
│   ├── Phase 3: SSE event parsing
│   ├── Phase 4: Stream parsing & buffering
│   ├── Phase 5: Callback chain & state updates
│   ├── Phase 6: SwiftUI state & rendering
│   ├── Phase 7: Text animation & display
│   ├── Phase 8: Markdown rendering & display
│   ├── Phase 9: Sources & citations
│   ├── Complete data flow visualization
│   ├── Key design patterns (5 patterns)
│   ├── Error handling & edge cases (3 scenarios)
│   ├── Performance characteristics (latency, memory, network)
│   ├── Files summary table (40+ files)
│   └── Testing entry points (9 points)
│
└── RESEARCH_ARCHITECTURE_DIAGRAM.md     ← VISUAL REFERENCE (682 lines)
    ├── High-level component architecture
    ├── Token flow through system
    ├── Deep Research V2 event sequence (timeline)
    ├── State coordination at each stage
    ├── Thread safety & concurrency model
    ├── Error handling flows (4 scenarios)
    └── Critical flow examples
```

---

## Documentation Content Map

### By Topic

**Network & Streaming:**
- `FLOW_ANALYSIS.md` - Phase 2: Stream connection & network layer
- `FLOW_ANALYSIS.md` - Phase 3: SSE event parsing
- `ARCHITECTURE_DIAGRAM.md` - Token flow through system
- `README.md` - Network characteristics

**State Management:**
- `FLOW_ANALYSIS.md` - Phase 6: SwiftUI state & rendering
- `ARCHITECTURE_DIAGRAM.md` - State coordination diagram
- `README.md` - Critical files (state & events)

**Animation:**
- `FLOW_ANALYSIS.md` - Phase 7: Text animation & display
- `ARCHITECTURE_DIAGRAM.md` - High-level component architecture
- `README.md` - Customizing animation (extension point)

**Error Handling:**
- `FLOW_ANALYSIS.md` - Error handling & edge cases
- `ARCHITECTURE_DIAGRAM.md` - Error handling flows
- `README.md` - Common issues & solutions

**Deep Research V2:**
- `ARCHITECTURE_DIAGRAM.md` - Multi-round event sequence timeline
- `FLOW_ANALYSIS.md` - Phase 4: Stream parsing & buffering
- `README.md` - Feature capabilities (tier support)

---

## Quick Reference Sections

### Critical Files by Function

**UI Rendering (InformationRetrievalView.swift):**
- Entry point for all search interactions
- Tracks global animation state
- Manages scroll and keyboard

**State Holder (MedicalResearchViewModel.swift):**
- @Published @answers array
- @Published searchState
- All handler methods (@MainActor)

**Animator (TypewriterAnimator.swift):**
- Character queues per answer
- Adaptive delays (8ms base, 50ms punctuation)
- Actor for thread-safe access

**Parser (ResearchStreamParser.swift):**
- Token accumulation
- Event deduplication
- Deferred completion handling
- Timeout synthesis

**Network Client (ResearchStreamingAPIClient.swift):**
- URL session creation
- Byte-by-byte streaming loop
- UTF-8 safe chunking
- Event emission

---

## Performance at a Glance

| Metric | Value |
|--------|-------|
| Token latency | 50-150ms |
| First visible char | ~100ms after token |
| Full answer | 30-90s depending on tier |
| Per-stream memory | 2-3MB |
| Animation buffers | 100KB |
| Stream timeout | 360 seconds |
| Idle detection | 120 seconds |
| Retry attempts | 3 with backoff |

---

## Design Patterns Implemented

1. **Real-Time Token Streaming**
   - Immediate token append to content
   - SwiftUI observation triggers animation
   - No buffering or delays

2. **Deferred Completion**
   - Complete event stored but not fired
   - Continues reading until stream closes
   - Prevents premature termination

3. **Multi-Layer Animation**
   - Backend state + typewriter state = effective state
   - UI blocks until both complete

4. **Per-Answer Cancellation**
   - UUID token per search
   - Stale events filtered

5. **Conversation Context**
   - Sessions maintain history
   - Context-aware responses

---

## Testing Checklist

- [ ] Mock token event received
- [ ] Verify answer.content updated
- [ ] Check animation starts
- [ ] See displayedContent change
- [ ] Mock complete event
- [ ] Verify searchState = idle
- [ ] Test network timeout
- [ ] Test idle timeout (120s)
- [ ] Test retry logic
- [ ] Verify memory cleanup

---

## Extension Guide

### To Add New Event Type:
1. Add case to `ResearchSSEEvent` enum
2. Add JSON parsing in `ResearchSSEParser`
3. Create callback in `ResearchStreamCallbacksBuilder`
4. Add handler method in `ResearchEventHandler`
5. Wire up in `MedicalResearchViewModel`

See: `RESEARCH_ANALYSIS_README.md` - Extension Points

### To Customize Delays:
- `baseDelay: UInt64 = 8` (regular char)
- `spaceDelay: UInt64 = 5` (spaces)
- `punctuationDelay: UInt64 = 50` (after `.!?:;`)

File: `TypewriterAnimator.swift`

### To Modify Display:
- Edit `AnswerCardView.swift` for layout
- Edit `MarkdownText.swift` for styling
- Edit `SourcePillsView.swift` for sources

---

## Problem-Solving Guide

**Symptom:** Text appears delayed after first token
- **Root:** TypewriterAnimator queue stalled
- **Fix:** Check `enqueueText()` called, verify `deliver` callback

**Symptom:** Animation continues after stream complete
- **Root:** Stale animation task not cancelled
- **Fix:** Ensure `onChange(of: answerId)` cancels old tasks

**Symptom:** Sources not appearing
- **Root:** Event not processed or merged incorrectly
- **Fix:** Verify callback invoked, check deduplication

**Symptom:** Memory leak during streaming
- **Root:** Retained references in callbacks
- **Fix:** Use `[weak self]` in `Task { @MainActor }`

More details: `RESEARCH_ANALYSIS_README.md` - Common Issues & Solutions

---

## Architecture Layers (Bottom to Top)

```
Layer 9: UI Rendering (SwiftUI Views)
         └─ Text appears on screen

Layer 8: Animation (@State Actor)
         └─ Character-by-character delays

Layer 7: State Management (@MainActor ViewModel)
         └─ Observable property updates

Layer 6: Event Processing (@MainActor)
         └─ Handle typed events

Layer 5: Callback Marshalling (Background → Main)
         └─ Sendable callbacks

Layer 4: Stream State (Actor)
         └─ Accumulate tokens/sources

Layer 3: SSE Parsing (Background)
         └─ JSON → ResearchSSEEvent

Layer 2: Stream Management (Background)
         └─ Byte-by-byte reading

Layer 1: Network (Firebase Cloud Function)
         └─ HTTP/2 SSE protocol
```

---

## Key Statistics

| Item | Count |
|------|-------|
| Total research files | ~40 |
| Lines of code | 15,000+ |
| Major components | 6 |
| SSE event types | 20+ |
| Supported tiers | 3 (T1, T2, T3) |
| Documentation lines | 2,087 |
| Documentation files | 3 |
| Code examples | 50+ |
| Diagrams | 10+ |

---

## Related Documentation

- `CLAUDE.md` - Project standards and conventions
- `PERFORMANCE_AUDIT_*.md` - Performance analysis
- `nutri-bug.md` - Known issues and workarounds

---

## How to Use This Documentation

### Scenario 1: Onboarding New Team Member
1. Read: `RESEARCH_ANALYSIS_README.md` (15 min)
2. Study: `RESEARCH_FLOW_ANALYSIS.md` Phases 1-3 (30 min)
3. Review: `RESEARCH_ARCHITECTURE_DIAGRAM.md` (15 min)
4. Start coding with file references

### Scenario 2: Debugging an Issue
1. Check: `RESEARCH_ANALYSIS_README.md` - Common Issues
2. If not found, read: Relevant phase in `RESEARCH_FLOW_ANALYSIS.md`
3. Verify: Architecture in `RESEARCH_ARCHITECTURE_DIAGRAM.md`
4. Add breakpoints and trace execution

### Scenario 3: Adding a Feature
1. Identify affected layers (use `ARCHITECTURE_DIAGRAM.md`)
2. Check: `RESEARCH_ANALYSIS_README.md` - Extension Points
3. Study: Related phases in `RESEARCH_FLOW_ANALYSIS.md`
4. Implement following existing patterns

### Scenario 4: Performance Optimization
1. Check: `RESEARCH_FLOW_ANALYSIS.md` - Performance Characteristics
2. Profile: Using Instruments on identified layers
3. Reference: Layer responsibilities in `ARCHITECTURE_DIAGRAM.md`
4. Optimize: Following patterns in code

---

## Quick Links

- [RESEARCH_ANALYSIS_README.md](./RESEARCH_ANALYSIS_README.md) - Overview & Reference
- [RESEARCH_FLOW_ANALYSIS.md](./RESEARCH_FLOW_ANALYSIS.md) - Detailed Technical Guide
- [RESEARCH_ARCHITECTURE_DIAGRAM.md](./RESEARCH_ARCHITECTURE_DIAGRAM.md) - Visual Diagrams

---

**Last Updated:** November 12, 2025
**Status:** Complete Analysis
**Version:** 1.0

