# Badge Mismatch Bug - Investigation & Fix Report

**Date:** 2025-11-02
**Investigator:** Claude Code (Forensic Debugger)
**Severity:** P0 - Critical User-Facing Data Inconsistency
**Status:** ✅ FIXED - Build Verified

---

## Executive Summary

**Bug Description:**
Impact score badge displayed during food item editing (in Label detail view) does NOT match the badge shown on the Food Archive card after saving. This creates user confusion as they see one badge when confirming their changes, then a different badge appears in their food library.

**Root Cause:**
Badge calculation using DIFFERENT nutrition values in edit view vs. archive view. The edit view was using BASE (unscaled) fat/protein values while showing a badge for SCALED nutrition based on slider position. After save, the archive uses the SCALED values saved to the database, creating a mismatch.

**Fix Applied:**
Updated `FoodItemDetailView.currentImpactLevel` to scale fat and protein values by the same adjustment ratio used when saving to database. This ensures the badge shown during editing EXACTLY matches what will appear in the archive.

**Files Modified:**
- `/balli/Features/FoodArchive/Views/FoodItemDetailView.swift` (Lines 263-288)

**Build Status:** ✅ Build succeeded with existing warnings (no new errors introduced)

---

## Root Cause Analysis

### The Data Flow Problem

#### 1. During Editing (FoodItemDetailView)

**Badge Calculation Logic (BEFORE FIX):**
```swift
private var currentImpactLevel: ImpactLevel {
    guard let result = currentImpactResult else {
        return .low
    }
    return ImpactLevel.from(
        score: result.score,        // ✅ Score calculated with SCALED carbs/fiber/sugar
        fat: Double(fat) ?? 0.0,    // ❌ BASE fat (NOT scaled)
        protein: Double(protein) ?? 0.0  // ❌ BASE protein (NOT scaled)
    )
}
```

**What This Means:**
- `result.score` is calculated by `ImpactScoreCalculator.calculate()` which internally scales ALL nutrition values by `portionGrams / servingSize`
- But the three-threshold evaluation (`ImpactLevel.from()`) received BASE fat/protein values
- This creates an inconsistency: score reflects SCALED nutrition, but fat/protein thresholds use BASE values

**Example Scenario:**
- Food: 100g serving, 50g carbs, 10g protein, 5g fat
- User slides to 50g portion (50% of original)
- Score calculated: Uses 25g carbs (SCALED) → Low impact score
- Three-threshold check: Uses 10g protein, 5g fat (BASE) → Triggers different badge
- **Badge shown:** Based on mixed scaled/unscaled values

#### 2. Save Operation (handleSave)

**What Gets Saved to Database:**
```swift
if portionChanged {
    let adjustmentRatio = portionGrams / baseServing

    // ALL nutrition values are SCALED and saved
    foodItem.servingSize = portionGrams
    foodItem.totalCarbs = (Double(carbohydrates) ?? 0) * adjustmentRatio
    foodItem.fiber = (Double(fiber) ?? 0) * adjustmentRatio
    foodItem.sugars = (Double(sugars) ?? 0) * adjustmentRatio
    foodItem.protein = (Double(protein) ?? 0) * adjustmentRatio  // ✅ SCALED
    foodItem.totalFat = (Double(fat) ?? 0) * adjustmentRatio     // ✅ SCALED
}
```

**Database After Save:**
- `servingSize = 50g` (NEW portion size)
- `totalCarbs = 25g` (SCALED)
- `protein = 5g` (SCALED)
- `totalFat = 2.5g` (SCALED)

#### 3. Food Archive Display (ArdiyeView)

**Badge Calculation from Database:**
```swift
ProductCardView(
    impactLevel: foodItem.impactLevelDetailed
)

// From FoodItem+Extensions.swift
var impactLevelDetailed: ImpactLevel {
    return ImpactLevel.from(
        score: impactScore,        // Calculated from SAVED values
        fat: totalFat,             // 2.5g (SCALED value from database)
        protein: protein           // 5g (SCALED value from database)
    )
}
```

**Archive Badge Calculation:**
- Score: Calculated from 25g carbs (SCALED) → Low impact score
- Three-threshold: Uses 5g protein, 2.5g fat (SCALED) → Different thresholds apply
- **Badge shown:** Based on SCALED values (correct for saved state)

### The Discrepancy

**Edit View Badge:** Mixed scaled score + unscaled fat/protein → Badge A
**Archive Badge:** All scaled values → Badge B
**Result:** Badge A ≠ Badge B → User confusion

---

## The Fix

### Code Changes

**File:** `/balli/Features/FoodArchive/Views/FoodItemDetailView.swift`

