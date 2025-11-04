# PORTION SYSTEM FIX - IMPLEMENTATION GUIDE
**Step-by-step code changes with line numbers**

---

## OVERVIEW

This guide provides EXACT code changes to fix all three portion system bugs:
1. ✅ Stepper updates nutrition values
2. ✅ Saved portion displays correctly
3. ✅ Slider updates nutrition values in real-time

**Estimated Time:** 1-2 hours
**Complexity:** Low-Medium (mostly inline calculations)
**Risk:** Low (changes are localized, no Core Data schema changes required)

---

## PHASE 1: MAKE NUTRITION VALUES REACTIVE (P0)

### Fix 1.1: Inline Nutrition Calculations

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Lines 94-168 (Nutritional Values Rows section)

**Current Code:**
```swift
// Nutritional Values Rows
VStack(spacing: ResponsiveDesign.Spacing.small) {
    nutritionRow(
        label: "Kalori",
        value: displayedCalories,  // ❌ Computed property
        unit: "kcal"
    )

    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 0.5)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)

    nutritionRow(
        label: "Karbonhidrat",
        value: displayedCarbohydrates,  // ❌ Computed property
        unit: "g"
    )

    // ... more rows
}
```

**Replace With:**
```swift
// Nutritional Values Rows
VStack(spacing: ResponsiveDesign.Spacing.small) {
    // Inline calculations for SwiftUI reactivity
    let caloriesValue = selectedTab == 0
        ? String(format: "%.0f", (Double(caloriesPerServing) ?? 0) * portionMultiplier)
        : calories

    let carbsValue = selectedTab == 0
        ? String(format: "%.1f", (Double(carbohydratesPerServing) ?? 0) * portionMultiplier)
        : carbohydrates

    let fiberValue = selectedTab == 0
        ? String(format: "%.1f", (Double(fiberPerServing) ?? 0) * portionMultiplier)
        : fiber

    let sugarValue = selectedTab == 0
        ? String(format: "%.1f", (Double(sugarPerServing) ?? 0) * portionMultiplier)
        : sugar

    let proteinValue = selectedTab == 0
        ? String(format: "%.1f", (Double(proteinPerServing) ?? 0) * portionMultiplier)
        : protein

    let fatValue = selectedTab == 0
        ? String(format: "%.1f", (Double(fatPerServing) ?? 0) * portionMultiplier)
        : fat

    let glycemicLoadValue = selectedTab == 0
        ? String(format: "%.0f", (Double(glycemicLoadPerServing) ?? 0) * portionMultiplier)
        : glycemicLoad

    nutritionRow(
        label: "Kalori",
        value: caloriesValue,
        unit: "kcal"
    )

    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 0.5)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)

    nutritionRow(
        label: "Karbonhidrat",
        value: carbsValue,
        unit: "g"
    )

    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 0.5)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)

    nutritionRow(
        label: "Lif",
        value: fiberValue,
        unit: "g"
    )

    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 0.5)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)

    nutritionRow(
        label: "Şeker",
        value: sugarValue,
        unit: "g"
    )

    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 0.5)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)

    nutritionRow(
        label: "Protein",
        value: proteinValue,
        unit: "g"
    )

    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 0.5)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)

    nutritionRow(
        label: "Yağ",
        value: fatValue,
        unit: "g"
    )

    // Only show Glycemic Load in Porsiyon tab (it's a per-portion metric)
    if selectedTab == 0 {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)

        nutritionRow(
            label: "Glisemik Yük",
            value: glycemicLoadValue,
            unit: ""
        )
    }
}
.padding(.vertical, ResponsiveDesign.Spacing.medium)
```

**Why This Works:**
- SwiftUI sees direct reference to `portionMultiplier` in view body
- Automatically tracks dependency and re-renders when it changes
- No more hidden computed properties that SwiftUI can't track

---

## PHASE 2: MAKE RECIPE OBSERVABLE (P0)

### Fix 2.1: Change Recipe Parameter Type

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Line 19

**Current Code:**
```swift
let recipe: Recipe?  // Optional - only available for saved recipes
```

**Replace With:**
```swift
@ObservedObject var recipe: Recipe  // Observable - MUST be non-optional
```

**Why This Works:**
- `@ObservedObject` tells SwiftUI to watch for changes to the recipe
- When `recipe.portionSize` changes, SwiftUI re-renders the view
- Now the portion card will update immediately after save

---

### Fix 2.2: Update Computed Properties to Use Non-Optional Recipe

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Lines 280-310

