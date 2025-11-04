# Absorption Timing Chart - Technical Specification

## Overview
Create an interactive chart visualizing the timing mismatch between insulin action (Novorapid) and meal absorption based on macronutrient composition. The chart updates dynamically based on nutritional values.

---

## Component Specification

### Component Name
`AbsorptionTimingChart.swift`

### Visual Design Requirements

**Chart Style:**
- Clean, minimalist line chart
- Transparent background (adapts to system background)
- No decorative elements, icons, warning symbols, or cognitive load indicators
- Subtle grid lines
- Two smooth curves with optional dashed difference line

**Color Specifications:**
- **Orange line**: Novorapid insulin absorption
  - Use: `Color.orange` (standard system orange)
  - Line width: 3pt
- **Purple line**: Meal absorption
  - Use: App's custom purple color (Claude Code knows this)
  - Line width: 3pt
- **Dashed line**: Peak timing difference (optional, only shown if difference > 0.5 hours)
  - Use: `Color.gray.opacity(0.5)`
  - Style: Dashed stroke [5, 5]
  - Line width: 2pt

**Layout:**
- Full width of container
- Height: 220pt
- Padding: 16pt
- Corner radius: 12pt
- Background: System background color

**Typography:**
- Title: `.headline`, secondary color
- Axis labels: `.caption`
- Time difference label: `.caption`, secondary color, with background pill

---

## Data Model

```swift
struct AbsorptionProfile {
    let insulinCurve: [TimePoint]
    let mealCurve: [TimePoint]
    let peakDifferenceHours: Double
    let insulinPeakTime: Double
    let mealPeakTime: Double
}

struct TimePoint: Identifiable {
    let id = UUID()
    let timeHours: Double     // 0.0 to 6.0 hours
    let intensity: Double     // 0.0 to 1.0 (normalized)
}
```

---

## Curve Generation Logic

### 1. Insulin Curve (Novorapid - Fixed Pharmacokinetics)

```swift
func generateInsulinCurve() -> [TimePoint] {
    // Novorapid pharmacokinetics (clinically established):
    // - Onset: 10-15 min (0.17-0.25h)
    // - Peak: 1-1.5 hours
    // - Duration: 3-5 hours
    // - Action profile: Rapid rise, sharp peak, gradual decline
    
    let dataPoints: [(time: Double, intensity: Double)] = [
        (0.0, 0.0),      // Injection time
        (0.25, 0.35),    // Rapid onset (15 min)
        (0.5, 0.65),     // Rising
        (1.0, 1.0),      // Peak at 1h
        (1.5, 0.85),     // Just past peak
        (2.0, 0.60),     // Declining
        (2.5, 0.40),     
        (3.0, 0.25),     // Tail
        (3.5, 0.15),
        (4.0, 0.08),
        (4.5, 0.04),
        (5.0, 0.02),
        (6.0, 0.0)       // End of action
    ]
    
    return dataPoints.map { TimePoint(timeHours: $0.time, intensity: $0.intensity) }
}
```

### 2. Meal Curve (Dynamic - Based on Macronutrients)

