# Performance Profiling Guide - Phase 10

**Date:** 2025-11-02
**Target:** iOS 26+ | iPhone 17 Pro | Swift 6
**Tools:** Xcode Instruments

---

## Overview

This guide provides a comprehensive checklist for profiling the balli app using Xcode Instruments. Phase 10 requires interactive tooling that cannot be automated via command line.

**Time Required:** 2-3 hours
**Prerequisites:** iPhone 17 Pro simulator or physical device, Xcode 16+

---

## Pre-Profiling Checklist

### 1. Build Configuration
```bash
# Ensure Release build configuration for accurate profiling
xcodebuild -scheme balli -configuration Release -sdk iphoneos clean build
```

**Why Release Build?**
- Optimizations enabled (like production)
- Debug symbols still available for profiling
- Accurate performance measurements

### 2. Test Scenarios Preparation

Prepare test data for profiling:
- [ ] 50+ food items in database
- [ ] 20+ logged meals with photos
- [ ] 10+ recipes generated
- [ ] 5+ research queries with sources
- [ ] Sample glucose data (if Dexcom connected)

### 3. Known Performance-Critical Areas

Based on code audit, focus profiling on:

**High Priority:**
1. **TodayView.swift** (790 lines) - Main dashboard
2. **ArdiyeView.swift** (826 lines) - Food archive with large datasets
3. **InformationRetrievalView.swift** (592 lines) - Streaming research
4. **RecipeGenerationView.swift** (658 lines) - AI recipe generation with streaming
5. **LoggedMealsView.swift** (765 lines) - Meal history with photos

**Data Operations:**
6. **PersistenceController** - Core Data operations
7. **MemorySyncService** - Background sync operations
8. **CacheManager** - Memory and disk caching

**Rendering:**
9. **MarkdownRenderer** - Markdown to AttributedString conversion
10. **Image loading** - UIImage/AsyncImage performance

---

## Instruments Template Guide

### Template 1: Time Profiler (CPU Usage)

**Purpose:** Identify CPU hotspots and inefficient code paths

**How to Run:**
1. Open Xcode
2. Product → Profile (⌘I)
3. Select "Time Profiler" template
4. Click Record (red button)

**What to Test:**
- [ ] App launch (cold and warm)
- [ ] TodayView initial load
- [ ] ArdiyeView scrolling with 100+ items
- [ ] Recipe generation with streaming
- [ ] Research query with markdown rendering
- [ ] Photo capture and OCR processing
- [ ] Switching between tabs rapidly

**What to Look For:**
- Functions taking >100ms on main thread
- Excessive calls to small functions (N+1 issues)
- SwiftUI body computations taking >16ms (causes frame drops)
- Image decoding on main thread
- Heavy computations not on background queues

**Red Flags:**
- 🔴 Main thread blocked >100ms → UI freeze
- 🟡 Function called 1000+ times → Loop optimization needed
- 🟡 JSON parsing on main thread → Move to background

**Export Results:**
```
File → Export → CSV → time_profiler_results.csv
```

---

### Template 2: Allocations (Memory Usage)

**Purpose:** Detect memory leaks, excessive allocations, and memory growth

**How to Run:**
1. Product → Profile (⌘I)
2. Select "Allocations" template
3. Click Record
4. Enable "Generations" in toolbar

