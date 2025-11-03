# Data Architecture Deep Analysis

## Executive Summary

This document provides a comprehensive analysis of the balli app's data persistence and synchronization architecture. The app uses a **triple-layer data strategy**:
1. **CoreData** (local persistence + HealthKit sync)
2. **Firestore** (cloud backup + cross-device sync)
3. **SwiftData** (AI conversation memory + research sessions)

**Overall Assessment:** The architecture is well-designed but has **several incomplete implementations** and **optimization opportunities**.

---

## 📊 Data Layer 1: CoreData (Primary Local Storage)

### Purpose
CoreData serves as the **primary source of truth** for user health data, meals, recipes, and glucose readings. It's optimized for:
- Fast local queries
- Complex relationships
- HealthKit integration
- Offline-first operation

### Entities Mapped (15 total)

| Entity | Purpose | Sync Status | Issues Found |
|--------|---------|-------------|--------------|
| **FoodItem** | Food database with nutrition | ❌ Not synced | Large dataset, no cloud backup |
| **MealEntry** | Meal logs with glucose context | ✅ Firestore sync | foodItem relationship not synced |
| **GlucoseReading** | CGM data from Dexcom/manual | ⚠️ HealthKit only | No Firestore backup |
| **ScanImage** | Photos of nutrition labels | ❌ Not synced | Binary data, no cloud storage |
| **NutritionVariant** | Alternative serving sizes | ❌ Not synced | Orphaned if FoodItem deleted |
| **Recipe** | User/AI-generated recipes | ❌ Not synced | Recipe data loss risk |
| **RecipeHistory** | Recipe generation history | ❌ Not synced | AI insights not preserved |
| **ShoppingListItem** | Shopping list items | ❌ Not synced | Cross-device sync missing |
| **MedicationEntry** | Insulin/medication logs | ❌ Not synced | Critical health data not backed up |
| **MedicationSchedule** | Medication schedules | ❌ Not synced | Reminders lost on device change |
| **UserMedicalProfile** | Medical settings (ICR, CF) | ❌ Not synced | Settings lost on reinstall |
| **FoodLabelHistory** | Historical scans | ❌ Not synced | Audit trail not preserved |
| **HealthChatMessage** | Health chat history | ❌ Not synced | Conversation history lost |
| **HealthEventContext** | Meal/glucose context | ❌ Not synced | Analytics data not preserved |
| **ConversationHealthContext** | Health chat context | ❌ Not synced | Context lost between sessions |
| **HealthNotificationSettings** | Notification config | ❌ Not synced | Settings lost on reinstall |
| **MemoryDecisionLog** | Memory storage decisions | ❌ Not synced | Debugging data not preserved |
| **UserPreferences** | App preferences | ❌ Not synced | Settings reset on reinstall |

### CoreData Configuration

```swift
// Location: /balli/Core/Data/Persistence/CoreDataStack.swift

✅ Strengths:
- Persistent history tracking enabled (line 46-49)
- Automatic migration configured (line 52-53)
- FileProtection.complete for security (line 57-58)
- Automatic merge from parent (line 149)
- Proper context isolation (view + background)
- Migration error recovery (lines 79-110)

⚠️ Weaknesses:
- No CloudKit integration
- No batch import optimization
- Background context creation deferred (may cause issues)
- Staleness interval too aggressive (line 154: 0.0)
```

### Critical Finding: FoodItem Table Growth

**Problem:** FoodItem table grows unbounded. Each scan creates a new entry even for duplicates.

**Impact:**
- Database bloat over time
- Slow queries as table grows
- No deduplication logic
- Memory pressure on older devices

**Recommendation:** Implement barcode-based deduplication in `/balli/Features/CameraScanning/Services/CaptureImageProcessor.swift`

---

## ☁️ Data Layer 2: Firestore (Cloud Sync)

### Purpose
Firestore provides **cloud backup and cross-device sync** for critical health data.

### Current Firestore Schema

