# Implementation Plan: AI-Powered Recipe Tracking

## Overview

This implementation plan breaks down the AI-powered recipe tracking feature into discrete, incremental coding tasks. The approach follows a bottom-up strategy: first extending the data models and persistence layer, then implementing the AI service integration, followed by business logic, and finally the UI components. Each task builds on previous work, with testing integrated throughout to catch errors early.

The implementation maintains consistency with existing CountMe patterns (actor-based DataStore, SwiftData persistence, SwiftUI views) while adding new capabilities for macro tracking, custom meals, and AI-powered recipe parsing.

## Tasks

- [x] 1. Extend FoodItem model with macro tracking support
  - Add optional protein, carbohydrates, and fats fields to FoodItem model
  - Update FoodItem initializer to accept optional macro parameters
  - Ensure backward compatibility (existing FoodItems without macros should work)
  - Update FoodItemSource enum to include `.customMeal` case
  - _Requirements: 6.1, 6.5, 8.1_

- [ ]* 1.1 Write property test for FoodItem backward compatibility
  - **Property 17: Backward Compatibility with Legacy FoodItems**
  - **Validates: Requirements 6.5**

- [x] 2. Create CustomMeal and Ingredient data models
  - Create Ingredient model with SwiftData @Model annotation
  - Include fields: id, name, quantity, unit, calories, protein, carbohydrates, fats
  - Create CustomMeal model with SwiftData @Model annotation
  - Include fields: id, name, ingredients array, createdAt, lastUsedAt, servingsCount
  - Implement computed properties for total nutritional values (totalCalories, totalProtein, totalCarbohydrates, totalFats)
  - _Requirements: 1.6, 2.1_

- [ ]* 2.1 Write property test for CustomMeal total calculation invariant
  - **Property 2: Custom Meal Total Calculation Invariant**
  - **Validates: Requirements 1.6, 3.5, 5.2, 9.2, 9.4**

- [x] 3. Extend DailyLog with macro tracking computed properties
  - Add computed property `totalProtein` that sums all food items' protein values
  - Add computed property `totalCarbohydrates` that sums all food items' carbs values
  - Add computed property `totalFats` that sums all food items' fats values
  - Handle nil macro values by treating them as zero in calculations
  - _Requirements: 5.2, 6.5_

- [ ]* 3.1 Write property test for daily log macro totals invariant
  - **Property 8: Daily Log Macro Totals Invariant**
  - **Validates: Requirements 5.2, 6.5**

- [x] 4. Extend DataStore with CustomMeal persistence operations
  - Add `fetchAllCustomMeals()` method to retrieve all saved custom meals
  - Add `fetchCustomMeal(id: UUID)` method to retrieve a specific meal
  - Add `saveCustomMeal(_ meal: CustomMeal)` method to persist a new meal
  - Add `updateCustomMeal(_ meal: CustomMeal)` method to update existing meal
  - Add `deleteCustomMeal(_ meal: CustomMeal)` method with cascade delete for ingredients
  - Add `searchCustomMeals(query: String)` method for case-insensitive name filtering
  - Sort results by lastUsedAt (most recent first) in fetch methods
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 12.1_

- [ ]* 4.1 Write property test for CustomMeal persistence round-trip
  - **Property 3: Custom Meal Persistence Round-Trip**
  - **Validates: Requirements 2.1, 11.1**

- [ ]* 4.2 Write property test for CustomMeal sort order
  - **Property 4: Custom Meal Sort Order**
  - **Validates: Requirements 2.2, 12.5**

- [ ]* 4.3 Write property test for cascade deletion completeness
  - **Property 5: Cascade Deletion Completeness**
  - **Validates: Requirements 2.3**

