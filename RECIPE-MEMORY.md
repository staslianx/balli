# Recipe Memory Feature Specification

## Overview

A recipe memory system for a diabetes-friendly recipe generation iOS app that prevents repetitive recipe suggestions across multiple meal categories while maintaining recipe quality.

## Problem Statement

The app currently generates similar recipes too frequently, creating a poor user experience. Users see the same ingredient combinations (e.g., chicken + broccoli) repeatedly within short timeframes.

## Solution Architecture

### Category-Based Memory System

Store recipe history separately for each meal category to prevent false positives between contextually different meals (breakfast vs dinner).

### Category Hierarchy

The app has a hierarchical category structure for UI organization, but **memory tracking happens at the leaf/subcategory level only**.

**Full Category Structure:**

```
├── Kahvaltı (Breakfast)
├── Salatalar (Salads)
│   ├── Doyurucu salata (Hearty salad - main protein source)
│   └── Hafif salata (Light salad - side dish)
├── Akşam Yemeği (Dinner)
│   ├── Karbonhidrat ve Protein Uyumu (Carb + Protein balance)
│   └── Tam tahıl makarna çeşitleri (Whole grain pasta varieties)
├── Tatlılar (Desserts)
│   ├── Sana özel tatlılar (Diabetes-friendly dessert versions)
│   ├── Dondurma (Ice cream for Ninja Creami machine)
│   └── Meyve salatası (Fruit salad)
└── Atıştırmalıklar (Snacks)
```

**Important:** Parent categories (Salatalar, Akşam Yemeği, Tatlılar) are UI groupings only. Memory is NOT shared between subcategories.

### Memory Limits Per Subcategory

There are **9 independent memory pools**, one for each leaf category:

|Subcategory                  |Memory Limit|Rationale                                              |
|-----------------------------|------------|-------------------------------------------------------|
|Kahvaltı                     |20-25       |Limited diabetes-friendly breakfast options            |
|Doyurucu salata              |25-30       |High variety potential with protein + vegetable combos |
|Hafif salata                 |15-20       |Simpler compositions, less variety needed              |
|Karbonhidrat ve Protein Uyumu|30          |Main dinners require maximum variety                   |
|Tam tahıl makarna çeşitleri  |20-25       |Decent variety potential with different sauces/proteins|
|Sana özel tatlılar           |15          |Diabetes-friendly desserts inherently limited          |
|Dondurma                     |10          |Very limited variety for diabetes-friendly ice cream   |
|Meyve salatası               |8-10        |Limited fruit combinations for diabetes                |
|Atıştırmalıklar              |15-20       |Moderate variety for healthy snacks                    |

## Data Structure

### Recipe Memory Entry

Store minimal data per recipe:

```
{
  "mainIngredients": [string], // 3-5 key ingredients only (in Turkish)
  "dateGenerated": ISO8601 timestamp,
  "category": string
}
```

**What to store as main ingredients:**

- Primary protein (if applicable): “tavuk göğsü”, “somon balığı”, “tofu”
- Primary vegetables (2-3 max): “brokoli”, “kabak”, “biber”
- Defining flavor/ingredient: “sarımsak”, “zencefil”, “limon”

**What NOT to store:**

- Common seasonings (tuz, karabiber, zeytinyağı)
- Su, basic condiments
- Exact measurements
- Full recipe text or instructions

### Storage Implementation

- iOS: Use UserDefaults for simplicity (single user app)
- Structure: Dictionary with **9 subcategory keys**, each containing array of memory entries
- Key: “recipeMemory”

```
{
  "Kahvaltı": [...],
  "Doyurucu salata": [...],
  "Hafif salata": [...],
  "Karbonhidrat ve Protein Uyumu": [...],
  "Tam tahıl makarna çeşitleri": [...],
  "Sana özel tatlılar": [...],
  "Dondurma": [...],
  "Meyve salatası": [...],
  "Atıştırmalıklar": [...]
}
```

**Example entry:**

```
"Kahvaltı": [
  {
    "mainIngredients": ["yumurta", "domates", "beyaz peynir"],
    "dateGenerated": "2025-10-23T08:30:00Z",
    "subcategory": "Kahvaltı"
  },
  ...
]
```

## Recipe Generation Flow

### Step 1: Retrieve Subcategory Memory

- User selects a specific subcategory (e.g., “Doyurucu salata”, not the parent “Salatalar”)
- Fetch memory array for that specific subcategory
- If array exceeds subcategory limit, trim oldest entries
- Extract main ingredients from the most recent 10 recipes only

