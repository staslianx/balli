# Add dSYM Upload Script - Step by Step

## What You're About to Do (3 minutes)

You'll add a build script that automatically uploads debug symbols to Firebase Crashlytics. This makes crash reports readable.

---

## Step-by-Step Instructions

### 1. Open Project in Xcode
```bash
# Open the project
open /Users/serhat/SW/balli/balli.xcodeproj
```

### 2. Navigate to Build Phases

1. In Xcode's left sidebar, click on **"balli"** (the project, top item with blue icon)
2. In the main editor area, select the **"balli"** target (under TARGETS, not PROJECT)
3. Click the **"Build Phases"** tab at the top

### 3. Add New Run Script Phase

1. Click the **"+"** button in the top-left of the Build Phases panel
2. Select **"New Run Script Phase"**
3. A new phase called "Run Script" appears at the bottom

### 4. Configure the Script

1. **Rename it:** Double-click "Run Script" and rename to:
   ```
   Upload dSYMs to Crashlytics
   ```

2. **Add the script:** In the text box below "Shell /bin/sh", paste this EXACT line:
   ```bash
   "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
   ```

3. **Check the optimization box:**
   - ✅ Check "Based on dependency analysis"
   - This makes builds faster

4. **Leave unchecked:**
   - ⬜ "Show environment variables in build log"
   - ⬜ "Run script: For install builds only"

### 5. Position the Script (Important!)

The script should run AFTER frameworks are embedded:

1. Look for a phase called **"Embed Frameworks"** or **"Embed Libraries"**
2. **Drag** your "Upload dSYMs to Crashlytics" phase to position it:
   - AFTER "Embed Frameworks"
   - BEFORE "Copy Files" (if it exists)

Typical order should be:
```
✓ Compile Sources
✓ Link Binary with Libraries
✓ Embed Frameworks
✓ Upload dSYMs to Crashlytics  ← Your new script
✓ Copy Files (if exists)
```

### 6. Save and Test

1. Press **⌘S** to save
2. Build the project: **⌘B**
3. Watch the build output - you should see no errors

---

## Verification

After building, the script runs automatically. Check for errors:

**Good output (success):**
```
Upload dSYMs to Crashlytics
Command PhaseScriptExecution succeeded
```

**If you see an error:**
```
run: No such file or directory
```

**Solution:** The path is wrong. Try this alternative script:
```bash
# Alternative script if first one fails
if [ -f "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run" ]; then
  "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
else
  echo "Crashlytics run script not found - dSYMs not uploaded"
fi
```

---

## What This Does

**Before build completes:**
1. Xcode generates `.dSYM` files (debug symbol maps)
2. Script uploads them to Firebase
3. Firebase matches crash addresses to function names

**Result:** Crash reports show readable stack traces!

**Before dSYM upload:**
```
0x00000001081a4c20 + 0
0x00000001081a5d40 + 128
```

**After dSYM upload:**
```
RecipeViewModel.generateRecipe() line 42
RecipeGenerationCoordinator.start() line 156
```

---

## Testing the Script

Want to verify it works?

```bash
# Build for device (not simulator) to generate dSYMs
xcodebuild -scheme balli -sdk iphoneos -configuration Debug build

# Check build log for:
# "Upload dSYMs to Crashlytics"
# "Command PhaseScriptExecution succeeded"
```

**Note:** The script only runs for device builds (not simulator), so don't worry if you don't see it when building for simulator.

---

## Troubleshooting

### Script not running?
- Make sure it's positioned correctly (after Embed Frameworks)
- Verify "Based on dependency analysis" is checked
- Try building for device (not simulator)

### "Permission denied" error?
```bash
# The script should be executable by default, but if not:
chmod +x "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

### Still not working?
The script only matters when you archive for release. For development, it's optional. You can still debug crashes using Xcode's crash logs.

---

## Success Criteria

✅ Script added to Build Phases
✅ Named "Upload dSYMs to Crashlytics"
✅ Positioned after "Embed Frameworks"
✅ Build succeeds without errors
✅ Ready for production crash reporting!

---

**Time to complete:** 3 minutes
**Difficulty:** Easy
**Importance:** High for production

Done? Mark this complete and move on to testing! 🚀
