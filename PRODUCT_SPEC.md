# Balli - Product Specification Document

**Version:** 1.0.0
**Last Updated:** October 2025
**Target Platform:** iOS 26+
**Primary Users:** People with diabetes and their caregivers

---

## 1. Product Overview

### Product Name
**Balli** (Turkish for "honey") - A diabetes management companion app

### Product Vision
Balli empowers people with diabetes to manage their condition through AI-powered meal planning, real-time glucose monitoring, and intelligent research assistance. The app combines traditional diabetes management tools with cutting-edge AI to make healthy living easier and more personalized.

### Target Users
- **Primary:** Adults with Type 1 or Type 2 diabetes
- **Secondary:** Caregivers managing diabetes for family members
- **Tertiary:** Pre-diabetic individuals seeking preventive lifestyle management

### Core Value Proposition
- **AI-Powered Recipe Generation:** Get personalized, diabetic-friendly recipes that never repeat
- **Voice-First Meal Logging:** Log meals naturally by speaking, with AI understanding Turkish food descriptions
- **Real-Time Glucose Monitoring:** Seamless Dexcom CGM integration with beautiful visualizations
- **Medical Research Translation:** Access cutting-edge diabetes research translated to Turkish
- **Label Scanning:** Instantly analyze packaged foods by photographing nutrition labels

---

## 2. Product Capabilities Summary

Users can accomplish the following with Balli:

1. **Monitor glucose levels in real-time** from Dexcom CGM devices with historical trends
2. **Generate personalized recipes** tailored to dietary needs with AI ensuring variety
3. **Log meals effortlessly** using voice input with automatic carbohydrate calculation
4. **Scan nutrition labels** on packaged foods for instant analysis
5. **Research diabetes topics** with AI-powered search and Turkish translation
6. **Track activity metrics** including steps, heart rate, and exercise from Apple Health
7. **Manage shopping lists** based on recipes with automatic ingredient tracking
8. **Switch between user profiles** for family members sharing one device

---

## 3. Feature Inventory

### 3.1 Dashboard (Hoşgeldin - "Welcome")

#### What it does (user perspective):
The main dashboard shows users their current health status with a beautiful carousel of cards showing glucose trends and activity metrics, plus quick action buttons for common tasks.

#### User flow:
1. User opens the app to the dashboard
2. System displays carousel with glucose chart and activity metrics cards
3. User can swipe between cards to view different health data
4. User can tap quick action buttons: voice meal log, camera scan, or recipe generation
5. System provides real-time glucose readings if Dexcom is connected

#### Key capabilities:
- Horizontal scrolling carousel with glucose and activity cards
- Real-time glucose data display with trend indicators
- Quick access buttons for all meal logging methods
- "Favorites" section showing frequently used recipes
- Daily view calendar access for historical meal logs
- Automatic data refresh when returning to foreground

#### Business rules:
- Glucose data updates every 5 minutes when Dexcom is connected
- Activity metrics sync from Apple Health automatically
- Dashboard refreshes glucose data automatically when app becomes active
- Favorites section shows recipes marked as favorite by user
- Calendar button navigates to daily meal log history

#### Integrations/Dependencies:
- **Dexcom API:** Real-time continuous glucose monitoring
- **Apple Health:** Activity metrics (steps, heart rate, active energy)
- **Firebase Firestore:** Recipe favorites and user preferences
- **Core Data:** Local meal history and glucose cache

#### Current status:
✅ Fully functional

#### Known limitations:
- Glucose data requires active Dexcom connection
- Activity metrics require Apple Health permissions
- No manual glucose entry for non-CGM users

---

### 3.2 Voice Meal Logging

#### What it does (user perspective):
Users can speak naturally in Turkish to log meals, and the AI automatically extracts food items, quantities, meal type (breakfast/lunch/dinner), and calculates total carbohydrates.

#### User flow:
1. User taps the "+" button on dashboard or long-presses quick action button
2. System opens voice input modal with microphone visualization
3. User speaks their meal description in Turkish (e.g., "Kahvaltıda iki dilim ekmek, peynir ve domates yedim")
4. System records audio and shows animated waveform visualization
5. User taps stop button to end recording
6. System sends audio to Gemini 2.5 Flash for transcription and analysis
7. System displays parsed meal data: foods list, quantities, carbs per item, total carbs, meal time, meal type
8. User reviews and can tap checkmark to save
9. System creates individual FoodItem entries for each food mentioned
10. System saves meal entries to Core Data for history tracking

#### Key capabilities:
- Natural Turkish language understanding
- Automatic food item extraction from speech
- Intelligent carbohydrate estimation
- Meal type classification (breakfast, lunch, dinner, snack)
- Time inference from speech or current time
- Multi-item meal parsing (e.g., "bread and cheese" → 2 items)
- Real-time audio waveform visualization
- Confidence scoring for AI predictions

#### Business rules:
- Each food item becomes a separate database entry
- Total carbs distributed across items if specific amounts not mentioned
- Meal type inferred from time of day if not explicitly stated
- Meals logged within last 24 hours automatically
- Audio processed using Gemini 2.5 Flash multimodal model
- Low confidence results show warning message for user verification

#### Integrations/Dependencies:
- **Gemini 2.5 Flash:** Audio transcription and meal data extraction via Firebase Cloud Function
- **Firebase Cloud Functions:** `transcribeMeal` endpoint for audio processing
- **Core Data:** Meal storage with FoodItem relationships
- **AVFoundation:** Audio recording with M4A format

#### Current status:
✅ Fully functional

#### Known limitations:
- Turkish language only (English not supported)
- Requires microphone permission
- Cannot distinguish between very similar foods without explicit quantities
- Network connectivity required for AI processing
- Maximum recording length not explicitly defined

---

### 3.3 AI Recipe Generation

