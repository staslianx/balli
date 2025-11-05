# Balli - Feature Documentation

**Last Updated:** 2025-11-05
**Purpose:** Comprehensive catalog of all user-facing features in the Balli iOS app
**Audience:** Product managers, developers, stakeholders, and new team members

---

## Overview

Balli is a comprehensive diabetes management app for iOS that helps users track glucose, meals, activity, and nutrition. It integrates with Dexcom CGM, Apple Health, and uses AI-powered features for meal logging, recipe generation, and medical research.

---

## 🩸 Glucose Monitoring & Health Dashboard

### Unified Health Dashboard
**Files:**
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Views/UnifiedDashboardView.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/ViewModels/HosgeldinViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/ViewModels/GlucoseChartViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/ViewModels/ActivityMetricsViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Views/GlucoseDashboardView.swift`

**Summary:**
The main health dashboard displays real-time glucose readings with trend charts and activity metrics in an interactive carousel. Users can view their current glucose level, trend direction (rising, falling, stable), and daily activity summaries (steps, calories, exercise minutes) all in one glanceable interface. The dashboard includes quick-action buttons for logging meals via camera, voice, or manual entry, and provides personalized health insights.

---

### Dexcom CGM Integration (Official API)
**Files:**
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Services/DexcomService.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Views/DexcomConnectionView.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Services/DexcomBackgroundRefreshManager.swift`
- `/Users/serhat/SW/balli/balli/Core/Protocols/Services/DexcomServiceProtocol.swift`

**Summary:**
Users can connect their Dexcom CGM device using OAuth authentication to automatically sync glucose readings every 5 minutes. The integration provides historical glucose data (3+ hours) and displays detailed device information including transmitter model, display device, and connection status. Background sync ensures glucose data remains current even when the app is closed.

---

### Dexcom Share Integration (Real-Time API)
**Files:**
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Services/DexcomShareService.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Services/DexcomSyncCoordinator.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Views/DexcomShareSettingsView.swift`
- `/Users/serhat/SW/balli/balli/Core/Protocols/DexcomShareServiceProtocol.swift`

**Summary:**
Enables real-time glucose monitoring (0-3 hours) through Dexcom Share API, complementing the Official API's historical data. Users authenticate with their Dexcom Share username and password to receive the most recent readings with minimal delay (3-second lag). The service automatically coordinates with the Official API to provide a complete glucose timeline without data duplication.

---

### Apple Health Integration
**Files:**
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/ViewModels/ActivityMetricsViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/HealthGlucose/Models/DailyActivity+CoreDataClass.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/Components/ActivitySyncSection.swift`

**Summary:**
Syncs daily activity metrics from Apple Health including steps, active energy burned, exercise minutes, and stand hours. Users can view their activity trends alongside glucose data to understand how physical activity affects their blood sugar levels. Historical activity data can be backfilled for up to 90 days for comprehensive trend analysis.

---

## 🍽️ Meal Tracking & Food Entry

### Voice-Based Meal Logging
**Files:**
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/Views/VoiceInputView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/Services/AudioRecordingService.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/Services/GeminiTranscriptionService.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/Services/MealTranscriptionParser.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/Models/ParsedMealData.swift`

**Summary:**
Users can log meals by simply speaking what they ate, using AI-powered speech recognition and natural language processing. The system transcribes audio, extracts food items with portions, estimates total carbohydrates, determines meal type (breakfast, lunch, dinner, snack), and optionally logs insulin dosage if mentioned. After transcription, users can review and edit the AI-extracted data before saving to ensure accuracy.

---

### Camera-Based Nutrition Label Scanning
**Files:**
- `/Users/serhat/SW/balli/balli/Features/CameraScanning/Views/CameraView.swift`
- `/Users/serhat/SW/balli/balli/Features/CameraScanning/Views/AIAnalysisView.swift`
- `/Users/serhat/SW/balli/balli/Features/CameraScanning/ViewModels/AnalysisViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/CameraScanning/Services/CaptureFlowManager.swift`
- `/Users/serhat/SW/balli/balli/Features/CameraScanning/Views/AnalysisNutritionLabelView.swift`
- `/Users/serhat/SW/balli/balli/Core/Services/LabelAnalysisService.swift`

**Summary:**
Users can photograph nutrition labels on food packaging to automatically extract nutritional information using computer vision and AI. The camera captures the label, AI analyzes the image to extract calories, carbohydrates, protein, fat, serving size, and ingredients, and presents the data in an editable format. This eliminates manual data entry and reduces logging friction for packaged foods.

---

### Manual Meal Entry
**Files:**
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/ManualEntryView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodEntry/Models/EditableFoodItem.swift`
- `/Users/serhat/SW/balli/balli/Core/Services/MealEntryService.swift`