```
users/{userId}/
├── meals/{mealId}  ✅ IMPLEMENTED
│   ├── id: UUID
│   ├── timestamp: Timestamp
│   ├── mealType: String
│   ├── consumedCarbs: Double
│   ├── glucoseBefore/After: Double
│   ├── insulinUnits: Double
│   ├── foodItemId: UUID? (reference only)
│   ├── foodItemName: String?
│   ├── lastModified: Timestamp
│   ├── deviceId: String
│   └── firestoreSyncStatus: String
│
├── memory/  ✅ IMPLEMENTED (SwiftData → HTTP sync)
│   ├── facts/{factId}
│   ├── summaries/{summaryId}
│   ├── recipes/{recipeId}
│   └── patterns/{patternId}
│
└── [MISSING COLLECTIONS]
    ├── foodItems/  ❌ NOT IMPLEMENTED
    ├── recipes/  ❌ NOT IMPLEMENTED
    ├── glucoseReadings/  ❌ NOT IMPLEMENTED
    ├── medicationEntries/  ❌ NOT IMPLEMENTED
    ├── userProfile/  ❌ NOT IMPLEMENTED
    └── preferences/  ❌ NOT IMPLEMENTED
```

### Meal Sync Implementation Analysis

**File:** `/balli/Features/FoodArchive/Services/MealFirestoreService.swift`

✅ **Strengths:**
- Bidirectional sync (upload + download)
- Thread-safe data transfer via MealData struct (lines 353-398)
- Conflict resolution based on lastModified timestamp (line 276)
- Batch operations for efficiency (lines 85-102)
- Proper error handling and retry logic
- Device ID tracking for multi-device scenarios (line 246)

⚠️ **Critical Issues:**

1. **TODO on Line 315:** `// TODO: Handle foodItem relationship if foodItemId is provided`
   - **Impact:** Meals sync without their associated food nutrition data
   - **Result:** Incomplete meal data on other devices
   - **Fix Required:** Add foodItem lookup/creation on download

2. **Firestore Query Inefficiency (lines 115-120):**
   ```swift
   var query: Query = db
       .collection("users")
       .document(userId)
       .collection("meals")
       .order(by: "lastModified", descending: true)
       .limit(to: limit)  // Hardcoded to 100
   ```
   - **Problem:** No pagination tokens, always fetches same 100 meals
   - **Impact:** Can't sync beyond 100 most recent meals
   - **Fix Required:** Implement cursor-based pagination

3. **Sync Status Management:**
   - Only tracks `pending`, `synced`, `error` (line 312)
   - No tracking for: deleted, conflicted, partial
   - No sync conflict UI for user resolution

### Meal Sync Coordinator Analysis

**File:** `/balli/Core/Sync/MealSyncCoordinator.swift`

✅ **Strengths:**
- Automatic sync on CoreData changes (lines 66-79)
- Debouncing to reduce API calls (line 39: 5 second delay)
- App activation sync (lines 118-134)
- Pending changes count tracking (line 24)
- Background/foreground sync support

⚠️ **Issues:**

1. **Auto-sync may be too aggressive:**
   - Syncs after EVERY meal save (even while editing)
   - No batching for rapid successive changes
   - Could trigger rate limits with rapid meal logging

2. **Network error handling incomplete:**
   - No exponential backoff
   - No offline queue management
   - Sync errors surface to UI but no auto-retry

3. **Conflict resolution is naive:**
   - Last-write-wins based solely on timestamp (MealSyncConflictResolver)
   - No user conflict resolution UI
   - Can lose data if simultaneous edits on multiple devices

---

## 🧠 Data Layer 3: SwiftData (AI Memory System)

### Purpose
SwiftData stores **AI-generated insights and research sessions** for personalized assistance.

### SwiftData Models (6 models)

