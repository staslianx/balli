# Recipe Nutrition Calculation - Testing Guide

**Purpose:** Verify the nutrition calculation fix works correctly
**Duration:** 15-20 minutes
**Tools Needed:** Xcode, iPhone Simulator, Console.app

---

## Quick Start

### 1. Open Console.app to Monitor Logs

```bash
# Open Console.app
open /System/Applications/Utilities/Console.app

# Filter logs:
# 1. Select your Mac in sidebar
# 2. In search box, type: "NUTRITION"
# 3. Set filter to "Any" (not "Message")
```

**What to Look For:**
- `📊 [NUTRITION-DEBUG]` - FormState values before calculation
- `📤 [NUTRITION-API]` - Request sent to Cloud Function
- `✅ [NUTRITION-CALC] Success` - Calculation completed
- `❌ [NUTRITION]` - Any errors

---

## Test Scenario 1: Saved Recipe (CRITICAL - Primary Fix)

### Objective
Verify that `recipeContent` is properly loaded from CoreData after saving

### Steps

1. **Generate Recipe**
   - Open balli app
   - Navigate to Recipe Generation
   - Generate AI recipe (any type)
   - Wait for streaming to complete
   - Recipe should display with markdown content

2. **Save Recipe**
   - Tap "Save" button
   - Wait for save confirmation
   - Note the recipe name

3. **Navigate Away**
   - Go back to main screen or recipe archive
   - This clears the in-memory formState

4. **Open Saved Recipe**
   - Find the recipe you just saved
   - Tap to open detail view
   - Recipe should load from CoreData

5. **Calculate Nutrition**
   - Tap the nutrition card (story card)
   - Watch Console.app for logs

### Expected Console Logs

```
🍽️ [NUTRITION] Starting on-demand nutrition calculation - isManualRecipe: false

📊 [NUTRITION-DEBUG] FormState values:
   - recipeName: 'Scrambled Eggs'                    ✅ Should match recipe
   - recipeContent length: 543 chars                 ✅ CRITICAL: Should be > 0
   - recipeContent isEmpty: false                    ✅ CRITICAL: Should be false
   - recipeContent first 100 chars: '## Malzemeler\n- 2 yumurta\n- 1 yemek kaşığı tereyağı\n- Tuz ve karabiber (isteğe bağlı)\n\n## Yapılışı\n1. Orta'
   - ingredients count: 3                            ✅ Should have ingredients
   - ingredients: ["2 yumurta", "1 yemek kaşığı tereyağı", "Tuz ve karabiber (isteğe bağlı)"]
   - directions count: 4                             ✅ Should have directions

📤 [NUTRITION-API] Request parameters:
   - recipeName: 'Scrambled Eggs'
   - recipeContent length: 543 chars                 ✅ Should match formState
   - recipeContent isEmpty: false
   - recipeContent first 200 chars: '## Malzemeler\n- 2 yumurta\n- 1 yemek kaşığı tereyağı\n...'
   - servings: 1
   - recipeType: aiGenerated

🍽️ [NUTRITION-CALC] Response received in 67.3s

✅ [NUTRITION-CALC] Success in 67.3s:
   - Calories: 95 kcal/100g
   - Carbs: 2.1g
   - Protein: 6.5g
   - Fat: 7.2g
   - GL: 1
```

### Success Criteria

| Check | Expected | Status |
|-------|----------|--------|
| `recipeContent length` | > 0 chars | ⬜ |
| `recipeContent isEmpty` | false | ⬜ |
| `recipeContent first 100 chars` | Shows actual markdown | ⬜ |
| `ingredients count` | > 0 | ⬜ |
| API request shows content | `recipeContent length > 0` | ⬜ |
| Calculation succeeds | ✅ Success log appears | ⬜ |
| Nutrition displayed | Values shown in UI | ⬜ |

### If This Fails

**Symptom:** `recipeContent length: 0 chars`

**Diagnosis:**
- Fix #1 not applied correctly
- Check `RecipeFormState.swift` line 177
- Should have: `recipeContent = recipe.recipeContent ?? ""`

**Action:** Verify the fix was applied, rebuild, retry

---

## Test Scenario 2: Unsaved Recipe (Regression Check)

### Objective
Verify unsaved recipes still work (no regression)

### Steps

1. **Generate Recipe**
   - Open balli app
   - Generate AI recipe
   - Wait for streaming completion