**Summary:**
Provides a traditional form-based interface for users who prefer typing meal details manually. Users can enter food names, portions, carbohydrate counts, meal type, timestamp, and optional insulin information through text fields and pickers. The manual entry option ensures users always have a fallback when voice or camera methods aren't suitable.

---

### Meal History & Archive
**Files:**
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/LoggedMealsView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/MealDetailView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/MealEditSheet.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Services/MealFirestoreService.swift`
- `/Users/serhat/SW/balli/balli/Core/Data/Models/MealEntry+Extensions.swift`

**Summary:**
Users can browse their complete meal logging history organized by date with detailed nutritional breakdowns. Each meal entry is editable and displays food items, carbohydrate totals, insulin dosages (if logged), and timestamps. The archive syncs with Firebase Firestore for cross-device access and long-term storage.

---

### Food Archive (Ardiye)
**Files:**
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/ArdiyeView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/ArdiyeSearchView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Components/ProductCardView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/OnlyFavoritesView.swift`
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Models/ArdiyeModels.swift`

**Summary:**
A comprehensive library of saved food items, products, and meals that users have logged previously. Users can browse their personal food database, search by name, filter by favorites, and quickly re-log frequently eaten items without re-entering nutritional data. The archive includes both scanned packaged foods and custom entries, making repeat meal logging instantaneous.

---

## 🧑‍🍳 Recipe Management & Generation

### AI Recipe Generation
**Files:**
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeGenerationViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/RecipeGenerationView.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Services/RecipeGenerationService.swift`

**Summary:**
Users can generate personalized recipes using AI by specifying meal type (breakfast, lunch, dinner) and dietary preferences. The system creates recipes with ingredient lists, step-by-step instructions, cooking times, and nutritional information tailored to diabetes management. Users can optionally provide ingredients they have on hand or describe what they're craving, and the AI will create appropriate recipes.

---

### Recipe Detail & Viewing
**Files:**
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeDetailViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/RecipeDetailView.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/RecipeDetail/RecipeMetadataSection.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Models/RecipeDetailData.swift`

**Summary:**
Displays comprehensive recipe information including ingredients with quantities, cooking instructions, preparation/cooking times, servings, and complete nutritional breakdown (calories, carbs, protein, fat). Users can favorite recipes, adjust serving sizes, and send ingredient lists directly to the shopping list. Recipe photos are displayed prominently to help users visualize the dish.

---

### Recipe Photo Generation
**Files:**
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeImageHandler.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/RecipeGenerationHeroSection.swift`

**Summary:**
Automatically generates appetizing food photography for recipes using AI image generation. Users see a visually appealing photo of their recipe's completed dish, making the recipe library more engaging and helping with meal planning and inspiration. Photos are generated based on recipe name and description.

---

