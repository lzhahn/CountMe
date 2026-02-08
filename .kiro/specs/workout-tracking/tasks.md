# Tasks: Workout Tracking

## Phase 1: Data Models & Core Logic

- [ ] 1.1 Create ExerciseCategory enum
  - Define Cardio, Strength, Sports, Flexibility cases
  - Add Codable conformance
  - Location: `CountMe/Models/ExerciseCategory.swift`
  - **Validates: Requirement 1.2**

- [ ] 1.2 Create IntensityLevel enum
  - Define Light, Moderate, Vigorous cases
  - Implement metMultiplier computed property (Light: 0.5, Moderate: 1.0, Vigorous: 1.5)
  - Add Codable conformance
  - Location: `CountMe/Models/IntensityLevel.swift`
  - **Validates: Requirements 2.3, 3.2, 3.3, 3.4**

- [ ] 1.3 Create Exercise struct
  - Define properties: id, name, category, baseMET, description
  - Add Identifiable and Codable conformance
  - Location: `CountMe/Models/Exercise.swift`
  - **Validates: Requirement 1.4**

- [ ] 1.4 Create WorkoutEntry model
  - Define @Model class with properties: _id, exerciseType, exerciseCategory, duration, intensity, caloriesBurned, timestamp, baseMET
  - Add SyncableEntity conformance (userId, lastModified, syncStatus)
  - Add relationship to DailyLog (var dailyLog: DailyLog?)
  - Implement id computed property returning _id.uuidString
  - Location: `CountMe/Models/WorkoutEntry.swift`
  - **Validates: Requirements 2.1, 2.6, 6.1**

- [ ] 1.5 Extend DailyLog model
  - Add workoutEntries relationship with cascade delete: @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.dailyLog)
  - Add totalCaloriesBurned computed property: workoutEntries.reduce(0) { $0 + $1.caloriesBurned }
  - Add netCalories computed property: totalCalories - totalCaloriesBurned
  - Location: `CountMe/Models/DailyLog.swift`
  - **Validates: Requirements 4.1, 4.2, 4.3, 6.3**

- [ ] 1.6 Create CalorieBurnCalculator
  - Implement calculateCaloriesBurned static method
  - Use formula: (duration × baseMET × intensity.metMultiplier × weight) / 200
  - Apply rounding with .rounded() and non-negative constraint with max(0, ...)
  - Set defaultWeight constant to 70.0 kg
  - Location: `CountMe/Services/CalorieBurnCalculator.swift`
  - **Validates: Requirements 3.1, 3.5, 3.6, 3.7**

- [ ] 1.7 Create ExerciseLibrary service
  - Implement singleton pattern (static let shared)
  - Define predefined exercise list with 20+ exercises across all categories
  - Include exercises from design: Running (8.0), Walking (3.5), Cycling (6.0), Swimming (7.0), Jump Rope (10.0), Rowing (6.0), Weightlifting (5.0), Bodyweight (4.0), Basketball (6.5), Soccer (7.0), Tennis (7.0), Yoga (2.5), Stretching (2.3), Pilates (3.0), etc.
  - Implement getAllExercises() -> [Exercise]
  - Implement getExercises(by category: ExerciseCategory) -> [Exercise]
  - Implement searchExercises(query: String) -> [Exercise] with case-insensitive filtering
  - Location: `CountMe/Services/ExerciseLibrary.swift`
  - **Validates: Requirements 1.1, 1.3, 1.5**

- [ ] 1.8 Write unit tests for CalorieBurnCalculator
  - Test calorie calculation formula accuracy with known inputs
  - Test intensity multipliers (Light: 0.5, Moderate: 1.0, Vigorous: 1.5)
  - Test rounding behavior (e.g., 123.4 -> 123, 123.6 -> 124)
  - Test non-negative constraint (ensure result >= 0)
  - Test edge cases (0 duration, extreme MET values, extreme weights)
  - Location: `CountMeTests/Services/CalorieBurnCalculatorTests.swift`
  - **Validates: Requirements 3.1, 3.6, 3.7**