2. **Calculate Immediately (Don't Save)**
   - Tap nutrition card immediately
   - Watch Console.app

### Expected Console Logs

```
📊 [NUTRITION-DEBUG] FormState values:
   - recipeName: 'Protein Pancakes'
   - recipeContent length: 612 chars                 ✅ From streaming
   - recipeContent isEmpty: false
   - recipeContent first 100 chars: '## Malzemeler\n...'

📤 [NUTRITION-API] Request parameters:
   - recipeContent length: 612 chars                 ✅ Complete content

✅ [NUTRITION-CALC] Success in 68.1s
```

### Success Criteria

| Check | Expected | Status |
|-------|----------|--------|
| `recipeContent` populated | length > 0 | ⬜ |
| API receives content | length > 0 | ⬜ |
| Calculation succeeds | ✅ Success | ⬜ |

---

## Test Scenario 3: Edge Case - Validation Blocks Bad Data

### Objective
Verify improved validation prevents invalid API calls

### Setup
This test requires manually triggering an edge case. Skip if not comfortable with code modification.

**Alternative:** Just verify scenarios 1 & 2 work. This validates the main fix.

---

## What Good Logs Look Like

### ✅ HEALTHY - Saved Recipe Loads Content

```
📊 [NUTRITION-DEBUG] FormState values:
   - recipeName: 'Menemen'
   - recipeContent length: 687 chars          👈 GOOD: > 0
   - recipeContent isEmpty: false             👈 GOOD: not empty
   - recipeContent first 100 chars: '## Malzemeler\n- 3 adet domates\n- 2 adet yeşil biber\n- 1 soğan\n- 3 yumurta\n- 2 yemek kaşığı zeytinyağı'

📤 [NUTRITION-API] Request parameters:
   - recipeContent length: 687 chars          👈 GOOD: matches formState
   - recipeContent isEmpty: false

✅ [NUTRITION-CALC] Success in 65.7s:
   - Calories: 87 kcal/100g
   - Carbs: 6.2g
   - Protein: 4.1g
   - Fat: 5.3g
   - GL: 2
```

---

### ❌ BAD - Missing Content (Should NOT Happen After Fix)

```
📊 [NUTRITION-DEBUG] FormState values:
   - recipeName: 'Menemen'
   - recipeContent length: 0 chars            👈 BAD: empty!
   - recipeContent isEmpty: true              👈 BAD: fix not working
   - ingredients count: 1
   - ingredients: [""]                        👈 BAD: empty array

❌ [NUTRITION] Cannot calculate - no recipe content or ingredients
   - hasValidRecipeContent: false
   - hasValidIngredients: false
   - hasValidDirections: false
```

**If you see this:** Fix #1 is NOT working. Contact developer.

---

### ❌ BAD - API Receives Empty Content (Should NOT Happen)

```
📤 [NUTRITION-API] Request parameters:
   - recipeName: 'Menemen'
   - recipeContent length: 0 chars            👈 BAD: validation failed
   - recipeContent isEmpty: true

❌ [NUTRITION-CALC] HTTP error: 400
```

**If you see this:** Validation is not catching the error. Contact developer.

---

## Troubleshooting

### Problem: No Logs Appear in Console

**Solution:**
1. Ensure app is running on simulator (not device)
2. Check Console.app filter: "NUTRITION" in search box
3. Verify "Any" is selected (not "Message")
4. Restart Console.app
5. Try triggering calculation again

### Problem: Logs Show Empty recipeContent for Saved Recipe

**Diagnosis:** Fix #1 not applied or CoreData issue

**Steps:**
1. Verify `RecipeFormState.swift` line 177 has:
   ```swift
   recipeContent = recipe.recipeContent ?? ""
   ```
2. Check if recipe actually has content in CoreData:
   - Look for log: `📋 [PERSIST-DEBUG] FormState values:` during save
   - Should show `recipeContent length: XXX chars`
3. Clean build: Product → Clean Build Folder
4. Rebuild and retry

### Problem: Calculation Fails with Network Error

**Diagnosis:** Cloud Function issue (unrelated to fix)

**Steps:**
1. Check internet connection
2. Verify Firebase Cloud Function is deployed
3. Check for server-side errors in Firebase Console
4. Try again in 5 minutes (may be temporary)

### Problem: App Crashes During Calculation

**Diagnosis:** Unexpected error (report to developer)

**Steps:**
1. Check Xcode console for crash log
2. Note exact steps that caused crash
3. Save crash log
4. Report to developer with:
   - Steps to reproduce
   - Console logs before crash
   - Xcode crash log

---

## Success Confirmation

### All Tests Pass If:

1. **Saved Recipe Test:**
   - ✅ `recipeContent length > 0` in logs
   - ✅ Nutrition calculation succeeds
   - ✅ Values displayed in UI

2. **Unsaved Recipe Test:**
   - ✅ Still works (no regression)
   - ✅ Calculation succeeds

3. **No Errors:**
   - ✅ No "Tarif içeriği eksik" errors
   - ✅ No empty recipeContent for saved recipes
   - ✅ No unexpected crashes

---

## Reporting Results

### If All Tests Pass ✅

**Message:**
```
✅ Nutrition calculation fix VERIFIED

Test 1 (Saved Recipe): PASS
- recipeContent loaded correctly from CoreData
- API received complete content
- Calculation succeeded

Test 2 (Unsaved Recipe): PASS
- No regression
- Still works as expected

No issues found. Fix is working correctly.
```

### If Tests Fail ❌

**Include:**
1. Which test failed (1, 2, or both)
2. Complete Console logs for failed test
3. Screenshots of error in UI
4. Steps you took (exactly as performed)
5. Recipe name used for testing

**Example:**
```
❌ Nutrition calculation fix FAILED

Test 1 (Saved Recipe): FAIL
- recipeContent length: 0 chars (expected > 0)
- Error: "Tarif içeriği eksik"

Recipe used: "Scrambled Eggs"

Console logs:
[paste complete logs here]

Screenshot:
[attach screenshot of error]
```

---

## Clean Up After Testing

1. **Delete Test Recipes:**
   - Remove any test recipes created during testing
   - Keep real recipes

2. **Review Logs:**
   - Note any warnings or unusual patterns
   - Save logs if needed for reference

3. **Reset Simulator (Optional):**
   ```bash
   # If you want fresh start
   xcrun simctl erase all
   ```

---

## Next Steps

### After Successful Testing:
- [ ] Document any edge cases discovered
- [ ] Consider if debug logs should be reduced
- [ ] Monitor production usage for any issues

### If Issues Found:
- [ ] Report using format above
- [ ] Do NOT proceed with further testing
- [ ] Wait for developer response

---

**Testing Prepared By:** Forensic Code Investigator
**Date:** 2025-11-11
**Estimated Testing Time:** 15-20 minutes
