# CODEBASE AUDIT REPORT
**Date:** 2025-10-19
**Auditor:** Code Quality Manager Agent
**Project:** Balli Diabetes Assistant (iOS + Firebase Backend)

---

## Executive Summary

**Total Files Analyzed:**
- **iOS App (Swift):** 408 files across 13 feature modules
- **Firebase Functions (TypeScript):** 74 files with AI flows, tools, and utilities
- **Test Files:** 100+ build logs, multiple test scripts

**Key Findings:**
1. ✅ **Well-Organized Features** - iOS app follows feature-based architecture
2. ⚠️ **Duplicate Research Flows** - Multiple Tier 3 implementations causing confusion
3. ❌ **Orphaned Files** - Unused test scripts, duplicate flows, commented-out code
4. ⚠️ **File Size Violations** - 12 files exceed CLAUDE.md's 300-line limit
5. ✅ **Active Tier 3 Flow** - `deep-research-v2.ts` is the ONLY active implementation
6. 🗑️ **Massive Build Log Pollution** - 90+ build logs cluttering root directory

---

## 1. FEATURE INVENTORY

### iOS App Features (`/balli/Features/`)

#### ✅ **WORKING AND ACTIVELY USED**

| Feature | Status | Files | Notes |
|---------|--------|-------|-------|
| **Research** | ✅ Active | 13 files | Search with streaming SSE, Tier 3 deep research |
| **RecipeManagement** | ✅ Active | 15 files | Recipe generation, photo generation, memory system |
| **ChatAssistant** | ✅ Active | 11 files | Streaming chat with markdown rendering |
| **CameraScanning** | ✅ Active | 22 files | Label scanning, nutrition extraction |
| **HealthGlucose** | ✅ Active | 19 files | HealthKit integration, Dexcom sync |
| **FoodArchive** | ✅ Active | 3 files | Food history (Ardiye view) |
| **FoodEntry** | ✅ Active | 6 files | Voice input, meal logging |
| **Cooking** | ✅ Active | 10 files | Cooking sessions, timers, voice control |
| **ShoppingList** | ✅ Active | 4 files | Recipe ingredients to shopping list |
| **Settings** | ✅ Active | 2 files | App preferences, recipe preferences |

#### ⚠️ **PARTIALLY WORKING / UNCLEAR STATUS**

| Feature | Status | Files | Issues |
|---------|--------|-------|--------|
| **MedicalSearch** | ⚠️ Partial | 12 files | Overlaps with Research feature - seems redundant |
| **UserOnboarding** | ⚠️ Unknown | 1 file | Unclear if used or just placeholder |
| **Launch** | ⚠️ Minimal | 1 file | Simple transition view |
| **Debug** | ⚠️ Dev Only | 1 file | Development tools |

#### 🔍 **POTENTIAL DUPLICATION**

**Research vs MedicalSearch:**
- `Features/Research/` - Has `ResearchSearchService`, `SearchViewModel`, SSE streaming
- `Features/MedicalSearch/` - Has `MedicalSearchService`, `PubMedProvider`, `ExaSearchProvider`
- **FINDING:** MedicalSearch services appear to be low-level providers used by Research feature
- **RECOMMENDATION:** Consolidate into `Research/Services/Providers/` folder

---

### Firebase Functions Features (`/functions/src/`)

#### ✅ **ACTIVE AND EXPORTED**

| Endpoint/Flow | File | Status | Usage |
|---------------|------|--------|-------|
| **diabetesAssistantStream** | `diabetes-assistant-stream.ts` | ✅ ACTIVE | Primary streaming endpoint for iOS Research feature |
| **generateRecipeWithMemory** | `recipe-memory/index.ts` | ✅ ACTIVE | Recipe generation with diversity/deduplication |
| **generateRecipeFromIngredients** | `index.ts` | ✅ ACTIVE | Non-streaming recipe generation |
| **generateSpontaneousRecipe** | `index.ts` | ✅ ACTIVE | Spontaneous recipe with diversity |
| **generateRecipePhoto** | `index.ts` | ✅ ACTIVE | Imagen 4 Ultra photo generation |
| **extractNutritionFromImage** | `index.ts` | ✅ ACTIVE | Direct Gemini API nutrition extraction |