| Model | Location | Purpose | Sync Mechanism |
|-------|----------|---------|----------------|
| **PersistentUserFact** | PersistentMemoryModels.swift | User preferences, health facts | ✅ HTTP sync via Cloud Functions |
| **PersistentConversationSummary** | PersistentMemoryModels.swift | Chat summaries | ✅ HTTP sync via Cloud Functions |
| **PersistentRecipePreference** | PersistentMemoryModels.swift | Saved recipes, meal preferences | ✅ HTTP sync via Cloud Functions |
| **PersistentGlucosePattern** | PersistentMemoryModels.swift | Glucose response patterns | ✅ HTTP sync via Cloud Functions |
| **PersistentUserPreference** | PersistentMemoryModels.swift | App preferences (key-value) | ✅ HTTP sync via Cloud Functions |
| **StoredMessage** | ConversationStore.swift | Conversation history | ⚠️ Local only, no sync |
| **ResearchSession** | ResearchSession.swift | Research query sessions | ❌ Local only, no sync |
| **SessionMessage** | SessionMessage.swift | Research conversation | ❌ Local only, no sync |
| **ResearchAnswer** | CoreData entity | Research results | ❌ Local only, no sync |
| **ImageAttachment** | ImageAttachment.swift | Research image attachments | ❌ Local only, no sync |

### Memory Sync Architecture

**File:** `/balli/Core/Services/Memory/Sync/MemorySyncCoordinator.swift`

✅ **Excellent Design:**
- 3 sync triggers: app launch (line 50), background task (line 76), network restore (line 103)
- Non-blocking async operations
- Proper state management (isSyncing flag)
- Background task registration for periodic sync
- Network observer for offline/online transitions

✅ **Sync Service Implementation:**
- HTTP-based sync (no Firebase SDK dependency)
- Separate upload/download services
- Conflict resolution via timestamp comparison
- Retry logic with max attempts (maxRetryCount)
- Sendable-safe data transfers

⚠️ **Issues:**

1. **Research Sessions NOT Synced:**
   - ResearchSession, SessionMessage, ImageAttachment are local-only
   - Users lose research history on device change
   - No cloud backup for expensive AI operations
   - **File:** `/balli/Features/Research/Models/ResearchSessionModelContainer.swift`
   - Uses separate ModelContainer, isolated from memory sync

2. **Conversation Messages NOT Synced:**
   - StoredMessage in ConversationStore is local-only
   - Chat history lost on reinstall
   - No sync implementation despite sync status field (line 34)
   - **TODO:** Implement conversation sync to Firestore

3. **Memory Sync User ID Hardcoded:**
   - Line 62: `let userId = await getCurrentUserId()`
   - No actual implementation, placeholder function
   - Must integrate with Firebase Auth

---

## 🔄 Sync Patterns Analysis

### Pattern 1: CoreData → Firestore (Meal Sync)

```
┌─────────────┐
│  MealEntry  │ CoreData change detected
│  (CoreData) │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ MealSyncCoordinator │ Observes NSManagedObjectContextObjectsDidChange
└──────┬──────────────┘
       │
       │ 5s debounce
       ▼
┌──────────────────────┐
│ MealFirestoreService │ Uploads pending meals
└──────┬───────────────┘
       │
       ▼
┌─────────────┐
│  Firestore  │ users/{userId}/meals/{mealId}
│   (Cloud)   │
└─────────────┘
```

**Strengths:**
- Auto-sync on save
- Debounced to reduce API calls
- Status tracking (pending/synced/error)

**Weaknesses:**
- No pagination for downloads (hardcoded 100 limit)
- FoodItem relationship not synced (TODO line 315)
- No exponential backoff on errors
- Naive conflict resolution

### Pattern 2: SwiftData → Cloud Functions (Memory Sync)

