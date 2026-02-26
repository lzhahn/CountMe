# Requirements Document

## Introduction

CountMe currently accepts arbitrary values at model boundaries, lacks bounds checking during Firestore deserialization, and has gaps in sync queue resilience. This feature hardens the app by adding input validation to model constructors, bounds checking to Firestore deserialization, and robustness improvements to the sync queue (size limits, deduplication, per-item retry with backoff via the existing RetryManager).

## Glossary

- **Model_Validator**: The validation logic embedded in model constructors (FoodItem, DailyLog, CustomMeal, ExerciseItem, Ingredient) that enforces value constraints at creation time.
- **Deserialization_Validator**: The validation logic within `fromFirestoreData()` static methods that enforces value range checks on data arriving from Firestore.
- **Sync_Queue**: The array of pending `SyncOperation` items inside `FirebaseSyncEngine` that buffers operations for later execution when offline or after failures.
- **RetryManager**: The existing actor in `CountMe/Services/RetryManager.swift` that provides exponential backoff retry logic for async operations.
- **ValidationError**: A new error type representing invalid input data at model boundaries, distinct from `SyncError`.
- **FoodItem**: A SwiftData model representing a food entry with name, calories, and optional macros.
- **DailyLog**: A SwiftData model representing a day's food and exercise entries with an optional calorie goal.
- **CustomMeal**: A SwiftData model representing a reusable meal template with ingredients.
- **ExerciseItem**: A SwiftData model representing an exercise entry with calories burned and duration.
- **Ingredient**: A SwiftData model representing a single ingredient within a CustomMeal.

## Requirements

### Requirement 1: FoodItem Constructor Validation

**User Story:** As a developer, I want FoodItem construction to reject invalid values, so that no FoodItem with nonsensical data enters the system.

#### Acceptance Criteria

1. WHEN a FoodItem is created with an empty or whitespace-only name, THE Model_Validator SHALL throw a ValidationError indicating the name is invalid.
2. WHEN a FoodItem is created with a negative calories value, THE Model_Validator SHALL throw a ValidationError indicating calories are invalid.
3. WHEN a FoodItem is created with calories exceeding 50,000, THE Model_Validator SHALL throw a ValidationError indicating calories are unrealistically high.
4. WHEN a FoodItem is created with a negative value for protein, carbohydrates, or fats, THE Model_Validator SHALL throw a ValidationError indicating the macro value is invalid.
5. WHEN a FoodItem is created with protein, carbohydrates, or fats exceeding 10,000 grams, THE Model_Validator SHALL throw a ValidationError indicating the macro value is unrealistically high.
6. WHEN a FoodItem is created with all values within valid ranges, THE Model_Validator SHALL successfully create the FoodItem without error.

### Requirement 2: ExerciseItem Constructor Validation

**User Story:** As a developer, I want ExerciseItem construction to reject invalid values, so that no ExerciseItem with nonsensical data enters the system.

#### Acceptance Criteria

1. WHEN an ExerciseItem is created with an empty or whitespace-only name, THE Model_Validator SHALL throw a ValidationError indicating the name is invalid.
2. WHEN an ExerciseItem is created with a negative caloriesBurned value, THE Model_Validator SHALL throw a ValidationError indicating caloriesBurned is invalid.
3. WHEN an ExerciseItem is created with caloriesBurned exceeding 50,000, THE Model_Validator SHALL throw a ValidationError indicating caloriesBurned is unrealistically high.
4. WHEN an ExerciseItem is created with a negative durationMinutes value, THE Model_Validator SHALL throw a ValidationError indicating durationMinutes is invalid.
5. WHEN an ExerciseItem is created with durationMinutes exceeding 1,440 (24 hours), THE Model_Validator SHALL throw a ValidationError indicating durationMinutes is unrealistically high.
6. WHEN an ExerciseItem is created with all values within valid ranges, THE Model_Validator SHALL successfully create the ExerciseItem without error.

### Requirement 3: Ingredient Constructor Validation

**User Story:** As a developer, I want Ingredient construction to reject invalid values, so that no Ingredient with nonsensical data enters the system.

#### Acceptance Criteria