- [ ] 1.9 Write unit tests for ExerciseLibrary
  - Test exercise count (assert count >= 20)
  - Test category filtering (verify each category has exercises)
  - Test search functionality (verify partial name matching)
  - Test case-insensitive search (e.g., "running" matches "Running")
  - Test empty query returns all exercises
  - Location: `CountMeTests/Services/ExerciseLibraryTests.swift`
  - **Validates: Requirements 1.1, 1.3**

## Phase 2: Data Persistence

- [ ] 2.1 Extend DataStore with fetchWorkoutEntries method
  - Normalize date parameter using normalizeDate()
  - Fetch daily log for normalized date using fetchDailyLog(for:)
  - Return log.workoutEntries array (or empty array if no log)
  - Location: `CountMe/Services/DataStore.swift`
  - **Validates: Requirements 6.5, 6.6**

- [ ] 2.2 Extend DataStore with saveWorkoutEntry method
  - Accept WorkoutEntry and DailyLog parameters
  - Set entry.timestamp to Date()
  - Append entry to log.workoutEntries
  - Call modelContext.save()
  - Location: `CountMe/Services/DataStore.swift`
  - **Validates: Requirements 2.5, 6.2**

- [ ] 2.3 Extend DataStore with deleteWorkoutEntry method
  - Accept WorkoutEntry and DailyLog parameters
  - Find entry in log.workoutEntries by id using firstIndex(where:)
  - Remove from array using remove(at:)
  - Call modelContext.save()
  - Location: `CountMe/Services/DataStore.swift`
  - **Validates: Requirement 5.5**

- [ ] 2.4 Extend DataStore with updateWorkoutEntry method
  - Accept WorkoutEntry parameter
  - Call modelContext.save() to persist changes
  - Location: `CountMe/Services/DataStore.swift`
  - **Validates: Requirements 5.3, 5.4**

- [ ] 2.5 Write unit tests for DataStore workout operations
  - Test fetchWorkoutEntries with date normalization (verify midnight conversion)
  - Test saveWorkoutEntry adds to daily log and persists
  - Test deleteWorkoutEntry removes from daily log
  - Test updateWorkoutEntry persists changes (modify duration, verify saved)
  - Test cascade deletion when daily log deleted (verify workout entries deleted)
  - Location: `CountMeTests/Services/DataStoreWorkoutTests.swift`
  - **Validates: Requirements 6.2, 6.3, 6.5, 6.6**

## Phase 3: Input Validation

- [ ] 3.1 Create WorkoutEntryValidator
  - Define ValidationError enum with cases: durationTooShort, durationTooLong, missingExercise, missingIntensity, futureTimestamp
  - Implement LocalizedError conformance with descriptive errorDescription for each case
  - Implement validate static method accepting exercise, duration, intensity, timestamp
  - Check duration >= 1 (throw durationTooShort)
  - Check duration <= 1440 (throw durationTooLong)
  - Check exercise != nil (throw missingExercise)
  - Check intensity != nil (throw missingIntensity)
  - Check timestamp <= Date() (throw futureTimestamp)
  - Location: `CountMe/Utilities/WorkoutEntryValidator.swift`
  - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**

- [ ] 3.2 Write unit tests for WorkoutEntryValidator
  - Test duration too short (duration = 0, expect durationTooShort)
  - Test duration too long (duration = 1441, expect durationTooLong)
  - Test missing exercise (exercise = nil, expect missingExercise)
  - Test missing intensity (intensity = nil, expect missingIntensity)
  - Test future timestamp (timestamp = Date() + 3600, expect futureTimestamp)
  - Test valid input passes (all fields valid, expect no throw)
  - Test error messages are descriptive
  - Location: `CountMeTests/Utilities/WorkoutEntryValidatorTests.swift`
  - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 8.6**

## Phase 4: User Interface

