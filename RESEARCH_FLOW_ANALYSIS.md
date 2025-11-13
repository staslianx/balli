# Research View Feature - Complete AI Response Flow Analysis

## Executive Summary

This document maps the complete execution path from when the AI backend starts responding to a medical research query until the answer is displayed on screen with full sources, citations, and metadata.

**Key Components:**
- Backend: Firebase Cloud Function streaming SSE (Server-Sent Events)
- Network Layer: HTTP/2 async streaming with UTF-8 boundary detection
- Parsing: Lightweight SSE parser with type-safe event decoding
- Buffering: Token smoothing for performance optimization
- Animation: Character-by-character typewriter effect
- Rendering: SwiftUI markdown text with inline citations

---

## Phase 1: User Initiates Search

### Entry Point
**File:** `InformationRetrievalView.swift` (main search interface)

```swift
// User taps search or enters query
Task {
    await viewModel.search(query: question)
}
```

### ViewModel Setup
**File:** `MedicalResearchViewModel.swift`

```swift
func search(query: String, image: UIImage? = nil) async {
    // 1. Create placeholder answer with empty content
    let placeholderAnswer = SearchAnswer(
        query: query,
        content: "",        // CRITICAL: Empty content initially
        sources: [],
        timestamp: Date(),
        tier: predictedTier
    )
    
    // 2. Insert at index 0 (newest first, reversed for display)
    stateManager.insertAnswer(placeholderAnswer, at: 0)
    searchState = .loading
    
    // 3. Initialize cancellation token for this answer
    let answerId = placeholderAnswer.id
    _ = streamProcessor.initializeCancellationToken(for: answerId)
    
    // 4. Start streaming search
    await performStreamingSearch(
        query: query,
        answerId: answerId,
        conversationHistory: conversationHistory
    )
}
```

---

## Phase 2: Stream Connection & Network Layer

### HTTP/2 Connection Setup
**File:** `ResearchStreamingAPIClient.swift`

```swift
func searchStreaming(
    query: String,
    userId: String,
    // ... multiple callbacks ...
    onToken: @escaping @Sendable (String) -> Void,
    onComplete: @escaping @Sendable (ResearchSearchResponse) -> Void
) async {
    // 1. Build request body with query + conversation history
    guard let jsonData = try? await networkService.buildSearchRequestBody(...) else {
        onError(ResearchSearchError.invalidRequest)
        return
    }
    
    // 2. Create URLRequest with streaming headers
    guard let request = try? await networkService.createStreamingRequest(...) else {
        return
    }
    
    // 3. Create streaming URLSession with 360s timeout
    let session = await networkService.createStreamingURLSession()
    
    // 4. Open HTTP/2 connection - returns AsyncSequence<UInt8>
    let (asyncBytes, response) = try await session.bytes(for: request)
    
    // 5. Validate HTTP 200 response
    try await networkService.validateStreamingResponse(response)
    
    streamingLogger.info("✅ Stream connection established - HTTP 200")
}
```

