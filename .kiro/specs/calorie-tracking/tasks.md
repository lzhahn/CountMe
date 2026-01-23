# Implementation Plan: Calorie Tracking

## Overview

This implementation plan breaks down the calorie tracking feature into discrete, incremental coding tasks. Each task builds on previous work, starting with core data models and progressing through business logic, API integration, persistence, and UI components. The plan emphasizes early validation through testing and includes checkpoints to ensure quality at each stage.

## Tasks

- [x] 1. Set up core data models and SwiftData schema
  - Create `FoodItem` model with SwiftData annotations
  - Create `DailyLog` model with computed properties for totals
  - Define `FoodItemSource` enum and `NutritionSearchResult` struct
  - Set up SwiftData model container in `CountMeApp.swift`
  - _Requirements: 1.1, 1.2, 3.1, 4.1_

- [ ]* 1.1 Write property test for FoodItem model
  - **Property 14: Required Fields Validation**
  - **Validates: Requirements 8.3**

- [x] 2. Implement DataStore actor for persistence operations
  - [x] 2.1 Create `DataStore` actor with ModelContext
    - Implement `fetchDailyLog(for:)` method
    - Implement `saveDailyLog(_:)` method
    - Implement `fetchHistoricalLogs(from:to:)` method
    - Add date normalization helper (midnight of day)
    - _Requirements: 1.4, 6.1, 6.4, 7.1_
  
  - [x] 2.2 Add food item mutation methods
    - Implement `deleteFoodItem(_:from:)` method
    - Implement `updateFoodItem(_:in:)` method
    - Ensure changes trigger persistence
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [ ]* 2.3 Write property test for data persistence
    - **Property 3: Data Persistence Round-Trip**
    - **Validates: Requirements 1.4, 4.1, 5.3, 7.2**

- [ ] 3. Implement FatSecret API client with OAuth 1.0
  - [x] 3.1 Create OAuth 1.0 signature generator
    - Implement signature base string generation
    - Implement HMAC-SHA1 signing
    - Add timestamp and nonce generation
    - _Requirements: 2.1_
  
  - [x] 3.2 Create `NutritionAPIClient` actor
    - Implement `searchFood(query:)` method
    - Parse FatSecret search response to `NutritionSearchResult`
    - Extract calories from food description string
    - Handle pagination (first page only for MVP)
    - _Requirements: 2.1, 2.2_
  
  - [x] 3.3 Add error handling for API failures
    - Define `NutritionAPIError` enum
    - Handle network errors with descriptive messages
    - Handle invalid responses and missing data
    - Implement timeout (30 seconds)
    - _Requirements: 2.3, 8.2_
  
  - [ ]* 3.4 Write property test for search results
    - **Property 4: Search Results Relevance**
    - **Validates: Requirements 2.1**
  
  - [ ]* 3.5 Write property test for calorie validation
    - **Property 13: Calorie Value Validation**
    - **Validates: Requirements 8.1, 8.3**
  
  - [ ] 3.6 Write unit test for API error handling
    - Test network failure scenario
    - Test invalid response scenario
    - _Requirements: 2.3, 8.2_

- [x] 4. Checkpoint - Ensure data and API layers work correctly
  - Run all tests and verify they pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement CalorieTracker business logic
  - [x] 5.1 Create `CalorieTracker` observable class
    - Add properties for `currentLog` and `selectedDate`
    - Inject `DataStore` and `NutritionAPIClient` dependencies
    - Implement `loadLog(for:)` method
    - Implement `getCurrentDailyTotal()` method
    - _Requirements: 3.1, 6.1_
  
  - [x] 5.2 Implement food item management methods
    - Implement `addFoodItem(_:)` method
    - Implement `removeFoodItem(_:)` method
    - Implement `updateFoodItem(_:)` method
    - Ensure all methods update totals and persist changes
    - _Requirements: 1.1, 1.3, 5.1, 5.2_
  
  - [x] 5.3 Implement goal management and search
    - Implement `setDailyGoal(_:)` method
    - Implement `searchFood(query:)` method
    - Add computed property for remaining calories
    - _Requirements: 2.1, 4.1, 4.4_
  
  - [ ]* 5.4 Write property test for daily total invariant
    - **Property 2: Daily Total Calculation Invariant**
    - **Validates: Requirements 1.3, 3.1, 3.3, 5.1, 5.2**
  
  - [ ]* 5.5 Write property test for food item addition
    - **Property 1: Food Item Addition Completeness**
    - **Validates: Requirements 1.1, 1.2**
  
  - [ ]* 5.6 Write property test for remaining calories
    - **Property 7: Remaining Calories Calculation**
    - **Validates: Requirements 4.4**

- [x] 6. Implement main calorie tracking view
  - [x] 6.1 Create `MainCalorieView` SwiftUI view
    - Display daily total prominently
    - Display daily goal and remaining calories
    - Show progress indicator (circular or bar)
    - Add visual feedback when goal exceeded
    - Add button to navigate to food search
    - _Requirements: 3.4, 4.2, 4.3, 4.4_
  
  - [x] 6.2 Create `FoodItemRow` view component
    - Display food name, calories, and timestamp
    - Add swipe-to-delete action
    - Add tap gesture for editing
    - Format timestamp as relative time (e.g., "2 hours ago")
    - _Requirements: 5.1, 5.2_
  
  - [x] 6.3 Add food items list to MainCalorieView
    - Display list of today's food items
    - Use `FoodItemRow` for each item
    - Handle empty state with helpful message
    - Wire up delete and edit actions
    - _Requirements: 1.1, 5.1_
  
  - [ ]* 6.4 Write property test for main screen display
    - **Property 15: Main Screen Display Completeness**
    - **Validates: Requirements 4.2**
  
  - [ ]* 6.5 Write property test for goal exceeded state
    - **Property 8: Goal Exceeded State**
    - **Validates: Requirements 4.3**

