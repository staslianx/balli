# Insulin/Meal Absorption Chart System Documentation

This document explains the logic behind the insulin vs meal absorption timing charts in the Balli app.

## Chart System Architecture

The app has **two different chart implementations**:

### 1. AbsorptionTimingChart.swift (Simpler, uses Swift Charts)

- **File:** `balli/Features/RecipeManagement/Views/Components/AbsorptionTimingChart.swift`
- **Used in:** `NutritionalValuesView` (the nutrition modal)
- **Framework:** Swift Charts API
- **Curves:**
  - **Insulin:** NovoRapid curve (orange) - hardcoded data points
  - **Meal:** Dynamic curve (purple) calculated from macros

### 2. DualCurveChartView.swift (More advanced, uses Canvas)

- **File:** `balli/Features/RecipeManagement/Views/Components/DualCurveChartView.swift`
- **Framework:** Custom Canvas rendering with Catmull-Rom spline interpolation
- **Curves:**
  - **Insulin:** NovoRapid curve (orange) from `InsulinCurveData`
  - **Glucose:** Dynamic curve (purple) from `InsulinCurveCalculator`

---

## Key Logic Components

### A. Insulin Curve (Fixed - NovoRapid)

**Source:** `AbsorptionTimingChart.swift:170-188`

Hardcoded NovoRapid pharmacokinetics based on clinical data:

```swift
// Clinical Profile
- Onset: 15 min (0.25h)
- Peak: 1.0 hour (60 minutes)
- Duration: 6 hours
- Profile: Rapid rise → sharp peak → gradual decline

// Data points: [(time_hours, intensity_0_to_1)]
(0.0, 0.0)   // Injection
(0.25, 0.35) // Rapid onset (15 min)
(0.5, 0.65)  // Rising
(1.0, 1.0)   // PEAK at 1 hour
(1.5, 0.85)  // Just past peak
(2.0, 0.60)  // Declining
(2.5, 0.40)
(3.0, 0.25)  // Tail
(3.5, 0.15)
(4.0, 0.08)
(4.5, 0.04)
(5.0, 0.02)
(6.0, 0.0)   // End of action
```

---

### B. Meal Curve (Dynamic - Calculated from Macros)

**Source:** `AbsorptionTimingChart.swift:196-248`

#### Peak Time Calculation

```swift
basePeakTime = 1.0 hour  // Starting point

// Fat delays peak
fatRatio = fat / max(carbs, 1.0)
fatDelay = fatRatio × 1.5 hours
// Example: 30g fat / 50g carbs = 0.6 ratio → 0.9h delay

// Protein delays peak
proteinRatio = protein / max(carbs, 1.0)
proteinDelay = proteinRatio × 0.5 hours
// Example: 25g protein / 50g carbs = 0.5 ratio → 0.25h delay

peakTime = basePeakTime + fatDelay + proteinDelay
peakTime = min(peakTime, 4.0)  // Capped at 4 hours maximum
```

#### Duration Calculation

```swift
baseDuration = 3.0 hours

// Fat extends duration
duration = baseDuration + (fatRatio × 2.0)
duration = min(duration, 6.0)  // Capped at 6 hours
duration = max(duration, peakTime + 1.0)  // Must be at least 1h past peak
```

#### Curve Shape Generation

Uses trigonometric functions for smooth, physiologically realistic curves:

```swift
// Generate 25 points (every 0.25h from 0 to 6 hours)
for t in 0.0...6.0 (step 0.25):
    if t <= peakTime {
        // Rising phase: sine curve (0° to 90°)
        progress = t / peakTime
        intensity = sin(progress × π/2)

    } else if t <= duration {
        // Falling phase: cosine curve (0° to 90°)
        progress = (t - peakTime) / (duration - peakTime)
        intensity = cos(progress × π/2)

    } else {
        // Tail phase: exponential decay
        tailProgress = t - duration
        intensity = max(0.0, 0.1 × e^(-0.8 × tailProgress))
    }
```

**Rationale:** Sine/cosine curves provide smooth acceleration/deceleration, mimicking natural biological absorption patterns.

---

### C. InsulinCurveCalculator (Medical/Scientific Approach)

**Source:** `balli/Core/Services/InsulinCurveCalculator.swift`

This is the more sophisticated medical algorithm used in the dual curve system.

#### Peak Time Formula

**Source:** `InsulinCurveCalculator.swift:33-90`