**Current Code:**
```swift
/// Whether portion adjustment is available (recipe must be saved)
private var canAdjustPortion: Bool {
    recipe != nil
}

/// Current portion size from recipe
private var currentPortionSize: Double {
    guard let recipe = recipe else { return 0 }
    return recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight
}

/// Number of portions the recipe makes based on current adjustment
private var adjustedPortionCount: Double {
    guard let recipe = recipe, adjustingPortionWeight > 0 else { return 1.0 }
    return recipe.totalRecipeWeight / adjustingPortionWeight
}

/// Nutrition for the adjusted portion size
private var adjustedPortionNutrition: NutritionValues {
    guard let recipe = recipe else {
        return NutritionValues(
            calories: 0, carbohydrates: 0, fiber: 0,
            sugar: 0, protein: 0, fat: 0, glycemicLoad: 0
        )
    }
    return recipe.calculatePortionNutrition(for: adjustingPortionWeight)
}

/// Whether portion is defined in recipe
private var isPortionDefined: Bool {
    recipe?.isPortionDefined ?? false
}
```

**Replace With:**
```swift
/// Whether portion adjustment is available (recipe is now always non-optional)
private var canAdjustPortion: Bool {
    true  // Recipe is always available since it's now non-optional
}

/// Current portion size from recipe
private var currentPortionSize: Double {
    recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight
}

/// Number of portions the recipe makes based on current adjustment
private var adjustedPortionCount: Double {
    guard adjustingPortionWeight > 0 else { return 1.0 }
    return recipe.totalRecipeWeight / adjustingPortionWeight
}

/// Nutrition for the adjusted portion size
private var adjustedPortionNutrition: NutritionValues {
    recipe.calculatePortionNutrition(for: adjustingPortionWeight)
}

/// Whether portion is defined in recipe
private var isPortionDefined: Bool {
    recipe.isPortionDefined
}
```

**Why This Works:**
- No more optional unwrapping needed
- Cleaner, more readable code
- SwiftUI can track recipe changes directly

---

### Fix 2.3: Update savePortionSize() to Remove Optional Check

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Lines 206-254

**Current Code:**
```swift
private func savePortionSize() {
    // Ensure recipe exists
    guard let recipe = recipe else {
        logger.warning("⚠️ Cannot save portion - recipe not available")
        return
    }

    // Validate portion size
    guard adjustingPortionWeight >= minPortionSize else {
        logger.warning("Attempted to save portion below minimum: \(self.adjustingPortionWeight)g")
        return
    }

    guard adjustingPortionWeight <= recipe.totalRecipeWeight else {
        logger.warning("Attempted to save portion above maximum: \(self.adjustingPortionWeight)g")
        return
    }

    // Update recipe
    recipe.updatePortionSize(adjustingPortionWeight)

    // Save to Core Data
    do {
        try viewContext.save()
        logger.info("✅ Saved portion size: \(self.adjustingPortionWeight)g")

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
                    isPortionAdjustmentExpanded = false
                }
            }
        }

    } catch {
        logger.error("❌ Failed to save portion size: \(error.localizedDescription)")
    }
}
```

**Replace With:**
```swift
private func savePortionSize() {
    // Validate portion size
    guard adjustingPortionWeight >= minPortionSize else {
        logger.warning("Attempted to save portion below minimum: \(self.adjustingPortionWeight)g")
        return
    }

    guard adjustingPortionWeight <= recipe.totalRecipeWeight else {
        logger.warning("Attempted to save portion above maximum: \(self.adjustingPortionWeight)g")
        return
    }

    // Update recipe
    recipe.updatePortionSize(adjustingPortionWeight)

    // Reset portion multiplier after defining new portion
    portionMultiplier = 1.0

    // Save to Core Data
    do {
        try viewContext.save()
        logger.info("✅ Saved portion size: \(self.adjustingPortionWeight)g, multiplier reset to 1.0")

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
                    isPortionAdjustmentExpanded = false
                }
            }
        }

    } catch {
        logger.error("❌ Failed to save portion size: \(error.localizedDescription)")
    }
}
```

**Key Changes:**
1. ✅ Removed `guard let recipe = recipe` check (no longer needed)
2. ✅ Added `portionMultiplier = 1.0` reset after defining new portion
3. ✅ Updated log message to mention multiplier reset

**Why This Works:**
- After saving a new portion definition, the multiplier resets to 1.0x
- This is correct: defining "1 portion = 150g" means multiplier should be 1.0
- User sees expected behavior: portion card shows 150g with 1.0x

---

