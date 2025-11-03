# AI Diagnostics Integration Guide

## Overview
This guide shows where to integrate `AIDiagnosticsLogger` across all AI features in the app.

## ✅ Completed
- Created `AIDiagnosticsLogger.swift` in `/balli/Core/Diagnostics/`
- Created `AIDiagnosticsView.swift` in `/balli/Features/Settings/Views/`
- Added AI Diagnostics to Settings → Tanı section
- Integrated with Firebase Crashlytics for error tracking
- Build verified: **SUCCESS** (only 5 expected Sendable warnings)

## 📋 Integration Points

### 1. Leaven Analysis / Camera Scanning

**Files to modify:**
- `/balli/Features/CameraScanning/Services/CaptureFlowManager.swift`
- `/balli/Features/CameraScanning/Services/CaptureImageProcessor.swift`
- `/balli/Features/CameraScanning/ViewModels/AIResultViewModel.swift`

**Logging points:**
```swift
// At the top of each file
import AIDiagnosticsLogger

// In CaptureFlowManager.confirmAndProcess():
let operationId = UUID().uuidString
await AIDiagnosticsLogger.shared.logLeavenAnalysis(
    "Starting leaven analysis",
    operationId: operationId,
    metadata: ["imageSize": "\(image.size)"],
    level: .info
)

// When analysis starts:
await AIDiagnosticsLogger.shared.logImageProcessing(
    "Processing captured image for nutrition extraction",
    operationId: operationId,
    level: .info
)

// When Gemini API is called:
await AIDiagnosticsLogger.shared.logGeminiAPI(
    "Calling Gemini Vision API for nutrition analysis",
    operationId: operationId,
    metadata: ["model": "gemini-2.5-flash"],
    level: .info
)

// On success:
await AIDiagnosticsLogger.shared.logLeavenAnalysis(
    "Leaven analysis completed successfully",
    operationId: operationId,
    metadata: [
        "calories": "\(result.calories)",
        "carbs": "\(result.carbohydrates)",
        "confidence": "\(result.confidence)"
    ],
    level: .success
)

// On error:
await AIDiagnosticsLogger.shared.logLeavenAnalysis(
    "Leaven analysis failed: \(error.localizedDescription)",
    operationId: operationId,
    level: .error
)

// Performance tracking:
let startTime = Date()
// ... perform operation ...
let duration = Date().timeIntervalSince(startTime)
await AIDiagnosticsLogger.shared.logPerformance(
    "Leaven analysis completed in \(String(format: "%.2f", duration))s",
    operationId: operationId,
    metadata: ["duration_ms": "\(Int(duration * 1000))"]
)
```

### 2. Nutrition Calculation

**Files to modify:**
- `/balli/Features/CameraScanning/Services/CaptureImageProcessor.swift` (nutrition extraction)
- `/balli/Features/FoodEntry/Views/VoiceInputView.swift` (voice-based nutrition)

**Logging points:**
```swift
// When nutrition calculation starts:
let operationId = UUID().uuidString
await AIDiagnosticsLogger.shared.logNutritionCalculation(
    "Starting nutrition calculation",
    operationId: operationId,
    metadata: ["source": "camera|voice"],
    level: .info
)

// When parsing nutrition values:
await AIDiagnosticsLogger.shared.logNutritionCalculation(
    "Parsing nutrition values from AI response",
    operationId: operationId,
    level: .debug
)

// On validation:
await AIDiagnosticsLogger.shared.logNutritionCalculation(
    "Validating nutrition values",
    operationId: operationId,
    metadata: [
        "calories": "\(calories)",
        "carbs": "\(carbs)",
        "protein": "\(protein)"
    ],
    level: .info
)

// On success:
await AIDiagnosticsLogger.shared.logNutritionCalculation(
    "Nutrition calculation completed",
    operationId: operationId,
    metadata: ["netCarbs": "\(netCarbs)"],
    level: .success
)

// On error:
await AIDiagnosticsLogger.shared.logNutritionCalculation(
    "Nutrition calculation failed: \(error)",
    operationId: operationId,
    level: .error
)
```

### 3. Recipe Generation

**Files to modify:**
- `/balli/Features/RecipeManagement/ViewModels/RecipeViewModel.swift`

**Logging points:**
```swift
// At recipe generation start:
let operationId = UUID().uuidString
await AIDiagnosticsLogger.shared.logRecipeGeneration(
    "Starting recipe generation",
    operationId: operationId,
    metadata: [
        "hasIngredients": "\(!ingredients.isEmpty)",
        "ingredientCount": "\(ingredients.count)"
    ],
    level: .info
)

// When calling Cloud Function:
await AIDiagnosticsLogger.shared.logGeminiAPI(
    "Calling Cloud Function for recipe generation",
    operationId: operationId,
    metadata: ["function": "generateRecipe"],
    level: .info
)

// During streaming:
await AIDiagnosticsLogger.shared.logStreaming(
    "Receiving recipe chunk: \(chunk.count) bytes",
    operationId: operationId,
    level: .debug
)

// On recipe parsed:
await AIDiagnosticsLogger.shared.logRecipeGeneration(
    "Recipe parsed successfully",
    operationId: operationId,
    metadata: [
        "title": recipe.title,
        "servings": "\(recipe.servings)",
        "ingredients": "\(recipe.ingredients.count)"
    ],
    level: .success
)

// On error:
await AIDiagnosticsLogger.shared.logRecipeGeneration(
    "Recipe generation failed: \(error.localizedDescription)",
    operationId: operationId,
    level: .error
)

// Performance:
await AIDiagnosticsLogger.shared.logPerformance(
    "Recipe generation took \(duration)s",
    operationId: operationId,
    metadata: ["totalTokens": "\(tokenCount)"]
)
```