- [ ] 4.1 Create WorkoutEntryRow view
  - Display exercise name with SF Symbol icon (e.g., "figure.run")
  - Display duration (e.g., "30 min") and intensity (e.g., "Moderate")
  - Display calories burned as negative value in red (e.g., "-250 cal")
  - Display timestamp in HH:MM format
  - Match FoodItemRow styling for consistency
  - Add swipe actions: Edit (blue), Delete (red)
  - Location: `CountMe/Views/WorkoutEntryRow.swift`
  - **Validates: Requirements 5.2, 9.1, 9.4, 9.5**

- [ ] 4.2 Create WorkoutEntryView
  - Add searchable exercise picker using ExerciseLibrary
  - Add duration TextField with numeric keyboard (1-1440 minutes)
  - Add intensity Picker with segmented style (Light, Moderate, Vigorous)
  - Add read-only calories burned Text (auto-calculated)
  - Implement real-time calorie calculation on duration/intensity change
  - Add Save button (validates input, calls DataStore.saveWorkoutEntry)
  - Add Cancel button (dismisses sheet)
  - Show Alert for validation errors with specific messages
  - Location: `CountMe/Views/WorkoutEntryView.swift`
  - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 8.4, 8.5, 9.3**

- [ ] 4.3 Extend MainCalorieView
  - Add "Add Workout" Button alongside "Add Food" button
  - Display workout entries in same List as food items
  - Add "Calories Burned" section showing totalCaloriesBurned
  - Add "Net Calories" display with color coding:
    - Green if netCalories < 0 (deficit)
    - Red if netCalories > 0 (surplus)
    - Gray if netCalories == 0
  - Update daily summary layout to show: Consumed, Burned, Net
  - Handle workout entry sheet presentation (.sheet modifier)
  - Location: `CountMe/Views/MainCalorieView.swift`
  - **Validates: Requirements 4.1, 4.2, 4.3, 9.1, 9.2, 9.6, 9.7**

- [ ]* 4.4 Extend HistoricalView
  - Display workout entries for past dates
  - Show daily calories burned totals
  - Maintain existing date navigation
  - Location: `CountMe/Views/HistoricalView.swift`
  - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

- [ ]* 4.5 Write UI tests for WorkoutEntryRow
  - Test display of exercise name
  - Test display of duration and intensity
  - Test display of calories burned (negative, red)
  - Test swipe actions appear
  - Location: `CountMeTests/Views/WorkoutEntryRowTests.swift`
  - **Validates: Requirement 5.2**

- [ ]* 4.6 Write UI tests for WorkoutEntryView
  - Test exercise selection from picker
  - Test duration input validation (reject < 1, > 1440)
  - Test intensity selection
  - Test calorie calculation updates on input change
  - Test save button validation (all fields required)
  - Test error alert display for validation failures
  - Location: `CountMeTests/Views/WorkoutEntryViewTests.swift`
  - **Validates: Requirements 2.1, 2.2, 2.3, 8.3, 8.4, 8.5**

- [ ]* 4.7 Write UI tests for MainCalorieView workout integration
  - Test workout entries display in list
  - Test total calories burned display
  - Test net calories calculation
  - Test color coding (green for deficit, red for surplus, gray for zero)
  - Test add workout button presents sheet
  - Location: `CountMeTests/Views/MainCalorieViewWorkoutTests.swift`
  - **Validates: Requirements 4.1, 4.2, 4.3, 9.6**

## Phase 5: Firebase Integration

- [ ] 5.1 Add WorkoutEntry Firestore serialization
  - Implement toFirestoreData() method returning [String: Any]
  - Include fields: id, exerciseType, exerciseCategory, duration, intensity, caloriesBurned, timestamp, baseMET, userId, lastModified, syncStatus
  - Convert Date to Timestamp, enums to rawValue
  - Implement fromFirestoreData(_ data:) static method
  - Parse all fields with proper type casting
  - Throw SyncError.invalidFirestoreData for missing/invalid fields
  - Location: `CountMe/Models/WorkoutEntry.swift`
  - **Validates: Requirements 6.1, 6.2**

- [ ] 5.2 Update DailyLog Firestore serialization
  - Add workoutEntryIds array to toFirestoreData (map workoutEntries to ids)
  - Add totalCaloriesBurned to toFirestoreData
  - Update fromFirestoreData to handle workoutEntryIds field (optional)
  - Location: `CountMe/Models/DailyLog.swift`
  - **Validates: Requirements 4.2, 6.1**

