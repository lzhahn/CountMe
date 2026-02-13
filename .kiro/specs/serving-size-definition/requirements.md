# Requirements Document: Serving Size UI Enhancement

## Introduction

This feature enhances the existing AI recipe tracking system by adding UI for users to define and display serving sizes. The `servingsCount` field already exists in CustomMeal but lacks user-facing UI. This enhancement allows users to specify how many servings a recipe makes during creation and displays per-serving nutrition throughout the app.

## Glossary

- **Custom_Meal**: A user-created meal template containing multiple ingredients with nutritional information
- **servingsCount**: Existing field in CustomMeal representing how many servings the recipe makes (default 1.0)
- **Per_Serving_Nutrition**: Total recipe nutrition divided by servingsCount
- **Serving_Multiplier**: The number of servings consumed when adding a meal to daily log (existing parameter)
- **System**: The CountMe iOS application

## Requirements

### Requirement 1: Serving Count Input During Meal Creation

**User Story:** As a user, I want to specify how many servings a recipe makes when creating it, so that I can see per-serving nutrition.

#### Acceptance Criteria

1. WHEN creating a custom meal from AI-parsed ingredients, THE System SHALL prompt "This recipe makes ___ servings"
2. WHEN the user enters a serving count, THE System SHALL accept positive decimal values (e.g., 1, 2, 4, 6)
3. WHEN the user skips the input, THE System SHALL default to 1.0 servings (entire recipe = 1 serving)
4. THE System SHALL validate that serving count is a positive number greater than zero
5. WHEN the user confirms, THE System SHALL save the value to CustomMeal.servingsCount
6. THE System SHALL apply this to all meal creation workflows (AI parsing, search results, daily log items)

### Requirement 2: Per-Serving Nutrition Display

**User Story:** As a user, I want to see nutrition per serving, so that I understand what one serving contains.

#### Acceptance Criteria

1. WHEN viewing a custom meal with servingsCount > 1, THE System SHALL display per-serving nutrition (total ÷ servingsCount)
2. WHEN viewing a custom meal, THE System SHALL display both per-serving AND total recipe nutrition
3. WHEN servingsCount = 1, THE System SHALL only display total nutrition (no redundant per-serving display)
4. THE System SHALL clearly label "Per Serving" and "Total Recipe" sections
5. THE System SHALL display per-serving values for calories, protein, carbs, and fats

### Requirement 3: Serving Count Display in Meal Library

**User Story:** As a user, I want to see serving information when browsing meals, so that I can quickly identify portion sizes.

#### Acceptance Criteria

1. WHEN viewing the custom meals library, THE System SHALL display "Makes X servings" for meals with servingsCount > 1
2. WHEN servingsCount > 1, THE System SHALL display per-serving calories alongside total calories
3. WHEN servingsCount = 1, THE System SHALL display only total calories
4. THE System SHALL format serving counts without unnecessary decimals (e.g., "4" not "4.0")

### Requirement 4: Improved Add-to-Log UI

**User Story:** As a user, I want to specify servings (not multipliers) when adding meals, so that the interface is more intuitive.

#### Acceptance Criteria

1. WHEN adding a custom meal to daily log, THE System SHALL prompt "How many servings?" instead of showing a generic multiplier
2. WHEN servingsCount > 1, THE System SHALL display per-serving nutrition and total consumed nutrition
3. WHEN the user adjusts serving count, THE System SHALL update displayed nutrition in real-time
4. THE System SHALL default to 1.0 servings when opening the add-to-log interface
5. THE System SHALL accept decimal values (e.g., 0.5, 1.5, 2.0)
6. THE System SHALL pass the value to existing `addCustomMealToLog(servingMultiplier:)` method

### Requirement 5: Serving Count Editing

**User Story:** As a user, I want to edit serving counts for saved meals, so that I can correct mistakes.

#### Acceptance Criteria

1. WHEN editing a custom meal, THE System SHALL allow changing the servingsCount value
2. WHEN servingsCount is changed, THE System SHALL recalculate and display updated per-serving nutrition
3. THE System SHALL not modify existing daily log entries when servingsCount is edited
4. WHEN saving edits, THE System SHALL persist the updated servingsCount to CustomMeal

### Requirement 6: Backward Compatibility

**User Story:** As a user, I want my existing custom meals to continue working, so that nothing breaks.

#### Acceptance Criteria

1. WHEN loading existing custom meals with servingsCount = 1.0, THE System SHALL display them normally
2. WHEN adding existing meals to daily log, THE System SHALL use the existing servingMultiplier behavior
3. THE System SHALL not require migration of existing custom meals
4. WHEN editing existing meals, THE System SHALL allow adding/changing servingsCount

### Requirement 7: Validation

**User Story:** As a developer, I want to validate serving count inputs, so that data integrity is maintained.

#### Acceptance Criteria

1. THE System SHALL reject serving counts that are zero, negative, or non-numeric
2. WHEN validation fails, THE System SHALL display an error message
3. THE System SHALL prevent saving meals with invalid serving counts
4. THE System SHALL validate serving count when adding meals to daily log

### Requirement 8: Calculation Accuracy

**User Story:** As a developer, I want accurate per-serving calculations, so that nutrition tracking is correct.

#### Acceptance Criteria

1. THE System SHALL calculate per-serving nutrition as: totalNutrition ÷ servingsCount
2. THE System SHALL calculate consumed nutrition as: (totalNutrition ÷ servingsCount) × servingsConsumed
3. THE System SHALL maintain full precision in calculations (no intermediate rounding)
4. THE System SHALL round displayed values to 1 decimal place for readability
5. THE System SHALL handle servingsCount = 1.0 without division errors