### 4. Research View

**Files to modify:**
- `/balli/Features/Research/ViewModels/MedicalResearchViewModel.swift`

**Logging points:**
```swift
// At search start:
let operationId = UUID().uuidString
await AIDiagnosticsLogger.shared.logResearch(
    "Starting medical research query",
    operationId: operationId,
    metadata: ["query": query],
    level: .info
)

// When calling Cloud Function:
await AIDiagnosticsLogger.shared.logGeminiAPI(
    "Calling Cloud Function for research",
    operationId: operationId,
    metadata: ["function": "medicalResearch"],
    level: .info
)

// During streaming:
await AIDiagnosticsLogger.shared.logStreaming(
    "Research SSE event received: \(event.type)",
    operationId: operationId,
    metadata: ["stage": event.stage],
    level: .debug
)

// On search sources:
await AIDiagnosticsLogger.shared.logResearch(
    "Searching sources: \(sources.joined(separator: ", "))",
    operationId: operationId,
    level: .info
)

// On completion:
await AIDiagnosticsLogger.shared.logResearch(
    "Research query completed",
    operationId: operationId,
    metadata: [
        "citationCount": "\(citations.count)",
        "stageCount": "\(stages.count)"
    ],
    level: .success
)

// On error:
await AIDiagnosticsLogger.shared.logResearch(
    "Research query failed: \(error.localizedDescription)",
    operationId: operationId,
    level: .error
)

// Image processing (if multimodal):
if hasImages {
    await AIDiagnosticsLogger.shared.logImageProcessing(
        "Processing \(imageCount) images for research",
        operationId: operationId,
        level: .info
    )
}
```

## 🔑 Key Integration Patterns

### 1. Operation ID Pattern
Always create a UUID at the start of an operation and pass it through:
```swift
let operationId = UUID().uuidString
// Use this ID in all related log calls
```

### 2. Error Handling Pattern
Wrap AI operations in do-catch and log appropriately:
```swift
do {
    let result = try await performAIOperation()
    await AIDiagnosticsLogger.shared.logCategory("Success", operationId: operationId, level: .success)
} catch {
    await AIDiagnosticsLogger.shared.logCategory(
        "Failed: \(error.localizedDescription)",
        operationId: operationId,
        level: .error
    )
    // Crashlytics already notified via logger
}
```

### 3. Performance Tracking Pattern
```swift
let startTime = Date()
// ... operation ...
let duration = Date().timeIntervalSince(startTime)
await AIDiagnosticsLogger.shared.logPerformance(
    "Operation took \(String(format: "%.2f", duration))s",
    operationId: operationId,
    metadata: ["duration_ms": "\(Int(duration * 1000))"]
)
```

### 4. Metadata Pattern
Always include relevant context:
```swift
metadata: [
    "key1": "value1",
    "key2": "\(numericValue)",
    "status": status.rawValue
]
```

## 🧪 Testing the Integration

1. **Leaven Analysis Test:**
   - Take a photo of food packaging
   - Go to Settings → Tanı → AI İşlemleri Tanılama
   - Verify logs show: imageProcessing, geminiAPI, leavenAnalysis events
   - Check for operationId consistency
   - Export JSON and verify structure

2. **Nutrition Calculation Test:**
   - Use voice input to log a meal
   - Check diagnostics for nutritionCalculation events
   - Verify confidence scores in metadata

3. **Recipe Generation Test:**
   - Generate a recipe
   - Check for recipeGeneration, streaming, geminiAPI events
   - Verify token counts and performance metrics

4. **Research Test:**
   - Perform a medical research query
   - Check for research, streaming, imageProcessing (if images) events
   - Verify SSE stage transitions are logged

5. **Error Scenarios:**
   - Test with network disconnected
   - Test with invalid input
   - Verify errors appear in diagnostics
   - Confirm Crashlytics receives errors

## 📊 Expected Log Volume

With proper integration, you should see:
- **Leaven analysis:** 5-10 log entries per scan
- **Nutrition calculation:** 3-5 entries per calculation
- **Recipe generation:** 10-20 entries per recipe (due to streaming)
- **Research:** 15-30 entries per query (multiple stages)

Total: ~10,000 entries capacity = ~300-500 AI operations retained

## ⚠️ Important Notes

1. **Performance:** Logger is an actor - all calls are async
2. **Privacy:** Don't log sensitive user data in plain text
3. **Crashlytics:** Errors automatically sent, breadcrumbs for all events
4. **Console.app:** All logs also go to system logger for debugging
5. **Export:** Both JSON and text formats supported for troubleshooting

## 🚀 Next Steps

1. Add logging to each file listed above
2. Test each AI feature
3. Verify logs appear in AIDiagnosticsView
4. Export and share logs for troubleshooting
5. Monitor Crashlytics dashboard for AI errors

---

**Status:** Infrastructure complete, awaiting integration into AI ViewModels and Services.
