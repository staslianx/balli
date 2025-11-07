# CLAUDE.md - iOS Project Standards

## Project Overview
[Your app name and description]

**Target:** iOS 26+ | Swift 6 | Xcode 16+
**Architecture:** MVVM with SwiftUI
**Design System:** Liquid Glass (iOS 26 native)
**Backend:** Firebase (Firestore, Auth, Storage, Functions)
**AI Integration:** Gemini 2.5 Flash via Genkit

---

## 🎯 Core Principles

### 1. **Code Excellence Standards**
Every line of code must meet these non-negotiable standards:

**File Organization:**
- Max 800 lines per file
- One responsibility per file
- Feature-based folder structure (not layer-based)
- No "Utilities" or "Helpers" dumping grounds

**Naming Conventions:**
- `UserProfileViewModel.swift` not `ProfileVM.swift`
- Clear, descriptive names over brevity
- Consistent suffixes: `ViewModel`, `Service`, `Repository`, `View`
- No abbreviations unless universally understood (URL, API, ID)

**Architecture:**
```
Features/
├── Authentication/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   └── Models/
├── Profile/
└── Settings/

Core/
├── Network/
├── Storage/
└── Extensions/
```

### 2. **Swift 6 Concurrency (MANDATORY)**
Strict concurrency MUST be enabled. Zero data races tolerated.

**Required Patterns:**
- `@MainActor` for all UI-touching code
- Custom actors for isolated business logic
- `Sendable` conformance for types crossing boundaries
- `async/await` over completion handlers
- NO `DispatchQueue.main.async` - use `@MainActor` instead

**Example:**
```swift
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?

    func loadUser() async {
        // Async work here
    }
}
```

### 3. **iOS 26 Liquid Glass System**
All UI MUST use native SwiftUI with Liquid Glass design language.

**NEVER:**
- Use UIKit unless explicitly approved
- Import custom glass effect libraries
- Implement glass effects manually
- Create custom toolbar button containers with frames and backgrounds

**ALWAYS:**
- Use `.glassEffect(.regular.interactive(), in: Shape())` for custom glass
- Use `GlassEffectContainer` for multiple glass elements
- Trust native `.toolbar` for authentic Liquid Glass navigation
- Use simple icon-based toolbar buttons (iOS handles hit targets natively)

#### Native Navigation Bar with Edge-to-Edge Content

For views with hero images or full-width content that should extend behind the navigation bar:

```swift
struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image that extends to top
                Image("hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 400)
                    .ignoresSafeArea(edges: .top)

                // Rest of content
                ContentSection()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Action
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.purple)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Action
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.purple)
                }
            }
        }
    }
}
```

**Key Points:**
- ✅ Use `.toolbarBackground(.hidden, for: .navigationBar)` for native transparent blur
- ✅ Use `.ignoresSafeArea(edges: .top)` on content to extend edge-to-edge
- ✅ Keep toolbar buttons simple - just icons, no custom containers
- ✅ iOS automatically provides native blur/vibrancy and proper hit targets
- ✅ Standard icon size: `17pt` for toolbar items
- ✅ Use `.foregroundColor()` for better compatibility
- ❌ Don't add `.frame()`, `.background()`, or `.overlay()` to toolbar buttons
- ❌ Don't try to create circular button containers manually

### 4. **Error Handling (Zero Tolerance)**
**FORBIDDEN:**
- Force unwraps (`!`) except in genuinely safe contexts
- `try!` anywhere
- Ignoring errors silently
- Generic error messages to users

**REQUIRED:**
- Custom error types with context
- Proper `do-catch` blocks
- User-friendly error messages
- Comprehensive logging with `Logger`

**Example:**
```swift
enum ProfileError: LocalizedError {
    case userNotFound
    case networkFailure(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "We couldn't find your profile. Please try logging in again."
        case .networkFailure:
            return "Connection issue. Please check your internet and try again."
        }
    }
}
```

### 5. **Logging Standards**
Use `Logger` framework with proper subsystems and categories.

