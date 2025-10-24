---
description: Verify all data synchronization happens correctly before main screen loads
argument-hint: "[optional: specific sync area to focus on]"
allowed-tools:
  - Bash
  - FileSystem
---

# Sync Expert Analysis

Verify that all necessary data synchronization completes successfully before the user reaches the main screen. Analyze "$ARGUMENTS" or perform full sync flow audit.

## Critical Sync Requirements

**The user should NEVER see:**
- Empty states that suddenly populate
- Loading spinners after reaching main screen
- Stale or missing data
- Authentication errors after login appears successful
- Half-loaded UI states

## Sync Analysis Steps

### 1. App Launch Sequence
Trace the complete launch flow:

**iOS Side:**
- `AppDelegate` / `@main App` initialization
- What happens in `application(_:didFinishLaunchingWithOptions:)`
- SceneDelegate setup or SwiftUI App initialization
- Root view determination logic

**Key questions:**
- Is there a splash/loading screen while sync happens?
- What determines when to show main screen vs login screen?
- Are there race conditions between auth check and data fetch?

**Red flags:**
- No loading state during initial sync
- Immediate navigation to main screen without awaiting data
- Auth state checked without waiting for completion

### 2. Firebase Authentication Sync
Check authentication flow completion:
```swift
// What should happen
Firebase.Auth.auth().addStateDidChangeListener { auth, user in
    // Wait for this to complete before proceeding
}
```

**Verify:**
- ✅ Auth state listener is set up BEFORE showing any UI
- ✅ Anonymous auth (if used) completes before data access
- ✅ User token is refreshed if expired
- ✅ Custom claims are loaded if using role-based access
- ✅ Auth persistence is configured correctly
- ❌ No race condition: UI appears before `user` is available
- ❌ No multiple auth checks causing redundant calls

**Check these files:**
- AppDelegate, SceneDelegate, or App struct
- AuthManager/AuthService singleton
- Root view coordinator logic

### 3. Firestore Initial Data Sync
Verify critical data loads before main screen:

**Essential data that MUST be synced:**
- User profile/settings
- User preferences (theme, language, etc.)
- Initial content for home screen
- Any cached/offline data rehydration
- Remote Config values
- Feature flags

**Firestore specific checks:**
```swift
// Bad: No await, data might not be ready
func loadUserProfile() {
    db.collection("users").document(userId).getDocument { snapshot, error in
        // UI might already be shown
    }
}

// Good: Async/await ensures completion
func loadUserProfile() async throws -> UserProfile {
    let snapshot = try await db.collection("users").document(userId).getDocument()
    return try snapshot.data(as: UserProfile.self)
}
```

**Verify:**
- ✅ Using `async/await` or completion handlers properly awaited
- ✅ Sequential dependencies handled (auth → user profile → preferences)
- ✅ Parallel fetching where possible (using `async let` or `TaskGroup`)
- ✅ Offline persistence enabled: `Firestore.firestore().settings.isPersistenceEnabled = true`
- ✅ Initial data fetched from cache first, then network
- ❌ No fire-and-forget queries before main screen
- ❌ No assuming data exists without checking

### 4. Synchronization Coordinator
Look for centralized sync management:

**Should have:**
- A dedicated sync manager/coordinator class
- Clear sync states: `.notStarted`, `.syncing`, `.completed`, `.failed`
- Observable sync progress for UI
- Proper error handling and retry logic

**Example structure:**
```swift
class SyncManager: ObservableObject {
    @Published var syncState: SyncState = .notStarted

    func performInitialSync() async throws {
        // 1. Auth check
        // 2. User profile
        // 3. Critical app data
        // 4. Cache warming
    }
}
```