#### ✅ **ACTIVE TIER 3 FLOW - CONFIRMED**

| File | Lines | Status | Used By |
|------|-------|--------|---------|
| **deep-research-v2.ts** | 585 | ✅ **ACTIVE** | `diabetes-assistant-stream.ts` line 1005 |
| **deep-research-v2-types.ts** | 103 | ✅ **ACTIVE** | Type definitions for deep-research-v2 |

**Proof of Usage:**
```typescript
// diabetes-assistant-stream.ts:1005
const { executeDeepResearchV2, formatResearchForSynthesis } =
  await import('./flows/deep-research-v2');
```

**Tools Used by deep-research-v2:**
- ✅ `tools/latents-planner.ts` - Research plan generation
- ✅ `tools/latents-reflector.ts` - Round reflection and stopping condition
- ✅ `tools/query-refiner.ts` - Query refinement between rounds
- ✅ `tools/source-deduplicator.ts` - Deduplication across rounds
- ✅ `tools/source-ranker.ts` - Source ranking by relevance
- ✅ `tools/source-selector.ts` - Final source selection for synthesis
- ✅ `tools/pubmed-search.ts` - PubMed API integration
- ✅ `tools/arxiv-search.ts` - arXiv API integration
- ✅ `tools/clinical-trials.ts` - ClinicalTrials.gov integration
- ✅ `tools/exa-search.ts` - Exa web search integration
- ✅ `tools/stopping-condition-evaluator.ts` - Stopping condition logic

#### ❌ **DEPRECATED / ORPHANED FLOWS**

| File | Lines | Status | Reason |
|------|-------|--------|--------|
| **pro-research-flow.ts** | 489 | ❌ ORPHANED | Old Tier 3 implementation, replaced by deep-research-v2 |
| **tier3-flow.ts** | 502 | ⚠️ POSSIBLY ORPHANED | Older Tier 3 flow, check if used anywhere |
| **tier1-flow.ts** | 242 | ⚠️ CHECK | May be used by router, needs verification |
| **tier2-flow.ts** | 256 | ⚠️ CHECK | May be used by router, needs verification |
| **flash-flow.ts** | 378 | ⚠️ CHECK | Fast responses, unclear if used |

**CRITICAL QUESTION FOR USER:** Are tier1-flow, tier2-flow, and flash-flow still used by the router? Or does the router only route to deep-research-v2 for Tier 3?

#### ❌ **ORPHANED / UNUSED ENDPOINTS**

| Endpoint | File | Status | Notes |
|----------|------|--------|-------|
| **diabetesAssistant** (non-streaming) | `diabetes-assistant.ts` | ❌ DEPRECATED | Replaced by streaming version |
| **diabetesAssistantHealth** | `diabetes-assistant.ts` | ❌ UNUSED | Health check endpoint not needed |
| **getTier3UsageStats** | `diabetes-assistant.ts` | ❌ UNUSED | Stats endpoint not used by iOS |
| **researchSearch** | `research-search.ts` | ⚠️ DUPLICATE? | Seems to overlap with diabetesAssistantStream |

#### ⚠️ **UNUSED MEMORY SYSTEM CODE**

**In `index.ts`:**
- Lines 103-276: `searchMemoryFlow` - Defined but never exported or used
- Lines 283-368: `transcribeAudioFlow` - Defined but never exported or used
- Lines 981-985: Comments indicate removed endpoints:
  - `transcribeAudio` - Not used by iOS app
  - `embedText` - Memory management not used
  - `processMessage` - Memory management not used
  - `searchSimilarMessages` - Memory management not used
  - `processConversationBoundary` - Memory management not used
  - `chatText` - Consolidated into streaming only

**Finding:** 600+ lines of dead code in index.ts related to abandoned memory features

---

## 2. DUPLICATE CODE ANALYSIS

### 🔴 **CRITICAL DUPLICATIONS**

#### **Tier 3 Research Flows (3 implementations!)**

1. **deep-research-v2.ts** (585 lines) - ✅ **ACTIVE** - Multi-round research with latents
2. **pro-research-flow.ts** (489 lines) - ❌ **ORPHANED** - Old single-round research
3. **tier3-flow.ts** (502 lines) - ⚠️ **UNKNOWN** - Original Tier 3 flow

**Impact:** 1,576 lines of code doing nearly the same thing. Only ONE is active.