```swift
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.yourapp",
    category: "Authentication"
)

// Usage
logger.info("User logged in successfully")
logger.error("Login failed: \(error.localizedDescription)")
logger.debug("Token refresh initiated")
```

**Categories:** Authentication, Network, Database, UI, Profile, Settings

---

## 🏗️ Architecture Patterns

### MVVM Structure
```
View (SwiftUI) → ViewModel (@MainActor) → Service (Business Logic) → Repository (Data Layer)
```

**Responsibilities:**
- **View:** UI only, no business logic
- **ViewModel:** State management, user interactions, UI logic
- **Service:** Business logic, data transformation
- **Repository:** Data access (Firebase, local storage)

### Dependency Injection
NO singletons except for truly global concerns (like AppState).

```swift
// WRONG
class ProfileViewModel {
    let service = AuthService.shared // ❌
}

// RIGHT
class ProfileViewModel {
    let service: AuthServiceProtocol // ✅

    init(service: AuthServiceProtocol) {
        self.service = service
    }
}
```

---

## 🔥 Firebase Integration

### Firestore Schema
```
users/{userId}
    - displayName: String
    - email: String
    - createdAt: Timestamp
    - profileImageURL: String?

conversations/{conversationId}
    - userId: String
    - createdAt: Timestamp
    - messages (subcollection)
```

### Security Rules
- ALWAYS write security rules before implementing features
- Test rules in Firebase Console
- Never rely on client-side validation alone

### Repository Pattern
```swift
protocol UserRepositoryProtocol: Sendable {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

actor UserRepository: UserRepositoryProtocol {
    // Implementation
}
```

---

## 🧪 Testing Requirements

### Test Coverage
- All ViewModels: 80%+ coverage
- All Services: 90%+ coverage
- Business logic: 100% coverage

### Test Principles
1. Tests define what code SHOULD do
2. When tests fail, fix the code, NEVER change the test
3. Test happy paths AND unhappy paths
4. Mock external dependencies (Firebase, network)

**Example:**
```swift
@MainActor
final class ProfileViewModelTests: XCTestCase {
    var viewModel: ProfileViewModel!
    var mockService: MockAuthService!

    override func setUp() async throws {
        mockService = MockAuthService()
        viewModel = ProfileViewModel(service: mockService)
    }

    func testLoadUser_Success() async throws {
        // Given
        let expectedUser = User(id: "123", name: "Test")
        mockService.userToReturn = expectedUser

        // When
        await viewModel.loadUser()

        // Then
        XCTAssertEqual(viewModel.user, expectedUser)
        XCTAssertNil(viewModel.error)
    }

    func testLoadUser_Failure() async throws {
        // Given
        mockService.shouldFail = true

        // When
        await viewModel.loadUser()

        // Then
        XCTAssertNil(viewModel.user)
        XCTAssertNotNil(viewModel.error)
    }
}
```

---

## 🚀 Build & Deploy

### Build Verification
After EVERY code change:
1. Build project: `⌘B`
2. Run on iPhone 17 Pro simulator
3. Verify zero warnings
4. Run test suite: `⌘U`
5. Check SwiftUI previews render correctly

### Build Configurations
- **Debug:** Development with verbose logging
- **Release:** Production-ready, optimized, minimal logging

---

## 🎨 SwiftUI Best Practices

### View Composition
Break large views into small, reusable components.

```swift
// WRONG: 1000-line view
struct ProfileView: View {
    var body: some View {
        // 1000 lines of UI code ❌
    }
}

// RIGHT: Composed views
struct ProfileView: View {
    var body: some View {
        VStack {
            ProfileHeaderView()
            ProfileStatsView()
            ProfileActionsView()
        }
    }
}
```

### Previews (MANDATORY)
Every view MUST have comprehensive previews showing all states.

```swift
#Preview("Default State") {
    ProfileView(viewModel: ProfileViewModel.preview)
}

#Preview("Loading State") {
    ProfileView(viewModel: ProfileViewModel.previewLoading)
}

#Preview("Error State") {
    ProfileView(viewModel: ProfileViewModel.previewError)
}
```