**BEFORE (Lines 263-273):**
```swift
private var currentImpactLevel: ImpactLevel {
    guard let result = currentImpactResult else {
        return .low
    }
    // Use three-threshold evaluation for accurate safety assessment
    return ImpactLevel.from(
        score: result.score,
        fat: Double(fat) ?? 0.0,        // ❌ BASE fat
        protein: Double(protein) ?? 0.0  // ❌ BASE protein
    )
}
```

**AFTER (Lines 263-288):**
```swift
private var currentImpactLevel: ImpactLevel {
    guard let result = currentImpactResult else {
        return .low
    }

    // CRITICAL FIX: Scale fat/protein to match what will be saved to database
    // This ensures the badge shown during editing EXACTLY matches the badge
    // that will appear in the Food Archive after saving.
    //
    // Why: The save logic (handleSave) scales ALL nutrition values when the
    // portion changes. The archive badge then calculates from these SCALED
    // saved values. To show consistent badges, we must scale fat/protein here
    // to match what will be in the database after save.
    let baseServing = Double(servingSize) ?? 100.0
    let adjustmentRatio = portionGrams / baseServing

    let scaledFat = (Double(fat) ?? 0.0) * adjustmentRatio
    let scaledProtein = (Double(protein) ?? 0.0) * adjustmentRatio

    // Use three-threshold evaluation with SCALED values (matches saved state)
    return ImpactLevel.from(
        score: result.score,
        fat: scaledFat,        // ✅ Scaled to current portion (matches what will be saved)
        protein: scaledProtein  // ✅ Scaled to current portion (matches what will be saved)
    )
}
```

### Why This Fix Works

1. **Consistency:** Both score AND fat/protein now use SCALED values
2. **Matches Save Logic:** Uses same `adjustmentRatio` calculation as `handleSave()`
3. **Matches Archive:** Archive reads SCALED values from database, now edit view shows badge for those same SCALED values
4. **No Side Effects:** Only affects badge display, doesn't change save behavior

---

## Verification Plan

### Test Scenarios

#### Scenario 1: Slider Adjustment Only
**Steps:**
1. Open food item: 100g serving, 50g carbs, 10g protein, 5g fat
2. Note initial badge (e.g., "checkmark.seal.fill" for low impact)
3. Move slider to 50g portion (50% of original)
4. **Verify:** Badge updates in real-time
5. Note the badge symbol shown (e.g., changes to "questionmark.circle.fill" for medium)
6. Tap Save (checkmark button)
7. Navigate back to Food Archive
8. **Expected:** Same badge symbol as shown in step 5

**What to Check:**
- Badge symbol matches exactly (low/medium/high)
- Badge doesn't change between edit view and archive view

#### Scenario 2: Slider to Low Impact Range
**Steps:**
1. Open high-impact food: 100g serving, 80g carbs, 20g protein, 10g fat
2. Note initial badge (likely "xmark.seal.fill" - high impact)
3. Move slider to 20g portion (20% of original)
   - Scaled: 16g carbs, 4g protein, 2g fat
   - Should show low impact badge
4. **Verify:** Badge changes to "checkmark.seal.fill" (low impact)
5. Tap Save
6. **Expected:** Food Archive shows "checkmark.seal.fill" (same as edit view)

#### Scenario 3: Three-Threshold Edge Case
**Steps:**
1. Open food: 100g serving, 20g carbs, 15g protein, 8g fat
2. Move slider to 70g portion
   - Scaled: 14g carbs, 10.5g protein, 5.6g fat
   - Protein crosses 10g threshold → affects badge
3. **Verify:** Badge reflects protein threshold crossing
4. Move slider to 65g portion
   - Scaled: 13g carbs, 9.75g protein, 5.2g fat
   - All under thresholds → should show low impact
5. **Expected:** Badge matches between edit and archive after save

#### Scenario 4: Text Field Edit (No Slider)
**Steps:**
1. Open food: 100g serving, 50g carbs, 10g protein, 5g fat
2. Change carbs from 50g to 30g (text field only)
3. Do NOT move slider (stays at 100g)
4. **Verify:** Badge updates based on new carb value
5. Tap Save
6. **Expected:** Archive shows same badge (no scaling applied when slider unchanged)

### Manual Testing Checklist

Before marking as verified, test ALL scenarios above and confirm:

- [ ] Scenario 1: Slider adjustment - badge matches
- [ ] Scenario 2: Slider to low impact - badge matches
- [ ] Scenario 3: Three-threshold edge case - badge matches
- [ ] Scenario 4: Text field only edit - badge matches
- [ ] No regression: Foods already in archive still show correct badges
- [ ] Real-time updates: Badge changes smoothly as slider moves
- [ ] Save confirmation: Toast shows "Kaydedildi" after save
- [ ] Archive refresh: Badge appears immediately without manual refresh

### Expected Behavior Summary

**Edit View Badge:**
- Updates in real-time as slider moves
- Uses SCALED nutrition values for all three thresholds
- Shows the EXACT badge that will appear after save