### Nutrition Calculation
**Files:**
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeNutritionHandler.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Repositories/RecipeNutritionRepository.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Services/NutritionCalculationService.swift`

**Summary:**
Calculates detailed nutritional information for recipes by analyzing ingredient lists and quantities. Users receive accurate macronutrient breakdowns (carbohydrates, protein, fat, fiber) and total calories per serving, essential for insulin dosing and carb counting. The system uses the Edamam Nutrition API for precise calculations.

---

### Recipe Library & Favorites
**Files:**
- `/Users/serhat/SW/balli/balli/Features/FoodArchive/Views/Components/RecipeCardView.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Models/RecentRecipe.swift`
- `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/RecipesLibraryView.swift`

**Summary:**
Users can browse their saved recipe collection, mark favorites for quick access, and filter by meal type, cuisine, or dietary restrictions. Recent recipes appear prominently for easy re-access, and each recipe card displays key information like prep time, servings, and carbohydrate content at a glance.

---

## 🛒 Shopping List Management

### Smart Shopping List
**Files:**
- `/Users/serhat/SW/balli/balli/Features/ShoppingList/Views/ShoppingListViewSimple.swift`
- `/Users/serhat/SW/balli/balli/Features/ShoppingList/ViewModels/ShoppingListViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/ShoppingList/Views/ShoppingListInputContainer.swift`
- `/Users/serhat/SW/balli/balli/Core/Data/Models/ShoppingListItem+CoreDataClass.swift`

**Summary:**
Users maintain a dynamic shopping list with inline editing, quantity tracking, and recipe-based organization. Items can be added manually or automatically from recipe ingredient lists, checked off during shopping, and organized by recipe groups. The list persists locally in Core Data and supports notes, quantity specifications (e.g., "2x", "1 kg"), and suggested alternatives.

---

### Recipe-to-Shopping-List Integration
**Files:**
- `/Users/serhat/SW/balli/balli/Features/ShoppingList/Services/ShoppingListIntegrationService.swift`
- `/Users/serhat/SW/balli/balli/Features/ShoppingList/Views/RecipeShoppingSection.swift`

**Summary:**
Seamlessly sends recipe ingredients to the shopping list with one tap, automatically organizing them by recipe name. Users can see which items belong to which recipe while shopping, check off items as they find them, and track progress per recipe. This eliminates the need to manually transcribe ingredient lists for meal prep.

---

### Market Locator
**Files:**
- `/Users/serhat/SW/balli/balli/Features/ShoppingList/Views/NearbyMarketsView.swift`

**Summary:**
Opens Apple Maps with a search for nearby markets/grocery stores directly from the shopping list view. Users can quickly find the closest stores, get directions, and see hours of operation without leaving the context of their shopping task. This feature streamlines the shopping experience by reducing app-switching friction.

---

## 🔬 Medical Research & Information Retrieval

### AI-Powered Medical Research
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Research/Views/InformationRetrievalView.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/ViewModels/MedicalResearchViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/Services/ResearchService.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/ViewModels/ResearchStreamProcessor.swift`

**Summary:**
Users can ask health and diabetes-related questions and receive AI-generated research summaries with citations from medical sources. The system searches PubMed, ArXiv, clinical trials, and web sources in real-time, synthesizes findings, and presents them with inline citations and source links. Responses stream live for immediate feedback, and users can ask follow-up questions in a conversational format.

---

### Research Session History
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Research/Views/SearchLibraryView.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/Views/SearchDetailView.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/Models/ResearchSessionModelContainer.swift`

**Summary:**
Users can review their past research queries and responses, organized as searchable conversations with timestamps. Each session is preserved with full context, allowing users to reference previous findings, share research with healthcare providers, or continue exploring topics across multiple app sessions. The library supports search and filtering for quick retrieval.

---

### Multi-Modal Research (Text + Images)
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Research/Models/ImageAttachment.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/Views/Components/SearchBarView.swift`

**Summary:**
Users can attach images to research queries, enabling questions about medical images, nutrition labels, or visual symptoms. The AI analyzes both text and images simultaneously to provide context-aware answers, making it useful for questions like "What are the carbs in this meal?" with a food photo attached.

---

### Source Citations & Verification
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Research/Views/Components/CollectiveSourcePill.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/Models/InlineCitation.swift`
- `/Users/serhat/SW/balli/balli/Features/Research/Models/ResearchSource.swift`

**Summary:**
All research responses include clickable inline citations linked to original medical sources (PubMed articles, clinical studies, medical websites). Users can verify claims by tapping citation numbers to view source details, publication dates, authors, and direct links to full texts. This transparency helps users evaluate the reliability of health information.

---

## ⚙️ Settings & Configuration

### App Settings
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/AppSettingsView.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/Components/AccountProfileSection.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/Components/NotificationSettingsView.swift`

