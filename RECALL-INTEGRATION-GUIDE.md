# Cross-Conversation Memory (Recall) - Integration Guide

This guide walks you through the manual steps to complete the Recall feature integration.

## ✅ Prerequisites

All code implementation is complete. You just need to:
1. Add SQLite.swift dependency
2. Wire FTS5Manager into app launch
3. Deploy backend function
4. Test the integration

---

## Step 1: Add SQLite.swift Package Dependency

### Via Xcode (Recommended):

1. **Open Xcode** and load the `balli.xcodeproj` project

2. **Add Package Dependency**:
   - Go to `File` → `Add Package Dependencies...`
   - In the search field, paste: `https://github.com/stephencelis/SQLite.swift`
   - Click "Add Package"

3. **Configure Package**:
   - **Dependency Rule**: "Up to Next Major Version"
   - **Version**: `0.15.3` (or latest)
   - Click "Add Package"

4. **Select Target**:
   - Check the box next to `balli` target
   - Click "Add Package"

5. **Verify Installation**:
   - In Project Navigator, expand "Package Dependencies"
   - You should see "SQLite" listed

### Alternative: Via Package.swift (if using SPM directly):

If you're managing dependencies via `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3")
],
targets: [
    .target(
        name: "balli",
        dependencies: [
            .product(name: "SQLite", package: "SQLite.swift")
        ]
    )
]
```

---

## Step 2: Wire FTS5Manager into App Launch

### Option A: Add to balliApp.swift (Recommended)

Add FTS5 initialization in the `configureApp()` method:

**File**: `balli/App/balliApp.swift`

**Add after line 99** (after HealthKit permissions request):

```swift
// Initialize FTS5 Manager for cross-conversation memory (recall)
Task.detached(priority: .background) {
    do {
        // Initialize FTS5Manager
        let fts5Manager = try FTS5Manager()
        logger.info("✅ FTS5Manager initialized successfully")

        // Run one-time migration to index existing completed sessions
        let container = ResearchSessionModelContainer.shared.container
        let storageActor = SessionStorageActor(
            modelContainer: container,
            fts5Manager: fts5Manager
        )

        await AppLifecycleCoordinator.shared.migrateToFTS5IfNeeded(
            fts5Manager: fts5Manager,
            storageActor: storageActor
        )

        logger.info("✅ FTS5 migration check complete")
    } catch {
        logger.error("❌ FTS5 initialization failed: \(error.localizedDescription)")
        // Non-fatal - recall feature won't work but app continues
    }
}
```

**Full context** (what the section should look like):

```swift
// Request HealthKit permissions upfront on app launch
// This prevents infinite loops from repeated per-type requests
Task {
    do {
        try await healthKitPermissions.requestAllPermissions()
    } catch {
        logger.error("HealthKit authorization failed: \(error.localizedDescription)")
        // Non-fatal - app continues to work with limited functionality
    }
}

// Initialize FTS5 Manager for cross-conversation memory (recall)
Task.detached(priority: .background) {
    do {
        // Initialize FTS5Manager
        let fts5Manager = try FTS5Manager()
        logger.info("✅ FTS5Manager initialized successfully")

        // Run one-time migration to index existing completed sessions
        let container = ResearchSessionModelContainer.shared.container
        let storageActor = SessionStorageActor(
            modelContainer: container,
            fts5Manager: fts5Manager
        )

        await AppLifecycleCoordinator.shared.migrateToFTS5IfNeeded(
            fts5Manager: fts5Manager,
            storageActor: storageActor
        )

        logger.info("✅ FTS5 migration check complete")
    } catch {
        logger.error("❌ FTS5 initialization failed: \(error.localizedDescription)")
        // Non-fatal - recall feature won't work but app continues
    }
}
```

### Option B: Add to AppDelegate (Alternative)

If you prefer centralizing startup logic in AppDelegate:

**File**: `balli/App/AppDelegate.swift`

Add to `application(_:didFinishLaunchingWithOptions:)`:

```swift
// Initialize FTS5 for recall search
Task.detached(priority: .background) {
    do {
        let fts5Manager = try FTS5Manager()
        let container = ResearchSessionModelContainer.shared.container
        let storageActor = SessionStorageActor(
            modelContainer: container,
            fts5Manager: fts5Manager
        )

        await AppLifecycleCoordinator.shared.migrateToFTS5IfNeeded(
            fts5Manager: fts5Manager,
            storageActor: storageActor
        )
    } catch {
        print("FTS5 initialization failed: \(error)")
    }
}
```

---

## Step 3: Deploy Backend Functions

### 3.1 Build Backend Functions

```bash
cd /Users/serhat/SW/balli/functions
npm install
npm run build
```

**Expected output**:
```
✔  functions: Finished running predeploy script.
i  functions: preparing codebase for deployment
✔  functions: build complete
```

### 3.2 Deploy to Firebase

Deploy only the new `generateSessionMetadata` function:

```bash
firebase deploy --only functions:generateSessionMetadata
```

**Expected output**:
```
=== Deploying to 'your-project'...

i  deploying functions
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
i  functions: preparing codebase for deployment
✔  functions: codebase prepared for deployment
i  functions: deploying function generateSessionMetadata
✔  functions[generateSessionMetadata(us-central1)]: Successful create operation.

