# PORTION SYSTEM FORENSIC INVESTIGATION REPORT
**Date:** 2025-11-05
**Investigator:** Claude Code (Forensic Debugging Specialist)
**Priority:** P0 - CRITICAL BUGS (Breaking User Experience)

---

## EXECUTIVE SUMMARY

Three critical bugs confirmed in the portion adjustment system. All stem from a fundamental **architectural mismatch** between:
- `recipe.portionSize` (user-defined portion in Core Data)
- `portionMultiplier` (temporary UI multiplier, also in Core Data)

**Root Cause:** The system conflates TWO DIFFERENT CONCEPTS:
1. **Defining** what "1 portion" means (saved as `portionSize`)
2. **Multiplying** a portion temporarily for display (using `portionMultiplier`)

This confusion causes the three reported bugs.

---

## BUG #1: Stepper Only Changes Header Text

### 🔴 SYMPTOM
User taps stepper (- 1.0x +) → Only the header "1 porsiyon: 272g" changes → Nutrition values (calories, carbs, etc.) stay the same.

### 🔍 ROOT CAUSE ANALYSIS

**Location:** `NutritionalValuesView.swift` lines 449-475

```swift
// Portion multiplier stepper
HStack(spacing: 8) {
    Button {
        if portionMultiplier > 0.5 {
            portionMultiplier -= 0.5  // ✅ Changes binding
        }
    } label: {
        Image(systemName: "minus.circle.fill")
    }

    Text(String(format: "%.1f", portionMultiplier) + "x")  // ✅ Updates

    Button {
        portionMultiplier += 0.5  // ✅ Changes binding
    } label: {
        Image(systemName: "plus.circle.fill")
    }
}
```

**What happens when stepper is tapped:**

1. ✅ `portionMultiplier` binding updates (e.g., 1.0 → 1.5)
2. ✅ Header text updates via `infoText` computed property (line 334-347):
   ```swift
   let multipliedWeight = (Double(totalRecipeWeight) ?? 0) * portionMultiplier
   return Text("1 porsiyon: **\(String(format: "%.0f", multipliedWeight))g**")
   ```
3. ❌ **NUTRITION VALUES DON'T UPDATE** because they use `displayedCalories`, `displayedCarbohydrates`, etc. (lines 349-410)

**Why don't nutrition values update?**

Look at `displayedCalories` (line 349-356):

```swift
private var displayedCalories: String {
    if selectedTab == 0 {
        let value = (Double(caloriesPerServing) ?? 0) * portionMultiplier  // ✅ Uses multiplier
        return String(format: "%.0f", value)
    } else {
        return calories  // 100g tab
    }
}
```

**WAIT - This SHOULD work!** The code multiplies by `portionMultiplier`. So why doesn't it update?

**THE PROBLEM:** SwiftUI doesn't know these computed properties depend on `portionMultiplier`!

- `displayedCalories` is a computed property that reads `portionMultiplier`
- BUT when `portionMultiplier` changes, SwiftUI doesn't re-evaluate `displayedCalories` in the view body
- This is because the **nutrition card is rendered ONCE** when the view loads

