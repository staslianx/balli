# Research View Architecture - Visual Diagrams

## High-Level Component Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                        │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ InformationRetrievalView (Main Research Screen)          │  │
│  │ - Display answers in chronological order                 │  │
│  │ - Track animation state globally                         │  │
│  │ - Manage keyboard and scroll state                       │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │ ForEach(answersInChronologicalOrder) │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │ AnswerCardView (Per Answer)                              │  │
│  │ - Display query, tier, sources                           │  │
│  │ - Show research stage progress (Deep Research V2)        │  │
│  │ - Layout answer content and action buttons               │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │ Streaming Content                     │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │ TypewriterAnswerView (Animation Controller)              │  │
│  │ - Receive streaming content from backend                 │  │
│  │ - Coordinate with TypewriterAnimator                     │  │
│  │ - Manage animation lifecycle (start/complete)            │  │
│  │ - Feed displayedContent to view                          │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │ displayedContent (Animated)           │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │ StreamingAnswerView (Content Display)                    │  │
│  │ - No animation logic, just display                       │  │
│  │ - Pass to MarkdownText for rendering                     │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │ content (raw string)                  │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │ MarkdownText (Markdown Renderer)                         │  │
│  │ - Parse markdown syntax                                  │  │
│  │ - Apply styling (bold, italic, headers, lists)           │  │
│  │ - Render inline citations with sources                   │  │
│  │ - FINAL OUTPUT TO USER                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
         ▲
         │ @Published property updates
         │
┌────────┴──────────────────────────────────────────────────────┐
│              STATE MANAGEMENT LAYER (@MainActor)               │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ MedicalResearchViewModel (@MainActor ObservableObject)│  │
│  │                                                        │  │
│  │  @Published var answers: [SearchAnswer] = []          │  │
│  │  @Published var searchState: ViewState<Void>          │  │
│  │  @Published var currentSearchTier: ResponseTier?      │  │
│  │  @Published var currentStages: [String: String]       │  │
│  │                                                        │  │
│  │  Handler Methods:                                     │  │
│  │  - handleToken(_ token, answerId)                     │  │
│  │  - handleSourcesReady(_ sources, answerId)            │  │
│  │  - handleComplete(_ response, query, answerId)        │  │
│  │  - handlePlanningStarted/Complete (Deep Research)     │  │
│  │  - handleRoundStarted/Complete (Deep Research)        │  │
│  │  - handleReflectionStarted/Complete (Deep Research)   │  │
│  └────────────────────────────────────────────────────────┘  │
│            ▲                          ▲                        │
│            │ updateAnswer()           │ getAnswers()          │
│            │                          │                       │
│  ┌─────────┴──────────────────────────┴──────────────────┐   │
│  │ ResearchAnswerStateManager                           │   │
│  │ - Maintain answers array                             │   │
│  │ - Update individual answers at index                 │   │
│  │ - Track first token per answer                       │   │
│  │ - Provide ObservableObject semantics                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
         ▲
         │ Token/event callbacks from streaming
         │
┌────────┴──────────────────────────────────────────────────────┐
│            EVENT PROCESSING LAYER (@MainActor)                 │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ResearchEventHandler (@MainActor)                     │  │
│  │ - handleToken() → append to answer.content             │  │
│  │ - handleSourcesReady() → merge into answer.sources     │  │
│  │ - handleComplete() → finalize answer state             │  │
│  │ - handlePlanningStarted/Complete/etc → stageCoordinator│ │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                               │
│  ┌────────────▼────────────────────────────────────────┐   │
│  │ ResearchStreamCallbacksBuilder                      │   │
│  │ - Build callbacks from handler methods              │   │
│  │ - Wrap with Task { @MainActor in ... }              │   │
│  │ - Provide to streaming network client               │   │
│  └────────────────────────────────────────────────────┘   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
         ▲
         │ Parsed SSE events
         │
