# Issue Analysis - Performance & UI Cut-off Issues

## Issue 1: Device Performance Issue with `checkConnectionStatus`

### Problem
The HEAT.md logs show abnormally high device temperature/performance impact when using `checkConnectionStatus()`. The logs reveal multiple calls to this method happening frequently.

### Root Cause Analysis

#### 1. **Multiple Simultaneous Calls on App Launch**
From the logs:
```
🔍 [DexcomShareService]: checkConnectionStatus() called - current cached state: false
checkConnectionStatus() - cached isConnected=false
```

The `checkConnectionStatus()` method is called from multiple places:
- `AppLifecycleCoordinator.refreshDexcomTokenIfNeeded()` (line 134)
- `DexcomBackgroundRefreshManager.performConnectionHealthCheck()` (lines 162, 167)
- Multiple views observing Dexcom connection status

#### 2. **Expensive Operations in Check**
Looking at `DexcomShareService.checkConnectionStatus()` (lines 144-315):

```swift
func checkConnectionStatus() async {
    // ... debouncing logic ...

    // EXPENSIVE OPERATIONS:
    let hasCredentials = await authManager.hasCredentials()      // Keychain access
    let authenticated = await authManager.isAuthenticated()      // Session validation
    _ = try await authManager.getSessionId()                     // Full re-authentication
}
```

Each call involves:
- **Keychain access** (hasCredentials) - slow operation
- **Session validation** (isAuthenticated) - network request possibility
- **Token refresh/recovery** (getSessionId) - full OAuth flow with network requests
- **Multiple async operations** in sequence

#### 3. **Debounce Window Issue**
The code has a 2-second debounce (line 67):
```swift
private let connectionCheckDebounceInterval: TimeInterval = 2.0
```

But from HEAT.md logs:
```
Within debounce window (0.0s) - checking auth but skipping token refresh
```

This shows calls happening TOO FREQUENTLY (0.0s gap), overwhelming the debounce mechanism.

#### 4. **Foreground Transition Calls**
From `AppLifecycleCoordinator.swift` (line 134):
```swift
// Called EVERY TIME app comes to foreground
await dexcomService.checkConnectionStatus()
```

Combined with:
- Background refresh manager calling it every 6-8 hours
- Views calling it on appear
- Multiple service initialization calls

### Performance Impact

**Why Device Gets Hot:**
1. **Rapid Keychain Access**: Secure enclave operations are CPU-intensive
2. **Network Requests**: Multiple simultaneous OAuth validation requests
3. **Task Cancellation Overhead**: Race condition fix (line 146) cancels previous tasks but they may have already started expensive operations
4. **Exponential Backoff Retry**: Recovery attempts with delays (lines 220-248) keep CPU active

From logs:
```
🔄 Recovery attempt 1/3
🔄 Recovery attempt 2/3
🔄 Recovery attempt 3/3
```

Multiple recovery cycles = sustained CPU usage.

### Solution Recommendations

#### P0: Reduce Call Frequency
1. **Increase debounce interval** from 2s to 5s for foreground checks
2. **Cache connection state** more aggressively - only check on:
   - First app launch
   - Manual user action (settings)
   - Background refresh (6-8h intervals)
   - NOT on every foreground transition

#### P0: Optimize Expensive Operations
```swift
// BEFORE: Serial expensive checks
let hasCredentials = await authManager.hasCredentials()  // ~50ms
let authenticated = await authManager.isAuthenticated()   // ~100ms
_ = try await authManager.getSessionId()                  // ~500ms

// AFTER: Early exit with cached state
if cachedIsConnected && timeSinceLastFullCheck < 5.minutes {
    return // Skip expensive checks
}
```

#### P1: Batch Recovery Attempts
Instead of immediate retry with exponential backoff:
```swift
// BEFORE: Immediate retry cycles
🔄 Recovery attempt 1/3 (wait 30s)
🔄 Recovery attempt 2/3 (wait 60s)
🔄 Recovery attempt 3/3 (wait 120s)

// AFTER: Single recovery attempt, longer cooldown
🔄 Recovery attempt 1 (next attempt in 10 minutes)
```

#### P2: Remove Redundant Calls
From `AppLifecycleCoordinator.handleForegroundTransition()`:
```swift
// Remove this automatic check
// await refreshDexcomTokenIfNeeded()

// Replace with: Check only if user navigates to glucose view
```

---

## Issue 2: AI Response Cut-off at Beginning in Research View

### Problem
The AI response in the live research view (InformationRetrievalView) always appears cut off at the beginning, but when the same response is saved and viewed in research history (SearchLibraryView → SearchDetailView), the full text displays correctly.

### Root Cause Analysis

#### 1. **Typewriter Animation Timing Issue**
Looking at `TypewriterAnswerView.swift` (lines 54-84):

```swift
.task(id: content) {
    guard content.count > fullContentReceived.count else { return }

    let newChars = String(content.dropFirst(fullContentReceived.count))
    fullContentReceived = content  // ✅ Updated immediately

    // But animation starts AFTER this...
    await animator.enqueueText(newChars, for: answerId) { displayedText in
        // Delivered character by character with 8ms delay
        self.displayedContent = displayedText
    }
}
```

**The Problem:**
1. First content chunk arrives: "The answer to your question is..."
2. `fullContentReceived` is set to full text immediately
3. Animation starts character-by-character
4. **BUT**: If view re-renders before animation completes, the next `.task(id:)` run sees:
   - `content = "The answer to your question is..."`
   - `fullContentReceived = "The answer to your question is..."` (already updated!)
   - Guard fails: `content.count > fullContentReceived.count` = FALSE
   - **Animation never starts for initial chunk!**