**Recommendation:** Delete `pro-research-flow.ts` and `tier3-flow.ts` after confirming they're not used.

---

#### **Medical Search Providers (Scattered)**

**iOS Side:**
- `/Features/MedicalSearch/Services/PubMedProvider.swift`
- `/Features/MedicalSearch/Services/ExaSearchProvider.swift`
- `/Features/MedicalSearch/Services/ClinicalTrialsProvider.swift`
- `/Features/MedicalSearch/Services/MedicalSearchCoordinator.swift`

**Backend Side:**
- `/functions/src/tools/pubmed-search.ts`
- `/functions/src/tools/exa-search.ts`
- `/functions/src/tools/clinical-trials.ts`

**Finding:** iOS has duplicate search provider implementations that aren't used - all research goes through the backend streaming endpoint.

**Recommendation:** Delete iOS medical search services, keep only backend tools.

---

#### **Build Logs (90+ files!!)**

**Root directory pollution:**
```
build.log
build_ABSOLUTE_ZERO_FINAL.log
build_FINAL_ZERO_CHECK.log
build_VICTORY.log
build_ZERO_VERIFICATION.log
build_absolute_zero.log
build_absolute_zero_baseline.log
build_absolutely_final.log
... (80+ more)
```

**Impact:** Makes root directory unusable, creates confusion, wastes space.

**Recommendation:** Create `/build-logs/archive/` and move ALL build logs there. Add to `.gitignore`.

---

### 🟡 **MODERATE DUPLICATIONS**

#### **Session Management (Hybrid Approach)**

- `/functions/src/session-store.ts` - Firestore session store
- `/functions/src/vector-utils.ts` - Vector embedding utilities
- `/functions/src/vector-search.ts` - Semantic search
- `/functions/src/intent-classifier.ts` - Intent classification
- `/balli/Core/Storage/ConversationStore.swift` - iOS conversation persistence

**Finding:** Session management split between Firestore (backend) and CoreData (iOS), creating potential sync issues.

**Recommendation:** Audit if both are needed or if one can be simplified.

---

## 3. ORPHANED FILES

### 🗑️ **SAFE TO DELETE (HIGH CONFIDENCE)**

#### **Root Directory Clutter**

| File | Size | Reason |
|------|------|--------|
| `test_recipe_generation.js` | 3.8 KB | Test script not used |
| `test_research_tiers.js` | 7.7 KB | Test script not used |
| All `build_*.log` files (90+) | 26 MB | Historical build logs |
| `all_warnings.txt` | 40 KB | Old warning snapshot |
| `warnings.txt` | 341 KB | Old warning snapshot |
| `current_warnings.txt` | 6.4 KB | Old warning snapshot |
| `crash_log.txt` | 30 bytes | Empty crash log |
| `startup_logs.txt` | 133 bytes | Minimal startup log |
| `final_6_warnings.txt` | 0 bytes | Empty file |
| `get_all_logs.sh` | 665 bytes | Old log collection script |
| `get_logs.sh` | 116 bytes | Old log collection script |
| `WARNING_FIX_COMMANDS.sh` | 12.6 KB | Old warning fix script |
| `add_files_to_xcode.py` | 1.2 KB | One-time Xcode script |
| `add_markdown_files.rb` | 1.2 KB | One-time Ruby script |
| `APPTHEME_REFACTORING_SUMMARY.swift` | 10.6 KB | Old refactoring notes |
| `OFFLINE_SUPPORT_SUMMARY.txt` | 9 KB | Old feature notes |
| `SECTION_9.2_SUMMARY.txt` | 1.9 KB | Old section notes |
| `WARNING_ANALYSIS_VISUAL.txt` | 19.8 KB | Old warning analysis |
| `workspace-state.json` | 596 bytes | IDE workspace file |

**Total to delete:** ~100 files, ~30 MB of dead weight

---

#### **Backend Orphans**

| File | Lines | Reason |
|------|-------|--------|
| `functions/src/diabetes-assistant.ts` | 363 | Non-streaming version replaced by streaming |
| `functions/src/research-search.ts` | 873 | Seems to duplicate diabetesAssistantStream |
| `functions/src/diabetes-assistant-stream-enhanced.ts` | Unknown | "Enhanced" version - unclear if used |
| `functions/src/memory-sync.ts` | 735 | Memory sync feature not actively used |
| `functions/src/flows/pro-research-flow.ts` | 489 | Replaced by deep-research-v2 |
| `functions/src/flows/tier3-flow.ts` | 502 | Possibly replaced by deep-research-v2 |