---

## 🔐 Security

### Secrets Management
- NO hardcoded API keys
- Use `.xcconfig` files (not committed to git)
- Keychain for sensitive data
- Environment variables for configuration

### Firebase Security
- Always implement Firestore security rules
- Use Firebase App Check
- Validate all user input server-side
- Never trust client-side validation

---

## 📝 Code Review Checklist

Before any PR/commit, verify:
- [ ] Zero build warnings
- [ ] All tests pass
- [ ] SwiftUI previews work
- [ ] No force unwraps or `try!`
- [ ] Proper error handling
- [ ] Swift 6 concurrency compliant
- [ ] Logged important events
- [ ] No files over 800 lines
- [ ] No functions over 50 lines
- [ ] Follows MVVM pattern
- [ ] Uses dependency injection
- [ ] Has comprehensive tests

---

## 🚨 Forbidden Practices

These will be REJECTED in code review:

❌ Force unwrapping: `user!`
❌ Force try: `try! data.write()`
❌ Massive files: Over 800 lines
❌ Mega classes: One class doing everything
❌ Singletons everywhere
❌ `DispatchQueue.main.async` (use `@MainActor`)
❌ UIKit in new code (without approval)
❌ Commented-out code
❌ Magic numbers: Use constants
❌ Generic variable names: `temp`, `data`, `x`
❌ Nested pyramids: Max 3 indentation levels

---

## 🎯 Performance Standards

- App launch: < 2 seconds
- View transitions: 60fps
- Network requests: < 3 seconds timeout
- Image loading: Progressive with placeholders
- No memory leaks (verify with Instruments)

---

## 📚 Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios)
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

---

## 🤝 Agent Coordination & Prompt Engineering

### Available Specialist Agents
When Claude Code deploys specialist agents:
- **contextor**: Always use before feature work - finds relevant files efficiently
- **planner**: Feature planning and project breakdown
- **researcher**: Finding current technical documentation
- **ios-expert**: All iOS-specific issues (concurrency, permissions, logging, previews, markdown)
- **googler**: Firebase/GCP/Gemini integration
- **code-quality-manager**: Code reviews, refactoring, organization, file deletion, cleanup
- **deep-debugger**: Persistent bugs, verification, end-to-end flow tracing
- **rigorous-tester**: Test coverage and verification
- **llm-chat-architect**: LLM streaming, chat features, markdown rendering, AI workflows
- **technical-documentation-architect**: System documentation, architecture docs, ADRs
- **memory-systems-architect**: RAG/LLM memory systems (if applicable)
- **prompt-engineer**: Prompt optimization, LLM instruction crafting, AI system design

### Agent Ownership & Responsibility

**CRITICAL RULE FOR ALL AGENTS:**
When any agent is deployed, they take FULL OWNERSHIP of making their work succeed. This means:

**Zero Tolerance for Blockers:**
- If compilation errors exist ANYWHERE in the project, the agent MUST fix them before proceeding
- If tests fail due to unrelated test files, the agent MUST fix those test files
- If dependencies are broken, the agent MUST resolve them
- If configuration is missing, the agent MUST add it
- NO EXCUSES: "There are other errors" is NOT acceptable - fix them

**Specific to rigorous-tester Agent:**
When the rigorous-tester is asked to "build and run tests":
1. **First:** Attempt to build the test target
2. **If build fails:** Identify ALL compilation errors in ANY test file
3. **Fix ALL errors:** Not just the tests you wrote, but EVERY broken test in the project
4. **Then:** Run the complete test suite
5. **Report:** Both your new tests AND the status of all other tests

The rigorous-tester agent CANNOT report success until:
- ✅ The entire project builds without errors
- ✅ ALL test files compile successfully
- ✅ The full test suite runs (even if some tests fail)
- ✅ The tests the agent was asked to write pass

**Why This Matters:**
A broken test suite means the project is in a bad state. Any agent that encounters this MUST fix it, not work around it. This prevents technical debt accumulation and ensures the project is always in a buildable, testable state.