```swift
func generateMealCurve(fat: Double, protein: Double, carbs: Double) -> [TimePoint] {
    // Calculate macronutrient ratios
    let safeDivisor = max(carbs, 1.0)  // Prevent division by zero
    let fatRatio = fat / safeDivisor
    let proteinRatio = protein / safeDivisor
    
    // Calculate peak timing
    // Base peak for low-fat meal: 1.0 hour
    // Fat delays peak: Each 1.0 fat ratio adds ~1.5h delay
    // Protein delays peak: Each 1.0 protein ratio adds ~0.5h delay
    let basePeakTime = 1.0
    let fatDelay = fatRatio * 1.5
    let proteinDelay = proteinRatio * 0.5
    var peakTime = basePeakTime + fatDelay + proteinDelay
    peakTime = min(peakTime, 4.0)  // Cap at 4 hours
    
    // Calculate absorption duration
    // Base duration: 3 hours
    // Fat extends duration: Each 1.0 fat ratio adds 2h
    let baseDuration = 3.0
    var duration = baseDuration + (fatRatio * 2.0)
    duration = min(duration, 6.0)  // Cap at 6 hours
    duration = max(duration, peakTime + 1.0)  // Must be at least 1h past peak
    
    // Generate smooth curve
    var points: [TimePoint] = []
    
    // Create 25 points for smooth curve (every 0.25h)
    for i in 0...24 {
        let t = Double(i) * 0.25  // 0.0, 0.25, 0.5, ... 6.0
        let intensity: Double
        
        if t <= peakTime {
            // Rising phase: Use sine curve for smooth rise
            // Progress from 0 to π/2 (0° to 90°)
            let progress = t / peakTime
            intensity = sin(progress * .pi / 2)
        } else if t <= duration {
            // Falling phase: Use cosine curve for smooth decline
            // Progress from 0 to π/2 (0° to 90°)
            let progress = (t - peakTime) / (duration - peakTime)
            intensity = cos(progress * .pi / 2)
        } else {
            // Tail phase: Exponential decay
            let tailProgress = t - duration
            intensity = max(0.0, 0.1 * exp(-tailProgress * 0.8))
        }
        
        points.append(TimePoint(timeHours: t, intensity: intensity))
    }
    
    return points
}
```

### 3. Peak Difference Calculation

```swift
func calculatePeakDifference(
    insulinCurve: [TimePoint],
    mealCurve: [TimePoint]
) -> (timeDifference: Double, insulinPeakTime: Double, mealPeakTime: Double) {
    
    // Find peak points
    guard let insulinPeak = insulinCurve.max(by: { $0.intensity < $1.intensity }),
          let mealPeak = mealCurve.max(by: { $0.intensity < $1.intensity }) else {
        return (0, 0, 0)
    }
    
    let timeDifference = abs(mealPeak.timeHours - insulinPeak.timeHours)
    
    return (
        timeDifference: timeDifference,
        insulinPeakTime: insulinPeak.timeHours,
        mealPeakTime: mealPeak.timeHours
    )
}
```

---

## SwiftUI Implementation

```swift
import SwiftUI
import Charts

struct AbsorptionTimingChart: View {
    let nutritionData: NutritionCalculationResult
    
    @State private var absorptionProfile: AbsorptionProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text("Emilim Zamanlaması")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let profile = absorptionProfile {
                // Main chart
                Chart {
                    // Insulin curve (orange)
                    ForEach(profile.insulinCurve) { point in
                        LineMark(
                            x: .value("Saat", point.timeHours),
                            y: .value("Yoğunluk", point.intensity)
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)  // Smooth curves
                    }
                    
                    // Meal curve (custom purple)
                    ForEach(profile.mealCurve) { point in
                        LineMark(
                            x: .value("Saat", point.timeHours),
                            y: .value("Yoğunluk", point.intensity)
                        )
                        .foregroundStyle(CustomColors.purple)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)  // Smooth curves
                    }
                    
                    // Peak difference line (only show if meaningful difference)
                    if profile.peakDifferenceHours > 0.5 {
                        // Vertical dashed line at the difference point
                        RuleMark(x: .value("Fark", profile.mealPeakTime))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .annotation(position: .top, alignment: .center, spacing: 4) {
                                Text(String(format: "%.1f saat fark", profile.peakDifferenceHours))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .systemBackground).opacity(0.9))
                                    .cornerRadius(6)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, 1, 2, 3, 4, 5, 6]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Double.self) {
                                Text("\(Int(hour))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text("\(Int(val * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...1.1)
                .chartXScale(domain: 0...6)
                .frame(height: 220)
                
                // Legend
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Text("İnsülin (Novorapid)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(CustomColors.purple)
                            .frame(width: 10, height: 10)
                        Text("Yemek Emilimi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            } else {
                // Loading state
                ProgressView()
                    .frame(height: 220)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .onAppear {
            calculateAbsorptionProfile()
        }
        .onChange(of: nutritionData.totalRecipe.fat) { _ in
            calculateAbsorptionProfile()
        }
        .onChange(of: nutritionData.totalRecipe.protein) { _ in
            calculateAbsorptionProfile()
        }
        .onChange(of: nutritionData.totalRecipe.carbohydrates) { _ in
            calculateAbsorptionProfile()
        }
    }
    
    private func calculateAbsorptionProfile() {
        let insulinCurve = generateInsulinCurve()
        let mealCurve = generateMealCurve(
            fat: nutritionData.totalRecipe.fat,
            protein: nutritionData.totalRecipe.protein,
            carbs: nutritionData.totalRecipe.carbohydrates
        )
        
        let peaks = calculatePeakDifference(
            insulinCurve: insulinCurve,
            mealCurve: mealCurve
        )
        
        absorptionProfile = AbsorptionProfile(
            insulinCurve: insulinCurve,
            mealCurve: mealCurve,
            peakDifferenceHours: peaks.timeDifference,
            insulinPeakTime: peaks.insulinPeakTime,
            mealPeakTime: peaks.mealPeakTime
        )
    }
}
```