┌────────┴──────────────────────────────────────────────────────┐
│         SSE PARSING & STREAM MANAGEMENT (Background)          │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ResearchStreamingAPIClient (@MainActor)               │  │
│  │ - Delegate to ResearchNetworkService                  │  │
│  │ - Create streaming URLSession                         │  │
│  │ - Open HTTP/2 connection (asyncBytes)                 │  │
│  │ - Main event loop (byte-by-byte processing)           │  │
│  │ - Buffer chunk at event boundaries or 256B            │  │
│  │ - Process UTF-8 safely (no mid-sequence splits)       │  │
│  │ - Feed events to ResearchStreamParser                 │  │
│  │ - Invoke callbacks for parsed events                  │  │
│  └─────────────────────┬──────────────────────────────┬──┘  │
│                        │                              │       │
│          ┌─────────────▼──────────────┐       ┌──────▼─────┐ │
│          │ResearchStreamParser (Actor)│       │ResearchSSE │ │
│          │ - Maintain stream state    │       │ Parser     │ │
│          │ - Accumulate tokens        │       │ - Parse    │ │
│          │ - Buffer management        │       │ - JSON     │ │
│          │ - Emit events via handlers │       │ - Type     │ │
│          │ - Track completion         │       │ - Enum     │ │
│          └───────────────────────────┘       └────────────┘ │
│                                                                │
└────────────────────────────────────────────────────────────────┘
         ▲
         │ HTTP/2 stream (raw bytes)
         │
┌────────┴──────────────────────────────────────────────────────┐
│              NETWORK LAYER (URLSession)                        │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  Firebase Cloud Function HTTP Streaming Endpoint              │
│  └─ Server-Sent Events (SSE) Protocol                         │
│  └─ JSON formatted events separated by \n\n                   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Token Flow Through System

```
┌─────────────────┐
│ Firebase Backend│
│ LLM Synthesis   │
└────────┬────────┘
         │ Streams token as SSE event
         │ data: {"type": "token", "content": "The"}\n\n
         │
         ▼
┌─────────────────────────────┐
│ URLSession byte stream      │
│ Receives: 0x54 0x68 0x65... │  (T h e ...)
└────────┬────────────────────┘
         │ Accumulate 256 bytes or event boundary
         │
         ▼
┌─────────────────────────────┐
│ UTF-8 Decoding              │
│ "data: {...}\n\n"          │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ ResearchSSEParser           │
│ JSON parse → type + content │
│ ResearchSSEEvent.token      │
└────────┬────────────────────┘
         │ .token(content: "The")
         │
         ▼
┌─────────────────────────────┐
│ handleEvent callback        │
│ accumulatedAnswer += "The"  │
│ onToken("The") called       │
└────────┬────────────────────┘
         │ Cross thread boundary via Task { @MainActor }
         │
         ▼
┌─────────────────────────────┐
│ @MainActor handleToken()    │
│ answer.content += "The"     │
│ stateManager.updateAnswer() │
│ @Published property changed │
└────────┬────────────────────┘
         │ SwiftUI observes change
         │
         ▼
┌─────────────────────────────┐
│ TypewriterAnswerView        │
│ .task(id: content) fires    │
│ Enqueue "The" to animator   │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ TypewriterAnimator (Actor)  │
│ Char 'T': delay 8ms         │
│ Char 'h': delay 8ms         │
│ Char 'e': delay 8ms         │
│ Deliver: "T" → "Th" → "The" │
└────────┬────────────────────┘
         │ displayedContent updated
         │
         ▼
┌─────────────────────────────┐
│ StreamingAnswerView render  │
│ displayedContent passed     │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ MarkdownText renders        │
│ "The" appears on screen     │
└─────────────────────────────┘
```

---

## Deep Research V2 (Multi-Round) Event Sequence

