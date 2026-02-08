# Requirements Document: Workout Tracking

## Introduction

This document defines the requirements for adding workout and exercise tracking functionality to the CountMe iOS application. The feature enables users to log physical activities, calculate calories burned, and integrate exercise data with the existing calorie tracking system to provide a complete view of caloric intake versus expenditure.

## Glossary

- **Workout_System**: The complete workout tracking subsystem including models, views, and business logic
- **Exercise**: A specific type of physical activity (e.g., running, cycling, weightlifting)
- **Workout_Entry**: A logged instance of an exercise with duration, intensity, and calculated calorie burn
- **Intensity_Level**: The effort level of an exercise based on MET ranges (Light: <3.0 METs, Moderate: 3.0-5.9 METs, Vigorous: ≥6.0 METs)
- **Calorie_Burn**: The estimated number of calories expended during a workout
- **Daily_Log**: The existing system component that tracks daily food intake (now extended for workouts)
- **Net_Calories**: Total calories consumed minus total calories burned
- **MET_Value**: Metabolic Equivalent of Task - a standard measure of exercise intensity (1 MET = resting metabolic rate)
- **DataStore**: The actor-based SwiftData persistence layer
- **HIIT**: High-Intensity Interval Training - alternating short bursts of intense exercise with recovery periods

## Requirements

### Requirement 1: Exercise Library

**User Story:** As a user, I want to select from a predefined list of common exercises, so that I can quickly log workouts without manual data entry.

#### Acceptance Criteria

1. THE Workout_System SHALL provide a library of at least 20 common exercise types
2. WHEN displaying the exercise library, THE Workout_System SHALL organize exercises by category (Cardio, Strength, Sports, Flexibility)
3. WHEN a user searches for an exercise, THE Workout_System SHALL filter the library by exercise name
4. THE Workout_System SHALL store exercise metadata including name, category, and base MET value
5. WHEN an exercise is selected, THE Workout_System SHALL display its category and typical intensity range

### Requirement 2: Workout Entry Creation

**User Story:** As a user, I want to log a workout with duration and intensity, so that I can track my physical activity and calorie expenditure.

#### Acceptance Criteria

1. WHEN a user creates a workout entry, THE Workout_System SHALL require exercise type, duration, and intensity level
2. WHEN a user specifies duration, THE Workout_System SHALL accept values in minutes with a minimum of 1 minute
3. WHEN a user selects intensity, THE Workout_System SHALL offer three levels (Light, Moderate, Vigorous)
4. WHEN a workout entry is created, THE Workout_System SHALL automatically calculate calories burned
5. WHEN a workout entry is saved, THE Workout_System SHALL associate it with the current date's daily log
6. WHEN a workout entry is created, THE Workout_System SHALL record the timestamp of the activity

### Requirement 3: Calorie Burn Calculation

**User Story:** As a user, I want accurate calorie burn estimates based on my workout details, so that I can understand my energy expenditure.

#### Acceptance Criteria

1. WHEN calculating calorie burn, THE Workout_System SHALL use the formula: Calories = (Duration_minutes × MET × Weight_kg) / 200
2. WHEN intensity is Light, THE Workout_System SHALL use MET values < 3.0 (e.g., slow walking, gentle stretching)
3. WHEN intensity is Moderate, THE Workout_System SHALL use MET values between 3.0 and 5.9 (e.g., brisk walking, recreational cycling)
4. WHEN intensity is Vigorous, THE Workout_System SHALL use MET values ≥ 6.0 (e.g., running, high-intensity interval training)
5. THE Workout_System SHALL use a default weight of 70kg for calorie calculations
6. WHEN displaying calorie burn, THE Workout_System SHALL round to the nearest whole number
7. THE Workout_System SHALL ensure all calorie burn values are non-negative
8. THE Workout_System SHALL store the base MET value for each exercise and adjust it based on selected intensity level

### Requirement 4: Daily Log Integration

**User Story:** As a user, I want to see both food intake and workout calories in my daily summary, so that I can understand my net caloric balance.

#### Acceptance Criteria

1. WHEN displaying a daily log, THE Workout_System SHALL show total calories consumed from food
2. WHEN displaying a daily log, THE Workout_System SHALL show total calories burned from workouts
3. WHEN displaying a daily log, THE Workout_System SHALL calculate and display net calories (consumed - burned)
4. WHEN a workout entry is added to a daily log, THE Workout_System SHALL update the total calories burned immediately
5. WHEN a workout entry is removed from a daily log, THE Workout_System SHALL update the total calories burned immediately
6. THE Workout_System SHALL maintain separate lists for food items and workout entries within each daily log