**Proof:** The stepper is OUTSIDE the collapsed card (line 437), but the nutrition values are INSIDE the main card (lines 76-175). When you tap the stepper:
- The stepper's own UI updates (because it's bound to `@Binding`)
- The header updates (because it's in `infoText` which is evaluated in the card)
- BUT the nutrition rows don't re-render because they were already rendered with the initial `portionMultiplier` value

**Evidence from code structure:**

```
unifiedPortionCard (lines 415-559)
├─ Header row (lines 418-485)
│  └─ Stepper (lines 449-475) ← Changes portionMultiplier
└─ Slider section (lines 488-553)

Main nutrition card (lines 76-175)
├─ infoText header (line 79) ← ✅ Updates because re-evaluated
└─ Nutrition rows (lines 94-168)
   ├─ displayedCalories (line 97) ← ❌ Not re-evaluated
   ├─ displayedCarbohydrates (line 108)
   └─ ... other nutrition values
```

### 💡 WHY THIS IS A SWIFTUI REACTIVITY ISSUE

The computed properties ARE correct. The problem is SwiftUI's view update cycle:

1. When `@Binding var portionMultiplier: Double` changes, SwiftUI marks the view as needing update
2. SwiftUI re-renders ONLY the parts that directly reference the binding
3. The stepper UI directly references `portionMultiplier` → Updates ✅
4. The nutrition rows call `displayedCalories` → This is a **computed property** that reads `portionMultiplier`
5. BUT SwiftUI doesn't trace through computed properties to detect dependencies!

**Solution:** The nutrition rows need to **explicitly depend** on `portionMultiplier` so SwiftUI knows to re-render them.

---

## BUG #2: Saved Portion Doesn't Update Card Display

### 🔴 SYMPTOM
1. User opens portion card (shows 200g)
2. Slides to 150g
3. Taps "Porsiyonu Kaydet"
4. Success banner shows
5. Card collapses
6. **BUG:** Card STILL shows 200g (should show 150g)

### 🔍 ROOT CAUSE ANALYSIS

**Location:** `NutritionalValuesView.swift` lines 206-254

```swift
private func savePortionSize() {
    guard let recipe = recipe else { return }

    // Update recipe
    recipe.updatePortionSize(adjustingPortionWeight)  // ✅ Saves to portionSize

    // Save to Core Data
    try viewContext.save()  // ✅ Persists

    // Show success feedback
    withAnimation(.spring()) {
        showSuccessBanner = true
    }

    // Collapse section after brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        withAnimation {
            showSuccessBanner = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPortionAdjustmentExpanded = false  // ✅ Collapses
            }
        }
    }
}
```

**What the save does:**

1. ✅ Calls `recipe.updatePortionSize(adjustingPortionWeight)` → Updates `recipe.portionSize` to 150g
2. ✅ Saves to Core Data → Persists to database
3. ✅ Shows success banner
4. ✅ Collapses the card

**What displays in the collapsed card header (line 437-447):**

```swift
if !isPortionAdjustmentExpanded {
    // Show current portion value
    HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text("\(Int(currentPortionSize))")  // ← Uses currentPortionSize
            .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.primaryPurple)

        Text("g")
            .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }
    ...
}
```

**What is `currentPortionSize`? (line 285-288)**

```swift
private var currentPortionSize: Double {
    guard let recipe = recipe else { return 0 }
    return recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight
}
```

**ANALYSIS:**

1. ✅ `recipe.portionSize` gets updated to 150g
2. ✅ Core Data saves successfully
3. ✅ `currentPortionSize` reads from `recipe.portionSize`
4. ❌ **BUT SWIFTUI DOESN'T RE-RENDER** because:
   - `recipe` is a `let recipe: Recipe?` parameter (line 19)
   - It's NOT `@ObservedObject` or `@StateObject`
   - Changes to the recipe don't trigger view updates

**THE FUNDAMENTAL PROBLEM:**

```swift
struct NutritionalValuesView: View {
    let recipe: Recipe?  // ❌ Not observable!
    @Binding var portionMultiplier: Double  // ✅ Observable
    ...
}
```

- The `Recipe` object is a Core Data `NSManagedObject`
- Core Data changes DON'T automatically trigger SwiftUI updates
- You need `@ObservedObject` or `@FetchRequest` for reactivity

**Why does this happen?**

When you call `recipe.updatePortionSize(150)`:
1. The `recipe` object in memory updates
2. Core Data saves to disk
3. BUT the SwiftUI view doesn't know to re-read `currentPortionSize`
4. The view still shows the OLD cached value (200g)

**Evidence:** If you close the modal and reopen it, it WILL show 150g (because it reads fresh from Core Data).

---

## BUG #3: Nutrition Values Don't Update When Slider Moves

### 🔴 SYMPTOM
User moves slider from 272g → 150g → Nutrition values stay the same.

### 🔍 ROOT CAUSE ANALYSIS

**Location:** `NutritionalValuesView.swift` lines 508-520

```swift
Slider(
    value: $adjustingPortionWeight,
    in: minPortionSize...recipe.totalRecipeWeight,
    step: sliderStep
)
.onChange(of: adjustingPortionWeight) { _, newValue in
    // Update portion multiplier to reflect slider changes in main nutrition card
    guard recipe.portionSize > 0 else { return }
    let ratio = newValue / recipe.portionSize
    portionMultiplier = ratio  // ✅ Updates binding
}
```

**What happens when slider moves:**

1. ✅ `adjustingPortionWeight` updates (e.g., 272g → 150g)
2. ✅ `onChange` fires
3. ✅ Calculates ratio: `150 / 200 = 0.75`
4. ✅ Sets `portionMultiplier = 0.75`
5. ❌ **NUTRITION VALUES DON'T UPDATE**

**Why not?**

Same issue as Bug #1! The nutrition rows in the main card (lines 94-168) don't re-render when `portionMultiplier` changes because SwiftUI doesn't track the dependency through computed properties.

---

## ARCHITECTURAL PROBLEMS

### Problem 1: Two Storage Locations for Related Data

```swift
@NSManaged public var portionSize: Double         // Core Data - "What is 1 portion?"
@NSManaged public var portionMultiplier: Double   // Core Data - "How many portions am I viewing?"
```

**Issues:**
- `portionSize` is persistent (saved to database)
- `portionMultiplier` is ALSO persistent (saved to database)
- This creates confusion: is `portionMultiplier` temporary UI state or saved data?

**Evidence:** In `RecipeDetailView.swift` (lines 216-224):

```swift
portionMultiplier: Binding(
    get: { recipeData.recipe.portionMultiplier },
    set: { newValue in
        recipeData.recipe.portionMultiplier = newValue
        Task { @MainActor in
            viewModel.savePortionMultiplier()  // ← Saves to Core Data!
        }
    }
)
```

**This is WRONG for a multiplier!** A multiplier should be:
- **Temporary UI state** (like a "zoom level")
- **Reset to 1.0** when you close and reopen the modal
- **NOT persisted** to the database

**Why?** Because the multiplier is for **temporary viewing adjustments**, not for redefining the portion.

### Problem 2: Conflating Definition and Display

The system tries to do TWO THINGS with the same UI:

1. **Define** what "1 portion" means (permanent, saved to `portionSize`)
2. **View** different portion sizes temporarily (temporary, using `portionMultiplier`)

**Evidence:** The slider does BOTH:
- When you move the slider, it updates `portionMultiplier` (temporary display)
- When you click "Porsiyonu Kaydet", it saves to `portionSize` (permanent definition)

**This is confusing** because:
- The slider shows grams (e.g., 150g) → Suggests you're defining a portion
- But the stepper shows multiplier (e.g., 1.5x) → Suggests you're viewing multiple portions
- These are DIFFERENT operations!

### Problem 3: No Observable Recipe

```swift
struct NutritionalValuesView: View {
    let recipe: Recipe?  // ❌ Not observable
    @Binding var portionMultiplier: Double
}
```

**Why this is a problem:**
- When you update `recipe.portionSize`, the view doesn't re-render
- You need `@ObservedObject var recipe: Recipe` for reactivity
- BUT Core Data objects require special handling in SwiftUI

---

## COMPLETE DATA FLOW ANALYSIS

### EXPECTED Flow (What SHOULD Happen)

```
┌─────────────────────────────────────────────────────────────────┐
│ USER OPENS MODAL                                                │
├─────────────────────────────────────────────────────────────────┤
│ Recipe has:                                                     │
│ - portionSize = 200g (user-defined "1 portion")                │
│ - totalRecipeWeight = 400g (entire recipe)                     │
│ - caloriesPerServing = 500 (for 1 portion = 200g)              │
│                                                                 │
│ UI shows:                                                       │
│ - Portion card: "200g" with "1.0x" multiplier                  │
│ - Main card: "1 porsiyon: 200g" with 500 kcal                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER TAPS STEPPER: 1.0x → 1.5x                                 │
├─────────────────────────────────────────────────────────────────┤
│ Expected:                                                       │
│ - portionMultiplier: 1.0 → 1.5                                 │
│ - Header: "1 porsiyon: 200g" → "1 porsiyon: 300g"              │
│ - Calories: 500 kcal → 750 kcal (500 × 1.5)                    │
│ - Carbs: 50g → 75g (50 × 1.5)                                  │
│ - All nutrition values scale by 1.5x                            │
│                                                                 │
│ Actual:                                                         │
│ ✅ portionMultiplier updates to 1.5                            │
│ ✅ Header updates to "1 porsiyon: 300g"                        │
│ ❌ Calories stay at 500 kcal                                    │
│ ❌ Carbs stay at 50g                                            │
│ ❌ No nutrition values update                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER EXPANDS PORTION CARD                                       │
├─────────────────────────────────────────────────────────────────┤
│ Expected:                                                       │
│ - adjustingPortionWeight initializes to: currentPortionSize × 1.5│
│   = 200g × 1.5 = 300g                                           │
│ - Slider shows 300g                                             │
│                                                                 │
│ Actual:                                                         │
│ ✅ adjustingPortionWeight = 300g (line 424)                    │
│ ✅ Slider shows 300g                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER MOVES SLIDER: 300g → 150g                                 │
├─────────────────────────────────────────────────────────────────┤
│ Expected:                                                       │
│ - adjustingPortionWeight: 300g → 150g                           │
│ - portionMultiplier: 1.5 → 0.75 (150 / 200)                    │
│ - Main card updates:                                            │
│   - Header: "1 porsiyon: 300g" → "1 porsiyon: 150g"            │
│   - Calories: 750 kcal → 375 kcal (500 × 0.75)                 │
│   - Carbs: 75g → 37.5g (50 × 0.75)                             │
│                                                                 │
│ Actual:                                                         │
│ ✅ adjustingPortionWeight updates to 150g                      │
│ ✅ onChange fires, calculates ratio = 0.75                     │
│ ✅ portionMultiplier = 0.75                                    │
│ ✅ Header updates to "1 porsiyon: 150g"                        │
│ ❌ Calories stay at 750 kcal                                    │
│ ❌ Carbs stay at 75g                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER CLICKS "PORSIYONU KAYDET"                                 │
├─────────────────────────────────────────────────────────────────┤
│ Expected:                                                       │
│ - recipe.portionSize: 200g → 150g                              │
│ - Core Data saves                                               │
│ - Success banner shows                                          │
│ - Card collapses                                                │
│ - Collapsed card shows: "150g" with "1.0x"                      │
│ - portionMultiplier resets to 1.0                               │
│ - Main card shows: "1 porsiyon: 150g" with 375 kcal            │
│                                                                 │
│ Actual:                                                         │
│ ✅ recipe.portionSize updates to 150g (line 226)               │
│ ✅ Core Data saves successfully (line 230)                     │
│ ✅ Success banner shows                                         │
│ ✅ Card collapses (line 246)                                   │
│ ❌ Collapsed card STILL shows "200g"                            │
│ ❌ portionMultiplier stays at 0.75 (not reset)                 │
│ ❌ Main card shows "1 porsiyon: 112.5g" (150 × 0.75)           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER CLOSES AND REOPENS MODAL                                  │
├─────────────────────────────────────────────────────────────────┤
│ Expected:                                                       │
│ - Recipe reads portionSize = 150g from Core Data               │
│ - portionMultiplier resets to 1.0                               │
│ - Portion card shows: "150g" with "1.0x"                        │
│ - Main card shows: "1 porsiyon: 150g" with 375 kcal            │
│                                                                 │
│ Actual:                                                         │
│ ✅ Recipe reads portionSize = 150g                             │
│ ⚠️  portionMultiplier = 0.75 (PERSISTED from before!)          │
│ ❌ Portion card shows: "150g" with "0.75x"                      │
│ ❌ Main card shows: "1 porsiyon: 112.5g" with 281 kcal         │
└─────────────────────────────────────────────────────────────────┘
```

### ACTUAL Flow (What IS Happening)

The issue is that **SwiftUI doesn't re-render** when:
1. `portionMultiplier` changes (due to computed property dependency tracking)
2. `recipe.portionSize` changes (due to non-observable Recipe object)

---

## TECHNICAL EXPLANATION: WHY SWIFTUI DOESN'T UPDATE

### SwiftUI Reactivity Model

SwiftUI tracks dependencies through:
1. `@State` - Local state
2. `@Binding` - Reference to external state
3. `@ObservedObject` / `@StateObject` - External object conforming to `ObservableObject`
4. `@Published` - Properties within `ObservableObject`

**What SwiftUI DOES track:**
```swift
@Binding var portionMultiplier: Double

var body: some View {
    Text("\(portionMultiplier)")  // ✅ Direct reference → Updates when binding changes
}
```

**What SwiftUI DOESN'T track:**
```swift
@Binding var portionMultiplier: Double

private var displayedCalories: String {
    let value = (Double(caloriesPerServing) ?? 0) * portionMultiplier
    return String(format: "%.0f", value)
}

var body: some View {
    Text(displayedCalories)  // ❌ Indirect reference through computed property
                              //    SwiftUI doesn't know this depends on portionMultiplier!
}
```

**Fix:** Make the dependency explicit:
```swift
var body: some View {
    let _ = portionMultiplier  // Force dependency tracking
    Text(displayedCalories)    // Now updates when portionMultiplier changes
}
```

Or better, compute inline:
```swift
var body: some View {
    let value = (Double(caloriesPerServing) ?? 0) * portionMultiplier
    Text(String(format: "%.0f", value))  // Direct dependency
}
```

### Core Data Reactivity

Core Data objects (`NSManagedObject`) are NOT automatically observable in SwiftUI.

**What DOESN'T work:**
```swift
struct MyView: View {
    let recipe: Recipe  // ❌ Changes to recipe properties don't trigger updates

    var body: some View {
        Text("\(recipe.portionSize)")  // Stale value!
    }
}
```

**What DOES work:**
```swift
struct MyView: View {
    @ObservedObject var recipe: Recipe  // ✅ Now observable

    var body: some View {
        Text("\(recipe.portionSize)")  // Updates when changed!
    }
}
```

OR use `@FetchRequest`:
```swift
struct MyView: View {
    @FetchRequest(sortDescriptors: []) var recipes: FetchedResults<Recipe>

    var body: some View {
        ForEach(recipes) { recipe in
            Text("\(recipe.portionSize)")  // ✅ Updates automatically
        }
    }
}
```

---

## CONCRETE FIXES

### Fix 1: Make Nutrition Values Reactive to portionMultiplier

**Problem:** Computed properties don't trigger view updates.

**Solution:** Inline the calculations to create direct dependencies.

**File:** `NutritionalValuesView.swift` lines 94-168

**Before:**
```swift
nutritionRow(
    label: "Kalori",
    value: displayedCalories,  // ❌ Computed property
    unit: "kcal"
)
```

**After:**
```swift
let caloriesValue = selectedTab == 0
    ? String(format: "%.0f", (Double(caloriesPerServing) ?? 0) * portionMultiplier)
    : calories

nutritionRow(
    label: "Kalori",
    value: caloriesValue,  // ✅ Direct dependency on portionMultiplier
    unit: "kcal"
)
```

Apply to ALL nutrition rows (calories, carbs, fiber, sugar, protein, fat, glycemic load).

**Lines to change:** 95-167

### Fix 2: Make Recipe Observable

**Problem:** Recipe is not observable, so changes don't trigger updates.

**Solution:** Use `@ObservedObject` instead of `let`.

**File:** `NutritionalValuesView.swift` line 19

**Before:**
```swift
let recipe: Recipe?  // ❌ Not observable
```

**After:**
```swift
@ObservedObject var recipe: Recipe  // ✅ Observable
```

**Side effect:** Need to update all call sites to use non-optional `Recipe`.

**File:** `RecipeDetailView.swift` line 196

**Before:**
```swift
NutritionalValuesView(
    recipe: recipeData.recipe,  // Optional
    ...
)
```

**After:**
```swift
if let recipe = recipeData.recipe {
    NutritionalValuesView(
        recipe: recipe,  // Non-optional
        ...
    )
}
```

### Fix 3: Reset portionMultiplier After Save

**Problem:** Multiplier persists after defining a new portion.

**Solution:** Reset to 1.0 after saving.

**File:** `NutritionalValuesView.swift` line 225 (after `recipe.updatePortionSize`)

**Before:**
```swift
// Update recipe
recipe.updatePortionSize(adjustingPortionWeight)

// Save to Core Data
try viewContext.save()
```

**After:**
```swift
// Update recipe
recipe.updatePortionSize(adjustingPortionWeight)

// Reset multiplier to 1.0 after defining new portion
portionMultiplier = 1.0

// Save to Core Data
try viewContext.save()
```

**Rationale:** When you save a new portion definition, you're saying "THIS is now 1 portion". The multiplier should reset to 1.0x to reflect this.

### Fix 4: Don't Persist portionMultiplier

**Problem:** Multiplier is saved to Core Data, but it should be temporary UI state.

**Solution:** Remove `portionMultiplier` from Core Data, make it `@State` in the view.

**File:** `Recipe+CoreDataProperties.swift` line 48

**Before:**
```swift
@NSManaged public var portionMultiplier: Double
```

**After:**
```swift
// Removed - this should be transient UI state, not persisted
```

**File:** `NutritionalValuesView.swift` lines 45-46

**Before:**
```swift
// Portion multiplier binding for persistence
@Binding var portionMultiplier: Double
```

**After:**
```swift
// Portion multiplier for temporary display adjustments (NOT persisted)
@State private var portionMultiplier: Double = 1.0
```

**File:** `RecipeDetailView.swift` lines 216-224

**Before:**
```swift
portionMultiplier: Binding(
    get: { recipeData.recipe.portionMultiplier },
    set: { newValue in
        recipeData.recipe.portionMultiplier = newValue
        Task { @MainActor in
            viewModel.savePortionMultiplier()
        }
    }
)
```

**After:**
```swift
// No longer needed - portionMultiplier is now @State in NutritionalValuesView
```

### Fix 5: Update Core Data Model

**File:** `balli.xcdatamodeld/balli.xcdatamodel/contents`

**Action:** Remove `portionMultiplier` attribute from Recipe entity.

**Migration:** Add a lightweight migration to handle existing data:
- Read `portionMultiplier` values
- If != 1.0, it means user was viewing a multiplied portion
- Reset all to 1.0 (they'll see the base portion on next open)

---

## PRIORITY-ORDERED FIX LIST

### P0 (MUST FIX - Breaking User Experience)

1. **Fix nutrition values reactivity** (Fix #1)
   - File: `NutritionalValuesView.swift`
   - Lines: 94-167
   - Impact: Solves Bug #1 and Bug #3
   - Complexity: Low (inline calculations)

2. **Make Recipe observable** (Fix #2)
   - File: `NutritionalValuesView.swift` line 19
   - File: `RecipeDetailView.swift` line 196
   - Impact: Solves Bug #2
   - Complexity: Medium (requires call site updates)

3. **Reset multiplier after save** (Fix #3)
   - File: `NutritionalValuesView.swift` line 225
   - Impact: Prevents confusing UI state after save
   - Complexity: Low (one-line change)

### P1 (SHOULD FIX - Architectural Improvement)

4. **Remove portionMultiplier from Core Data** (Fix #4 + #5)
   - Files: `Recipe+CoreDataProperties.swift`, `NutritionalValuesView.swift`, `RecipeDetailView.swift`, Core Data model
   - Impact: Prevents persisting temporary UI state
   - Complexity: High (requires Core Data migration)

---

## VERIFICATION PLAN

### Test Case 1: Stepper Updates Nutrition Values

**Steps:**
1. Open recipe with nutrition data
2. Tap stepper to 1.5x
3. **Verify:** All nutrition values multiply by 1.5x
4. Tap stepper to 2.0x
5. **Verify:** All nutrition values multiply by 2.0x
6. Tap stepper to 0.5x
7. **Verify:** All nutrition values multiply by 0.5x

**Expected:**
- ✅ Calories, carbs, protein, fat, fiber, sugar ALL update immediately
- ✅ Header "1 porsiyon: Xg" updates correctly
- ✅ Glycemic load updates

### Test Case 2: Slider Updates Nutrition Values

**Steps:**
1. Open portion card
2. Move slider from 200g → 150g
3. **Verify:** Main card nutrition values update immediately (without saving)
4. Move slider to 300g
5. **Verify:** Nutrition values update again

**Expected:**
- ✅ Nutrition values update as slider moves
- ✅ Header shows correct gram weight
- ✅ Stepper shows correct multiplier (e.g., 1.5x for 300g portion)

### Test Case 3: Save Updates Display

**Steps:**
1. Open portion card (shows 200g)
2. Slide to 150g
3. Tap "Porsiyonu Kaydet"
4. **Verify:** Success banner shows
5. **Verify:** Card collapses and shows "150g"
6. **Verify:** Stepper shows "1.0x" (reset)
7. **Verify:** Main card shows "1 porsiyon: 150g"
8. **Verify:** Nutrition values reflect 150g portion

**Expected:**
- ✅ Collapsed card displays NEW portion (150g)
- ✅ Multiplier resets to 1.0x
- ✅ Nutrition values are for 1.0x of NEW portion

### Test Case 4: Reopen Modal Resets Multiplier

**Steps:**
1. Open nutrition modal
2. Change stepper to 1.5x
3. Close modal (without saving)
4. Reopen modal
5. **Verify:** Multiplier is back to 1.0x

**Expected:**
- ✅ Multiplier does NOT persist across modal opens
- ✅ Always starts at 1.0x

### Test Case 5: Portion Persists Across App Restarts

**Steps:**
1. Open recipe
2. Define portion as 150g and save
3. Close app
4. Kill app from app switcher
5. Reopen app
6. Open same recipe
7. **Verify:** Portion is still 150g

**Expected:**
- ✅ User-defined portion (150g) persists
- ✅ Multiplier starts at 1.0x (does NOT persist)

---

## FILES REQUIRING CHANGES

### Critical Files (P0 Fixes)

1. **`/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`**
   - Lines 19: Change `let recipe: Recipe?` to `@ObservedObject var recipe: Recipe`
   - Lines 94-167: Inline all nutrition calculations
   - Line 225: Add `portionMultiplier = 1.0` after save

2. **`/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/RecipeDetailView.swift`**
   - Line 196: Wrap NutritionalValuesView in optional binding
   - Lines 216-224: Remove portionMultiplier binding (after P1 fixes)

### Architectural Files (P1 Fixes)

3. **`/Users/serhat/SW/balli/balli/Core/Data/Models/Recipe+CoreDataProperties.swift`**
   - Line 48: Remove `@NSManaged public var portionMultiplier: Double`

4. **`/Users/serhat/SW/balli/balli/balli.xcdatamodeld/balli.xcdatamodel/contents`**
   - Remove `portionMultiplier` attribute from Recipe entity

5. **`/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeDetailViewModel.swift`**
   - Lines 479-486: Remove `savePortionMultiplier()` method

---

## SUMMARY

### Root Causes
1. **SwiftUI Reactivity Issue:** Computed properties don't create tracked dependencies
2. **Non-Observable Recipe:** Core Data object changes don't trigger view updates
3. **Architectural Confusion:** Mixing temporary UI state with persistent data

### Impact
- 🔴 **Bug #1:** Stepper doesn't update nutrition values (P0 - breaks user trust)
- 🔴 **Bug #2:** Saved portion doesn't display correctly (P0 - breaks feature)
- 🔴 **Bug #3:** Slider doesn't update nutrition values (P0 - breaks interactivity)

### Solution Complexity
- **P0 Fixes:** Low-Medium complexity, ~50 lines of code changes
- **P1 Fixes:** Medium-High complexity, requires Core Data migration

### Estimated Effort
- **P0 Fixes:** 1-2 hours (immediate bug fixes)
- **P1 Fixes:** 3-4 hours (architectural cleanup)

---

## NEXT STEPS

1. **Implement P0 Fixes** (in order of priority)
2. **Test thoroughly** using verification plan
3. **Deploy to TestFlight** for user validation
4. **Plan P1 Fixes** for next sprint (architectural improvement)

---

**END OF FORENSIC REPORT**
