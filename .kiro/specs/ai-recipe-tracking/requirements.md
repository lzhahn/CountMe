# Requirements Document: AI-Powered Recipe Tracking

## Introduction

This feature enables users to create and track custom meals by providing natural language recipe descriptions. An AI service parses these descriptions into structured ingredient lists with nutritional information, which can be saved as reusable custom meals. This extends the existing calorie tracking system to support complex, multi-ingredient meals while maintaining the same data validation and persistence patterns.

## Glossary

- **Custom_Meal**: A user-created meal template containing multiple ingredients with nutritional information that can be reused across multiple days
- **Recipe_Parser**: The AI service that converts natural language recipe descriptions into structured ingredient lists with nutritional data
- **Ingredient**: A component of a custom meal with name, quantity, serving size, and nutritional information (calories, protein, carbs, fats)
- **Macro**: Macronutrient values including protein, carbohydrates, and fats (in grams)
- **Meal_Instance**: A specific occurrence of a custom meal added to a daily log, potentially with adjusted serving sizes
- **System**: The CountMe iOS application
- **DataStore**: The actor-based persistence layer using SwiftData
- **FoodItem**: The existing model for individual food entries in daily logs

## Requirements

### Requirement 1: Custom Meal Creation

**User Story:** As a user, I want to describe a recipe in natural language, so that the AI can break it down into trackable ingredients with nutritional information.

#### Acceptance Criteria

1. WHEN a user provides a recipe description, THE Recipe_Parser SHALL parse it into a list of ingredients with names, quantities, and serving sizes
2. WHEN the Recipe_Parser processes a description, THE System SHALL retrieve nutritional data (calories, protein, carbs, fats) for each ingredient
3. WHEN parsing completes successfully, THE System SHALL display the ingredient list with nutritional breakdown for user review
4. WHEN parsing fails or returns incomplete data, THE System SHALL allow manual editing of ingredient details
5. WHEN a user confirms the ingredient list, THE System SHALL save it as a Custom_Meal with a user-provided name
6. WHEN saving a Custom_Meal, THE System SHALL calculate and store total nutritional values across all ingredients

### Requirement 2: Custom Meal Storage and Retrieval

**User Story:** As a user, I want to save custom meals for reuse, so that I don't have to re-enter recipes I make frequently.

#### Acceptance Criteria

1. WHEN a Custom_Meal is saved, THE DataStore SHALL persist it with all ingredient details and nutritional information
2. WHEN retrieving Custom_Meals, THE DataStore SHALL return all saved meals sorted by most recently used
3. WHEN a Custom_Meal is deleted, THE DataStore SHALL remove it and all associated ingredient data
4. WHEN the System starts, THE DataStore SHALL load all Custom_Meals for offline access
5. THE System SHALL maintain Custom_Meals independently from daily food logs

### Requirement 3: Custom Meal Selection and Addition

**User Story:** As a user, I want to browse my saved custom meals and add them to my daily log, so that I can quickly track meals I make regularly.

#### Acceptance Criteria

1. WHEN a user views the custom meals list, THE System SHALL display all saved Custom_Meals with names and total nutritional values
2. WHEN a user selects a Custom_Meal, THE System SHALL show detailed ingredient breakdown with individual nutritional values
3. WHEN a user adds a Custom_Meal to their daily log, THE System SHALL create Meal_Instance entries for each ingredient
4. WHEN adding a Custom_Meal, THE System SHALL allow serving size adjustment before adding to the log
5. WHEN a Custom_Meal is added, THE System SHALL update the daily total calories and macros immediately

### Requirement 4: Serving Size Adjustment

**User Story:** As a user, I want to adjust serving sizes when adding custom meals, so that I can track partial servings or multiple servings accurately.

#### Acceptance Criteria

1. WHEN a user adjusts serving size, THE System SHALL recalculate all nutritional values proportionally
2. WHEN serving size is set to zero or negative, THE System SHALL reject the adjustment and maintain current values
3. WHEN serving size adjustment is confirmed, THE System SHALL apply the multiplier to all ingredients in the Custom_Meal
4. THE System SHALL preserve the original Custom_Meal template when creating adjusted Meal_Instances

### Requirement 5: Macro Tracking Integration

**User Story:** As a user, I want to see protein, carbs, and fats for my meals, so that I can track macronutrients in addition to calories.

#### Acceptance Criteria

1. THE System SHALL display macro breakdown (protein, carbs, fats) for each Custom_Meal
2. WHEN viewing a daily log, THE System SHALL show total macros across all food items and custom meals
3. WHEN a user sets macro goals, THE System SHALL display remaining macros alongside remaining calories
4. THE System SHALL validate that all macro values are non-negative
5. WHEN macro data is unavailable for an ingredient, THE System SHALL allow manual entry or default to zero

### Requirement 6: FoodItem Model Extension

**User Story:** As a developer, I want to extend the FoodItem model to support macro tracking, so that both regular food items and custom meal ingredients use the same data structure.

#### Acceptance Criteria

1. THE FoodItem SHALL include optional fields for protein, carbs, and fats (in grams)
2. WHEN a FoodItem is created from API search, THE System SHALL populate macro fields if available
3. WHEN a FoodItem is created manually, THE System SHALL allow optional macro entry
4. WHEN a FoodItem is created from a Custom_Meal ingredient, THE System SHALL include all macro values
5. THE System SHALL maintain backward compatibility with existing FoodItems that lack macro data

### Requirement 7: AI Service Integration

**User Story:** As a developer, I want to integrate with an AI service for recipe parsing, so that users can input natural language descriptions.