```
┌─────────────────────┐
│ PersistentUserFact  │
│ PersistentSummary   │ SwiftData models
│ PersistentPattern   │
└──────┬──────────────┘
       │
       │ App launch / Background / Network restore
       ▼
┌────────────────────────┐
│ MemorySyncCoordinator  │ Triggers sync
└──────┬─────────────────┘
       │
       ▼
┌────────────────────────┐
│   MemorySyncService    │ HTTP sync (no Firebase SDK)
└──────┬─────────────────┘
       │
       │ Upload: MemorySyncUploader
       │ Download: MemorySyncDownloader
       ▼
┌────────────────────────┐
│   Cloud Functions      │ /syncMemoryUp, /syncMemoryDown
│   (HTTP endpoints)     │
└──────┬─────────────────┘
       │
       ▼
┌─────────────┐
│  Firestore  │ users/{userId}/memory/*
│   (Cloud)   │
└─────────────┘
```

**Strengths:**
- Multiple sync triggers (proactive)
- HTTP-based (no SDK coupling)
- Separate upload/download services
- Conflict resolution via timestamps
- Background task support

**Weaknesses:**
- ResearchSession not included in sync
- StoredMessage not included in sync
- User ID retrieval not implemented (placeholder)
- No sync progress UI

### Pattern 3: Local-Only (No Sync)

**Entities with NO sync:**
- FoodItem (local food database)
- Recipe (user recipes)
- GlucoseReading (except HealthKit)
- MedicationEntry (critical data!)
- UserMedicalProfile (settings)
- RecipeHistory
- ScanImage
- All research models

**Impact:** Data loss on device change/reinstall

---

## 🔴 Critical Issues & TODOs Found

### Issue 1: FoodItem Relationship Not Synced

**Location:** `MealFirestoreService.swift:315`

```swift
// TODO: Handle foodItem relationship if foodItemId is provided
```

**Impact:**
- Meals sync to Firestore with only `foodItemName` string
- No nutrition data for meals on other devices
- Users must rescan foods on each device
- Breaks meal history completeness

**Fix Priority:** 🔴 HIGH

**Recommended Solution:**
1. Create `foodItems` collection in Firestore
2. Sync FoodItem when MealEntry references it
3. On download, fetch/create FoodItem by foodItemId
4. Add FoodItem sync to MealSyncCoordinator

### Issue 2: Hardcoded Pagination Limit

**Location:** `MealFirestoreService.swift:120`

```swift
.limit(to: limit)  // Hardcoded to 100
```

**Impact:**
- Cannot sync more than 100 meals
- Older meals never downloaded to new devices
- No way to fetch meal history beyond 100 entries

**Fix Priority:** 🔴 HIGH

**Recommended Solution:**
Implement cursor-based pagination:
```swift
func downloadMeals(since: Date? = nil, limit: Int = 100, startAfter: DocumentSnapshot? = nil) async throws -> (meals: [FirestoreMeal], lastSnapshot: DocumentSnapshot?)
```

### Issue 3: Research Sessions Not Synced

**Location:** `ResearchSessionModelContainer.swift`

**Impact:**
- Users lose expensive AI research results
- No cloud backup for research sessions
- Cannot access research from other devices
- Image attachments lost on device change

**Fix Priority:** 🟡 MEDIUM

**Recommended Solution:**
1. Integrate ResearchSession into MemorySyncService
2. Upload to `users/{userId}/research/{sessionId}`
3. Store images in Firebase Storage (not inline)
4. Add sync UI in SearchLibraryView

### Issue 4: Medication Data Not Synced

**Location:** `MedicationEntry` + `MedicationSchedule` (CoreData)

**Impact:**
- 🔴 CRITICAL: Health data not backed up
- Medication history lost on device change
- Schedules reset on reinstall
- No cross-device medication tracking

**Fix Priority:** 🔴 CRITICAL

**Recommended Solution:**
1. Create MedicationFirestoreService (similar to MealFirestoreService)
2. Sync to `users/{userId}/medications/{medicationId}`
3. Sync schedules to `users/{userId}/medicationSchedules/{scheduleId}`
4. Add to AppSyncCoordinator

### Issue 5: UserMedicalProfile Not Synced