### Requirement 5: Workout Entry Management

**User Story:** As a user, I want to view, edit, and delete my workout entries, so that I can maintain accurate activity records.

#### Acceptance Criteria

1. WHEN viewing a daily log, THE Workout_System SHALL display all workout entries for that day
2. WHEN displaying a workout entry, THE Workout_System SHALL show exercise name, duration, intensity, calories burned, and timestamp
3. WHEN a user edits a workout entry, THE Workout_System SHALL allow modification of duration and intensity
4. WHEN a workout entry is edited, THE Workout_System SHALL recalculate calories burned automatically
5. WHEN a user deletes a workout entry, THE Workout_System SHALL remove it from the daily log and update totals
6. WHEN a user deletes a workout entry, THE Workout_System SHALL prompt for confirmation before deletion

### Requirement 6: Data Persistence

**User Story:** As a developer, I want workout data persisted using SwiftData, so that it integrates seamlessly with the existing data architecture.

#### Acceptance Criteria

1. THE Workout_System SHALL store workout entries using SwiftData models
2. WHEN a workout entry is saved, THE DataStore SHALL persist it to the database immediately
3. WHEN a daily log is deleted, THE DataStore SHALL cascade delete all associated workout entries
4. THE Workout_System SHALL maintain workout history for 90 days consistent with food tracking retention
5. WHEN the app launches, THE DataStore SHALL load workout entries for the current date
6. THE Workout_System SHALL normalize workout entry dates to midnight for consistent daily log retrieval

### Requirement 7: Historical Workout Data

**User Story:** As a user, I want to view my workout history, so that I can track my exercise patterns over time.

#### Acceptance Criteria

1. WHEN viewing historical data, THE Workout_System SHALL display workout entries grouped by date
2. WHEN displaying historical workout data, THE Workout_System SHALL show total calories burned per day
3. WHEN viewing a past date, THE Workout_System SHALL display all workout entries for that date with full details
4. THE Workout_System SHALL allow navigation between dates in the historical view
5. WHEN no workout entries exist for a date, THE Workout_System SHALL display an appropriate empty state message

### Requirement 8: Input Validation

**User Story:** As a user, I want the system to validate my workout entries, so that I don't accidentally log invalid data.

#### Acceptance Criteria

1. WHEN a user enters duration, THE Workout_System SHALL reject values less than 1 minute
2. WHEN a user enters duration, THE Workout_System SHALL reject values greater than 1440 minutes (24 hours)
3. WHEN a user attempts to save a workout entry, THE Workout_System SHALL validate that all required fields are present
4. WHEN validation fails, THE Workout_System SHALL display a specific error message indicating the problem
5. WHEN validation fails, THE Workout_System SHALL prevent the workout entry from being saved
6. THE Workout_System SHALL reject workout entries with future timestamps

### Requirement 9: User Interface Integration

**User Story:** As a user, I want workout tracking to feel like a natural part of the app, so that I have a seamless experience.

#### Acceptance Criteria

1. WHEN viewing the main calorie view, THE Workout_System SHALL display workout entries in the same list area as food entries
2. WHEN viewing the main calorie view, THE Workout_System SHALL provide a clear action to add a workout
3. WHEN adding a workout, THE Workout_System SHALL present a modal or sheet interface consistent with food entry
4. WHEN displaying workout entries, THE Workout_System SHALL use visual styling consistent with food item rows
5. THE Workout_System SHALL use SF Symbols for workout-related icons
6. WHEN displaying net calories, THE Workout_System SHALL use color coding (green for deficit, red for surplus)
7. THE Workout_System SHALL maintain the existing app navigation patterns and user flows

### Requirement 10: Error Handling

**User Story:** As a user, I want clear feedback when something goes wrong, so that I can correct issues and continue using the app.

#### Acceptance Criteria

1. WHEN a persistence error occurs, THE Workout_System SHALL display a user-friendly error message
2. WHEN a persistence error occurs, THE Workout_System SHALL log the error details for debugging
3. IF a workout entry fails to save, THEN THE Workout_System SHALL retain the user's input for retry
4. WHEN data corruption is detected, THE Workout_System SHALL prevent app crashes and notify the user
5. WHEN loading workout data fails, THE Workout_System SHALL display an empty state with a retry option
6. THE Workout_System SHALL handle concurrent access to workout data safely using the DataStore actor
