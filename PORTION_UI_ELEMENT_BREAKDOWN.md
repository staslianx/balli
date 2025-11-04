# PORTION SYSTEM UI ELEMENT BREAKDOWN
**Visual map of EVERY UI element and its behavior**

---

## 📱 THE NUTRITION MODAL LAYOUT

```
┌─────────────────────────────────────────────────────────────────┐
│ ← [Recipe Name]                                      [Kapat]    │ ← Navigation Bar
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ [Porsiyon] [100g]  ← Segmented Picker                     │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│  ┃ PORTION CARD (Only shown when "Porsiyon" tab selected)  ┃ │
│  ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ │
│  ┃                                                          ┃ │
│  ┃ Porsiyon          200g  [- 1.0x +]  ▼                   ┃ │ ← COLLAPSED STATE
│  ┃     ▲              ▲        ▲                            ┃ │
│  ┃     │              │        └─ Stepper (- 1.0x +)       ┃ │
│  ┃     │              └─ Current portion value             ┃ │
│  ┃     └─ Label                                            ┃ │
│  ┃                                                          ┃ │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│                                                                 │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│  ┃ PORTION CARD - EXPANDED                                  ┃ │
│  ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ │
│  ┃                                                          ┃ │
│  ┃ Porsiyon                                            ▲   ┃ │
│  ┃ ────────────────────────────────────────────────────    ┃ │
│  ┃                                                          ┃ │
│  ┃                      150g                                ┃ │ ← Gram Display
│  ┃                                                          ┃ │
│  ┃ ───────●─────────────────────────────────────           ┃ │ ← Slider
│  ┃ 50g                                          400g        ┃ │
│  ┃                                                          ┃ │
│  ┃         [  Porsiyonu Kaydet  ]                          ┃ │ ← Save Button
│  ┃                                                          ┃ │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│                                                                 │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│  ┃ MAIN NUTRITION CARD                                      ┃ │
│  ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ │
│  ┃                                                          ┃ │
│  ┃ 1 porsiyon: 272g                                        ┃ │ ← Header Text (infoText)
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Kalori                                    500 kcal      ┃ │ ← Nutrition Row
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Karbonhidrat                                50 g        ┃ │ ← Nutrition Row
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Lif                                         10 g        ┃ │ ← Nutrition Row
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Şeker                                        5 g        ┃ │ ← Nutrition Row
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Protein                                     30 g        ┃ │ ← Nutrition Row
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Yağ                                         15 g        ┃ │ ← Nutrition Row
│  ┃ ──────────────────────────────────────────────────      ┃ │
│  ┃ Glisemik Yük                                20          ┃ │ ← Nutrition Row
│  ┃                                                          ┃ │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│                                                                 │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│  ┃ Emilim Zamanlaması                              ▼       ┃ │ ← Chart Section
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔴 BUG #1: STEPPER DOESN'T UPDATE NUTRITION VALUES

### UI Element: Portion Stepper (- 1.0x +)

**Location:** Inside collapsed portion card header
**File:** `NutritionalValuesView.swift` lines 449-475

```swift
HStack(spacing: 8) {
    Button { portionMultiplier -= 0.5 } label: {
        Image(systemName: "minus.circle.fill")
    }

    Text(String(format: "%.1f", portionMultiplier) + "x")  // ← Shows "1.0x", "1.5x", etc.

    Button { portionMultiplier += 0.5 } label: {
        Image(systemName: "plus.circle.fill")
    }
}
```

### Current Behavior (BROKEN)

```
USER ACTION:     Tap [+] button
                 ↓
BINDING UPDATE:  portionMultiplier: 1.0 → 1.5 ✅
                 ↓
UI UPDATES:      ┌─────────────────────────────────────────┐
                 │ Stepper shows "1.5x" ✅                 │
                 │ Header shows "1 porsiyon: 408g" ✅      │
                 │ (272g × 1.5 = 408g)                     │
                 └─────────────────────────────────────────┘
                 ↓
                 ┌─────────────────────────────────────────┐
                 │ Calories: 500 kcal ❌ STAYS THE SAME   │
                 │ Carbs: 50g ❌ STAYS THE SAME            │
                 │ Protein: 30g ❌ STAYS THE SAME          │
                 │ All nutrition rows frozen!              │
                 └─────────────────────────────────────────┘
```

**EXPECTED:** Calories should show 750 kcal (500 × 1.5)

### Why It's Broken

**Problem File:** Lines 349-410 (Computed properties)

```swift
// ❌ BROKEN - Computed property not tracked by SwiftUI
private var displayedCalories: String {
    if selectedTab == 0 {
        let value = (Double(caloriesPerServing) ?? 0) * portionMultiplier
        return String(format: "%.0f", value)
    } else {
        return calories
    }
}

