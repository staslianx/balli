# PORTION SYSTEM DATA FLOW DIAGRAM
**Visual representation of current vs expected data flow**

---

## CURRENT (BROKEN) DATA FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NutritionalValuesView                             │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ PROPERTIES                                                          │   │
│  ├────────────────────────────────────────────────────────────────────┤   │
│  │ let recipe: Recipe?                    ❌ NOT OBSERVABLE           │   │
│  │ @Binding var portionMultiplier: Double ✅ OBSERVABLE               │   │
│  │ @State var adjustingPortionWeight      ✅ LOCAL STATE              │   │
│  │ @State var isPortionAdjustmentExpanded                             │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ COMPUTED PROPERTIES                                                 │   │
│  ├────────────────────────────────────────────────────────────────────┤   │
│  │ var currentPortionSize: Double {                                   │   │
│  │     recipe.portionSize > 0 ? recipe.portionSize : totalWeight      │   │
│  │ }                                                                   │   │
│  │ ❌ Reads from recipe but SwiftUI doesn't track this!               │   │
│  │                                                                     │   │
│  │ var displayedCalories: String {                                    │   │
│  │     (Double(caloriesPerServing) ?? 0) * portionMultiplier          │   │
│  │ }                                                                   │   │
│  │ ❌ Uses portionMultiplier but SwiftUI doesn't track dependency!    │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

                                    │
                                    ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERACTIONS                              │
└─────────────────────────────────────────────────────────────────────────────┘

╔═════════════════════════════════════════════════════════════════════════════╗
║ INTERACTION 1: Tap Stepper (- 1.0x +)                                      ║
╚═════════════════════════════════════════════════════════════════════════════╝

   Button { portionMultiplier -= 0.5 }  →  portionMultiplier: 1.0 → 0.5
                                                     │
                                                     ▼
                ┌────────────────────────────────────────────────────────┐
                │ SwiftUI detects @Binding change                       │
                │ ✅ Re-renders ONLY direct references                  │
                └────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
           ┌───────────────┐                   ┌───────────────┐
           │ Stepper UI    │                   │ infoText      │
           │ ✅ Updates    │                   │ ✅ Updates    │
           │ Shows "0.5x"  │                   │ Shows "136g"  │
           └───────────────┘                   └───────────────┘

                BUT...

           ┌────────────────────────────────────────────────────┐
           │ Nutrition Rows (displayedCalories, etc.)          │
           │ ❌ DO NOT UPDATE                                  │
           │                                                    │
           │ Why? SwiftUI doesn't know these computed          │
           │ properties depend on portionMultiplier!           │
           │                                                    │
           │ The view body was rendered once with old values.  │
           │ Changing portionMultiplier doesn't trigger        │
           │ re-evaluation of displayedCalories.               │
           └────────────────────────────────────────────────────┘


╔═════════════════════════════════════════════════════════════════════════════╗
║ INTERACTION 2: Move Slider (200g → 150g)                                   ║
╚═════════════════════════════════════════════════════════════════════════════╝

   Slider(value: $adjustingPortionWeight, in: 50...400, step: 5)
          │
          ▼
   adjustingPortionWeight: 200 → 150  ✅ Updates
          │
          ▼
   .onChange(of: adjustingPortionWeight) { _, newValue in
       let ratio = newValue / recipe.portionSize  // 150 / 200 = 0.75
       portionMultiplier = ratio                  // ✅ Sets to 0.75
   }
          │
          ▼
   portionMultiplier: 1.0 → 0.75  ✅ Updates
          │
          ▼
   ┌────────────────────────────────────────────────────┐
   │ SwiftUI detects @Binding change                    │
   │ ✅ Re-renders direct references                    │
   └────────────────────────────────────────────────────┘
          │
          ▼
   ┌──────────────────┐       ┌──────────────────┐
   │ Gram Display     │       │ infoText         │
   │ ✅ Updates       │       │ ✅ Updates       │
   │ Shows "150g"     │       │ Shows "150g"     │
   └──────────────────┘       └──────────────────┘

   BUT AGAIN...

   ┌────────────────────────────────────────────────────┐
   │ Nutrition Values (displayedCalories, etc.)         │
   │ ❌ DO NOT UPDATE                                  │
   │                                                    │
   │ Same issue: computed properties not tracked       │
   └────────────────────────────────────────────────────┘


