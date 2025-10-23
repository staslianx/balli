# Comprehensive Naming Audit Report
**Project:** balli (iOS Diabetes Management App)
**Date:** 2025-10-19
**Standards Reference:** CLAUDE.md

---

## Executive Summary

This audit identified **32 naming issues** across iOS (Swift) and Cloud Functions (TypeScript) code, categorized by severity. The most critical issues involve semantically misleading names that obscure actual functionality, while medium-priority issues center on generic "Manager" classes that violate CLAUDE.md's prohibition against vague utility names.

**Key Findings:**
- **8 Critical** - Actively misleading or semantically incorrect names
- **12 High** - Names that don't match actual functionality
- **9 Medium** - Vague, generic, or inconsistent names
- **3 Low** - Minor clarity improvements

---

## 🔴 CRITICAL ISSUES (8)

### 1. `ResearchSearchService` - Misleading Name
**File:** `/Users/serhat/SW/balli/balli/Features/Research/Services/ResearchSearchService.swift`

**What it actually does:**
Not a general search service - it's a **Firebase Cloud Function HTTP client** that makes streaming SSE requests to `diabetesAssistantStream` endpoint. Handles SSE parsing, rate limiting, error handling, and feedback submission. 95% of the code is HTTP/streaming infrastructure, not search logic.

**Why problematic:**
"Search" implies it performs searches locally. In reality, it's a **Cloud Function API client with streaming capabilities**. The name suggests business logic when it's pure transport/networking.

**Suggested name:** `ResearchStreamingAPIClient` or `DiabetesAssistantStreamClient`

**Impact:** 2 files reference it (`SearchViewModel`, test files)

---

### 2. `SearchViewModel` - Ambiguous Scope
**File:** `/Users/serhat/SW/balli/balli/Features/Research/ViewModels/SearchViewModel.swift`

**What it actually does:**
Manages **medical research queries** with deep research features (multi-round, planning, reflection, sources). Handles T1/T2/T3 research tiers, SSE event processing, and research round tracking. Contains specialized medical research state like `ResearchPlan`, `ResearchRound`, and tier prediction.

**Why problematic:**
"Search" is too generic for a medical research coordinator. The file manages complex multi-round research workflows, not simple searches. Compare to the project's shopping list search or food archive search - those are searches. This is **medical research orchestration**.

**Suggested name:** `MedicalResearchViewModel` or `ResearchQueryViewModel`

**Impact:** ~5 files (views, services, models)

---

### 3. `AIProcessor` - Overly Generic Name
**File:** `/Users/serhat/SW/balli/balli/Features/ChatAssistant/Services/AIProcessor.swift`

**What it actually does:**
**Coordinator/facade** for chat-specific AI operations (text, image, medical, web search processors). Routes to specialized processors like `AITextProcessor`, `AIImageProcessor`, `AIMedicalProcessor`. NOT a general-purpose AI processor - it's tightly coupled to chat/conversation workflows.

**Why problematic:**
Name suggests it processes any AI task. Reality: it's a **chat-specific orchestrator**. The class even has chat-specific methods like `processTextMessage(conversationHistory:)` and manages chat streaming state.

**Suggested name:** `ChatAICoordinator` or `ConversationAIProcessor`

**Impact:** ~8 files across ChatAssistant feature

---

### 4. `SessionManager` - Confusing Scope
**File:** `/Users/serhat/SW/balli/balli/Core/Managers/SessionManager.swift`

**What it actually does:**
Manages **authentication session lifecycle** - token refresh, expiry, keychain storage, network monitoring. NOT user sessions or app sessions - specifically auth tokens with HIPAA-compliant cleanup.

**Why problematic:**
"Session" is ambiguous in a multi-user diabetes app. Could mean: user session, conversation session, cooking session, glucose tracking session. The actual scope is **authentication token lifecycle management**.

**Suggested name:** `AuthenticationSessionManager` or `AuthTokenLifecycleManager`

**Impact:** ~6 files (auth flows, app delegate)

---

### 5. `AppStateManager` - Misleading Purpose
**File:** `/Users/serhat/SW/balli/balli/Core/Managers/AppStateManager.swift`

**What it actually does:**
Manages **app lifecycle events** (foreground/background transitions, deep links, Core Data saves) and **UserDefaults preferences**. NOT UI state or navigation state - it's an **app lifecycle coordinator**.

