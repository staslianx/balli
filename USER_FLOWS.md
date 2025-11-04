# Critical User Flows - balli App

## Overview
This document describes the 5 critical user flows in the balli diabetes management app, including happy paths, error states, recovery procedures, and expected performance metrics.

**Last Updated**: 2025-01-04
**Primary User**: Dilara (Type 1 Diabetes)
**Platform**: iOS 26+, Swift 6

---

## Flow 1: Dexcom Connection & Glucose Sync

### Entry Point
**Settings → Dexcom Connection**

### Happy Path

1. **User taps "Connect to Dexcom"**
   - Entry: `DexcomConnectionView` → `connectWithDexcom()` method
   - File: `balli/Features/HealthGlucose/Views/DexcomConnectionView.swift`

2. **OAuth flow opens in Safari**
   - `DexcomService` initiates OAuth
   - File: `balli/Features/HealthGlucose/Services/DexcomService.swift:227`
   - URL: `https://api.dexcom.com/v2/oauth2/login`

3. **User logs into Dexcom Share account**
   - External: Dexcom OAuth page
   - User enters Dexcom credentials
   - User grants permissions

4. **App receives OAuth tokens**
   - Callback URL captured
   - Access token + refresh token received
   - File: `DexcomService.swift:handleOAuthCallback(_:)`

5. **Tokens stored in Keychain**
   - Secure storage via `SecItemAdd`
   - Keys: `dexcom_access_token`, `dexcom_refresh_token`
   - File: `DexcomService.swift:saveTokens(_:)`

6. **First sync starts automatically**
   - Background: `DexcomBackgroundRefreshManager.swift:scheduleNextRefresh()`
   - Fetches last 24 hours of glucose readings
   - File: `DexcomService.swift:fetchGlucoseReadings()`

7. **Dashboard shows glucose data**
   - View: `GlucoseDashboardView`
   - Components:
     - Current glucose reading (large number)
     - Trend arrow (↑ ↗ → ↘ ↓)
     - Time in range chart
     - Recent readings list

8. **Background sync scheduled**
   - Interval: Every 4 hours
   - Service: `DexcomBackgroundRefreshManager`
   - Uses `BGTaskScheduler` for background execution

### Error States

#### OAuth Cancelled
- **Trigger**: User taps "Cancel" in Safari
- **Behavior**: Returns to DexcomConnectionView
- **UI**: Toast shows "Connection cancelled. Try again when ready."
- **Recovery**: User can retry immediately
- **File**: `DexcomConnectionView.swift:154`

#### Invalid Credentials
- **Trigger**: Wrong Dexcom username/password
- **Behavior**: OAuth fails with 401 error
- **UI**: Alert shows "Login failed. Please check your Dexcom Share credentials."
- **Recovery**: Retry button in alert
- **File**: `DexcomService.swift:handleOAuthCallback(_:)`

#### Network Offline
- **Trigger**: No internet during OAuth or sync
- **Behavior**: URLSession timeout after 30s
- **UI**: Alert shows "No internet connection. Please connect to Wi-Fi or cellular."
- **Recovery**: Auto-retry when network restored
- **File**: `DexcomService.swift` catch block

#### Token Expired
- **Trigger**: Access token expires (typically after 2 hours)
- **Behavior**: Auto-refresh using refresh token
- **UI**: No UI (happens silently)
- **Fallback**: If refresh fails, prompts reconnection
- **File**: `DexcomService.swift:refreshAccessTokenIfNeeded()`

#### Dexcom API Rate Limit
- **Trigger**: Too many requests (>600/day)
- **Behavior**: API returns 429 status
- **UI**: Shows "Rate limit reached. Please try again in 1 hour."
- **Recovery**: Automatic retry after cooldown period
- **File**: `DexcomService.swift` catch block

### Recovery Procedures

**"I can't see my glucose data"**
1. Check Dexcom connection: Settings → Dexcom Connection
2. Verify internet connection (Wi-Fi or cellular)
3. Try manual refresh: Pull down on GlucoseDashboardView
4. Check Dexcom Share app (ensure data is uploading)
5. If still failing: Tap "Reconnect" in Settings

**"My glucose sync stopped working"**
1. Check token expiration: Settings → Debug → View Token Status
2. Token expired? Tap "Reconnect to Dexcom"
3. Background refresh disabled? Enable in Settings → Background App Refresh
4. If persistent: Force quit app, reopen, allow 1 minute for sync

### Expected Behavior

**Timing**:
- Initial OAuth flow: 10-30 seconds (depends on user speed)
- First sync after connection: 5-10 seconds
- Background sync: <5 seconds
- Token refresh: <2 seconds (silent)

**Data Retention**:
- Local CoreData cache: 90 days
- Firestore sync: All time
- Dexcom API provides: Last 90 days

**Offline Mode**:
- Shows cached glucose data with timestamp
- Banner: "Offline - Last updated X minutes ago"
- Retries sync when network restored