```
Timeline:
┌──────────────────────────────────────────────────────────────────┐
│ T+0s: Backend starts processing                                  │
│ Event: planning_started                                          │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ ResearchStageCoordinator displays                            │
│ │  "Planning research strategy..."                              │
│ │  Progress: [████░░░░░░] 25%                                   │
│ └─ UI shows shimmer + stage card                                │
│
└──────────────────────────────────────────────────────────────────┘
│ T+2s: Plan complete, starts Round 1                              │
│ Event: planning_complete                                         │
│        plan: {                                                   │
│          subQuestions: ["Q1", "Q2", "Q3"],                      │
│          estimatedRounds: 3,                                    │
│          complexity: "complex"                                  │
│        }                                                         │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Show plan details                                            │
│ │  "3 sub-questions, Estimated 3 rounds"                       │
│ └─ Progress: [████████░░] 50%                                   │
│
└──────────────────────────────────────────────────────────────────┘
│ T+5s: Round 1 started                                            │
│ Event: round_started                                             │
│        round: 1                                                  │
│        query: "Sub-question 1"                                  │
│        estimatedSources: 25                                     │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Show "Searching Round 1..."                                 │
│ │  "Sub-question 1"                                            │
│ │  Progress: [████████░░] 50% → [██████████] 100%             │
│ └─ Spinner indicates searching                                  │
│
└──────────────────────────────────────────────────────────────────┘
│ T+8s: APIs called (pubmed, arxiv, clinical trials)              │
│ Event: api_started (multiple)                                   │
│        api: "pubmed", count: 25                                 │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Show "Searching PubMed (25 sources expected)..."             │
│ └─ Per-API progress tracking                                    │
│
└──────────────────────────────────────────────────────────────────┘
│ T+12s: APIs complete, sources ready                             │
│ Event: api_completed (multiple)                                 │
│        sources: [{title, url, ...}]                            │
│        Then: round_complete                                     │
│        sources: [combined from all APIs]                        │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Update sources immediately                                   │
│ │  [Source 1] [Source 2] [Source 3] ...                        │
│ │  "45 sources found in Round 1"                               │
│ └─ Parallel synthesis starts                                    │
│
└──────────────────────────────────────────────────────────────────┘
│ T+15s: Quality reflection on Round 1                            │
│ Event: reflection_started                                       │
│        round: 1                                                 │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Show "Analyzing evidence quality..."                         │
│ └─ Pause waiting for reflection result                          │
│
└──────────────────────────────────────────────────────────────────┘
│ T+18s: Reflection complete                                      │
│ Event: reflection_complete                                      │
│        reflection: {                                            │
│          hasEnoughEvidence: true,                              │
│          evidenceQuality: "high",                              │
│          shouldContinue: false                                 │
│        }                                                        │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Decision: Evidence sufficient, abort Rounds 2-3              │
│ │  "High quality evidence found, proceeding to synthesis"      │
│ └─ Progress: Move to synthesis stage                            │
│
└──────────────────────────────────────────────────────────────────┘
│ T+20s: Source selection                                         │
│ Event: source_selection_started                                 │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Show "Selecting best sources..."                             │
│ └─ Filtering to most relevant ~10-15 sources                    │
│
└──────────────────────────────────────────────────────────────────┘
│ T+22s: Synthesis preparation                                    │
│ Event: synthesis_preparation                                    │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Show "Preparing final answer..."                             │
│ └─ Organizing sources and structure                             │
│
└──────────────────────────────────────────────────────────────────┘
│ T+24s: Synthesis begins                                         │
│ Event: synthesis_started                                        │
│        totalRounds: 1,                                          │
│        totalSources: 45                                         │
│ Then: token events begin...                                     │
│       token: "Type"                                             │
│       token: "2"                                                │
│       token: " diabetes..."                                     │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Hide stage card                                              │
│ │  Start displaying tokens with typewriter animation           │
│ │  Show sources in pill at header                              │
│ │  "45 sources used"                                           │
│ │  Display: "Type2 diabetes..." (characters appear)            │
│ └─ User sees real-time synthesis                                │
│
└──────────────────────────────────────────────────────────────────┘
│ T+60s: Final tokens arrive                                      │
│ Event: token: "...care plan." (last token)                     │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Continue animation for final tokens                          │
│ └─ displayedContent = full answer                              │
│
└──────────────────────────────────────────────────────────────────┘
│ T+62s: Complete event received                                  │
│ Event: complete                                                 │
│        sources: [final source list]                            │
│        metadata: {tokenUsage, processingTime, etc}             │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Parser stores but continues reading                          │
│ └─ Stream waiting to close                                      │
│
└──────────────────────────────────────────────────────────────────┘
│ T+63s: Stream closes                                            │
│ Backend closed connection (natural)                             │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Parser fires onComplete callback                             │
│ │  searchState = .idle                                         │
│ │  Wait for typewriter animation to finish                     │
│ └─ Action buttons become available                              │
│
└──────────────────────────────────────────────────────────────────┘
│ T+68s: Animation completes                                      │
│ All characters displayed, animation queue empty                │
└──────────────────────────────────────────────────────────────────┘
│
│ ┌─ Final state:                                                 │
│ │  ✅ Answer complete                                          │
│ │  ✅ All sources displayed                                    │
│ │  ✅ Tier badge (T3 Deep Research)                            │
│ │  ✅ Thinking summary (if available)                          │
│ │  ✅ Action row visible (Copy, Share, Feedback)               │
│ │  ✅ Follow-up questions ready                                │
│ └─ User can interact                                            │
│
└──────────────────────────────────────────────────────────────────┘
```

---

## State Coordination Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Answer State at Various Stages                                  │
└─────────────────────────────────────────────────────────────────┘

INITIAL STATE (Placeholder):
├─ answer.id = UUID
├─ answer.query = "Type 2 diabetes management"
├─ answer.content = ""                      ← Empty
├─ answer.sources = []                      ← Empty
├─ answer.tier = .predicted (T2)            ← Guessed
└─ answer.timestamp = now