```swift
// 1. Base peak time from sugar content (carb type)
sugarRatio = sugar / carbohydrates

if sugarRatio > 0.7 (>70% sugar):
    basePeakTime = 60 min   // Fast absorption
else if sugarRatio > 0.4 (40-70% sugar):
    basePeakTime = 90 min   // Medium absorption
else (<40% sugar):
    basePeakTime = 120 min  // Complex carbs, slow absorption

// 2. Fat delay (stepped thresholds)
if fat < 10g:  fatDelay = 0 min
if fat < 20g:  fatDelay = 30 min
if fat < 30g:  fatDelay = 60 min
if fat < 40g:  fatDelay = 90 min
if fat >= 40g: fatDelay = 120 min

// 3. Protein delay (stepped thresholds)
if protein < 15g: proteinDelay = 0 min
if protein < 25g: proteinDelay = 15 min
if protein < 35g: proteinDelay = 30 min
if protein >= 35g: proteinDelay = 45 min

// 4. Fiber delay (stepped thresholds)
if fiber > 10g: fiberDelay = 20 min
if fiber > 5g:  fiberDelay = 10 min
else:           fiberDelay = 0 min

// Final calculation
totalPeakTime = basePeakTime + fatDelay + proteinDelay + fiberDelay
totalPeakTime = clamp(totalPeakTime, 45, 300)  // 45 min to 5 hours
```

#### Duration Calculation

**Source:** `InsulinCurveCalculator.swift:99-126`

```swift
// 1. Base duration from glycemic load
if glycemicLoad < 10:  baseDuration = 180 min  // Low GL: 3 hours
if glycemicLoad < 20:  baseDuration = 240 min  // Medium GL: 4 hours
else:                  baseDuration = 300 min  // High GL: 5 hours

// 2. Fat extension (prolonged gastric emptying)
if fat < 10g:  fatExtension = 0 min
if fat < 20g:  fatExtension = 60 min   // +1 hour
if fat < 30g:  fatExtension = 120 min  // +2 hours
else:          fatExtension = 180 min  // +3 hours

// 3. Physiological constraint
minDuration = peakTime × 1.5  // Duration must be at least 1.5× peak time

// Final calculation
duration = max(baseDuration + fatExtension, minDuration)
```

#### Peak Height Calculation

**Source:** `InsulinCurveCalculator.swift:133-160`

```swift
// 1. Base height from glycemic load
if glycemicLoad < 10:  baseHeight = 0.5   // Low impact
if glycemicLoad < 20:  baseHeight = 0.75  // Medium impact
else:                  baseHeight = 1.0   // High impact

// 2. Sugar multiplier (rapid absorption increases peak)
sugarRatio = sugar / carbohydrates
sugarMultiplier = 1.0 + (sugarRatio × 0.3)  // Up to +30% for pure sugar

// 3. Fiber reduction (slower absorption reduces peak)
if fiber > 10g: fiberReduction = 0.85  // -15% for high fiber
if fiber > 5g:  fiberReduction = 0.92  // -8% for moderate fiber
else:           fiberReduction = 1.0   // No reduction

// Final calculation
finalHeight = baseHeight × sugarMultiplier × fiberReduction
finalHeight = min(finalHeight, 1.0)  // Capped at 1.0 (100%)
```

#### Glucose Curve Generation

**Source:** `InsulinCurveCalculator.swift:167-187`

```swift
// Calculate parameters
peakTime = calculateGlucosePeakTime(nutrition)
duration = calculateGlucoseDuration(nutrition, peakTime)
peakHeight = calculateGlucosePeakHeight(nutrition)
onset = max(30, peakTime × 0.3)  // Onset is 30% of peak time, min 30 min

// Generate 9-point curve with realistic absorption profile
points = [
    (0,                                     0.0),              // Start (meal consumed)
    (onset,                                 peakHeight × 0.2), // Onset (digestion begins)
    (onset × 1.5,                           peakHeight × 0.4), // Rising
    (peakTime × 0.7,                        peakHeight × 0.7), // Near peak
    (peakTime,                              peakHeight),       // PEAK (maximum glucose)
    (peakTime + (duration - peakTime) × 0.3, peakHeight × 0.85), // Plateau
    (peakTime + (duration - peakTime) × 0.6, peakHeight × 0.6),  // Declining
    (duration × 0.9,                        peakHeight × 0.3), // Tail
    (duration,                              0.0)               // End (complete absorption)
]
```

---

## Comparison: Two Systems Side-by-Side

