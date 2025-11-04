# Dependency Injection Guide

**Project:** Balli iOS App
**Date:** 2025-11-04
**Status:** Phase 0 Complete - Infrastructure Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Phase 0: Infrastructure](#phase-0-infrastructure)
3. [Using Protocol-Based Services](#using-protocol-based-services)
4. [Writing Testable Code](#writing-testable-code)
5. [SwiftUI Previews with DI](#swiftui-previews-with-di)
6. [Migration Guide](#migration-guide)
7. [Best Practices](#best-practices)

---

## Overview

This guide explains how to use the Dependency Injection (DI) system in the Balli app. We're transitioning from singleton-based architecture to protocol-based dependency injection to improve testability, maintainability, and code quality.

### Why Dependency Injection?

**Before (Singletons):**
```swift
class MyViewModel {
    func loadData() {
        DexcomService.shared.syncData()  // ❌ Hard to test
    }
}
```

**Problems:**
- ❌ Can't mock `DexcomService.shared` in tests
- ❌ Hidden dependencies (where does DexcomService come from?)
- ❌ Tests affect each other via shared state
- ❌ Can't test error paths easily

**After (Dependency Injection):**
```swift
class MyViewModel {
    private let dexcomService: DexcomServiceProtocol  // ✅ Explicit dependency

    init(dexcomService: DexcomServiceProtocol) {
        self.dexcomService = dexcomService
    }

    func loadData() {
        dexcomService.syncData()  // ✅ Easy to test
    }
}
```

**Benefits:**
- ✅ Can inject `MockDexcomService` in tests
- ✅ Dependencies are explicit and visible
- ✅ Tests are isolated and independent
- ✅ Easy to test error paths with mocks

---

## Phase 0: Infrastructure

### What's Available Now

Phase 0 has established the foundation for dependency injection:

#### 1. Protocol Definitions

Located in `balli/Core/Protocols/Services/`:

- `MealReminderManagerProtocol`
- `LocalAuthenticationManagerProtocol`
- `AnalyticsServiceProtocol`
- `KeychainStorageServiceProtocol`
- `DexcomServiceProtocol`

#### 2. Mock Implementations

Located in `balliTests/Mocks/`:

- `MockMealReminderManager`
- `MockLocalAuthenticationManager`
- `MockAnalyticsService`
- `MockKeychainStorageService`
- `MockDexcomService`

#### 3. Enhanced DependencyContainer

The `DependencyContainer` now provides protocol-based access to services while maintaining backward compatibility with existing singleton usage.

---

## Using Protocol-Based Services

### In ViewModels

**Pattern: Constructor Injection**

```swift
@MainActor
final class GlucoseDashboardViewModel: ObservableObject {
    // 1. Declare dependencies as protocol types
    private let dexcomService: DexcomServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    // 2. Accept dependencies via initializer
    init(
        dexcomService: DexcomServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.dexcomService = dexcomService
        self.analyticsService = analyticsService
    }

    // 3. Use dependencies
    func syncData() async {
        await analyticsService.track(.dexcomSyncStarted)

        do {
            try await dexcomService.syncData(force: false)
            await analyticsService.track(.dexcomSyncSuccess)
        } catch {
            await analyticsService.trackError(.dexcomSyncFailed, error: error)
        }
    }
}
```

### In SwiftUI Views

**Pattern: Environment Access**

```swift
struct GlucoseDashboardView: View {
    // 1. Access dependencies via environment
    @Environment(\.dependencies) private var dependencies

    // 2. Create ViewModel with dependencies
    @StateObject private var viewModel: GlucoseDashboardViewModel

    init() {
        // This will be called when view initializes
        // Use `@Environment` isn't available yet, so we use shared temporarily
        let deps = DependencyContainer.shared
        _viewModel = StateObject(wrappedValue: GlucoseDashboardViewModel(
            dexcomService: deps.dexcomService,
            analyticsService: deps.analyticsService
        ))
    }

    var body: some View {
        // Your view code
    }
}
```

**Alternative Pattern: Direct ViewModel Creation**

For simpler cases, create ViewModel lazily:

```swift
struct SettingsView: View {
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        SettingsContent(
            analyticsService: dependencies.analyticsService,
            authManager: dependencies.localAuthenticationManager
        )
    }
}
```

### In Services

**Pattern: Service Dependencies**

```swift
final class RecipeSyncCoordinator {
    private let analyticsService: AnalyticsServiceProtocol
    private let recipeService: RecipeFirestoreService

    init(
        analyticsService: AnalyticsServiceProtocol,
        recipeService: RecipeFirestoreService
    ) {
        self.analyticsService = analyticsService
        self.recipeService = recipeService
    }

    func syncRecipes() async throws {
        await analyticsService.track(.recipeSyncStarted)
        // ... sync logic
    }
}
```

---

## Writing Testable Code

### Example: Testing a ViewModel

```swift
import XCTest
@testable import balli

@MainActor
final class GlucoseDashboardViewModelTests: XCTestCase {

    // 1. Declare test subjects and mocks
    var viewModel: GlucoseDashboardViewModel!
    var mockDexcomService: MockDexcomService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        // 2. Create fresh mocks for each test
        mockDexcomService = MockDexcomService()
        mockAnalytics = MockAnalyticsService()

        // 3. Inject mocks into ViewModel
        viewModel = GlucoseDashboardViewModel(
            dexcomService: mockDexcomService,
            analyticsService: mockAnalytics
        )
    }

    override func tearDown() {
        viewModel = nil
        mockDexcomService = nil
        mockAnalytics = nil
    }

    // 4. Test happy path
    func testSyncData_Success() async throws {
        // Given: Mock will succeed
        mockDexcomService.shouldSucceedSync = true
        mockDexcomService.mockReadings = [
            MockDexcomService.mockGlucoseReading(value: 120.0)
        ]

        // When: Sync data
        await viewModel.syncData()

        // Then: Verify behavior
        XCTAssertEqual(mockDexcomService.syncDataCallCount, 1)
        XCTAssertTrue(await mockAnalytics.wasEventTracked(.dexcomSyncStarted))
        XCTAssertTrue(await mockAnalytics.wasEventTracked(.dexcomSyncSuccess))
        XCTAssertFalse(await mockAnalytics.wasEventTracked(.dexcomSyncFailed))
    }

    // 5. Test error path
    func testSyncData_Failure() async throws {
        // Given: Mock will fail
        mockDexcomService.shouldSucceedSync = false
        mockDexcomService.mockError = .networkError(NSError(domain: "Test", code: -1, userInfo: nil))

        // When: Sync data
        await viewModel.syncData()

        // Then: Verify error handling
        XCTAssertEqual(mockDexcomService.syncDataCallCount, 1)
        XCTAssertTrue(await mockAnalytics.wasEventTracked(.dexcomSyncStarted))
        XCTAssertTrue(await mockAnalytics.wasEventTracked(.dexcomSyncFailed))
        XCTAssertFalse(await mockAnalytics.wasEventTracked(.dexcomSyncSuccess))
    }
}
```

### Mock Configuration Examples

#### Configure Mock to Return Data

```swift
// Setup mock readings
mockDexcomService.mockReadings = [
    MockDexcomService.mockGlucoseReading(value: 120.0, timestamp: Date()),
    MockDexcomService.mockGlucoseReading(value: 130.0, timestamp: Date().addingTimeInterval(-300))
]

// Fetch will return these readings
let readings = try await mockDexcomService.fetchRecentReadings(days: 7)
XCTAssertEqual(readings.count, 2)
```

#### Configure Mock to Throw Error

```swift
// Setup mock to fail
mockKeychainService.shouldThrowOnRetrieve = true

// Retrieve will throw
do {
    let token = try await mockKeychainService.retrieve(String.self, for: "token", itemType: .accessToken)
    XCTFail("Should have thrown")
} catch {
    // Expected error
}
```

#### Track Mock Calls

```swift
// Perform operations
await mockAnalytics.track(.dexcomSyncStarted)
await mockAnalytics.track(.dexcomSyncSuccess, properties: ["duration": "1500"])

// Verify calls
XCTAssertEqual(mockAnalytics.trackCallCount, 2)
XCTAssertTrue(await mockAnalytics.wasEventTracked(.dexcomSyncStarted))

// Get properties for specific event
let properties = await mockAnalytics.getProperties(for: .dexcomSyncSuccess)
XCTAssertEqual(properties.first?["duration"], "1500")
```

---

## SwiftUI Previews with DI

### Basic Preview

```swift
#Preview("Default State") {
    GlucoseDashboardView()
        .environment(\.dependencies, DependencyContainer.preview())
}
```

### Preview with Mock Data

```swift
#Preview("Connected with Data") {
    let container = DependencyContainer.preview()

    // Configure mock data (when we move to Phase 1)
    // For now, uses real services

    return GlucoseDashboardView()
        .environment(\.dependencies, container)
}
```

### Preview Multiple States

```swift
#Preview("Loading State") {
    // Show loading spinner
    GlucoseDashboardView()
        .environment(\.dependencies, DependencyContainer.preview())
}

#Preview("Error State") {
    // Show error message
    GlucoseDashboardView()
        .environment(\.dependencies, DependencyContainer.preview())
}

#Preview("Empty State") {
    // Show empty state
    GlucoseDashboardView()
        .environment(\.dependencies, DependencyContainer.preview())
}
```

---

## Migration Guide

### Current State (Phase 0)

Services are still singletons but accessed via `DependencyContainer`:

```swift
// Still works (backward compatible)
DexcomService.shared.syncData()

// New way (preferred)
dependencies.dexcomService.syncData()
```

Both access the SAME singleton instance. This ensures zero breaking changes.

### Future Phases

**Phase 1:** Refactor simple singletons (Week 2)
- `MealReminderManager` → constructor injection
- `LocalAuthenticationManager` → constructor injection

**Phase 2-3:** Refactor complex singletons (Week 3-6)
- `AnalyticsService` → injected everywhere
- `DexcomService` → protocol + DI
- `KeychainStorageService` → protocol + DI

### How to Migrate Your Code

#### Step 1: Update ViewModel to Accept Protocol

```swift
// Before
@MainActor
class MyViewModel: ObservableObject {
    func doSomething() {
        DexcomService.shared.syncData()  // ❌ Direct singleton access
    }
}

// After
@MainActor
class MyViewModel: ObservableObject {
    private let dexcomService: DexcomServiceProtocol  // ✅ Protocol dependency

    init(dexcomService: DexcomServiceProtocol) {
        self.dexcomService = dexcomService
    }

    func doSomething() {
        dexcomService.syncData()  // ✅ Uses injected dependency
    }
}
```

#### Step 2: Update View to Inject Dependencies

```swift
// Before
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()  // ❌ Can't inject

    var body: some View {
        // ...
    }
}

// After
struct MyView: View {
    @Environment(\.dependencies) private var dependencies
    @StateObject private var viewModel: MyViewModel

    init() {
        let deps = DependencyContainer.shared
        _viewModel = StateObject(wrappedValue: MyViewModel(
            dexcomService: deps.dexcomService
        ))
    }

    var body: some View {
        // ...
    }
}
```

#### Step 3: Update Tests to Use Mocks

```swift
// Before
func testSync() async {
    let viewModel = MyViewModel()
    await viewModel.doSomething()

    // ❌ Can't verify what happened - uses real DexcomService.shared
}

// After
func testSync() async {
    let mockDexcom = MockDexcomService()
    mockDexcom.shouldSucceedSync = true

    let viewModel = MyViewModel(dexcomService: mockDexcom)
    await viewModel.doSomething()

    // ✅ Can verify mock interactions
    XCTAssertEqual(mockDexcom.syncDataCallCount, 1)
}
```

---

## Best Practices

### 1. Always Use Protocol Types

```swift
// ✅ Good: Protocol type enables testing
private let analytics: AnalyticsServiceProtocol

// ❌ Bad: Concrete type prevents mocking
private let analytics: AnalyticsService
```

### 2. Inject via Constructor, Not Properties

```swift
// ✅ Good: Constructor injection makes dependencies explicit
init(dexcomService: DexcomServiceProtocol) {
    self.dexcomService = dexcomService
}

// ❌ Bad: Property injection allows incomplete initialization
var dexcomService: DexcomServiceProtocol?  // Could be nil!
```

### 3. Use @Environment for Views

```swift
// ✅ Good: Standard SwiftUI pattern
@Environment(\.dependencies) private var dependencies

// ❌ Bad: Direct singleton access breaks DI
DependencyContainer.shared.dexcomService
```

### 4. Reset Mocks Between Tests

```swift
override func setUp() async throws {
    mockService = MockDexcomService()
    // Fresh mock for each test ✅
}

override func tearDown() {
    mockService.reset()  // Clean up ✅
    mockService = nil
}
```

### 5. Test Both Happy and Unhappy Paths

```swift
func testSync_Success() async {
    // Test success case ✅
}

func testSync_NetworkError() async {
    // Test network error ✅
}

func testSync_AuthError() async {
    // Test auth error ✅
}
```

---

## Common Patterns

### Pattern: Service with Multiple Dependencies

```swift
actor RecipeSyncCoordinator {
    private let analytics: AnalyticsServiceProtocol
    private let keychain: KeychainStorageServiceProtocol
    private let recipeService: RecipeFirestoreService

    init(
        analytics: AnalyticsServiceProtocol,
        keychain: KeychainStorageServiceProtocol,
        recipeService: RecipeFirestoreService
    ) {
        self.analytics = analytics
        self.keychain = keychain
        self.recipeService = recipeService
    }
}
```

### Pattern: Factory Methods in DependencyContainer

```swift
extension DependencyContainer {
    func makeRecipeSyncCoordinator() -> RecipeSyncCoordinator {
        RecipeSyncCoordinator(
            analytics: analyticsService,
            keychain: keychainStorageService,
            recipeService: RecipeFirestoreService()
        )
    }
}
```

### Pattern: Optional Dependencies

```swift
// For truly optional dependencies
init(
    analytics: AnalyticsServiceProtocol? = nil,
    dexcomService: DexcomServiceProtocol  // Required
) {
    self.analytics = analytics
    self.dexcomService = dexcomService
}

// Use with nil-coalescing
analytics?.track(.eventHappened)
```

---

## Troubleshooting

### Issue: "Protocol 'X' can only be used as a generic constraint"

**Solution:** Add `AnyObject` or `Sendable` constraint:

```swift
protocol MyServiceProtocol: AnyObject {
    // For @MainActor classes
}

protocol MyActorServiceProtocol: Actor {
    // For actors
}
```

### Issue: "Cannot find 'MockXService' in scope"

**Solution:** Ensure mock is in test target:
1. Check `balliTests/Mocks/` directory
2. Verify file is in test target membership
3. Import `@testable import balli`

### Issue: Tests failing with "shared" not found

**Solution:** Update to use protocol injection:

```swift
// Old
let service = DexcomService.shared  // ❌ Won't work in tests

// New
let mockService = MockDexcomService()  // ✅ Works in tests
let viewModel = MyViewModel(dexcomService: mockService)
```

---

## Next Steps

### Phase 1: Simple Singletons (Week 2)

We'll refactor:
- `MealReminderManager`
- `LocalAuthenticationManager`

These will be the first to fully remove singleton access and use pure DI.

### Phase 2-6: Complex Singletons (Week 3-7)

We'll systematically refactor:
- `AnalyticsService` (used in ~30 places)
- `DexcomService` (used in ~25 places)
- `RecipeGenerationService`
- All sync coordinators

---

## Resources

- [CLAUDE.md](../CLAUDE.md) - Project coding standards
- [Swift Dependency Injection Best Practices](https://www.swiftbysundell.com/articles/dependency-injection-in-swift/)
- [Testing in Swift](https://developer.apple.com/documentation/xctest)

---

**Last Updated:** 2025-11-04
**Phase:** 0 - Infrastructure Complete
**Next Phase:** Week 2 - Simple Singleton Refactoring