#### What it does (user perspective):
Users can generate personalized, diabetic-friendly recipes either spontaneously or by providing specific ingredients they have on hand. The AI ensures recipe variety and never repeats the same meals within a 15-day window.

#### User flow:
1. User taps recipe generation button from dashboard
2. System shows meal type selection (Breakfast, Dinner, Salads, Desserts, Snacks)
3. User selects meal type and style subcategory (e.g., "Traditional Turkish" for dinner)
4. User chooses between:
   - **Spontaneous:** AI generates creative recipe based on preferences
   - **From Ingredients:** User enters available ingredients
5. System generates recipe with streaming display (content appears progressively)
6. System shows complete recipe with:
   - Recipe name and beautiful AI-generated photo
   - Prep time and cook time
   - Ingredient list with quantities
   - Step-by-step cooking instructions
   - Nutritional information (carbs, protein, fat, fiber, glycemic load)
   - Chef's notes for diabetic considerations
7. User can save recipe to archive (Ardiye)
8. User can generate photo if recipe doesn't have one
9. User can add ingredients to shopping list
10. User can edit recipe inline to customize

#### Key capabilities:
- Spontaneous AI-generated recipes with guaranteed variety
- Recipe generation from user-provided ingredients
- Beautiful AI-generated recipe photography
- Real-time streaming generation (content appears as AI writes)
- Markdown formatting for elegant recipe display
- Inline recipe editing with ingredient/instruction modification
- Nutritional analysis with glycemic load calculation
- Recipe photo regeneration with Imagen 4 Ultra
- Memory-based variety system (no repeats within 15 days)
- Recipe favoriting and organization

#### Business rules:
- **15-day non-repetition rule:** Recipes analyze main ingredients and avoid duplicates within sliding 15-day window
- Recipes regenerated automatically if too similar to recent meals
- All nutritional values calculated per 100g serving
- Glycemic load considers both carbs and glycemic index
- Photos generated in 1:1 aspect ratio optimized for mobile
- Recipes tagged with meal type and style for organization
- Markdown content includes ingredients and instructions sections
- User edits preserved with lastModified timestamp

#### Integrations/Dependencies:
- **Gemini 2.5 Flash:** Recipe content generation via Genkit
- **Imagen 4 Ultra:** High-quality food photography generation
- **Firebase Cloud Functions:** `generateSpontaneousRecipe` and `generateRecipeFromIngredients` endpoints
- **Firebase Genkit:** Streaming recipe generation with prompts
- **Core Data:** Recipe persistence with relationships to ingredients
- **Recipe Memory System:** Tracks main ingredients for variety enforcement

#### Current status:
✅ Fully functional

#### Known limitations:
- Recipe generation requires network connectivity
- Cannot import recipes from external websites
- Photo generation takes 10-15 seconds
- Memory system limited to last 10 recipes for performance
- Single retry only if recipe too similar (accepts second attempt regardless)
- Cannot generate recipes for specific calorie targets

---

### 3.4 Nutrition Label Scanning (Camera)

#### What it does (user perspective):
Users can photograph nutrition labels on packaged foods to instantly extract complete nutritional information with AI-powered accuracy.

#### User flow:
1. User taps camera button from dashboard
2. System checks camera permission and requests if needed
3. System shows camera viewfinder with overlay rectangle showing scan area
4. User positions nutrition label within the rectangle
5. User taps capture button
6. System shows preview of captured image
7. User confirms or retakes photo
8. System sends image to Gemini Flash for analysis
9. System displays extracted nutrition data:
   - Product name and brand
   - Serving size and unit
   - Carbohydrates per serving
   - Protein, fat, fiber, sugar
   - Calories
   - Confidence scores for accuracy
10. User can review and edit any values
11. User saves to food archive for future use

#### Key capabilities:
- Real-time camera preview with zoom control (1x, 2x)
- Intelligent viewfinder overlay guiding label placement
- AI-powered OCR and nutrition extraction
- Multi-language label support (Turkish and English)
- Confidence scoring for data quality
- Manual correction of any extracted values
- Automatic serving size normalization
- Impact level calculation (low/medium/high glycemic)

#### Business rules:
- Camera requires explicit user permission
- Nutrition values extracted per serving size stated on label
- Values normalized to 100g for consistent comparison
- Low confidence (<70%) requires manual verification
- Extracted data saved as "ai_scanned" source type
- Scanned products stored separately from recipes in archive
- Demo products auto-generated on first app launch for exploration

#### Integrations/Dependencies:
- **Gemini Flash:** Multimodal vision API for label analysis
- **Firebase Cloud Functions:** `extractNutritionFromImage` endpoint with responseSchema
- **AVFoundation:** Camera capture and session management
- **Core Data:** FoodItem storage with nutrition data
- **Response Schema:** Structured JSON extraction (99%+ reliability)

#### Current status:
✅ Fully functional

#### Known limitations:
- Requires good lighting for accurate OCR
- Small or damaged labels may have lower accuracy
- Cannot scan handwritten labels
- Only supports printed nutrition facts tables
- No barcode scanning capability
- Image quality depends on camera hardware

---

### 3.5 Food Archive (Ardiye)

#### What it does (user perspective):
Users can browse, search, and manage their saved recipes and scanned products in a beautifully organized library with filtering and favorites.

#### User flow:
1. User taps "Ardiye" tab from bottom navigation
2. System shows segmented control: "Tarifler" (Recipes) | "Ürünler" (Products)
3. User selects category to view
4. System displays items:
   - **Recipes:** Full-width cards with photo, name, serving size, carbs
   - **Products:** 2-column grid with brand, name, portion, carbs
5. User can search by name or carb amount
6. User can tap item to view full details
7. User can favorite/unfavorite items via long-press context menu
8. User can delete items by swiping left or via context menu
9. User can access shopping list from toolbar