- [ ]* 5.3 Extend FirebaseSyncEngine for WorkoutEntry
  - Add workout entry sync methods (upload, download, delete)
  - Handle workout entry collection in Firestore
  - Handle workout entry deletion sync
  - Location: `CountMe/Services/FirebaseSyncEngine.swift`

- [ ]* 5.4 Write tests for WorkoutEntry Firestore serialization
  - Test toFirestoreData includes all fields with correct types
  - Test fromFirestoreData creates valid WorkoutEntry
  - Test fromFirestoreData throws for missing required fields
  - Test fromFirestoreData throws for invalid data types
  - Location: `CountMeTests/Models/WorkoutEntryFirestoreTests.swift`

- [ ]* 5.5 Write tests for workout sync functionality
  - Test workout entry upload to Firestore
  - Test workout entry download from Firestore
  - Test workout entry deletion sync
  - Test offline queue handling for workouts
  - Location: `CountMeTests/Services/FirebaseSyncEngineWorkoutTests.swift`

## Phase 6: Error Handling

- [ ] 6.1 Create WorkoutError enum
  - Define error cases: persistenceError(Error), validationError(WorkoutEntryValidator.ValidationError), calculationError, dataCorruption
  - Implement LocalizedError conformance
  - Add descriptive errorDescription for each case
  - Location: `CountMe/Models/WorkoutError.swift`
  - **Validates: Requirements 10.1, 10.2, 10.4**