╔═════════════════════════════════════════════════════════════════════════════╗
║ INTERACTION 3: Click "Porsiyonu Kaydet"                                    ║
╚═════════════════════════════════════════════════════════════════════════════╝

   Button(action: savePortionSize)
          │
          ▼
   func savePortionSize() {
       recipe.updatePortionSize(adjustingPortionWeight)  // 150g
       │
       ▼
       ┌─────────────────────────────────────────────────┐
       │ Recipe Extension (Recipe+Extensions.swift)      │
       │                                                 │
       │ func updatePortionSize(_ newSize: Double) {     │
       │     self.portionSize = newSize  // ✅ Updates  │
       │     self.markAsPendingSync()                    │
       │ }                                               │
       └─────────────────────────────────────────────────┘
       │
       ▼
       try viewContext.save()  ✅ Persists to Core Data
       │
       ▼
       ┌─────────────────────────────────────────────────┐
       │ Core Data: recipe.portionSize = 150g            │
       │ ✅ SAVED SUCCESSFULLY                           │
       └─────────────────────────────────────────────────┘

       BUT...

       ┌─────────────────────────────────────────────────┐
       │ SwiftUI View                                    │
       │ ❌ DOESN'T KNOW recipe CHANGED                  │
       │                                                 │
       │ Why? recipe is `let recipe: Recipe?`           │
       │      NOT `@ObservedObject var recipe: Recipe`  │
       │                                                 │
       │ Core Data changes don't trigger view updates!  │
       └─────────────────────────────────────────────────┘
       │
       ▼
       withAnimation { isPortionAdjustmentExpanded = false }
       │
       ▼
       ┌─────────────────────────────────────────────────┐
       │ Collapsed Card Header                           │
       │ Text("\(Int(currentPortionSize))")              │
       │                                                 │
       │ ❌ SHOWS OLD VALUE (200g)                       │
       │                                                 │
       │ currentPortionSize reads recipe.portionSize     │
       │ but the view was rendered with the old value    │
       │ and SwiftUI doesn't know to re-read it!         │
       └─────────────────────────────────────────────────┘
   }