#### Key capabilities:
- Dual-view layouts: list for recipes, grid for products
- Real-time search with debouncing for performance
- Search by name or carbohydrate amount (±5g tolerance)
- Recipe cards show generated photos or placeholder
- Product cards show brand, name, serving, and carbs
- Yellow star indicator for favorited items
- Segmented filter switching (Recipes/Products)
- Context menu for quick actions (favorite, delete)
- Swipe-to-delete gesture support

#### Business rules:
- Recipes sorted by lastModified date (newest first)
- Products filtered to show only "ai_scanned" source (excludes voice meals)
- Voice-logged meals NOT shown in Products view (only in daily log)
- Search matches name or carb amount with ±5g tolerance
- Favorites toggle updates Core Data immediately
- Deleted items removed permanently (no trash/archive)
- Demo products added automatically on first launch

#### Integrations/Dependencies:
- **Core Data:** Recipe and FoodItem queries with fetch limits
- **Firebase Firestore:** Future cloud sync capability
- **Image storage:** Recipe photos stored as imageData blob

#### Current status:
✅ Fully functional

#### Known limitations:
- No cloud backup of recipes (local device only)
- Cannot export recipes to share with others
- No recipe import from external sources
- Search doesn't support ingredient filtering
- Cannot organize recipes into custom categories/folders
- Deleted items cannot be recovered

---

### 3.6 Medical Research Assistant (Araştır)

#### What it does (user perspective):
Users can ask diabetes-related questions in Turkish and receive AI-generated answers with citations to medical research, translated and explained in accessible language.

#### User flow:
1. User taps "Araştır" (Research) tab
2. System shows empty state: "What would you like to learn?"
3. User types question in search bar (e.g., "What foods lower blood sugar?")
4. User submits question
5. System shows stages:
   - Searching medical databases (PubMed, Clinical Trials)
   - Analyzing research papers
   - Synthesizing answer
6. System streams answer progressively (markdown rendered in real-time)
7. Answer includes:
   - Comprehensive explanation in Turkish
   - Citations with [1], [2] reference numbers
   - Follow-up question suggestions
   - Research metadata (sources found, confidence)
8. User can tap citation to see source details
9. User can click suggested follow-up questions
10. Conversation continues in same session
11. User can start new conversation via toolbar button
12. User can access conversation library for past sessions

#### Key capabilities:
- Natural Turkish language question understanding
- Multi-source medical research aggregation
- Real-time streaming answer generation
- Citation-backed responses with source links
- Markdown rendering with headers, lists, bold, italic
- Follow-up question generation based on answer
- Conversation history with session management
- Cross-session memory via FTS5 full-text search
- Semantic similarity search for relevant past discussions
- Research source metadata (confidence, database)

#### Business rules:
- Answers cite peer-reviewed medical research only
- All content translated to Turkish for accessibility
- Streaming content appears word-by-word for engagement
- Citations linked to original research papers
- Conversations auto-save as "completed" sessions
- New conversation clears current chat history
- Past sessions searchable via library view
- Recall feature finds relevant past answers

#### Integrations/Dependencies:
- **Gemini 2.5 Flash:** Answer generation and research synthesis
- **Firebase Cloud Functions:** `diabetesAssistantStream` streaming endpoint
- **PubMed API:** Medical research paper retrieval
- **Clinical Trials API:** Clinical study data
- **SwiftData:** Session storage with conversation history
- **FTS5 SQLite:** Full-text search for cross-conversation recall
- **Markdown Rendering:** Custom AttributedString parser

#### Current status:
✅ Fully functional

#### Known limitations:
- Turkish language only (no English support)
- Requires internet connection for research
- Cannot access paywalled research papers
- No image/diagram support in answers
- Cannot save specific answers as favorites
- No offline mode for previously asked questions

---

### 3.7 Glucose Monitoring (Dexcom Integration)

#### What it does (user perspective):
Users can connect their Dexcom CGM device to see real-time glucose readings with beautiful trend visualizations, alerts, and historical data.

#### User flow:
1. User navigates to Settings → Dexcom CGM
2. System shows two connection options:
   - **Dexcom SHARE** (unofficial API, faster setup)
   - **Official Dexcom API** (OAuth, official support)
3. User chooses connection method:

**SHARE API Flow:**
4a. User enters Dexcom SHARE username and password
5a. User selects server (US/International)
6a. System authenticates and stores credentials in Keychain
7a. System retrieves session ID and starts polling
8a. Connection status shows "Connected" with green indicator

**Official API Flow:**
4b. User taps "Connect with Dexcom"
5b. System opens OAuth web flow in-app
6b. User logs into Dexcom account
7b. User authorizes app access
8b. System receives access token
9b. System starts fetching data via official endpoint

**Common Flow:**
10. System displays glucose chart with:
    - Current reading (large number display)
    - Trend arrow (rising, falling, stable)
    - 24-hour line chart with range shading
    - High/low glucose threshold bands
    - Time-series data points
11. System updates readings every 5 minutes automatically
12. User can view different time ranges (1h, 3h, 6h, 12h, 24h)
13. System syncs data to Apple Health (if permission granted)

#### Key capabilities:
- Dual integration: SHARE API + Official API hybrid
- Real-time glucose monitoring with 5-minute updates
- Beautiful line chart visualization with smooth animations
- Trend arrow indicators (↑↑ rising fast, ↓ falling, → stable)
- Customizable high/low glucose thresholds
- Range shading (in-range: green, high: red, low: yellow)
- Historical data display up to 24 hours
- Background data syncing even when app closed
- Automatic retry on connection failures
- Apple Health integration for glucose storage

#### Business rules:
- Glucose data updates every 5 minutes (Dexcom standard interval)
- SHARE API polls server every 5 minutes for new readings
- Official API uses webhooks for real-time push updates
- Readings older than 15 minutes show "stale data" warning
- High threshold default: 180 mg/dL, Low threshold: 70 mg/dL
- In-range target: 70-180 mg/dL for most users
- Credentials stored in Keychain for security (not UserDefaults)
- Session expires after 24 hours, requires re-authentication

