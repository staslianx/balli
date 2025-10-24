---
description: Generate a Product Specification Document from current codebase state
argument-hint: "[optional: specific feature area to focus on]"
allowed-tools:
  - Bash
  - FileSystem
---

# Product Specification Document Generator

Generate a comprehensive Product Specification Document that describes what the product does from a user and product perspective, NOT from an engineering perspective. Focus on "$ARGUMENTS" if specified, otherwise cover entire product.

## Document Structure

Create a professional product spec with these sections:

### 1. Product Overview
**Write in plain language:**
- **Product Name**: [Extract from app name/bundle identifier]
- **Product Vision**: What problem does this solve? Who is it for?
- **Target Users**: Who uses this app and why?
- **Core Value Proposition**: What makes this product valuable?

**Extract from:**
- App name, marketing strings
- Comments or README files
- Feature set analysis

### 2. Product Capabilities Summary
**High-level capabilities** (not features yet):
- What can users accomplish with this product?
- What are the main use cases?
- What workflows does it support?

Example format:
- "Users can monitor their glucose levels in real-time"
- "Users can log meals and track nutritional information"
- "Users can access medical research translated to their language"

### 3. Feature Inventory

For each feature, document in this format:

#### [Feature Name]
**What it does (user perspective):**
[1-2 sentences describing what users can do]

**User flow:**
1. User does X
2. System shows Y
3. User can then Z

**Key capabilities:**
- Capability 1
- Capability 2
- Capability 3

**Business rules:**
- Rule 1 (e.g., "recipes don't repeat within 15 days")
- Rule 2
- Rule 3

**Integrations/Dependencies:**
- [e.g., "Requires Dexcom API connection"]

