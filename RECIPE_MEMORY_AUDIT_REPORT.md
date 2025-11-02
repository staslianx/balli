# Recipe Memory Audit Report: Protein Variety Tracking

**Date:** 2025-11-01
**Issue:** Recipe recommendations heavily skewed toward chicken, lacking protein diversity
**Root Cause:** Memory system tracks ingredients but doesn't prioritize protein variety

---

## Executive Summary

### Problem Confirmed
The recipe memory system IS collecting ingredients and passing them to Cloud Functions, BUT:
1. **No protein-specific tracking**: All ingredients treated equally
2. **No variety weighting**: Recent proteins not explicitly deprioritized
3. **Prompt doesn't emphasize protein diversity**: Only generic "avoid repetition" guidance
4. **No protein categorization**: Chicken vs fish vs beef not distinguished

### Current State: ✅ WORKING (But Not Optimal)

**What's working:**
- ✅ Ingredients ARE being extracted via Gemini after generation (`extractMainIngredients()`)
- ✅ Ingredients ARE being stored in UserDefaults per subcategory
- ✅ Memory IS being fetched and passed to Cloud Functions
- ✅ Recent recipes ARE sent to the prompt (up to 10 entries)

**What's NOT working:**
- ❌ Protein variety is NOT explicitly tracked or weighted
- ❌ Protein frequency is NOT analyzed before generation
- ❌ Prompt doesn't emphasize "use different protein than last N recipes"
- ❌ No protein diversity scoring or suggestion system

---

## Architecture Analysis

### Data Flow Diagram
```
iOS Recipe Generation Request
    ↓
RecipeGenerationCoordinator.generateRecipeWithStreaming()
    ↓
fetchMemoryForGeneration() → RecipeMemoryService.getMemoryForCloudFunctions()
    ↓
RecipeMemoryRepository.fetchRecentMemory() → UserDefaults
    ↓
Convert to SimpleRecentRecipe (title, mainIngredient, cookingMethod)
    ↓
POST to Cloud Functions /generateSpontaneousRecipe
    ↓
recipe_chef_assistant.prompt (Genkit) with recentRecipes
    ↓
Gemini 2.5 Flash generates recipe
    ↓
extractMainIngredients() uses Gemini to extract 3-5 main ingredients
    ↓
Response includes extractedIngredients array
    ↓
recordRecipeInMemory() saves to RecipeMemoryRepository
    ↓
UserDefaults stores RecipeMemoryEntry (mainIngredients[], dateGenerated, subcategory)
```

### Memory Storage Schema

**iOS (UserDefaults):**
```swift
struct RecipeMemoryEntry {
    mainIngredients: [String]  // e.g., ["tavuk göğsü", "brokoli", "domates"]
    dateGenerated: Date
    subcategory: RecipeSubcategory
    recipeName: String?
}

struct RecipeMemoryStorage {
    entries: [String: [RecipeMemoryEntry]]
    // Key: subcategory rawValue (e.g., "Karbonhidrat ve Protein Uyumu")
    // Value: Array of entries (up to 30 per subcategory)
}
```

**Cloud Functions Format:**
```typescript
interface RecipeMemoryEntry {
  mainIngredients: string[];  // ["tavuk göğsü", "brokoli", "domates"]
  dateGenerated: string;      // ISO8601 timestamp
  subcategory: string;        // "Karbonhidrat ve Protein Uyumu"
  recipeName?: string;        // "Tavuklu Brokoli Sote"
}
```

**Prompt Format (converted to SimpleRecentRecipe):**
```typescript
interface SimpleRecentRecipe {
  title: string;           // "Tavuklu Brokoli Sote"
  mainIngredient: string;  // "tavuk göğsü" (first ingredient)
  cookingMethod: string;   // "Genel" (hardcoded - not stored!)
}
```

---

## Code Analysis

### ✅ iOS Memory System (WORKING)