#### Acceptance Criteria

1. WHEN the Recipe_Parser is invoked, THE System SHALL send the recipe description to the AI service with appropriate authentication
2. WHEN the AI service responds, THE System SHALL parse the structured response into ingredient objects
3. IF the AI service request fails, THEN THE System SHALL display an error message and allow manual ingredient entry
4. WHEN the AI service returns partial data, THE System SHALL populate available fields and flag missing data for user review
5. THE System SHALL implement a 30-second timeout for AI service requests

### Requirement 8: Data Source Tracking

**User Story:** As a developer, I want to track the source of food items, so that the system can distinguish between API-sourced, manually-entered, and AI-generated items.

#### Acceptance Criteria

1. THE FoodItemSource SHALL include a new case for AI-generated custom meal ingredients
2. WHEN a FoodItem is created from a Custom_Meal, THE System SHALL set the source to the AI-generated case
3. WHEN displaying food items, THE System SHALL indicate the source with appropriate visual indicators
4. THE System SHALL maintain source information through persistence and retrieval operations

### Requirement 9: Custom Meal Editing

**User Story:** As a user, I want to edit saved custom meals, so that I can correct mistakes or update recipes.

#### Acceptance Criteria

1. WHEN a user selects a Custom_Meal for editing, THE System SHALL display all ingredient details in an editable form
2. WHEN a user modifies ingredient details, THE System SHALL recalculate total nutritional values
3. WHEN a user saves edits, THE DataStore SHALL update the Custom_Meal and preserve the modification timestamp
4. WHEN a user adds or removes ingredients, THE System SHALL update the ingredient list and recalculate totals
5. THE System SHALL not modify existing Meal_Instances when a Custom_Meal template is edited

### Requirement 10: Data Validation

**User Story:** As a developer, I want to validate all nutritional data, so that the system maintains data integrity consistent with existing validation rules.

#### Acceptance Criteria

1. THE System SHALL reject any nutritional values (calories, protein, carbs, fats) that are negative
2. WHEN validating a Custom_Meal, THE System SHALL ensure all ingredients have required fields (name, calories)
3. WHEN validating serving sizes, THE System SHALL ensure they are positive numbers
4. IF validation fails, THEN THE System SHALL display field-specific error messages
5. THE System SHALL apply the same validation rules to Custom_Meals as to regular FoodItems

### Requirement 11: Offline Support

**User Story:** As a user, I want to access my saved custom meals offline, so that I can track meals without an internet connection.

#### Acceptance Criteria

1. THE System SHALL persist all Custom_Meals locally using SwiftData
2. WHEN offline, THE System SHALL allow browsing and adding saved Custom_Meals to daily logs
3. WHEN offline, THE System SHALL disable AI recipe parsing and display an appropriate message
4. WHEN connectivity is restored, THE System SHALL not require re-syncing of Custom_Meals
5. THE System SHALL maintain full functionality for saved Custom_Meals regardless of network status

### Requirement 12: Search and Filtering

**User Story:** As a user, I want to search my saved custom meals, so that I can quickly find specific recipes.

#### Acceptance Criteria

1. WHEN a user enters a search query, THE System SHALL filter Custom_Meals by name (case-insensitive)
2. WHEN a user clears the search, THE System SHALL display all Custom_Meals
3. THE System SHALL update search results in real-time as the user types
4. WHEN no Custom_Meals match the search, THE System SHALL display a message indicating no results
5. THE System SHALL maintain the sort order (most recently used) within search results

### Requirement 13: Create Custom Meals from Search Results

**User Story:** As a user, I want to create a custom meal by searching for and selecting multiple food items from the nutrition database, so that I can build reusable meals from accurate nutritional data without typing a recipe description.

#### Acceptance Criteria

1. WHEN a user is in the food search view, THE System SHALL provide a "Build Custom Meal" mode
2. WHEN in build mode, THE System SHALL allow searching for foods using the FatSecret API
3. WHEN search results are displayed, THE System SHALL show a selection checkbox next to each result
4. WHEN a user selects search results, THE System SHALL add them to a temporary ingredient list
5. WHEN a user confirms their selection, THE System SHALL convert each NutritionSearchResult to an Ingredient with all nutritional data preserved
6. WHEN converting search results to Ingredients, THE System SHALL preserve serving sizes, units, calories, and all macro values
7. THE System SHALL allow editing ingredient quantities and serving sizes before saving
8. THE System SHALL prompt for a meal name before saving
9. WHEN saved, THE Custom_Meal SHALL be immediately available in the custom meals library
10. THE System SHALL allow users to continue searching and adding more items to the same meal

### Requirement 14: Create Custom Meals from Daily Log Items

**User Story:** As a user, I want to create a custom meal by selecting existing food items from my daily logs, so that I can quickly save meals I've already tracked as reusable templates.

#### Acceptance Criteria

1. WHEN a user views their daily log, THE System SHALL provide an option to select multiple food items
2. WHEN a user selects food items, THE System SHALL display a "Create Meal from Selection" action
3. WHEN creating a meal from selected items, THE System SHALL convert each FoodItem to an Ingredient with all nutritional data preserved
4. WHEN converting FoodItems to Ingredients, THE System SHALL preserve serving sizes, units, and all macro values
5. WHEN the user confirms, THE System SHALL create a new Custom_Meal with the converted ingredients
6. THE System SHALL prompt for a meal name before saving
7. WHEN saved, THE Custom_Meal SHALL be immediately available in the custom meals library
8. THE System SHALL maintain the original FoodItems in the daily log (non-destructive operation)