---

## 🎯 Prompt Engineering Standards for AI Agents

When deploying AI agents or writing prompts for LLM integration:

### 1. Clarity Principles
**ALWAYS:**
- Be specific and concrete - replace vague terms with measurable criteria
- Use imperative form: "Analyze..." not "Could you please analyze..."
- State requirements explicitly, never assume context
- Remove filler words and polite padding

**NEVER:**
- Use "role-play trap" (excessive persona descriptions)
- Be ambiguous about success criteria
- Assume the agent knows your domain
- Use generic variable names in examples

### 2. Structure and Organization
Use clear XML-style boundaries:

```xml
<context>
Background information
</context>

<task>
Specific action to take
</task>

<format>
Output structure requirements
</format>

<constraints>
- Critical constraint 1
- Critical constraint 2
</constraints>
```

### 3. Priority Hierarchy (P0/P1/P2)
When multiple requirements exist:

```
P0 (MUST - output invalid without):
✓ Security requirements
✓ Schema/format requirements
✓ Breaking functionality

P1 (SHOULD - quality suffers without):
✓ Performance standards
✓ Code quality rules
✓ UX requirements

P2 (NICE TO HAVE):
✓ Stylistic preferences
✓ Optional features
```

**Why:** When everything is "critical", nothing is. Clear priorities enable intelligent tradeoffs.

### 4. Examples Over Explanation
Show patterns, not text to copy:

❌ **WRONG:**
```
Write clean code like: "func fetchUser() async throws -> User"
```

✅ **RIGHT:**
```
⚠️ Example shows STRUCTURE, not text to copy!

Pattern: func [actionName]() async throws -> [ReturnType]

Use YOUR function names following this pattern.
```

### 5. Prevent Verbatim Copying
Add explicit warnings:

```
⚠️ This example shows PATTERN, not text to copy!
- Write your own implementation
- Use different variable names
- NEVER copy example text verbatim
```

### 6. Token Efficiency
Maximize information density:

**Before (43 tokens):**
```
I would really appreciate it if you could please help me understand 
how to implement authentication in SwiftUI using Firebase Auth.
```

**After (11 tokens):**
```
Implement SwiftUI Firebase Auth.
Requirements: async/await, error handling, secure storage.
```

### 7. Depth Control for Technical Agents
Prevent over/under-complexity:

```
Explanation depth levels:
- Layer 1: WHAT (concept) ✅
- Layer 2: HOW (mechanism) ✅  
- Layer 3: WHY (theory) - Only if requested
- Layer 4: IMPLEMENTATION DETAILS ❌

Stop signals:
- 3+ technical terms in one sentence → Simplify
- Requires PhD-level knowledge → Add context first
```

### 8. Self-Correction Loops
For quality-critical outputs:

```
1. Generate initial response

2. Self-check:
   ☐ Swift 6 concurrency compliant
   ☐ No force unwraps
   ☐ Proper error handling
   ☐ Under 800 lines

3. If any check fails:
   - Identify issue
   - Fix immediately
   - Re-verify
```

### 9. Common Anti-Patterns to Avoid

**The Kitchen Sink:**
❌ 50 requirements in one prompt
✅ 3-5 prioritized requirements

**The Moving Target:**
❌ "Make it better, more professional, higher quality"
✅ "Reduce to 800 lines, add error handling, remove force unwraps"

**The Wall of Text:**
❌ 1000-word paragraph with buried instructions
✅ Structured sections with clear boundaries

**The Perfection Demand:**
❌ "This must be absolutely perfect with zero mistakes"
✅ P0/P1/P2 hierarchy with clear acceptance criteria

### 10. Agent-Specific Prompt Patterns

**For ios-expert:**
```
<task>Implement [feature]</task>
<constraints>
- Swift 6 strict concurrency
- iOS 26+ APIs only
- Max 200 lines
- Comprehensive error handling
</constraints>
<verification>
- Builds without warnings
- Passes all tests
- SwiftUI previews work
</verification>
```