✔  Deploy complete!
```

### 3.3 Verify Deployment

Check that the function is live:

```bash
firebase functions:list
```

You should see `generateSessionMetadata` in the list with status `ACTIVE`.

---

## Step 4: Build and Test iOS App

### 4.1 Clean Build

```bash
cd /Users/serhat/SW/balli
xcodebuild clean -scheme balli
```

### 4.2 Build Project

```bash
xcodebuild -scheme balli -sdk iphonesimulator -configuration Debug build
```

**Expected**: Build should succeed with no errors.

### 4.3 Run Tests

```bash
xcodebuild test -scheme balli -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Expected**: All tests pass, including the new `FTS5ManagerTests`.

### 4.4 Manual Testing Checklist

Open the app in Xcode (`⌘R`) and test these scenarios:

#### ✅ Test 1: Complete a Research Session
1. Open the Research tab
2. Ask a question: "Tip 1 diyabet nedir?"
3. Wait for the answer
4. Say "teşekkürler" to end the session
5. **Verify**: Session ends and metadata is generated

#### ✅ Test 2: Recall from Past Session
1. Open a new research query
2. Ask: "Tip 1 diyabet neydi?" (past tense)
3. **Verify**:
   - Warm amber "Hafıza" badge appears
   - System searches past sessions
   - Returns answer from previous session

#### ✅ Test 3: No Recall Match
1. Ask: "Daha önce kanser araştırdık mı?"
2. **Verify**:
   - "Hafıza" badge appears
   - Response: "Bu konuda daha önce bir araştırma kaydı bulamadım. Şimdi araştırayım mı?"

#### ✅ Test 4: Multiple Recall Matches
1. Complete 2 sessions about diabetes (different topics)
2. Ask ambiguously: "Diyabet hakkında ne konuşmuştuk?"
3. **Verify**:
   - Shows list of matching sessions with titles and dates
   - Asks which one you're referring to

#### ✅ Test 5: FTS5 Search Quality
1. Complete a session about "Dawn phenomenon"
2. Ask: "dawn neydi?" (Turkish past tense + English term)
3. **Verify**: Correctly finds the session despite mixed language

#### ✅ Test 6: Inactivity Timeout
1. Start a research session
2. Wait 30+ minutes without interaction
3. **Verify**: Session auto-ends and metadata is saved

---

## Step 5: Console Monitoring

Watch Console.app logs during testing:

```bash
# Filter for relevant subsystems
log stream --predicate 'subsystem == "com.anaxoniclabs.balli" && category IN {"Research", "RecallSearch", "FTS5"}'
```

**Expected log messages**:

```
✅ FTS5Manager initialized successfully
✅ FTS5 migration check complete
📚 Handling recall request: tip 1 diyabet neydi?
🔍 Searching sessions via FTS5 for: tip 1 diyabet
✅ Found 1 sessions from FTS5 search
📚 Displayed LLM-generated recall answer from: Tip 1 Diyabet Araştırması
```

---

## Troubleshooting

### Error: "Unable to find module dependency: 'SQLite'"

**Solution**: SQLite.swift package not added. Go back to Step 1.

### Error: FTS5 initialization failed

**Possible causes**:
1. Database permission issues
2. Invalid database path

**Solution**: Check logs for specific error. FTS5 database is stored in app's Documents directory.

### Error: Backend function not found (404)

**Solution**:
1. Verify deployment: `firebase functions:list`
2. Check function URL in logs
3. Redeploy: `firebase deploy --only functions:generateSessionMetadata`

### Recall not triggering

**Possible causes**:
1. Query doesn't match past-tense patterns
2. No completed sessions with metadata

**Debug**:
- Check `shouldAttemptRecall()` patterns in `MedicalResearchViewModel.swift:1303`
- Verify sessions have `status = "complete"` in database
- Check UserDefaults key `HasMigratedToFTS5` is `true`

### Tests failing

**Solution**:
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clean build folder
xcodebuild clean -scheme balli

# Rebuild
xcodebuild -scheme balli build
```

---

## Performance Validation

After integration, verify performance metrics:

- **FTS5 Search**: Should complete in <1 second (check logs)
- **Metadata Generation**: Should complete in 2-5 seconds
- **Session Ending**: Should be instant (no blocking)
- **App Launch**: FTS5 init should not block (runs on background queue)

---

## Rollback Plan

If you need to temporarily disable recall:

1. **Comment out FTS5 initialization** in `balliApp.swift`:
   ```swift
   // Task.detached(priority: .background) {
   //     let fts5Manager = try FTS5Manager()
   //     ...
   // }
   ```

2. **Recall detection will gracefully fail** - app continues to work normally without recall feature

---

## Success Criteria

You've successfully integrated the Recall feature when:

- ✅ App builds without errors
- ✅ All tests pass (including `FTS5ManagerTests`)
- ✅ Past-tense queries trigger recall search
- ✅ "Hafıza" badge appears on recall answers
- ✅ Backend generates session metadata
- ✅ FTS5 search returns relevant sessions in <1 second
- ✅ No crashes or data races in production

---

## Next Steps After Integration

1. **Monitor Production**: Watch crash reports and logs for FTS5-related issues
2. **Collect Feedback**: See if users understand the recall feature
3. **Tune Detection**: Adjust past-tense patterns if false positives/negatives occur
4. **Optimize**: If search gets slow with 1000+ sessions, consider pruning old data

---

## Support

If you encounter issues during integration:

1. Check logs in Console.app
2. Review error messages in Xcode
3. Verify all files were modified correctly (see implementation summary)
4. Test on a clean simulator to rule out state issues

---

**Last Updated**: 2025-10-22
**Implementation Version**: 1.0
**Status**: Ready for Integration ✅