#### Integrations/Dependencies:
- **Dexcom SHARE API:** Unofficial REST API for glucose data
- **Dexcom Official API:** OAuth-based official endpoint
- **Apple Health:** CGM data export for ecosystem integration
- **Keychain:** Secure credential storage for SHARE API
- **Firebase Firestore:** Future cloud backup of glucose history
- **Background fetch:** Automatic data updates while app inactive

#### Current status:
✅ Fully functional (hybrid SHARE + Official API)

#### Known limitations:
- SHARE API unofficial and may break with Dexcom updates
- Official API requires separate OAuth setup
- No alerts/notifications for high/low glucose yet
- Cannot manually add glucose readings for non-CGM users
- No data export to CSV or other formats
- No glucose predictions or trend forecasting
- International SHARE server support limited

---

### 3.8 Activity Tracking (Apple Health)

#### What it does (user perspective):
Users can view their daily activity metrics including steps, active energy, exercise time, and heart rate data synced from Apple Health in a beautiful card on the dashboard.

#### User flow:
1. User sees Activity Metrics card in dashboard carousel
2. System requests Apple Health permissions on first use
3. User grants permissions for:
   - Steps
   - Active Energy Burned
   - Exercise Minutes
   - Heart Rate
4. System syncs data from Apple Health automatically
5. Card displays:
   - Steps with goal progress ring
   - Active energy (calories)
   - Exercise minutes
   - Heart rate average
6. User can tap card to see detailed view (future enhancement)
7. Data refreshes automatically throughout the day

#### Key capabilities:
- Real-time activity data sync from Apple Health
- Steps tracking with visual progress indicator
- Active energy burned (calories)
- Exercise time tracking
- Heart rate monitoring
- Automatic background refresh
- Permission management with granular control

#### Business rules:
- Data refreshes every 30 minutes in background
- Steps goal default: 10,000 steps/day
- Active energy goal: based on user's Apple Health settings
- Heart rate shown as most recent reading
- No historical activity data stored locally (read-only from Health)
- Permissions required before data display

#### Integrations/Dependencies:
- **Apple HealthKit:** Read-only access to activity data
- **Background fetch:** Periodic data refresh
- **HealthKitPermissionManager:** Permission coordination

#### Current status:
✅ Fully functional

#### Known limitations:
- Read-only (cannot write activity to Health)
- No historical trends or charts for activity
- Cannot set custom step/calorie goals
- No activity-glucose correlation analysis
- Requires Apple Watch or iPhone for step tracking

---

### 3.9 Shopping List Management

#### What it does (user perspective):
Users can create and manage shopping lists, with automatic ingredient population from saved recipes.

#### User flow:
1. User taps shopping basket icon in Ardiye toolbar
2. System opens shopping list view
3. User can:
   - Add items manually via text input
   - Check off items as purchased
   - Delete items by swiping
   - Add entire recipe ingredient list
4. System organizes items by category (future enhancement)
5. Items persist across app sessions

#### Key capabilities:
- Manual item addition with name and quantity
- Recipe ingredient import
- Check/uncheck purchased items
- Swipe to delete
- Persistent storage across sessions

#### Business rules:
- Items stored in Core Data locally
- Checked items remain visible (not hidden)
- Recipe ingredients added as individual line items
- No duplicate detection (can add same item twice)

#### Integrations/Dependencies:
- **Core Data:** ShoppingListItem storage
- **Recipe integration:** Import ingredients from Recipe entities

#### Current status:
⚠️ Partially implemented (basic functionality works, category organization pending)

#### Known limitations:
- No category organization
- Cannot share lists with others
- No quantity tracking (checkboxes only)
- No store location suggestions
- Cannot reorder items
- No auto-complete for common items

---

### 3.10 User Profile Management

#### What it does (user perspective):
Users can create and switch between multiple user profiles on the same device, enabling family sharing with personalized data for each person.

#### User flow:
1. On first app launch, system shows user selection modal
2. User selects profile from:
   - **Serhat** (primary user, purple theme)
   - **Yağmur** (secondary user, pink theme)
3. System loads user-specific data and preferences
4. Each user has separate:
   - Meal history
   - Recipe favorites
   - Glucose data
   - Research conversations
5. User can switch profiles via Settings:
   - Settings → Change User
   - System shows user selection again
6. System saves current user preference locally

#### Key capabilities:
- Multi-user support on single device
- Profile-specific data isolation
- Visual differentiation (emoji + color theme)
- Quick user switching without re-authentication
- Separate favorites and meal logs per user

#### Business rules:
- User selection required on first launch
- Current user stored in UserDefaults
- All Core Data queries filtered by current user
- Glucose data specific to connected CGM device
- User switching preserves all data (no data loss)

#### Integrations/Dependencies:
- **UserDefaults:** Current user selection persistence
- **Core Data:** User-scoped data queries
- **UserProfileSelector:** Centralized user management

#### Current status:
✅ Fully functional

#### Known limitations:
- No cloud sync for multi-device user profiles
- Cannot create new users (limited to Serhat/Yağmur)
- No password/PIN protection for user profiles
- Cannot delete user data individually
- No user profile pictures (emoji only)

---

### 3.11 Settings & Configuration

#### What it does (user perspective):
Users can manage app settings, permissions, integrations, and account preferences.

#### User flow:
1. User taps gear icon from Ardiye toolbar
2. System shows settings organized by category:
   - **Account:** Current user, switch user, logout
   - **Health & Data:** Apple Health, Dexcom CGM, notifications
   - **Support & Info:** Contact, About, Version
3. User can:
   - Switch user profiles
   - Connect/disconnect Dexcom
   - Manage Apple Health permissions
   - Export data
   - View app version and credits