**Save Operation:**
- Scales ALL nutrition values (carbs, fiber, sugars, protein, fat) by adjustment ratio
- Updates `servingSize` to new portion size
- Persists to Core Data

**Archive View Badge:**
- Calculates from SCALED values in database
- Shows SAME badge as was shown in edit view at save time
- No stale cache issues (refreshes on Core Data save notification)

---

## Technical Deep Dive

### Impact Score Calculation Flow

#### ImpactScoreCalculator.calculate()
**Purpose:** Calculate glycemic load for a specific portion
**Input:** BASE nutrition values + serving size + portion grams
**Process:**
1. Calculates `adjustmentRatio = portionGrams / servingSize`
2. Scales ALL nutrients: `scaledCarbs = totalCarbs * adjustmentRatio`
3. Applies Nestlé formula to SCALED values
4. Returns `ImpactScoreResult` with calculated score

**Key Point:** This function EXPECTS base values and handles scaling internally.

#### ImpactLevel.from(score:fat:protein:)
**Purpose:** Three-threshold safety evaluation
**Input:** Impact score + fat grams + protein grams
**Process:**
1. Checks score threshold: `< 5.0 = low, 5.0-10.0 = medium, >= 10.0 = high`
2. Checks fat threshold: `< 5.0 = low, 5.0-15.0 = medium, >= 15.0 = high`
3. Checks protein threshold: `< 10.0 = low, 10.0-20.0 = medium, >= 20.0 = high`
4. Returns badge level (ALL three must be low for LOW badge)

**Key Point:** This function expects values AT THE PORTION SIZE being evaluated.

### The Bug Pattern

**Anti-Pattern (BEFORE FIX):**
```swift
// Calculate score with scaled values
let scoreResult = calculate(baseCarbs, baseFiber, ..., portionGrams)
// ✅ scoreResult.score reflects SCALED nutrition

// Determine badge level with MIXED values
let badge = ImpactLevel.from(
    score: scoreResult.score,  // ✅ Based on SCALED nutrition
    fat: baseFat,              // ❌ NOT scaled (inconsistent!)
    protein: baseProtein       // ❌ NOT scaled (inconsistent!)
)
```

**Correct Pattern (AFTER FIX):**
```swift
// Calculate score with scaled values
let scoreResult = calculate(baseCarbs, baseFiber, ..., portionGrams)
// ✅ scoreResult.score reflects SCALED nutrition

// Scale fat/protein to match
let adjustmentRatio = portionGrams / servingSize
let scaledFat = baseFat * adjustmentRatio
let scaledProtein = baseProtein * adjustmentRatio

// Determine badge level with ALL scaled values
let badge = ImpactLevel.from(
    score: scoreResult.score,  // ✅ Based on SCALED nutrition
    fat: scaledFat,           // ✅ SCALED (consistent!)
    protein: scaledProtein    // ✅ SCALED (consistent!)
)
```

### Why NutritionLabelView Doesn't Have This Bug

**File:** `/balli/Features/Components/NutritionLabelView.swift` (Lines 279-288)

```swift
if let result = currentImpactResult {
    // ✅ CORRECTLY scales fat and protein
    let scaledFat = (Double(fat) ?? 0.0) * adjustmentRatio
    let scaledProtein = (Double(protein) ?? 0.0) * adjustmentRatio

    let currentLevel = ImpactLevel.from(
        score: result.score,
        fat: scaledFat,      // ✅ Scaled
        protein: scaledProtein  // ✅ Scaled
    )

    CompactImpactBannerView(impactLevel: currentLevel, ...)
}
```

**Why:** `NutritionLabelView` is a reusable component that properly implements the pattern. It was used correctly but `FoodItemDetailView` had its own implementation that missed the scaling step.

---

## Related Code Locations

### Key Files in Badge Flow

1. **FoodItemDetailView.swift** (FIXED)
   - Lines 234-288: Badge calculation during editing
   - Lines 296-387: Save logic that persists scaled values
   - **Fix Location:** Lines 263-288

2. **NutritionLabelView.swift** (Reference - Correct Implementation)
   - Lines 147-172: Real-time impact calculation
   - Lines 279-294: Badge display with scaling
   - **Pattern:** Shows correct scaling approach

3. **ArdiyeView.swift** (Archive Display)
   - Lines 389-418: ProductCardView rendering
   - Line 401: `impactLevel: foodItem.impactLevelDetailed`
   - **No Changes Needed:** Archive correctly reads from database

4. **FoodItem+Extensions.swift** (Model Logic)
   - Lines 71-99: Impact score and level calculations
   - **No Changes Needed:** Correctly calculates from saved values

5. **ImpactScoreCalculator.swift** (Core Logic)
   - Lines 40-91: Main calculation entry point
   - Lines 95-146: Nestlé formula implementation
   - Lines 157-186: Three-threshold safety evaluation
   - **No Changes Needed:** Algorithm is correct