**Background Refresh**:
- Frequency: Every 4 hours (configurable)
- Battery-efficient: Uses `BGAppRefreshTask`
- Wakes app in background for 30s max

---

## Flow 2: Recipe Generation

### Entry Point
**Home → Purple + Button → Recipe Generation**

### The 4 Generation Flows

Recipe generation has **4 distinct flows** based on what input the user provides. The app intelligently routes to the appropriate flow using `RecipeGenerationFlowCoordinator`.

#### Flow 1: Empty State (No Input)

**User Action**: Taps purple + button with no ingredients or notes

**Flow**:
1. **Meal selection modal appears**
   - File: `RecipeGenerationView.swift:showMealSelectionModal`
   - Options: Kahvaltı, Öğle Yemeği, Akşam Yemeği, Atıştırmalık
   - Subcategories (if applicable): Salata, Sıcak Yemek, Çorba, etc.

2. **User selects meal type + style**
   - Example: "Akşam Yemeği" → "Sıcak Yemek"
   - Button enabled after selection
   - File: `RecipeGenerationView.swift:227`

3. **AI generates recipe using memory for variety**
   - Service: `RecipeGenerationCoordinator.swift:generateSpontaneous()`
   - Memory: Last 5 recipes fetched to avoid repetition
   - Diversity constraints: Avoids recently used proteins
   - File: `RecipeGenerationCoordinator.swift:490`

4. **Streaming text appears in real-time**
   - SSE (Server-Sent Events) from Cloud Function
   - View: `RecipeGenerationView` → `processStreamingEvent()`
   - Updates every ~50ms as tokens arrive
   - File: `RecipeStreamingService.swift:183`

5. **Recipe displays with Save button**
   - Shows: Name, ingredients, instructions, story, nutrition
   - Save button enabled once generation completes
   - File: `RecipeGenerationView.swift:138`

#### Flow 2: Ingredients Only

**User Action**: Adds ingredients (e.g., "2 yumurta, 1 domates"), taps generate

**Flow**:
1. **Meal selection modal appears**
   - Reason: Ingredients alone are ambiguous
   - Could be breakfast, lunch, or dinner
   - File: `RecipeGenerationFlowCoordinator.swift:66`

2. **User selects meal type + style**
   - AI will use selected context + provided ingredients
   - Example: "Kahvaltı" → "Yumurtalı Tarifler"

3. **AI generates recipe USING provided ingredients**
   - Service: `RecipeGenerationCoordinator.swift:generateWithIngredients()`
   - Ingredients passed as required components
   - File: `RecipeGenerationCoordinator.swift:316`

4. **Recipe includes nutrition info**
   - Nutrition calculated from ingredients
   - Shows: Carbs, protein, fat, fiber, calories
   - File: Recipe includes `nutritionalValues` field

5. **Save button appears**
   - Recipe stored with ingredients as user-provided
   - CoreData entity: `Recipe` with `userIngredients` field

#### Flow 3: Notes Only (Explicit Intent)

**User Action**: Writes notes (e.g., "diabetes-friendly tiramisu"), taps generate

**Flow**:
1. **SKIPS meal selection modal** ✨
   - Reason: Notes contain explicit intent
   - User knows what they want
   - File: `RecipeGenerationFlowCoordinator.swift:77`

2. **AI generates recipe respecting notes**
   - Service: `RecipeGenerationCoordinator.swift:generateSpontaneous()`
   - Notes passed as `userContext` parameter
   - Generic defaults: mealType = "Akşam Yemeği", styleType = "Genel"
   - File: `RecipeGenerationCoordinator.swift:490`

3. **Recipe follows user's specific request**
   - Example: "diabetes-friendly tiramisu"
   - Result: Tiramisu with sugar alternatives, low-carb ladyfingers
   - Respects dietary constraints from notes

4. **Save button appears**
   - Recipe stored with notes as context
   - CoreData field: `personalNotes`

#### Flow 4: Ingredients + Notes (Maximum Personalization)

**User Action**: Adds ingredients + writes notes, taps generate

**Flow**:
1. **SKIPS meal selection modal** ✨
   - Reason: User is being very specific
   - Both what (ingredients) and how (notes)
   - File: `RecipeGenerationFlowCoordinator.swift:89`

2. **AI generates recipe using ingredients + respecting notes**
   - Service: `RecipeGenerationCoordinator.swift:generateWithIngredients()`
   - Both ingredients AND notes passed
   - Most constrained generation
   - File: `RecipeGenerationCoordinator.swift:316`

3. **Highly personalized output**
   - Example: Ingredients "2 tavuk göğsü, 100g mantar" + Notes "yağsız, baharatlı"
   - Result: Grilled chicken with mushrooms, heavy spices, no oil

4. **Save button appears**
   - Recipe stored with both ingredients and notes
   - Maximum context preservation

### Saving Flow (All Flows)

1. **User taps Save button**
   - File: `RecipeGenerationViewModel.swift:saveRecipe()`
   - Creates `Recipe` CoreData entity