**Files Analyzed:**
- `/balli/Features/RecipeManagement/Models/RecipeMemoryEntry.swift`
- `/balli/Features/RecipeManagement/Services/RecipeMemoryService.swift`
- `/balli/Features/RecipeManagement/Repositories/RecipeMemoryRepository.swift`
- `/balli/Features/RecipeManagement/Services/RecipeGenerationCoordinator.swift`

**Key Findings:**

1. **Ingredient Extraction (Post-Generation)**
   - **Location:** `/functions/src/services/recipe-memory.ts:224-295`
   - **Method:** `extractMainIngredients(recipeContent, recipeName)` uses Gemini to extract 3-5 main ingredients
   - **Prompt:** "Extract 3-5 main ingredients: primary protein, 2-3 main vegetables, defining flavor component"
   - **Status:** ✅ Working - Cloud Functions logs show successful extraction

2. **Memory Storage**
   - **Location:** `RecipeMemoryRepository.saveEntry()` → UserDefaults
   - **Limit:** 30 entries per subcategory (configurable via `RecipeSubcategory.memoryLimit`)
   - **Trimming:** Oldest entries auto-removed when limit exceeded
   - **Status:** ✅ Working

3. **Memory Retrieval**
   - **Location:** `RecipeGenerationCoordinator.fetchMemoryForGeneration()`
   - **Fetches:** Last 10 entries for subcategory
   - **Conversion:** `RecipeMemoryEntry` → `SimpleRecentRecipe` (extracts first ingredient as mainIngredient)
   - **Status:** ✅ Working

4. **Protein Classification**
   - **Location:** `RecipeMemoryService.isProtein()`, `RecipeMemoryService.isVegetable()`
   - **Proteins:** tavuk, somon, ton balığı, dana eti, kuzu eti, yumurta, etc.
   - **Status:** ✅ Implemented but NOT USED for diversity

### ❌ Cloud Functions Prompt (NOT OPTIMIZED)

**File:** `/functions/prompts/recipe_chef_assistant.prompt`

**Current Prompt (Lines 229-234):**
```handlebars
{{#if recentRecipes}}
{{#if recentRecipes.length}}
Son tarifler: {{#each recentRecipes}}{{this.title}}{{#unless @last}}, {{/unless}}{{/each}}
**Bunlardan farklı bir şey yap!**
{{/if}}
{{/if}}
```

**Problems:**
1. ❌ Generic "do something different" - no protein-specific guidance
2. ❌ Doesn't identify which protein was used in recent recipes
3. ❌ Doesn't suggest underutilized proteins
4. ❌ Doesn't weight recent proteins more heavily

**Diversity Constraints (Lines 236-252):**
```handlebars
{{#if diversityConstraints}}
{{#if diversityConstraints.avoidProteins}}
Protein değiştir: {{#each diversityConstraints.avoidProteins}}{{this}}{{#unless @last}}, {{/unless}}{{/each}}
{{/if}}
{{#if diversityConstraints.suggestProteins}}
Önerilen proteinler: {{#each diversityConstraints.suggestProteins}}{{this}}{{#unless @last}}, {{/unless}}{{/each}}
{{/if}}
{{/if}}
```

**Status:** ✅ Schema exists BUT ❌ NEVER POPULATED
- `diversityConstraints` parameter exists in prompt schema
- iOS code NEVER passes this parameter
- Result: Prompt section never triggers

---

## Root Cause: Missing Diversity Intelligence

### What's Missing:

1. **Pre-Generation Protein Analysis**
   - iOS should analyze recent recipes BEFORE calling Cloud Functions
   - Extract protein frequency: `{"tavuk": 5, "somon": 1, "dana eti": 0}`
   - Identify overused proteins (count >= 3 in last 10 recipes)
   - Identify underused proteins (count < 2 in last 10 recipes)

2. **Diversity Constraints Population**
   - **avoidProteins:** Proteins used >= 3 times in last 10 recipes
   - **suggestProteins:** Proteins used < 2 times OR never used
   - Pass these to Cloud Functions in request body

