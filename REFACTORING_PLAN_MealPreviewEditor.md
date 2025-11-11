# Refactoring Plan: MealPreviewEditor.swift

## Current State Analysis
- **File Size:** 674 lines
- **Primary Responsibility:** Editable meal preview form with insulin and food item management
- **Key Dependencies:** SwiftUI, EditableFoodItem model, ParsedMealData
- **Concurrency Model:** @MainActor (all views)
- **Current Location:** `balli/Features/FoodEntry/Views/Components/MealPreviewEditor.swift`

## Problems Identified
1. **Near limit:** At 674 lines (84% of 800-line limit) - close to threshold
2. **Multiple responsibilities:** Food editing, insulin editing, form orchestration, preview configurations
3. **Complex inline editing:** EditableFoodRow has intricate focus management (200+ lines)
4. **Large preview blocks:** 3 comprehensive previews (175 lines total)
5. **Duplicate stepper logic:** Carb stepper and insulin stepper share patterns

## Proposed File Structure

### New File 1: MealPreviewEditor.swift (180 lines)
**Responsibility:** Main form orchestration and layout
**Reasoning:** Keep only structural composition and coordination
**Contains:**
- Main ScrollView body
- Top row (meal type + carb stepper)
- Foods array section
- Insulin section (conditional)
- Timestamp picker
- Confidence warning
- Transcription display
- Add food/insulin buttons

### New File 2: EditableFoodRow.swift (200 lines)
**Responsibility:** Single food item editing with inline focus management
**Reasoning:** Self-contained component with complex state - deserves own file
**Contains:**
- EditableFoodRow struct (lines 86-279)
- Focus state management (@FocusState)
- Inline editing for name, amount, carbs
- All editing methods (start/save)
- Conditional carbs pill (isDetailedFormat)

### New File 3: EditableInsulinRow.swift (100 lines)
**Responsibility:** Insulin dosage and type editing with pill/stepper states
**Reasoning:** Distinct domain (insulin vs food) with unique interaction pattern
**Contains:**
- EditableInsulinRow struct (lines 12-82)
- Stepper mode (editing)
- Pill mode (finalized)
- Tap-to-edit transition

### New File 4: MealFormComponents.swift (120 lines)
**Responsibility:** Reusable form components (carb stepper, buttons)
**Reasoning:** Extract reusable UI patterns
**Contains:**
- CarbStepperView component (carb adjustment UI)
- AddItemButtonsView (food/insulin add buttons)
- MealTypePicker component
- Shared styling and layout patterns

### New File 5: MealPreviewEditor+Previews.swift (75 lines)
**Responsibility:** Preview configurations
**Reasoning:** Keep previews separate for clarity
**Contains:**
- Simple meal preview (lines 535-579)
- Detailed meal with insulin (lines 581-630)
- Low confidence warning (lines 632-674)

## Dependency Graph
```
MealPreviewEditor (main)
├─→ EditableFoodRow (used in ForEach)
├─→ EditableInsulinRow (conditional)
├─→ MealFormComponents (carb stepper, buttons, pickers)
└─→ ParsedMealData (input model)
```

## File Organization
```
Features/FoodEntry/Views/Components/
├── MealPreviewEditor.swift (180 lines)
└── MealPreview/
    ├── EditableFoodRow.swift (200 lines)
    ├── EditableInsulinRow.swift (100 lines)
    ├── MealFormComponents.swift (120 lines)
    └── MealPreviewEditor+Previews.swift (75 lines)
```

## Risk Assessment
- **Breaking Changes:** None - public API unchanged
- **Test Impact:** None - behavior preserved
- **Migration Complexity:** Low - clean component extraction

## Refactoring Strategy

### Phase 1: Extract EditableInsulinRow
- Move struct to own file (lines 12-82)
- No changes to implementation
- Verify @Binding parameters work correctly

### Phase 2: Extract EditableFoodRow
- Move struct to own file (lines 86-279)
- Keep all @FocusState and editing logic intact
- Ensure @Binding to EditableFoodItem works

### Phase 3: Extract Reusable Components
- Create MealFormComponents file
- Extract carb stepper UI (lines 322-361)
- Extract add buttons section (lines 383-423)
- Create reusable components with proper parameters

### Phase 4: Simplify Main File
- Remove extracted structs
- Keep only composition logic
- Ensure all bindings passed correctly

### Phase 5: Extract Previews
- Move all #Preview blocks (lines 535-674)
- Create separate preview file
- Verify previews compile and render

### Phase 6: Verify
- Confirm main file under 200 lines
- Test all editing interactions
- Verify focus management still works

## Success Criteria
✓ Main file reduced from 674 → ~180 lines (73% reduction)
✓ All extracted files under 250 lines each
✓ Zero functional changes to behavior
✓ Focus management preserved exactly
✓ All binding patterns work unchanged
✓ SwiftUI previews render correctly
✓ Proper @MainActor annotations maintained
✓ @FocusState works in extracted components

## Implementation Notes
- **Focus state:** @FocusState can live in extracted components without issues
- **Binding patterns:** All @Binding parameters pass through cleanly
- **Inline editing:** Complex but well-encapsulated in EditableFoodRow
- **Reusable components:** Carb stepper pattern could be extracted for reuse
- **Transaction disabling:** Keep line 387-388 exactly as-is (prevents animation glitch)

## Estimated Final Sizes
- MealPreviewEditor.swift: 180 lines ✅ (under 800)
- EditableFoodRow.swift: 200 lines ✅ (under 800)
- EditableInsulinRow.swift: 100 lines ✅ (under 800)
- MealFormComponents.swift: 120 lines ✅ (under 800)
- MealPreviewEditor+Previews.swift: 75 lines ✅ (under 800)

**Total:** 675 lines across 5 files (vs. 674 in 1 file)
**Reduction in main file:** 73% (674 → 180 lines)

## Additional Benefits
- **Testability:** EditableFoodRow can be tested in isolation
- **Reusability:** EditableInsulinRow could be reused elsewhere
- **Maintainability:** Easier to understand focus management in dedicated file
- **Type Safety:** Clear component boundaries with explicit parameters
