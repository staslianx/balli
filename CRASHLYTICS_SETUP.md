# Firebase Crashlytics Setup Guide

## Status: Code Changes Complete ✅

The code has been updated to use Crashlytics:
- ✅ `AppDelegate.swift` now imports `FirebaseCrashlytics`
- ✅ `Crashlytics.crashlytics()` is called after `FirebaseApp.configure()`

## What You Need to Do

### Step 1: Add FirebaseCrashlytics Package Dependency

Since the project uses Swift Package Manager and already has `firebase-ios-sdk` added, you just need to add the Crashlytics product:

**Option A: Using Xcode (Recommended - 2 minutes)**

1. Open `balli.xcodeproj` in Xcode
2. Select the project in the navigator (top-level "balli")
3. Select the "balli" target (under TARGETS)
4. Go to the "General" tab
5. Scroll down to "Frameworks, Libraries, and Embedded Content"
6. Click the "+" button
7. In the dialog, find and select `FirebaseCrashlytics` from the firebase-ios-sdk package
8. Click "Add"

**Option B: Using Package Dependencies Tab**

1. Open `balli.xcodeproj` in Xcode
2. Select the project in the navigator
3. Click on "Package Dependencies" tab
4. You'll see `firebase-ios-sdk` already listed
5. Select the "balli" target in the sidebar
6. Under "Frameworks and Libraries", click "+"
7. Find `FirebaseCrashlytics` and add it

###Step 2: Build the Project

```bash
xcodebuild -scheme balli -sdk iphonesimulator build
```

Or just press ⌘B in Xcode.

The build should now succeed!

### Step 3: Add dSYM Upload Script (Required for Crash Symbolication)

This script uploads debug symbols so crash reports show function names instead of memory addresses.

1. Open `balli.xcodeproj` in Xcode
2. Select the project → Select "balli" target
3. Go to "Build Phases" tab
4. Click "+" → "New Run Script Phase"
5. Rename it to "Upload dSYMs to Crashlytics"
6. Drag it to run AFTER "Embed Frameworks" but BEFORE "Copy Files"
7. Paste this script:

```bash
# Upload dSYMs to Firebase Crashlytics
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

8. Check "Based on dependency analysis" (for faster builds)

### Step 4: Verify Crashlytics is Working

**Test Crash:**

Add this test code temporarily to verify Crashlytics is working:

```swift
// In any view, add a button:
Button("Test Crash") {
    fatalError("Test crash for Crashlytics")
}
```

**Check Firebase Console:**

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your "balli" project
3. Click "Crashlytics" in the left sidebar
4. You should see the initialization message after first launch
5. After forcing a crash (and restarting app), you'll see the crash report within ~5 minutes

### Step 5: Remove Test Crash Code

Once verified, remove the test crash button!

---

## What Crashlytics Will Give You

✅ **Automatic Crash Detection:**
- Every crash is captured automatically
- No code changes needed beyond init

✅ **Detailed Crash Reports:**
- Stack traces with function names (thanks to dSYMs)
- Device info (model, iOS version)
- Memory/disk state at crash time

✅ **Crash Analytics:**
- See which crashes affect most users
- Track crash-free users percentage
- Get notified of new crashes

✅ **Free Forever:**
- Firebase Crashlytics is completely free
- Unlimited crash reports
- No usage limits

---

## Troubleshooting

### Build Error: "Unable to find module dependency: 'FirebaseCrashlytics'"

**Solution:** You need to complete Step 1 above to add the package dependency.

### dSYM Upload Script Fails

**Error:** `run: No such file or directory`

**Solution:** Make sure the script path matches your package checkout location. The provided path should work if you're using SPM (Swift Package Manager).

### Crashes Not Showing in Console

**Possible causes:**
1. Wait 5 minutes after crash (processing time)
2. Make sure you restarted the app after crash (crashes are sent on next launch)
3. Check Firebase project is correct in GoogleService-Info.plist
4. Verify network connectivity

### "Firebase not configured" Error

**Solution:** This shouldn't happen since `FirebaseApp.configure()` is already in `AppDelegate.swift`, but if it does:
- Verify `GoogleService-Info.plist` is in the project
- Clean build folder (⇧⌘K) and rebuild

---

## Next Steps After Setup

1. **Remove any debug crash test code**
2. **Deploy to Dilara's device** (TestFlight or direct install)
3. **Monitor Firebase Console** for the first week
4. **Fix critical crashes** within 24 hours
5. **Review weekly** crash-free users percentage

---

## Firebase Console Quick Links

- **Crashlytics Dashboard:** `console.firebase.google.com/project/YOUR_PROJECT/crashlytics`
- **View All Crashes:** Click any crash to see stack trace
- **Set Up Alerts:** Crashlytics → Settings → Email notifications

---

## Success Criteria

✅ Build succeeds without errors
✅ App launches and logs "📊 Crashlytics initialized for crash reporting"
✅ Firebase Console shows Crashlytics is enabled
✅ Test crash appears in Firebase Console

**Once all checkboxes above are ✅, Crashlytics is production-ready!** 🎉