**Current status:**
- ✅ Fully functional
- ⚠️ Partially implemented (specify what's missing)
- 🚧 In development
- 💡 Planned but not started

**Known limitations:**
- [What users can't do that they might expect]

---

**How to identify features:**
- Look at main navigation/tabs
- Check ViewModels and their responsibilities
- Analyze screen flows
- Read Firebase collections (what data types exist = what features exist)
- Check API endpoints/Cloud Functions

**Feature categories to look for:**
- Authentication & User Management
- Health Data Tracking (glucose, meals, etc.)
- Recipe/Meal Planning
- Research & Information
- Settings & Preferences
- Notifications
- Data Sync & Offline
- Analytics/Insights

### 4. User Flows & Journeys

Document key user journeys:

#### [Journey Name] (e.g., "Logging a Meal")
**User goal:** [What user wants to accomplish]

**Steps:**
1. [User action] → [System response]
2. [User action] → [System response]
3. [Final outcome]

**Decision points:**
- If [condition], then [path A], else [path B]

**Success criteria:**
- [How do we know user succeeded?]

**Common patterns to document:**
- Onboarding flow
- Core task completion (most common user action)
- Data entry workflows
- Settings/configuration
- Error recovery

### 5. Data & Integrations

**External Services:**
- Service name
- What it provides
- How it's used in product
- User-visible impact

Example:
- **Dexcom API**: Provides real-time glucose readings
  - Users see continuous glucose monitoring
  - Data updates every 5 minutes
  - Syncs automatically in background

**Data Types Managed:**
- User profile data
- Health metrics
- Recipes/meals
- Research content
- [etc.]

**Offline Capabilities:**
- What works offline?
- What requires internet?
- How does sync work from user perspective?

### 6. Business Logic & Rules

Document the "rules of the game":

**Content Generation Rules:**
- Recipe variety requirements
- Translation requirements
- Personalization logic

**Data Validation:**
- Required fields
- Valid ranges
- Format requirements

**User Permissions:**
- Who can do what?
- Any role-based access?

**Timing & Triggers:**
- When do things happen automatically?
- What triggers notifications?
- Background processes users should know about

### 7. User Experience Specifications

**Language & Localization:**
- Supported languages
- Translation approach
- Content localization

**Platform Support:**
- iOS version requirements
- Device support
- Feature availability by platform

**Accessibility:**
- What accessibility features exist?
- Any limitations?

**Performance Expectations:**
- How fast should things load?
- What's acceptable lag?
- Offline experience

### 8. Success Metrics & KPIs

**Product success measured by:**
- [Engagement metrics]
- [Health outcome metrics]
- [User satisfaction indicators]

**Feature usage metrics:**
- Which features are essential vs. nice-to-have?
- Expected usage patterns

### 9. Known Issues & Limitations

**Current product limitations:**
- What users might expect but can't do
- Workarounds required
- Planned improvements

**Scale limitations:**
- Data volume limits
- Performance constraints
- User capacity

### 10. Product Roadmap Context

**What's complete:**
- [List major capabilities that work end-to-end]

**What's in progress:**
- [Features partially built]

**What's missing:**
- [Obvious gaps or expected features not yet built]

## Writing Guidelines

**DO:**
- Write in present tense: "Users can log meals"
- Focus on user actions and outcomes
- Use plain language, no technical jargon
- Be specific about what works vs. what doesn't
- Include actual examples from the app

**DON'T:**
- Talk about code architecture
- Mention ViewModels, Services, Managers
- Describe technical implementation
- Use engineering terms (API calls, database schemas, etc.)
- Be vague ("good user experience")

**Translation Examples:**

❌ Engineering: "The RecipeViewModel uses Gemini 2.5 Flash via Firebase Cloud Functions"
✅ Product: "Users receive AI-generated recipe suggestions based on their dietary needs"

❌ Engineering: "Implemented 15-day sliding window with category-based tracking"
✅ Product: "Recipe suggestions vary daily and won't repeat the same meal within 2 weeks"

❌ Engineering: "SwiftUI views with MVVM architecture"
✅ Product: "Users see a modern, iOS-native interface with smooth animations"

❌ Engineering: "Firebase Firestore with offline persistence enabled"
✅ Product: "App works offline and syncs data automatically when connected"

## Analysis Process

### Step 1: Map the Product Structure
- Read app entry point (App.swift, AppDelegate)
- Identify main navigation structure
- List all screens/views
- Map screen hierarchy

### Step 2: Identify Feature Modules
- Check project structure/folders
- Look for feature-focused view groups
- Analyze Firebase collections
- Review Cloud Functions

### Step 3: Extract Business Logic
- Read any configuration files
- Check for business rule constants
- Analyze validation logic
- Look for feature flags or remote config

### Step 4: Document User Flows
- Trace navigation paths
- Identify form submissions
- Map data creation/editing flows
- Document search and discovery

### Step 5: Find Integration Points
- Identify external APIs (Dexcom, etc.)
- Check authentication providers
- Look for third-party SDKs
- Document data sources

### Step 6: Assess Completeness
- Check for TODO comments
- Identify stub implementations
- Look for disabled features
- Find incomplete flows

## Specific Files to Analyze

**iOS Structure:**
- Main app file (App.swift)
- Root views and navigation
- Feature view folders
- Models (understand data types)
- Any Constants or Config files

**Firebase:**
- firebase.json (what's configured)
- Firestore structure (collections = features)
- Cloud Functions (what automation exists)
- firestore.rules (understand data access)

**Documentation:**
- README files
- CLAUDE.md
- Any design docs
- Comments in code

## Output Format

Create a **markdown document** saved as `PRODUCT_SPEC.md` with:
- Clear section headers
- Bullet points for readability
- Tables where appropriate
- Examples for clarity
- Emoji indicators (✅ ⚠️ 🚧 💡) for status

**Length guidance:**
- Be thorough but not exhaustive
- Each feature: 1 paragraph + bullets
- Each user flow: 5-10 steps
- Total doc: 15-30 pages equivalent

## Example Feature Documentation

#### Meal Logging
**What it does:**
Users can log meals by entering food items and quantities. The app calculates total carbohydrates and tracks nutritional information to help manage glucose levels.

**User flow:**
1. User taps "Log Meal" from home screen
2. System shows meal entry form with time pre-filled to now
3. User adds food items either by search or manual entry
4. For each item, user specifies quantity/serving size
5. System calculates total carbs automatically
6. User can add notes or photos (optional)
7. User taps "Save"
8. System logs meal and shows it in meal history
9. If glucose monitoring is connected, system will track post-meal glucose response

**Key capabilities:**
- Add multiple food items per meal
- Search food database for nutritional info
- Manual entry for custom foods
- Automatic carb calculation
- Photo attachment
- Meal history tracking
- Integration with glucose monitoring

**Business rules:**
- Meals must have at least one food item
- Carb calculations round to nearest gram
- Photos are optional but compressed for storage
- Meal timestamp can be edited within same day
- Deleted meals are archived, not permanently removed

**Integrations/Dependencies:**
- Uses food database API for nutritional lookup
- Syncs with glucose monitor for meal-glucose correlation
- Firebase storage for meal photos

**Current status:**
✅ Fully functional

**Known limitations:**
- Food database only includes common Turkish and international foods
- Cannot log meals more than 24 hours in the past
- No barcode scanning yet
- Cannot split meals or log partial servings

---

Generate a complete, professional Product Specification Document that a non-technical stakeholder could read and understand exactly what the product does and how users interact with it.
