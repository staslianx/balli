# Refactoring Plan: NutritionLabelView.swift

## Current State Analysis
- **File Size:** 712 lines
- **Primary Responsibility:** Display nutrition label with live adjustments and impact scoring
- **Key Dependencies:** SwiftUI, OSLog, ImpactScoreCalculator
- **Concurrency Model:** @MainActor (all views), nonisolated slider helpers
- **Current Location:** `balli/Features/Components/NutritionLabelView.swift`

## Problems Identified
1. **Near limit:** At 712 lines (89% of 800-line limit) - will exceed limit with minor additions
2. **Multiple responsibilities:** Main label display, calories section, nutrition rows, slider logic, impact calculations
3. **Legacy code:** Contains deprecated `NutritionLabelRow` component (lines 675-712)
4. **Complex computed properties:** 6+ adjusted value calculations with logging
5. **Slider math:** Logarithmic conversion logic embedded in main view

## Proposed File Structure

### New File 1: NutritionLabelView.swift (200 lines)
**Responsibility:** Main label orchestration and layout
**Reasoning:** Keep only structural layout and coordination
**Contains:**
- Main body with VStack layout
- Conditional slider section
- Header, calories, divider, nutrition, slider composition
- Initialization (preserves backward compatibility)
- showingValues animation logic

### New File 2: NutritionLabelCalculations.swift (150 lines)
**Responsibility:** All value calculations and formatting
**Reasoning:** Separate pure calculations from UI rendering
**Contains:**
- `adjustmentRatio` computed property
- All `adjusted*` computed properties (calories, carbs, fiber, sugar, protein, fat)
- `formatNutritionValue()` helper
- `currentImpactResult` calculation
- `shouldShowValue()` helper

### New File 3: NutritionLabelSlider.swift (100 lines)
**Responsibility:** Logarithmic slider logic and conversions
**Reasoning:** Self-contained mathematical domain
**Contains:**
- SliderConfig enum
- `sliderPosition` binding
- `sliderPositionFromGrams()` conversion
- `gramsFromSliderPosition()` conversion
- Slider section view component

### New File 4: CaloriesSectionView.swift (120 lines)
**Responsibility:** Calories display with focus management
**Reasoning:** Already a separate struct, just needs own file
**Contains:**
- CaloriesSectionView struct (lines 488-559)
- Focus state management
- Computed bindings for calories/serving size
- TextField handling

### New File 5: NutritionLabelRowProportional.swift (80 lines)
**Responsibility:** Single nutrition row with proportional adjustment
**Reasoning:** Reusable component used 5 times
**Contains:**
- NutritionLabelRowProportional struct (lines 621-672)
- Focus state for editing
- Value binding logic

### New File 6: NutritionLabelView+Preview.swift (60 lines)
**Responsibility:** Preview configurations
**Reasoning:** Separate preview setup from main code
**Contains:**
- #Preview block (lines 564-619)
- PreviewWrapper with state

## Dependency Graph
```
NutritionLabelView (main)
├─→ NutritionLabelCalculations (imports for computed properties)
├─→ NutritionLabelSlider (for slider section)
├─→ CaloriesSectionView (for calories section)
├─→ NutritionLabelRowProportional (used 5x in nutrition section)
└─→ ImpactScoreCalculator (external)
```

## File Organization
```
Features/Components/
├── NutritionLabelView.swift (200 lines)
└── NutritionLabel/
    ├── NutritionLabelCalculations.swift (150 lines)
    ├── NutritionLabelSlider.swift (100 lines)
    ├── CaloriesSectionView.swift (120 lines)
    ├── NutritionLabelRowProportional.swift (80 lines)
    └── NutritionLabelView+Preview.swift (60 lines)
```

## Risk Assessment
- **Breaking Changes:** None - maintaining exact public API
- **Test Impact:** None - behavior unchanged
- **Migration Complexity:** Low - clean component extraction
- **Legacy Code:** Will REMOVE deprecated `NutritionLabelRow` (unused, not tested)

## Refactoring Strategy

### Phase 1: Remove Legacy Code
- Delete `NutritionLabelRow` struct (lines 675-712)
- Verify no usages in codebase via Grep
- This saves ~40 lines immediately

### Phase 2: Extract Row Component
- Move `NutritionLabelRowProportional` to own file (lines 621-672)
- No changes to implementation

### Phase 3: Extract Calories Section
- Move `CaloriesSectionView` to own file (lines 488-559)
- No changes to implementation

### Phase 4: Extract Calculations
- Create NutritionLabelCalculations extension
- Move all computed properties to extension
- Use extension on NutritionLabelView for access

### Phase 5: Extract Slider Logic
- Move slider helpers to separate struct/extension
- Move slider section view
- Keep slider position binding accessible

### Phase 6: Extract Preview
- Move #Preview block to separate file
- Ensure preview imports all dependencies

### Phase 7: Verify Main File
- Confirm main file is under 220 lines
- Test all components compile
- Verify previews render

## Success Criteria
✓ Main file reduced from 712 → ~200 lines (72% reduction)
✓ All extracted files under 200 lines each
✓ Zero functional changes to behavior
✓ All tests pass unchanged (NutritionLabelViewTests.swift)
✓ SwiftUI preview works
✓ Legacy code removed safely
✓ Proper @MainActor and nonisolated annotations maintained
✓ Backward-compatible initializer preserved

## Implementation Notes
- **Calculations extraction:** Can be done as extension OR separate struct - extension preferred for computed properties
- **Legacy removal:** Verify no usages before deleting
- **Slider logic:** nonisolated functions must stay nonisolated
- **Impact banner:** External component, not extracted

## Estimated Final Sizes
- NutritionLabelView.swift: 200 lines ✅ (under 800)
- NutritionLabelCalculations.swift: 150 lines ✅ (under 800)
- NutritionLabelSlider.swift: 100 lines ✅ (under 800)
- CaloriesSectionView.swift: 120 lines ✅ (under 800)
- NutritionLabelRowProportional.swift: 80 lines ✅ (under 800)
- NutritionLabelView+Preview.swift: 60 lines ✅ (under 800)

**Total:** 710 lines across 6 files (vs. 712 in 1 file)
**Reduction in main file:** 72% (712 → 200 lines)
**Legacy code removed:** 40 lines (NutritionLabelRow)