// Used in view:
nutritionRow(label: "Kalori", value: displayedCalories, unit: "kcal")
//                                    ^^^^^^^^^^^^^^^^
//                            SwiftUI doesn't track this dependency!
```

**Root Cause:** SwiftUI doesn't know `displayedCalories` depends on `portionMultiplier` because it's called through a computed property.

### Expected Behavior (AFTER FIX)

```
USER ACTION:     Tap [+] button
                 ↓
BINDING UPDATE:  portionMultiplier: 1.0 → 1.5 ✅
                 ↓
UI UPDATES:      ┌─────────────────────────────────────────┐
                 │ Stepper shows "1.5x" ✅                 │
                 │ Header shows "1 porsiyon: 408g" ✅      │
                 │ Calories: 750 kcal ✅ UPDATES!          │
                 │ Carbs: 75g ✅ UPDATES!                  │
                 │ Protein: 45g ✅ UPDATES!                │
                 │ All nutrition rows scale by 1.5x ✅     │
                 └─────────────────────────────────────────┘
```

---

## 🔴 BUG #2: SAVED PORTION SHOWS OLD VALUE

### UI Element: Collapsed Portion Card Display

**Location:** Portion card header when collapsed
**File:** `NutritionalValuesView.swift` lines 437-447

```swift
if !isPortionAdjustmentExpanded {
    // Show current portion value
    HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text("\(Int(currentPortionSize))")  // ← Shows "200"
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AppTheme.primaryPurple)

        Text("g")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
    }
}
```

### Current Behavior (BROKEN)

```
INITIAL STATE:   Portion card shows "200g"
                 ↓
USER ACTION:     1. Tap portion card to expand
                 2. Move slider to 150g
                 3. Tap "Porsiyonu Kaydet"
                 ↓
SAVE LOGIC:      recipe.portionSize = 150g ✅
                 try viewContext.save() ✅
                 ↓
UI UPDATES:      ┌─────────────────────────────────────────┐
                 │ Success banner shows ✅                 │
                 │ Card collapses ✅                       │
                 │ Portion card STILL shows "200g" ❌      │
                 │ (Should show "150g")                    │
                 └─────────────────────────────────────────┘
```

**EXPECTED:** After save, collapsed card should immediately show "150g"

### Why It's Broken

**Problem:** Recipe is not observable

```swift
struct NutritionalValuesView: View {
    let recipe: Recipe?  // ❌ NOT OBSERVABLE
    //  ^^^
    //  When recipe.portionSize changes, SwiftUI doesn't re-render!

    private var currentPortionSize: Double {
        guard let recipe = recipe else { return 0 }
        return recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight
        //     ^^^^^^^^^^^^^^^^^^^^
        //     Reads from recipe but SwiftUI doesn't know to update when it changes!
    }
}
```

**Data Flow:**
1. ✅ User saves → `recipe.portionSize` updates in Core Data
2. ✅ Core Data persists successfully
3. ❌ SwiftUI view doesn't re-read `currentPortionSize` because recipe isn't observable
4. ❌ UI shows cached old value (200g)

**Proof:** If you CLOSE the modal and REOPEN it, it WILL show 150g (because it reads fresh from Core Data).

### Expected Behavior (AFTER FIX)

```
INITIAL STATE:   Portion card shows "200g"
                 ↓
USER ACTION:     1. Tap portion card to expand
                 2. Move slider to 150g
                 3. Tap "Porsiyonu Kaydet"
                 ↓
SAVE LOGIC:      recipe.portionSize = 150g ✅
                 portionMultiplier = 1.0 ✅ RESET
                 try viewContext.save() ✅
                 ↓
UI UPDATES:      ┌─────────────────────────────────────────┐
                 │ Success banner shows ✅                 │
                 │ Card collapses ✅                       │
                 │ Portion card shows "150g" ✅            │
                 │ Stepper shows "1.0x" ✅                 │
                 │ Main card shows "1 porsiyon: 150g" ✅   │
                 │ All values correct! ✅                  │
                 └─────────────────────────────────────────┘
```

---

## 🔴 BUG #3: SLIDER DOESN'T UPDATE NUTRITION VALUES

### UI Element: Portion Size Slider

**Location:** Inside expanded portion card
**File:** `NutritionalValuesView.swift` lines 508-520

```swift
Slider(
    value: $adjustingPortionWeight,
    in: minPortionSize...recipe.totalRecipeWeight,
    step: sliderStep
)
.onChange(of: adjustingPortionWeight) { _, newValue in
    // Update portion multiplier to reflect slider changes
    guard recipe.portionSize > 0 else { return }
    let ratio = newValue / recipe.portionSize  // 150 / 200 = 0.75
    portionMultiplier = ratio
}
```

### Current Behavior (BROKEN)

```
INITIAL STATE:   Slider at 200g
                 Main card shows 500 kcal, 50g carbs
                 ↓
