---
description: Systematically fix all build warnings with code-quality-manager agent
disable-model-invocation: false
---

# Warning Elimination Workflow

Fix all build warnings in the codebase: $ARGUMENTS

## Phase 1: Warning Analysis & Categorization

1. **Build and Capture Warnings**
   - Run: `xcodebuild -project balli.xcodeproj -scheme balli -sdk iphonesimulator -derivedDataPath ./build 2>&1 | grep "warning:" > warnings.txt`
   - Parse and categorize all warnings by type:
     - Swift 6 Concurrency violations
     - Deprecated API usage
     - Code quality issues
     - Redundant/unreachable code
   
2. **Create Warning Report**
   - Total count by category
   - Severity assessment (critical vs. minor)
   - Files with most warnings
   - Recommended fix order (most critical first)

3. **Present Initial Analysis**
   - Show categorized warning breakdown
   - Explain impact of each category
   - Propose fix strategy and order
   - **WAIT FOR USER VERIFICATION** before proceeding

## Phase 2: Systematic Fix Plan

1. **Priority Order (Fix in this sequence):**
   - **Priority 1:** Swift 6 Concurrency (data race risks)
   - **Priority 2:** Deprecated APIs (future compatibility)
   - **Priority 3:** Code quality (unused vars, unreachable code)
   - **Priority 4:** Redundant code (cleanup)

2. **Batch Strategy:**
   - Group warnings by file and category
   - Fix related warnings together
   - Never fix more than 10 files at once
   - Build verification after each batch

3. **Present Fix Plan**
   - Show batches and order
   - Estimated files to modify per batch
   - **ASK FOR APPROVAL** to proceed with code-quality-manager agent

## Phase 3: Execute Fixes (Only After Approval)

1. **Invoke code-quality-manager Agent**
   - Share complete warning analysis
   - Provide CLAUDE.md standards for reference
   - Execute fixes in priority order

2. **For Each Batch:**
   - Fix warnings in current batch
   - Follow CLAUDE.md standards strictly:
     - Maintain Swift 6 concurrency compliance
     - Use proper `@MainActor` annotations
     - Replace deprecated APIs with modern alternatives
     - Remove dead code safely
     - Keep functions under 50 lines
     - No force unwraps introduced

3. **Build Verification After Each Batch:**
   ```bash
   xcodebuild -project balli.xcodeproj -scheme balli -sdk iphonesimulator -derivedDataPath ./build
   ```
   - Verify zero new warnings introduced
   - Verify zero new errors introduced
   - Count remaining warnings

## Phase 4: Testing & Validation

1. **Run Full Test Suite:**
   - Execute: `⌘U` or `xcodebuild test -scheme balli`
   - Verify all tests still pass
   - No functionality broken

2. **Build Clean Check:**
   - Clean build folder
   - Full rebuild: `⌘B`
   - Verify warning count reduction
   - Ensure no new issues

## Phase 5: Progress Reporting

After each batch, provide:
- ✅ Warnings fixed in this batch: [count]
- 📊 Total warnings remaining: [count]
- 📁 Files modified: [list]
- 🔧 Fix types applied: [categories]
- ⚠️ Any issues encountered
- 🎯 Next batch preview

## Phase 6: Final Verification

1. **Warning Count Verification:**
   ```bash
   xcodebuild -project balli.xcodeproj -scheme balli -sdk iphonesimulator -derivedDataPath ./build 2>&1 | grep -c "warning:"
   ```
   - Target: 0 warnings
   - Acceptable: < 10 warnings (document why remaining ones can't be fixed)

2. **Comprehensive Testing:**
   - All unit tests pass
   - SwiftUI previews work
   - App builds and runs on simulator
   - App builds and runs on physical device

3. **Final Report:**
   ```
   ## Warning Elimination Summary
   
   **Starting State:**
   - Total warnings: 229
   
   **Fixes Applied:**
   - Swift 6 Concurrency: [count] fixed
   - Deprecated APIs: [count] fixed
   - Code Quality: [count] fixed
   - Redundant Code: [count] fixed
   
   **Final State:**
   - Total warnings: [count]
   - Warnings eliminated: [percentage]%
   
   **Files Modified:** [count]
   
   **Remaining Warnings (if any):**
   [List with explanation why they can't be fixed]
   
   **Testing Status:**
   - ✅ All tests passing
   - ✅ Clean build
   - ✅ App runs successfully
   ```

## Important Constraints

- **NEVER fix more than 10 files in a single batch**
- **ALWAYS build after each batch** - stop if build fails
- **ALWAYS verify tests** after significant changes
- **NEVER introduce force unwraps** or unsafe code
- **ALWAYS follow CLAUDE.md** standards
- **PRESERVE functionality** - if unsure, ask before changing

## Swift 6 Concurrency Fix Patterns

When fixing concurrency warnings, use these patterns:

**Pattern 1: Non-Sendable in @Sendable closure**
```swift
// Before (warning)
Task { @Sendable in
    processData(myArray) // myArray is [String: Any]
}

// After (fixed)
let sendableData = myArray // Capture before Task
Task {
    await processData(sendableData)
}
```

**Pattern 2: Main actor isolation**
```swift
// Before (warning)
func updateUI() {
    label.text = "Updated" // Called from non-main context
}

// After (fixed)
@MainActor
func updateUI() {
    label.text = "Updated"
}
```

**Pattern 3: Actor-isolated property access**
```swift
// Before (warning)
Task {
    myActor.property = value // Cross-actor access
}

// After (fixed)
Task {
    await myActor.updateProperty(value)
}
```

## Deprecated API Fix Patterns

**Pattern 1: UIScreen.main (iOS 26)**
```swift
// Before
UIScreen.main.bounds

// After
view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
```

**Pattern 2: onChange (iOS 17)**
```swift
// Before
.onChange(of: value) { newValue in
    handleChange(newValue)
}

// After
.onChange(of: value) { oldValue, newValue in
    handleChange(newValue)
}
```

**Pattern 3: Text concatenation (iOS 26)**
```swift
// Before
Text("Hello ") + Text(name)

// After
Text("Hello \(name)")
```

## Notes

- This is a large refactoring - expect 2-4 hours depending on complexity
- Some warnings may require architectural changes
- When in doubt, ask before making breaking changes
- Keep git commits small and focused per batch
- Document any warnings that cannot be fixed