### Step 2: Generate Recipe with Gemini

**Prompt Structure (in Turkish):**

```
Diyabet dostu bir [SUBCATEGORY] tarifi oluştur.

Bağlam: [PARENT_CATEGORY_CONTEXT if helpful]
Örnek: "Bu, protein içeren ana yemek olarak servis edilen doyurucu bir salata"

Çeşitlilik için, iyi bir araya gelen bu malzemelerden bazılarını kullanmayı düşün:
Proteinler: [list of least-used proteins in this subcategory - e.g., "dana eti", "kırmızı mercimek", "karides"]
Sebzeler: [list of least-used vegetables in this subcategory - e.g., "karnabahar", "ıspanak", "mantar"]

Diyabet yönetimi için beslenme dengesini koruyan benzersiz ve lezzetli bir tarif oluştur.
```

**Key Points:**

- DO NOT use negative prompts (“X kullanma”)
- Frame as positive suggestions for variety
- Let Gemini maintain recipe quality
- Include subcategory context in prompt (e.g., “doyurucu salata”, “tam tahıllı makarna”, “Ninja Creami için dondurma”)
- Parent category context may help (e.g., mention “akşam yemeği” for Akşam Yemeği subcategories)
- **All prompts must be in Turkish**
- Ingredients returned by Gemini should be in Turkish

### Step 3: Extract Main Ingredients from Generated Recipe

Parse the Gemini response to identify:

1. Primary protein (if any) - e.g., “tavuk göğsü”, “kıyma”, “somon”
1. 2-3 main vegetables or key ingredients - e.g., “brokoli”, “patlıcan”, “domates”
1. Any defining flavor component - e.g., “sarımsak”, “kimyon”, “limon”

Create an array of 3-5 main ingredients **in Turkish**.

**Important:** Normalize ingredient names:

- Lowercase: “Tavuk Göğsü” → “tavuk göğsü”
- Trim whitespace
- Use consistent naming: “tavuk” not “piliç”, “beyaz peynir” not “peynir”

### Step 4: Similarity Check

Compare new recipe’s main ingredients against the **last 10 recipes** in the subcategory memory:

**Matching Logic:**

- Count ingredient overlap between new recipe and each of last 10
- If 3 or more ingredients match any single previous recipe → TOO SIMILAR

**Alternative Simple Check:**

- Concatenate protein + primary vegetable as a combo string
- Check if this combo exists in last 10 recipes
- Example: “tavuk-brokoli”, “somon-kuşkonmaz”

### Step 5: Handle Similarity Result

**If TOO SIMILAR:**

- Regenerate recipe once (maximum 1 retry)
- Use same prompt
- If second attempt also too similar, accept it anyway (avoid infinite loops)

**If SUFFICIENTLY DIFFERENT:**

- Present recipe to user
- Add to subcategory memory with current timestamp
- Trim memory array if it exceeds subcategory limit

## Technical Requirements

### Language Requirements

- **All user-facing content must be in Turkish**
- Recipe generation prompts to Gemini must be in Turkish
- Ingredient names stored in memory must be in Turkish
- UI category names are already in Turkish
- Error messages and user feedback should be in Turkish

### Cloud Functions Integration

- Current setup: Gemini API via Cloud Functions
- Function should accept: **subcategory** (e.g., “Doyurucu salata”), user preferences, memory array for that subcategory
- Function returns: generated recipe + extracted main ingredients
- Parent category (e.g., “Salatalar”) can optionally be passed for context but is not used for memory lookup

### iOS Implementation

- Store memory in UserDefaults with 9 independent subcategory keys
- Sync reads/writes to prevent race conditions
- Handle memory serialization/deserialization
- UI should allow selection of specific subcategories (not just parent categories)
- Pass exact subcategory name (e.g., “Doyurucu salata”) to Cloud Function

### Memory Management

- Auto-trim: Remove oldest entries when limit exceeded
- No manual clearing needed
- Optional: Add “clear memory” button in settings for testing

## Edge Cases & Handling

### Limited Recipe Variety in Subcategory

- Some subcategories (Dondurma, Meyve salatası) have inherently limited variety
- Accept that repetition may occur more frequently in these subcategories
- Don’t force bad recipe combinations just for variety

### Back-to-Back Generation in Same Subcategory

- If user generates 5 recipes consecutively in “Doyurucu salata”, some similarity expected
- System will still prevent exact duplicates in last 10

### Gemini Ignoring Guidance

- LLMs don’t follow constraints perfectly
- Single retry handles most cases
- Accept occasional similar recipe rather than multiple retries