3. **Prompt Enhancement**
   - Add explicit protein variety emphasis BEFORE diversity constraints
   - Example: "🎯 Protein çeşitliliği kritik! Son 10 tariften 5'i tavuk kullandı. Somon, dana eti, veya tempeh tercih et."

4. **Protein Recency Weighting**
   - Last 3 recipes: High priority to avoid (weight = 3x)
   - Recipes 4-7: Medium priority to avoid (weight = 2x)
   - Recipes 8-10: Low priority to avoid (weight = 1x)

---

## Protein Distribution Analysis (Hypothesis)

**Likely Current Distribution:**
```
Tavuk (Chicken):        60-70%  ⚠️ Over-represented
Somon (Salmon):         10-15%
Dana/Kıyma (Beef):      5-10%
Tofu/Tempeh:            2-5%
Kuzu (Lamb):            1-3%
Köfte (Meatballs):      1-3%
Ton Balığı (Tuna):      1-3%
Other:                  5-10%
```

**Desired Distribution:**
```
Tavuk (Chicken):        25-30%  ✅ Balanced
Somon (Salmon):         15-20%
Dana/Kıyma (Beef):      15-20%
Balık (Other Fish):     10-15%
Tofu/Tempeh/Legumes:    10-15%
Kuzu (Lamb):            5-10%
Other:                  5-10%
```

**Target:** No protein should exceed 40% in last 10 recipes (4 out of 10)

---

## Recommended Fixes

### Priority 1: Implement Protein Variety Tracking (iOS)

**Location:** `RecipeMemoryService.swift`

**New Method:**
```swift
func analyzeProteinVariety(for subcategory: RecipeSubcategory) async -> ProteinVarietyAnalysis {
    let recentEntries = try await repository.fetchRecentMemory(for: subcategory, limit: 10)

    var proteinCounts: [String: Int] = [:]
    var recentProteins: [String] = []  // Last 3 recipes

    for (index, entry) in recentEntries.enumerated() {
        for ingredient in entry.mainIngredients {
            if Self.isProtein(ingredient) {
                proteinCounts[ingredient, default: 0] += 1
                if index < 3 {
                    recentProteins.append(ingredient)
                }
            }
        }
    }

    // Identify overused proteins (>= 40% = 4 out of 10)
    let overusedProteins = proteinCounts.filter { $0.value >= 4 }.map { $0.key }

    // Identify underused proteins (< 2 in history)
    let allProteins = ["tavuk göğsü", "somon", "dana eti", "kuzu eti", "ton balığı", "karides", "tofu", "kırmızı mercimek"]
    let underusedProteins = allProteins.filter { (proteinCounts[$0] ?? 0) < 2 }

    return ProteinVarietyAnalysis(
        overusedProteins: overusedProteins,
        recentProteins: recentProteins,
        suggestedProteins: underusedProteins,
        proteinCounts: proteinCounts
    )
}
```

### Priority 2: Populate Diversity Constraints (iOS)

**Location:** `RecipeGenerationCoordinator.generateRecipeWithStreaming()`

**Before Cloud Functions call:**
```swift
// Analyze protein variety
let varietyAnalysis = await memoryService.analyzeProteinVariety(for: subcategory)

// Build diversity constraints
let diversityConstraints = DiversityConstraints(
    avoidProteins: varietyAnalysis.overusedProteins,
    suggestProteins: varietyAnalysis.suggestedProteins,
    avoidCuisines: [],  // Future enhancement
    avoidMethods: []    // Future enhancement
)

// Add to request
let request = SpontaneousRecipeRequest(
    mealType: mealType,
    styleType: styleType,
    userId: userId,
    streamingEnabled: true,
    recentRecipes: recentRecipes,
    diversityConstraints: diversityConstraints  // NEW
)
```