**For code-quality-manager:**
```
<task>Refactor [component]</task>
<priorities>
P0: Fix force unwraps and try!
P1: Reduce file to <800 lines
P2: Improve naming
</priorities>
<standards>Follow CLAUDE.md section 1</standards>
```

**For rigorous-tester:**
```
<task>Test [component]</task>
<coverage>
- Happy path: All critical flows
- Unhappy path: All error states
- Edge cases: Boundary conditions
</coverage>
<must_fix>All compilation errors in test target</must_fix>
```

### 11. Prompt Quality Checklist

Before deploying any agent with a prompt, verify:
- [ ] Clear P0/P1/P2 priorities
- [ ] Specific success criteria (no vague terms)
- [ ] Structured sections (XML-style tags)
- [ ] Examples with anti-copy warnings
- [ ] No polite padding or filler
- [ ] Imperative form used
- [ ] Token-efficient (removed redundancy)
- [ ] Self-verification steps included
- [ ] Consequences stated for P0 violations

---

**IMPORTANT:** You are the MANAGER OF ALL SUBAGENTS. You MUST verify your agents follow these rules. If an agent reports blockers without fixing them, redeploy that agent with explicit instructions to fix ALL blockers following the prompt engineering standards above.

---

## 🔧 Known Solutions & Debugging Patterns

### SSE Streaming Completion Handling

**Problem:** Server-Sent Events (SSE) streams may close without sending proper `completed` events, causing state to remain "in progress" indefinitely (e.g., loading spinners, button animations that never stop).

**Root Cause:** Firebase Cloud Functions or other SSE endpoints may terminate connections prematurely or fail to send the final `completed` event due to timeouts, errors, or malformed event structures.

**Solution Pattern:**

```swift
// In SSE streaming handler
var completedEventReceived = false
var lastChunkData: EventType?

for try await line in asyncBytes.lines {
    // Process events
    if event.type == "completed" {
        completedEventReceived = true
    }
    if event.type == "chunk" {
        lastChunkData = event
    }

    await handleEvent(event)
}

// CRITICAL: Fallback completion when stream ends
if !completedEventReceived {
    logger.warning("Stream closed without 'completed' event - synthesizing completion")

    if let lastChunk = lastChunkData {
        // Synthesize minimal completion response
        let fallbackResponse = ResponseType(
            // Use empty/minimal values - don't overwrite already-streamed content
            recipeName: "",
            content: lastChunk.fullContent
        )

        await onComplete(fallbackResponse)
    }
}
```

**Key Implementation Details:**

1. **Track Completion State**: Monitor if `completed` event was received during stream
2. **Store Last Chunk**: Keep reference to most recent chunk for fallback
3. **Synthesize Minimal Response**: Create response with empty metadata to avoid overwriting streamed content
4. **Conditional Data Loading**: Only load response if it contains real data (non-empty recipeName)

```swift
// In completion handler
onComplete: { response in
    // Guard against overwriting already-streamed content
    if !response.recipeName.isEmpty {
        // Real completed event from server - load full response
        self.formState.loadFromGenerationResponse(response)
    } else {
        // Synthesized fallback - preserve already-streamed content
        logger.info("Skipping loadFromGenerationResponse - using already-streamed content")
    }

    // Always trigger state transitions
    self.stopAnimation()
    self.isGenerating = false
}
```

**Benefits:**
- ✅ Gracefully handles both normal and abnormal stream termination
- ✅ Preserves real-time streamed content (recipe names, markdown, metadata)
- ✅ Ensures UI state transitions complete (animations stop, buttons enable)
- ✅ Backward compatible if server is fixed to send proper `completed` events
- ✅ Comprehensive logging for debugging

**Files Modified:**
- `RecipeStreamingService.swift`: Added fallback completion synthesis
- `RecipeGenerationCoordinator.swift`: Added conditional response loading guard

**Related:** Server-Sent Events, Streaming Responses, State Management, Animation Lifecycle

---

**Last Updated:** 2025-11-07
**Enforced By:** Claude Code + Code Review