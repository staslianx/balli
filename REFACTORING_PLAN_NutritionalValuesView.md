# Refactoring Plan: NutritionalValuesView.swift

## Current State Analysis
- **File Size:** 907 lines
- **Primary Responsibility:** Display and edit nutritional values with portion adjustment
- **Key Dependencies:** SwiftUI, CoreData, OSLog, ObservableRecipeWrapper
- **Concurrency Model:** @MainActor (view), Core Data context
- **Current Location:** `balli/Features/RecipeManagement/Views/Components/NutritionalValuesView.swift`

## Problems Identified
1. **Oversized file:** 107 lines over 800-line limit (CRITICAL - P0)
2. **Multiple responsibilities:** Nutrition display, portion editing, CoreData persistence, wrapper class
3. **Duplicate portion cards:** `unifiedPortionCard` and `multiplierOnlyCard` are nearly identical (400+ lines combined)
4. **Large computed properties:** Multiple nutrition calculation helpers
5. **Monolithic view hierarchy:** All UI components inline in main view

## Proposed File Structure

### New File 1: NutritionalValuesView.swift (180 lines)
**Responsibility:** Main orchestration view and navigation setup
**Reasoning:** Keep only top-level structure, navigation, and coordination
**Contains:**
- Main body with NavigationStack
- Segmented picker
- Info text computed property
- Conditional rendering of portions/nutrition cards
- Toast and state management
- onAppear lifecycle

### New File 2: PortionControlCard.swift (280 lines)
**Responsibility:** Single unified portion adjustment card (consolidate both variants)
**Reasoning:** Both portion cards share 80% of code - merge into one with conditional rendering
**Contains:**
- Unified portion card with `isRecipeSaved: Bool` parameter
- Header row with chevron
- Expanded slider section
- Portion multiplier stepper
- Save button logic delegation

### New File 3: NutritionDisplayCard.swift (150 lines)
**Responsibility:** Display nutritional values in a card format
**Reasoning:** Separate display concerns from editing concerns
**Contains:**
- Main nutrition card container
- Header section with info text
- Nutrition rows with dividers
- Glycemic load row (conditional)
- Reusable `nutritionRow()` helper

### New File 4: NutritionalValuesActions.swift (120 lines)
**Responsibility:** Business logic for portion saving and validation
**Reasoning:** Separate side effects (CoreData) from UI rendering
**Contains:**
- `savePortionSize()` method
- `savePortionSizeForUnsavedRecipe()` method
- Validation logic
- CoreData operations
- Error handling

### New File 5: ObservableRecipeWrapper.swift (80 lines)
**Responsibility:** Recipe wrapper for SwiftUI reactivity
**Reasoning:** Independent model class, should be in separate file
**Contains:**
- ObservableRecipeWrapper class
- All wrapper methods
- Computed properties for recipe access

### New File 6: NutritionalValuesView+Previews.swift (100 lines)
**Responsibility:** Preview configurations
**Reasoning:** Keep previews separate for clarity
**Contains:**
- All #Preview blocks
- Preview mock data

## Dependency Graph
```
NutritionalValuesView (main)
├─→ PortionControlCard
│   └─→ NutritionalValuesActions (via closure)
├─→ NutritionDisplayCard
├─→ ObservableRecipeWrapper
└─→ NutritionalValuesActions (owns methods)
```

## File Organization
```
Features/RecipeManagement/Views/Components/
├── NutritionalValuesView.swift (180 lines)
└── NutritionalValues/
    ├── PortionControlCard.swift (280 lines)
    ├── NutritionDisplayCard.swift (150 lines)
    ├── NutritionalValuesActions.swift (120 lines)
    ├── ObservableRecipeWrapper.swift (80 lines)
    └── NutritionalValuesView+Previews.swift (100 lines)
```

## Risk Assessment
- **Breaking Changes:** None - only organizational changes
- **Test Impact:** None - functionality preserved exactly
- **Migration Complexity:** Low - clean extraction with clear boundaries

## Refactoring Strategy

### Phase 1: Extract ObservableRecipeWrapper
- Move class to separate file (lines 738-785)
- No changes to implementation

### Phase 2: Extract Actions
- Move `savePortionSize()` and `savePortionSizeForUnsavedRecipe()` (lines 220-360)
- Create struct/class to hold these methods
- Pass CoreData context and bindings via initializer

### Phase 3: Consolidate Portion Cards
- Merge `unifiedPortionCard` and `multiplierOnlyCard` (lines 410-702)
- Add `isRecipeSaved: Bool` parameter to control behavior
- Extract to PortionControlCard.swift
- Use closures for save actions

### Phase 4: Extract Nutrition Display
- Move nutrition card UI (lines 82-194)
- Create NutritionDisplayCard component
- Pass calculated values via parameters

### Phase 5: Extract Previews
- Move all #Preview blocks (lines 789-907)
- Create separate preview file

### Phase 6: Verify Main File
- Confirm main file is under 200 lines
- Ensure all dependencies properly imported
- Test compilation

## Success Criteria
✓ Main file reduced from 907 → ~180 lines (80% reduction)
✓ All extracted files under 300 lines each
✓ Zero functional changes to behavior
✓ All tests pass unchanged
✓ SwiftUI previews work for all components
✓ Proper @MainActor annotations maintained
✓ CoreData context properly threaded through
✓ Proper dependency injection (no singletons)

## Implementation Notes
- **Portion card consolidation:** This is the biggest win - reduces ~400 lines to ~280
- **Action extraction:** Improves testability by separating business logic
- **Preview separation:** Common pattern for large views
- **Wrapper extraction:** Should have been separate from day 1

## Estimated Final Sizes
- NutritionalValuesView.swift: 180 lines ✅ (under 800)
- PortionControlCard.swift: 280 lines ✅ (under 800)
- NutritionDisplayCard.swift: 150 lines ✅ (under 800)
- NutritionalValuesActions.swift: 120 lines ✅ (under 800)
- ObservableRecipeWrapper.swift: 80 lines ✅ (under 800)
- NutritionalValuesView+Previews.swift: 100 lines ✅ (under 800)

**Total:** 910 lines across 6 files (vs. 907 in 1 file)
**Reduction in main file:** 80% (907 → 180 lines)
