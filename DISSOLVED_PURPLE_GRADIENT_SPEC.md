# Dissolved Purple Gradient Specification

## Overview
Diagonal gradient (top-left to bottom-right) with adaptive opacity for light/dark modes.

## Light Mode (Better Visibility)
**Maximum Opacity: 25%** at corners, **8%** at center for full coverage

| Stop | Location | Opacity | Purpose |
|------|----------|---------|---------|
| 1 | 0.0 | 25% | Top-left corner - strongest purple |
| 2 | 0.15 | 18% | Fade towards center |
| 3 | 0.25 | 12% | More fade |
| 4 | 0.50 | 8% | Center - lower opacity (not clear) |
| 5 | 0.75 | 12% | Start intensifying |
| 6 | 0.85 | 18% | More intense |
| 7 | 1.0 | 25% | Bottom-right corner - strongest purple |

**Color:** `AppTheme.primaryPurple` (#67619E)
**Effect:** Creates full purple coverage with stronger corners for better card definition in light backgrounds

## Dark Mode (Subtle Glass)
**Maximum Opacity: 12%** at corners, **3%** at center for full coverage

| Stop | Location | Opacity | Purpose |
|------|----------|---------|---------|
| 1 | 0.0 | 12% | Top-left corner - dissolved purple |
| 2 | 0.15 | 8% | Fade towards center |
| 3 | 0.25 | 5% | More fade |
| 4 | 0.50 | 3% | Center - lower opacity (not clear) |
| 5 | 0.75 | 5% | Start reappearing |
| 6 | 0.85 | 8% | More visible |
| 7 | 1.0 | 12% | Bottom-right corner - dissolved purple |

**Color:** `AppTheme.primaryPurple` (#67619E)
**Effect:** Maintains full purple coverage with subtle corners for Liquid Glass aesthetic in dark UI

## Usage

```swift
// Automatically adapts to color scheme
.dissolvedPurpleGlass(cornerRadius: 32)
```

## Applied To
- `RecipeCardView.swift` - Recipe/meal cards in Ardiye
- `ProductCardView.swift` - Product/food item cards

## Visual Effect
- **Full Coverage:** Purple tint across entire card with intensity variation
- **Corner Emphasis:** Stronger purple at diagonal corners for definition
- **Center Subtlety:** Lower opacity at center maintains focus on content
- **Smooth Transition:** 7 stops create buttery-smooth gradient
- **Native Glass:** Uses iOS 26 `.glassEffect()` underneath
