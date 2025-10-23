---
description: Verify that an implementation was actually completed correctly
argument-hint: "[description of what was implemented]"
allowed-tools:
  - Bash
  - FileSystem
---

# Verify Implementation

Thoroughly verify that the implementation described in "$ARGUMENTS" was actually completed and works correctly.

## Verification Steps

### 1. Understand the Implementation
First, clarify exactly what was supposed to be implemented based on "$ARGUMENTS".

### 2. Search for Related Changes
- Use `git status` to see what files were modified
- Use `git diff` to review the actual changes made
- Search the codebase for relevant files, functions, and classes related to the implementation
- Check both iOS (Swift) and backend (TypeScript/JavaScript/Firebase) files as applicable

### 3. File-by-File Analysis
For each modified file:
- **Read the actual code** - don't just trust git diff summaries
- Verify the implementation is complete, not partial or stubbed out
- Check for TODO comments, placeholder code, or empty function bodies
- Ensure proper error handling exists
- Verify type safety (TypeScript types, Swift optionals)

### 4. Integration Verification
- **iOS Side**: Check that UI components are properly connected to ViewModels/Controllers
- **Firebase Side**: Verify Firestore rules, Cloud Functions, or Realtime Database changes are complete
- **Connections**: Confirm iOS app actually calls the Firebase endpoints/listeners
- Check that data models match on both sides (Swift structs vs Firestore documents)
- Verify proper async/await or completion handler patterns

### 5. Configuration & Dependencies
- Check if any new dependencies were added to `Podfile`, `package.json`, or SPM
- Verify Firebase configuration files (`GoogleService-Info.plist`, `.firebaserc`, `firebase.json`)
- Check for required API keys, environment variables, or configuration

### 6. Build & Runtime Verification
- **iOS**: Check if the Xcode project builds without errors or warnings
- **Backend**: Verify TypeScript compiles and Firebase functions deploy successfully
- Look for potential runtime issues: force unwraps, uncaught promises, missing null checks

### 7. Testing Evidence
- Check if there are any tests for the new functionality
- If no tests exist, note what should be tested
- Identify edge cases that might not be handled

### 8. Gap Analysis
Create a detailed list of:
- ❌ What was NOT implemented despite being part of the requirement
- ⚠️ What is incomplete or partially implemented
- 🐛 Potential bugs or issues in the implementation
- 📝 What still needs to be done to fully complete the task

## Report Format

Provide a clear verification report with:

1. **Summary**: One sentence - is it actually done or not?
2. **What Was Actually Implemented**: Specific files and changes
3. **Verification Results**: What works, what doesn't
4. **Issues Found**: Bugs, incomplete code, missing pieces
5. **Still TODO**: Concrete next steps to finish the implementation

Be specific with file paths and line numbers. Don't accept vague claims - verify the actual code exists and works.