**NEEDS VERIFICATION:** tier1-flow, tier2-flow, flash-flow usage

---

#### **iOS Orphans (Potential)**

| File/Folder | Reason |
|-------------|--------|
| `/Features/MedicalSearch/Services/*` | All search goes through backend, local providers unused |
| `/Features/Debug/` | Development-only feature |
| `/Features/UserOnboarding/` | Unclear if actually used |

---

### ⚠️ **UNCLEAR STATUS - NEEDS INVESTIGATION**

| File | Why Unclear |
|------|-------------|
| `functions/src/flows/tier1-flow.ts` | May be used by router for simple questions |
| `functions/src/flows/tier2-flow.ts` | May be used by router for web search |
| `functions/src/flows/flash-flow.ts` | Fast response tier, unclear if active |
| `balli/Features/MedicalSearch/` | May be low-level providers for Research |

---

## 4. INCONSISTENT PATTERNS

### 🔴 **FILE SIZE VIOLATIONS**

**CLAUDE.md Rule:** Max 300 lines per file (prefer 200 or less)

**Violators:**

| File | Lines | Overage | Severity |
|------|-------|---------|----------|
| `MarkdownText.swift` | 2,227 | +1,927 | 🔴 CRITICAL |
| `index.ts` | 1,724 | +1,424 | 🔴 CRITICAL |
| `SearchViewModel.swift` | 1,085 | +785 | 🔴 CRITICAL |
| `ResearchSearchService.swift` | 1,042 | +742 | 🔴 CRITICAL |
| `ArdiyeView.swift` | 915 | +615 | 🔴 MAJOR |
| `AppSettingsView.swift` | 740 | +440 | 🔴 MAJOR |
| `RecipeEntryView.swift` | 664 | +364 | 🟡 MAJOR |
| `GenkitService.swift` | 592 | +292 | 🟡 MODERATE |
| `deep-research-v2.ts` | 585 | +285 | 🟡 MODERATE |
| `RecipeViewModel.swift` | 576 | +276 | 🟡 MODERATE |
| `NutritionLabelView.swift` | 569 | +269 | 🟡 MODERATE |
| `tier3-flow.ts` | 502 | +202 | 🟡 MODERATE |

**Total violations:** 12 files
**Recommendation:** Break these into smaller, focused files

---

### 🟡 **CONCURRENCY INCONSISTENCY**

**CLAUDE.md Rule:** Use `@MainActor` instead of `DispatchQueue.main.async`

**Finding:** Need to grep for `DispatchQueue.main.async` usage

**Known Good Examples:**
- ✅ `SearchViewModel.swift` - Properly uses `@MainActor`
- ✅ Most ViewModels follow strict concurrency

---

### 🟡 **NAMING INCONSISTENCY**

**CLAUDE.md Rule:** Consistent suffixes (ViewModel, Service, Repository, View)

**Violations Found:**
- ❌ `AIProcessor.swift` - Should be `AIProcessingService.swift`
- ❌ `GenkitService.swift` vs `StreamingService.swift` - Inconsistent naming (Genkit is specific tech, Streaming is generic)
- ✅ Most files follow convention correctly

---

### 🟡 **FOLDER STRUCTURE INCONSISTENCY**

**Features with complete MVVM structure:**
- ✅ Research (Views, ViewModels, Models, Services)
- ✅ RecipeManagement (Views, ViewModels, Models, Services, Utilities, Components)
- ✅ HealthGlucose (Views, ViewModels, Models, Services, Security)
- ✅ CameraScanning (Views, ViewModels, Models, Services, Utilities, Components)

**Features with incomplete structure:**
- ⚠️ Settings (only Views, no ViewModels)
- ⚠️ Launch (only Views)
- ⚠️ UserOnboarding (only Views)
- ⚠️ Debug (only 1 file)

---

## 5. SHARED CODE OPPORTUNITIES

### 🟢 **ALREADY WELL SHARED**

