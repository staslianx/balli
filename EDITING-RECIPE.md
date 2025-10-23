# Recipe Detail View: Inline Editing Feature

## Overview

Add inline editing capability to the existing recipe detail view. The editing mode should be **visually identical** to the read-only view, with text fields replacing static text in place.

## Critical Requirements

### Visual Consistency

**MOST IMPORTANT:** The editing mode must look EXACTLY like the current view except that text becomes editable.

- Same fonts (size, weight, family)
- Same text colors
- Same spacing and padding
- Same layout structure
- Same background colors
- NO visual difference until user taps on a text field

### What Changes

Only these elements change when entering edit mode:

1. Static `Text` views → Editable `TextField` or `TextEditor` views
1. Navigation bar: Back button → İptal (top-left), Ellipsis menu → Kaydet (top-right)
1. That’s it. Nothing else.

## Implementation Approach

### State Management

Add a single boolean state variable:

```swift
@State private var isEditing: Bool = false
```

### Toggle Edit Mode

When user taps “Düzenle” from the ellipsis menu:

- Set `isEditing = true`
- UI automatically switches Text views to TextField/TextEditor views
- Navigation bar buttons update

### DO NOT Reconstruct the View

**Critical:** Do NOT create a separate editing view or rebuild the UI from scratch.

Instead:

- Use conditional rendering within the EXISTING view
- Example: `if isEditing { TextField(...) } else { Text(...) }`
- Keep all styling in BOTH branches identical

## Editable Elements

### 1. Recipe Title

**Current:** “Narlı Güllaç Kasesi” as static Text with white color, large font

**Edit Mode:**

- Becomes TextField
- Pre-populated with current title
- Same font: `.largeTitle` or whatever size is currently used
- Same color: white
- Same weight: bold
- NO border, NO background difference
- Placeholder: empty (not needed since pre-populated)

### 2. Ingredients List (Malzemeler)

**Current:** Bulleted list of ingredient items

**Edit Mode:**

- Each ingredient becomes an editable TextField
- Pre-populated with current ingredient text
- Same font size and color as current
- Same bullet point indicator (•) before each field
- Ability to:
  - Edit existing ingredients
  - Add new ingredient (+ button or automatic new line)
  - Delete ingredient (swipe to delete or - button)
- Keep the “Malzemeler” header as static Text (not editable)

### 3. Directions/Instructions (if present in view)

**Current:** Text paragraphs or numbered steps

**Edit Mode:**

- Becomes TextEditor (for multi-line text)
- Pre-populated with current directions
- Same font size and color
- Same line spacing
- NO visible border or background

### 4. Balli’nin Notu Section

**Edit Mode:**

- The note text becomes editable TextEditor
- Pre-populated with current note
- Same font and styling

## UI Changes

### Top Navigation Bar

**Read-Only Mode:**

```
[< Back]                    [...(ellipsis menu)]
```

**Edit Mode:**

```
[İptal]                     [Kaydet]
```

- İptal: Top-left, replaces back button
- Kaydet: Top-right, replaces ellipsis menu
- Same styling as navigation bar items
- Standard iOS navigation bar button styling

### Bottom Action Buttons

**Both Modes:**

```
[Kaydet] [Değerler] [Alışveriş]
```

**These buttons remain unchanged and stay visible in both read-only and edit modes.**

- In edit mode, these buttons may be disabled or hidden (implementation choice)
- OR they remain functional if that makes sense for your app

### TextField/TextEditor Styling

**Critical Styling Requirements:**

```swift
TextField("", text: $recipeTitle)
    .font(.system(size: 32, weight: .bold)) // Match exact current size
    .foregroundColor(.white) // Match current color
    .background(Color.clear) // NO visible background
    .textFieldStyle(.plain) // Remove default TextField styling
    .multilineTextAlignment(.leading) // Match current alignment
```

For TextEditor (multi-line):

```swift
TextEditor(text: $recipeNote)
    .font(.system(size: 16)) // Match exact current size
    .foregroundColor(.primary) // Match current color
    .background(Color.clear)
    .scrollContentBackground(.hidden) // iOS 16+ to hide default background
    .frame(minHeight: 100) // Appropriate height
```

## User Flow

### Entering Edit Mode

1. User taps three-dot ellipsis button (top right)
1. Menu appears with options
1. User taps “Düzenle”
1. `isEditing` becomes `true`
1. Text fields appear in place (visually identical until tapped)
1. Navigation bar updates: back button → İptal, ellipsis → Kaydet
1. Bottom buttons (Kaydet, Değerler, Alışveriş) remain visible

