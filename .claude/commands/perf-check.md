---
description: Check implementation for performance, efficiency, memory, concurrency, and energy impact
argument-hint: "[description of what was implemented]"
allowed-tools:
  - Bash
  - FileSystem
---

# Performance & Efficiency Check

Analyze the implementation of "$ARGUMENTS" for performance bottlenecks, inefficiencies, and resource usage issues.

## Performance Analysis Steps

### 1. Main Thread Analysis (iOS)
Check for main thread blocking operations:
- ❌ **Network calls on main thread** - All URLSession, Firebase queries must be async
- ❌ **Heavy computation on main thread** - Image processing, JSON parsing, data transforms
- ❌ **Synchronous file I/O on main thread** - Reading/writing files, UserDefaults heavy operations
- ❌ **Database queries on main thread** - Core Data fetches, Realm queries
- ✅ Verify proper use of `async/await`, `Task`, `@MainActor` annotations
- ✅ Check UI updates are dispatched to main thread when needed

**Red flags:**
- `DispatchQueue.main.sync` (deadlock risk)
- Blocking calls in `viewDidLoad`, `viewWillAppear`
- Heavy work in SwiftUI view body or computed properties

### 2. Concurrency Issues
Analyze threading and concurrency:
- **Data races**: Unsynchronized access to shared mutable state
- **Actor isolation**: Check `@MainActor` usage for UI-bound properties
- **Task management**: Uncontrolled `Task` creation (task explosion)
- **Structured concurrency**: Using `async let` or `TaskGroup` where appropriate
- **Cancellation**: Tasks that don't respect cancellation
- **Firebase listeners**: Not properly detached or causing retain cycles

**Swift specific checks:**
- Proper use of `actor` for thread-safe state
- `@MainActor` on ViewModel or View classes
- No force-unwrapping in async contexts
- Sendable conformance where needed

### 3. Memory Efficiency
Identify memory issues:
- **Retain cycles**: `[weak self]` or `[unowned self]` in closures
- **Large allocations**: Arrays, images, or data held in memory unnecessarily
- **Lazy loading**: Check if large data sets are loaded all at once
- **Image caching**: Proper image downsampling and caching strategy
- **Collection inefficiency**: Using `Array` where `Set` or `Dictionary` would be O(1)
- **Firebase listeners**: Detaching listeners when views disappear
- **Memory leaks in ViewModels**: Strong reference cycles with Combine publishers

**Check for:**
- `deinit` logging to verify objects are released
- Instruments-friendly code (avoid excessive object creation)
- Proper `viewDidDisappear` cleanup

### 4. Network & Firebase Efficiency
Analyze network and backend calls:
- **Over-fetching**: Downloading more data than needed
- **N+1 queries**: Multiple sequential Firebase queries that could be batched
- **Missing pagination**: Loading entire collections instead of paginating
- **Unnecessary real-time listeners**: Using `.addSnapshotListener` when `.getDocuments` would work
- **No offline support**: Not leveraging Firebase offline persistence
- **Large payload**: Sending/receiving unnecessarily large JSON payloads
- **Missing caching**: Re-fetching static data on every load

**Firebase specific:**
- Check for `.whereField().whereField().whereField()` chains (composite indexes needed?)
- Verify indexes exist for complex queries
- Check security rules aren't causing extra reads
- Avoid reading entire documents when only specific fields needed

### 5. Database Query Efficiency
For Firestore/Realtime Database:
- **Compound queries without indexes**: Will fail or be slow
- **Reading entire collections**: Use `.limit()` appropriately
- **Listening to large data sets**: Should use queries with filters
- **No pagination**: Implement cursor-based pagination with `startAfter()`
- **Denormalization**: Check if data structure requires excessive joins

### 6. UI Rendering Performance
Check SwiftUI/UIKit performance:
- **Unnecessary view updates**: Overuse of `@State`, `@Published` causing re-renders
- **Heavy view hierarchies**: Too many nested views or conditionals in body
- **Missing `.equatable()`**: Views re-rendering when data hasn't changed
- **Image rendering**: Large images not downsampled before display
- **List performance**: Missing `id` in `ForEach`, inefficient list updates
- **Animations**: Heavy animations or too many simultaneous animations

**SwiftUI checks:**
- Heavy computation in `var body` (should be in computed properties with caching)
- Missing `@State` or `@Published` where needed (not triggering updates)
- Excessive use of `.task` or `.onAppear` modifiers

### 7. Energy Efficiency
Identify battery drains:
- **Constant location updates**: Using `.requestAlwaysAuthorization` unnecessarily
- **Background processing**: Unnecessary background tasks
- **Timers**: Frequent timers that keep CPU active
- **Network polling**: Repeatedly checking for updates instead of push
- **Screen brightness**: Keeping screen on unnecessarily
- **Firebase listeners**: Too many active real-time listeners

### 8. TypeScript/Firebase Functions Performance
For backend code:
- **Cold start issues**: Large dependencies in Cloud Functions
- **Unoptimized queries**: Missing indexes, scanning entire collections
- **Synchronous operations**: Not using `Promise.all()` for parallel ops
- **Memory limits**: Functions exceeding allocated memory
- **Timeout risks**: Long-running operations without chunking
- **No batching**: Sequential writes that could be batched

### 9. Algorithm Complexity
Check algorithmic efficiency:
- **O(n²) operations**: Nested loops that could be optimized
- **Unnecessary sorting**: Sorting when not needed
- **Linear search**: Using `.first { }` on large arrays (use Dictionary)
- **String concatenation**: Building strings in loops (use String interpolation or StringBuilder)
- **Duplicate work**: Recalculating same values repeatedly

## Performance Report Format

Provide a detailed report with:

### 🎯 Executive Summary
- Overall performance grade (A/B/C/D/F)
- Critical issues count
- Estimated user impact (battery drain, sluggishness, crashes)

### ⚠️ Critical Issues
List blocking performance problems with:
- **Issue**: Specific problem
- **Location**: File and line number
- **Impact**: Main thread block, memory leak, battery drain, etc.
- **Fix**: Concrete solution

### 📊 Performance Metrics
Estimate:
- Main thread blocking time (ms)
- Memory overhead (MB)
- Network calls count
- Database reads/writes
- Energy impact (Low/Medium/High)

### ✅ What's Done Well
Highlight good practices already in place

### 🔧 Optimization Recommendations
Prioritized list:
1. **High priority**: Must fix (crashes, main thread blocks)
2. **Medium priority**: Should fix (inefficiencies, memory leaks)
3. **Low priority**: Nice to have (micro-optimizations)

### 📝 Code Examples
Show before/after code snippets for top 3 issues

## Check These Files Specifically
- ViewModels: Threading, memory leaks, over-publishing
- Services/Managers: Singletons with proper lifecycle
- Firebase queries: Indexes, pagination, over-fetching
- Image handling: Downsampling, caching
- List/Collection views: Rendering performance

Be specific about file names, line numbers, and provide actual code examples of issues found.