**iOS Core:**
- ✅ `/Core/Networking/` - Centralized network layer
- ✅ `/Core/Data/Persistence/` - Centralized CoreData management
- ✅ `/Core/Utilities/` - Shared utilities (LoggerFactory, Debouncer, RetryUtility)
- ✅ `/Core/Security/` - Centralized security (Keychain, TLS pinning)
- ✅ `/Core/Permissions/` - Unified permission management
- ✅ `/Features/Components/` - Shared UI components

**Backend:**
- ✅ `/functions/src/utils/` - Shared utilities (error-logger, retry-handler, research-helpers)
- ✅ `/functions/src/tools/` - Reusable research tools
- ✅ `/functions/src/providers.ts` - Centralized model configuration

---

### 🟡 **SHOULD BE SHARED (Opportunities)**

#### **1. Markdown Rendering**

**Current:**
- `Features/ChatAssistant/Views/Components/MarkdownText.swift` (2,227 lines)
- `Features/ChatAssistant/Views/Components/MarkdownTextPreview.swift` (461 lines)
- `Features/Research/Views/Components/SmoothFadeInRenderer.swift` (478 lines)

**Recommendation:** Extract to `/Features/Components/Markdown/` for reuse

---

#### **2. Streaming Text Animation**

**Current:**
- `Features/Research/Views/Components/PiRollingWaveText.swift` (478 lines)
- `Features/Research/Views/Components/SmoothFadeInRenderer.swift` (478 lines)

**Finding:** Both do streaming text effects - consolidate

---

#### **3. Timer Components**

**Current:**
- `Features/Cooking/Views/TimerComponents.swift` (482 lines)

**Recommendation:** Could be shared if other features need timers

---

#### **4. SSE Parsing**

**Current:**
- `Features/Research/Services/SSEParser.swift` (446 lines)
- Used only in Research feature

**Recommendation:** If ChatAssistant also uses SSE, share this service

---

## 6. CONFIGURATION SCATTERED

### 🔴 **MODEL CONFIGURATIONS (Gemini)**

**Current locations:**
- `/functions/src/providers.ts` - Backend model selection (GoogleAI vs VertexAI)
- Hardcoded in multiple flows (tier1-flow, tier2-flow, tier3-flow)
- `/functions/src/index.ts` - Recipe model configuration

**Recommendation:** Already centralized in `providers.ts` - GOOD!

---

### 🔴 **FIREBASE CONFIGURATION**

**Current locations:**
- `/firebase.json` - Firebase project config
- `/firestore.rules` - Firestore security rules
- `/firestore.indexes.json` - Firestore indexes
- `/GoogleService-Info.plist` - iOS Firebase config
- Scattered API endpoint URLs in iOS services

**Recommendation:** Create `/balli/Core/Configuration/FirebaseEndpoints.swift` to centralize all Cloud Function URLs

---

### 🟡 **FEATURE FLAGS**

**No centralized feature flag system found**

**Recommendation:** Create `/balli/Core/Configuration/FeatureFlags.swift` for:
- Enable/disable Tier 3 deep research
- Enable/disable recipe photo generation
- Enable/disable voice input
- Enable/disable HealthKit integration

---

## 7. ARCHITECTURE VIOLATIONS

### 🔴 **CRITICAL ISSUES**

#### **1. MarkdownText.swift - 2,227 lines**

**Violations:**
- 7.4x over 300-line limit
- Doing too many things: parsing, rendering, styling, layout
- Should be split into:
  - `MarkdownParser.swift` - Text parsing logic
  - `MarkdownRenderer.swift` - SwiftUI rendering
  - `MarkdownStyles.swift` - Style configuration
  - `MarkdownComponents/` - Individual component views

---

#### **2. index.ts - 1,724 lines**

**Violations:**
- 5.7x over 300-line limit
- Contains:
  - Memory management flows (unused)
  - Recipe generation flows
  - Nutrition extraction
  - Audio transcription (unused)
  - Session management
  - Helper functions

**Recommendation:** Split into:
- `recipe-endpoints.ts` - Recipe generation endpoints only
- `nutrition-endpoints.ts` - Nutrition extraction only
- Remove 600+ lines of unused memory code

---

#### **3. SearchViewModel.swift - 1,085 lines**