**Location:** `UserMedicalProfile` (CoreData)

**Impact:**
- ICR (insulin-to-carb ratio) lost on reinstall
- Correction factor reset
- Target blood sugar reset
- Dietary preferences lost

**Fix Priority:** 🟡 MEDIUM-HIGH

**Recommended Solution:**
Sync to `users/{userId}/profile` (single document)

### Issue 6: Conversation History Not Synced

**Location:** `ConversationStore.swift` (StoredMessage)

**Impact:**
- Chat history lost on device change
- No conversation continuity across devices
- Sync status fields exist but unused (line 34)

**Fix Priority:** 🟡 MEDIUM

**Recommended Solution:**
1. Implement ConversationSyncService
2. Sync to `users/{userId}/conversations/{messageId}`
3. Add to MemorySyncCoordinator triggers

### Issue 7: Dexcom Credentials Hardcoded

**Location:** `DexcomConfiguration.swift:244-245`

```swift
username: "dilaraturann21@icloud.com", // TODO: Replace with actual Dexcom username
password: "FafaTuka2117", // TODO: Replace with actual Dexcom password
```

**Impact:**
- 🔴 SECURITY: Credentials exposed in source code
- Violates security best practices
- Git history contains credentials
- Cannot distribute to other users

**Fix Priority:** 🔴 CRITICAL (SECURITY)

**Recommended Solution:**
1. Remove hardcoded credentials immediately
2. Store in Keychain via KeychainService
3. Add Dexcom login UI in DexcomConnectionView
4. Rotate exposed credentials

---

## 📈 Performance Concerns

### 1. Unbounded Table Growth

**Affected Tables:**
- FoodItem (grows with each scan, no deduplication)
- ScanImage (binary data, unbounded)
- GlucoseReading (CGM data every 5 minutes = 288/day)
- MealEntry (grows linearly)

**Impact:**
- Database file size grows indefinitely
- Query performance degrades over time
- Memory pressure on older devices
- Backup/restore becomes slow

**Recommendation:**
Implement data retention policies:
- Archive glucose readings older than 90 days
- Delete scan images older than 30 days (keep FoodItem)
- Implement FoodItem deduplication by barcode

### 2. N+1 Query Problem

**Location:** Various FetchedResultsController usages

**Example:** Loading meals with food items:
```swift
// Current (N+1):
meals.forEach { meal in
    let foodName = meal.foodItem?.name  // Separate query per meal
}
```

**Impact:**
- One query per meal to fetch related FoodItem
- Slow rendering of meal lists
- UI lag on large datasets

**Recommendation:**
Use batch faulting:
```swift
request.relationshipKeyPathsForPrefetching = ["foodItem", "glucoseReadings"]
```

### 3. Image Storage Strategy

**Current:** ScanImage.imageData stored as binary in CoreData

**Issues:**
- CoreData not optimized for binary data
- allowsExternalBinaryDataStorage helps but not enough
- No image compression
- No progressive loading

**Recommendation:**
1. Store images in Documents directory
2. Save file paths in CoreData (not binary)
3. Compress images before storage (JPEG quality 0.7)
4. Implement progressive loading with thumbnails

---

## 🎯 Recommended Architecture Improvements

### Priority 1: Complete Meal Sync (FoodItem)

**Goal:** Sync complete meal nutrition data, not just meal entries

**Steps:**
1. Create `FoodItemFirestoreService`
2. Sync referenced FoodItems when uploading meals
3. Download and reconstruct FoodItems when syncing meals
4. Add FoodItem sync to `MealSyncCoordinator`

**Files to Modify:**
- `/balli/Features/FoodArchive/Services/MealFirestoreService.swift` (implement TODO line 315)
- `/balli/Core/Sync/MealSyncCoordinator.swift` (add FoodItem sync)

### Priority 2: Sync Critical Health Data

**Goal:** Backup medication and medical profile to cloud