```

---

## EXPECTED (FIXED) DATA FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NutritionalValuesView                             │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ PROPERTIES (FIXED)                                                  │   │
│  ├────────────────────────────────────────────────────────────────────┤   │
│  │ @ObservedObject var recipe: Recipe    ✅ NOW OBSERVABLE            │   │
│  │ @State var portionMultiplier = 1.0    ✅ LOCAL TRANSIENT STATE     │   │
│  │ @State var adjustingPortionWeight     ✅ LOCAL STATE               │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ VIEW BODY (FIXED)                                                   │   │
│  ├────────────────────────────────────────────────────────────────────┤   │
│  │ var body: some View {                                              │   │
│  │     // Inline calculations for reactivity                          │   │
│  │     let caloriesValue = selectedTab == 0                           │   │
│  │         ? String(format: "%.0f",                                   │   │
│  │             (Double(caloriesPerServing) ?? 0) * portionMultiplier) │   │
│  │         : calories                                                 │   │
│  │                                                                     │   │
│  │     ✅ Direct dependency on portionMultiplier                      │   │
│  │     ✅ SwiftUI tracks this automatically                           │   │
│  │ }                                                                   │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

╔═════════════════════════════════════════════════════════════════════════════╗
║ INTERACTION 1: Tap Stepper (FIXED)                                         ║
╚═════════════════════════════════════════════════════════════════════════════╝

   Button { portionMultiplier -= 0.5 }  →  portionMultiplier: 1.0 → 0.5
                                                     │
                                                     ▼
                ┌────────────────────────────────────────────────────────┐
                │ SwiftUI detects @State change                         │
                │ ✅ Re-renders ALL views that reference it             │
                └────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┬────────────────┐
                    ▼                 ▼                 ▼                ▼
           ┌───────────┐     ┌────────────┐   ┌──────────────┐  ┌─────────────┐
           │ Stepper   │     │ infoText   │   │ Calories Row │  │ Carbs Row   │
           │ ✅ "0.5x" │     │ ✅ "136g"  │   │ ✅ 250 kcal  │  │ ✅ 25g      │
           └───────────┘     └────────────┘   └──────────────┘  └─────────────┘
                                      │
                                      ▼
                          ✅ ALL nutrition values update
                          ✅ User sees immediate feedback


╔═════════════════════════════════════════════════════════════════════════════╗
║ INTERACTION 2: Move Slider (FIXED)                                         ║
╚═════════════════════════════════════════════════════════════════════════════╝

   Slider(value: $adjustingPortionWeight)  →  150g
          │
          ▼
   .onChange(of: adjustingPortionWeight) { _, newValue in
       let ratio = newValue / recipe.portionSize  // 150 / 200 = 0.75
       portionMultiplier = ratio                  // ✅ Updates @State
   }
          │
          ▼
   portionMultiplier: 1.0 → 0.75  ✅ @State change
          │
          ▼
   ┌────────────────────────────────────────────────────┐
   │ SwiftUI detects @State change                      │
   │ ✅ Re-renders ALL dependent views                  │
   └────────────────────────────────────────────────────┘
          │
          ▼
   ┌──────────────────┬──────────────────┬──────────────────┐
   │ Gram Display     │ Calories         │ All Macros       │
   │ ✅ "150g"        │ ✅ 375 kcal      │ ✅ Update        │
   └──────────────────┴──────────────────┴──────────────────┘
                          │
                          ▼
                  ✅ REAL-TIME UPDATES as slider moves
                  ✅ User sees nutrition values change


╔═════════════════════════════════════════════════════════════════════════════╗
║ INTERACTION 3: Click "Porsiyonu Kaydet" (FIXED)                            ║
╚═════════════════════════════════════════════════════════════════════════════╝

   Button(action: savePortionSize)
          │
          ▼
   func savePortionSize() {
       recipe.updatePortionSize(adjustingPortionWeight)  // 150g
       │
       ▼
       ┌─────────────────────────────────────────────────┐
       │ @ObservedObject var recipe: Recipe              │
       │ ✅ SwiftUI IS OBSERVING THIS                    │
       └─────────────────────────────────────────────────┘
       │
       ▼
       recipe.portionSize = 150g  ✅ Core Data property changes
       │
       ▼
       portionMultiplier = 1.0  ✅ RESET after defining new portion
       │
       ▼
       try viewContext.save()  ✅ Persists
       │
       ▼
       ┌─────────────────────────────────────────────────┐
       │ SwiftUI detects:                                │
       │ 1. recipe.portionSize changed (@ObservedObject) │
       │ 2. portionMultiplier reset (@State)             │
       │ ✅ TRIGGERS VIEW UPDATE                         │
       └─────────────────────────────────────────────────┘
       │
       ▼
       withAnimation { isPortionAdjustmentExpanded = false }
       │
       ▼
       ┌─────────────────────────────────────────────────┐
       │ Collapsed Card Header                           │
       │ Text("\(Int(recipe.portionSize))")              │
       │ ✅ SHOWS NEW VALUE: "150g"                      │
       │                                                 │
       │ Stepper shows "1.0x"                            │
       │ ✅ RESET TO 1.0x                                │
       │                                                 │
       │ Main nutrition card:                            │
       │ - "1 porsiyon: 150g"                            │
       │ - 375 kcal (for 150g portion)                   │
       │ ✅ ALL VALUES CORRECT                           │
       └─────────────────────────────────────────────────┘
   }

```

---

## REACTIVITY COMPARISON

### Current (Broken)

```
USER ACTION                      BINDING CHANGES                VIEW UPDATES
────────────────────────────────────────────────────────────────────────────

Tap Stepper                      @Binding portionMultiplier    ✅ Stepper UI
                                 1.0 → 1.5                     ✅ Header text
                                                               ❌ Nutrition values

Move Slider                      @State adjustingPortionWeight ✅ Gram display
                                 200 → 150                     ✅ Header text
                                 │                             ❌ Nutrition values
                                 ▼
                                 @Binding portionMultiplier
                                 1.0 → 0.75

Click Save                       recipe.portionSize            ❌ Portion display
                                 200 → 150                     ❌ Nothing updates
                                 (Core Data, not observable)   (Need to reopen modal)
```

### Fixed

```
USER ACTION                      BINDING CHANGES                VIEW UPDATES
────────────────────────────────────────────────────────────────────────────

Tap Stepper                      @State portionMultiplier      ✅ Stepper UI
                                 1.0 → 1.5                     ✅ Header text
                                                               ✅ Nutrition values
                                                               ✅ ALL rows update

Move Slider                      @State adjustingPortionWeight ✅ Gram display
                                 200 → 150                     ✅ Header text
                                 │                             ✅ Nutrition values
                                 ▼                             ✅ Real-time updates
                                 @State portionMultiplier
                                 1.0 → 0.75

Click Save                       @ObservedObject recipe        ✅ Portion display
                                 portionSize: 200 → 150        ✅ Stepper (reset)
                                 │                             ✅ Nutrition values
                                 @State portionMultiplier      ✅ Everything updates
                                 0.75 → 1.0 (RESET)
```