- [x] 5. Implement AIRecipeParser actor for AI service integration
  - Create AIRecipeParser actor with URLSession and API configuration
  - Implement structured prompt with JSON schema enforcement (use design document prompt)
  - Implement `parseRecipe(description: String)` method with 30-second timeout
  - Add request validation (10-500 character length, sanitization)
  - Implement JSON response parsing with validation (positive values, allowed units, confidence range)
  - Handle malformed JSON (strip markdown blocks, extract JSON from mixed content)
  - Define AIParserError enum (invalidResponse, networkError, parsingFailed, timeout, insufficientData)
  - Add retry logic with exponential backoff (max 3 attempts)
  - _Requirements: 1.1, 1.2, 7.1, 7.2, 7.5_

- [ ]* 5.1 Write unit tests for AI prompt validation
  - Test recipe description length validation (reject < 10 or > 500 chars)
  - Test sanitization of special characters and prompt injection attempts
  - _Requirements: 7.1_

- [ ]* 5.2 Write unit tests for JSON parsing edge cases
  - Test parsing valid JSON with all fields
  - Test parsing JSON with missing optional macro fields
  - Test rejection of negative nutritional values
  - Test rejection of invalid units
  - Test rejection of empty ingredient arrays
  - Test extraction of JSON from markdown code blocks
  - _Requirements: 7.2, 7.4_

- [ ]* 5.3 Write property test for AI response parsing completeness
  - **Property 18: AI Response Parsing Completeness**
  - **Validates: Requirements 7.2**

- [x] 6. Implement serving size calculation utilities
  - Create `applyServingMultiplier(_ multiplier: Double, to ingredient: Ingredient)` function
  - Multiply all nutritional values (calories, protein, carbs, fats, quantity) by multiplier
  - Validate multiplier is positive (> 0), reject zero or negative values
  - Return new Ingredient instance (preserve immutability)
  - _Requirements: 4.1, 4.2, 4.3_

- [ ]* 6.1 Write property test for serving size multiplier proportionality
  - **Property 9: Serving Size Multiplier Proportionality**
  - **Validates: Requirements 4.1, 4.3**

- [ ]* 6.2 Write unit tests for serving size validation
  - Test rejection of zero multiplier
  - Test rejection of negative multiplier
  - Test that original ingredient is unchanged after applying multiplier
  - _Requirements: 4.2_

- [x] 7. Implement CustomMealManager business logic
  - Create CustomMealManager class with @Observable annotation
  - Add properties: savedMeals array, isLoading bool, errorMessage optional string
  - Inject DataStore and AIRecipeParser dependencies
  - Implement `parseRecipe(description: String)` method that calls AIRecipeParser
  - Implement `saveCustomMeal(name: String, ingredients: [Ingredient])` method
  - Implement `updateCustomMeal(_ meal: CustomMeal)` method with timestamp update
  - Implement `deleteCustomMeal(_ meal: CustomMeal)` method
  - Implement `loadAllCustomMeals()` method to populate savedMeals array
  - Implement `addCustomMealToLog(_ meal: CustomMeal, servingMultiplier: Double, log: DailyLog)` method
  - Implement `searchCustomMeals(query: String)` method with case-insensitive filtering
  - Handle all error scenarios with user-friendly error messages
  - _Requirements: 1.1, 1.5, 2.1, 2.3, 3.3, 9.3, 12.1_

- [ ]* 7.1 Write property test for meal-to-FoodItems conversion completeness
  - **Property 7: Meal-to-FoodItems Conversion Completeness**
  - **Validates: Requirements 3.3**

- [ ]* 7.2 Write property test for custom meal data independence
  - **Property 6: Custom Meal Data Independence**
  - **Validates: Requirements 2.5, 9.5**

- [ ]* 7.3 Write property test for serving size multiplier immutability
  - **Property 10: Serving Size Multiplier Immutability**
  - **Validates: Requirements 4.4**

- [x] 8. Implement data validation utilities
  - Create validation function for nutritional values (non-negative check)
  - Create validation function for required ingredient fields (name, calories)
  - Create validation function for serving sizes (positive check)
  - Return field-specific error messages for validation failures
  - Ensure same validation logic applies to FoodItems, Ingredients, and manual entries
  - _Requirements: 10.1, 10.2, 10.3, 10.5_