### Priority 3: Enhance Prompt (Cloud Functions)

**Location:** `/functions/prompts/recipe_chef_assistant.prompt`

**Enhanced Section (Replace lines 229-252):**
```handlebars
{{#if recentRecipes}}
{{#if recentRecipes.length}}
📚 **Son 10 Tarif:** {{#each recentRecipes}}{{this.title}}{{#unless @last}}, {{/unless}}{{/each}}

⚠️ **ÇEŞITLILIK KURALI:** Aynı proteini sık kullanma! Farklı protein seçeneklerini tercih et.
{{/if}}
{{/if}}

{{#if diversityConstraints}}
🎯 **Protein Çeşitliliği Analizi:**

{{#if diversityConstraints.avoidProteins}}
{{#if diversityConstraints.avoidProteins.length}}
❌ **KAÇINILMASI GEREKEN PROTEİNLER (son 10 tariften 4+ kez kullanıldı):**
{{#each diversityConstraints.avoidProteins}}
- {{this}}
{{/each}}

**Bu proteinleri KULLANMA. Alternatif protein seç!**
{{/if}}
{{/if}}

{{#if diversityConstraints.suggestProteins}}
{{#if diversityConstraints.suggestProteins.length}}
✅ **ÖNERİLEN PROTEİNLER (az kullanıldı veya hiç kullanılmadı):**
{{#each diversityConstraints.suggestProteins}}
- {{this}}
{{/each}}

**Bu proteinlerden birini MUTLAKA kullan!**
{{/if}}
{{/if}}
{{/if}}
```

### Priority 4: Update Cloud Functions Types

**Location:** `/functions/src/types/recipe-memory.ts`

**Add:**
```typescript
export interface DiversityConstraints {
  avoidCuisines?: string[];
  avoidProteins?: string[];
  avoidMethods?: string[];
  suggestCuisines?: string[];
  suggestProteins?: string[];
}

export interface RecipeGenerationRequest {
  mealType: string;
  styleType: string;
  userId?: string;
  streamingEnabled?: boolean;
  memoryEntries?: RecipeMemoryEntry[];
  diversityConstraints?: DiversityConstraints;  // NEW
}

export interface ProteinVarietyAnalysis {
  overusedProteins: string[];
  recentProteins: string[];
  suggestedProteins: string[];
  proteinCounts: Record<string, number>;
}
```

---

## Testing Strategy

### Test Scenario 1: Chicken Repetition (High Priority)

**Setup:**
1. Generate 5 consecutive "Karbonhidrat ve Protein Uyumu" recipes
2. Record all proteins used

**Expected BEFORE Fix:**
- Chicken appears 3-4 times (60-80%)

**Expected AFTER Fix:**
- Chicken appears max 2 times (40%)
- At least 4 different proteins across 5 recipes

### Test Scenario 2: Variety Across 10 Recipes

**Setup:**
1. Generate 10 recipes in same subcategory
2. Track protein distribution

**Expected AFTER Fix:**
- No protein exceeds 4 occurrences (40%)
- At least 5 different proteins used
- Proteins that appeared in last 3 recipes are avoided in next generation

### Test Scenario 3: Rare Protein Suggestion

**Setup:**
1. Generate 5 chicken recipes
2. Next generation should suggest underused proteins

**Expected AFTER Fix:**
- Prompt includes "suggestProteins: [somon, dana eti, tofu, ...]"
- Gemini receives explicit instruction to use suggested proteins
- Generated recipe uses a suggested protein

---

## Success Criteria

✅ **Criterion 1:** No protein exceeds 40% in last 10 recipes (4 out of 10)
✅ **Criterion 2:** Proteins used in last 3 recipes are deprioritized
✅ **Criterion 3:** Underused proteins are explicitly suggested
✅ **Criterion 4:** Variety analysis is logged for debugging
✅ **Criterion 5:** Test script shows diverse protein distribution

---

## Implementation Checklist