**Steps:**
1. Create `MedicationFirestoreService` (pattern: MealFirestoreService)
2. Create `ProfileFirestoreService` for UserMedicalProfile
3. Add to `AppSyncCoordinator`
4. Sync on app launch and daily background task

**Files to Create:**
- `/balli/Features/HealthGlucose/Services/MedicationFirestoreService.swift`
- `/balli/Features/Settings/Services/ProfileFirestoreService.swift`

### Priority 3: Implement Research Session Sync

**Goal:** Preserve expensive AI research results

**Steps:**
1. Add ResearchSession to MemorySyncService
2. Upload to Firestore: `users/{userId}/research/{sessionId}`
3. Store images in Firebase Storage (not inline)
4. Add sync UI in SearchLibraryView (line 175 TODO)

**Files to Modify:**
- `/balli/Core/Networking/Specialized/MemorySyncUploader.swift`
- `/balli/Core/Networking/Specialized/MemorySyncDownloader.swift`
- `/balli/Features/Research/Views/SearchLibraryView.swift`

### Priority 4: Implement Conversation Sync

**Goal:** Enable conversation continuity across devices

**Steps:**
1. Create `ConversationSyncService`
2. Integrate with MemorySyncCoordinator
3. Sync to `users/{userId}/conversations/{messageId}`
4. Add sync status UI

**Files to Modify:**
- `/balli/Core/Storage/ConversationStore.swift` (implement sync methods)
- `/balli/Core/Services/Memory/Sync/MemorySyncCoordinator.swift`

### Priority 5: Add Pagination to Meal Sync

**Goal:** Sync meal history beyond 100 entries

**Steps:**
1. Add cursor-based pagination to `downloadMeals()`
2. Store last sync token
3. Implement incremental sync UI (download more history)

**Files to Modify:**
- `/balli/Features/FoodArchive/Services/MealFirestoreService.swift`

### Priority 6: Security - Remove Hardcoded Credentials

**Goal:** 🔴 CRITICAL - Secure Dexcom credentials

**Steps:**
1. Remove hardcoded credentials from `DexcomConfiguration.swift`
2. Implement Keychain storage
3. Add login UI
4. Rotate exposed credentials
5. Add `.env` file to `.gitignore` for development credentials

**Files to Modify:**
- `/balli/Features/HealthGlucose/Services/DexcomConfiguration.swift`
- `/balli/Features/Settings/Views/DexcomConnectionView.swift`

### Priority 7: Implement Data Retention

**Goal:** Prevent unbounded table growth

**Steps:**
1. Archive old glucose readings (>90 days) to Firestore
2. Delete old scan images (>30 days), keep FoodItems
3. Implement FoodItem deduplication by barcode
4. Add "Free Up Space" in app settings

**Files to Create:**
- `/balli/Core/Services/DataRetentionService.swift`

**Files to Modify:**
- `/balli/Features/Settings/Views/AppSettingsView.swift` (add data management section)

---

## 🏗️ Alternative Architecture: Single Source of Truth

### Current (Fragmented):
```
CoreData ←→ Firestore (meals only)
SwiftData ←→ Cloud Functions (memory only)
Research ←→ [NO SYNC]
```

### Proposed (Unified):
```
                  ┌─────────────────┐
                  │   Firestore     │
                  │  (Single Truth) │
                  └────────┬────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
┌────────────────┐  ┌─────────────┐  ┌──────────────┐
│    CoreData    │  │  SwiftData  │  │   Storage    │
│ (Local cache + │  │  (AI memory │  │  (Images)    │
│  relationships)│  │   + search) │  │              │
└────────────────┘  └─────────────┘  └──────────────┘
```

**Benefits:**
- Firestore as single source of truth
- CoreData as local cache with relationships
- SwiftData for AI-specific queries (vectors, semantic search)
- Clear sync strategy for all data types

**Migration Path:**
1. Implement Firestore collections for all entities
2. Use CoreData for local caching only
3. Firestore sync becomes the primary sync mechanism
4. SwiftData remains for AI memory (already separate)