- [ ]* 8.1 Write property test for nutritional value validation
  - **Property 11: Nutritional Value Validation**
  - **Validates: Requirements 4.2, 5.4, 10.1, 10.3**

- [ ]* 8.2 Write property test for required fields validation
  - **Property 12: Required Fields Validation**
  - **Validates: Requirements 10.2**

- [ ]* 8.3 Write property test for validation rule consistency
  - **Property 21: Validation Rule Consistency**
  - **Validates: Requirements 10.5**

- [x] 9. Checkpoint - Ensure all data layer and business logic tests pass
  - Run all property tests and unit tests for models, DataStore, AIRecipeParser, and CustomMealManager
  - Verify 90%+ code coverage for business logic
  - Ask the user if questions arise

- [x] 10. Implement RecipeInputView for AI parsing
  - Create SwiftUI view with multi-line TextField for recipe description
  - Add character count display (10-500 character limit)
  - Add "Parse Recipe" button that calls CustomMealManager.parseRecipe()
  - Show loading indicator during AI request
  - Display error message with retry button on failure
  - Add "Enter Manually" button to bypass AI and go to manual ingredient entry
  - Include example prompts to guide user input
  - Disable parse button when offline (check network reachability)
  - _Requirements: 1.1, 1.4, 7.3, 11.3_

- [x] 11. Implement IngredientReviewView for parsed ingredient editing
  - Create SwiftUI view that displays list of parsed ingredients
  - Each ingredient row shows: name, quantity, unit, calories, protein, carbs, fats
  - Make all fields editable with appropriate input types (text, number)
  - Add validation with inline error display for invalid values
  - Show total nutritional summary at top (sum of all ingredients)
  - Add "Add Ingredient" button to manually add more ingredients
  - Add "Remove" button for each ingredient (swipe-to-delete)
  - Add "Save Custom Meal" button that prompts for meal name
  - Add "Cancel" button to discard and return to recipe input
  - Display warning if AI confidence < 0.7
  - _Requirements: 1.3, 1.4, 1.5, 1.6, 9.1, 9.2, 9.4_

- [x] 12. Implement CustomMealsLibraryView for browsing saved meals
  - Create SwiftUI view with search bar at top
  - Implement real-time search filtering (case-insensitive)
  - Display list of CustomMeals with name, total calories, and macro summary
  - Show creation date and last used date for each meal
  - Implement swipe-to-delete for meal removal
  - Add "+" button in toolbar to create new custom meal (navigate to RecipeInputView)
  - Show empty state with helpful message when no meals saved
  - Display "No results" message when search returns empty
  - Sort meals by most recently used (lastUsedAt descending)
  - _Requirements: 2.2, 3.1, 12.1, 12.2, 12.4_

- [ ]* 12.1 Write property test for custom meal search correctness
  - **Property 20: Custom Meal Search Correctness**
  - **Validates: Requirements 12.1, 12.2**

- [x] 13. Implement CustomMealDetailView for viewing and adding meals
  - Create SwiftUI view that displays meal name and creation date
  - Show full ingredient list with quantities and units
  - Display total nutritional breakdown (calories, protein, carbs, fats) prominently
  - Add serving size adjustment control (stepper or slider, default 1.0)
  - Implement real-time recalculation of nutritional values as serving size changes
  - Add "Add to Today" button that adds meal to current daily log
  - Add "Edit" button that navigates to IngredientReviewView with meal data
  - Add "Delete" button with confirmation alert
  - Update lastUsedAt timestamp when meal is added to log
  - _Requirements: 3.2, 3.4, 4.1, 9.1_

- [x] 14. Implement MacroDisplayView reusable component
  - Create SwiftUI view that displays macro breakdown visually
  - Show horizontal bar chart or circular progress with color-coded sections
  - Use blue for protein, green for carbs, orange for fats
  - Display numeric values with units (grams)
  - Show percentage of daily goals if goals are set
  - Make component reusable for daily log view and custom meal views
  - Handle nil macro values gracefully (treat as zero)
  - _Requirements: 5.1, 5.2, 5.3_