### Phase 1: iOS Foundation (Estimated: 2-3 hours)
- [ ] Add `ProteinVarietyAnalysis` model to `RecipeMemoryService.swift`
- [ ] Implement `analyzeProteinVariety()` method
- [ ] Add `DiversityConstraints` model to iOS
- [ ] Update `RecipeGenerationService` to accept `diversityConstraints` parameter
- [ ] Update `RecipeGenerationCoordinator` to populate diversity constraints before generation
- [ ] Add comprehensive logging for debugging

### Phase 2: Cloud Functions Enhancement (Estimated: 1 hour)
- [ ] Update `recipe-memory.ts` types to include `DiversityConstraints`
- [ ] Update prompt schema to accept `diversityConstraints` parameter
- [ ] Enhance prompt text to emphasize protein variety (lines 229-252)
- [ ] Test prompt rendering with sample data

### Phase 3: Testing & Validation (Estimated: 2 hours)
- [ ] Generate 5 consecutive recipes, verify protein distribution
- [ ] Generate 10 recipes, verify no protein exceeds 40%
- [ ] Verify logs show diversity analysis and constraints
- [ ] Test with empty memory (first recipe in subcategory)
- [ ] Test with partially filled memory (5 entries)

### Phase 4: Documentation (Estimated: 30 minutes)
- [ ] Update architecture docs with protein variety system
- [ ] Document `ProteinVarietyAnalysis` usage
- [ ] Add examples to `RECIPE_MEMORY_AUDIT_REPORT.md`

---

## Long-Term Enhancements (Future)

### 1. Cuisine Variety Tracking
- Track cuisine types (Turkish, Italian, Asian, etc.)
- Avoid cuisine repetition similar to protein

### 2. Cooking Method Diversity
- Track methods (fırında, tavada, haşlama, etc.)
- Suggest underused methods

### 3. Smart Recency Weighting
- Last 3 recipes: weight = 3x (critical to avoid)
- Recipes 4-7: weight = 2x
- Recipes 8-10: weight = 1x

### 4. User Preference Learning
- Track which recipes user saves/favorites
- Prefer protein types from saved recipes

### 5. Seasonal Ingredient Suggestions
- Suggest seasonal vegetables/proteins
- Integrate with ingredient availability data

---

## Risk Assessment

### Low Risk
- ✅ Memory system already working - only adding intelligence layer
- ✅ Backward compatible - works without `diversityConstraints`
- ✅ Fails gracefully - if analysis fails, generation continues

### Medium Risk
- ⚠️ Prompt changes may affect generation quality - requires testing
- ⚠️ Over-constraining might limit Gemini creativity - may need tuning

### Mitigation
- Keep diversity constraints as suggestions, not hard rules
- Prompt says "prefer" not "must" (except for overused proteins)
- Monitor generation quality after deployment

---

## Conclusion

**The recipe memory system infrastructure is solid and working correctly.**

The issue is NOT:
- ❌ Ingredients not being extracted
- ❌ Memory not being stored
- ❌ Memory not being retrieved

The issue IS:
- ❌ No protein-specific intelligence
- ❌ No variety analysis before generation
- ❌ Prompt doesn't emphasize protein diversity
- ❌ No diversity constraints being passed

**Solution:** Add intelligence layer that:
1. Analyzes protein frequency before generation
2. Identifies overused/underused proteins
3. Populates `diversityConstraints` parameter
4. Enhances prompt to emphasize protein variety

**Estimated Total Time:** 5-6 hours
**Complexity:** Medium (mostly new logic, minimal breaking changes)
**Impact:** High (solves core user complaint about chicken repetition)

---

## Next Steps

1. **Implement Priority 1-3 fixes** (iOS + Cloud Functions)
2. **Test with 15-recipe test script** (similar to existing test)
3. **Monitor production logs** for diversity analysis output
4. **Iterate on prompt** if initial results show insufficient variety

**Ready to proceed with implementation?**