**Summary:**
Centralized settings interface for managing account details, app appearance (light/dark/system theme), notification preferences, and data connections. Users can access all configuration options, diagnostic tools, and account management from this unified hub. Settings include theme selection, language preferences, glucose unit preferences, and integration toggles.

---

### Health Data Connections
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/HealthKitManagerView.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/Components/ActivitySyncSection.swift`

**Summary:**
Users manage permissions and connections to Apple Health, Dexcom CGM (both APIs), and activity tracking services. The interface shows connection status, last sync times, and provides quick actions to reconnect or troubleshoot issues. Users can backfill historical data (up to 90 days) for comprehensive trend analysis.

---

### Recipe Preferences
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/RecipePreferencesView.swift`

**Summary:**
Users customize recipe generation by setting dietary preferences, cuisine favorites, allergies, and carbohydrate targets. These preferences influence AI recipe suggestions to better align with personal needs, taste preferences, and diabetes management goals. Settings persist across app sessions for consistent recipe recommendations.

---

### Developer & Diagnostic Tools
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/Components/DeveloperModeSection.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/DexcomDiagnosticsView.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/AIDiagnosticsView.swift`
- `/Users/serhat/SW/balli/balli/Features/Settings/Views/ResearchStageDiagnosticsView.swift`

**Summary:**
Advanced diagnostic interfaces for troubleshooting data sync issues, viewing API logs, and accessing developer-mode features. Users (or support staff) can inspect Dexcom connection logs, AI model responses, research pipeline stages, and data integrity checks. This enables faster issue resolution and provides transparency into app functionality.

---

## 📊 Data Export & Analysis

### Comprehensive Data Export
**Files:**
- `/Users/serhat/SW/balli/balli/Features/DataExport/Views/DataExportView.swift`
- `/Users/serhat/SW/balli/balli/Features/DataExport/ViewModels/DataExportViewModel.swift`
- `/Users/serhat/SW/balli/balli/Features/DataExport/Services/DataExportService.swift`

**Summary:**
Users can export their complete health data (meals, glucose readings, insulin entries, activity) in multiple formats (CSV, JSON, correlation analysis). Export options include custom date ranges, quick presets (last 7/30/90 days), and format selection based on use case (spreadsheet analysis, research, medical records). This enables data portability, third-party analysis, and sharing with healthcare providers.

---

### Time-Series & Correlation Analysis
**Files:**
- `/Users/serhat/SW/balli/balli/Features/DataExport/Services/TimeSeriesCSVGenerator.swift`
- `/Users/serhat/SW/balli/balli/Features/DataExport/Services/CorrelationCSVGenerator.swift`
- `/Users/serhat/SW/balli/balli/Features/DataExport/Services/EventJSONGenerator.swift`

**Summary:**
Exports structured data files optimized for correlation analysis between meals, glucose, insulin, and activity. Users can analyze how specific foods affect their glucose levels, identify patterns in their diabetes management, and provide data to researchers or healthcare providers. CSV exports are Excel-compatible, and JSON exports support programmatic analysis.

---

## 👤 User Management & Onboarding

### User Profile Selection
**Files:**
- `/Users/serhat/SW/balli/balli/Features/UserOnboarding/Views/UserSelectionView.swift`
- `/Users/serhat/SW/balli/balli/Core/Services/UserProfileSelector.swift`

**Summary:**
Multi-user support allowing households to share one device with separate health data profiles. Users select their profile on app launch, and all data (meals, glucose, recipes, research) remains isolated per user. This is essential for families where multiple members have diabetes and need independent tracking.

---

### Launch & Sync Experience
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Launch/LaunchTransitionView.swift`
- `/Users/serhat/SW/balli/balli/Features/Launch/LoadingSplashView.swift`
- `/Users/serhat/SW/balli/balli/Features/Launch/SyncErrorView.swift`

**Summary:**
Handles app startup sequence including data synchronization, service initialization, and error recovery. Users see a polished loading experience while critical data (glucose readings, recent meals) syncs from cloud and device sources. If sync fails, users receive clear error messages with actionable steps to resolve connectivity issues.

---

## 🧾 Cost Tracking (Future Feature)