- [ ]* 14.1 Write property test for macro goal remaining calculation
  - **Property 13: Macro Goal Remaining Calculation**
  - **Validates: Requirements 5.3**

- [x] 15. Integrate custom meals into main calorie tracking flow
  - Update MainCalorieView to display macro totals alongside calorie totals
  - Add MacroDisplayView component to daily log display
  - Update FoodItemRow to show macro information if available
  - Add "Custom Meals" option to food entry flow (alongside API search and manual entry)
  - Update FoodSearchView to include "Browse Custom Meals" button
  - Ensure FoodItems created from custom meals have source set to `.customMeal`
  - Display source indicator icon for custom meal items
  - _Requirements: 3.1, 5.1, 5.2, 8.2, 8.3_

- [ ]* 15.1 Write property test for FoodItem source attribution
  - **Property 14: FoodItem Source Attribution**
  - **Validates: Requirements 8.2**

- [x] 16. Extend ManualEntryView with macro fields
  - Add optional text fields for protein, carbohydrates, and fats
  - Place macro fields in a separate "Nutritional Details (Optional)" section
  - Use number input with decimal pad keyboard
  - Apply same validation rules (non-negative values)
  - Display inline validation errors for invalid macro values
  - Ensure macro fields are optional (can be left empty)
  - _Requirements: 6.3_

- [x] 17. Update FatSecret API integration to populate macro fields
  - Modify NutritionSearchResult to include protein, carbs, and fats fields
  - Parse macro data from FatSecret API responses (servings.serving array)
  - Map macro values to FoodItem when creating from API search result
  - Handle missing macro data gracefully (set to nil)
  - _Requirements: 6.2_

- [ ]* 17.1 Write property test for API-to-FoodItem macro preservation
  - **Property 15: API-to-FoodItem Macro Preservation**
  - **Validates: Requirements 6.2**

- [ ]* 17.2 Write property test for custom meal ingredient macro preservation
  - **Property 16: Custom Meal Ingredient Macro Preservation**
  - **Validates: Requirements 6.4**

- [x] 18. Implement offline support and network detection
  - Add network reachability monitoring (use NWPathMonitor)
  - Disable AI parsing UI when offline with tooltip message
  - Ensure all CustomMeal operations work offline (browse, view, add to log)
  - Show offline indicator in UI when network unavailable
  - Automatically enable AI parsing when connectivity restored
  - _Requirements: 11.2, 11.3, 11.4_

- [ ]* 18.1 Write property test for offline custom meal access
  - **Property 19: Offline Custom Meal Access**
  - **Validates: Requirements 11.2, 11.4**

- [x] 19. Implement comprehensive error handling UI
  - Add error display components for AI parsing failures
  - Add retry buttons for network errors
  - Add validation error displays with field highlighting
  - Add confirmation alerts for destructive actions (delete meal)
  - Add toast notifications for successful operations (meal saved, meal added to log)
  - Ensure all error messages are user-friendly and actionable
  - _Requirements: 7.3, 7.4, 10.4_

- [ ] 20. Final checkpoint - Integration testing and polish
  - Test complete flow: recipe input → AI parsing → review → save → browse → add to log
  - Test error scenarios: AI failure → manual entry fallback
  - Test offline scenarios: browse saved meals, add to log, AI disabled
  - Test serving size adjustments with various multipliers
  - Test search and filtering with various queries
  - Verify all 21 correctness properties pass
  - Verify 90%+ code coverage achieved
  - Test backward compatibility with existing FoodItems without macros
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties with 100+ iterations
- Unit tests validate specific examples, edge cases, and error conditions
- AI prompt design is critical - follow the exact format in the design document
- Maintain consistency with existing CountMe patterns (actor-based DataStore, SwiftUI views)
- Macro fields are optional throughout to ensure backward compatibility