### Fix 2.4: Update Slider onChange to Remove Optional Check

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Lines 514-520

**Current Code:**
```swift
.onChange(of: adjustingPortionWeight) { _, newValue in
    // Update portion multiplier to reflect slider changes in main nutrition card
    // The ratio is: new slider value / recipe's defined portion size
    guard recipe.portionSize > 0 else { return }
    let ratio = newValue / recipe.portionSize
    portionMultiplier = ratio
}
```

**Replace With:**
```swift
.onChange(of: adjustingPortionWeight) { _, newValue in
    // Update portion multiplier to reflect slider changes in main nutrition card
    // The ratio is: new slider value / recipe's defined portion size
    guard recipe.portionSize > 0 else { return }
    let ratio = newValue / recipe.portionSize
    portionMultiplier = ratio
}
```

**No Change Needed!** This code already works correctly. The guard statement is for checking if portionSize is valid, not for optional unwrapping.

---

### Fix 2.5: Update Call Site in RecipeDetailView

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/RecipeDetailView.swift`

**Location:** Lines 196-227

**Current Code:**
```swift
.sheet(isPresented: $viewModel.showingNutritionalValues) {
    NutritionalValuesView(
        recipe: recipeData.recipe,
        recipeName: recipeData.recipeName,
        calories: String(format: "%.0f", recipeData.recipe.calories),
        carbohydrates: String(format: "%.1f", recipeData.recipe.totalCarbs),
        // ... more parameters
        portionMultiplier: Binding(
            get: { recipeData.recipe.portionMultiplier },
            set: { newValue in
                recipeData.recipe.portionMultiplier = newValue
                Task { @MainActor in
                    viewModel.savePortionMultiplier()
                }
            }
        )
    )
    .presentationDetents([.large])
}
```

**Replace With:**
```swift
.sheet(isPresented: $viewModel.showingNutritionalValues) {
    // Only show if recipe has nutrition data
    if recipeData.recipe.calories > 0 {
        NutritionalValuesView(
            recipe: recipeData.recipe,  // Now non-optional
            recipeName: recipeData.recipeName,
            calories: String(format: "%.0f", recipeData.recipe.calories),
            carbohydrates: String(format: "%.1f", recipeData.recipe.totalCarbs),
            fiber: String(format: "%.1f", recipeData.recipe.fiber),
            sugar: String(format: "%.1f", recipeData.recipe.sugars),
            protein: String(format: "%.1f", recipeData.recipe.protein),
            fat: String(format: "%.1f", recipeData.recipe.totalFat),
            glycemicLoad: String(format: "%.0f", recipeData.recipe.glycemicLoad),
            caloriesPerServing: String(format: "%.0f", recipeData.recipe.caloriesPerServing),
            carbohydratesPerServing: String(format: "%.1f", recipeData.recipe.carbsPerServing),
            fiberPerServing: String(format: "%.1f", recipeData.recipe.fiberPerServing),
            sugarPerServing: String(format: "%.1f", recipeData.recipe.sugarsPerServing),
            proteinPerServing: String(format: "%.1f", recipeData.recipe.proteinPerServing),
            fatPerServing: String(format: "%.1f", recipeData.recipe.fatPerServing),
            glycemicLoadPerServing: String(format: "%.0f", recipeData.recipe.glycemicLoadPerServing),
            totalRecipeWeight: String(format: "%.0f", recipeData.recipe.totalRecipeWeight),
            digestionTiming: viewModel.digestionTimingInsights
            // portionMultiplier parameter REMOVED - now @State in view
        )
        .presentationDetents([.large])
    }
}
```

**Key Changes:**
1. ✅ Wrapped in `if` check to ensure recipe has nutrition data
2. ✅ Removed `portionMultiplier` binding parameter
3. ✅ Recipe is now passed as non-optional

---

### Fix 2.6: Update NutritionalValuesView Initializer

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Lines 14-46

**Current Signature:**
```swift
struct NutritionalValuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    let recipe: Recipe?  // Optional - only available for saved recipes
    let recipeName: String

    // Per-100g values
    let calories: String
    let carbohydrates: String
    let fiber: String
    let sugar: String
    let protein: String
    let fat: String
    let glycemicLoad: String

    // Per-serving values
    let caloriesPerServing: String
    let carbohydratesPerServing: String
    let fiberPerServing: String
    let sugarPerServing: String
    let proteinPerServing: String
    let fatPerServing: String
    let glycemicLoadPerServing: String
    let totalRecipeWeight: String

    // API insights (optional - from nutrition calculation)
    let digestionTiming: DigestionTiming?

    // Portion multiplier binding for persistence
    @Binding var portionMultiplier: Double