**What to Test:**
- [ ] Navigate through all major views
- [ ] Generate 5 recipes (check memory after each)
- [ ] Perform 5 research queries (check memory after each)
- [ ] Load 100+ food items in ArdiyeView
- [ ] Take 10 photos with camera (check each photo's memory)
- [ ] Switch tabs 20 times
- [ ] Use app for 10 minutes continuously

**Create Generations:**
After each major action, click "Mark Generation" to track memory growth.

**What to Look For:**
- Memory growth after generations (should return to baseline)
- SwiftUI View allocations not being released
- Image cache growing unbounded
- Core Data fetch results not released
- Closure capture cycles (leaked actors/view models)

**Memory Targets:**
- App launch: <100MB
- Normal usage: <150MB
- Heavy usage (photos): <300MB
- After returning to background: Return to <100MB

**Red Flags:**
- 🔴 Memory grows 10MB+ per generation → Memory leak
- 🔴 Memory never decreases after actions → Retention cycle
- 🟡 Sudden 50MB+ allocation → Large asset or data issue
- 🟡 100+ view allocations not released → SwiftUI leak

**Export Results:**
```
File → Export → CSV → allocations_results.csv
```

---

### Template 3: Leaks (Memory Leak Detection)

**Purpose:** Find retain cycles and leaked objects

**How to Run:**
1. Product → Profile (⌘I)
2. Select "Leaks" template
3. Click Record
4. Watch for red "Leak" indicators

**What to Test:**
- [ ] Navigate to every view and back
- [ ] Generate recipe, close view, repeat 5x
- [ ] Start research query, cancel, repeat 5x
- [ ] Open camera, close, repeat 5x
- [ ] Open meal detail, close, repeat 10x
- [ ] Use app for 5 minutes, background, foreground

**What to Look For:**
- Red "Leak" indicators in timeline
- Leaked closures capturing self
- Retained view models after view dismissal
- Actor reference cycles
- SwiftUI environment object leaks

**Common Leak Patterns:**
```swift
// 🔴 LEAK: Strong self capture
Task {
    self.performAction() // Should be [weak self]
}

// 🔴 LEAK: Delegate not weak
var delegate: SomeDelegate // Should be weak var

// 🔴 LEAK: Closure capture in SwiftUI
.onChange(of: value) { _ in
    self.viewModel.update() // Should use @Binding or weak self
}
```

**Red Flags:**
- 🔴 Any leak detected → Must fix
- 🔴 Leaked actors → Critical concurrency issue
- 🔴 Leaked view models → Navigation issue

**Export Results:**
```
File → Export → CSV → leaks_results.csv
```

---

### Template 4: Energy Log (Battery Impact)

**Purpose:** Measure battery drain and identify energy-intensive operations

**How to Run:**
1. Product → Profile (⌘I)
2. Select "Energy Log" template
3. Click Record
4. Use app normally for 10 minutes

**What to Test:**
- [ ] Background sync operations
- [ ] Continuous glucose monitoring (if enabled)
- [ ] Location services (if used)
- [ ] Network requests frequency
- [ ] Camera usage
- [ ] Screen brightness impact

**What to Look For:**
- CPU usage over time (should be low when idle)
- Network activity spikes (batching opportunities)
- Location updates frequency (should be minimal)
- Background tasks running too frequently

**Energy Targets:**
- Idle (background): <5% CPU
- Normal usage: <20% CPU average
- Heavy usage (camera): <40% CPU average

**Red Flags:**
- 🔴 >10% CPU in background → Background task issue
- 🟡 Frequent network requests (>1/sec) → Batch requests
- 🟡 Location updates every second → Reduce frequency
- 🟡 Screen constantly preventing sleep → Timer issue

**Export Results:**
```
File → Export → CSV → energy_log_results.csv
```

---

### Template 5: Network (API Performance)

**Purpose:** Analyze network request performance and efficiency

**How to Run:**
1. Product → Profile (⌘I)
2. Select "Network" template
3. Click Record

**What to Test:**
- [ ] Initial app launch (auth, data sync)
- [ ] Generate 5 recipes (Cloud Functions calls)
- [ ] Perform 5 research queries (streaming responses)
- [ ] Upload 10 photos
- [ ] Sync meal logs to Firestore
- [ ] Background sync operations

**What to Look For:**
- Request duration (should be <3s for normal operations)
- Duplicate requests (caching opportunities)
- Large payload sizes (compression opportunities)
- Sequential requests that could be parallelized
- Failed requests (retry logic verification)

**Network Targets:**
- API response time: <1s median
- Image upload: <5s for 2MB image
- Streaming responses: Start within 500ms
- Cache hit rate: >70% for repeated data

**Red Flags:**
- 🔴 >5s request time → Timeout or slow API
- 🔴 Same request repeated 10+ times → Cache not working
- 🟡 10MB+ response without compression → Enable compression
- 🟡 Waterfall of sequential requests → Parallelize

**Export Results:**
```
File → Export → CSV → network_results.csv
```

---

## Profiling Scenarios

### Scenario 1: App Launch Performance

**Goal:** App launch <2 seconds to interactive

**Steps:**
1. Force quit app completely
2. Start Time Profiler
3. Launch app from home screen
4. Wait until TodayView is fully loaded
5. Stop profiling

**Success Criteria:**
- [ ] Launch to first UI: <1s
- [ ] Launch to interactive: <2s
- [ ] No frame drops during splash
- [ ] Main thread never blocked >100ms

**Check:**
- PersistenceController initialization time
- Firebase SDK initialization time
- SwiftUI view first render time
- Initial data fetch time

---

### Scenario 2: TodayView Performance

**Goal:** 60fps scrolling and <500ms load time

**Steps:**
1. Start Time Profiler
2. Navigate to TodayView
3. Scroll rapidly up and down for 30 seconds
4. Pull to refresh 5 times
5. Stop profiling

**Success Criteria:**
- [ ] Initial load: <500ms
- [ ] Smooth scrolling at 60fps (16ms per frame)
- [ ] Pull-to-refresh: <1s
- [ ] No visible stutter

**Check:**
- SwiftUI body re-computation frequency
- Image loading performance (should be async)
- Data fetching impact on UI thread
- Layout calculation time

---

### Scenario 3: Recipe Generation with Streaming

**Goal:** Streaming starts <500ms, smooth text updates

**Steps:**
1. Start Time Profiler + Allocations
2. Generate 3 recipes sequentially
3. Watch for smooth streaming text
4. Cancel mid-stream, generate again
5. Stop profiling

**Success Criteria:**
- [ ] Streaming starts: <500ms
- [ ] Text updates smoothly without lag
- [ ] No memory growth after each recipe
- [ ] Markdown rendering doesn't block UI

**Check:**
- Network streaming implementation
- Markdown rendering performance
- Memory allocation per token
- AsyncStream buffer handling

---

### Scenario 4: Research Query Performance

**Goal:** Citations render correctly, no raw markdown visible

**Steps:**
1. Start Time Profiler
2. Perform 3 research queries
3. Verify citations [1], [2], etc. render as links
4. Verify no raw markdown (**bold**, *italic*) visible
5. Scroll through long responses
6. Stop profiling

**Success Criteria:**
- [ ] Query response starts: <500ms
- [ ] Markdown renders properly (no raw syntax)
- [ ] Citations are clickable links
- [ ] Scrolling smooth at 60fps
- [ ] No text flickering during streaming

**Check:**
- Markdown parser performance
- Citation link generation
- AttributedString creation time
- Incremental rendering performance

---

### Scenario 5: Memory Leak Detection

**Goal:** No memory leaks in any feature

**Steps:**
1. Start Leaks template
2. Navigate through EVERY major view:
   - TodayView → ArdiyeView → LoggedMealsView
   - RecipeGenerationView → Generate recipe → Back
   - InformationRetrievalView → Query → Back
   - CameraView → Take photo → Back
   - AppSettingsView → Change settings → Back
3. Repeat navigation 3 times
4. Check for any red "Leak" indicators
5. Stop profiling

**Success Criteria:**
- [ ] Zero leaks detected
- [ ] Memory returns to baseline after navigation
- [ ] No zombie actors or view models

**Check:**
- SwiftUI view lifecycle
- Actor reference cycles
- Closure capture patterns
- Delegate/protocol retention

---

### Scenario 6: Background Sync Performance

**Goal:** Efficient background sync without draining battery

**Steps:**
1. Start Energy Log
2. Add 10 meal logs offline
3. Background app (CMD+SHIFT+H on simulator)
4. Wait 2 minutes
5. Foreground app
6. Verify meals synced
7. Stop profiling

**Success Criteria:**
- [ ] Sync completes in background
- [ ] <5% CPU usage in background
- [ ] Batch operations (not per-item sync)
- [ ] Network requests batched

**Check:**
- MemorySyncService performance
- Background task CPU usage
- Network request batching
- Core Data batch operations

---

## Critical Areas to Profile

### 1. MarkdownRenderer.swift (HIGH PRIORITY)

**Why:** Used in research responses with potentially thousands of characters

**Profile:**
- Time to render 5000-character markdown
- AttributedString creation time
- Citation link generation performance
- Memory allocation per render

**Expected:**
- <50ms for 1000 characters
- <200ms for 5000 characters
- Memory: ~1KB per 1000 characters

**Red Flags:**
- 🔴 >500ms for any render → Optimize parser
- 🔴 Blocking main thread → Move to background
- 🟡 Creating new parser per render → Reuse instance

---

### 2. CacheManager.swift (HIGH PRIORITY)

**Why:** Used for images, responses, and data caching

**Profile:**
- Cache hit/miss ratio
- Disk I/O performance
- Memory cache size growth
- Eviction policy effectiveness

**Expected:**
- Cache hit rate: >70%
- Disk read: <10ms
- Disk write: <50ms
- Memory usage: <50MB for cache

**Red Flags:**
- 🔴 <50% hit rate → Cache TTL too short
- 🔴 Cache growing unbounded → Eviction not working
- 🟡 Disk I/O on main thread → Move to background

---

### 3. PersistenceController.swift (HIGH PRIORITY)

**Why:** Core Data operations for all data storage

**Profile:**
- Fetch request time
- Save operation time
- Context merge performance
- Background task concurrency

**Expected:**
- Simple fetch: <10ms
- Complex fetch: <50ms
- Save operation: <100ms
- No main thread blocking

**Red Flags:**
- 🔴 >500ms for any fetch → Query optimization needed
- 🔴 Save blocking UI → Use background context
- 🟡 Frequent small saves → Batch operations

---

### 4. ResearchStreamProcessor.swift (MEDIUM PRIORITY)

**Why:** Handles streaming research responses

**Profile:**
- SSE event processing time
- Stage transition performance
- AsyncStream buffer handling
- Token-by-token processing overhead

**Expected:**
- Event processing: <1ms per event
- Stage transition: <10ms
- No buffer overflow
- Smooth UI updates

**Red Flags:**
- 🔴 Events backing up → Slow processing
- 🔴 UI updates blocking stream → Bad actor isolation
- 🟡 High memory per event → Optimize data structures

---

### 5. Image Loading (MEDIUM PRIORITY)

**Why:** Photos in meals, recipes, and food items

**Profile:**
- Image decode time
- Thumbnail generation performance
- AsyncImage loading time
- Memory per image

**Expected:**
- Thumbnail generation: <100ms
- Image decode: <200ms
- Memory per full-size image: <10MB
- Thumbnails cached efficiently

**Red Flags:**
- 🔴 Decoding on main thread → Use background
- 🔴 Loading full images when thumbnail needed → Optimize
- 🟡 Not caching decoded images → Add cache layer

---

## Performance Benchmarks

### CPU Performance

| Operation | Target | Warning | Critical |
|-----------|--------|---------|----------|
| App Launch | <2s | 2-4s | >4s |
| View Load | <500ms | 500ms-1s | >1s |
| Scroll Frame Time | <16ms | 16-32ms | >32ms |
| API Response | <1s | 1-3s | >3s |
| Background CPU | <5% | 5-10% | >10% |

### Memory Performance

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| App Launch | <100MB | 100-150MB | >150MB |
| Normal Usage | <150MB | 150-200MB | >200MB |
| With Photos | <300MB | 300-400MB | >400MB |
| Memory Growth/Hour | <10MB | 10-20MB | >20MB |
| Leak Count | 0 | 1-2 | >2 |

### Network Performance

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| API Latency | <500ms | 500ms-1s | >1s |
| Streaming Start | <500ms | 500ms-1s | >1s |
| Image Upload | <3s | 3-5s | >5s |
| Cache Hit Rate | >70% | 50-70% | <50% |
| Retry Rate | <5% | 5-10% | >10% |

### Battery Performance

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Idle CPU | <5% | 5-10% | >10% |
| Normal CPU | <20% | 20-30% | >30% |
| Network/Min | <10 | 10-30 | >30 |
| Location/Min | <1 | 1-5 | >5 |

---

## Post-Profiling Analysis

### 1. Generate Report

Create `PERFORMANCE_PROFILING_RESULTS.md` with:

```markdown
# Performance Profiling Results

**Date:** [Date]
**Device:** [Device]
**iOS Version:** [Version]
**App Version:** [Version]

## Executive Summary
- Overall Performance: [Good/Needs Work/Poor]
- Critical Issues Found: [Count]
- Memory Leaks Found: [Count]
- Recommendations: [Count]

## Time Profiler Results
- Hottest Functions: [List top 5]
- Main Thread Block Time: [Total ms]
- Background Thread Efficiency: [Good/Poor]

## Allocations Results
- Peak Memory: [MB]
- Average Memory: [MB]
- Memory Growth: [MB/hour]
- Concerning Allocations: [List]

## Leaks Results
- Leaks Found: [Count]
- Leaked Objects: [List]
- Retention Cycles: [List]

## Energy Results
- Battery Impact: [Low/Medium/High]
- CPU Usage: [%]
- Network Activity: [Requests/min]

## Recommendations
1. [Fix 1]
2. [Fix 2]
...
```

### 2. Prioritize Fixes

**P0 - Critical (Fix Immediately):**
- Memory leaks
- Main thread blocks >500ms
- Crashes or freezes

**P1 - High (Fix This Sprint):**
- Performance <50% of target
- Memory growth >20MB/hour
- Battery drain in background

**P2 - Medium (Fix Next Sprint):**
- Performance 50-80% of target
- Cache hit rate <70%
- Minor optimizations

**P3 - Low (Nice to Have):**
- Performance 80-100% of target
- Code cleanup
- Micro-optimizations

### 3. Create Fix Tasks

For each issue found, create a task:
```markdown
## Issue: [Description]
- Severity: [P0/P1/P2/P3]
- Found in: [File:Line]
- Impact: [Description]
- Fix: [Proposed solution]
- Effort: [Hours]
```

---

## Common Performance Issues & Fixes

### Issue 1: SwiftUI Body Re-computation

**Symptom:** High CPU, frequent view updates

**Instruments Shows:**
- `body` getter called 100+ times
- View update time >16ms

**Fix:**
```swift
// ❌ BEFORE: Recomputes on every state change
var body: some View {
    VStack {
        expensiveView()  // Recomputed every time
    }
}

// ✅ AFTER: Extract to computed property or separate view
var body: some View {
    VStack {
        ExpensiveView()  // SwiftUI optimizes this
    }
}
```

---

### Issue 2: Image Decoding on Main Thread

**Symptom:** Scroll stuttering, frame drops

**Instruments Shows:**
- `UIImage(data:)` on main thread
- Frame time spikes to 100ms+

**Fix:**
```swift
// ❌ BEFORE: Decodes on main thread
let image = UIImage(data: data)

// ✅ AFTER: Decode on background
Task {
    let image = await Task.detached {
        UIImage(data: data)
    }.value
    await MainActor.run {
        self.image = image
    }
}
```

---

### Issue 3: Core Data on Main Thread

**Symptom:** UI freezes during data operations

**Instruments Shows:**
- `NSManagedObjectContext.fetch()` on main thread
- Main thread blocked 200ms+

**Fix:**
```swift
// ❌ BEFORE: Fetch on main thread
let results = try viewContext.fetch(request)

// ✅ AFTER: Fetch in background
let results = try await performBackgroundTask { context in
    try context.fetch(request)
}
```

---

### Issue 4: Memory Leak - Strong Self Capture

**Symptom:** Memory grows continuously

**Instruments Shows:**
- Leaked closures
- Retain cycle graph

**Fix:**
```swift
// ❌ BEFORE: Strong self capture
Task {
    try await self.fetchData()
}

// ✅ AFTER: Weak self capture
Task { [weak self] in
    try await self?.fetchData()
}
```

---

### Issue 5: Unbounded Cache Growth

**Symptom:** Memory grows over time

**Instruments Shows:**
- Cache dictionary growing
- Memory never released

**Fix:**
```swift
// ❌ BEFORE: No eviction
var cache: [String: Data] = [:]
cache[key] = data  // Grows forever

// ✅ AFTER: LRU cache with size limit
actor CacheManager {
    private var cache: [String: CacheEntry] = [:]
    private let maxSize: Int

    func set(_ key: String, _ data: Data) {
        if cache.count >= maxSize {
            evictOldest()
        }
        cache[key] = CacheEntry(data: data, timestamp: Date())
    }
}
```

---

## Success Criteria

After profiling and fixes, verify:

- [ ] App launch <2s to interactive
- [ ] All views load <500ms
- [ ] Scrolling smooth at 60fps
- [ ] No memory leaks detected
- [ ] Memory stable over 1 hour usage
- [ ] Background CPU <5%
- [ ] Network requests batched efficiently
- [ ] Cache hit rate >70%
- [ ] No main thread blocks >100ms
- [ ] Battery impact: Low rating

---

## Next Steps After Profiling

1. **Document Results** - Create PERFORMANCE_PROFILING_RESULTS.md
2. **Prioritize Fixes** - Sort by P0/P1/P2/P3
3. **Create Fix Plan** - Estimate effort for each fix
4. **Implement Fixes** - Start with P0 critical issues
5. **Re-Profile** - Verify fixes worked
6. **Iterate** - Continue until all targets met

---

**Phase 10 Status:** 📋 GUIDE COMPLETE - Ready for Interactive Profiling

When you run this profiling session, expect to spend:
- Setup: 30 minutes
- Profiling: 2 hours
- Analysis: 1 hour
- **Total: 3.5 hours**

Good luck with the profiling session! 🚀

---

**Generated:** 2025-11-02
**Tools:** Xcode Instruments 16+
**Target:** iOS 26+ | iPhone 17 Pro