---

## Integration Guide

### Where to Add the Chart

Add the chart component to nutrition values modal sheet, ina way that is collapsed first, and expands when user taps: 

```swift
struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var nutritionData: NutritionCalculationResult?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Recipe header
                RecipeHeaderView(recipe: recipe)
                
                // Nutritional summary
                if let nutrition = nutritionData {
                    NutritionSummaryCard(data: nutrition)
                    
                    // Absorption timing chart (NEW)
                    AbsorptionTimingChart(nutritionData: nutrition)
                        .padding(.horizontal)
                }
                
                // Ingredients, instructions, etc.
                RecipeIngredientsView(recipe: recipe)
                RecipeInstructionsView(recipe: recipe)
            }
        }
        .navigationTitle(recipe.name)
        .task {
            await loadNutritionData()
        }
    }
}
```

---

## Chart Behavior Examples

### Example 1: Low-Fat Meal (Curves Aligned)
**Input:**
- Carbs: 50g
- Protein: 25g
- Fat: 15g

**Result:**
- Meal peak: ~1.3 hours
- Insulin peak: 1.0 hours
- Difference: 0.3 hours
- **No dashed line shown** (difference < 0.5h)

### Example 2: Moderate-Fat Meal
**Input:**
- Carbs: 45g
- Protein: 30g
- Fat: 25g

**Result:**
- Meal peak: ~2.2 hours
- Insulin peak: 1.0 hours
- Difference: 1.2 hours
- **Dashed line shown** with "1.2 saat fark" label

### Example 3: High-Fat Meal (Dana Sote)
**Input:**
- Carbs: 48g
- Protein: 49g
- Fat: 42g

**Result:**
- Meal peak: ~3.0 hours
- Insulin peak: 1.0 hours
- Difference: 2.0 hours
- **Dashed line shown** with "2.0 saat fark" label

---

## Technical Notes

### Performance Considerations
- Curve generation is computational, cache the `AbsorptionProfile` in `@State`
- Only recalculate when macronutrient values change (use `onChange` modifiers)
- 25 data points per curve provides smooth visualization without performance issues

### Accessibility
- Chart is automatically accessible through SwiftUI Charts framework
- VoiceOver will read axis labels and data points
- Consider adding `.accessibilityLabel()` to describe the chart's meaning

### Testing
Test with these edge cases:
1. **Zero fat**: Should show curves almost aligned
2. **Very high fat (>50g)**: Peak difference should cap at reasonable value
3. **Zero carbs**: Handle gracefully (keto meals)
4. **All macros zero**: Show empty state or default curves

---

## Visual Polish Suggestions

1. **Animation**: Add `.animation(.easeInOut, value: absorptionProfile)` to animate curve changes
2. **Interactive tooltip**: Consider adding tap gesture to show exact values at any time point
3. **Time markers**: Add subtle vertical lines at 1h, 2h, 3h for easier reading
4. **Gradient fill**: Optionally fill area under curves with subtle gradient

---

## Future Enhancements (Not Required Now)

- Personal calibration: Adjust curves based on CGM data
- Multiple insulin types: Support for different insulin action profiles
- Meal history comparison: Overlay previous similar meals
- Export: Share chart as image