| Aspect | AbsorptionTimingChart | InsulinCurveCalculator |
|--------|----------------------|------------------------|
| **Complexity** | Simpler, continuous ratio-based | Medical, stepped thresholds |
| **Fat handling** | Continuous ratio (linear) | Stepped (10g increments) |
| **Sugar consideration** | Not directly used | Primary factor for base peak time |
| **Fiber handling** | Not considered | Adds delay (+10-20 min) |
| **Peak height** | Fixed at 1.0 | Variable (0.5-1.0) based on GL |
| **Curve points** | 25 points (smooth) | 9 points (key milestones) |
| **Rendering** | Swift Charts (declarative) | Canvas (custom drawing) |
| **Medical basis** | General physiological principles | Clinical thresholds and research |

---

## Example Calculation

**Recipe:** 50g carbs, 30g fat, 25g protein, 8g fiber, 12g sugar, GL=18

### Using AbsorptionTimingChart

```
fatRatio = 30 / 50 = 0.6
proteinRatio = 25 / 50 = 0.5

peakTime = 1.0 + (0.6 × 1.5) + (0.5 × 0.5)
         = 1.0 + 0.9 + 0.25
         = 2.15 hours

duration = 3.0 + (0.6 × 2.0)
         = 3.0 + 1.2
         = 4.2 hours

Result: Peak at 2.15h, duration 4.2h, fixed height 1.0
```

### Using InsulinCurveCalculator

```
// Sugar ratio
sugarRatio = 12 / 50 = 0.24 (24% sugar, <40%)
basePeakTime = 120 min (complex carbs)

// Fat delay
fat = 30g → 60 min delay (20-30g bracket)

// Protein delay
protein = 25g → 15 min delay (15-25g bracket)

// Fiber delay
fiber = 8g → 10 min delay (5-10g bracket)

// Total peak time
totalPeakTime = 120 + 60 + 15 + 10 = 205 min (3.42 hours)

// Duration
glycemicLoad = 18 → baseDuration = 240 min (GL 10-20)
fat = 30g → fatExtension = 120 min
duration = 240 + 120 = 360 min (6 hours)

// Peak height
glycemicLoad = 18 → baseHeight = 0.75
sugarMultiplier = 1.0 + (0.24 × 0.3) = 1.072
fiberReduction = 0.92 (5-10g fiber)
peakHeight = 0.75 × 1.072 × 0.92 = 0.74

Result: Peak at 3.42h, duration 6h, height 0.74
```

### Comparison

| Metric | AbsorptionTimingChart | InsulinCurveCalculator | Difference |
|--------|----------------------|------------------------|------------|
| **Peak Time** | 2.15 hours | 3.42 hours | +1.27 hours |
| **Duration** | 4.2 hours | 6.0 hours | +1.8 hours |
| **Peak Height** | 1.0 | 0.74 | -26% |

**Analysis:** The InsulinCurveCalculator predicts a later peak, longer duration, and lower peak intensity due to:
- Using sugar ratio to determine base peak (complex carbs = slower)
- More conservative fat impact (stepped thresholds)
- Adding fiber delay factor
- Incorporating glycemic load for duration and height

---

## Mismatch Calculation and Warnings

**Source:** `InsulinCurveCalculator.swift:196-215`

```swift
// Insulin peak (NovoRapid): 75 minutes
// Glucose peak: calculated from recipe

mismatch = abs(glucosePeakTime - 75)

// Warning levels (from CurveWarningLevel)
if mismatch < 30 min:      .low      // Good alignment
if mismatch < 60 min:      .medium   // Some mismatch
if mismatch < 120 min:     .high     // Significant mismatch
if mismatch >= 120 min:    .danger   // Critical mismatch

// Additional factors can escalate warning:
- High fat (>25g) AND high mismatch → escalate
- High glycemic load (>20) → consider impact
```

---

## Visual Chart Features

### Peak Difference Indicator

**Source:** `AbsorptionTimingChart.swift:48-63`

```swift
// Only shown if meaningful difference (>0.5 hours)
if peakDifferenceHours > 0.5 {
    // Draw dashed vertical line at meal peak
    // Annotation shows time difference in hours
    RuleMark(x: mealPeakTime)
        .annotation: "X.X saat fark"
}
```

### Canvas Rendering (DualCurveChartView)

**Source:** `DualCurveChartView.swift:150-206`

Uses Catmull-Rom spline interpolation for smooth curves:

```swift
// Catmull-Rom control point calculation
tension = 0.5  // Standard Catmull-Rom tension

For each segment (p1 → p2):
    p0 = previous point (or p1 if first)
    p3 = next point (or p2 if last)

    cp1 = p1 + (p2 - p0) / (6.0 / tension)
    cp2 = p2 - (p3 - p1) / (6.0 / tension)

    Draw cubic Bézier curve from p1 to p2 using cp1, cp2
```

**Result:** Smooth, professional curves without visible angles or discontinuities.

---

## Clinical References

### NovoRapid (Insulin Aspart) Pharmacokinetics

- **Onset:** 10-15 minutes
- **Peak:** 1-1.5 hours (75 minutes used in app)
- **Duration:** 3-5 hours (6 hours used to capture tail)
- **Source:** NovoNordisk clinical documentation

### Gastric Emptying Factors

| Factor | Effect | Mechanism |
|--------|--------|-----------|
| **High Fat** | Delays emptying | Stimulates CCK hormone, slows gastric motility |
| **High Protein** | Moderate delay | Requires more digestion time, some gluconeogenesis |
| **High Fiber** | Slows absorption | Forms gel in gut, reduces contact with intestinal wall |
| **Simple Sugars** | Rapid absorption | No digestion needed, direct glucose entry |

### Glycemic Load Impact

- **Low GL (<10):** Gradual glucose rise, shorter duration
- **Medium GL (10-20):** Moderate glucose rise, standard duration
- **High GL (>20):** Sharp glucose rise, extended duration

---

## Edge Cases Handled

**Source:** `InsulinCurveCalculator.swift:222-240`

### 1. Very Low Carb (<5g)

```swift
isVeryLowCarb(carbsGrams: Double) -> Bool
// Potential hypoglycemia risk if taking insulin
// Should show special warning
```

### 2. Extreme Mismatch (>4 hours)

```swift
isExtremeMismatch(mismatchMinutes: Int) -> Bool
// mismatchMinutes > 240 (4 hours)
// Requires split-wave bolus or different insulin strategy
```

### 3. High Protein + Low Carb

```swift
isHighProteinLowCarb(proteinGrams, carbsGrams) -> Bool
// protein > 30g AND carbs < 20g
// Gluconeogenesis may cause delayed glucose rise
// 50-60% of protein converts to glucose over 3-4 hours
```

---

## Files Overview

| File | Purpose | Lines of Code |
|------|---------|---------------|
| `AbsorptionTimingChart.swift` | Swift Charts-based meal curve visualization | 361 |
| `DualCurveChartView.swift` | Canvas-based high-performance dual curve | 275 |
| `InsulinCurveCalculator.swift` | Medical algorithm for glucose curve calculation | 242 |
| `InsulinCurveData.swift` | Static NovoRapid insulin curve data | ~50 |
| `CurveWarningLevel.swift` | Warning level determination logic | ~100 |
| `AbsorptionTimingModels.swift` | Data models (TimePoint, AbsorptionProfile) | ~50 |

---

## Future Improvement Opportunities

### 1. Personalization

- User-specific insulin sensitivity factor (ISF)
- Personal fat tolerance (some people respond more to fat)
- Historical meal data to refine predictions

### 2. Additional Factors

- **Meal temperature:** Hot meals digest faster than cold
- **Time of day:** Dawn phenomenon affects morning glucose
- **Exercise:** Pre/post-exercise meals absorb differently
- **Stress/illness:** Cortisol affects glucose absorption

### 3. Multiple Insulin Types

- Fiasp (ultra-rapid): Peak at 45-60 min
- Regular insulin: Peak at 2-3 hours
- Mixed regimens: Dual insulin curves

### 4. Algorithm Refinement

- Use continuous glucose monitor (CGM) data to validate predictions
- Machine learning to refine delay factors per user
- Real-time adjustment based on current glucose trend

### 5. Unified System

Currently maintaining two separate systems creates technical debt:
- Consider deprecating `AbsorptionTimingChart`
- Use `InsulinCurveCalculator` everywhere for consistency
- Or vice versa if simpler model proves more accurate in practice

---

## Testing

**Test file:** `balliTests/InsulinCurveCalculatorTests.swift`

Key test scenarios:
- Low-fat meal (expect early peak ~60-90 min)
- High-fat meal (expect late peak ~180-240 min)
- High-protein low-carb (expect delayed gluconeogenesis)
- Pure sugar meal (expect very early peak ~45-60 min)
- Extreme cases (validate clamping and edge case handling)

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2025-11-07 | Initial documentation | Claude Code |

---

**End of Documentation**