- [ ] 6.2 Add error handling to WorkoutEntryView
  - Wrap save operation in do-catch block
  - Catch validation errors and show Alert with error message
  - Catch persistence errors with Alert offering retry option
  - Retain user input on error (don't clear form)
  - Location: `CountMe/Views/WorkoutEntryView.swift`
  - **Validates: Requirements 10.1, 10.3, 10.5**

- [ ] 6.3 Add error handling to DataStore workout methods
  - Wrap save/delete operations in do-catch blocks
  - Log errors using print() for debugging
  - Throw WorkoutError.persistenceError wrapping underlying error
  - Location: `CountMe/Services/DataStore.swift`
  - **Validates: Requirements 10.1, 10.2, 10.6**

- [ ] 6.4 Write tests for error handling
  - Test validation error display in WorkoutEntryView
  - Test persistence error recovery (retry option)
  - Test data corruption handling (skip corrupted entry)
  - Test user input retention on error (form not cleared)
  - Location: `CountMeTests/Services/WorkoutErrorHandlingTests.swift`
  - **Validates: Requirements 10.1, 10.3, 10.4, 10.5**

## Phase 7: Property-Based Testing

- [ ] 7.1 Write Property 1: Calorie Calculation Non-Negativity
  - Generate random duration (1-1440), baseMET (1.0-15.0), intensity (Light/Moderate/Vigorous), weight (40-150 kg)
  - Call CalorieBurnCalculator.calculateCaloriesBurned
  - Assert result >= 0 for all inputs
  - Run 100+ iterations using Swift Testing
  - **Validates: Requirement 3.7**
  - Location: `CountMeTests/Services/CalorieBurnCalculatorPropertyTests.swift`

- [ ] 7.2 Write Property 2: Duration Bounds
  - Generate random workout entries with various durations
  - Assert 1 <= entry.duration <= 1440 for all entries
  - Run 100+ iterations
  - **Validates: Requirements 8.1, 8.2**
  - Location: `CountMeTests/Models/WorkoutEntryPropertyTests.swift`

- [ ] 7.3 Write Property 3: Daily Log Totals Consistency
  - Generate random workout entries (1-10 per log)
  - Add to daily log
  - Assert sum(workoutEntries.map(\.caloriesBurned)) == log.totalCaloriesBurned
  - Run 100+ iterations
  - **Validates: Requirements 4.2, 4.4, 4.5**
  - Location: `CountMeTests/Models/DailyLogPropertyTests.swift`

- [ ] 7.4 Write Property 4: Net Calories Calculation
  - Generate random food items (total calories 1000-3000)
  - Generate random workout entries (total burned 0-1000)
  - Assert log.netCalories == log.totalCalories - log.totalCaloriesBurned
  - Run 100+ iterations
  - **Validates: Requirement 4.3**
  - Location: `CountMeTests/Models/DailyLogPropertyTests.swift`

- [ ] 7.5 Write Property 5: Intensity MET Adjustment
  - Generate random exercises with different intensities
  - Calculate effective MET (baseMET × intensity.metMultiplier)
  - Assert Light: effective MET < 3.0 (baseMET × 0.5 < 3.0)
  - Assert Moderate: 3.0 <= effective MET < 6.0 (baseMET × 1.0 in range)
  - Assert Vigorous: effective MET >= 6.0 (baseMET × 1.5 >= 6.0)
  - Run 100+ iterations
  - **Validates: Requirements 3.2, 3.3, 3.4, 3.8**
  - Location: `CountMeTests/Models/IntensityLevelPropertyTests.swift`

- [ ] 7.6 Write Property 6: Date Normalization
  - Generate random workout entries with various timestamps (different hours/minutes)
  - Add to daily log
  - Assert normalizeDate(entry.timestamp) == log.date for all entries
  - Run 100+ iterations
  - **Validates: Requirement 6.6**
  - Location: `CountMeTests/Services/DataStorePropertyTests.swift`

- [ ] 7.7 Write Property 7: Cascade Deletion
  - Create daily logs with random workout entries (1-10 per log)
  - Delete daily logs
  - Assert all associated workout entries are deleted (fetch returns empty)
  - Run 100+ iterations
  - **Validates: Requirement 6.3**
  - Location: `CountMeTests/Models/DailyLogPropertyTests.swift`

- [ ] 7.8 Write Property 8: Timestamp Validity
  - Generate random workout entries with timestamps
  - Assert entry.timestamp <= Date() for all entries
  - Run 100+ iterations
  - **Validates: Requirement 8.6**
  - Location: `CountMeTests/Models/WorkoutEntryPropertyTests.swift`

- [ ] 7.9 Write Property 9: Exercise Library Completeness
  - Assert ExerciseLibrary.shared.getAllExercises().count >= 20
  - Assert all categories (Cardio, Strength, Sports, Flexibility) have at least 1 exercise
  - Verify each exercise has valid baseMET > 0
  - **Validates: Requirement 1.1**
  - Location: `CountMeTests/Services/ExerciseLibraryPropertyTests.swift`

- [ ] 7.10 Write Property 10: Calorie Calculation Accuracy
  - Generate random valid inputs (duration, baseMET, intensity, weight)
  - Calculate expected: round((duration × baseMET × intensity.metMultiplier × weight) / 200)
  - Assert CalorieBurnCalculator.calculateCaloriesBurned == expected
  - Run 100+ iterations
  - **Validates: Requirement 3.1**
  - Location: `CountMeTests/Services/CalorieBurnCalculatorPropertyTests.swift`

## Phase 8: Testing & Polish

- [ ]* 8.1 Verify test coverage
  - Run test coverage report
  - Ensure 90%+ coverage for business logic
  - Ensure 100% coverage for error handling
  - Document any coverage gaps

- [ ]* 8.2 Accessibility review
  - Test VoiceOver support for all views
  - Verify Dynamic Type scaling
  - Check color contrast ratios
  - Test minimum touch targets (44x44)
  - Location: All view files

- [ ]* 8.3 Performance testing
  - Test with 100+ workout entries
  - Verify smooth scrolling in lists
  - Check memory usage
  - Test date range queries
  - Document any performance issues

- [ ]* 8.4 Integration testing
  - Test complete workout entry flow
  - Test workout deletion flow
  - Test workout editing flow
  - Test historical view navigation
  - Test Firebase sync end-to-end

- [ ]* 8.5 Update documentation
  - Add workout tracking to README
  - Document new models and services
  - Update API documentation
  - Add usage examples