AFTER TIER SELECTED:
├─ answer.id = UUID (same)
├─ answer.query = "Type 2 diabetes management"
├─ answer.content = ""                      ← Still empty
├─ answer.sources = []
├─ answer.tier = .selected (T3)             ← Updated
└─ processingTierRaw = "DEEP_RESEARCH"      ← Set

DURING TOKENS (First Content):
├─ answer.id = UUID (same)
├─ answer.query = "Type 2 diabetes management"
├─ answer.content = "Type"                  ← Streaming
├─ answer.sources = []
├─ answer.tier = .selected (T3) (same)
└─ completedRounds = [ResearchRound(...)]   ← Added

DURING TOKENS (Continuing):
├─ answer.id = UUID (same)
├─ answer.query = "Type 2 diabetes management"
├─ answer.content = "Type 2 diabetes is a..."  ← Growing
├─ answer.sources = []
├─ answer.tier = .selected (T3) (same)
└─ completedRounds = [ResearchRound(...)]   ← Accumulating

AFTER SOURCES READY:
├─ answer.id = UUID (same)
├─ answer.query = "Type 2 diabetes management"
├─ answer.content = "Type 2 diabetes is a..."  ← Still growing
├─ answer.sources = [Source1, Source2, ...]    ← Added!
├─ answer.tier = .selected (T3) (same)
└─ completedRounds = [ResearchRound(...)]   ← Complete

AFTER COMPLETE EVENT:
├─ answer.id = UUID (same)
├─ answer.query = "Type 2 diabetes management"
├─ answer.content = "Type 2 diabetes is a... [rest]"  ← All tokens
├─ answer.sources = [Source1, Source2, ...]  (same)
├─ answer.tier = .selected (T3) (same)
├─ answer.thinkingSummary = "Key insights..." ← Added!
├─ answer.tokenCount = 1245                    ← Final count
├─ processingTierRaw = "DEEP_RESEARCH"         ← Confirmed
└─ completedRounds = [ResearchRound(...)]      ← Final

UI VISIBILITY AT EACH STAGE:
├─ Initial: "Query • Shimmer (searching...)"
├─ After tier: "Query • T3 Badge • Shimmer"
├─ First token: "Query • T3 Badge • Text(single char) • Shimmer"
├─ Streaming: "Query • T3 Badge • Text(growing) • Source pill • Shimmer"
├─ Sources: "Query • T3 Badge • Text(growing) • [Source1][Source2]..."
├─ Synthesis: "Query • T3 Badge • Text(complete) • Sources • Action row"
└─ Complete: "Query • T3 Badge • Text(complete) • Sources • Feedback row"
```

---

## Thread Safety & Concurrency Model

```
┌─────────────────────────────────────────────────────────────────┐
│ Main Thread (@MainActor)                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MedicalResearchViewModel (@MainActor class)                   │
│  ├─ @Published var answers: [SearchAnswer]                    │
│  ├─ @Published var searchState: ViewState<Void>               │
│  ├─ All handler methods: handleToken(), handleComplete(), etc  │
│  └─ All mutations on main thread ONLY                         │
│                                                                 │
│  ResearchEventHandler (@MainActor class)                      │
│  └─ Receives callbacks from background → Wraps in MainActor   │
│                                                                 │
│  TypewriterAnswerView @State properties                        │
│  ├─ displayedContent (updated by animator)                    │
│  ├─ fullContentReceived (tracks what arrived)                 │
│  └─ isAnimationComplete (lifecycle flag)                      │
│                                                                 │
│  TypewriterAnimator (@State actor)                            │
│  ├─ Isolated actor (safe concurrent access)                   │
│  ├─ enqueueText() → add to characterQueues                    │
│  ├─ deliver callback → async, back to MainActor               │
│  └─ No direct SwiftUI mutation                                │
│                                                                 │
│  InformationRetrievalView @State properties                   │
│  ├─ animatingAnswerIds: Set<String>                           │
│  └─ displayedAnswerIds: Set<String>                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         ▲                                      │
         │ Callbacks wrapped in Task {}        │ Isolation boundary
         │                                      │
         ▼                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│ Background Threads (URLSession + Task pools)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ResearchStreamingAPIClient (dispatches to background)         │