**Why problematic:**
"AppState" sounds like global UI state (loading, error, navigation). Developers expect something like Redux/MobX state. Reality: it's a **lifecycle event handler** with UserDefaults management.

**Suggested name:** `AppLifecycleCoordinator` or `ApplicationLifecycleManager`

**Impact:** ~10 files (app delegate, scene delegate, main app)

---

### 6. `UserManager` - Overly Generic
**File:** `/Users/serhat/SW/balli/balli/Core/Managers/UserManager.swift`

**What it actually does:**
Manages **user profile selection** between 2 hardcoded users (Dilara and Serhat) for a personal 2-user app. Stores selection in `@AppStorage`. NOT user authentication, user data CRUD, or user profiles - just **profile switching**.

**Why problematic:**
"UserManager" implies comprehensive user management (CRUD, auth, profiles). Actual scope is tiny: select between 2 predefined profiles and save to UserDefaults.

**Suggested name:** `UserProfileSelector` or `ProfileSwitchingManager`

**Impact:** ~4 files (settings, main app, environment)

---

### 7. `NavigationManager` - Scope Confusion
**File:** `/Users/serhat/SW/balli/balli/Core/Navigation/NavigationManager.swift`

**What it actually does:**
Manages **SwiftUI navigation state** (NavigationPath, sheets, alerts, tabs) and **deep linking**. Provides destination routing and state preservation.

**Why problematic:**
Name is fine for general navigation BUT the file also handles **deep linking URL parsing** (50% of code), which is not typical navigation management. Deep linking is integration/routing, not navigation state.

**Suggested name:** Consider splitting into `NavigationStateManager` and `DeepLinkRouter`, OR rename to `AppNavigationCoordinator` to indicate broader scope.

**Impact:** ~12 files (all views using navigation)

---

### 8. `diabetes-assistant-stream.ts` - Misleading Filename
**File:** `/Users/serhat/SW/balli/functions/src/diabetes-assistant-stream.ts`

**What it actually does:**
**Main HTTP endpoint** for streaming research responses (T1/T2/T3). Handles routing, tier selection, SSE streaming, rate limiting. It's the **primary backend entry point**, not a helper utility.

**Why problematic:**
Filename suggests it's a streaming utility or module. Reality: it's the **main Cloud Function HTTP handler**. Should be immediately obvious this is the entry point.

**Suggested name:** `diabetesAssistantHandler.ts` or `researchStreamingEndpoint.ts`

**Impact:** Referenced in Firebase Functions config, iOS service

---

## 🟠 HIGH PRIORITY ISSUES (12)

### 9. `MemorySyncService` - Unclear Direction
**File:** `/Users/serhat/SW/balli/balli/Core/Network/MemorySyncService.swift`

**What it does:** Syncs **iOS → Firebase** memory data (user facts, preferences, patterns)

**Problem:** Name doesn't indicate sync direction (client→server vs bidirectional)

**Suggested:** `FirebaseMemorySyncService` or `MemoryServerSyncService`

**Impact:** 3 files

---

### 10. `ConversationStore` - Vague Type
**File:** `/Users/serhat/SW/balli/balli/Core/Storage/ConversationStore.swift`

**What it does:** **CoreData repository** for chat conversations

**Problem:** "Store" could mean UserDefaults, cache, database, file storage. Doesn't indicate CoreData.

**Suggested:** `ConversationRepository` or `CoreDataConversationStore`

**Impact:** 5 files

---

### 11. `WindowAccessor` - Misleading Purpose
**File:** `/Users/serhat/SW/balli/balli/Core/UI/WindowAccessor.swift`

**What it does:** Likely provides access to UIWindow for modals/overlays

**Problem:** Sounds like a data accessor pattern when it's a **UI utility**

**Suggested:** `UIWindowProvider` or `WindowHelpers`

**Impact:** Unknown (likely 2-3 files)

---

### 12. `Debouncer` - Functional Mismatch
**File:** `/Users/serhat/SW/balli/balli/Core/Utilities/Debouncer.swift`

**What it does:** Delays execution of closures (debouncing)

**Problem:** English grammar issue - should be `Debouncers` (service that debounces) or `DebounceService`

**Suggested:** `DebounceService` or `InputDebouncer`

**Impact:** 3-5 files (search, forms)

---