### Editing Content

1. User taps on recipe title → cursor appears, can edit
1. User taps on ingredient → cursor appears, can edit
1. User can add new ingredients
1. User can delete ingredients
1. User can edit note section

### Saving Changes

1. User taps “Kaydet”
1. Validate changes (optional: check for empty fields)
1. Update the recipe data model
1. Set `isEditing = false`
1. Return to read-only view

### Canceling Changes

1. User taps “İptal”
1. Discard all changes
1. Restore original values
1. Set `isEditing = false`
1. Return to read-only view

## Data Handling

### State Variables for Edit Mode

```swift
@State private var isEditing = false
@State private var editedTitle: String = ""
@State private var editedIngredients: [String] = []
@State private var editedNote: String = ""
```

### Initialize Edit State

When entering edit mode:

```swift
func startEditing() {
    editedTitle = recipe.title
    editedIngredients = recipe.ingredients
    editedNote = recipe.note
    isEditing = true
}
```

### Save Changes

```swift
func saveChanges() {
    recipe.title = editedTitle
    recipe.ingredients = editedIngredients
    recipe.note = editedNote
    isEditing = false
    // Persist to storage
}
```

### Cancel Changes

```swift
func cancelEditing() {
    isEditing = false
    // editedTitle, editedIngredients, editedNote are discarded
}
```

## Common Mistakes to Avoid

### ❌ DON’T DO THIS:

- Create a separate EditRecipeView
- Rebuild the entire UI in edit mode
- Use different fonts or colors in edit mode
- Add visible borders or backgrounds to TextFields by default
- Change the layout or spacing in edit mode
- Show an empty state or placeholder-only fields

### ✅ DO THIS:

- Toggle between Text and TextField in the same view structure
- Copy ALL styling from Text to TextField exactly
- Pre-populate all fields with current values
- Keep layout identical in both modes
- Only visual difference: cursor appears when field is tapped

## Testing Checklist

### Visual Verification

- [ ] Edit mode looks identical to read-only mode at first glance
- [ ] Font sizes match exactly
- [ ] Colors match exactly
- [ ] Spacing and padding match exactly
- [ ] No visible borders or backgrounds on TextFields
- [ ] Title is pre-populated with current value
- [ ] All ingredients are pre-populated
- [ ] Note section is pre-populated

### Functionality Verification

- [ ] Can edit title
- [ ] Can edit each ingredient
- [ ] Can add new ingredients
- [ ] Can delete ingredients
- [ ] Can edit note section
- [ ] Top “Kaydet” button saves changes
- [ ] Top “İptal” button discards changes
- [ ] Back button is hidden in edit mode
- [ ] Ellipsis menu is hidden in edit mode
- [ ] Bottom buttons (Kaydet, Değerler, Alışveriş) remain visible in edit mode
- [ ] Changes persist after saving
- [ ] Changes are discarded after canceling

## Example Code Structure

```swift
struct RecipeDetailView: View {
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedIngredients: [String] = []

    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Image (always read-only)
                recipeImage

                // Title - switches between Text and TextField
                if isEditing {
                    TextField("", text: $editedTitle)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                } else {
                    Text(recipe.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                // Note section
                noteSection

                // Ingredients
                ingredientsSection

                // Bottom buttons (always visible)
                HStack {
                    Button("Kaydet") { }
                    Button("Değerler") { }
                    Button("Alışveriş") { }
                }
            }
        }
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            // Leading (left) button
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("İptal") { cancelEditing() }
                }
            }

            // Trailing (right) button
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Kaydet") { saveChanges() }
                } else {
                    Menu {
                        Button("Düzenle") { startEditing() }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }

    func startEditing() {
        editedTitle = recipe.title
        editedIngredients = recipe.ingredients
        isEditing = true
    }

    func saveChanges() {
        // Save logic
        isEditing = false
    }

    func cancelEditing() {
        isEditing = false
    }
}
```

## Summary

The key to this feature is **visual consistency**. The user should not notice any difference between read-only and edit mode until they tap on a field and see the cursor. This is achieved by:

1. Using the same view structure for both modes
1. Copying all styling from Text to TextField exactly
1. Pre-populating all fields with current values
1. Using `.plain` textFieldStyle and `.clear` backgrounds
1. Only changing the navigation bar buttons (İptal and Kaydet replace back button and ellipsis)

This creates a seamless inline editing experience that feels natural and professional.