6. **ImpactLevel.swift** (Badge Definitions)
   - Lines 67-76: Single-threshold evaluation
   - Lines 88-112: Three-threshold evaluation
   - Lines 150-160: Card symbol names (used in archive)
   - **No Changes Needed:** Threshold logic is correct

### Data Model

**FoodItem Core Data Entity:**
```swift
// Saved to database (SCALED after portion adjustment)
totalCarbs: Double
fiber: Double
sugars: Double
protein: Double
totalFat: Double
servingSize: Double  // Updated to new portion size
```

**Computed Properties:**
```swift
var impactScore: Double {
    // Calculates from SAVED database values
    ImpactScoreCalculator.calculateForFullServing(...)
}

var impactLevelDetailed: ImpactLevel {
    // Uses SAVED fat/protein from database
    ImpactLevel.from(score: impactScore, fat: totalFat, protein: protein)
}
```

---

## Additional Findings

### No Other Badge Calculation Issues Found

**Checked Locations:**
- ✅ `NutritionLabelView.swift`: Correctly scales fat/protein
- ✅ `ArdiyeView.swift`: Correctly reads from database
- ✅ `ProductCardView.swift`: Displays badge passed from parent (no calculation)
- ✅ `FoodItem+Extensions.swift`: Correctly calculates from model properties
- ✅ `ImpactScoreCalculator.swift`: Algorithm validated by Nestlé research

### Consistent Three-Threshold Implementation

All badge calculations now use the three-threshold model:
1. **Score threshold:** `< 5.0 = low`, `5.0-10.0 = medium`, `>= 10.0 = high`
2. **Fat threshold:** `< 5.0 = low`, `5.0-15.0 = medium`, `>= 15.0 = high`
3. **Protein threshold:** `< 10.0 = low`, `10.0-20.0 = medium`, `>= 20.0 = high`

**Rule:** ALL three must be low for LOW badge (green checkmark seal)

---

## Build Verification

**Command:**
```bash
xcodebuild -scheme balli -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

**Result:** ✅ BUILD SUCCEEDED

**Warnings:** 30 existing warnings (none related to this fix)
- FlowTextWithCitations actor isolation (pre-existing)
- DexcomDiagnosticsLogger actor isolation (pre-existing)
- UIScreen.main deprecation (pre-existing)
- Sendable conformance (pre-existing)

**No New Errors:** Fix compiles cleanly with Swift 6 strict concurrency

---

## Risk Assessment

### Potential Side Effects: NONE

**Why:**
1. **Read-Only Change:** Only affects badge calculation, doesn't modify save logic
2. **Same Formula:** Uses identical `adjustmentRatio` calculation as save operation
3. **No API Changes:** Function signature unchanged, no breaking changes
4. **Isolated Scope:** Change limited to one computed property in one view

### Rollback Plan: N/A

**If Regression Occurs:**
1. Revert file to git commit before fix
2. Badge will return to previous behavior (mismatch remains)
3. No data corruption risk (only affects display logic)

### Performance Impact: NEGLIGIBLE

**Additional Computation:**
- 2 floating-point multiplications per badge update
- Triggered only when slider moves (user interaction)
- No impact on scroll performance or list rendering

---

## Success Criteria

**Fix is verified when:**
1. ✅ Build succeeds without new errors
2. ⏳ Manual testing confirms badge matches between edit and archive
3. ⏳ All test scenarios pass
4. ⏳ No regression in existing badge functionality
5. ⏳ Real-time badge updates still work smoothly

**Current Status:** Build verified, manual testing required

---

## Conclusion

### Summary

This fix resolves a critical user-facing data consistency bug where the impact score badge shown during food item editing did not match the badge displayed in the Food Archive after saving. The root cause was identified as a state synchronization issue where the edit view used BASE (unscaled) fat/protein values while the archive used SCALED values from the database.

### Fix Quality

**Code Quality:** Production-ready
- Follows Swift 6 concurrency best practices
- Comprehensive inline documentation
- No force unwraps or unsafe operations
- Consistent with existing codebase patterns

**Testing Status:** Build verified, manual testing required
- No compilation errors
- No new warnings introduced
- Existing warnings unrelated to fix

### Next Steps

1. **Manual Testing:** Run all test scenarios in verification plan
2. **User Validation:** Confirm fix resolves reported issue
3. **Monitor:** Watch for any unexpected badge behavior in production
4. **Document:** Update user-facing documentation if needed

---

**Report Generated:** 2025-11-02
**Fix Implemented By:** Claude Code (Forensic Debugger)
**Build Status:** ✅ Verified
**Manual Testing Status:** ⏳ Pending
**Production Ready:** ✅ Yes (after manual testing verification)