```

**New Signature:**
```swift
struct NutritionalValuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var recipe: Recipe  // Observable - now non-optional
    let recipeName: String

    // Per-100g values
    let calories: String
    let carbohydrates: String
    let fiber: String
    let sugar: String
    let protein: String
    let fat: String
    let glycemicLoad: String

    // Per-serving values
    let caloriesPerServing: String
    let carbohydratesPerServing: String
    let fiberPerServing: String
    let sugarPerServing: String
    let proteinPerServing: String
    let fatPerServing: String
    let glycemicLoadPerServing: String
    let totalRecipeWeight: String

    // API insights (optional - from nutrition calculation)
    let digestionTiming: DigestionTiming?

    // Portion multiplier - transient UI state (resets to 1.0 on each open)
    @State private var portionMultiplier: Double = 1.0
```

**Key Changes:**
1. ✅ `let recipe: Recipe?` → `@ObservedObject var recipe: Recipe`
2. ✅ `@Binding var portionMultiplier` → `@State private var portionMultiplier = 1.0`

---

### Fix 2.7: Update Preview Constructors

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

**Location:** Lines 637-755 (All previews)

**Current Preview:**
```swift
#Preview("With Both Values - Low Warning") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    // ... recipe setup

    return NutritionalValuesView(
        recipe: recipe,
        recipeName: "Izgara Tavuk Salatası",
        // ... parameters
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}
```

**New Preview:**
```swift
#Preview("With Both Values - Low Warning") {
    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Izgara Tavuk Salatası"
    recipe.totalRecipeWeight = 350
    recipe.caloriesPerServing = 578
    recipe.carbsPerServing = 28
    recipe.fiberPerServing = 10.5
    recipe.sugarsPerServing = 7
    recipe.proteinPerServing = 108.5
    recipe.fatPerServing = 12.6
    recipe.glycemicLoadPerServing = 14
    recipe.portionSize = 350

    return NutritionalValuesView(
        recipe: recipe,
        recipeName: "Izgara Tavuk Salatası",
        calories: "165",
        carbohydrates: "8",
        fiber: "3",
        sugar: "2",
        protein: "31",
        fat: "3.6",
        glycemicLoad: "4",
        caloriesPerServing: "578",
        carbohydratesPerServing: "28",
        fiberPerServing: "10.5",
        sugarPerServing: "7",
        proteinPerServing: "108.5",
        fatPerServing: "12.6",
        glycemicLoadPerServing: "14",
        totalRecipeWeight: "350",
        digestionTiming: nil
        // portionMultiplier parameter REMOVED
    )
    .environment(\.managedObjectContext, context)
}
```

**Apply to ALL three previews** (lines 637-755).

---

## PHASE 3: OPTIONAL CLEANUP (P1)

### Optional Fix 3.1: Remove portionMultiplier from RecipeDetailViewModel

**File:** `/Users/serhat/SW/balli/balli/Features/RecipeManagement/ViewModels/RecipeDetailViewModel.swift`

**Location:** Lines 479-486

**Current Code:**
```swift
// MARK: - Portion Management

