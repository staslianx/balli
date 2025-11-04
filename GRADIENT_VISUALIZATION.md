# Dissolved Purple Gradient Visualization

## Light Mode (25% corners → 8% center)

```
┌─────────────────────────────────────┐
│ 25%                                 │  ← Top-left: Strongest purple
│   18%                               │
│     12%                             │
│        8% (lower opacity)           │  ← Center region (not clear)
│                            12%      │
│                          18%        │
│                       25%           │  ← Bottom-right: Strongest purple
└─────────────────────────────────────┘
       Diagonal gradient flow
```

**Visual Effect in Light Mode:**
```
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪🟪
```
*(Darker purple at corners, lighter in center)*

## Dark Mode (12% corners → 3% center)

```
┌─────────────────────────────────────┐
│ 12%                                 │  ← Top-left: Dissolved purple
│   8%                                │
│     5%                              │
│        3% (lower opacity)           │  ← Center region (not clear)
│                             5%      │
│                           8%        │
│                        12%          │  ← Bottom-right: Dissolved purple
└─────────────────────────────────────┘
       Diagonal gradient flow
```

**Visual Effect in Dark Mode:**
```
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣🟣
```
*(Darker purple at corners, lighter in center)*

## Comparison Table

| Aspect | Light Mode | Dark Mode |
|--------|------------|-----------|
| **Corner Opacity** | 25% | 12% |
| **Center Opacity** | 8% (lower, not clear) | 3% (lower, not clear) |
| **Coverage** | Full purple tint across card | Full purple tint across card |
| **Visual Impact** | Strong corners for visibility | Subtle corners for glass aesthetic |
| **Purpose** | Stand out against light backgrounds | Blend with dark UI naturally |

## Real-World Example

### Recipe Card in Light Mode
```
┌────────────────────────────────────┐
│ 🟪🟪 Mercimek Çorbası           🟪 │ ← Stronger purple at corners
│ 🟪                              🟪 │
│ 🟪 200 gr                       🟪 │ ← Lighter purple throughout
│ 🟪 18.5 gr Karb.       [Photo]  🟪 │
│ 🟪                           🟪🟪 │ ← Stronger purple at corners
└────────────────────────────────────┘
```

### Recipe Card in Dark Mode
```
┌────────────────────────────────────┐
│ 🟣🟣 Mercimek Çorbası           🟣 │ ← Subtle purple at corners
│ 🟣                              🟣 │
│ 🟣 200 gr                       🟣 │ ← Very light purple throughout
│ 🟣 18.5 gr Karb.       [Photo]  🟣 │
│ 🟣                           🟣🟣 │ ← Subtle purple at corners
└────────────────────────────────────┘
```

## Key Design Decisions

1. **Light Mode (25% corners → 8% center):**
   - Full purple coverage for cohesive brand identity
   - Stronger corners create definition against light backgrounds
   - Lower center opacity keeps focus on content
   - 8% center maintains purple presence without overwhelming

2. **Dark Mode (12% corners → 3% center):**
   - Full purple coverage maintains consistency
   - Subtle corners preserve Liquid Glass aesthetic
   - Very light center (3%) prevents dark UI from feeling heavy
   - Glass effect naturally more visible in dark mode

3. **Full Coverage Philosophy:**
   - Entire card has purple tint for brand consistency
   - No clear/transparent areas - always some purple present
   - Gradient intensity creates visual interest
   - Center remains readable with lower (not zero) opacity

4. **Smooth Transition:**
   - 7 gradient stops (not just 3)
   - Creates professional, polished look
   - No harsh color bands
   - Diagonal flow adds dynamism