2. **Recipe saves to CoreData**
   - Entity: `Recipe` with all fields
   - Timestamp: `createdDate = Date()`
   - File: `RecipeDataManager.swift:saveRecipe(_:)`

3. **Photo URL downloads (if generated)**
   - Service: `RecipeGenerationService.swift:generateRecipePhoto()`
   - Async download, doesn't block save
   - Stored as `recipePhotoURL` field

4. **Sync to Firestore starts in background**
   - Service: `RecipeSyncCoordinator.swift:syncLocalChangesToFirestore()`
   - Detached Task (doesn't block UI)
   - File: `RecipeSyncCoordinator.swift:100`

5. **Success confirmation appears**
   - Toast: "Tarif kaydedildi ✓"
   - Duration: 2 seconds
   - File: `RecipeGenerationView.swift:saveRecipe()`

6. **Recipe appears in recipe list**
   - View: `RecipeListView`
   - Sorted by: `createdDate` descending
   - File: `RecipeListView.swift`

### Error States

#### Generation Fails
- **Trigger**: AI model error, network timeout, rate limit
- **Behavior**: Streaming stops, error event received
- **UI**: Alert shows "Recipe generation failed. Please try again."
- **Recovery**: Retry button in alert
- **File**: `RecipeStreamingService.swift:185` (error event)

#### Save Fails (CoreData)
- **Trigger**: CoreData save error (rare)
- **Behavior**: Exception caught in `saveRecipe()`
- **UI**: Alert shows "Failed to save recipe. Please try again."
- **Recovery**: User can retry save
- **File**: `RecipeGenerationViewModel.swift:saveRecipe()` catch block

#### Photo Download Fails
- **Trigger**: Image URL unreachable or timeout
- **Behavior**: Recipe saves WITHOUT photo
- **UI**: No error shown (photo is optional)
- **Fallback**: Default gradient background used
- **File**: `RecipeHeroImageSection.swift:64`

#### Firestore Sync Fails
- **Trigger**: No internet, Firestore offline
- **Behavior**: Queued for offline sync
- **UI**: No immediate error (happens in background)
- **Recovery**: Auto-syncs when network restored
- **File**: `RecipeSyncCoordinator.swift:syncLocalChangesToFirestore()`

### Edge Cases

**Edge Case 1**: User writes notes AFTER generating recipe
- **Expected**: Treats notes as personal notes, not generation prompts
- **Behavior**: If regenerate tapped, shows meal selection (notes ambiguous at this point)
- **File**: `RecipeGenerationFlowCoordinator.swift:66`

**Edge Case 2**: User adds invalid ingredients (e.g., "asdfjkl;")
- **Expected**: AI rejects or ignores invalid ingredients
- **Behavior**: Generates recipe with valid subset OR shows clarification
- **File**: Cloud Function validates and filters ingredients

**Edge Case 3**: User requests impossible recipe (e.g., "sugar-free cake with 100g sugar")
- **Expected**: AI resolves contradiction or asks for clarification
- **Behavior**: Prioritizes dietary constraint (makes sugar-free)
- **File**: Cloud Function prompt includes conflict resolution

### Expected Performance

| Stage | Expected Duration | Acceptable Range |
|-------|-------------------|------------------|
| Meal selection UI | Instant | <100ms |
| Stream connection | 1-2 seconds | Up to 5s |
| First token arrival | 2-3 seconds | Up to 5s |
| Full recipe generation | 5-10 seconds | Up to 15s |
| Save to CoreData | <500ms | Up to 2s |
| Photo download | 2-5 seconds | Up to 10s (async) |
| Firestore sync | 1-3 seconds | Up to 10s (background) |

---

## Flow 3: Medical Research

### Entry Point
**Research Tab → Question Input Field**

### Tier System

The app offers **3 research tiers** with different speed/depth tradeoffs:

- **Tier 1 (Hızlı)**: <10 seconds, cached answers, free
- **Tier 2 (Araştırma)**: 15-30 seconds, PubMed + web search
- **Tier 3 (Derin)**: 30-60 seconds, comprehensive multi-source analysis

### Happy Path

1. **User types question**
   - View: `InformationRetrievalView.swift:89`
   - TextField: Auto-focuses, supports multi-line
   - Example: "Tip 1 diyabetlilerde egzersizin HbA1c üzerine etkisi nedir?"

2. **User selects tier (or auto-detects)**
   - Selection: Segmented control with 3 options
   - Auto-detect: Complex questions → Tier 2/3, simple → Tier 1
   - File: `MedicalResearchViewModel.swift:selectTier(_:)`

3. **User taps search button**
   - Button: Disabled if question empty
   - Action: `submitResearchQuestion()`
   - File: `InformationRetrievalView.swift:142`

4. **Loading animation appears**
   - View: Shimmer effect on answer card
   - Progress: "Kaynak aranıyor..." → "Analiz ediliyor..."
   - File: `AnswerCardView.swift:62`

5. **Answer streams in real-time**
   - SSE: Server-Sent Events from Cloud Function
   - Markdown: Rendered with proper formatting (bold, italic, lists)
   - Chunks: Arrive every ~100-200ms
   - File: `MedicalResearchViewModel.swift:submitResearchQuestion()`

6. **Sources appear as pills below answer**
   - Pills: Colored badges (PubMed=purple, Clinical=blue, Web=gray)
   - Clickable: Opens source URL in Safari
   - File: `AnswerCardView.swift:201`

7. **User can highlight important text**
   - Selection: Long-press or drag on text
   - Highlighter button: Appears in toolbar
   - Colors: 5 vibrant options
   - File: `HighlightManager.swift:highlightSelection(_:)`

8. **User can save highlights**
   - Storage: SwiftData `TextHighlight` entity
   - Persistence: Survives app restart
   - File: `HighlightManager.swift:88`

9. **Session saved for history**
   - Entity: `ResearchSession` with messages
   - History: Accessible from "History" tab
   - File: `ResearchSessionManager.swift:saveSession()`

### Error States

#### Empty Question
- **Trigger**: User taps search with empty text field
- **Behavior**: Validation prevents submission
- **UI**: TextField shake animation + error message
- **Message**: "Lütfen bir soru girin"
- **File**: `InformationRetrievalView.swift:142`

#### Network Failure (Before Stream Starts)
- **Trigger**: No internet when tapping search
- **Behavior**: URLSession fails immediately
- **UI**: Alert "İnternet bağlantısı yok. Lütfen kontrol edin."
- **Recovery**: Retry button in alert
- **File**: `MedicalResearchViewModel.swift` catch block

#### Network Failure (During Stream)
- **Trigger**: Internet drops while streaming
- **Behavior**: Stream breaks, no more chunks arrive
- **UI**: Shows partial answer + error banner
- **Message**: "Bağlantı kesildi. Kısmi sonuçlar gösteriliyor."
- **Recovery**: Retry button in banner
- **File**: `ResearchStreamProcessor.swift:handleStreamError(_:)`

#### Tier Timeout
- **Trigger**: Tier 3 takes too long (>60s)
- **Behavior**: Auto-fallback to Tier 2 results
- **UI**: Toast "Derin araştırma zaman aşımına uğradı. Hızlı sonuçlar gösteriliyor."
- **Recovery**: Automatic, user sees partial results
- **File**: Cloud Function timeout handling

#### AI Failure (Model Error)
- **Trigger**: Gemini API error, rate limit, or crash
- **Behavior**: Error event received from stream
- **UI**: Alert "Araştırma başarısız oldu. Lütfen tekrar deneyin."
- **Recovery**: Retry button
- **File**: `MedicalResearchViewModel.swift:handleError(_:)`

### Recovery Procedures

**"My question didn't return results"**
1. Check internet connection
2. Simplify question (remove complex medical terms)
3. Try different tier (Tier 1 for simple questions)
4. Rephrase question in Turkish or English

**"The answer stopped mid-sentence"**
1. Check network stability
2. Retry with same question
3. Try lower tier for faster completion
4. If persistent: Report issue with screenshot

**"I can't find my previous questions"**
1. Check History tab
2. Session saving enabled? Settings → Research → Save History
3. If empty: Previous sessions may have been cleared
4. Manual recovery: Check Firestore `research_sessions` collection

### Expected Performance

| Tier | Expected Duration | Sources | Accuracy |
|------|-------------------|---------|----------|
| Tier 1 (Hızlı) | <10 seconds | Cached, OpenAI | Good for general questions |
| Tier 2 (Araştırma) | 15-30 seconds | PubMed, Web, ArXiv | High for medical questions |
| Tier 3 (Derin) | 30-60 seconds | All sources + deep analysis | Highest for complex topics |

**Streaming Performance**:
- First token: 2-5 seconds
- Token rate: 30-50 tokens/second
- Chunk size: 5-10 tokens
- Update frequency: Every 100-200ms

---

## Flow 4: Food Entry & Meal Logging

### Entry Point
**Home → Camera Button → Capture Meal**

### Happy Path

1. **User taps camera button**
   - Location: Bottom navigation bar
   - Icon: Camera symbol
   - File: `ContentView.swift:cameraButton`

2. **Camera opens with meal capture mode**
   - View: `CameraView` with meal detection overlay
   - Features: Grid lines, flash control, gallery access
   - Permissions: Prompts for camera access if needed
   - File: `CameraView.swift`

3. **User captures photo of meal**
   - Action: Tap shutter button
   - Feedback: Shutter sound + flash animation
   - Processing: Photo saved to temp directory
   - File: `CameraView.swift:capturePhoto()`

4. **Image uploads to Cloud Storage**
   - Service: Firebase Storage
   - Path: `/meal-images/{userId}/{timestamp}.jpg`
   - Progress: Shows upload progress bar
   - File: `MealCaptureService.swift:uploadImage(_:)`

5. **AI extracts nutrition data**
   - Service: Cloud Function `extractNutritionFromImage`
   - Model: Gemini Vision + USDA FoodData API
   - Extracts: Food items, portions, estimated nutrition
   - File: Cloud Function `functions/src/index.ts:extractNutritionFromImage`

6. **Meal entry created with timestamp**
   - Entity: `MealEntry` CoreData entity
   - Fields: photo, timestamp, foods, nutrition, notes
   - File: `MealEntryRepository.swift:createEntry(_:)`

7. **Shows estimated impact score**
   - Calculation: Based on carbs, GI index, user insulin sensitivity
   - Score: 1-10 (low to high glucose impact)
   - Color: Green (1-3), Yellow (4-6), Red (7-10)
   - File: `ImpactScoreCalculator.swift:calculate(_:)`

8. **Saves to CoreData**
   - Storage: Local CoreData database
   - Persistence: Immediate save
   - File: `MealEntryRepository.swift:save()`

9. **Syncs to Firestore**
   - Background: Async upload to Firestore
   - Path: `/users/{userId}/meals/{mealId}`
   - Queued if offline
   - File: `MealSyncCoordinator.swift:syncToFirestore(_:)`

### Error States

#### Camera Permission Denied
- **Trigger**: User denies camera access
- **Behavior**: Alert prompts to Settings
- **UI**: "Kamera erişimi gerekli. Ayarlar'dan izin verin."
- **Recovery**: Button opens Settings app
- **File**: `CameraView.swift:checkPermissions()`

#### Photo Upload Fails
- **Trigger**: No internet, Storage quota exceeded
- **Behavior**: Saves locally, queues for retry
- **UI**: Toast "Fotoğraf yüklenemedi. Otomatik olarak tekrar denenecek."
- **Recovery**: Auto-retry when network restored
- **File**: `MealCaptureService.swift:uploadImage(_:)` catch block

#### AI Extraction Fails
- **Trigger**: Unrecognizable food, poor image quality
- **Behavior**: Shows manual entry option
- **UI**: "Yemek tanınamadı. Manuel olarak girmek ister misiniz?"
- **Recovery**: Button opens manual nutrition entry form
- **File**: `NutritionExtractionView.swift:showManualEntry()`

#### Network Offline During Capture
- **Trigger**: Airplane mode, no data connection
- **Behavior**: Saves locally, disables cloud features
- **UI**: Banner "Çevrimdışı - Veriler daha sonra senkronize edilecek"
- **Recovery**: Auto-sync when network restored
- **File**: `NetworkMonitor.swift:isConnected`

#### Insufficient Storage
- **Trigger**: Device storage full
- **Behavior**: Alert prompts to free space
- **UI**: "Depolama alanı yetersiz. Lütfen yer açın."
- **Recovery**: User must delete files/apps
- **File**: `MealCaptureService.swift:checkStorageAvailable()`

### Expected Performance

| Stage | Expected Duration |
|-------|-------------------|
| Camera open | <500ms |
| Capture photo | Instant |
| Upload to Storage | 2-5 seconds |
| AI nutrition extraction | 5-10 seconds |
| Impact score calculation | <500ms |
| CoreData save | <500ms |
| Firestore sync | 1-3 seconds (background) |

---

## Flow 5: Data Export & Analysis

### Entry Point
**Settings → Data Privacy → Export Data**

### Happy Path

1. **User taps "Export Data"**
   - View: `DataPrivacyView.swift`
   - Button: "Verilerimi Dışa Aktar"
   - File: `DataPrivacyView.swift:exportData()`

2. **Loading indicator appears**
   - View: Progress spinner with message
   - Text: "Verileriniz hazırlanıyor..."
   - File: `DataPrivacyView.swift:isExporting = true`

3. **Generates Correlation CSV (Glucose + Meals)**
   - Service: `CorrelationCSVGenerator.swift:generate()`
   - Data: Glucose readings + meal timestamps + carbs
   - Format: CSV with headers (timestamp, glucose, meal, carbs, impact)
   - File: `CorrelationCSVGenerator.swift:66`

4. **Generates Event JSON (All Events)**
   - Service: `EventJSONGenerator.swift:generate()`
   - Data: All events (meals, insulin, exercise, notes)
   - Format: JSON array with event objects
   - File: `EventJSONGenerator.swift:45`

5. **Shows share sheet**
   - View: Native `UIActivityViewController`
   - Files: correlation.csv, events.json
   - Options: AirDrop, Files app, Mail, Messages
   - File: `DataPrivacyView.swift:showShareSheet()`

6. **User saves to Files or shares via AirDrop**
   - Destination: iCloud Drive, local Files, or shared device
   - Completion: Toast "Veriler dışa aktarıldı ✓"

### Error States

#### No Data to Export
- **Trigger**: User has no glucose readings or meals
- **Behavior**: Validation prevents export
- **UI**: Alert "Dışa aktarılacak veri yok. Verileriniz senkronize olduğundan emin olun."
- **Recovery**: User must add data first
- **File**: `ExportDataRepository.swift:hasData()`

#### Export Generation Fails
- **Trigger**: CoreData query error, formatting error
- **Behavior**: Error caught in export service
- **UI**: Alert "Veri dışa aktarılamadı. Lütfen tekrar deneyin."
- **Recovery**: Retry button
- **File**: `CorrelationCSVGenerator.swift` catch block

#### Insufficient Storage for Export
- **Trigger**: Device storage full, can't create temp files
- **Behavior**: File creation fails
- **UI**: Alert "Yetersiz depolama alanı. Lütfen yer açın."
- **Recovery**: User must free storage
- **File**: `ExportDataRepository.swift:checkStorage()`

#### Share Sheet Dismissed
- **Trigger**: User cancels share sheet
- **Behavior**: Export files deleted from temp directory
- **UI**: No error (expected behavior)
- **Cleanup**: Automatic temp file deletion
- **File**: `DataPrivacyView.swift:shareSheetDismissed()`

### Expected Performance

| Stage | Expected Duration |
|-------|-------------------|
| Export button tap | Instant |
| Fetch data from CoreData | 1-2 seconds |
| Generate CSV | 2-5 seconds |
| Generate JSON | 1-3 seconds |
| Show share sheet | <500ms |
| **Total** | **5-10 seconds** |

---

## Critical Error Handling Patterns

### Network Errors

#### Offline Mode
- **Detection**: `NetworkMonitor` observes `NWPathMonitor`
- **Behavior**: Show cached data + "Offline" banner
- **Banner**: Top of screen, yellow background
- **Text**: "Çevrimdışı - Son güncelleme: X dakika önce"
- **Auto-dismiss**: When network restored
- **File**: `NetworkMonitor.swift:startMonitoring()`

#### Timeout
- **Duration**: 30 seconds for API calls, 60s for AI
- **Behavior**: Retry 3 times with exponential backoff
- **Backoff**: 1s, 2s, 4s delays
- **After 3 failures**: Show error to user
- **File**: All service classes use `URLSession` with timeouts

#### Connection Reset
- **Trigger**: Server closes connection mid-request
- **Behavior**: Treat as network offline
- **Recovery**: Auto-retry when network stable
- **File**: Network error handling in all services

### Authentication Errors

#### Token Expired
- **Detection**: Firebase Auth token older than 1 hour
- **Behavior**: Auto-refresh using refresh token
- **Silent**: No UI, happens in background
- **Fallback**: If refresh fails, prompt re-authentication
- **File**: `LocalAuthenticationManager.swift:refreshToken()`

#### Invalid Token
- **Trigger**: Malformed token, revoked access
- **Behavior**: Clear stored tokens, prompt re-login
- **UI**: Alert "Oturum süreniz doldu. Lütfen tekrar giriş yapın."
- **Recovery**: Redirect to login screen
- **File**: `LocalAuthenticationManager.swift:handleInvalidToken()`

#### Missing Token
- **Trigger**: User never logged in
- **Behavior**: Redirect to login/onboarding
- **UI**: No error (expected first-run behavior)
- **File**: `AppNavigationCoordinator.swift:determineInitialView()`

### Data Sync Errors

#### Firestore Write Fails
- **Trigger**: No internet, Firestore quota exceeded, permission denied
- **Behavior**: Queue for offline sync
- **Storage**: Pending writes stored in `PendingSyncQueue`
- **Retry**: Automatic when network restored
- **File**: `RecipeSyncCoordinator.swift:queueForOfflineSync(_:)`

#### CoreData Save Fails
- **Trigger**: Database corruption, disk full
- **Behavior**: Log error, show user message
- **UI**: Alert "Veri kaydedilemedi. Uygulamayı yeniden başlatın."
- **Recovery**: User should force quit and reopen
- **File**: All CoreData save operations in try-catch

#### Conflict Resolution
- **Strategy**: Last-write-wins (LWW)
- **Behavior**: Firestore timestamp determines winner
- **Edge case**: Simultaneous writes from multiple devices
- **Resolution**: Latest `updatedAt` timestamp wins
- **File**: `RecipeSyncCoordinator.swift:resolveConflict(_:_:)`

### AI/Backend Errors

#### Rate Limit Exceeded
- **Trigger**: Too many API calls to Gemini/OpenAI
- **Behavior**: Show countdown timer
- **UI**: "Çok fazla istek. Lütfen X dakika sonra tekrar deneyin."
- **Cooldown**: 5 minutes (adjustable)
- **File**: Cloud Function rate limiting

#### Model Failure (Gemini/OpenAI)
- **Trigger**: Model returns error, empty response, timeout
- **Behavior**: Retry with backoff, fallback to lower tier
- **Retries**: 3 attempts
- **Fallback**: Tier 3 → Tier 2 → Tier 1
- **File**: Cloud Functions error handling

#### Invalid Response Format
- **Trigger**: AI returns malformed JSON
- **Behavior**: Log for debugging, show error to user
- **UI**: "Yanıt işlenemedi. Lütfen tekrar deneyin."
- **Recovery**: Retry button
- **File**: `RecipeStreamingService.swift:parseResponse(_:)`

---

## User Recovery Procedures

### "I can't see my glucose data"

**Steps**:
1. **Check Dexcom connection**: Settings → Dexcom Connection → Status
2. **Verify internet**: Open Safari, load any website
3. **Manual refresh**: Pull down on GlucoseDashboardView
4. **Check Dexcom Share app**: Ensure CGM is uploading data
5. **Reconnect**: Settings → Dexcom → "Yeniden Bağlan"
6. **Last resort**: Force quit app, reopen, wait 1 minute

**File References**:
- Connection check: `DexcomConnectionView.swift:checkConnection()`
- Manual refresh: `GlucoseDashboardView.swift:refreshData()`

### "Recipe generation failed"

**Steps**:
1. **Check internet**: Settings → Wi-Fi/Cellular
2. **Tap retry**: Alert has "Tekrar Dene" button
3. **Simplify input**: Remove complex ingredients or notes
4. **Try without customization**: Empty state generation
5. **Report issue**: Settings → Debug → "Hata Bildir"

**File References**:
- Retry logic: `RecipeGenerationViewModel.swift:retryGeneration()`
- Error reporting: `ErrorReporter.swift:report(_:)`

### "My data isn't syncing"

**Steps**:
1. **Check internet**: Open Safari
2. **Force sync**: Settings → Advanced → "Şimdi Senkronize Et"
3. **View sync status**: Settings → Debug → "Sync Status"
4. **Force quit app**: Swipe up from home screen, swipe up on app
5. **Reopen app**: Sync attempts automatically
6. **Export backup**: Settings → Export Data (as precaution)

**File References**:
- Manual sync: `RecipeSyncCoordinator.swift:forceSyncNow()`
- Sync status: `SyncStatusView.swift:displayStatus()`

### "App crashed"

**Steps**:
1. **Reopen app**: State should restore from CoreData
2. **Check Console.app**: Mac users can see crash logs
3. **Persistent crashes**: Settings → Reset Cache
4. **Last resort**: Delete and reinstall (exports data first)
5. **Report crash**: Send screenshot to developer

**File References**:
- State restoration: `AppDelegate.swift:application(_:didFinishLaunchingWithOptions:)`
- Reset cache: `CacheManager.swift:clearAll()`

---

## Onboarding Flow (First-Time User)

### For Dilara (Primary User)

#### Step 1: First Launch
- **View**: `UserSelectionView`
- **Options**: "Dilara" or "Serhat" profile
- **Action**: User selects "Dilara"
- **File**: `UserSelectionView.swift:selectUser(_:)`

#### Step 2: HealthKit Permission
- **Prompt**: "balli needs access to your Health data"
- **Permissions**: Glucose, carbs, insulin, exercise
- **Action**: User taps "Allow"
- **File**: `HealthKitManager.swift:requestAuthorization()`

#### Step 3: Notification Permission
- **Prompt**: "Allow balli to send you notifications?"
- **Purpose**: Meal reminders, glucose alerts
- **Action**: User taps "Allow"
- **File**: `NotificationManager.swift:requestPermission()`

#### Step 4: Dexcom Setup Walkthrough
- **View**: `DexcomOnboardingView`
- **Content**: Step-by-step guide with screenshots
- **Steps**:
  1. Tap "Connect to Dexcom"
  2. Login to Dexcom Share
  3. Grant permissions
  4. Wait for first sync
- **Completion**: Green checkmark "Bağlantı başarılı ✓"
- **File**: `DexcomOnboardingView.swift`

#### Step 5: Dashboard Introduction
- **View**: `GlucoseDashboardView` with coach marks
- **Highlights**:
  - Current glucose reading
  - Trend arrow meaning
  - Time in range chart
  - Favorites section
- **Action**: User taps "Anladım" to dismiss
- **File**: `OnboardingCoachMarks.swift:showGlucoseDashboard()`

#### Step 6: Recipe Generation Demo
- **View**: `RecipeGenerationView` with overlay
- **Demo**: Shows sample recipe generation
- **Explains**:
  - Purple + button
  - Meal selection
  - Streaming text
  - Save button
- **Action**: User generates first recipe
- **File**: `OnboardingCoachMarks.swift:showRecipeGeneration()`

#### Step 7: Research Introduction
- **View**: `InformationRetrievalView` with tooltip
- **Explains**:
  - 3 tier system
  - Question examples
  - Source citations
  - Highlight feature
- **Action**: User asks first question
- **File**: `OnboardingCoachMarks.swift:showResearch()`

#### Step 8: Settings Tour
- **View**: `SettingsView` with highlights
- **Shows**:
  - Notification settings
  - Data export
  - Debug tools
  - About section
- **Action**: User taps "Turu Bitir"
- **Completion**: Onboarding marked complete
- **File**: `OnboardingManager.swift:markComplete()`

---

## Known Edge Cases

### Recipe Generation

**Edge Case 1**: User writes notes AFTER generating recipe
- **Expected**: Notes treated as personal notes, not generation prompts
- **Behavior**: If "Regenerate" tapped, shows meal selection (notes now ambiguous)
- **Reason**: Notes written post-generation indicate reflection, not intent
- **File**: `RecipeGenerationFlowCoordinator.swift:determineFlow()`

**Edge Case 2**: User adds ingredients that conflict (e.g., "vegan, chicken")
- **Expected**: AI resolves conflict or asks for clarification
- **Behavior**: Prioritizes most recent/specific constraint
- **Example**: "vegan, 200g chicken" → Replaces chicken with plant-based protein
- **File**: Cloud Function prompt includes conflict resolution

**Edge Case 3**: User requests impossible recipe
- **Example**: "Sugar-free cake with 100g sugar"
- **Expected**: AI detects contradiction
- **Behavior**: Prioritizes health constraint (makes sugar-free)
- **Fallback**: Shows clarification question if unresolvable
- **File**: Cloud Function validation logic

### Glucose Sync

**Edge Case 1**: User has no recent data in Dexcom
- **Trigger**: CGM not worn, Share not uploading
- **Expected**: Shows "No recent data" message
- **Behavior**: Does not crash, shows last known reading + timestamp
- **Message**: "Son ölçüm: X saat önce"
- **File**: `GlucoseDashboardView.swift:displayLastReading()`

**Edge Case 2**: Token expires during background sync
- **Trigger**: Refresh token fails while app in background
- **Expected**: Queue retry for foreground
- **Behavior**: Next foreground launch attempts reconnection
- **Message**: "Dexcom bağlantısı yenilenmedi. Lütfen yeniden bağlanın."
- **File**: `DexcomBackgroundRefreshManager.swift:handleTokenExpired()`

**Edge Case 3**: User changes Dexcom password
- **Trigger**: Password reset on Dexcom website
- **Expected**: Stored tokens become invalid
- **Behavior**: Auth fails with 401, prompts reconnection
- **Message**: "Dexcom şifreniz değişti. Lütfen yeniden bağlanın."
- **File**: `DexcomService.swift:handleAuthError(_:)`

### Research

**Edge Case 1**: User submits extremely long question (>500 words)
- **Trigger**: Pasted long medical article as question
- **Expected**: Validation truncates or rejects
- **Behavior**: Truncates to 500 words, shows warning
- **Message**: "Soru çok uzun. İlk 500 kelime kullanılacak."
- **File**: `InformationRetrievalView.swift:validateQuestion(_:)`

**Edge Case 2**: Question has no keywords (e.g., "???")
- **Trigger**: User submits gibberish or empty question
- **Expected**: Validation catches generic queries
- **Behavior**: Shows suggestion to reformulate
- **Message**: "Lütfen daha spesifik bir soru sorun."
- **File**: `MedicalResearchViewModel.swift:validateQuestion(_:)`

**Edge Case 3**: Tier 3 times out mid-stream
- **Trigger**: Deep research takes >60 seconds
- **Expected**: Fallback to Tier 2 results
- **Behavior**: Shows partial Tier 3 results + Tier 2 completion
- **Message**: Toast "Derin araştırma tamamlanamadı. Kısmi sonuçlar gösteriliyor."
- **File**: Cloud Function timeout handler

---

## Performance Expectations

### App Launch
- **Cold start**: <2 seconds (from tap to UI visible)
- **Warm start**: <500ms (from background to foreground)
- **State restoration**: <1 second (restoring previous view)

### View Transitions
- **Navigation**: <100ms (between tabs or screens)
- **Modal presentation**: <200ms (sheet or full-screen modal)
- **Animation**: 60fps (no jank or dropped frames)

### Network Requests
- **API calls**: 3-second timeout (recipe gen, research)
- **Firestore queries**: 5-second timeout
- **Image downloads**: 10-second timeout (with progress)

### Data Operations
- **CoreData fetch**: <500ms (for typical queries)
- **CoreData save**: <500ms (single entity)
- **Firestore sync**: 1-3 seconds (background, non-blocking)

---

## Acceptance Criteria

### For Dilara's Daily Use ✅
- [ ] Dexcom connection works reliably
- [ ] Glucose data syncs every 4 hours
- [ ] Recipe generation completes in <15 seconds
- [ ] Research returns results in <30 seconds (Tier 2)
- [ ] App doesn't crash during normal use
- [ ] Data syncs to Firestore for backup
- [ ] Offline mode shows cached data

### For Family Use ⚠️
- [ ] Multiple user profiles work correctly
- [ ] Data isolation between users
- [ ] Crashlytics reports crashes with stack traces
- [ ] Comprehensive error messages for all failures
- [ ] Recovery procedures documented and tested
- [ ] Export functionality works for all users

---

**Document Version**: 1.0
**Last Updated**: 2025-01-04
**Maintained By**: Development Team
**Next Review**: After first production week with Dilara