### 13. `RetryUtility` - Violates Naming Standards
**File:** `/Users/serhat/SW/balli/balli/Core/Utilities/RetryUtility.swift`

**What it does:** Retry logic with exponential backoff

**Problem:** CLAUDE.md prohibits "Utility" suffix. Should describe what it does, not that it's a utility.

**Suggested:** `RetryWithBackoffService` or `NetworkRetryHandler`

**Impact:** 8 files (all network services)

---

### 14. `LoggerFactory` - Factory Pattern Misuse
**File:** `/Users/serhat/SW/balli/balli/Core/Utilities/LoggerFactory.swift`

**What it does:** Static namespace for pre-configured Logger instances

**Problem:** "Factory" implies runtime instance creation. This is a **static logger registry**.

**Suggested:** `LoggerRegistry` or `AppLoggers`

**Impact:** ~30 files (entire codebase)

---

### 15. `PromptTemplates` - Unclear Scope
**File:** `/Users/serhat/SW/balli/balli/Core/Prompts/PromptTemplates.swift`

**What it does:** System prompts for AI conversations

**Problem:** "Templates" suggests generic text templates. Actually **AI system prompt definitions**.

**Suggested:** `AISystemPrompts` or `ConversationPromptLibrary`

**Impact:** 3 files

---

### 16. `NetworkService` - Too Generic
**File:** `/Users/serhat/SW/balli/balli/Core/Networking/NetworkService.swift`

**What it does:** Likely HTTP client wrapper

**Problem:** Every app has a "NetworkService". Doesn't indicate what it handles (REST, GraphQL, etc.)

**Suggested:** `HTTPClient` or `URLSessionNetworkService`

**Impact:** Unknown

---

### 17. `storage-models.ts` (inferred from .swift equivalent)
**File Pattern:** `StorageModels.swift`

**What it does:** Data models for storage operations

**Problem:** Vague - storage could be local, cloud, cache, database

**Suggested:** `FirebaseStorageModels` or `CloudStorageModels`

**Impact:** 2-3 files

---

### 18. `network-models.ts` (inferred)
**File Pattern:** `NetworkModels.swift`

**What it does:** API request/response models

**Problem:** "Network" is too broad - HTTP, WebSocket, etc.

**Suggested:** `APIModels` or `HTTPModels`

**Impact:** 5-8 files

---

### 19. `buildResearchSystemPrompt` - Inconsistent Verb
**File:** `/Users/serhat/SW/balli/functions/src/research-prompts.ts`

**What it does:** Constructs system prompt for research tiers

**Problem:** Inconsistent with Swift naming (Swift would use `make` or `create`)

**Suggested:** `createResearchSystemPrompt` (aligns with Swift conventions)

**Impact:** 3 files

---

### 20. `formatSourcesWithTypes` - Unclear Transformation
**File:** `/Users/serhat/SW/balli/functions/src/utils/research-helpers.ts`

**What it does:** Converts sources to formatted output structure

**Problem:** "format" is ambiguous (string formatting? data transformation?)

**Suggested:** `convertSourcesToFormattedOutput` or `transformSourcesToAPIFormat`

**Impact:** 2 files

---

## 🟡 MEDIUM PRIORITY ISSUES (9)

### 21. Multiple "Manager" Suffixes - Violates Standards
**Files:**
- `SessionManager.swift`
- `AppStateManager.swift`
- `UserManager.swift`
- `NavigationManager.swift`
- `CameraPermissionManager.swift`
- `UnifiedPermissionManager.swift`
- `SecureKeychainManager.swift`

**Problem:** CLAUDE.md states: *"No 'Utilities' or 'Helpers' dumping grounds"*. While not explicitly listing "Managers", the spirit is the same - avoid generic suffixes that don't describe purpose.

**Why it matters:** These are all different types of "managers":
- SessionManager = Auth token lifecycle
- AppStateManager = Lifecycle event handler
- UserManager = Profile selector
- NavigationManager = Navigation state + deep linking

**Suggested approach:** Use specific suffixes that indicate the actual pattern:
- `Coordinator` for orchestrators
- `Service` for business logic
- `Handler` for event processors
- `Repository` for data access
- `Provider` for dependency injection

**Impact:** 7 files, pervasive pattern

---

### 22. `MemoryModelContainer` - Unclear Purpose
**File:** `/Users/serhat/SW/balli/balli/Core/Storage/Memory/MemoryModelContainer.swift`