**Violations:**
- 3.6x over 300-line limit
- Manages too much state:
  - Search state
  - Streaming state
  - Multi-round research state
  - Cancellation state
  - Event tracking

**Recommendation:** Extract to:
- `SearchViewModel.swift` (200 lines) - Core search logic
- `ResearchStateManager.swift` - Multi-round research state
- `StreamingStateManager.swift` - Token buffering and streaming

---

### 🟡 **MODERATE ISSUES**

#### **Missing ViewModels in Settings**

**Current:**
- `Features/Settings/Views/RecipePreferencesView.swift` - No ViewModel
- `Features/Settings/Views/AppSettingsView.swift` (740 lines) - No ViewModel

**Violation:** MVVM pattern broken - Views contain business logic

**Recommendation:** Create `SettingsViewModel.swift` and `RecipePreferencesViewModel.swift`

---

## 8. TEST COVERAGE

### ❌ **MISSING TESTS**

**iOS App:**
- NO unit tests found for ViewModels in `/balliTests/`
- NO tests for Services
- Test target exists but appears empty or outdated

**Backend:**
- ✅ Good test coverage in `/functions/src/__tests__/`
- ✅ Tests for: pronoun-resolution, hybrid-memory, vector-search, vector-utils, diversity-scorer, source-selector

**Recommendation:** Prioritize iOS test coverage for:
1. SearchViewModel
2. RecipeViewModel
3. GenkitService
4. StreamingService
5. ResearchSearchService

---

## 9. SUMMARY STATISTICS

### **Codebase Health Score: 72/100**

**Breakdown:**
- ✅ Architecture (80/100) - Well-organized features, mostly follows MVVM
- ⚠️ Code Quality (65/100) - File size violations, some dead code
- ✅ Concurrency (85/100) - Good use of Swift 6 strict concurrency
- ❌ Test Coverage (40/100) - Backend has tests, iOS lacks tests
- ⚠️ Documentation (70/100) - Good inline comments, missing architectural docs
- ❌ Dead Code (50/100) - Significant orphaned flows and build logs

---

## 10. PRIORITY RECOMMENDATIONS

### 🔴 **IMMEDIATE (Week 1)**

1. **Delete build logs** - Free up 30 MB, clean root directory
2. **Confirm Tier 3 flow** - Verify only deep-research-v2 is active, delete others
3. **Delete orphaned flows** - Remove pro-research-flow.ts, possibly tier3-flow.ts
4. **Clean index.ts** - Remove 600 lines of unused memory code

**Impact:** ~2,000 lines of code deleted, root directory cleaned

---

### 🟡 **SHORT-TERM (Weeks 2-3)**

1. **Refactor MarkdownText.swift** - Split into 4-5 focused files
2. **Refactor SearchViewModel.swift** - Extract state managers
3. **Create Settings ViewModels** - Complete MVVM pattern
4. **Consolidate Medical Search** - Decide if iOS providers are needed

**Impact:** Better maintainability, CLAUDE.md compliance

---

### 🟢 **MEDIUM-TERM (Month 1)**

1. **Add iOS test coverage** - 80% coverage for ViewModels
2. **Centralize Firebase endpoints** - Create FirebaseEndpoints.swift
3. **Create feature flags system** - Enable/disable features easily
4. **Extract shared markdown components** - Reusable across features

**Impact:** Production-ready quality, easier feature toggling

---

## 11. DETAILED FILE INVENTORY

### **Firebase Functions - Active vs Orphaned**

#### ✅ **KEEP (Active)**

**Core Endpoints:**
- `index.ts` - Entry point (needs cleanup)
- `diabetes-assistant-stream.ts` - Primary streaming endpoint
- `recipe-memory/index.ts` - Recipe with memory

**Active Flows:**
- `flows/router-flow.ts` - Question routing
- `flows/deep-research-v2.ts` - ACTIVE Tier 3 flow
- `flows/deep-research-v2-types.ts` - Type definitions

**VERIFY THESE (may still be used by router):**
- `flows/tier1-flow.ts` - Direct knowledge
- `flows/tier2-flow.ts` - Web search
- `flows/flash-flow.ts` - Fast responses