#### Key capabilities:
- User profile switching
- Dexcom connection management
- Apple Health permission management
- Data export (future)
- Notification settings (future)
- Theme selection (future)
- Language selection (future)

#### Business rules:
- Settings changes saved immediately
- Logout clears user selection (not data)
- Permission changes reflect in app immediately
- Version information read from bundle

#### Integrations/Dependencies:
- **UserProfileSelector:** User switching
- **HealthKitPermissionManager:** Health permissions
- **DexcomService:** CGM connection
- **About view:** Credits and branding

#### Current status:
✅ Fully functional (core settings implemented)

#### Known limitations:
- No data export yet (UI exists, functionality pending)
- No notification settings yet
- No theme/appearance customization
- Cannot change app language (Turkish only)
- No account management (no email/password)

---

## 4. User Flows & Journeys

### 4.1 Morning Routine: Log Breakfast with Voice

**User goal:** Quickly log breakfast while eating

**Steps:**
1. User opens app → Dashboard loads with current glucose reading
2. User taps "+" button in toolbar
3. Voice input modal slides up from bottom
4. User speaks: "Kahvaltıda iki yumurta, bir dilim tam buğday ekmeği ve bir bardak süt içtim"
5. System shows animated waveform while recording
6. User finishes speaking and taps stop button
7. System shows "Analyzing with Gemini..." loading state
8. System displays parsed result:
   - 2 eggs (0g carbs)
   - 1 slice whole wheat bread (15g carbs)
   - 1 glass milk (12g carbs)
   - **Total: 27g carbs**
   - Meal type: Breakfast
   - Time: 8:30 AM
9. User reviews and taps checkmark to save
10. System dismisses modal, returns to dashboard
11. New meal appears in daily log calendar

**Decision points:**
- If microphone permission denied → System prompts to open Settings
- If network fails → System shows error, allows retry
- If low confidence → System warns user to verify carb amounts

**Success criteria:**
- Meal logged in under 30 seconds
- Carbohydrate calculation accurate within ±10%
- All food items correctly identified

---

### 4.2 Meal Planning: Generate Diabetic-Friendly Dinner Recipe

**User goal:** Find a healthy dinner recipe that won't spike blood sugar

**Steps:**
1. User taps recipe generation button from dashboard
2. System shows meal type grid
3. User selects "Akşam Yemeği" (Dinner)
4. System shows style options: Traditional Turkish, Mediterranean, Asian, etc.
5. User selects "Traditional Turkish"
6. User chooses "Spontaneous" (no specific ingredients)
7. System shows "Generating your recipe..." with streaming dots
8. Recipe content streams in progressively:
   - Recipe name appears: "Zeytinyağlı Bamya" (Okra in Olive Oil)
   - Ingredients list populates line by line
   - Cooking instructions stream in
   - Nutritional info calculates in real-time
9. System generates beautiful food photo (takes 10-15 seconds)
10. Complete recipe displayed with:
    - Hero photo of finished dish
    - Prep time: 15 minutes
    - Cook time: 35 minutes
    - Ingredients: okra, tomatoes, olive oil, onion, garlic, lemon
    - Step-by-step instructions (8 steps)
    - Nutrition: 18g carbs, 4g protein, 12g fat per 100g
    - Glycemic load: 6 (Low)
11. User taps heart icon to favorite
12. System saves to Ardiye

**Decision points:**
- If recipe too similar to recent meals → System regenerates automatically
- If photo generation fails → System shows placeholder, allows retry
- If user wants different recipe → User taps "Generate New" button

**Success criteria:**
- Recipe generated in under 20 seconds (excluding photo)
- Recipe meets diabetic-friendly criteria (low glycemic load)
- No repetition of recipes from last 15 days
- Nutritional information accurate and complete

---

### 4.3 Grocery Shopping: Scan Packaged Food Label

**User goal:** Determine if packaged product is suitable for diabetic diet

**Steps:**
1. User at grocery store, picks up yogurt container
2. User opens app → Dashboard → Camera button
3. System requests camera permission (first time only)
4. Camera view opens with viewfinder overlay
5. User positions nutrition label within rectangle
6. User taps capture button (camera shutter sound)
7. System shows preview of captured image
8. User confirms "Use Photo"
9. System uploads to Gemini Flash for analysis
10. System shows "Analyzing nutrition label..." progress
11. Extracted data appears:
    - Brand: "Danone"
    - Product: "Greek Yogurt, Plain"
    - Serving: 150g
    - Carbs: 6.5g per serving
    - Protein: 10g
    - Fat: 3g
    - Confidence: 92% (High)
12. User reviews data, confirms accuracy
13. User taps "Save" button
14. System saves to Food Archive → Products section
15. User can now search for this product later

**Decision points:**
- If camera permission denied → System shows permission prompt
- If label blurry/unreadable → System shows "Please retake photo" error
- If confidence <70% → System shows warning to manually verify
- If network fails → System allows offline save with manual entry

**Success criteria:**
- Nutrition data extracted in under 10 seconds
- All key values (carbs, protein, fat) captured correctly
- User can quickly decide if product fits diet

---

### 4.4 Research: Learn About Glycemic Index

**User goal:** Understand which foods have low glycemic index

**Steps:**
1. User taps "Araştır" (Research) tab
2. System shows empty state with search bar
3. User types: "Hangi yiyecekler glisemik indeksi düşük?"
4. User taps enter to submit
5. System shows research stages:
   - "Searching medical databases..." (3 seconds)
   - "Analyzing research papers..." (5 seconds)
   - "Writing answer..." (begins streaming)
6. Answer streams in word-by-word:
   - **Introduction paragraph** about glycemic index concept
   - **List of low-GI foods:** non-starchy vegetables, whole grains, legumes, nuts
   - **Scientific explanation** with citations [1], [2], [3]
   - **Practical tips** for meal planning