### API Cost Dashboard
**Files:**
- `/Users/serhat/SW/balli/balli/Features/CostTracking/Views/CostDashboardView.swift`
- `/Users/serhat/SW/balli/balli/Features/CostTracking/Services/CostTrackingService.swift`
- `/Users/serhat/SW/balli/balli/Features/CostTracking/Models/CostReport.swift`

**Summary:**
Monitors AI API usage costs (Gemini, nutrition calculation, image generation) to provide transparency and budgeting for users. The dashboard shows daily/monthly spending, cost per feature, and usage trends. This feature is currently under development and will help users understand the operational costs of AI-powered features.

---

## 🧩 Shared Components & Utilities

### Nutrition Label Display
**Files:**
- `/Users/serhat/SW/balli/balli/Features/Components/NutritionLabelView.swift`

**Summary:**
Reusable nutrition facts label component displaying standardized nutritional information in FDA-compliant format. Used throughout the app for food items, recipes, and scanned products to provide consistent, familiar nutrition presentation. Includes serving size, calories, macronutrients, and percent daily values.

---

### Analytics & Telemetry
**Files:**
- `/Users/serhat/SW/balli/balli/Core/Analytics/AnalyticsService.swift`

**Summary:**
Tracks app usage patterns, feature engagement, error rates, and performance metrics to guide product improvements. Events are logged for key user actions (meal logs, recipe generations, research queries) while respecting privacy by anonymizing health data. Analytics help prioritize features and identify usability issues.

---

## 📝 Feature State Summary

### ✅ Production-Ready Features
- Glucose monitoring (Dexcom Official + Share APIs)
- Voice-based meal logging
- Camera nutrition label scanning
- Manual meal entry
- AI recipe generation
- Recipe library & favorites
- Shopping list with recipe integration
- Medical research with citations
- Data export (CSV/JSON)
- User profile management
- Apple Health integration
- Settings & preferences

### 🚧 In Development
- Cost tracking dashboard
- Advanced correlation analytics
- Meal recommendations based on glucose patterns
- Social recipe sharing

### 🔮 Planned Features
- Medication tracking & reminders
- Insulin dosing calculator
- Carb counting assistant
- Healthcare provider data sharing
- Meal photo recognition (beyond nutrition labels)
- Barcode scanner for packaged foods

---

## 🎯 Feature Interdependencies

**Critical Dependency Chains:**
1. **Glucose Monitoring** → Meal Logging → Data Export → Research
2. **Recipe Generation** → Nutrition Calculation → Shopping List
3. **Voice Input** → Meal Archive → Favorites → Quick Re-logging
4. **Camera Scanning** → Food Archive → Meal History
5. **User Profiles** → ALL features (data isolation)

**Integration Points:**
- All meal entry methods (voice, camera, manual) → MealEntryService → Core Data + Firestore
- All recipes → RecipeViewModel → Firestore + ShoppingList
- Dexcom Official + Share → DexcomSyncCoordinator → GlucoseChartViewModel
- Research queries → Gemini API → Session Storage → SearchLibrary

---

## 🏗️ Technical Architecture Notes

**Data Flow:**
- **Local-First:** Core Data for offline-first meal/glucose storage
- **Cloud Sync:** Firestore for cross-device recipe/meal sync
- **Real-Time:** Dexcom Share for live glucose (5-min updates)
- **Batch Processing:** Background refresh for activity/glucose sync

**AI Services:**
- **Gemini 2.5 Flash:** Voice transcription, recipe generation, research
- **Vision API:** Nutrition label OCR and analysis
- **Edamam API:** Nutrition calculation and validation

**Concurrency:**
- Swift 6 strict concurrency enabled project-wide
- Actor isolation for all service layers
- @MainActor for all UI components
- Sendable conformance for cross-boundary types

---

## 📞 Support & Feedback

For feature requests, bug reports, or questions:
- **Contact:** stasli.anx@icloud.com
- **Settings:** App Settings > İletişim
- **Diagnostics:** Settings > Tanı (for technical issues)

---

**Document Maintained By:** Development Team
**Review Frequency:** After each major release
**Related Docs:** CLAUDE.md (development standards), architecture.md (technical design)