USER ACTION:     Move slider to 150g
                 ↓
STATE UPDATES:   adjustingPortionWeight: 200 → 150 ✅
                 ↓
SLIDER CHANGE:   ratio = 150 / 200 = 0.75 ✅
                 portionMultiplier = 0.75 ✅
                 ↓
UI UPDATES:      ┌─────────────────────────────────────────┐
                 │ Gram display: "150g" ✅                 │
                 │ Header: "1 porsiyon: 150g" ✅           │
                 │ Stepper: "0.75x" ✅                     │
                 └─────────────────────────────────────────┘
                 ↓
                 ┌─────────────────────────────────────────┐
                 │ Calories: 500 kcal ❌ FROZEN            │
                 │ Carbs: 50g ❌ FROZEN                    │
                 │ (Should be 375 kcal, 37.5g)             │
                 └─────────────────────────────────────────┘
```

**EXPECTED:** As slider moves, nutrition values should update in real-time

### Why It's Broken

**Same root cause as Bug #1:** Computed properties not tracked by SwiftUI.

```
Slider changes → portionMultiplier updates → But nutrition rows don't re-render
                                              because they use computed properties
```

### Expected Behavior (AFTER FIX)

```
INITIAL STATE:   Slider at 200g
                 Main card shows 500 kcal, 50g carbs
                 ↓
USER ACTION:     Move slider to 150g (SMOOTH CONTINUOUS DRAG)
                 ↓
STATE UPDATES:   adjustingPortionWeight: 200 → 190 → 180 → 170 → 160 → 150
                 ↓
REAL-TIME:       ┌─────────────────────────────────────────┐
                 │ As slider moves:                        │
                 │ - Gram display updates continuously ✅  │
                 │ - Header updates continuously ✅        │
                 │ - Calories: 500 → 475 → 450 → ... ✅   │
                 │ - Carbs: 50 → 47.5 → 45 → ... ✅       │
                 │ - ALL nutrition values update LIVE! ✅  │
                 │                                         │
                 │ User gets INSTANT FEEDBACK ✅           │
                 └─────────────────────────────────────────┘
```

---

## 🎯 ELEMENT-BY-ELEMENT MAPPING

### 1. Stepper (- 1.0x +)

**File:** Lines 449-475
**Property:** `portionMultiplier` (@Binding)
**Current:** ❌ Only stepper text updates
**After Fix:** ✅ ALL nutrition values update

| Action | Before | After |
|--------|--------|-------|
| Tap [-] | Stepper: 1.0x → 0.5x ✅<br>Header: Updates ✅<br>Calories: NO ❌ | Stepper: 1.0x → 0.5x ✅<br>Header: Updates ✅<br>Calories: 500 → 250 ✅ |
| Tap [+] | Stepper: 1.0x → 1.5x ✅<br>Header: Updates ✅<br>Carbs: NO ❌ | Stepper: 1.0x → 1.5x ✅<br>Header: Updates ✅<br>Carbs: 50 → 75 ✅ |

---

### 2. Collapsed Portion Display (200g)

**File:** Lines 437-447
**Property:** `currentPortionSize` (computed from `recipe.portionSize`)
**Current:** ❌ Shows old value after save
**After Fix:** ✅ Shows new value immediately

| Action | Before | After |
|--------|--------|-------|
| Save 150g | Save succeeds ✅<br>Card shows "200g" ❌ | Save succeeds ✅<br>Card shows "150g" ✅ |
| Reopen modal | Now shows "150g" ✅<br>(Had to close/reopen) | Shows "150g" immediately ✅<br>(No need to close/reopen) |

---

### 3. Slider

**File:** Lines 508-520
**Property:** `adjustingPortionWeight` (@State)
**Current:** ❌ Nutrition values frozen
**After Fix:** ✅ Real-time updates

| Action | Before | After |
|--------|--------|-------|
| Slide to 150g | Gram display: "150g" ✅<br>Calories: NO ❌ | Gram display: "150g" ✅<br>Calories: LIVE ✅ |
| Slide to 300g | Stepper: "1.5x" ✅<br>Protein: NO ❌ | Stepper: "1.5x" ✅<br>Protein: LIVE ✅ |

---

### 4. Header Text (1 porsiyon: 272g)

**File:** Lines 334-347 (`infoText` computed property)
**Property:** Reads `totalRecipeWeight * portionMultiplier`
**Current:** ✅ WORKS (updates correctly)
**After Fix:** ✅ STILL WORKS

**Why it works:** This text IS re-evaluated because it's directly in the view body.

---

### 5. Nutrition Rows (Kalori, Karbonhidrat, etc.)

**File:** Lines 94-168
**Property:** Uses `displayedCalories`, `displayedCarbohydrates`, etc.
**Current:** ❌ BROKEN (frozen values)
**After Fix:** ✅ WORKS (live updates)

| Row | Before | After |
|-----|--------|-------|
| Kalori | Shows 500 kcal (frozen) ❌ | Updates to 750 kcal at 1.5x ✅ |
| Karbonhidrat | Shows 50g (frozen) ❌ | Updates to 75g at 1.5x ✅ |
| Protein | Shows 30g (frozen) ❌ | Updates to 45g at 1.5x ✅ |
| Yağ | Shows 15g (frozen) ❌ | Updates to 22.5g at 1.5x ✅ |
| Glisemik Yük | Shows 20 (frozen) ❌ | Updates to 30 at 1.5x ✅ |

---

### 6. Save Button ("Porsiyonu Kaydet")

**File:** Lines 539-548
**Action:** Calls `savePortionSize()`
**Current:** ✅ Saves to Core Data, ❌ UI doesn't update
**After Fix:** ✅ Saves AND updates UI

**Before:**
```
Click Save → recipe.portionSize = 150g
          → Core Data saves
          → UI shows OLD value (200g) ❌