7. Three follow-up questions appear:
   - "How does fiber affect glycemic index?"
   - "What's the difference between GI and glycemic load?"
   - "Can low-GI foods help control diabetes?"
8. User taps first follow-up question
9. System adds to conversation and streams new answer
10. Conversation continues naturally

**Decision points:**
- If no relevant research found → System explains and suggests rephrasing
- If user clicks citation [1] → System shows source metadata popup
- If user wants new topic → User clicks "New Conversation" toolbar button

**Success criteria:**
- Answer appears within 15 seconds
- Content is medically accurate with citations
- Language is accessible (not overly technical)
- Follow-up questions are relevant and helpful

---

## 5. Data & Integrations

### External Services

#### **Dexcom CGM (Continuous Glucose Monitor)**
- **Provides:** Real-time glucose readings every 5 minutes
- **How it's used:**
  - Hybrid integration: SHARE API (faster, unofficial) + Official API (OAuth, supported)
  - Automatic background polling for new readings
  - Historical data up to 24 hours
- **User-visible impact:**
  - Live glucose graph on dashboard
  - Trend arrows showing glucose direction
  - High/low alerts (future enhancement)
  - Automatic sync to Apple Health

#### **Apple HealthKit**
- **Provides:** Activity and health data ecosystem integration
- **How it's used:**
  - Read steps, active energy, exercise minutes, heart rate
  - Write glucose data from Dexcom for ecosystem sharing
  - Permission-based access with granular control
- **User-visible impact:**
  - Activity metrics card on dashboard
  - Holistic health view combining glucose + activity
  - Data available to other health apps

#### **Google Gemini 2.5 Flash (Generative AI)**
- **Provides:** Multimodal AI for text, image, and audio understanding
- **How it's used:**
  - Voice meal transcription (audio → structured meal data)
  - Nutrition label OCR (image → nutrition facts)
  - Recipe generation with streaming
  - Medical research synthesis with citations
- **User-visible impact:**
  - Natural language meal logging
  - Instant label scanning
  - Creative, varied recipe suggestions
  - Accessible medical research answers

#### **Google Imagen 4 Ultra (Image Generation)**
- **Provides:** Photorealistic image synthesis
- **How it's used:**
  - Generate beautiful food photography for recipes
  - 1:1 aspect ratio optimized for mobile display
  - Ultra quality setting (2K resolution)
- **User-visible impact:**
  - Gorgeous recipe photos that look restaurant-quality
  - Visual appeal encourages recipe exploration

#### **Firebase Cloud Functions**
- **Provides:** Serverless backend for AI workloads
- **How it's used:**
  - `transcribeMeal`: Audio → meal data
  - `extractNutritionFromImage`: Label scan → nutrition facts
  - `generateSpontaneousRecipe`: AI recipe generation
  - `diabetesAssistantStream`: Research question answering
- **User-visible impact:**
  - Fast AI processing without heavy local compute
  - Consistent experience across all devices
  - Background processing doesn't drain battery

#### **PubMed / Clinical Trials APIs**
- **Provides:** Access to peer-reviewed medical research
- **How it's used:**
  - Diabetes research paper retrieval
  - Clinical trial data for latest treatments
  - Citation sourcing for AI answers
- **User-visible impact:**
  - Research-backed answers with real citations
  - Access to cutting-edge diabetes information
  - Turkish translations of English research

### Data Types Managed

#### **Local Device Storage (Core Data)**
- User profiles (Serhat, Yağmur)
- Recipes (name, ingredients, instructions, nutrition, photo)
- Food items (scanned products + voice-logged meals)
- Meal entries (timestamp, meal type, carbs, food items)
- Shopping list items
- Recipe favorites and user preferences

#### **Cloud Storage (Firebase Firestore - Future)**
- Recipe cloud backup (planned)
- Cross-device sync (planned)
- User preferences (planned)

#### **Memory/Cache (Local)**
- FTS5 full-text search index for research conversations
- SwiftData for research session history
- Recent recipe memory (last 10 recipes for variety checking)

### Offline Capabilities

**Works Offline:**
- Browse saved recipes in Food Archive
- View past meal logs from calendar
- View cached glucose data (last sync)
- Access shopping list
- Switch user profiles
- View app settings

**Requires Internet:**
- Voice meal logging (Gemini transcription)
- Nutrition label scanning (Gemini vision)
- Recipe generation (Gemini content generation)
- Recipe photo generation (Imagen)
- Medical research queries (PubMed + Gemini)
- Dexcom glucose data fetch
- Apple Health sync (device-local, not internet)

**Sync Behavior:**
- Glucose data syncs every 5 minutes when connected
- Apple Health data refreshes every 30 minutes
- Research conversations auto-save locally
- Recipe photos stored locally (no cloud upload)
- No manual "Refresh" button needed (automatic background fetch)

---

## 6. Business Logic & Rules

### Recipe Generation Rules

#### **Variety Enforcement (15-Day Non-Repetition)**
- System tracks main ingredients of last 10 generated recipes
- Before showing recipe, AI extracts 3-5 main ingredients
- System checks similarity: if 3+ ingredients match recent recipe → regenerate
- Single retry only: second attempt accepted regardless of similarity
- Memory sliding window: older recipes beyond 10 automatically forgotten
- Main ingredient extraction uses AI (not hardcoded rules)

**Example:**
- Day 1: Generate "Chicken with Rice" → main ingredients: [chicken, rice, onion]
- Day 5: Generate "Grilled Chicken Salad" → main ingredients: [chicken, lettuce, tomato]
- System detects "chicken" overlap but only 1 match → accepted
- Day 7: Generate "Chicken Rice Pilaf" → main ingredients: [chicken, rice, butter]
- System detects 2 matches (chicken, rice) ≥ 50% overlap → regenerate
- Retry: "Lentil Soup" → main ingredients: [lentils, carrot, tomato] → accepted