│  ├─ URLSession.bytes() executes on connection thread          │
│  ├─ Byte-by-byte reading loop                                 │
│  ├─ ResearchStreamParser.handleEvent() processes events       │
│  └─ Callback invocations (onToken, onComplete, etc)           │
│                                                                 │
│  ResearchStreamParser (Actor - background safe)               │
│  ├─ textBuffer / dataBuffer mutations                         │
│  ├─ accumulatedAnswer / accumulatedSources                    │
│  ├─ Methods are async-safe (await required)                   │
│  └─ No direct SwiftUI mutations                               │
│                                                                 │
│  Type Safety Guarantees:                                       │
│  ├─ All @Sendable callbacks passed across thread boundary      │
│  ├─ ResearchSSEEvent is Sendable (enum with Sendable values)  │
│  ├─ String, Array, Int are Sendable                           │
│  └─ No unsafe access or mutable state sharing                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

CRITICAL FLOW:
┌─────────────────────────────────┐
│ Background: onToken("The")      │ ← Non-Sendable callback parameter
└────────────┬────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│ Task { @MainActor in                         │
│   await viewModel.handleToken("The", id)    │  ← Marshal to main
│ }                                            │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│ @MainActor handleToken(_ token)              │
│   answer.content += token                    │  ← Safe mutation
│   stateManager.updateAnswer()                │
│   @Published notification sent               │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│ SwiftUI detects @Published change            │
│ TypewriterAnswerView.task(id:) fires         │  ← Main thread render
│ Calls animator.enqueueText()                 │
└─────────────────────────────────────────────┘
```

---

## Error Handling Flow

```
SCENARIO 1: Network Timeout (360s)
┌──────────────────────────────────────┐
│ URLSession times out                 │
│ No bytes received for 360s            │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ Stream loop catches error                        │
│ ResearchStreamingAPIClient catches exception     │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ onError(ResearchSearchError.networkTimeout)     │
│ Wrapped in Task { @MainActor }                   │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ ConnectionRetrier catches error                  │
│ Retries with exponential backoff                 │
│ Attempt 1: Immediate                             │
│ Attempt 2: After 2s delay                        │
│ Attempt 3: After 4s delay                        │
└────────┬─────────────────────────────────────────┘
         │
         ├─ If retry succeeds:
         │  └─ Stream resumes from beginning (restart)
         │
         └─ If all retries fail:
            └─ onError propagates to ViewModel
               └─ searchState = .error(...)
               └─ Show error banner to user


SCENARIO 2: Incomplete Response (120s idle)
┌──────────────────────────────────────┐
│ Tokens arriving normally              │
│ accumulatedAnswer = "Long response..."│
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ No events for 120s (idle timeout)    │
│ ResearchStreamParser.checkIdleTimeout()
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ Synthesize completion (stream didn't send        │
│ "complete" event normally)                       │
│                                                  │
│ Check:                                           │
│ ├─ Is accumulatedAnswer.count > 100?  YES       │
│ ├─ Is accumulatedAnswer.isEmpty?      NO        │
│ └─ Fire synthetic complete event      YES       │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ synthesizeCompleteEvent() creates                │
│ ResearchSearchResponse {                         │
│   answer: accumulatedAnswer (use what we have)   │
│   sources: accumulatedSources (from prior events)│
│   metadata: placeholder (incomplete)             │
│ }                                                │
│                                                  │
│ onComplete(synthesizedResponse)                 │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ @MainActor handleComplete() called               │
│ Update answer state with synthetic response      │
│ searchState = .idle                              │
│ Log warning: "Synthesized completion"            │
└──────────────────────────────────────────────────┘


SCENARIO 3: Malformed JSON in Event
┌──────────────────────────────────────┐
│ Event received:                       │
│ data: {"type": "token" "content": "x"}│  ← Missing comma
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ ResearchSSEParser.parseEvent()                   │
│ JSONSerialization throws error                   │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ parseEvent() returns nil (silent failure)        │
│ Logs error: "SSE JSON parse error"               │
│ Event ignored                                    │
│ Continue reading stream                          │
└──────────────────────────────────────────────────┘
         │
         └─ Stream continues, may recover with next valid event

SCENARIO 4: UTF-8 Decoding Error
┌──────────────────────────────────────┐
│ Invalid UTF-8 bytes in chunk          │
│ String(data:encoding:.utf8) returns nil
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ ResearchStreamParser.processDataBuffer()         │
│ Check: dataBuffer.count > 8192?                  │
├─ YES: Attempt recovery at boundaries            │
│       Try subsets until valid UTF-8 found       │
│       Skip corrupted bytes                      │
│                                                  │
│       Logs: "Skipping X bytes of bad data"      │
│                                                  │
└─ NO: Keep accumulating (maybe incomplete char)  │
       Wait for more bytes                        │
└──────────────────────────────────────────────────┘
```