### First-Time User (Empty Memory)

- Empty arrays for all 9 subcategories initially
- First 10 recipes in each subcategory will have no similarity checking
- System naturally builds up memory over time per subcategory
- User may have 30 recipes total but still have empty memory in unused subcategories (e.g., never generated Dondurma recipes)

## Success Metrics

### Primary Goal

Reduce the frequency of “I just had this” moments for the user.

### Measurable Outcomes

- No identical ingredient combinations in last 10 recipes **per subcategory**
- Regeneration rate < 10% of total generations
- User doesn’t see same protein-vegetable combo within 2 weeks of normal use **within the same subcategory**
- Cross-subcategory repetition is acceptable (chicken in breakfast vs chicken in dinner)

## Non-Goals

- Perfect variety (impossible with limited diabetes-friendly options)
- Zero repetition ever (unrealistic)
- Learning user taste preferences (future feature)
- Nutritional optimization (handled separately)

## Implementation Priority

### Phase 1: Core Memory System

1. Category-based storage structure
1. Save recipe main ingredients after generation
1. Basic retrieval by category

### Phase 2: Similarity Checking

1. Extract main ingredients from generated recipe
1. Compare against last 10 in category
1. Flag if too similar

### Phase 3: Regeneration Logic

1. Integrate similarity check into generation flow
1. Implement single retry on similarity match
1. Add fallback (accept after 1 retry)

### Phase 4: Polish

1. Memory trimming automation
1. Optional clear memory feature
1. Analytics/logging for similarity hits

## Testing Scenarios

### Test Case 1: New Subcategory

- Generate first recipe in empty subcategory (e.g., “Dondurma”)
- Verify storage works in correct subcategory key
- No similarity check should occur
- Other subcategories remain unaffected

### Test Case 2: Similar Recipe Generated

- Memory has “tavuk”, “brokoli”, “sarımsak”
- Generate recipe with “tavuk”, “brokoli”, “zencefil”
- Should detect similarity (3 matches)
- Should regenerate once

### Test Case 3: Different Recipe

- Memory has “tavuk”, “brokoli”, “sarımsak”
- Generate recipe with “somon”, “kuşkonmaz”, “limon”
- Should pass (different enough)
- Should save to memory

### Test Case 4: Memory Limit Reached

- Subcategory “Karbonhidrat ve Protein Uyumu” has 30 recipes (at limit)
- Generate new recipe in this subcategory
- Oldest should be removed from this subcategory only
- New one should be added
- Other subcategories unaffected

### Test Case 5: Cross-Subcategory Independence

- “Kahvaltı” memory has “yumurta”, “beyaz peynir”, “domates”
- Generate recipe in “Karbonhidrat ve Protein Uyumu” with “yumurta”, “beyaz peynir”, “domates”
- Should NOT flag as similar (different subcategories)
- Both subcategories maintain independent memories

## Technical Notes for Implementation

### UserDefaults Key Structure

```
Key: "recipeMemory_v1"
Value: Dictionary<String, [[String: Any]]>
```

### Ingredient Normalization

- Lowercase all ingredients: “Tavuk Göğsü” → “tavuk göğsü”
- Trim whitespace
- Singular form preferred: “domates” not “domatesler”
- Basic form: “tavuk göğsü” → “tavuk” (optional, but helps with matching)
- Consistent naming conventions:
  - “tavuk” (not “piliç” or “hindi” unless specifically turkey)
  - “beyaz peynir” (not just “peynir”)
  - “kırmızı et” vs “dana eti” vs “kuzu eti” (be specific)

**Note:** Turkish ingredient parsing from Gemini may require additional normalization handling for common variations

### Concurrency Considerations

- Single user app reduces complexity
- Still use proper read/write locking if generating multiple recipes simultaneously
- Cloud Function should be stateless

### Error Handling

- If memory retrieval fails → continue without check
- If Gemini call fails → return error to user, don’t save to memory
- If similarity check crashes → accept recipe (fail open)

## Future Enhancements (Out of Scope)

- User rating system for recipes
- Ingredient preference learning
- Seasonal ingredient suggestions
- Nutritional tracking integration
- Recipe favorites/bookmarking
- Shopping list generation from recipes

-----

## Summary

This specification describes a straightforward, category-based recipe memory system that prevents repetitive recipe suggestions by checking the last 10 recipes in each meal category. It balances simplicity, performance (minimal retries), and user experience (reduced repetition) for a personal diabetes-friendly recipe app.
