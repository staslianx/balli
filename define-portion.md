# Portion Definition System - Implementation Specification

**Version:** 1.0  
**Date:** 2025-11-04  
**App:** balli iOS  
**Critical:** This feature is essential for accurate diabetes management

---

## Table of Contents

1. [Overview](#overview)
2. [Data Models](#data-models)
3. [API Changes](#api-changes)
4. [Workflow Specifications](#workflow-specifications)
5. [UI Components](#ui-components)
6. [Calculation Logic](#calculation-logic)
7. [Edge Cases](#edge-cases)
8. [Testing Requirements](#testing-requirements)

---

## Overview

### Problem Statement

Users need two different recipe creation flows:
1. **AI-Generated Recipes:** Pre-portioned by AI for 1 serving
2. **Manual Recipes:** User enters ingredients without knowing portion size upfront

The portion definition system allows users to define or adjust what "1 portion" means for any recipe, enabling accurate nutritional tracking for diabetes management.

### Key Requirements

- Manual recipes MUST have portion defined before nutrition is finalized
- Generated recipes have portions pre-calculated but CAN be adjusted
- All nutrition values (including glycemic load) recalculate based on portion size
- Same UI component used for both "define" and "adjust" scenarios
- Calculations must be mathematically precise for medical accuracy

---

## Data Models

### 1. Recipe Model (Swift)

```swift
struct Recipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let content: String  // Markdown with ingredients + steps
    let createdAt: Date
    let recipeType: RecipeType
    
    // Nutrition data - always present after calculation
    var totalWeight: Double  // grams, cooked weight
    var totalNutrition: NutritionValues
    var per100g: NutritionValues
    
    // Portion data - may be nil for unconfigured manual recipes
    var portionSize: Double?  // grams per portion (user-defined)
    var portionNutrition: NutritionValues?  // calculated from portionSize
    
    // Computed properties
    var portionCount: Double? {
        guard let portionSize = portionSize else { return nil }
        return totalWeight / portionSize
    }
    
    var isPortionDefined: Bool {
        portionSize != nil
    }
    
    enum RecipeType: String, Codable {
        case aiGenerated
        case manual
    }
}
```

### 2. NutritionValues Model (Swift)

```swift
struct NutritionValues: Codable, Equatable {
    var calories: Double        // kcal
    var carbohydrates: Double   // grams
    var fiber: Double           // grams
    var sugar: Double           // grams
    var protein: Double         // grams
    var fat: Double             // grams
    var glycemicLoad: Double    // unitless (0-100+)
    
    // Calculate nutrition for a given ratio
    func scaled(by ratio: Double) -> NutritionValues {
        return NutritionValues(
            calories: calories * ratio,
            carbohydrates: carbohydrates * ratio,
            fiber: fiber * ratio,
            sugar: sugar * ratio,
            protein: protein * ratio,
            fat: fat * ratio,
            glycemicLoad: glycemicLoad * ratio
        )
    }
    
    // Multiply operator for convenience
    static func * (lhs: NutritionValues, rhs: Double) -> NutritionValues {
        return lhs.scaled(by: rhs)
    }
}
```

### 3. Cloud Function Response Schema (TypeScript)

**Current Schema (Keep this for AI-generated recipes):**
```typescript
interface NutritionResponse {
  calories: number;              // per 100g
  carbohydrates: number;         // per 100g
  fiber: number;                 // per 100g
  sugar: number;                 // per 100g
  protein: number;               // per 100g
  fat: number;                   // per 100g
  glycemicLoad: number;          // per portion (equals perPortion.glycemicLoad)
  
  perPortion: {
    weight: number;              // grams
    calories: number;
    carbohydrates: number;
    fiber: number;
    sugar: number;
    protein: number;
    fat: number;
    glycemicLoad: number;        // same as top-level glycemicLoad
  };
  
  nutritionCalculation: {
    totalRecipeWeight: number;
    totalRecipeCalories: number;
    calculationNotes: string;
    reasoningSteps: Array<{
      ingredient: string;
      recipeContext: string;
      reasoning: string;
      calculation: string;
      confidence: "high" | "medium" | "low";
    }>;
    sanityCheckResults: {
      // ... existing sanity checks
    };
  };
}
```

**New Schema for Manual Recipes (Add this as alternative response type):**
```typescript
interface ManualRecipeNutritionResponse {
  // NO per 100g values - calculate client-side
  // NO perPortion values - user will define
  
  totalRecipe: {
    weight: number;              // grams, cooked
    calories: number;            // total
    carbohydrates: number;       // total grams
    fiber: number;               // total grams
    sugar: number;               // total grams
    protein: number;             // total grams
    fat: number;                 // total grams
    glycemicLoad: number;        // total (will be divided by portions)
  };
  
  nutritionCalculation: {
    totalRecipeWeight: number;   // Same as totalRecipe.weight
    totalRecipeCalories: number; // Same as totalRecipe.calories
    calculationNotes: string;
    reasoningSteps: Array<{
      ingredient: string;
      recipeContext: string;
      reasoning: string;
      calculation: string;
      confidence: "high" | "medium" | "low";
    }>;
    sanityCheckResults: {
      // ... existing sanity checks
    };
  };
}

// Union type for API response
type NutritionCalculationResponse = 
  | NutritionResponse              // AI-generated recipes
  | ManualRecipeNutritionResponse  // Manual recipes
```

---

## API Changes

### 1. Nutrition Calculation Endpoint

**Endpoint:** `POST /calculateNutrition`

**Request Schema:**
```typescript
interface CalculateNutritionRequest {
  recipeName: string;
  recipeContent: string;       // Markdown format
  servings?: number | null;    // null = manual recipe, number = AI-generated
  recipeType: "aiGenerated" | "manual";  // Explicit flag
}
```

**Response Logic:**
```typescript
function calculateNutrition(request: CalculateNutritionRequest): Response {
  if (request.recipeType === "manual" || request.servings === null) {
    // Manual recipe flow
    return {
      totalRecipe: {
        weight: calculatedCookedWeight,
        calories: totalCalories,
        carbohydrates: totalCarbs,
        fiber: totalFiber,
        sugar: totalSugar,
        protein: totalProtein,
        fat: totalFat,
        glycemicLoad: totalGL
      },
      nutritionCalculation: {
        // ... detailed breakdown
      }
    };
  } else {
    // AI-generated recipe flow (existing behavior)
    return {
      calories: per100gCalories,
      carbohydrates: per100gCarbs,
      // ... per 100g values
      perPortion: {
        weight: cookedWeight / servings,
        calories: totalCalories / servings,
        // ... per portion values
      },
      nutritionCalculation: {
        // ... detailed breakdown
      }
    };
  }
}
```

### 2. Prompt Modifications

**Add to the existing nutrition calculation prompt:**

```markdown
## INPUT HANDLING

Check the `recipeType` field:

**IF recipeType = "manual" OR servings is null:**
- Calculate ONLY totalRecipe values
- Do NOT calculate perPortion
- Do NOT calculate per100g in the response (client will calculate)
- Set glycemicLoad to total value (client will divide by user-defined portions)

**ELSE (recipeType = "aiGenerated" AND servings is a number):**
- Calculate per100g values
- Calculate perPortion based on servings
- Calculate glycemicLoad per portion
- Use existing logic (no changes)

## OUTPUT FORMAT

**For manual recipes:**
```json
{
  "totalRecipe": {
    "weight": <cooked_weight_in_grams>,
    "calories": <total_calories>,
    "carbohydrates": <total_carbs_grams>,
    "fiber": <total_fiber_grams>,
    "sugar": <total_sugar_grams>,
    "protein": <total_protein_grams>,
    "fat": <total_fat_grams>,
    "glycemicLoad": <total_gl>
  },
  "nutritionCalculation": { ... }
}
```

**For AI-generated recipes (existing format):**
```json
{
  "calories": <per_100g>,
  "carbohydrates": <per_100g>,
  "fiber": <per_100g>,
  "sugar": <per_100g>,
  "protein": <per_100g>,
  "fat": <per_100g>,
  "glycemicLoad": <per_portion>,
  "perPortion": { ... },
  "nutritionCalculation": { ... }
}
```
```

---

## Workflow Specifications

### Workflow 1: Manual Recipe Creation

**Step-by-step:**

```
1. User Input
   ├─ User writes recipe in markdown
   ├─ Includes ingredients with weights (grams)
   ├─ Includes cooking steps (Yapılışı)
   └─ Taps "Save"

2. Recipe Save
   ├─ Recipe saved to database
   ├─ recipeType = "manual"
   ├─ portionSize = nil
   ├─ portionNutrition = nil
   └─ Recipe generation view remains open

3. Nutrition Calculation Trigger
   ├─ User taps "Calculate Nutrition" button
   ├─ Show loading indicator
   └─ Call API: POST /calculateNutrition
      {
        recipeName: "User's Recipe",
        recipeContent: "markdown content",
        servings: null,
        recipeType: "manual"
      }

4. API Response Processing
   ├─ Receive ManualRecipeNutritionResponse
   ├─ Store totalWeight = response.totalRecipe.weight
   ├─ Store totalNutrition = response.totalRecipe.*
   └─ Calculate per100g client-side:
      per100g = totalNutrition * (100 / totalWeight)

5. Portion Definition (REQUIRED)
   ├─ Automatically present PortionDefinerModal
   ├─ mode = .define
   ├─ Cannot dismiss without defining
   ├─ Default slider position = totalWeight (full recipe = 1 portion)
   └─ User adjusts slider to desired portion size

6. Portion Save
   ├─ User taps "✓ Save" in modal
   ├─ Store portionSize = userSelectedWeight
   ├─ Calculate portionNutrition:
      ratio = portionSize / totalWeight
      portionNutrition = totalNutrition * ratio
   ├─ Save to recipe
   └─ Dismiss modal → Return to recipe detail view

7. Recipe Detail Display
   ├─ Show portion info: "1 portion = Xg (Y.Y portions total)"
   ├─ Show portionNutrition values
   ├─ Show "Adjust Portion" button (for future edits)
   └─ Enable meal logging (now that portion is defined)
```

**Code Example:**
```swift
// Step 3: Nutrition Calculation
func calculateNutritionForManualRecipe(_ recipe: Recipe) async throws {
    let request = NutritionCalculationRequest(
        recipeName: recipe.name,
        recipeContent: recipe.content,
        servings: nil,
        recipeType: .manual
    )
    
    let response = try await nutritionService.calculateNutrition(request)
    
    // Step 4: Process response
    recipe.totalWeight = response.totalRecipe.weight
    recipe.totalNutrition = NutritionValues(
        calories: response.totalRecipe.calories,
        carbohydrates: response.totalRecipe.carbohydrates,
        fiber: response.totalRecipe.fiber,
        sugar: response.totalRecipe.sugar,
        protein: response.totalRecipe.protein,
        fat: response.totalRecipe.fat,
        glycemicLoad: response.totalRecipe.glycemicLoad
    )
    
    // Calculate per100g client-side
    recipe.per100g = recipe.totalNutrition * (100 / recipe.totalWeight)
    
    // Step 5: Show portion definer (required)
    showPortionDefiner(recipe: recipe, mode: .define, isRequired: true)
}

// Step 6: Save portion
func savePortionSize(recipe: Recipe, portionWeight: Double) {
    recipe.portionSize = portionWeight
    
    let ratio = portionWeight / recipe.totalWeight
    recipe.portionNutrition = recipe.totalNutrition * ratio
    
    saveRecipe(recipe)
}
```

---

### Workflow 2: AI-Generated Recipe Creation

**Step-by-step:**

```
1. User Input
   ├─ User requests recipe via AI
   ├─ Example: "1 kişilik tavuklu yemek yap"
   └─ servings = 1 (extracted from request)

2. Recipe Generation + Nutrition Calculation (Combined)
   ├─ AI generates recipe for 1 serving
   ├─ Immediately calculate nutrition
   └─ Call API: POST /calculateNutrition
      {
        recipeName: "Tavuklu Sote",
        recipeContent: "generated markdown",
        servings: 1,
        recipeType: "aiGenerated"
      }

3. API Response Processing
   ├─ Receive NutritionResponse
   ├─ Store totalWeight = response.nutritionCalculation.totalRecipeWeight
   ├─ Calculate totalNutrition from perPortion:
      totalNutrition = perPortion * servings
   ├─ Store per100g = response.* (top-level values)
   ├─ Store portionSize = response.perPortion.weight (ALREADY DEFINED)
   └─ Store portionNutrition = response.perPortion

4. Recipe Display
   ├─ Show complete recipe with nutrition
   ├─ Show portion info: "1 portion = Xg (1.0 portion total)"
   ├─ Show "Adjust Portion" button (OPTIONAL)
   └─ User can save and use immediately

5. Portion Adjustment (OPTIONAL)
   ├─ User taps "Adjust Portion" button
   ├─ Present PortionDefinerModal
   ├─ mode = .adjust
   ├─ Pre-fill slider with current portionSize
   ├─ User adjusts as desired
   └─ Can dismiss without saving

6. Portion Update (If user adjusted)
   ├─ User taps "✓ Save" in modal
   ├─ Update portionSize = userSelectedWeight
   ├─ Recalculate portionNutrition:
      ratio = portionSize / totalWeight
      portionNutrition = totalNutrition * ratio
   └─ Update recipe display with new values
```

**Code Example:**
```swift
// Step 2-3: Generate and calculate nutrition
func generateRecipe(prompt: String) async throws -> Recipe {
    // Generate recipe
    let generatedRecipe = try await aiService.generateRecipe(prompt)
    
    // Immediately calculate nutrition
    let request = NutritionCalculationRequest(
        recipeName: generatedRecipe.name,
        recipeContent: generatedRecipe.content,
        servings: 1,  // Always 1 for generated recipes
        recipeType: .aiGenerated
    )
    
    let response = try await nutritionService.calculateNutrition(request)
    
    // Process response - portion already defined
    var recipe = generatedRecipe
    recipe.totalWeight = response.nutritionCalculation.totalRecipeWeight
    recipe.per100g = NutritionValues(
        calories: response.calories,
        carbohydrates: response.carbohydrates,
        fiber: response.fiber,
        sugar: response.sugar,
        protein: response.protein,
        fat: response.fat,
        glycemicLoad: response.glycemicLoad
    )
    recipe.portionSize = response.perPortion.weight  // Already defined
    recipe.portionNutrition = NutritionValues(
        calories: response.perPortion.calories,
        carbohydrates: response.perPortion.carbohydrates,
        fiber: response.perPortion.fiber,
        sugar: response.perPortion.sugar,
        protein: response.perPortion.protein,
        fat: response.perPortion.fat,
        glycemicLoad: response.perPortion.glycemicLoad
    )
    
    // Calculate total nutrition from per-portion
    recipe.totalNutrition = recipe.portionNutrition! * 1.0  // servings = 1
    
    return recipe
}

// Step 5-6: Adjust portion (optional)
func adjustPortion(recipe: Recipe, newPortionWeight: Double) {
    recipe.portionSize = newPortionWeight
    
    let ratio = newPortionWeight / recipe.totalWeight
    recipe.portionNutrition = recipe.totalNutrition * ratio
    
    saveRecipe(recipe)
}
```

---

### Workflow 3: Portion Adjustment (Post-Creation)

**Applicable to both manual and AI-generated recipes**

```
1. Recipe Detail View
   ├─ Display current portion info
   ├─ "1 portion = 300g (1.3 portions total)"
   └─ Show "Adjust Portion" button

2. User Taps "Adjust Portion"
   ├─ Present PortionDefinerModal
   ├─ mode = .adjust
   ├─ Pre-fill slider with current portionSize
   └─ Show live nutrition preview as slider moves

3. User Adjusts Slider
   ├─ Slider range: 50g to totalWeight
   ├─ Live updates:
      - Portion weight (grams)
      - Portion count (totalWeight / portionWeight)
      - All nutrition values (scaled by ratio)
   └─ User sees immediate feedback

4. User Saves or Cancels
   ├─ Option A: Tap "✓ Save"
   │  ├─ Update portionSize
   │  ├─ Recalculate portionNutrition
   │  ├─ Save to database
   │  └─ Dismiss modal → Show updated values
   └─ Option B: Tap "✕ Cancel" or swipe down
      ├─ Discard changes
      └─ Dismiss modal → Show original values
```

---

## UI Components

### Component 1: PortionDefinerModal

**Purpose:** Unified component for defining/adjusting portions

**SwiftUI Implementation:**
```swift
struct PortionDefinerModal: View {
    // Input data
    let recipe: Recipe
    let mode: Mode
    let isRequired: Bool  // true for manual recipes (first time)
    
    // State
    @State private var portionWeight: Double
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case define   // First-time definition (manual recipes)
        case adjust   // Editing existing portion (both types)
        
        var title: String {
            switch self {
            case .define: return "Define Portion"
            case .adjust: return "Adjust Portion"
            }
        }
        
        var buttonText: String {
            switch self {
            case .define: return "Set Portion"
            case .adjust: return "Update Portion"
            }
        }
    }
    
    init(recipe: Recipe, mode: Mode, isRequired: Bool = false) {
        self.recipe = recipe
        self.mode = mode
        self.isRequired = isRequired
        
        // Initialize slider with current or default value
        _portionWeight = State(
            initialValue: recipe.portionSize ?? recipe.totalWeight
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(mode.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Slide to set what one portion means for you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Total recipe info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Recipe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("\(Int(recipe.totalWeight))g")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(Int(recipe.totalNutrition.calories)) kcal")
                            .font(.headline)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Divider()
                
                // Portion slider
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("One Portion")
                                .font(.headline)
                            Text("\(Int(portionWeight))g")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Makes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(portionCount, specifier: "%.1f")")
                                .font(.title)
                                .fontWeight(.semibold)
                            Text(portionCount == 1.0 ? "portion" : "portions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Slider(
                        value: $portionWeight,
                        in: 50...recipe.totalWeight,
                        step: 1
                    )
                    .accentColor(.blue)
                    
                    HStack {
                        Text("50g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(recipe.totalWeight))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                
                // Live nutrition preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition Per Portion")
                        .font(.headline)
                    
                    NutritionGrid(nutrition: portionNutrition)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: savePortionSize) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(mode.buttonText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    if !isRequired {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding()
            .interactiveDismissDisabled(isRequired)  // Can't swipe down if required
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRequired {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var portionCount: Double {
        recipe.totalWeight / portionWeight
    }
    
    var ratio: Double {
        portionWeight / recipe.totalWeight
    }
    
    var portionNutrition: NutritionValues {
        recipe.totalNutrition * ratio
    }
    
    // MARK: - Actions
    
    func savePortionSize() {
        // Update recipe
        var updatedRecipe = recipe
        updatedRecipe.portionSize = portionWeight
        updatedRecipe.portionNutrition = portionNutrition
        
        // Save to database
        Task {
            await RecipeService.shared.updateRecipe(updatedRecipe)
        }
        
        dismiss()
    }
}

// Supporting view for nutrition display
struct NutritionGrid: View {
    let nutrition: NutritionValues
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            NutritionItem(
                label: "Calories",
                value: "\(Int(nutrition.calories))",
                unit: "kcal"
            )
            NutritionItem(
                label: "Protein",
                value: String(format: "%.1f", nutrition.protein),
                unit: "g"
            )
            NutritionItem(
                label: "Carbs",
                value: String(format: "%.1f", nutrition.carbohydrates),
                unit: "g"
            )
            NutritionItem(
                label: "Fat",
                value: String(format: "%.1f", nutrition.fat),
                unit: "g"
            )
            NutritionItem(
                label: "Fiber",
                value: String(format: "%.1f", nutrition.fiber),
                unit: "g"
            )
            NutritionItem(
                label: "GL",
                value: String(format: "%.0f", nutrition.glycemicLoad),
                unit: ""
            )
        }
    }
}

struct NutritionItem: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }
}
```

---

### Component 2: Recipe Detail View Updates

**Add to existing RecipeDetailView:**

```swift
struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var showPortionDefiner = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ... existing recipe content
                
                // Portion info section
                if recipe.isPortionDefined {
                    PortionInfoCard(recipe: recipe) {
                        showPortionDefiner = true
                    }
                } else {
                    // For manual recipes without defined portion
                    DefinePortionPrompt {
                        showPortionDefiner = true
                    }
                }
                
                // Nutrition section (only if portion defined)
                if let portionNutrition = recipe.portionNutrition {
                    NutritionCard(nutrition: portionNutrition)
                }
                
                // ... rest of recipe details
            }
        }
        .sheet(isPresented: $showPortionDefiner) {
            PortionDefinerModal(
                recipe: recipe,
                mode: recipe.isPortionDefined ? .adjust : .define,
                isRequired: !recipe.isPortionDefined
            )
        }
    }
}

struct PortionInfoCard: View {
    let recipe: Recipe
    let onAdjust: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Portion Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let portionSize = recipe.portionSize,
                       let portionCount = recipe.portionCount {
                        Text("\(Int(portionSize))g")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(portionCount, specifier: "%.1f") portions total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onAdjust) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Adjust")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct DefinePortionPrompt: View {
    let onDefine: () -> Void
    
    var body: some View {
        Button(action: onDefine) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Portion Not Defined")
                            .font(.headline)
                    }
                    Text("Define what one portion means to calculate nutrition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

---

## Calculation Logic

### 1. Client-Side Calculations (Swift)

**Per 100g Calculation:**
```swift
extension Recipe {
    mutating func calculatePer100g() {
        guard totalWeight > 0 else { return }
        
        let ratio = 100.0 / totalWeight
        per100g = totalNutrition * ratio
    }
}
```

**Portion Nutrition Calculation:**
```swift
extension Recipe {
    mutating func calculatePortionNutrition() {
        guard let portionSize = portionSize, totalWeight > 0 else {
            portionNutrition = nil
            return
        }
        
        let ratio = portionSize / totalWeight
        portionNutrition = totalNutrition * ratio
    }
    
    mutating func updatePortionSize(_ newSize: Double) {
        portionSize = newSize
        calculatePortionNutrition()
    }
}
```

**Validation:**
```swift
extension Recipe {
    func validateNutrition() -> [String] {
        var errors: [String] = []
        
        // Check that totals match portions
        if let portionNutrition = portionNutrition,
           let portionCount = portionCount {
            let reconstructedTotal = portionNutrition * portionCount
            
            let caloriesDiff = abs(reconstructedTotal.calories - totalNutrition.calories)
            if caloriesDiff > 1.0 {  // Allow 1 kcal rounding error
                errors.append("Calorie calculation mismatch: \(caloriesDiff) kcal")
            }
            
            let proteinDiff = abs(reconstructedTotal.protein - totalNutrition.protein)
            if proteinDiff > 0.1 {  // Allow 0.1g rounding error
                errors.append("Protein calculation mismatch: \(proteinDiff)g")
            }
            
            // Check other macros similarly...
        }
        
        // Check portion size is reasonable
        if let portionSize = portionSize {
            if portionSize < 50 {
                errors.append("Portion size too small: \(portionSize)g")
            }
            if portionSize > totalWeight {
                errors.append("Portion size exceeds total recipe weight")
            }
        }
        
        return errors
    }
}
```

---

### 2. Server-Side Calculations (TypeScript)

**Glycemic Load Calculation:**
```typescript
function calculateGlycemicLoad(
  carbs: number,
  fiber: number,
  primaryGrainType: string
): number {
  const netCarbs = carbs - fiber;
  
  // Estimate GI based on primary carb source
  let estimatedGI: number;
  if (primaryGrainType.includes('quinoa') || 
      primaryGrainType.includes('bulgur') ||
      primaryGrainType.includes('oats')) {
    estimatedGI = 52;  // Whole grains
  } else if (primaryGrainType.includes('lentil') || 
             primaryGrainType.includes('chickpea')) {
    estimatedGI = 35;  // Legumes
  } else if (primaryGrainType.includes('white rice') || 
             primaryGrainType.includes('bread')) {
    estimatedGI = 75;  // Refined grains
  } else {
    estimatedGI = 55;  // Default mixed meal
  }
  
  const GL = (netCarbs * estimatedGI) / 100;
  return Math.round(GL);
}
```

**Total vs Per-Portion Logic:**
```typescript
function formatNutritionResponse(
  totalRecipeWeight: number,
  totalNutrition: NutritionValues,
  servings: number | null,
  recipeType: "aiGenerated" | "manual"
): NutritionResponse | ManualRecipeNutritionResponse {
  
  if (recipeType === "manual" || servings === null) {
    // Manual recipe: return totals only
    return {
      totalRecipe: {
        weight: totalRecipeWeight,
        calories: totalNutrition.calories,
        carbohydrates: totalNutrition.carbohydrates,
        fiber: totalNutrition.fiber,
        sugar: totalNutrition.sugar,
        protein: totalNutrition.protein,
        fat: totalNutrition.fat,
        glycemicLoad: totalNutrition.glycemicLoad
      },
      nutritionCalculation: {
        // ... detailed breakdown
      }
    };
  } else {
    // AI-generated: return per100g and perPortion
    const per100g = {
      calories: (totalNutrition.calories / totalRecipeWeight) * 100,
      carbohydrates: (totalNutrition.carbohydrates / totalRecipeWeight) * 100,
      fiber: (totalNutrition.fiber / totalRecipeWeight) * 100,
      sugar: (totalNutrition.sugar / totalRecipeWeight) * 100,
      protein: (totalNutrition.protein / totalRecipeWeight) * 100,
      fat: (totalNutrition.fat / totalRecipeWeight) * 100
    };
    
    const perPortion = {
      weight: totalRecipeWeight / servings,
      calories: totalNutrition.calories / servings,
      carbohydrates: totalNutrition.carbohydrates / servings,
      fiber: totalNutrition.fiber / servings,
      sugar: totalNutrition.sugar / servings,
      protein: totalNutrition.protein / servings,
      fat: totalNutrition.fat / servings,
      glycemicLoad: totalNutrition.glycemicLoad / servings
    };
    
    return {
      ...per100g,
      glycemicLoad: perPortion.glycemicLoad,  // Per portion, not per 100g
      perPortion,
      nutritionCalculation: {
        totalRecipeWeight,
        totalRecipeCalories: totalNutrition.calories,
        // ... detailed breakdown
      }
    };
  }
}
```

---

## Edge Cases

### 1. Very Small Portions

**Scenario:** User sets portion to 30g (less than minimum 50g)

**Handling:**
```swift
// In PortionDefinerModal
Slider(
    value: $portionWeight,
    in: 50...recipe.totalWeight,  // Hard minimum of 50g
    step: 1
)

// Show warning if user tries to go too small
if portionWeight < 100 {
    Text("⚠️ Very small portion - consider if this is realistic")
        .font(.caption)
        .foregroundColor(.orange)
}
```

---

### 2. Portion Larger Than Total Recipe

**Scenario:** User slides beyond total recipe weight

**Handling:**
```swift
// Slider max is clamped to totalWeight
Slider(
    value: $portionWeight,
    in: 50...recipe.totalWeight,  // Can't exceed total
    step: 1
)

// This automatically means 1 portion or less
// portionCount will be ≤ 1.0, which is valid
```

---

### 3. Recipe Without Total Weight

**Scenario:** API fails to calculate cooked weight

**Handling:**
```swift
// In Recipe model
var isNutritionCalculated: Bool {
    totalWeight > 0 && totalNutrition.calories > 0
}

// In UI
if !recipe.isNutritionCalculated {
    Text("Nutrition calculation failed")
    Button("Retry Calculation") {
        retryNutritionCalculation()
    }
} else if !recipe.isPortionDefined {
    DefinePortionPrompt {
        showPortionDefiner = true
    }
}
```

---

### 4. Floating Point Precision

**Scenario:** Rounding errors in division/multiplication

**Handling:**
```swift
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// Use in calculations
portionNutrition.calories = (totalNutrition.calories * ratio).rounded(toPlaces: 1)
portionNutrition.protein = (totalNutrition.protein * ratio).rounded(toPlaces: 1)
// etc.
```

---

### 5. User Edits Recipe After Portion Defined

**Scenario:** User changes ingredients, portion size no longer makes sense

**Handling:**
```swift
// When recipe content is edited
func onRecipeContentChanged() {
    if recipe.isPortionDefined {
        showAlert(
            title: "Recalculate Nutrition?",
            message: "You've changed the recipe ingredients. Nutrition values should be recalculated.",
            primaryAction: {
                // Clear portion, force recalculation
                recipe.portionSize = nil
                recipe.portionNutrition = nil
                recalculateNutrition()
            },
            secondaryAction: {
                // Keep existing values (not recommended)
            }
        )
    }
}
```

---

### 6. Network Failure During Calculation

**Scenario:** API call fails mid-flow

**Handling:**
```swift
func calculateNutrition() async {
    do {
        isCalculating = true
        let response = try await nutritionService.calculateNutrition(request)
        processResponse(response)
    } catch {
        // Show error to user
        showError(
            title: "Calculation Failed",
            message: "Could not calculate nutrition. Please check your connection and try again.",
            retryAction: {
                Task { await calculateNutrition() }
            }
        )
    }
    isCalculating = false
}
```

---

### 7. Portion Defined But Nutrition Missing

**Scenario:** Database inconsistency (shouldn't happen but defensive)

**Handling:**
```swift
// In Recipe model
var isReadyForLogging: Bool {
    isNutritionCalculated && 
    isPortionDefined && 
    portionNutrition != nil
}

// In UI
if recipe.portionSize != nil && recipe.portionNutrition == nil {
    // Inconsistent state - recalculate
    recipe.calculatePortionNutrition()
}
```

---

## Testing Requirements

### Unit Tests

**Test File:** `RecipeNutritionCalculationsTests.swift`

```swift
import XCTest
@testable import balli

class RecipeNutritionCalculationsTests: XCTestCase {
    
    // MARK: - Portion Calculation Tests
    
    func testPortionNutritionCalculation() {
        // Given
        var recipe = createMockRecipe(
            totalWeight: 500,
            totalCalories: 1000,
            totalProtein: 50,
            totalCarbs: 100,
            totalFat: 30
        )
        
        // When
        recipe.portionSize = 250  // Half the recipe
        recipe.calculatePortionNutrition()
        
        // Then
        XCTAssertEqual(recipe.portionNutrition?.calories, 500, accuracy: 0.1)
        XCTAssertEqual(recipe.portionNutrition?.protein, 25, accuracy: 0.1)
        XCTAssertEqual(recipe.portionNutrition?.carbohydrates, 50, accuracy: 0.1)
        XCTAssertEqual(recipe.portionNutrition?.fat, 15, accuracy: 0.1)
    }
    
    func testPortionCount() {
        // Given
        let recipe = createMockRecipe(totalWeight: 750)
        
        // When
        recipe.portionSize = 250
        
        // Then
        XCTAssertEqual(recipe.portionCount, 3.0, accuracy: 0.01)
    }
    
    func testPer100gCalculation() {
        // Given
        var recipe = createMockRecipe(
            totalWeight: 500,
            totalCalories: 1000
        )
        
        // When
        recipe.calculatePer100g()
        
        // Then
        XCTAssertEqual(recipe.per100g.calories, 200, accuracy: 0.1)
    }
    
    // MARK: - Validation Tests
    
    func testNutritionValidation_Success() {
        // Given
        var recipe = createMockRecipe(totalWeight: 600, totalCalories: 1200)
        recipe.portionSize = 300
        recipe.calculatePortionNutrition()
        
        // When
        let errors = recipe.validateNutrition()
        
        // Then
        XCTAssertTrue(errors.isEmpty, "Should have no validation errors")
    }
    
    func testNutritionValidation_PortionTooSmall() {
        // Given
        var recipe = createMockRecipe(totalWeight: 500)
        recipe.portionSize = 30  // Too small
        
        // When
        let errors = recipe.validateNutrition()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("too small") })
    }
    
    func testNutritionValidation_PortionExceedsTotal() {
        // Given
        var recipe = createMockRecipe(totalWeight: 500)
        recipe.portionSize = 600  // Exceeds total
        
        // When
        let errors = recipe.validateNutrition()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("exceeds") })
    }
    
    // MARK: - Edge Cases
    
    func testVerySmallPortion() {
        // Given
        var recipe = createMockRecipe(totalWeight: 1000, totalCalories: 2000)
        
        // When
        recipe.portionSize = 50  // Minimum allowed
        recipe.calculatePortionNutrition()
        
        // Then
        XCTAssertEqual(recipe.portionNutrition?.calories, 100, accuracy: 0.1)
        XCTAssertEqual(recipe.portionCount, 20, accuracy: 0.1)
    }
    
    func testPortionEqualsTotal() {
        // Given
        var recipe = createMockRecipe(totalWeight: 400, totalCalories: 800)
        
        // When
        recipe.portionSize = 400  // Full recipe = 1 portion
        recipe.calculatePortionNutrition()
        
        // Then
        XCTAssertEqual(recipe.portionNutrition?.calories, 800, accuracy: 0.1)
        XCTAssertEqual(recipe.portionCount, 1.0, accuracy: 0.01)
    }
    
    func testFloatingPointPrecision() {
        // Given
        var recipe = createMockRecipe(totalWeight: 333, totalCalories: 999)
        
        // When
        recipe.portionSize = 111  // 1/3 of recipe
        recipe.calculatePortionNutrition()
        
        // Then - Allow for floating point imprecision
        XCTAssertEqual(recipe.portionNutrition?.calories, 333, accuracy: 1.0)
        XCTAssertEqual(recipe.portionCount, 3.0, accuracy: 0.01)
    }
    
    // MARK: - GL Division Test
    
    func testGlycemicLoadDivision() {
        // Given
        var recipe = createMockRecipe(totalWeight: 600)
        recipe.totalNutrition.glycemicLoad = 30
        
        // When
        recipe.portionSize = 200  // 1/3 of recipe
        recipe.calculatePortionNutrition()
        
        // Then
        XCTAssertEqual(recipe.portionNutrition?.glycemicLoad, 10, accuracy: 0.1)
    }
    
    // MARK: - Helper
    
    func createMockRecipe(
        totalWeight: Double,
        totalCalories: Double = 500,
        totalProtein: Double = 30,
        totalCarbs: Double = 50,
        totalFat: Double = 15
    ) -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Test Recipe",
            content: "Test content",
            createdAt: Date(),
            recipeType: .manual,
            totalWeight: totalWeight,
            totalNutrition: NutritionValues(
                calories: totalCalories,
                carbohydrates: totalCarbs,
                fiber: 5,
                sugar: 3,
                protein: totalProtein,
                fat: totalFat,
                glycemicLoad: 20
            ),
            per100g: NutritionValues(
                calories: 0, carbohydrates: 0, fiber: 0,
                sugar: 0, protein: 0, fat: 0, glycemicLoad: 0
            ),
            portionSize: nil,
            portionNutrition: nil
        )
    }
}
```

---

### Integration Tests

**Test File:** `PortionDefinerIntegrationTests.swift`

```swift
import XCTest
@testable import balli

class PortionDefinerIntegrationTests: XCTestCase {
    
    func testManualRecipeFullFlow() async throws {
        // 1. Create manual recipe
        let recipe = Recipe(
            id: UUID(),
            name: "Manual Recipe",
            content: "Test ingredients",
            createdAt: Date(),
            recipeType: .manual,
            totalWeight: 0,
            totalNutrition: NutritionValues(),
            per100g: NutritionValues(),
            portionSize: nil,
            portionNutrition: nil
        )
        
        // 2. Calculate nutrition
        let request = NutritionCalculationRequest(
            recipeName: recipe.name,
            recipeContent: recipe.content,
            servings: nil,
            recipeType: .manual
        )
        
        let response = try await nutritionService.calculateNutrition(request)
        
        // 3. Verify response structure
        XCTAssertNotNil(response.totalRecipe)
        XCTAssertGreaterThan(response.totalRecipe.weight, 0)
        XCTAssertGreaterThan(response.totalRecipe.calories, 0)
        
        // 4. Process response
        recipe.totalWeight = response.totalRecipe.weight
        recipe.totalNutrition = NutritionValues(/* from response */)
        recipe.calculatePer100g()
        
        // 5. Define portion
        recipe.portionSize = 250
        recipe.calculatePortionNutrition()
        
        // 6. Validate
        XCTAssertNotNil(recipe.portionNutrition)
        XCTAssertEqual(recipe.portionCount!, recipe.totalWeight / 250, accuracy: 0.01)
        
        // 7. Verify nutrition scales correctly
        let ratio = recipe.portionSize! / recipe.totalWeight
        XCTAssertEqual(
            recipe.portionNutrition!.calories,
            recipe.totalNutrition.calories * ratio,
            accuracy: 1.0
        )
    }
    
    func testAIGeneratedRecipeFlow() async throws {
        // 1. Generate recipe
        let generatedRecipe = try await aiService.generateRecipe("1 kişilik tavuklu yemek")
        
        // 2. Calculate nutrition (automatic)
        let request = NutritionCalculationRequest(
            recipeName: generatedRecipe.name,
            recipeContent: generatedRecipe.content,
            servings: 1,
            recipeType: .aiGenerated
        )
        
        let response = try await nutritionService.calculateNutrition(request)
        
        // 3. Verify portion is pre-calculated
        XCTAssertNotNil(response.perPortion)
        XCTAssertGreaterThan(response.perPortion.weight, 0)
        
        // 4. Verify user can adjust
        let recipe = Recipe(from: generatedRecipe, response: response)
        XCTAssertNotNil(recipe.portionSize)
        
        let originalPortionSize = recipe.portionSize!
        recipe.portionSize = originalPortionSize * 1.5
        recipe.calculatePortionNutrition()
        
        // 5. Verify nutrition scaled correctly
        XCTAssertEqual(
            recipe.portionNutrition!.calories,
            response.perPortion.calories * 1.5,
            accuracy: 1.0
        )
    }
}
```

---

### UI Tests

**Test File:** `PortionDefinerUITests.swift`

```swift
import XCTest

class PortionDefinerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testManualRecipePortionDefinition() throws {
        // 1. Create manual recipe
        app.buttons["New Recipe"].tap()
        app.buttons["Manual Entry"].tap()
        
        // 2. Enter recipe
        let nameField = app.textFields["Recipe Name"]
        nameField.tap()
        nameField.typeText("Test Recipe")
        
        let contentField = app.textViews["Recipe Content"]
        contentField.tap()
        contentField.typeText("100g chicken\n50g rice")
        
        app.buttons["Save"].tap()
        
        // 3. Calculate nutrition
        app.buttons["Calculate Nutrition"].tap()
        
        // Wait for API call
        let portionDefiner = app.sheets["Define Portion"]
        XCTAssertTrue(portionDefiner.waitForExistence(timeout: 5))
        
        // 4. Adjust slider
        let slider = portionDefiner.sliders.firstMatch
        XCTAssertTrue(slider.exists)
        
        // Drag slider to middle
        let startCoord = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let endCoord = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        startCoord.press(forDuration: 0.1, thenDragTo: endCoord)
        
        // 5. Save portion
        portionDefiner.buttons["Set Portion"].tap()
        
        // 6. Verify portion is displayed
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'portions'")).firstMatch.exists)
        
        // 7. Verify nutrition is displayed
        XCTAssertTrue(app.staticTexts["Calories"].exists)
        XCTAssertTrue(app.staticTexts["Protein"].exists)
    }
    
    func testAIGeneratedRecipePortionAdjustment() throws {
        // 1. Generate recipe
        app.buttons["New Recipe"].tap()
        app.buttons["AI Generate"].tap()
        
        let promptField = app.textFields["Recipe Prompt"]
        promptField.tap()
        promptField.typeText("tavuklu yemek")
        
        app.buttons["Generate"].tap()
        
        // Wait for generation and calculation
        XCTAssertTrue(app.staticTexts["Nutrition"].waitForExistence(timeout: 30))
        
        // 2. Tap adjust portion
        app.buttons["Adjust Portion"].tap()
        
        let portionDefiner = app.sheets["Adjust Portion"]
        XCTAssertTrue(portionDefiner.waitForExistence(timeout: 2))
        
        // 3. Change portion size
        let slider = portionDefiner.sliders.firstMatch
        let startCoord = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let endCoord = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        startCoord.press(forDuration: 0.1, thenDragTo: endCoord)
        
        // 4. Save changes
        portionDefiner.buttons["Update Portion"].tap()
        
        // 5. Verify nutrition updated
        // (exact values would need to be verified programmatically)
        XCTAssertTrue(app.staticTexts["Nutrition"].exists)
    }
    
    func testPortionDefinerCancel() throws {
        // ... navigate to recipe with portion defined
        
        app.buttons["Adjust Portion"].tap()
        
        let portionDefiner = app.sheets["Adjust Portion"]
        XCTAssertTrue(portionDefiner.waitForExistence(timeout: 2))
        
        // Move slider
        let slider = portionDefiner.sliders.firstMatch
        // ... drag slider
        
        // Cancel without saving
        portionDefiner.buttons["Cancel"].tap()
        
        // Verify values didn't change
        // (would need to store original values and compare)
    }
}
```

---

## Implementation Checklist

### Backend (Cloud Functions)

- [ ] Add `recipeType` field to request schema
- [ ] Add conditional logic for manual vs AI-generated recipes
- [ ] Implement `ManualRecipeNutritionResponse` format
- [ ] Update prompt to handle null servings
- [ ] Test API with both recipe types
- [ ] Verify GL calculation is correct for totals
- [ ] Add validation that rejects invalid requests

### iOS App - Data Layer

- [ ] Add `Recipe` model with new fields
- [ ] Add `NutritionValues` model with `scaled(by:)` method
- [ ] Add `RecipeType` enum
- [ ] Implement `calculatePer100g()` method
- [ ] Implement `calculatePortionNutrition()` method
- [ ] Implement `updatePortionSize()` method
- [ ] Add `validateNutrition()` method
- [ ] Update Core Data / database schema

### iOS App - UI Layer

- [ ] Create `PortionDefinerModal` component
- [ ] Create `NutritionGrid` component
- [ ] Create `PortionInfoCard` component
- [ ] Create `DefinePortionPrompt` component
- [ ] Update `RecipeDetailView` with portion UI
- [ ] Update manual recipe flow to trigger portion definer
- [ ] Add "Adjust Portion" button to generated recipes
- [ ] Handle required vs optional modal behavior
- [ ] Add slider with live preview
- [ ] Add portion count display

### iOS App - Business Logic

- [ ] Update `NutritionService` to handle both response types
- [ ] Add client-side per100g calculation for manual recipes
- [ ] Add portion save/update logic
- [ ] Add nutrition recalculation on portion change
- [ ] Handle API failures gracefully
- [ ] Add retry logic for network errors
- [ ] Implement validation checks

### Testing

- [ ] Write unit tests for portion calculations
- [ ] Write unit tests for validation
- [ ] Write unit tests for edge cases
- [ ] Write integration tests for full flows
- [ ] Write UI tests for manual recipe flow
- [ ] Write UI tests for AI-generated recipe flow
- [ ] Test with real recipes (verify accuracy)
- [ ] Test offline behavior
- [ ] Test concurrent portion adjustments

### Documentation

- [ ] Update API documentation
- [ ] Update user-facing help text
- [ ] Add tooltips/hints in UI
- [ ] Create internal developer guide
- [ ] Document calculation formulas
- [ ] Add troubleshooting guide

---

## Success Criteria

### Functional Requirements

✅ **Manual recipes:**
- User can create recipe without defining portion upfront
- Nutrition calculation returns total values only
- Portion definition is required before finalizing
- User can adjust portion later

✅ **AI-generated recipes:**
- Portion is pre-calculated for 1 serving
- User can view and use recipe immediately
- User can optionally adjust portion
- Nutrition recalculates on adjustment

✅ **Calculations:**
- All nutrition values scale correctly by ratio
- Glycemic load divides proportionally
- Per 100g values are accurate
- Validation catches errors

### Non-Functional Requirements

✅ **Performance:**
- Portion adjustment UI responds instantly (<16ms)
- API calls complete in <5 seconds
- No UI lag when dragging slider

✅ **Reliability:**
- Handles network failures gracefully
- Data consistency maintained (validation)
- No crashes on edge cases

✅ **Usability:**
- Flow is intuitive (user testing)
- Error messages are clear
- No unnecessary friction

---

## Migration Plan

### Phase 1: Backend (Week 1)

1. Update Cloud Function to accept `recipeType`
2. Implement conditional response logic
3. Test with Postman/curl
4. Deploy to staging
5. Verify both response formats work

### Phase 2: iOS Data Layer (Week 1-2)

1. Update `Recipe` model
2. Add calculation methods
3. Write unit tests
4. Verify calculations are accurate

### Phase 3: iOS UI (Week 2)

1. Build `PortionDefinerModal`
2. Integrate with manual recipe flow
3. Add to AI-generated recipe flow
4. Polish UI/UX

### Phase 4: Testing (Week 2-3)

1. Integration testing
2. UI testing
3. Manual QA with real recipes
4. Fix bugs

### Phase 5: Deployment (Week 3)

1. TestFlight beta
2. Monitor crash reports
3. Collect user feedback
4. Iterate

---

## Questions for Product Team

1. **Slider granularity:** Should portions be adjustable by 1g, 5g, or 10g increments?
2. **Portion history:** Should we save portion adjustment history for analysis?
3. **Sharing recipes:** If user shares recipe, do they share their custom portion size?
4. **Meal logging:** Can user log a partial portion (e.g., 0.5 portions)?
5. **Preset portions:** Should we offer "Small/Medium/Large" presets?
6. **GL thresholds:** Should we warn users if GL exceeds a threshold after portion adjustment?

---

## Appendix A: Example API Responses

### Manual Recipe Response

```json
{
  "totalRecipe": {
    "weight": 756,
    "calories": 1041,
    "carbohydrates": 77.6,
    "fiber": 11.2,
    "sugar": 11.9,
    "protein": 107.9,
    "fat": 32.5,
    "glycemicLoad": 37
  },
  "nutritionCalculation": {
    "totalRecipeWeight": 756,
    "totalRecipeCalories": 1041,
    "calculationNotes": "Calculated using USDA values for all ingredients. Cooking losses applied based on method and time.",
    "reasoningSteps": [
      {
        "ingredient": "Chicken breast",
        "recipeContext": "300g tavuk göğsü, sotele 5 dakika",
        "reasoning": "Protein, base retention 0.75, brief cooking +0.10, final retention 0.85",
        "calculation": "300g × 0.85 = 255g cooked",
        "confidence": "high"
      }
      // ... more steps
    ],
    "sanityCheckResults": {
      "erythritolCheck": { "status": "N/A", "message": "No erythritol in recipe" },
      "totalWeightCheck": { "status": "PASS", "message": "Cooked weight 756g is 79% of raw 957g" },
      "calorieRangeCheck": { "status": "PASS", "message": "137.7 kcal per 100g is within normal range" },
      "macroBalanceCheck": { "status": "PASS", "message": "Macros sum to reasonable values" },
      "crossValidationCheck": { "status": "PASS", "message": "Total matches sum of ingredients" },
      "fiberAnomalyCheck": { "status": "PASS", "message": "Fiber 11.2g is within expected range" }
    }
  }
}
```

### AI-Generated Recipe Response

```json
{
  "calories": 137.7,
  "carbohydrates": 13.2,
  "fiber": 3.5,
  "sugar": 1.8,
  "protein": 14.3,
  "fat": 4.3,
  "glycemicLoad": 18,
  "perPortion": {
    "weight": 342,
    "calories": 480,
    "carbohydrates": 70.4,
    "fiber": 12.1,
    "sugar": 5.4,
    "protein": 20.9,
    "fat": 15.2,
    "glycemicLoad": 23
  },
  "nutritionCalculation": {
    "totalRecipeWeight": 342,
    "totalRecipeCalories": 480,
    "calculationNotes": "Calculated for 1 serving. Lentils and bulgur provide complex carbs with moderate GL.",
    "reasoningSteps": [
      {
        "ingredient": "Red lentils",
        "recipeContext": "60g kırmızı mercimek (kuru), kaynat 15 dakika",
        "reasoning": "Dry grain, expands 3×, no retention applied to dry weight",
        "calculation": "60g dry × 3 = 180g cooked",
        "confidence": "high"
      }
      // ... more steps
    ],
    "sanityCheckResults": {
      // ... same structure
    }
  }
}
```

---

## Appendix B: Calculation Examples

### Example 1: Manual Recipe Portion Definition

**Input:**
- Recipe: "Tavuklu Sebze Sote"
- Total cooked weight: 756g
- Total calories: 1041 kcal
- User defines: 1 portion = 378g

**Calculation:**
```
Portion count = 756g / 378g = 2.0 portions
Ratio = 378g / 756g = 0.5
Per portion calories = 1041 × 0.5 = 520.5 kcal
Per portion protein = 107.9g × 0.5 = 53.95g
... (same for all macros)
```

**Result:**
- 1 portion = 378g
- 520.5 kcal, 53.95g protein, 38.8g carbs, 16.25g fat
- Makes 2.0 portions

---

### Example 2: AI-Generated Recipe Adjustment

**Input:**
- AI generated for 1 serving
- Total cooked weight: 342g
- Portion pre-set: 342g (full recipe)
- Total calories: 480 kcal
- User adjusts to: 1 portion = 171g (half)

**Calculation:**
```
New portion count = 342g / 171g = 2.0 portions
New ratio = 171g / 342g = 0.5
New per portion calories = 480 × 0.5 = 240 kcal
New per portion protein = 20.9g × 0.5 = 10.45g
... (same for all macros)
```

**Result:**
- 1 portion = 171g
- 240 kcal, 10.45g protein, 35.2g carbs, 7.6g fat
- Makes 2.0 portions

---

**End of Specification**

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-04 | AI Assistant | Initial comprehensive specification |

---

## Approval Sign-off

- [ ] Product Manager: _______________
- [ ] Backend Developer: _______________
- [ ] iOS Developer: _______________
- [ ] QA Lead: _______________

---

**This specification is ready for implementation. Please review and approve before beginning development.**