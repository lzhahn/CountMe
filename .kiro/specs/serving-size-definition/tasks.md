# Implementation Plan: Serving Size UI Enhancement

## Overview

This implementation plan adds UI for the existing `servingsCount` field in CustomMeal. The field and calculation logic already exist - we only need to add user-facing components. This is a UI-focused enhancement with minimal business logic changes.

## Tasks

- [x] 1. Add computed properties for per-serving nutrition to CustomMeal
  - [x] 1.1 Create CustomMeal extension with computed properties
    - Add `perServingCalories: Double?` (returns nil if servingsCount ≤ 1)
    - Add `perServingProtein: Double?`
    - Add `perServingCarbohydrates: Double?`
    - Add `perServingFats: Double?`
    - Add `hasMultipleServings: Bool` (returns servingsCount > 1)
    - _Requirements: 2.1, 2.3, 8.1_
  
  - [x]* 1.2 Write unit tests for per-serving calculations
    - Test per-serving calculation with servingsCount = 4
    - Test returns nil when servingsCount = 1
    - Test returns nil when servingsCount = 0 (edge case)
    - Test hasMultipleServings returns correct boolean
    - _Requirements: 2.1, 8.1_

- [x] 2. Add serving count input to IngredientReviewView
  - [x] 2.1 Add serving count input UI
    - Add "Serving Information (Optional)" section
    - Add HStack with "This recipe makes ___ servings" text and TextField
    - Add @State for servingCountText (String) and servingCountError (String?)
    - Default servingCountText to "1"
    - Use .decimalPad keyboard type
    - _Requirements: 1.1, 1.3_
  
  - [x] 2.2 Add validation logic
    - Validate on text change: must be positive number > 0
    - Display inline error message for invalid input
    - Disable save button when validation fails
    - Clear error when input becomes valid
    - _Requirements: 1.4, 7.1, 7.2_
  
  - [x] 2.3 Pass servingsCount to saveCustomMeal
    - Convert servingCountText to Double
    - Pass to CustomMealManager.saveCustomMeal(servingsCount:)
    - Default to 1.0 if field is empty or invalid
    - _Requirements: 1.5_

- [x] 3. Update CustomMealManager.saveCustomMeal signature
  - [x] 3.1 Add servingsCount parameter
    - Add `servingsCount: Double = 1.0` parameter to saveCustomMeal method
    - Add validation: guard servingsCount > 0
    - Pass servingsCount to CustomMeal initializer
    - _Requirements: 1.5, 7.3_
  
  - [x] 3.2 Update all call sites
    - Update MealBuilderReviewView to pass servingsCount
    - Update any other views that call saveCustomMeal
    - Ensure backward compatibility (default parameter = 1.0)
    - _Requirements: 1.6, 6.1_
  
  - [x]* 3.3 Write unit tests
    - Test saving meal with servingsCount = 4
    - Test saving meal with default servingsCount = 1
    - Test validation rejects servingsCount ≤ 0
    - _Requirements: 7.3, 8.1_

- [x] 4. Add per-serving display to CustomMealDetailView
  - [x] 4.1 Add serving information section
    - Add conditional section that only shows if meal.hasMultipleServings
    - Display "Makes X servings" text
    - Display per-serving nutrition in labeled box
    - Show calories, protein, carbs, fats per serving
    - Use gray background for per-serving section
    - _Requirements: 2.1, 2.2, 2.4, 2.5_
  
  - [x] 4.2 Update total recipe section
    - Ensure total recipe nutrition always displays
    - Label clearly as "Total Recipe"
    - Use blue background to distinguish from per-serving
    - _Requirements: 2.2_
  
  - [ ]* 4.3 Write UI tests
    - Test per-serving section appears when servingsCount > 1
    - Test per-serving section hidden when servingsCount = 1
    - Test correct nutrition values displayed
    - _Requirements: 2.1, 2.3_