---

## STATE MANAGEMENT ARCHITECTURE

### Before (Broken)

```
┌────────────────────────────────────────────────────────────────┐
│ Core Data (Persistent)                                         │
├────────────────────────────────────────────────────────────────┤
│ recipe.portionSize: Double          ← User-defined portion     │
│ recipe.portionMultiplier: Double    ← ❌ SHOULD NOT PERSIST    │
│                                        (Temporary UI state)     │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ NutritionalValuesView                                          │
├────────────────────────────────────────────────────────────────┤
│ let recipe: Recipe?                 ← ❌ NOT OBSERVABLE        │
│ @Binding var portionMultiplier      ← Bound to Core Data      │
│ @State var adjustingPortionWeight   ← Local transient state   │
└────────────────────────────────────────────────────────────────┘

Problem: portionMultiplier persists across app restarts, causing confusion
```

### After (Fixed)

```
┌────────────────────────────────────────────────────────────────┐
│ Core Data (Persistent)                                         │
├────────────────────────────────────────────────────────────────┤
│ recipe.portionSize: Double          ← User-defined portion     │
│                                        ✅ PERSISTS             │
│                                                                │
│ recipe.portionMultiplier REMOVED    ← No longer exists        │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ NutritionalValuesView                                          │
├────────────────────────────────────────────────────────────────┤
│ @ObservedObject var recipe: Recipe  ← ✅ OBSERVABLE           │
│ @State var portionMultiplier = 1.0  ← ✅ LOCAL TRANSIENT      │
│                                        Resets to 1.0 on open   │
│ @State var adjustingPortionWeight   ← Local transient state   │
└────────────────────────────────────────────────────────────────┘

Benefits:
- portionMultiplier always starts at 1.0x (predictable)
- portionSize persists as expected (user-defined)
- Clear separation: persistent vs transient state
```

---

## CONCEPTUAL MODEL

### What SHOULD Happen

```
USER MENTAL MODEL:

1. "Define Portion" Operation (Permanent):
   ┌──────────────────────────────────────────────────────┐
   │ "I want to define that 1 portion = 150g"            │
   │                                                      │
   │ Action: Slide to 150g, click "Porsiyonu Kaydet"     │
   │ Result: recipe.portionSize = 150g (PERSISTS)        │
   │         portionMultiplier = 1.0 (RESET)             │
   └──────────────────────────────────────────────────────┘

2. "View Different Amount" Operation (Temporary):
   ┌──────────────────────────────────────────────────────┐
   │ "I want to see nutrition for 1.5 portions"          │
   │                                                      │
   │ Action: Tap stepper to 1.5x                          │
   │ Result: All nutrition values × 1.5                   │
   │         Does NOT save (closes → resets to 1.0x)     │
   └──────────────────────────────────────────────────────┘

CLEAR SEPARATION: Define (permanent) vs View (temporary)
```

### What WAS Happening (Broken)

```
BROKEN BEHAVIOR:

1. Define portion to 150g:
   - recipe.portionSize = 150g ✅
   - portionMultiplier = 0.75 ❌ (STAYS from slider!)
   - Next open: Shows 112.5g (150 × 0.75) ❌ CONFUSING

2. View 1.5x portion:
   - portionMultiplier = 1.5 ✅
   - Close and reopen
   - STILL shows 1.5x ❌ (persisted to Core Data)
   - User expects 1.0x

CONFUSION: Can't tell what's permanent vs temporary
```

---

## SUMMARY: WHAT CHANGED

| Aspect | Before (Broken) | After (Fixed) |
|--------|----------------|---------------|
| **Recipe observability** | `let recipe: Recipe?` | `@ObservedObject var recipe: Recipe` |
| **Multiplier storage** | Core Data (persisted) | `@State` (transient) |
| **Nutrition reactivity** | Computed properties (not tracked) | Inline calculations (tracked) |
| **Save behavior** | Only saves portionSize | Saves portionSize + resets multiplier |
| **Reopen behavior** | Shows old multiplier (confusing) | Always starts at 1.0x (predictable) |

---

**END OF DIAGRAM**