**Check for:**
- Is there a single source of truth for sync state?
- Can sync be triggered again if it fails?
- Is sync progress communicated to UI?
- Are there proper timeouts (don't wait forever)?

### 5. Loading/Splash Screen Implementation
Verify proper loading state management:

**iOS Side:**
- Is there a dedicated loading/splash view?
- Does it remain visible until sync completes?
- Is there a progress indicator or animation?
- Does it handle errors gracefully?

**Check transition logic:**
```swift
// Bad: Immediate transition
ContentView()

// Good: Conditional based on sync state
if syncManager.syncState == .completed {
    MainTabView()
} else if syncManager.syncState == .failed {
    ErrorView()
} else {
    LoadingView()
}
```

**Verify:**
- ✅ Loading view shows until `syncState == .completed`
- ✅ Minimum display time to avoid flicker (optional, 1-2 seconds)
- ✅ Maximum timeout (e.g., 30 seconds, then show error)
- ✅ User can retry if sync fails
- ❌ No premature dismissal of loading screen
- ❌ No "blank white screen" phase

### 6. Offline & Edge Cases
Test sync behavior in various scenarios:

**No network connection:**
- Does app load from cached data?
- Is user informed about offline state?
- Can they access previously loaded content?
- What happens on first launch with no network?

**Slow network:**
- Is there a reasonable timeout (10-30 seconds)?
- Does user see progress indication?
- Are critical queries prioritized?

**Partial sync failure:**
- If user profile loads but preferences fail, what happens?
- Are non-critical failures handled gracefully?
- Is there partial UI available?

**Auth edge cases:**
- User token expired during sync
- User logged out on another device
- Firebase auth state changes mid-sync

### 7. Data Dependencies & Order
Map out sync dependencies:

**Example dependency chain:**
```
1. Firebase Auth ✅
   ↓
2. User Profile (needs userId from auth) ✅
   ↓
3. User Preferences (needs profile) ✅
   ↓
4. Home Feed Data (needs preferences for filtering) ✅
   ↓
5. Show Main Screen ✅
```

**Verify:**
- Dependencies are loaded in correct order
- No circular dependencies
- Parallel loading where possible (independent data)
- Critical vs. nice-to-have data separated

**Example optimization:**
```swift
// Sequential (slow)
let profile = try await loadProfile()
let settings = try await loadSettings()
let feed = try await loadFeed()

// Parallel (faster) - if independent
async let profile = loadProfile()
async let settings = loadSettings()
try await (profile, settings)
let feed = try await loadFeed() // Depends on settings
```

### 8. Firebase Backend Sync State
Check server-side readiness:

**Firestore Security Rules:**
- Do rules allow reading user data immediately after auth?
- Are there any permission delays or race conditions?
- Check for rules that might block initial queries

**Cloud Functions:**
- Any onCreate triggers that need to complete first?
- User document creation race conditions?
- Profile initialization delays?

**Firebase Remote Config:**
- Is config fetched and activated before main screen?
- Are default values set for offline scenario?
- Check `activate()` is called, not just `fetch()`

**Firebase Cloud Messaging (if used):**
- Token registration happens but doesn't block main screen
- Proper permission handling

### 9. Performance of Initial Sync
Measure sync timing:

**Acceptable benchmarks:**
- Auth check: < 500ms
- User profile fetch: < 1 second
- Total initial sync: < 3-5 seconds
- Maximum timeout: 30 seconds

**Check for:**
- ❌ Serial queries that could be parallel
- ❌ Fetching too much data on initial load
- ❌ No caching strategy
- ❌ Large images loading during sync
- ❌ Unnecessary computation before showing UI

**Optimization opportunities:**
- Fetch minimal data first, lazy load rest
- Use Firestore cache for instant second launch
- Defer non-critical data to post-main-screen
- Implement progressive loading

### 10. Error Handling & Recovery
Verify robust error handling:

**For each sync operation:**
- What happens if it fails?
- Is error shown to user?
- Can user retry?
- Is there a fallback behavior?
- Are errors logged for debugging?

**User experience during errors:**
- Clear error message (not technical Firebase errors)
- Retry button
- Option to continue with cached data
- Contact support option for persistent failures

## Sync Report Format

Provide a comprehensive report:

### 🎯 Sync Status Overview
- **Overall verdict**: ✅ Properly synced / ⚠️ Needs fixes / ❌ Critical issues
- **User experience**: Good / Acceptable / Poor
- **Sync time estimate**: X seconds

### 🔄 Sync Flow Diagram
Visual representation:
```
App Launch
    ↓
[Loading Screen] ← Shows immediately
    ↓
Firebase Auth Check (500ms)
    ↓
User Profile Fetch (1s) ← May fail here
    ↓
Settings Sync (500ms)
    ↓
[Main Screen] ← Should appear here
```

### ⚠️ Critical Sync Issues
List blocking problems:
1. **Issue**: [specific problem]
   - **File**: [location]
   - **Impact**: User sees empty state / data race / crash
   - **Fix**: [concrete solution]

### 📋 Sync Checklist
- [ ] Auth completes before any data fetch
- [ ] Loading screen visible during sync
- [ ] All critical data loaded before main screen
- [ ] Offline scenario handled
- [ ] Sync failure shows error + retry
- [ ] Performance < 5 seconds typical case
- [ ] No race conditions
- [ ] Proper timeout handling

### 🔧 Recommended Sync Architecture

**If missing centralized sync:**
```swift
// Create SyncCoordinator
class SyncCoordinator: ObservableObject {
    @Published var state: SyncState = .idle

    enum SyncState {
        case idle
        case syncing(progress: Double)
        case completed
        case failed(Error)
    }

    func performInitialSync() async {
        state = .syncing(progress: 0.0)

        do {
            // Auth
            try await authManager.waitForAuthState()
            state = .syncing(progress: 0.3)

            // User data
            try await userManager.loadProfile()
            state = .syncing(progress: 0.6)

            // App data
            try await dataManager.loadEssentialData()
            state = .syncing(progress: 1.0)

            state = .completed
        } catch {
            state = .failed(error)
        }
    }
}
```

### 📝 Files to Review
List specific files that handle sync:
- [File]: [what it does in sync process]

### 🚀 Quick Wins
Immediate improvements:
1. [Specific optimization]
2. [Another fix]

### 💡 Long-term Improvements
- Implement proper sync coordinator
- Add offline-first architecture
- Progressive loading strategy
- Better error recovery

## Specific Checks

**Look for these patterns:**

**Bad:**
```swift
// Showing main screen immediately
var body: some View {
    MainTabView()
        .onAppear {
            // Too late - already visible!
            loadData()
        }
}
```

**Good:**
```swift
var body: some View {
    if syncManager.isReady {
        MainTabView()
    } else {
        LoadingView()
            .task {
                await syncManager.performInitialSync()
            }
    }
}
```

Be extremely specific about file paths, function names, and provide code examples of issues and fixes.