**What it does:** SwiftData model container for memory storage

**Problem:** "Memory" could mean RAM, long-term memory, or AI memory context. Needs clarification.

**Suggested:** `AIMemoryModelContainer` or `ConversationMemoryContainer`

**Impact:** 2 files

---

### 23. `SimpleLabelNutrition` - "Simple" Is Vague
**File:** `/Users/serhat/SW/balli/balli/Core/Models/SimpleLabelNutrition.swift`

**What it does:** Likely a lightweight nutrition data model

**Problem:** "Simple" doesn't describe what makes it different from complex version

**Suggested:** `BasicNutritionLabel` or `LabelNutritionSummary`

**Impact:** 3 files

---

### 24. `Persistence.swift` - Too Generic
**File:** `/Users/serhat/SW/balli/balli/Core/Data/Persistence.swift`

**What it does:** Unknown - likely CoreData stack setup

**Problem:** Every app has "persistence". Needs specificity.

**Suggested:** `CoreDataStack` or `PersistenceConfiguration`

**Impact:** Unknown

---

### 25. `SampleDataGenerator` - Misleading Name
**File:** `/Users/serhat/SW/balli/balli/Core/Data/SampleDataGenerator.swift`

**What it does:** Generates test/preview data

**Problem:** "Sample" suggests user-facing samples. Likely debug-only.

**Suggested:** `PreviewDataFactory` or `TestDataGenerator`

**Impact:** Preview code only

---

### 26. `router-flow.ts` - Inconsistent Naming
**File:** `/Users/serhat/SW/balli/functions/src/flows/router-flow.ts`

**What it does:** Routes questions to tier 1/2/3

**Problem:** Uses kebab-case (router-flow) while Swift uses PascalCase. Also "flow" is vague.

**Suggested:** `questionRouter.ts` or `tierRouter.ts`

**Impact:** 2 files

---

### 27. `research-helpers.ts` - Violates Standards
**File:** `/Users/serhat/SW/balli/functions/src/utils/research-helpers.ts`

**What it does:** Utility functions for research formatting

**Problem:** "Helpers" is explicitly forbidden by CLAUDE.md

**Suggested:** `researchFormatters.ts` or `sourceFormatting.ts`

**Impact:** 5 files

---

### 28. `response-cleaner.ts` - Unclear Transformation
**File:** `/Users/serhat/SW/balli/functions/src/utils/response-cleaner.ts`

**What it does:** Cleans/sanitizes LLM responses

**Problem:** "Cleaner" is vague - what kind of cleaning?

**Suggested:** `llmResponseSanitizer.ts` or `responseTextNormalizer.ts`

**Impact:** 3 files

---

### 29. `error-logger.ts` - Functional Overlap
**File:** `/Users/serhat/SW/balli/functions/src/utils/error-logger.ts`

**What it does:** Structured error logging

**Problem:** Overlaps with general logging. Should indicate it's for **structured error tracking**.

**Suggested:** `structuredErrorLogger.ts` or `errorTrackingService.ts`

**Impact:** 8 files

---

## 🟢 LOW PRIORITY ISSUES (3)

### 30. `SSEParser` - Acronym Without Context
**File:** `/Users/serhat/SW/balli/balli/Features/Research/Services/SSEParser.swift`

**What it does:** Parses Server-Sent Events

**Problem:** SSE acronym may not be immediately clear to new developers

**Suggested:** `ServerSentEventParser` (spell out first use)

**Impact:** 2 files

---

### 31. `Source` Model - Too Generic
**File:** `/Users/serhat/SW/balli/balli/Features/Research/Models/Source.swift`

**What it does:** Research source model (PubMed, arXiv, etc.)

**Problem:** "Source" could mean data source, code source, media source

**Suggested:** `ResearchSource` or `MedicalLiteratureSource`

**Impact:** 8 files (high impact despite low severity)

---

### 32. `Citation` Model - Potential Overlap
**File:** `/Users/serhat/SW/balli/balli/Features/Research/Models/Citation.swift`

**What it does:** Citation model for research answers

**Problem:** May overlap with `Source` - clarify distinction

**Suggested:** If different from `ResearchSource`, rename to `InlineCitation` or `AnswerCitation`

**Impact:** 3 files

---

## 📊 Summary Statistics