### UTF-8 Aware Byte-by-Byte Processing
**Critical:** SSE streams arrive as raw bytes. Must handle:
- Multi-byte UTF-8 sequences (don't split in middle)
- SSE event boundaries (`\n\n`)
- Chunk buffering for performance

```swift
// Raw byte loop
var totalBytesRead = 0
var currentChunk = Data()
currentChunk.reserveCapacity(512)

for try await byte in asyncBytes {
    currentChunk.append(byte)
    totalBytesRead += 1
    
    // Primary trigger: SSE event boundary \n\n
    let hasEventBoundary = currentChunk.count > 1 && 
                          currentChunk.suffix(2) == Data([0x0A, 0x0A])
    
    // Secondary trigger: 256 bytes with UTF-8 safety check
    let isUTF8Continuation = currentChunk.count >= 256 && 
                            !hasEventBoundary && 
                            isUTF8SequenceStart(currentChunk.last)
    let shouldProcessChunk = hasEventBoundary || 
                            (currentChunk.count >= 256 && !isUTF8Continuation)
    
    if shouldProcessChunk {
        // Process chunk
        processBytesAndEmitEvents(currentChunk)
        currentChunk = Data()
    }
}
```

---

## Phase 3: SSE Event Parsing

### Event Parser
**File:** `ServerSentEventParser.swift`

SSE Format (from backend):
```
data: {"type": "token", "content": "The"}\n\n
data: {"type": "token", "content": " patient"}\n\n
data: {"type": "complete", "sources": [...], "metadata": {...}}\n\n
```

**Parser Flow:**

```swift
class ResearchSSEParser {
    static func parseEvent(from data: String) -> ResearchSSEEvent? {
        // Handle comments (e.g., ": flush-tokens", ": keepalive")
        if data.hasPrefix(": ") {
            let comment = String(data.dropFirst(2))
            if comment == "flush-tokens" {
                return .flushTokens
            }
            return nil
        }
        
        // Extract JSON from "data: {...}"
        guard data.hasPrefix("data: ") else { return nil }
        let jsonString = String(data.dropFirst(6))
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        // Parse JSON
        guard let json = try JSONSerialization.jsonObject(...) as? [String: Any],
              let type = json["type"] as? String else { return nil }
        
        // Decode typed event
        switch type {
        case "token":
            guard let content = json["content"] as? String else { return nil }
            return .token(content: content)
            
        case "complete":
            // Parse sources, metadata, research summary
            let sources = parseSourcesArray(json["sources"])
            let metadata = parseMetadata(json["metadata"])
            return .complete(sources: sources, metadata: metadata, ...)
            
        case "planning_started":
            return .planningStarted(message: ..., sequence: ...)
            
        // ... 20+ other event types ...
        }
    }
}
```

### SSE Event Types

**Token Streaming Events:**
- `.token(content: String)` - Individual token from LLM synthesis
- `.flushTokens` - Backend signal that all tokens sent
- `.complete(...)` - Final response with all metadata

**Research Stage Events (Deep Research V2):**
- `.planningStarted/Complete` - Planning phase (T3 only)
- `.roundStarted/Complete` - Per-round search progress (T3 only)
- `.reflectionStarted/Complete` - Quality assessment (T3 only)
- `.sourceSelectionStarted` - Selecting best sources (T3 only)
- `.synthesisStarted` - Beginning final answer synthesis (T3 only)

**Search Progress Events:**
- `.searching(source:)` - Started searching source (pubmed, arxiv, etc.)
- `.searchComplete(count:, source:)` - Finished source search
- `.sourcesReady(sources:)` - Sources available before synthesis

---

## Phase 4: Stream Parsing & Buffering

### Raw Stream Processing
**File:** `ResearchStreamParser.swift` (Actor)

The ResearchStreamParser is an actor that maintains streaming state:

```swift
actor ResearchStreamParser {
    private var textBuffer = ""           // Partial SSE data
    private var dataBuffer = Data()       // Raw bytes waiting decode
    private var accumulatedAnswer = ""    // Growing answer text
    private var accumulatedSources: [SourceResponse] = []
    private var completeEventFired = false
    private var pendingCompleteData: CompleteEventData?
    
    // Buffer Management
    func appendToDataBuffer(_ chunk: Data) {
        dataBuffer.append(chunk)
    }
    
    func processDataBuffer() -> Bool {
        // Try UTF-8 decode, recover on partial sequences
        if let decodedString = String(data: dataBuffer, encoding: .utf8) {
            textBuffer += decodedString
            dataBuffer.removeAll(keepingCapacity: true)
            return true
        }
        // Handle corrupted/partial UTF-8 with recovery logic
    }
    
    func processCompleteEvents() -> [String] {
        var processedEvents: [String] = []
        
        // Extract SSE events ending with \n\n
        while let eventEndRange = textBuffer.range(of: "\n\n") {
            let eventData = String(textBuffer[..<eventEndRange.lowerBound])
            processedEvents.append(eventData)
            textBuffer.removeSubrange(..<eventEndRange.upperBound)
        }
        
        return processedEvents
    }
}
```

### Event Handling
**File:** `ResearchStreamParser.swift`

```swift
func handleEvent(
    _ event: ResearchSSEEvent,
    onToken: @escaping (String) -> Void,
    onComplete: @escaping (ResearchSearchResponse) -> Void,
    // ... other callbacks ...
) {
    switch event {
    case .token(let content):
        // Accumulate text
        accumulatedAnswer += content
        tokenCount += 1
        
        // Emit token callback IMMEDIATELY for real-time display
        onToken(content)
        
    case .flushTokens:
        // Backend signal - no action needed, tokens already emitted
        logger.info("Flush signal received - \(tokenCount) tokens sent")
        
    case .complete(let sources, let metadata, ...):
        // CRITICAL: Store complete event data but DON'T fire callback yet
        // Continue reading stream for any final events
        streamComplete = true
        pendingCompleteData = CompleteEventData(
            sources: sources,
            metadata: metadata,
            ...
        )
        logger.warning("Received 'complete' - storing but continuing stream")
        
    case .planningStarted(let message, let sequence):
        // Deep research events - forward to stage coordinator
        onPlanningStarted?(message, sequence)
        
    case .roundComplete(let round, let sources, let status, let sequence):
        // Research round completed - update UI with progress
        onRoundComplete?(round, sources, status, sequence)
        
    default:
        break
    }
}
```

**Critical Note on Complete Event:**
The `.complete` event is received BEFORE the stream actually closes. The parser stores it but continues reading for any final events. Only when:
1. Stream closes naturally, OR
2. Timeout after no events for 120s

...does it fire the `onComplete` callback.

This prevents:
- Premature completion before all tokens arrive
- Resetting streaming state mid-response
- Losing partial tokens

---

## Phase 5: Callback Chain & State Updates

### Callback Builder
**File:** `ResearchStreamCallbacksBuilder.swift`

The builder creates a complete set of @Sendable callbacks for the streaming operation:

```swift
struct ResearchStreamCallbacksBuilder {
    let viewModel: MedicalResearchViewModel
    
    func buildCallbacks(query: String, answerId: String) -> StreamCallbacks {
        return (
            // Token callback - CRITICAL: Real-time text delivery
            onToken: { token in
                Task { @MainActor in
                    await viewModel.handleToken(token, answerId: answerId)
                }
            },
            
            // Tier selected callback
            onTierSelected: { tier in
                Task { @MainActor in
                    await viewModel.handleTierSelected(
                        String(tier), 
                        answerId: answerId
                    )
                }
            },
            
            // Complete callback - Final response
            onComplete: { response in
                Task { @MainActor in
                    await viewModel.handleComplete(
                        response, 
                        query: query, 
                        answerId: answerId
                    )
                }
            },
            
            // Planning event callbacks (T3 only)
            onPlanningStarted: { message, sequence in
                Task { @MainActor in
                    await viewModel.handlePlanningStarted(
                        message: message, 
                        sequence: sequence, 
                        answerId: answerId
                    )
                }
            },
            
            // ... 10+ more callbacks ...
        )
    }
}
```

### Token Reception
**File:** `ResearchEventHandler.swift`

```swift
@MainActor
func handleToken(
    _ token: String,
    answerId: String,
    getAnswers: @escaping () -> [SearchAnswer],
    getAnswerIndex: @escaping (String) -> Int?,
    updateAnswer: @escaping (Int, SearchAnswer, Bool) -> Void
) async {
    // Locate answer
    guard let index = getAnswerIndex(answerId) else { return }
    
    let currentAnswer = getAnswers()[index]
    
    // FIRST TOKEN HANDLING: Signal animation start
    if currentAnswer.content.isEmpty {
        await stageCoordinator.handleFirstTokenArrival(answerId: answerId)
    }
    
    // APPEND TOKEN: Direct string concatenation
    let updatedAnswer = SearchAnswer(
        id: currentAnswer.id,
        query: currentAnswer.query,
        content: currentAnswer.content + token,  // <-- Direct append
        sources: currentAnswer.sources,
        // ... other fields unchanged ...
    )
    
    // UPDATE ANSWER STATE: Mutation on main thread
    updateAnswer(index, updatedAnswer, currentAnswer.content.isEmpty)
}
```

**Critical Design Note:**
- Token is appended DIRECTLY to `answer.content`
- NO intermediate buffering
- SwiftUI observes @Published property mutations → rerender
- Typewriter animation consumes tokens from displayed content

---

## Phase 6: SwiftUI State & Rendering

### ViewModel State Management
**File:** `MedicalResearchViewModel.swift`

```swift
@MainActor
class MedicalResearchViewModel: ObservableObject {
    // Answers array - main state
    @Published var answers: [SearchAnswer] = []
    
    // Search status
    @Published var searchState: ViewState<Void> = .idle
    
    // Tier being used
    @Published var currentSearchTier: ResponseTier?
    
    // Multi-round research stages
    @Published var currentStages: [String: String] = [:]
    
    // State manager handles answer mutations
    private let stateManager = ResearchAnswerStateManager()
    
    func updateAnswer(at index: Int, with answer: SearchAnswer) {
        stateManager.updateAnswer(at: index, with: answer)
        // Triggers objectWillChange → SwiftUI rerender
    }
}
```

### Main Research View
**File:** `InformationRetrievalView.swift`

```swift
struct InformationRetrievalView: View {
    @StateObject private var viewModel = MedicalResearchViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Display in chronological order (oldest → newest)
                ForEach(viewModel.answersInChronologicalOrder) { answer in
                    AnswerCardView(
                        answer: answer,
                        enableStreaming: !displayedAnswerIds.contains(answer.id),
                        isStreamingComplete: !isEffectivelySearching,
                        currentStage: viewModel.currentStages[answer.id],
                        onAnimationStateChange: { answerId, isAnimating in
                            // Track which answers still animating
                            if isAnimating {
                                animatingAnswerIds.insert(answerId)
                            } else {
                                animatingAnswerIds.remove(answerId)
                            }
                        }
                    )
                }
            }
        }
    }
}
```

**Critical Observation:**
- `viewModel.answers` changes trigger ForEach rebuild
- Each answer gets new AnswerCardView
- Animation state tracked separately from backend state
- `isEffectivelySearching = backend.isSearching || !animatingAnswerIds.isEmpty`

### Answer Card Display
**File:** `AnswerCardView.swift`

```swift
struct AnswerCardView: View {
    let answer: SearchAnswer
    let enableStreaming: Bool
    let isStreamingComplete: Bool
    let onAnimationStateChange: ((String, Bool) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: query, tier badge, source count
            AnswerCardHeaderSection(
                query: answer.query,
                tier: answer.tier,
                sources: answer.sources
            )
            
            // Research stage progress (Deep Research V2)
            if let stage = currentStage {
                ResearchStageStatusCard(stage: stage)
            }
            
            // Main answer content
            if !answer.content.isEmpty {
                TypewriterAnswerView(
                    content: answer.content,  // <-- Streaming content
                    isStreaming: !isStreamingComplete,
                    sourceCount: answer.sources.count,
                    sources: answer.sources,
                    fontSize: 19.0,
                    answerId: answer.id,
                    onAnimationStateChange: { isAnimating in
                        // Bubble up animation state
                        onAnimationStateChange?(answer.id, isAnimating)
                    }
                )
            }
            
            // Action buttons (copy, feedback) - show when animation complete
            if isStreamingComplete && !isTypewriterAnimating {
                ResearchResponseActionRow(...)
            }
        }
    }
}
```

---

## Phase 7: Text Animation & Display

### Typewriter Animation Controller
**File:** `TypewriterAnswerView.swift`

The typewriter view wraps StreamingAnswerView and animates tokens:

```swift
struct TypewriterAnswerView: View {
    let content: String  // Full accumulated content from backend
    let isStreaming: Bool
    let answerId: String
    let onAnimationStateChange: ((Bool) -> Void)?
    
    @State private var displayedContent = ""  // What user sees (animated)
    @State private var fullContentReceived = ""  // What backend sent
    @State private var animator = TypewriterAnimator()  // Animation engine
    @State private var isAnimationComplete = false
    
    var body: some View {
        StreamingAnswerView(
            content: displayedContent,  // <-- Animated display text
            isStreaming: isStreaming || !isAnimationComplete,
            sourceCount: sourceCount,
            sources: sources,
            fontSize: fontSize
        )
        .task(id: content) {
            // Triggered when backend appends new token
            guard content.count > fullContentReceived.count else { return }
            
            let newChars = String(content.dropFirst(fullContentReceived.count))
            
            // START ANIMATION on first characters
            if fullContentReceived.isEmpty {
                isAnimationComplete = false
                onAnimationStateChange?(true)  // Signal started
                
                // Cancel any stale animation
                await animator.cancel(answerId)
            }
            
            // ENQUEUE for character-by-character animation
            await animator.enqueueText(newChars, for: answerId) { displayedText in
                await MainActor.run {
                    // Deliver characters progressively
                    displayedContent = displayedText
                }
            } onComplete: {
                // All queued characters animated
                await MainActor.run {
                    isAnimationComplete = true
                    onAnimationStateChange?(false)  // Signal complete
                }
            }
            
            // Track what we've received
            fullContentReceived = content
        }
    }
}
```

**Flow Diagram:**
```
Backend sends token → content property updated
           ↓
.task(id: content) triggers
           ↓
Calculate new characters since last update
           ↓
enqueueText() to animator
           ↓
animator cycles through characters with delays
           ↓
deliver callback updates displayedContent
           ↓
StreamingAnswerView rerender (instant, no SwiftUI delay)
           ↓
User sees character appear on screen
```

### Typewriter Animator Engine
**File:** `TypewriterAnimator.swift` (Actor)

```swift
actor TypewriterAnimator {
    private let baseDelay: UInt64 = 8         // ms per character
    private let spaceDelay: UInt64 = 5        // ms for spaces
    private let punctuationDelay: UInt64 = 50 // ms after . ! ? : ;
    
    private var characterQueues: [String: [Character]] = [:]
    private var animationTasks: [String: Task<Void, Never>] = [:]
    
    func enqueueText(
        _ text: String,
        for answerId: String,
        deliver: @escaping @Sendable (String) async -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) async {
        // Initialize queue if needed
        if characterQueues[answerId] == nil {
            characterQueues[answerId] = []
        }
        
        // Add new characters to queue
        characterQueues[answerId]?.append(contentsOf: Array(text))
        
        // Start animation if not already running
        if animationTasks[answerId] == nil {
            await startAnimation(for: answerId, deliver: deliver, onComplete: onComplete)
        }
    }
    
    private func startAnimation(
        for answerId: String,
        deliver: @escaping @Sendable (String) async -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) async {
        let task = Task {
            var displayedText = ""
            
            while let queue = characterQueues[answerId], !queue.isEmpty {
                let char = queue.removeFirst()
                characterQueues[answerId]?.removeFirst()
                
                // Determine delay based on character
                let delay: UInt64 = {
                    if char.isWhitespace && char != "\n" { return spaceDelay }
                    if ",.!?;:".contains(char) { return punctuationDelay }
                    return baseDelay
                }()
                
                // Wait before displaying character
                try? await Task.sleep(nanoseconds: delay * 1_000_000)
                
                // Deliver character
                displayedText.append(char)
                await deliver(displayedText)
            }
            
            // Signal completion when queue empty
            await onComplete?()
        }
        
        animationTasks[answerId] = task
    }
}
```

---

## Phase 8: Markdown Rendering & Display

### MarkdownText Component
**File:** `MarkdownText.swift`

The final text render that converts markdown to styled SwiftUI:

```swift
struct MarkdownText: View {
    let content: String        // Markdown content
    let fontSize: CGFloat
    let sourceCount: Int
    let sources: [ResearchSource]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                // Parse markdown and render styled text
                ForEach(parseMarkdown(content), id: \.self) { element in
                    switch element {
                    case .paragraph(let text):
                        Text(text)
                            .font(.system(size: fontSize, weight: .regular, design: .default))
                            .lineSpacing(4)
                    
                    case .heading(let level, let text):
                        Text(text)
                            .font(.system(
                                size: fontSize * headingMultiplier(level),
                                weight: .semibold
                            ))
                            .padding(.top, 8)
                    
                    case .bulletList(let items):
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(items, id: \.self) { item in
                                HStack(alignment: .top) {
                                    Text("•")
                                    Text(item)
                                }
                            }
                        }
                    
                    case .citation(let text, let citationNumber):
                        // Inline citation with link
                        InlineCitationView(
                            text: text,
                            citationNumber: citationNumber,
                            sources: sources
                        )
                    }
                }
            }
            .padding(.horizontal, 0)
        }
    }
}
```

**Rendering Performance:**
- Direct SwiftUI Text rendering (no webview)
- Markdown parsing cached per content
- Citations rendered as interactive elements
- Inline links tappable to full source details

---

## Phase 9: Sources & Citations

### Source Display
**File:** `AnswerCardView.swift`

Sources appear in parallel with content:

```swift
// Sources callback (ResearchStreamParser)
case .sourcesReady(let sources):
    // Sources available during synthesis
    onSourcesReady?(sources)

// Handle in event handler
func handleSourcesReady(
    _ sources: [SourceResponse],
    answerId: String,
    updateAnswer: @escaping (Int, SearchAnswer) -> Void
) async {
    let convertedSources = sources.map { convertSource($0) }
    
    guard let index = getAnswerIndex(answerId) else { return }
    let currentAnswer = getAnswers()[index]
    
    // Merge with existing sources (avoid duplicates)
    let existingURLs = Set(currentAnswer.sources.map { $0.url.absoluteString })
    let newSources = convertedSources.filter { 
        !existingURLs.contains($0.url.absoluteString)
    }
    
    let updatedAnswer = SearchAnswer(
        // ... copy fields ...
        sources: currentAnswer.sources + newSources
    )
    
    updateAnswer(index, updatedAnswer)
}
```

### Citation Parsing
**File:** `CitationParser.swift`

Converts inline citations in markdown:

```
According to research[1], this is true[2].

[1] https://example.com
[2] https://paper.org
```

To:

```swift
InlineCitationView(
    text: "According to research",
    citationNumber: 1,
    sources: sources
)
```

---

## Complete Data Flow Visualization

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER INITIATION                                          │
│ InformationRetrievalView.search(query)                      │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. PLACEHOLDER CREATION                                     │
│ SearchAnswer(id, query, content="", sources=[], ...)        │
│ stateManager.insertAnswer(placeholderAnswer)                │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. NETWORK STREAM START                                     │
│ ResearchStreamingAPIClient.searchStreaming()                │
│ URLSession.bytes(for: request) → AsyncSequence<UInt8>       │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. BYTE ACCUMULATION (Background Thread)                    │
│ for try await byte in asyncBytes:                           │
│   currentChunk.append(byte)                                 │
│   if eventBoundary || 256bytes: processBytesAndEmitEvents() │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. SSE PARSING                                              │
│ ResearchSSEParser.parseEvent(data)                          │
│ JSON → ResearchSSEEvent (typed)                             │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
        ┌─────────────────────────┐
        │ 6a. Token Event         │
        │ .token(content: "The")   │
        └────────┬────────────────┘
                 │
        ┌────────▼─────────────────────────────────────┐
        │ 7a. Token Callback (Main Thread)             │
        │ onToken("The") → handleToken()               │
        └────────┬─────────────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────┐
        │ 8a. State Update                      │
        │ answer.content += "The"                │
        │ stateManager.updateAnswer()            │
        │ @Published mutation → SwiftUI rerender │
        └────────┬──────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────┐
        │ 9a. TypewriterAnswerView detects      │
        │ .task(id: content) fires              │
        │ Enqueue new "The" to animator         │
        └────────┬──────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────┐
        │ 10a. TypewriterAnimator               │
        │ Wait 8ms per char                     │
        │ deliver("T") → displayedContent="T"   │
        │ deliver("Th") → displayedContent="Th" │
        │ deliver("The") → displayedContent="The" │
        └────────┬──────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────┐
        │ 11a. StreamingAnswerView renders      │
        │ MarkdownText(content: displayedContent) │
        │ TEXT APPEARS ON SCREEN                │
        └────────────────────────────────────────┘
        
        ┌─────────────────────────┐
        │ 6b. Sources Ready Event │
        │ .sourcesReady(sources)  │
        └────────┬────────────────┘
                 │
        ┌────────▼──────────────────────┐
        │ 7b. Sources Callback          │
        │ onSourcesReady(sources)        │
        │ handleSourcesReady()           │
        └────────┬──────────────────────┘
                 │
        ┌────────▼──────────────────────┐
        │ 8b. State Update              │
        │ answer.sources += sources     │
        │ Update SourcePill on screen    │
        └────────┬──────────────────────┘
        
        ┌─────────────────────────┐
        │ 6c. Complete Event      │
        │ .complete(sources, meta)│
        └────────┬────────────────┘
                 │
        ┌────────▼──────────────────────┐
        │ Store pending completion data │
        │ Continue reading stream       │
        └────────┬──────────────────────┘
                 │
        ┌────────▼──────────────────────┐
        │ Stream closes naturally       │
        │ or timeout after 120s idle    │
        └────────┬──────────────────────┘
                 │
        ┌────────▼──────────────────────┐
        │ Fire onComplete callback      │
        │ searchState = .idle           │
        └────────────────────────────────┘
```

---

## Key Design Patterns

### 1. Real-Time Token Streaming
**Pattern:** Direct append to content, no intermediate buffering

```
Token arrives → Append to answer.content → SwiftUI observes → Rerender
                 ↓
             TypewriterView detects change via .task(id:)
                 ↓
             Animator enqueues characters
                 ↓
             Characters delivered with adaptive delays
                 ↓
             MarkdownText renders immediately
```

**Benefit:** Users see text appear in real-time without lag

### 2. Deferred Complete Event
**Pattern:** Store complete event data, fire callback only when stream truly ends

```
Complete event received → Store in parser → Continue reading stream
                           ↓
                      Timeout or stream close
                           ↓
                      Fire onComplete callback
```

**Benefit:** Prevents premature completion before all tokens arrive

### 3. Multi-Layer Animation
**Pattern:** Backend state + Typewriter animation + SwiftUI transitions

```
isSearching (backend) = true/false
                ↓
isAnimationComplete (typewriter) = true/false
                ↓
isEffectivelySearching = isSearching OR !isAnimationComplete
                ↓
Action buttons show only when BOTH complete
```

**Benefit:** UI stays responsive throughout entire operation

### 4. Per-Answer Cancellation
**Pattern:** UUID token per answer for stale event filtering

```
Answer 1 cancelled → Token UUID removed
Answer 2 events still processed
Answer 3 added → New token UUID assigned
```

**Benefit:** Multiple simultaneous searches supported

### 5. Conversation Context
**Pattern:** Maintain session with conversation history

```
Question 1 → Session 1 created
Answer 1 ← Stored in session
Question 2 → History=[Q1, A1] + New Q2
Answer 2 ← Uses context from Q1+A1
Question 3 → History=[Q1, A1, Q2, A2] + New Q3
```

**Benefit:** Coherent multi-turn conversations

---

## Error Handling & Edge Cases

### Stream Disconnection
```swift
// Automatic retry with exponential backoff
ResearchConnectionRetrier.executeWithRetry(
    operation: { attemptNumber in
        // Try streaming search
        await searchService.searchStreaming(...)
    },
    maxAttempts: 3,
    onReconnecting: { attempt in
        // Show "Reconnecting..." UI
    },
    onReconnected: {
        // Dismiss reconnection banner after 2s
    }
)
```

### Incomplete Response (Timeout)
```swift
// If no events for 120s idle timeout:
// 1. Check if we have partial content
if !accumulatedAnswer.isEmpty {
    // 2. Synthesize complete event from what we have
    synthesizeCompleteEvent()
} else {
    // 3. Report error to user
    onError(ResearchSearchError.streamingConnectionLost)
}
```

### UTF-8 Boundary Handling
```swift
// Don't split multi-byte UTF-8 sequences
if currentChunk.count >= 256 && !hasEventBoundary {
    let isUTF8Start = isUTF8SequenceStart(currentChunk.last)
    if isUTF8Start {
        // Wait for continuation bytes
        continue
    }
}
```

---

## Performance Characteristics

### Latency Breakdown
```
User hits search (0ms)
   ↓
Placeholder created (0.5ms)
   ↓
Network request built & sent (5-10ms)
   ↓
Backend processes & starts SSE (50-500ms depending on tier)
   ↓
First token arrives (50-2000ms)
   ↓
Token displayed with typewriter (8ms + animation delays)
   ↓
Text visible to user (100-150ms from token arrival)
```

### Memory Usage
```
Per active stream:
- TextBuffer: ~1MB (grows with response)
- DataBuffer: 512 bytes (reused)
- CharacterQueue: ~100KB (for animation)
- AccumulatedAnswer: ~1MB per 100K tokens
- Parser state: ~10KB
Total: ~2-3MB per active search
```

### Network Efficiency
```
Token batching: 256 bytes or event boundary (whichever first)
- Reduces syscalls vs byte-by-byte
- Maintains <16ms latency for character delivery
- Graceful handling of slow networks

Timeout: 360 seconds
- Allows deep research with multiple API calls
- Idle detection: 120s triggers timeout
- Partial response preserved on timeout
```

---

## Files Summary Table

| File | Purpose | Key Responsibility |
|------|---------|-------------------|
| `InformationRetrievalView.swift` | Main search UI | Display answers, handle search input |
| `MedicalResearchViewModel.swift` | Search orchestrator | State management, search lifecycle |
| `ResearchStreamingAPIClient.swift` | Network client | HTTP/2 SSE connection, byte streaming |
| `ServerSentEventParser.swift` | Event decoder | Parse JSON → ResearchSSEEvent |
| `ResearchStreamParser.swift` | Stream state manager | Buffer management, event accumulation |
| `ResearchEventHandler.swift` | Event processor | Handle each event type, update state |
| `TypewriterAnswerView.swift` | Animation controller | Animate tokens from content |
| `TypewriterAnimator.swift` | Animation engine | Character-by-character delays |
| `StreamingAnswerView.swift` | Content display | Render markdown with citations |
| `AnswerCardView.swift` | Answer container | Layout, sources, metadata display |
| `MarkdownText.swift` | Markdown renderer | Style markdown, handle citations |
| `ResearchStreamCallbacksBuilder.swift` | Callback factory | Create all streaming callbacks |
| `ResearchStreamProcessor.swift` | Event filter | Deduplication, cancellation |
| `ResearchStageCoordinator.swift` | Deep research UI | Display planning, rounds, reflection |

---

## Testing Entry Points

To verify the complete flow:

1. **Token Reception:** Mock SSE event with `token` type
2. **Content Display:** Verify `answer.content` updates
3. **Animation:** Check `displayedContent` animations
4. **Sources:** Mock `sourcesReady` event
5. **Completion:** Mock `complete` event with metadata
6. **Error Handling:** Disconnect stream, verify retry
7. **Timeout:** Wait 120s without events, verify synthesis