---

## 📝 Summary & Action Items

### Current State

| Component | Status | Sync | Issues |
|-----------|--------|------|--------|
| Meals | ✅ Good | ✅ Firestore | FoodItem not synced |
| AI Memory | ✅ Good | ✅ Cloud Functions | Complete |
| Research | ⚠️ Incomplete | ❌ No sync | Local only |
| Medications | ❌ Missing | ❌ No sync | Critical data at risk |
| Profile | ❌ Missing | ❌ No sync | Settings lost |
| FoodItems | ⚠️ Bloated | ❌ No sync | No deduplication |
| Conversations | ⚠️ Incomplete | ❌ No sync | History lost |
| Recipes | ⚠️ No backup | ❌ No sync | User data at risk |

### Action Items by Priority

#### 🔴 Critical (Do Immediately)
1. **Remove hardcoded Dexcom credentials** (SECURITY)
2. **Implement medication sync** (critical health data)
3. **Fix FoodItem relationship sync** (meal data completeness)
4. **Add pagination to meal sync** (data loss beyond 100 entries)

#### 🟡 High (Do This Sprint)
5. **Sync UserMedicalProfile** (settings preservation)
6. **Sync research sessions** (preserve expensive AI results)
7. **Implement conversation sync** (cross-device continuity)
8. **Add data retention policies** (prevent bloat)

#### 🟢 Medium (Do Next Sprint)
9. **Sync recipes** (user content preservation)
10. **Implement FoodItem deduplication** (database optimization)
11. **Add conflict resolution UI** (user control over conflicts)
12. **Improve error handling** (exponential backoff, auto-retry)

#### 🔵 Low (Future Optimization)
13. **Migrate to unified Firestore architecture**
14. **Implement image compression**
15. **Add batch faulting for relationships**
16. **Create data export feature** (GDPR compliance)

---

## 🔍 Code Quality Assessment

### Strengths
✅ Well-structured actor-based sync coordinators
✅ Thread-safe data transfer via value types
✅ Proper Swift 6 concurrency compliance
✅ Comprehensive error logging
✅ Offline-first design

### Weaknesses
⚠️ Incomplete sync implementations (7 TODOs found)
⚠️ No pagination for large datasets
⚠️ Hardcoded credentials (SECURITY)
⚠️ Fragmented sync strategies (CoreData vs SwiftData)
⚠️ No conflict resolution UI

### Technical Debt
- 7 TODOs in production code
- 18+ entities with no cloud backup
- Hardcoded credentials in source
- No data retention policies
- Missing pagination
- Naive conflict resolution

---

## 📚 References

**Files Analyzed:**
- `/balli/Core/Data/Persistence/CoreDataStack.swift`
- `/balli/Features/FoodArchive/Services/MealFirestoreService.swift`
- `/balli/Core/Sync/MealSyncCoordinator.swift`
- `/balli/Core/Services/Memory/Sync/MemorySyncCoordinator.swift`
- `/balli/Core/Storage/ConversationStore.swift`
- `/balli/Core/Storage/Memory/PersistentMemoryModels.swift`
- `/balli/Features/Research/Models/ResearchSessionModelContainer.swift`
- `/balli/balli.xcdatamodeld/balli.xcdatamodel/contents` (CoreData schema)

**TODOs Found:**
1. MealFirestoreService.swift:315 - foodItem relationship
2. VoiceInputView.swift:555 - Firebase Auth user ID
3. DexcomConfiguration.swift:244-245 - Hardcoded credentials
4. RecipePhotoGenerationCoordinator.swift:98 - Auth user ID
5. SearchLibraryView.swift:175 - Research navigation
6. SessionMetadataGenerator.swift - Backend implementation (3 TODOs)
7. ResearchSearchCoordinator.swift:56 - Deep research disabled

---

**Date:** 2025-11-03
**Author:** AI Architecture Analysis
**Status:** Complete