```

**After:**
```
Click Save → recipe.portionSize = 150g
          → portionMultiplier = 1.0 (RESET)
          → Core Data saves
          → UI shows NEW value (150g) ✅
```

---

### 7. Success Banner

**File:** Lines 257-275
**Property:** `showSuccessBanner` (@State)
**Current:** ✅ WORKS
**After Fix:** ✅ STILL WORKS

No changes needed for success banner.

---

## 📊 SUMMARY TABLE

| UI Element | Current Status | After Fix | Affected By |
|------------|---------------|-----------|-------------|
| Stepper (- 1.0x +) | ⚠️ Partial (only stepper updates) | ✅ Full (all values update) | Bug #1 |
| Collapsed Portion Display | ❌ Broken (shows old value) | ✅ Fixed (shows new value) | Bug #2 |
| Slider | ⚠️ Partial (only gram display) | ✅ Full (real-time updates) | Bug #3 |
| Header Text | ✅ Working | ✅ Working | None |
| Nutrition Rows | ❌ Broken (frozen) | ✅ Fixed (reactive) | Bug #1, #3 |
| Save Button | ⚠️ Partial (saves but no UI update) | ✅ Full (saves + updates) | Bug #2 |
| Success Banner | ✅ Working | ✅ Working | None |

---

## 🔧 HOW THE FIX WORKS

### Fix 1: Inline Calculations (Fixes Bugs #1, #3)

**Before:**
```swift
// Computed property (not tracked)
private var displayedCalories: String {
    let value = (Double(caloriesPerServing) ?? 0) * portionMultiplier
    return String(format: "%.0f", value)
}

// View uses it indirectly
nutritionRow(label: "Kalori", value: displayedCalories, unit: "kcal")
```

**After:**
```swift
// Inline calculation (directly tracked)
let caloriesValue = selectedTab == 0
    ? String(format: "%.0f", (Double(caloriesPerServing) ?? 0) * portionMultiplier)
    : calories

// View uses it directly
nutritionRow(label: "Kalori", value: caloriesValue, unit: "kcal")
```

**Result:** SwiftUI sees direct reference to `portionMultiplier` → Tracks dependency → Re-renders when it changes

---

### Fix 2: Observable Recipe (Fixes Bug #2)

**Before:**
```swift
let recipe: Recipe?  // Not observable
```

**After:**
```swift
@ObservedObject var recipe: Recipe  // Observable
```

**Result:** SwiftUI tracks changes to `recipe.portionSize` → Re-renders when it changes

---

### Fix 3: Reset Multiplier (Improves UX)

**Before:**
```swift
recipe.updatePortionSize(adjustingPortionWeight)
try viewContext.save()
// portionMultiplier stays at old value (e.g., 0.75)
```

**After:**
```swift
recipe.updatePortionSize(adjustingPortionWeight)
portionMultiplier = 1.0  // RESET
try viewContext.save()
```

**Result:** After defining new portion, multiplier resets to 1.0x (predictable UX)

---

**END OF UI ELEMENT BREAKDOWN**