- [x] 7. Implement food search and selection view
  - [x] 7.1 Create `FoodSearchView` SwiftUI view
    - Add search bar with query binding
    - Display loading indicator during search
    - Show search results list
    - Add manual entry button
    - Handle empty results state
    - _Requirements: 2.1, 2.2_
  
  - [x] 7.2 Create search result row component
    - Display food name and calories
    - Display brand name if available
    - Add tap gesture to select item
    - _Requirements: 2.2_
  
  - [x] 7.3 Wire up search to CalorieTracker
    - Trigger search on query change (with debounce)
    - Handle API errors with user-friendly messages
    - Add selected item to current daily log
    - Navigate back to main view after selection
    - _Requirements: 2.1, 2.3, 2.4_
  
  - [ ]* 7.4 Write property test for search result display
    - **Property 5: Search Result Completeness**
    - **Validates: Requirements 2.2**
  
  - [ ]* 7.5 Write property test for API selection
    - **Property 6: API Selection Preserves Data**
    - **Validates: Requirements 2.4**

- [x] 8. Implement manual food entry view
  - [x] 8.1 Create `ManualEntryView` SwiftUI view
    - Add text field for food name
    - Add number field for calories
    - Add optional fields for serving size/unit
    - Add save button
    - Validate inputs before saving
    - _Requirements: 2.3, 8.3_
  
  - [x] 8.2 Wire up manual entry to CalorieTracker
    - Create FoodItem from manual input
    - Add to current daily log
    - Navigate back to main view
    - Display validation errors
    - _Requirements: 1.1, 8.3_

- [x] 9. Checkpoint - Ensure core UI flows work correctly
  - Test adding food via search
  - Test adding food manually
  - Test editing and deleting items
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement historical data view
  - [x] 10.1 Create `HistoricalView` SwiftUI view
    - Add date picker for navigation
    - Display selected date prominently
    - Show daily total for selected date
    - Display food items list for that date
    - Add navigation buttons (previous/next day)
    - _Requirements: 6.1, 6.2, 6.3_
  
  - [x] 10.2 Wire up historical view to CalorieTracker
    - Load daily log when date changes
    - Handle dates with no data (empty state)
    - Display all required information (date, total, items)
    - _Requirements: 6.1, 6.3_
  
  - [ ]* 10.3 Write property test for historical display
    - **Property 9: Historical Display Completeness**
    - **Validates: Requirements 6.3**
  
  - [ ]* 10.4 Write property test for date-based retrieval
    - **Property 10: Date-Based Log Retrieval**
    - **Validates: Requirements 6.1**

- [x] 11. Implement goal setting view
  - [x] 11.1 Create `GoalSettingView` SwiftUI view
    - Add number field for daily calorie goal
    - Add save button
    - Display current goal if set
    - Validate input (positive number)
    - _Requirements: 4.1_
  
  - [x] 11.2 Wire up goal setting to CalorieTracker
    - Save goal to current daily log
    - Persist goal value
    - Update main view to reflect new goal
    - _Requirements: 4.1_

- [x] 12. Implement date transition handling
  - [x] 12.1 Add date change detection to CalorieTracker
    - Check for date change on app foreground
    - Create new daily log when date changes
    - Reset daily total to zero for new day
    - _Requirements: 3.2_
  
  - [ ]* 12.2 Write unit test for date transition
    - Test new log creation on date change
    - Test total reset to zero
    - _Requirements: 3.2_

- [ ] 13. Implement data retention policy
  - [ ] 13.1 Add cleanup method to DataStore
    - Implement method to delete logs older than 90 days
    - Call cleanup on app launch
    - _Requirements: 6.4_
  
  - [ ]* 13.2 Write unit test for data retention
    - Test logs from 90 days ago are retained
    - Test logs older than 90 days are deleted
    - _Requirements: 6.4_

- [ ] 14. Implement crash recovery
  - [x] 14.1 Write unit test for crash recovery
    - Simulate unexpected termination
    - Verify data recovery on next launch
    - _Requirements: 7.3_

- [x] 15. Wire everything together in ContentView
  - [x] 15.1 Update ContentView to use MainCalorieView
    - Initialize CalorieTracker with dependencies
    - Pass CalorieTracker to MainCalorieView
    - Set up navigation to other views
    - _Requirements: All_
  
  - [x] 15.2 Add navigation structure
    - Add navigation to FoodSearchView
    - Add navigation to HistoricalView
    - Add navigation to GoalSettingView
    - Add navigation to ManualEntryView
    - _Requirements: All_
  
  - [x] 15.3 Configure app initialization
    - Set up SwiftData model container
    - Initialize DataStore with context
    - Initialize NutritionAPIClient with credentials
    - Load current day's log on launch
    - _Requirements: 7.1_

- [x] 16. Final checkpoint - End-to-end testing
  - Test complete user flows
  - Verify all property tests pass
  - Verify all unit tests pass
  - Test error scenarios
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties across random inputs
- Unit tests validate specific examples, edge cases, and error conditions
- Checkpoints ensure incremental validation and provide opportunities for user feedback
- FatSecret API requires OAuth 1.0 authentication - ensure credentials are configured
- SwiftData handles persistence automatically, but explicit save calls ensure immediate persistence