1. WHEN an Ingredient is created with an empty or whitespace-only name, THE Model_Validator SHALL throw a ValidationError indicating the name is invalid.
2. WHEN an Ingredient is created with a non-positive quantity, THE Model_Validator SHALL throw a ValidationError indicating the quantity is invalid.
3. WHEN an Ingredient is created with an empty or whitespace-only unit, THE Model_Validator SHALL throw a ValidationError indicating the unit is invalid.
4. WHEN an Ingredient is created with a negative calories value, THE Model_Validator SHALL throw a ValidationError indicating calories are invalid.
5. WHEN an Ingredient is created with calories exceeding 50,000, THE Model_Validator SHALL throw a ValidationError indicating calories are unrealistically high.
6. WHEN an Ingredient is created with a negative value for protein, carbohydrates, or fats, THE Model_Validator SHALL throw a ValidationError indicating the macro value is invalid.
7. WHEN an Ingredient is created with all values within valid ranges, THE Model_Validator SHALL successfully create the Ingredient without error.

### Requirement 4: CustomMeal Constructor Validation

**User Story:** As a developer, I want CustomMeal construction to reject invalid values, so that no CustomMeal with nonsensical data enters the system.

#### Acceptance Criteria

1. WHEN a CustomMeal is created with an empty or whitespace-only name, THE Model_Validator SHALL throw a ValidationError indicating the name is invalid.
2. WHEN a CustomMeal is created with an empty ingredients array, THE Model_Validator SHALL throw a ValidationError indicating at least one ingredient is required.
3. WHEN a CustomMeal is created with a non-positive servingsCount, THE Model_Validator SHALL throw a ValidationError indicating servingsCount is invalid.
4. WHEN a CustomMeal is created with all values within valid ranges, THE Model_Validator SHALL successfully create the CustomMeal without error.

### Requirement 5: DailyLog Constructor Validation

**User Story:** As a developer, I want DailyLog construction to reject invalid values, so that no DailyLog with nonsensical data enters the system.

#### Acceptance Criteria

1. WHEN a DailyLog is created with a negative dailyGoal, THE Model_Validator SHALL throw a ValidationError indicating dailyGoal is invalid.
2. WHEN a DailyLog is created with a dailyGoal exceeding 50,000, THE Model_Validator SHALL throw a ValidationError indicating dailyGoal is unrealistically high.
3. WHEN a DailyLog is created with a nil dailyGoal, THE Model_Validator SHALL successfully create the DailyLog without error.
4. WHEN a DailyLog is created with a dailyGoal within valid range, THE Model_Validator SHALL successfully create the DailyLog without error.

### Requirement 6: Firestore Deserialization Bounds Checking

**User Story:** As a developer, I want fromFirestoreData() to reject documents with out-of-range values, so that corrupted or tampered Firestore data does not silently enter the local store.

#### Acceptance Criteria

1. WHEN FoodItem.fromFirestoreData() receives a document with negative calories, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
2. WHEN FoodItem.fromFirestoreData() receives a document with calories exceeding 50,000, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
3. WHEN FoodItem.fromFirestoreData() receives a document with an empty name, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
4. WHEN ExerciseItem.fromFirestoreData() receives a document with negative caloriesBurned, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
5. WHEN ExerciseItem.fromFirestoreData() receives a document with caloriesBurned exceeding 50,000, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
6. WHEN CustomMeal.fromFirestoreData() receives a document with ingredient calories that are negative, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
7. WHEN DailyLog.fromFirestoreData() receives a document with a negative dailyGoal, THE Deserialization_Validator SHALL throw a SyncError.invalidData with a descriptive reason.
8. WHEN fromFirestoreData() receives a document with all values within valid ranges, THE Deserialization_Validator SHALL successfully create the model instance without error.

### Requirement 7: Sync Queue Size Limit

**User Story:** As a developer, I want the sync queue to have a maximum size, so that unbounded offline usage does not exhaust device memory.

#### Acceptance Criteria

1. THE Sync_Queue SHALL enforce a maximum capacity of 1,000 operations.
2. WHEN a new operation is enqueued and the Sync_Queue is at maximum capacity, THE Sync_Queue SHALL drop the oldest operation to make room for the new one.
3. WHEN a new operation is enqueued and the Sync_Queue is below maximum capacity, THE Sync_Queue SHALL add the operation normally.

### Requirement 8: Sync Queue Per-Item Retry with Backoff

**User Story:** As a developer, I want each queued sync operation to be retried individually using the existing RetryManager, so that transient failures on one item do not block the rest of the queue.

#### Acceptance Criteria

1. WHEN processQueue() executes a queued operation, THE Sync_Queue SHALL use the RetryManager to retry the operation with exponential backoff on transient failure.
2. WHEN a queued operation exceeds the RetryManager maximum retry count, THE Sync_Queue SHALL remove the operation from the queue and log the failure.
3. WHEN a queued operation succeeds after retry, THE Sync_Queue SHALL remove the operation from the queue.
4. WHEN processQueue() encounters a failed operation, THE Sync_Queue SHALL continue processing remaining operations without stopping.
