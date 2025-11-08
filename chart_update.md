

I need to add a third curve to our insulin/meal absorption visualization system to show insulin effectiveness (insulin sensitivity/resistance) based on meal fat content.

## Context

Currently we have two curves:

1. **Orange curve**: NovoRapid insulin activity (fixed)
1. **Purple curve**: Glucose absorption from meal (calculated from macros)

We need to add:
3. **Red dashed curve**: Insulin effectiveness percentage (how well the body responds to insulin)

## Requirements

### New Function in `InsulinCurveCalculator.swift`

Add a function that calculates insulin effectiveness based on fat content:

```swift
func calculateInsulinEffectiveness(nutrition: NutritionalValues) -> [TimePoint]
```

**Logic:**

- Fat causes insulin resistance (reduces effectiveness)
- Base effectiveness: 100% (1.0)
- Fat thresholds:
  - <10g fat: 100% effectiveness, 0 hours resistance
  - 10-20g fat: 85% effectiveness, 4 hours resistance duration
  - 20-30g fat: 70% effectiveness, 6 hours resistance duration
  - ≥30g fat: 60% effectiveness, 8 hours resistance duration

**Curve shape:**

- Start at 100% (minute 0)
- Drop to reduced effectiveness over 30 minutes (as fat starts being digested)
- Stay at reduced level for the resistance duration
- Return to 100% at the end

Return an array of `TimePoint` objects representing this curve.

### Update `DualCurveChartView.swift`

Add the insulin effectiveness curve as a third dataset:

- **Color**: Red (#e74c3c or similar)
- **Style**: Dashed line (borderDash)
- **Y-axis**: Right Y-axis showing percentage (50% to 100%)
- **Label**: “İnsülin Etkinliği (%)” or “Insulin Effectiveness (%)”

The curve should be calculated from the recipe’s nutritional values and rendered alongside the existing insulin and glucose curves.

### Update `AbsorptionTimingChart.swift` (optional, if feasible with Swift Charts)

If possible with Swift Charts framework, add the same insulin effectiveness curve here as well. If it’s too complex due to dual Y-axis limitations, we can skip this and only add to `DualCurveChartView`.

## Medical Rationale

Fat in meals causes insulin resistance through:

1. Slower gastric emptying (already modeled in glucose curve)
1. **Reduced insulin sensitivity** (NEW - this is what we’re adding)

This is why high-fat meals require more total insulin, not just different timing. The visualization will help users understand that a 30g fat meal means their insulin only works at 70% effectiveness for 6 hours.

## Files to Modify

1. `balli/Core/Services/InsulinCurveCalculator.swift` - Add new calculation function
1. `balli/Features/RecipeManagement/Views/Components/DualCurveChartView.swift` - Add third curve rendering
1. (Optional) `balli/Features/RecipeManagement/Views/Components/AbsorptionTimingChart.swift` - Add if feasible

## Testing

After implementation, test with these scenarios:

- Low-fat meal (5g fat): Should show flat line at 100%
- Medium-fat meal (25g fat): Should show drop to 70% for 6 hours
- High-fat meal (40g fat): Should show drop to 60% for 8 hours

The curve should be clearly distinguishable from the other two curves (different color, dashed style, right Y-axis with % scale).

-----

**Additional note to include:**

“This addition was discussed as part of improving visualizations for understanding why timing insulin correctly isn’t always enough when meals contain significant fat. The insulin effectiveness curve explains the ‘double problem’ of high-fat meals: delayed glucose absorption AND reduced insulin response.”

-----