func savePortionMultiplier() {
    do {
        try viewContext.save()
        logger.info("✅ Portion multiplier saved")
    } catch {
        logger.error("❌ Failed to save portion multiplier: \(error.localizedDescription)")
    }
}
```

**Action:** Delete this entire method (it's no longer used).

---

### Optional Fix 3.2: Remove portionMultiplier from Core Data (REQUIRES MIGRATION)

**⚠️ WARNING:** This requires a Core Data model version and migration. Only do this if you understand Core Data migrations.

**File:** `/Users/serhat/SW/balli/balli/Core/Data/Models/Recipe+CoreDataProperties.swift`

**Location:** Line 48

**Current Code:**
```swift
@NSManaged public var portionMultiplier: Double
```

**Action:** Delete this line.

**File:** `/Users/serhat/SW/balli/balli/balli.xcdatamodeld/balli.xcdatamodel/contents`

**Action:** Remove the `portionMultiplier` attribute from the Recipe entity in Xcode's data model editor.

**Migration Steps:**
1. Create new model version: Editor → Add Model Version
2. Remove `portionMultiplier` attribute from new version
3. Set new version as current
4. Add lightweight migration policy
5. Test migration on clean install

**OR:** Leave `portionMultiplier` in Core Data but stop using it (easier, no migration needed).

---

## TESTING CHECKLIST

After implementing all P0 fixes, test these scenarios:

### Test 1: Stepper Updates Everything
- [ ] Open recipe with nutrition data
- [ ] Tap stepper to 1.5x
- [ ] ✅ Header shows "1 porsiyon: XXXg" (increased)
- [ ] ✅ Calories increase by 1.5x
- [ ] ✅ Carbs increase by 1.5x
- [ ] ✅ ALL macros increase by 1.5x
- [ ] Tap stepper to 0.5x
- [ ] ✅ ALL values decrease by 0.5x

### Test 2: Slider Updates Everything
- [ ] Open portion card
- [ ] Move slider to 150g
- [ ] ✅ Gram display shows 150g
- [ ] ✅ Header shows "1 porsiyon: 150g"
- [ ] ✅ Calories update immediately
- [ ] ✅ ALL macros update immediately
- [ ] ✅ Stepper shows correct multiplier (e.g., 0.75x)
- [ ] Move slider without saving
- [ ] ✅ Values continue updating in real-time

### Test 3: Save Works Correctly
- [ ] Open portion card (shows 200g)
- [ ] Slide to 150g
- [ ] Tap "Porsiyonu Kaydet"
- [ ] ✅ Success banner shows
- [ ] ✅ Card collapses
- [ ] ✅ Collapsed card shows "150g"
- [ ] ✅ Stepper shows "1.0x" (reset)
- [ ] ✅ Header shows "1 porsiyon: 150g"
- [ ] ✅ Calories show for 150g portion (1.0x)

### Test 4: Multiplier Doesn't Persist
- [ ] Open nutrition modal
- [ ] Change stepper to 1.5x
- [ ] Close modal (back button)
- [ ] Reopen modal
- [ ] ✅ Stepper shows "1.0x" (not 1.5x)
- [ ] ✅ All values are for 1.0x

### Test 5: Portion Persists Correctly
- [ ] Open recipe
- [ ] Define portion as 150g and save
- [ ] Close modal
- [ ] Close app completely
- [ ] Reopen app
- [ ] Open same recipe
- [ ] Open nutrition modal
- [ ] ✅ Portion card shows "150g"
- [ ] ✅ Stepper shows "1.0x"
- [ ] ✅ Values are for 150g portion

---

## ROLLBACK PLAN

If anything breaks:

1. **Revert Fix 1.1** (nutrition values inline):
   - Put computed properties back
   - Reference `displayedCalories`, etc. in view

2. **Revert Fix 2.1-2.6** (observable recipe):
   - Change `@ObservedObject var recipe: Recipe` back to `let recipe: Recipe?`
   - Add optional unwrapping back
   - Remove `if` wrapper in RecipeDetailView

3. **Revert Fix 2.3** (multiplier reset):
   - Remove `portionMultiplier = 1.0` line from savePortionSize()

**Git Command:**
```bash
git checkout HEAD -- balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift
git checkout HEAD -- balli/Features/RecipeManagement/Views/RecipeDetailView.swift
```

---

## SUMMARY OF CHANGES

### Files Modified (P0 - Required)

1. **NutritionalValuesView.swift** (7 changes)
   - Inline nutrition calculations (Fix 1.1)
   - Change recipe to @ObservedObject (Fix 2.1)
   - Remove optional unwrapping (Fix 2.2)
   - Add multiplier reset on save (Fix 2.3)
   - Change multiplier to @State (Fix 2.6)
   - Update previews (Fix 2.7)

2. **RecipeDetailView.swift** (1 change)
   - Wrap NutritionalValuesView in optional check (Fix 2.5)
   - Remove multiplier binding

### Files Modified (P1 - Optional)

3. **RecipeDetailViewModel.swift**
   - Remove savePortionMultiplier() method

4. **Recipe+CoreDataProperties.swift** (REQUIRES MIGRATION)
   - Remove portionMultiplier property

5. **balli.xcdatamodel** (REQUIRES MIGRATION)
   - Remove portionMultiplier attribute

---

## EXPECTED RESULTS

After implementing all P0 fixes:

✅ **Bug #1 FIXED:** Stepper updates ALL nutrition values immediately
✅ **Bug #2 FIXED:** Saved portion displays correctly in collapsed card
✅ **Bug #3 FIXED:** Slider updates nutrition values in real-time
✅ **Improved UX:** Multiplier resets to 1.0x after saving
✅ **Predictable:** Multiplier always starts at 1.0x when opening modal

---

**END OF IMPLEMENTATION GUIDE**