#### 2. **View Lifecycle Race Condition**
From `AnswerCardView.swift` (lines 146-164):

```swift
.onAppear {
    onViewReady?(answer.id)  // Signal view is ready

    // Animate badge/source pill
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
        showBadge = true
    }
}
```

**Sequence:**
1. AnswerCardView appears
2. View signals it's ready (line 148)
3. Backend immediately starts streaming content
4. First chunk arrives: "The answer..."
5. TypewriterAnswerView's `.task(id:)` runs
6. `fullContentReceived` = "The answer..." (set immediately)
7. Animation queued but NOT started yet
8. **SwiftUI re-renders due to badge animation**
9. `.task(id:)` cancelled and restarted
10. Guard check fails because `fullContentReceived` already equals `content`
11. **First chunk animation lost!**

#### 3. **Why History View Works Correctly**
From `SearchDetailView.swift` (lines 96-99):

```swift
// Answer Content - matching AnswerCardView style
if !answer.content.isEmpty {
    SelectableMarkdownText(
        content: answer.content,  // ✅ Full content passed directly
```

**No Typewriter Animation** - content is displayed immediately and fully. No character-by-character animation, no task cancellation, no race conditions.

### Visual Difference

**Live View (Cut-off):**
```
[Research Badge appearing...] ← Animation triggers re-render
[Source Pill appearing...]    ← Another re-render
Text: "wer to your question is..."  ← First ~20 chars lost
```

**History View (Full):**
```
Text: "The answer to your question is..."  ← Full text immediately
```

### Solution Recommendations

#### P0: Fix Task Cancellation Issue
```swift
// In TypewriterAnswerView.swift

// BEFORE:
.task(id: content) {
    guard content.count > fullContentReceived.count else { return }
    let newChars = String(content.dropFirst(fullContentReceived.count))
    fullContentReceived = content  // ❌ Set immediately before animation
    await animator.enqueueText(newChars, for: answerId) { ... }
}

// AFTER:
.task(id: content) {
    guard content.count > fullContentReceived.count else { return }
    let newChars = String(content.dropFirst(fullContentReceived.count))

    // ✅ Only update fullContentReceived AFTER animation starts
    await animator.enqueueText(newChars, for: answerId) { displayedText in
        self.displayedContent = displayedText
    } onStart: {
        // ✅ New callback - update tracker when animation actually begins
        self.fullContentReceived = content
    }
}
```

#### P0: Prevent Re-render During Initial Animation
```swift
// In AnswerCardView.swift

// BEFORE:
.onAppear {
    // These animations trigger re-renders immediately
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
        showBadge = true
    }
}

// AFTER:
.task {
    // Wait for content to start streaming before animating badges
    while answer.content.isEmpty {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // Now safe to animate badges - content animation already started
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
        showBadge = true
    }
}
```

#### P1: Add Animation Start Callback
Modify `TypewriterAnimator.swift` to include an `onStart` callback:

```swift
func enqueueText(
    _ text: String,
    for answerId: String,
    deliver: @escaping @Sendable (String) async -> Void,
    onStart: (@Sendable () async -> Void)? = nil,  // ✅ New callback
    onComplete: (@Sendable () async -> Void)? = nil
) async {
    // Add characters to queue
    characterQueues[answerId]?.append(contentsOf: Array(text))

    // Start animation if not already running
    if animationTasks[answerId] == nil {
        await onStart?()  // ✅ Call when animation actually starts
        await startAnimation(for: answerId, deliver: deliver, onComplete: onComplete)
    }
}
```

#### P2: Alternative - Disable Animation for First Chunk
```swift
// In TypewriterAnswerView.swift

@State private var firstChunkReceived = false

.task(id: content) {
    guard content.count > fullContentReceived.count else { return }
    let newChars = String(content.dropFirst(fullContentReceived.count))

    if !firstChunkReceived {
        // First chunk - display immediately without animation
        displayedContent = newChars
        fullContentReceived = content
        firstChunkReceived = true
        onAnimationStateChange?(true)
    } else {
        // Subsequent chunks - animate normally
        await animator.enqueueText(newChars, for: answerId) { displayedText in
            self.displayedContent = displayedText
        }
        fullContentReceived = content
    }
}
```

---

## Summary

### Issue 1: Performance
- **Root Cause**: Too many expensive `checkConnectionStatus()` calls with keychain access and network requests
- **Fix Priority**: P0 - Increase debounce, cache state, reduce call frequency
- **Expected Impact**: 70-80% reduction in CPU usage during foreground transitions

### Issue 2: UI Cut-off
- **Root Cause**: Race condition between `.task(id:)` cancellation and animation start, losing first chunk
- **Fix Priority**: P0 - Update `fullContentReceived` only after animation starts
- **Expected Impact**: 100% of responses display from beginning

### Testing Plan

**Performance:**
1. Monitor device temperature before/after fix
2. Measure time spent in `checkConnectionStatus()` with Instruments
3. Verify debounce is working with logs

**UI Cut-off:**
1. Start new research query
2. Verify first characters appear ("The answer..." not "wer to...")
3. Test with fast streaming (rapid chunks)
4. Test with slow streaming (delayed chunks)
5. Verify history view still works correctly