#### **Nutritional Validation**
- All nutrition values calculated per 100g for consistency
- Glycemic load = (carbs × glycemic index) / 100
- Low glycemic load: <10
- Medium: 10-20
- High: >20
- Recipes optimized for low-medium glycemic load (<15)

### Voice Meal Logging Rules

#### **Food Item Parsing**
- Turkish language only
- Each food mentioned → separate FoodItem entry
- Example: "Ekmek ve peynir yedim" → 2 separate entries
- If quantities unclear → distribute total carbs proportionally
- Meal type inferred from time if not stated:
  - 05:00-11:00 → Breakfast
  - 11:00-15:00 → Lunch
  - 15:00-17:00 → Snack
  - 17:00-22:00 → Dinner
  - 22:00-05:00 → Late snack

#### **Confidence Scoring**
- High confidence (>80%): No warning shown
- Medium confidence (60-80%): Yellow warning "Please verify amounts"
- Low confidence (<60%): Red warning "Manual verification required"

### Nutrition Label Scanning Rules

#### **OCR Validation**
- Serving size must be present and numeric
- Carbohydrates field required (cannot be zero)
- Protein, fat optional but encouraged
- Confidence score aggregated from:
  - OCR confidence (text recognition)
  - Carbs confidence (value extraction)
  - Overall confidence (field completeness)

#### **Impact Level Calculation**
- Low impact: Carbs <10g per serving
- Medium impact: 10-25g carbs per serving
- High impact: >25g carbs per serving
- Color coding: Green (low), Yellow (medium), Red (high)

### Glucose Monitoring Rules

#### **Data Freshness**
- Readings update every 5 minutes (Dexcom standard)
- Readings >15 minutes old flagged as "stale"
- Stale data shown with gray timestamp
- If no reading in 30 minutes → "No recent data" warning

#### **Threshold Alerts (Future)**
- Default high threshold: 180 mg/dL
- Default low threshold: 70 mg/dL
- User customizable in settings
- Alert triggers when reading crosses threshold

### Data Persistence Rules

#### **User Profile Scoping**
- All Core Data entities scoped to current user
- User switching preserves all data
- No data deletion on user switch
- Glucose data shared across profiles (device-specific)

#### **Auto-Save Behavior**
- All changes save immediately to Core Data
- No explicit "Save" button in most screens
- Background save on app quit
- Crash recovery via Core Data persistent store

---

## 7. User Experience Specifications

### Language & Localization
- **Supported Language:** Turkish only (TR)
- **UI Language:** All interface text in Turkish
- **Voice Input:** Turkish language recognition via Gemini
- **Research Output:** English research papers translated to Turkish
- **Future:** English localization planned

### Platform Support
- **iOS Version:** iOS 26+ required
- **Device Support:** iPhone only (iPad not optimized)
- **Device Requirements:**
  - Camera for label scanning
  - Microphone for voice meal logging
  - Internet connection for AI features
  - Optional: Apple Watch for activity data
  - Optional: Dexcom CGM device for glucose monitoring

### Accessibility
- **VoiceOver:** Partial support (not fully tested)
- **Dynamic Type:** Font scaling supported via `scaledSize()` utility
- **Color Contrast:** WCAG AA compliance for text on backgrounds
- **Haptic Feedback:** Provided for key actions (capture, voice stop)
- **Reduced Motion:** Not yet implemented

### Performance Expectations

#### **App Launch**
- Cold launch to dashboard: <3 seconds
- Initial data sync on first launch: 5-10 seconds
- Subsequent launches: <2 seconds (cached data)

#### **Feature Performance**
- Voice meal logging: 10-15 seconds (including transcription)
- Nutrition label scan: 5-10 seconds (including extraction)
- Recipe generation: 15-20 seconds (excluding photo)
- Recipe photo generation: 10-15 seconds
- Research query: 10-20 seconds (streaming begins sooner)
- Glucose data refresh: 2-3 seconds

#### **Offline Experience**
- Recipe browsing: Instant (local data)
- Meal log history: Instant (local data)
- Research conversations: 20-30 cached sessions searchable offline
- Shopping list: Instant (local data)

---

## 8. Success Metrics & KPIs

### Product Success Measured By:

#### **Engagement Metrics**
- Daily active users (DAU)
- Session frequency: Target 3-5 sessions/day
- Session duration: Target 2-3 minutes per session
- Feature adoption rate: % users using each feature
- Voice meal logging adoption: Target 60% of meal logs

#### **Health Outcome Indicators**
- Time-in-range (TIR) improvement: % time glucose 70-180 mg/dL
- Carbohydrate tracking consistency: % days with logged meals
- Recipe generation usage: # recipes generated per user/week
- Research query frequency: # questions asked per user/week

#### **User Satisfaction Indicators**
- Recipe save rate: % generated recipes favorited
- Voice transcription accuracy feedback
- Label scan confidence scores
- Feature completion rates (start → finish)

### Feature Usage Metrics

#### **Essential Features (Daily Use)**
- Dashboard views
- Glucose monitoring
- Voice meal logging
- Recipe browsing

#### **Regular Features (Weekly Use)**
- Recipe generation
- Nutrition label scanning
- Research queries
- Shopping list updates

#### **Occasional Features (Monthly Use)**
- User profile switching
- Settings configuration
- Data export
- Dexcom connection management

---

## 9. Known Issues & Limitations

### Current Product Limitations

#### **Multi-User Management**
- Only 2 hardcoded users (Serhat, Yağmur)
- Cannot create custom user profiles
- No password/PIN protection for profiles
- No user avatars (emoji only)
- Cannot delete user-specific data

#### **Data Management**
- No cloud backup (all data local only)
- No cross-device sync
- No data export functionality (UI exists, not implemented)
- Cannot import recipes from websites
- Cannot share recipes with other users
- Deleted items cannot be recovered (no trash)