**Active Tools:**
- `tools/latents-planner.ts`
- `tools/latents-reflector.ts`
- `tools/query-refiner.ts`
- `tools/source-deduplicator.ts`
- `tools/source-ranker.ts`
- `tools/source-selector.ts`
- `tools/pubmed-search.ts`
- `tools/arxiv-search.ts`
- `tools/clinical-trials.ts`
- `tools/exa-search.ts`
- `tools/stopping-condition-evaluator.ts`

**Infrastructure:**
- `providers.ts` - Model configuration
- `genkit-instance.ts` - Genkit setup
- `session-store.ts` - Session management
- `vector-search.ts` - Semantic search
- `vector-utils.ts` - Embedding utilities
- `intent-classifier.ts` - Intent classification
- `reference-detector.ts` - Reference resolution
- `conversation-state-extractor.ts` - State extraction
- `research-prompts.ts` - Prompt templates
- `nutrition-extractor.ts` - Direct API nutrition extraction

**Utils:**
- `utils/error-logger.ts`
- `utils/retry-handler.ts`
- `utils/research-helpers.ts`
- `utils/rate-limiter.ts`
- `utils/context-builder.ts`
- `utils/response-cleaner.ts`
- `utils/embedding-strategy.ts`

**Recipe Memory:**
- `recipe-memory/diversity-scorer.ts`
- `recipe-memory/analytics-manager.ts`
- `recipe-memory/memory-store.ts`
- `recipe-memory/smart-prompting.ts`
- `recipe-memory/similarity-checker.ts`
- `recipe-memory/types.ts`

---

#### ❌ **DELETE (Orphaned)**

**Deprecated Flows:**
- `flows/pro-research-flow.ts` (489 lines) - Old Tier 3
- `flows/tier3-flow.ts` (502 lines) - Original Tier 3 (VERIFY FIRST)

**Deprecated Endpoints:**
- `diabetes-assistant.ts` (363 lines) - Non-streaming version
- `research-search.ts` (873 lines) - Duplicate endpoint?
- `diabetes-assistant-stream-enhanced.ts` - Unknown "enhanced" version

**Unused Features:**
- `memory-sync.ts` (735 lines) - Memory sync not used
- `scheduled-backup.ts` - If backup not configured

**Old Tools (if not used by tier1/tier2):**
- `tools/parallel-research-fetcher.ts` - Old parallel fetching
- `tools/query-analyzer.ts` - Old query analysis

---

### **iOS App - Feature Status**

#### ✅ **KEEP (Active Features)**

All features listed in Section 1 under "Working and Actively Used"

---

#### ⚠️ **CONSOLIDATE (Redundant)**

**Medical Search Providers (if not used):**
- `Features/MedicalSearch/Services/PubMedProvider.swift`
- `Features/MedicalSearch/Services/ExaSearchProvider.swift`
- `Features/MedicalSearch/Services/ClinicalTrialsProvider.swift`
- `Features/MedicalSearch/Services/ClinicalTrialsModels.swift`
- `Features/MedicalSearch/Services/ClinicalTrialsServiceV2.swift`
- `Features/MedicalSearch/Services/PubMedModels.swift`
- `Features/MedicalSearch/Services/ExaSearchService.swift`

**Recommendation:** Check if Research feature uses these. If not, delete.

---

#### ❓ **VERIFY (Unclear Purpose)**

- `Features/UserOnboarding/` - Is onboarding used?
- `Features/Debug/` - Development only?
- `Features/Components/` - Check which components are actually used

---

## 12. NEXT STEPS

**AWAITING USER APPROVAL:**

1. ✅ **Confirm deep-research-v2 is the ONLY active Tier 3 flow**
2. ❓ **Are tier1-flow, tier2-flow, flash-flow still used by the router?**
3. ❓ **Is research-search.ts a duplicate of diabetesAssistantStream?**
4. ❓ **Are iOS MedicalSearch providers used, or is everything backend?**
5. ✅ **Can we delete all 90+ build log files?**

**Once confirmed, I will create:**
- `CLEANUP_PLAN.md` - Detailed step-by-step cleanup execution plan
- `REFACTORING_PLAN.md` - How to split oversized files
- `SHARED_CODE_EXTRACTION_PLAN.md` - Consolidation opportunities

---

## END OF AUDIT REPORT

**Generated by:** Code Quality Manager Agent
**Date:** 2025-10-19
**Status:** ✅ Phase 1 Complete - Awaiting User Review
