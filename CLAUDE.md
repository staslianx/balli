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
- Max 300 lines per file (prefer 200 or less)
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

**ALWAYS:**
- Use `.glassEffect(.regular.interactive(), in: Shape())` for custom glass
- Use `GlassEffectContainer` for multiple glass elements
- Trust native `.toolbar` for authentic Liquid Glass navigation

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
// WRONG: 500-line view
struct ProfileView: View {
    var body: some View {
        // 500 lines of UI code ❌
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
- [ ] No files over 300 lines
- [ ] No functions over 50 lines
- [ ] Follows MVVM pattern
- [ ] Uses dependency injection
- [ ] Has comprehensive tests

---

## 🚨 Forbidden Practices

These will be REJECTED in code review:

❌ Force unwrapping: `user!`
❌ Force try: `try! data.write()`
❌ Massive files: Over 300 lines
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

## 🤝 Agent Coordination

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

### **Agent Ownership & Responsibility**

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

**Example - What Should Happen:**
```
User: "Write tests for the ProfileViewModel"

rigorous-tester agent:
1. Writes ProfileViewModelTests.swift
2. Attempts to build test target
3. DISCOVERS: ResearchViewModelTests.swift has 3 compilation errors
4. FIXES: All 3 errors in ResearchViewModelTests.swift
5. DISCOVERS: LabelScannerTests.swift is missing import statement
6. FIXES: Adds missing import
7. Builds successfully
8. Runs full test suite
9. Reports: "Created ProfileViewModelTests with 8 tests (all passing).
   Also fixed compilation errors in ResearchViewModelTests and
   LabelScannerTests. Full test suite now builds and runs successfully."
```

**Example - What Should NOT Happen:**
```
User: "Write tests for the ProfileViewModel"

rigorous-tester agent:
"I've written the tests but there are compilation errors in other
test files preventing the test suite from running. You'll need to
fix those first." ❌ WRONG - The agent should have fixed them
```

---

**IMPORTANT:** You are the MANAGER OF ALL SUBAGENTS. You MUST verify your agents follow these rules. If an agent reports blockers without fixing them, redeploy that agent with explicit instructions to fix ALL blockers.

---

**Last Updated:** [Date]
**Enforced By:** Claude Code + Code Review