#### **Glucose Monitoring**
- No manual glucose entry for non-CGM users
- No glucose predictions or trend forecasting
- No high/low glucose alerts yet
- Cannot set custom time-in-range targets
- No A1C estimation from glucose trends

#### **Recipe System**
- Cannot filter recipes by tags or categories
- No meal planning calendar (future)
- Cannot scale recipe servings
- No cooking timers or step-by-step mode
- Cannot print or export recipes

#### **Voice Meal Logging**
- Turkish language only (no English support)
- No offline voice transcription
- Cannot edit transcription before processing
- Maximum recording length undefined
- No support for mixed languages

#### **Research Assistant**
- No image support in research answers
- Cannot save specific answers as bookmarks
- No offline access to cached research
- No PDF export of research sessions
- Limited to text-based questions

### Scale Limitations

#### **Performance Constraints**
- Recipe memory limited to last 10 recipes (performance optimization)
- Research session storage: 1000 sessions max (then auto-cleanup)
- FTS5 search index: 10MB max size
- Recipe photos: Compressed to <500KB per image
- Voice recordings: Max 2 minutes (Gemini API limit)

#### **Concurrency Limits**
- Firebase Cloud Functions: 2 concurrent requests per endpoint
- Gemini API: Rate limited to 60 requests/minute
- Dexcom SHARE: 1 request per 5 minutes
- Apple Health sync: 30-minute intervals

---

## 10. Product Roadmap Context

### What's Complete ✅

#### **Core Functionality**
- Multi-user profile system (Serhat, Yağmur)
- Voice meal logging with AI transcription
- Nutrition label scanning with OCR
- Recipe generation (spontaneous + from ingredients)
- Recipe photo generation with AI
- Food archive with search and favorites
- Medical research assistant with citations
- Dexcom CGM integration (SHARE + Official API)
- Apple Health activity tracking
- Shopping list management
- Settings and configuration

#### **AI/ML Capabilities**
- Gemini 2.5 Flash integration for all AI features
- Imagen 4 Ultra for recipe photography
- Turkish NLP for voice meal understanding
- Recipe memory system for variety enforcement
- Full-text search for research conversations

#### **User Experience**
- iOS 26 Liquid Glass design system
- Beautiful data visualizations
- Smooth animations and transitions
- Haptic feedback for key actions
- Error handling and retry logic
- Loading states and progress indicators

### What's In Progress 🚧

#### **Infrastructure**
- Firebase Firestore schema design (data models exist, cloud sync pending)
- Background task scheduling for glucose sync
- Memory sync coordinator for cross-conversation recall
- Developer mode for testing

### What's Missing 💡

#### **High Priority (Next 3-6 months)**
- **Notifications:** High/low glucose alerts
- **Meal Planning Calendar:** Weekly meal planner with recipes
- **Data Export:** CSV export for meals, glucose, recipes
- **Recipe Collections:** Organize recipes into folders/tags
- **Offline Mode:** Cache generated recipes for offline access
- **Cloud Sync:** Backup recipes and meals to Firebase

#### **Medium Priority (6-12 months)**
- **Recipe Scaling:** Adjust servings with automatic quantity recalculation
- **Cooking Mode:** Step-by-step guided cooking with timers
- **Medication Tracking:** Log insulin doses and medications
- **A1C Estimation:** Calculate estimated A1C from glucose trends
- **Trend Forecasting:** Predict future glucose trends using ML
- **Social Features:** Share recipes with other users

#### **Low Priority (12+ months)**
- **Apple Watch App:** Standalone glucose monitoring on watch
- **iPad App:** Optimized layout for large screens
- **English Localization:** Support for English-speaking users
- **Web App:** Access recipes and research from desktop
- **Community Features:** Public recipe sharing and ratings
- **Integration API:** Third-party app integrations

### Technical Debt to Address
- Consolidate duplicate FoodItem sources (voice vs. scanned)
- Optimize Core Data fetch requests (add batch limits)
- Implement proper image caching for recipe photos
- Add comprehensive error tracking (Sentry or similar)
- Increase test coverage (currently <50%)
- Document API endpoints with OpenAPI spec

---

## Appendix: Key Technologies

### iOS Stack
- **SwiftUI:** Modern declarative UI framework
- **Swift 6:** Strict concurrency model with actors
- **Core Data:** Local database for recipes, meals, users
- **SwiftData:** Research session storage
- **HealthKit:** Apple Health integration
- **AVFoundation:** Camera and audio recording
- **OSLog:** Structured logging

### Backend Stack
- **Firebase Cloud Functions:** Serverless compute (Node.js)
- **Firebase Genkit:** AI orchestration framework
- **Gemini 2.5 Flash:** Multimodal AI (text, image, audio)
- **Imagen 4 Ultra:** Photorealistic image generation
- **Firebase Firestore:** NoSQL cloud database (future)
- **Firebase Storage:** Recipe photo cloud storage (future)

### AI/ML
- **Google Gemini API:** Generative AI workloads
- **PubMed API:** Medical research retrieval
- **Clinical Trials API:** Clinical study data
- **FTS5 SQLite:** Full-text search for recall

### External Services
- **Dexcom API:** CGM glucose data
- **Dexcom SHARE API:** Unofficial CGM access
- **Apple Health:** Activity and health data

---

**END OF PRODUCT SPECIFICATION**

**Document Metadata:**
- **Total Feature Count:** 11 major features
- **Total User Flows Documented:** 4 key journeys
- **Integration Count:** 9 external services
- **Status:** Living document (updated quarterly)
- **Primary Audience:** Product managers, stakeholders, new engineers
- **Secondary Audience:** QA testers, technical writers, UX designers

For questions or updates, contact: Product Team @ Anaxonic Labs
