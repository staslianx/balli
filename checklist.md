# Claude Code Audit Prompt for Balli iOS App

Copy and paste this into Claude Code CLI to audit your codebase:

-----

You are auditing the Balli iOS app for production readiness. This is a personal diabetes management app for one user (Turkish language) that will launch in November 2025.

## Critical Context

- **Tech Stack:** SwiftUI, Swift 6, Core Data, Firebase Cloud Functions, Gemini 2.5 Flash
- **Key Features:** Voice meal logging, Dexcom CGM integration, AI recipe generation, nutrition label scanning
- **Critical Dependency:** Dexcom glucose readings MUST persist to Core Data for future insights feature
- **User:** Non-technical Turkish speaker with diabetes

## Audit Tasks

### 1. CRITICAL: Find Force Unwrapping (Crash Risks)

Search the entire codebase for:

- `!` force unwraps (except in test files)
- `try!` without error handling
- `as!` force casts
- `.first!` on arrays that could be empty
- Direct array access with `[index]` without bounds checking

**Output:** List every file and line number with force unwraps. Flag HIGH RISK ones in critical paths (Dexcom, voice logging, Core Data).

-----

### 2. Data Persistence Verification

Find all places where:

- Dexcom glucose readings are received from API
- Check if there’s a Core Data save operation nearby
- Verify `GlucoseReading` entity exists and is used
- Check if background fetch saves data to Core Data
- Look for potential data loss scenarios (app termination, memory warnings)

**Output:** Does glucose data actually persist? Show the code path from API → Core Data save.

-----

### 3. API Error Handling

Check all Firebase Cloud Function calls:

- `transcribeMeal`
- `extractNutritionFromImage`
- `generateSpontaneousRecipe`
- `generateRecipeFromIngredients`
- `diabetesAssistantStream`

For each, verify:

- Has try-catch or error handling
- Has timeout handling
- Has retry logic or graceful failure
- Shows user-friendly Turkish error message (not raw error dump)

**Output:** List any API calls missing proper error handling.

-----

### 4. Background Task Safety

Find:

- Background fetch implementations
- Dexcom polling in background
- Core Data operations in background threads
- Any UI updates from background threads (will crash)

**Output:** Flag any background operations that might crash or lose data.

-----

### 5. Memory Leaks & Retain Cycles

Search for:

- `@State`, `@StateObject`, `@ObservedObject` usage
- Strong reference captures in closures `[self]` instead of `[weak self]`
- Delegates without `weak` reference
- Timer/observers not invalidated in `deinit`

**Output:** List potential memory leak locations.

-----

### 6. Network Dependency Issues

Find code that:

- Assumes network is always available
- Doesn’t handle offline state
- Crashes when API returns unexpected format
- Doesn’t show loading state for async operations

**Output:** What breaks without internet? What still works?

-----

### 7. Security Issues

Check for:

- API keys hardcoded in source files
- Sensitive data logged to console (`print`, `NSLog`, `os_log`)
- Credentials stored in UserDefaults instead of Keychain
- Health data (glucose, meals) sent to analytics
- Voice recordings stored permanently

**Output:** List any security/privacy violations.

-----

### 8. Core Data Schema Issues

Examine Core Data model:

- Are relationships properly defined?
- Delete rules configured (cascade, nullify)?
- Indexes on frequently queried fields?
- Migration policy if schema changes?

**Output:** Show Core Data entity structure and flag missing relationships or indexes.

-----

### 9. Localization Issues

Find:

- Hardcoded English strings in user-facing UI
- Error messages not in Turkish
- Permission request descriptions
- Missing Turkish translations

**Output:** List any English strings that should be Turkish.

-----

### 10. Performance Issues

Look for:

- Fetch requests without limits (`.fetchLimit`)
- Images loaded synchronously on main thread
- Heavy operations in view body (runs every render)
- Repeated API calls for same data
- Missing caching

**Output:** Flag performance bottlenecks.

-----

### 11. Permission Handling

Check:

- Microphone permission request and denial handling
- Camera permission request and denial handling
- HealthKit permission request
- Photo library (if used)

**Output:** What happens if user denies each permission?

-----

### 12. Edge Cases

Find code that might break when:

- First app launch (no data exists)
- User has zero meals logged
- Dexcom never connected
- Recipe generation fails 3 times
- Phone storage is full
- Date/time edge cases (midnight, DST)

**Output:** List unhandled edge cases.

-----

### 13. Critical Path Testing

Trace these flows end-to-end:

1. **Voice meal logging:** Button tap → recording → Gemini API → parse → save Core Data → display
1. **Dexcom sync:** Background fetch → API call → parse → save Core Data → update chart
1. **Recipe generation:** Button tap → Gemini streaming → parse → photo generation → save Core Data

**Output:** Show complete code path for each. Flag any weak points.

-----

### 14. Configuration Issues

Check for:

- Bundle identifier set correctly
- Version number and build number
- Info.plist permission descriptions in Turkish
- Firebase configuration file present
- API endpoint URLs (not localhost)

**Output:** List any missing or incorrect configurations.

-----

### 15. Crash Recovery

Find:

- Uncaught exceptions
- Fatal errors that should be recoverable
- Missing state restoration
- Core Data save failures not handled

**Output:** What happens if the app crashes mid-operation?

-----

## Deliverable Format

For each section, provide:

1. **Status:** ✅ Good / ⚠️ Needs attention / 🚨 Critical issue
1. **Findings:** Specific file paths and line numbers
1. **Risk level:** HIGH / MEDIUM / LOW
1. **Recommendation:** What to fix and why

Prioritize issues that will:

- Cause crashes in production
- Lose user data (glucose readings, meals)
- Break core workflows (voice logging, Dexcom sync)
- Create bad user experience (confusing errors, app freeze)

## Most Critical Questions to Answer

1. **Does Dexcom glucose data actually persist to Core Data?** (Show the code)
1. **What crashes the app?** (Force unwraps, unhandled errors)
1. **What breaks without internet?** (Offline behavior)
1. **Are there memory leaks?** (Retain cycles, background tasks)
1. **Is sensitive data secure?** (API keys, credentials, health data)

Focus on the absolute must-fix issues before November launch.