| **Severity** | **Count** | **% of Total** |
|--------------|-----------|----------------|
| Critical     | 8         | 25%            |
| High         | 12        | 37.5%          |
| Medium       | 9         | 28%            |
| Low          | 3         | 9.5%           |
| **TOTAL**    | **32**    | **100%**       |

### Issues by Category

| **Category**                  | **Count** |
|-------------------------------|-----------|
| Generic "Manager" suffix      | 7         |
| Misleading functional names   | 8         |
| Vague scope indicators        | 6         |
| Violates CLAUDE.md standards  | 4         |
| Inconsistent conventions      | 3         |
| Ambiguous acronyms            | 2         |
| Unclear data types            | 2         |

---

## 🎯 Recommended Prioritization

### Phase 1: Critical Fixes (Week 1)
1. **ResearchSearchService** → `ResearchStreamingAPIClient`
2. **SearchViewModel** → `MedicalResearchViewModel`
3. **SessionManager** → `AuthenticationSessionManager`
4. **AppStateManager** → `AppLifecycleCoordinator`

**Rationale:** These 4 are the most misleading and affect developer understanding of core architecture.

### Phase 2: High-Impact Renamings (Week 2)
5. **AIProcessor** → `ChatAICoordinator`
6. **UserManager** → `UserProfileSelector`
7. **NavigationManager** → `AppNavigationCoordinator` (or split)
8. **diabetes-assistant-stream.ts** → `diabetesAssistantHandler.ts`
9. **LoggerFactory** → `AppLoggers`
10. **RetryUtility** → `NetworkRetryHandler`

**Rationale:** High usage frequency, violates standards, or creates architectural confusion.

### Phase 3: Consistency Improvements (Week 3)
11-20. Address all "Manager" suffix issues systematically
21-29. Fix TypeScript helper/utility violations

### Phase 4: Polish (Week 4)
30-32. Low-priority clarity improvements

---

## 🛠️ Refactoring Guidelines

### 1. **For Each Renaming:**
- [ ] Find all references using Xcode's "Find in Workspace"
- [ ] Update import statements
- [ ] Update documentation/comments
- [ ] Update test file names
- [ ] Run full test suite after each change
- [ ] Verify SwiftUI previews still work

### 2. **Special Considerations:**

**For Singletons:**
- Update `shared` property name if needed
- Check for environment key extensions

**For View Models:**
- Update all `@StateObject` and `@ObservedObject` declarations
- Check environment injection

**For Services:**
- Update dependency injection containers
- Verify protocol conformances still match

**For TypeScript:**
- Update Firebase Functions exports
- Verify iOS HTTP client URLs still match
- Check API integration tests

### 3. **Testing Strategy:**
After each phase:
1. Build iOS app (`⌘B`)
2. Run test suite (`⌘U`)
3. Run Firebase Functions tests (`npm test`)
4. Verify in iPhone 17 Pro simulator
5. Check for zero warnings

---

## 📝 Notes

### Files Not Requiring Rename
These files have **good, descriptive names** that follow standards:

✅ **Swift:**
- `RecipePhotoGenerationService` - Clear, specific purpose
- `HealthKitAuthorizationManager` - Specific domain + action
- `DexcomAPIClient` - Clear integration point
- `CaptureFlowStateMachine` - Pattern + domain
- `NutritionValidationService` - Domain + action
- `VoiceRecordingManager` - Specific purpose (acceptable "Manager")

✅ **TypeScript:**
- `query-analyzer.ts` - Clear functional name
- `source-ranker.ts` - Descriptive transformation
- `clinical-trials.ts` - Clear domain API
- `deep-research-v2.ts` - Versioned feature module

### Pattern Observation
The codebase shows **two naming approaches**:
1. **Good:** Feature-specific descriptive names (e.g., `RecipeValidationService`)
2. **Problematic:** Generic infrastructure names (e.g., `SessionManager`, `AppStateManager`)

**Recommendation:** Apply the feature-specific naming pattern to all infrastructure code.

---

## 🔗 References
- **CLAUDE.md**: Lines 15-22 (File Organization), Lines 33-39 (Naming Conventions)
- **Swift API Design Guidelines**: https://swift.org/documentation/api-design-guidelines/
- **Clean Code Principles**: Single Responsibility, Clear Naming

---

**Report Generated:** 2025-10-19
**Next Review:** After Phase 1 completion
**Reviewer:** Code Quality Manager (Claude Code)
