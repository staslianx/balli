# Feature Flow Verification Prompt

## Your Task
You are an expert iOS app auditor. Please thoroughly trace and verify the implementation of two core features in this diabetes management app. For each feature, check if all components, flows, and interactions are properly implemented and working as specified.

## Feature 1: Recipe Generation Flow

### Main Entry Point
- [ ] **Recipe button exists on main screen** - Verify the button is present and functional
- [ ] **Button tap navigation** - Confirm tapping opens the recipe generation view

### Recipe Generation View
- [ ] **Blank recipe paper UI** - Check if view displays with appropriate placeholder values and instructional text
- [ ] **Logo button placement** - Verify logo button exists in top-right corner
- [ ] **Logo button functionality** - Confirm tapping shows meal categories modal sheet

### Meal Category Selection
- [ ] **Modal sheet presentation** - Verify categories modal displays correctly
- [ ] **Category selection** - Check if users can select meal categories
- [ ] **Subcategory handling** - If categories have subcategories, verify they display and are selectable
- [ ] **AI generation trigger** - Confirm selection starts AI recipe generation

### Generation Process
- [ ] **Logo spinning animation** - Verify logo (not button) spins during generation
- [ ] **Animation timing** - Check spinning starts when generation begins
- [ ] **Animation stop** - Verify spinning stops when recipe generation completes
- [ ] **Recipe display** - Confirm generated recipe appears in the view

### Image Generation
- [ ] **Image generation button** - Verify button exists and is functional
- [ ] **AI image generation** - Check if tapping generates recipe photo
- [ ] **Image display** - Confirm generated image displays properly

### Recipe Saving
- [ ] **Save button location** - Verify "Save the recipe" button exists (user needs to scroll down)
- [ ] **Save functionality** - Confirm tapping saves recipe to food library
- [ ] **Navigation to library** - Check if save action properly adds to food library

## Feature 2: AI Label Scanning Flow

### Main Entry Point
- [ ] **Scanning button exists** - Verify button is present on main screen (next to recipe button)
- [ ] **Camera launch** - Confirm tapping opens camera interface

### Camera Interface
- [ ] **Camera zoom setting** - Verify camera opens at 0.5x zoom for macro capability
- [ ] **Photo capture** - Check if users can take photos of labels
- [ ] **Preview display** - Verify photo preview shows after capture

### Photo Processing
- [ ] **Check mark button** - Confirm check mark button exists at bottom of preview
- [ ] **AI analysis trigger** - Verify tapping check mark sends photo to AI for analysis
- [ ] **Progress indicator** - Check if progress section displays during analysis
- [ ] **Results display** - Verify extracted values appear on the label image

### Label Results View
- [ ] **Impact score display** - Verify impact score appears in top-right of label
- [ ] **Edit button placement** - Confirm edit button exists at bottom
- [ ] **Value editing** - Check if tapping edit makes AI-extracted values editable
- [ ] **Save functionality** - Verify users can save edited values

### Product Saving
- [ ] **Save to library** - Confirm saved products go to food library
- [ ] **Library integration** - Verify products appear in food library

## Feature 3: Food Library Integration

### Library Structure
- [ ] **Segmented control** - Verify segmented tabs exist for "Recipes" and "Products"
- [ ] **Tab switching** - Check if users can switch between recipe and product views

### Recipe Cards in Library
- [ ] **Card design** - Verify recipes display as round rectangle cards
- [ ] **Card layout** - Check recipe photo on right, text content on left
- [ ] **Card information** - Verify displays: recipe name, serving size, carb amount
- [ ] **Card tap action** - Confirm tapping opens recipe in modal sheet
- [ ] **Edit button in modal** - Verify edit button exists in top-right of modal
- [ ] **Edit functionality** - Check if users can modify AI-generated values
- [ ] **Save changes** - Verify edited values persist when saved/closed

### Product Cards in Library
- [ ] **Card design** - Verify products display as rounded squares
- [ ] **Card information** - Check displays: product name, brand, serving size, carb value
- [ ] **Card tap action** - Confirm tapping opens label screen
- [ ] **Edit functionality** - Verify edit button allows value modification
- [ ] **Save changes** - Check if edited values persist

## Feature 4: Serving Size Adjustment System

### Recipe Serving Adjustment
- [ ] **Edit button access** - Verify edit button exists in recipe view
- [ ] **Slider appearance** - Check if slider appears at bottom of nutritional values section
- [ ] **Proportional updates** - Verify moving slider updates all nutritional values proportionally
- [ ] **Value persistence** - Confirm adjusted values persist in app

### Product Serving Adjustment
- [ ] **Edit button access** - Verify edit button exists in product/label view
- [ ] **Slider functionality** - Check slider adjusts serving size and updates values proportionally
- [ ] **Impact score update** - Verify impact score changes with serving size adjustments
- [ ] **Value persistence** - Confirm changes persist between app launches

## Data Persistence Verification

### Cross-Launch Persistence
- [ ] **Recipe edits persist** - Verify recipe modifications survive app restarts
- [ ] **Product edits persist** - Check product/label changes survive app restarts
- [ ] **Card updates** - Confirm front-face card information reflects latest edits
- [ ] **Serving adjustments persist** - Verify serving size changes are maintained

### Library Consistency
- [ ] **Recipe card accuracy** - Check recipe cards show current name, serving size, carb amount
- [ ] **Product card accuracy** - Verify product cards display current name, brand, serving size, carb value
- [ ] **Cross-feature consistency** - Confirm values match between detail views and library cards

## Testing Instructions

1. **Test each feature independently** first, then test interactions between features
2. **Force quit and relaunch** the app between major testing phases to verify persistence
3. **Test edge cases**: empty states, network failures, very long/short content
4. **Verify UI responsiveness** during AI generation and processing states
5. **Check accessibility** features and VoiceOver compatibility where applicable

## Reporting Format

For each checklist item, report:
- ✅ **Working as expected** - Brief confirmation
- ⚠️ **Partial implementation** - What works, what doesn't
- ❌ **Not working/missing** - Clear description of issue
- 🔍 **Needs investigation** - Unclear behavior that requires further testing

## Priority Issues

Focus special attention on these critical flows:
1. **Data persistence across app launches**
2. **Proper navigation between features and food library**
3. **Serving size slider proportional calculations**
4. **AI generation states and user feedback**
5. **Edit/save cycles in both recipes and products**

Please trace through each feature methodically and provide a comprehensive report on the current implementation status.