- [x] 5. Update CustomMealsLibraryView meal rows
  - [x] 5.1 Add serving information to meal rows
    - Add conditional "Makes X servings" text when hasMultipleServings
    - Display per-serving calories alongside total when hasMultipleServings
    - Format as "XXX cal/serving • XXX cal total"
    - When servingsCount = 1, show only total calories
    - _Requirements: 3.1, 3.2, 3.3_
  
  - [x] 5.2 Format serving counts without decimals
    - Use Int(meal.servingsCount) for display
    - Only show decimals if servingsCount has fractional part
    - _Requirements: 3.4_
  
  - [ ]* 5.3 Write UI tests
    - Test row displays serving info when servingsCount > 1
    - Test row displays only total when servingsCount = 1
    - Test formatting of serving counts
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 6. Improve ServingAdjustmentView UI
  - [x] 6.1 Update labels and text
    - Change title to "How many servings?" instead of generic text
    - Change label from "multiplier" to "servings"
    - Update TextField placeholder to "Servings"
    - _Requirements: 4.1_
  
  - [x] 6.2 Add per-serving nutrition display
    - Add conditional section that shows when meal.hasMultipleServings
    - Display per-serving nutrition in gray box
    - Show calories, protein, carbs, fats per serving
    - Label as "Per Serving:"
    - _Requirements: 4.2_
  
  - [x] 6.3 Update total consumed display
    - Calculate and display total consumed nutrition
    - Show as "(total / servingsCount) × servingsConsumed"
    - Display in blue box labeled "Total (X servings):"
    - Update in real-time as servingCount changes
    - _Requirements: 4.2, 4.3_
  
  - [x] 6.4 Ensure existing functionality preserved
    - Verify servingCount still passed to addCustomMealToLog as servingMultiplier
    - Test with fractional servings (0.5, 1.5)
    - Test validation still works
    - _Requirements: 4.5, 4.6, 6.2_

- [x] 7. Add serving count editing capability
  - [x] 7.1 Add edit UI to CustomMealDetailView
    - Add "Edit Serving Count" button or inline edit field
    - Allow changing servingsCount value
    - Show validation errors inline
    - _Requirements: 5.1_
  
  - [x] 7.2 Update meal on save
    - Call updateCustomMeal with new servingsCount
    - Recalculate and display updated per-serving nutrition
    - Show success message
    - _Requirements: 5.2, 5.4_
  
  - [ ]* 7.3 Write tests
    - Test editing servingsCount updates display
    - Test validation prevents invalid values
    - Test existing log entries unchanged
    - _Requirements: 5.1, 5.2, 5.3_

- [x] 8. Add validation error enum
  - [x] 8.1 Create ValidationError enum
    - Add case `invalidServingCount`
    - Implement LocalizedError conformance
    - Add user-friendly error message
    - _Requirements: 7.1, 7.2_
  
  - [x] 8.2 Use in CustomMealManager
    - Throw ValidationError.invalidServingCount when servingsCount ≤ 0
    - Catch and display in UI components
    - _Requirements: 7.3_

- [ ]* 9. Test backward compatibility
  - [ ]* 9.1 Test existing meals
    - Load existing CustomMeals with servingsCount = 1.0
    - Verify they display correctly (no per-serving section)
    - Verify adding to log works as before
    - _Requirements: 6.1, 6.2, 6.3_
  
  - [ ]* 9.2 Test editing existing meals
    - Edit existing meal to add servingsCount > 1
    - Verify per-serving display appears
    - Verify calculations correct
    - _Requirements: 6.4_

- [ ]* 10. Final checkpoint - Integration testing
  - Test complete flow: create meal with servingsCount → view in library → add to log
  - Test editing servingsCount on existing meal
  - Test backward compatibility with servingsCount = 1
  - Test validation prevents invalid serving counts
  - Test per-serving calculations are accurate
  - Test UI displays correctly in all views
  - Verify no breaking changes to existing functionality

## Notes

- This is primarily a UI enhancement - the underlying data model and calculations already exist
- No database migration required (servingsCount field already exists with default 1.0)
- All changes are backward compatible
- Focus on clear, intuitive UI that makes serving sizes easy to understand
- Per-serving display only shows when servingsCount > 1 to avoid redundancy
- Existing servingMultiplier parameter continues to work exactly as before
