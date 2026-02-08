# Design Document: Workout Tracking

## Introduction

This document provides the technical design for implementing workout and exercise tracking functionality in the CountMe iOS application. The design integrates seamlessly with the existing SwiftData-based architecture, following established patterns for data persistence, UI components, and Firebase synchronization.

## Architecture Overview

### Component Structure

```
Views (SwiftUI)
    ↓
Services (Business Logic)
    ↓
DataStore (Actor-based SwiftData)
    ↓
Models (SwiftData @Model)
```

The workout tracking system follows the existing MVVM architecture with actor-based concurrency for thread-safe data operations.

## Data Models

### WorkoutEntry Model

**Location**: `CountMe/Models/WorkoutEntry.swift`

```swift
@Model
final class WorkoutEntry: SyncableEntity {
    var _id: UUID
    var exerciseType: String
    var exerciseCategory: ExerciseCategory
    var duration: Int  // minutes
    var intensity: IntensityLevel
    var caloriesBurned: Double
    var timestamp: Date
    var baseMET: Double
    
    // Relationship to DailyLog
    var dailyLog: DailyLog?
    
    // SyncableEntity properties
    var userId: String = ""
    var lastModified: Date = Date()
    var syncStatus: SyncStatus = .pendingUpload
    
    var id: String {
        _id.uuidString
    }
}
```

**Key Design Decisions**:
- Duration stored as Int (minutes) for simplicity and validation
- Calories burned stored as computed value to avoid recalculation
- BaseMET stored to support intensity adjustments
- Follows SyncableEntity pattern for Firebase integration

### ExerciseCategory Enum

```swift
enum ExerciseCategory: String, Codable {
    case cardio = "Cardio"
    case strength = "Strength"
    case sports = "Sports"
    case flexibility = "Flexibility"
}
```

### IntensityLevel Enum

```swift
enum IntensityLevel: String, Codable {
    case light = "Light"
    case moderate = "Moderate"
    case vigorous = "Vigorous"
    
    var metMultiplier: Double {
        switch self {
        case .light: return 0.5      // < 3.0 METs
        case .moderate: return 1.0   // 3.0-5.9 METs
        case .vigorous: return 1.5   // ≥ 6.0 METs
        }
    }
}
```

### Exercise Library Structure

**Location**: `CountMe/Models/Exercise.swift`

```swift
struct Exercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: ExerciseCategory
    let baseMET: Double
    let description: String?
}
```

**Predefined Exercise Library** (minimum 20 exercises):

**Cardio**:
- Running (MET: 8.0)
- Walking (MET: 3.5)
- Cycling (MET: 6.0)
- Swimming (MET: 7.0)
- Jump Rope (MET: 10.0)
- Rowing (MET: 6.0)

**Strength**:
- Weightlifting (MET: 5.0)
- Bodyweight Exercises (MET: 4.0)
- Resistance Training (MET: 5.0)
- CrossFit (MET: 8.0)

**Sports**:
- Basketball (MET: 6.5)
- Soccer (MET: 7.0)
- Tennis (MET: 7.0)
- Volleyball (MET: 4.0)
- Golf (MET: 4.5)

**Flexibility**:
- Yoga (MET: 2.5)
- Stretching (MET: 2.3)
- Pilates (MET: 3.0)
- Tai Chi (MET: 3.0)
- Meditation/Breathing (MET: 1.5)

### DailyLog Extension

**Modification**: Extend existing `DailyLog` model to include workout entries.

```swift
@Model
final class DailyLog: SyncableEntity {
    // ... existing properties ...
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.dailyLog)
    var workoutEntries: [WorkoutEntry] = []
    
    var totalCaloriesBurned: Double {
        workoutEntries.reduce(0) { $0 + $1.caloriesBurned }
    }
    
    var netCalories: Double {
        totalCalories - totalCaloriesBurned
    }
}
```

## Business Logic

### CalorieBurnCalculator

**Location**: `CountMe/Services/CalorieBurnCalculator.swift`

```swift
struct CalorieBurnCalculator {
    static let defaultWeight: Double = 70.0  // kg
    
    static func calculateCaloriesBurned(
        duration: Int,
        baseMET: Double,
        intensity: IntensityLevel,
        weight: Double = defaultWeight
    ) -> Double {
        let adjustedMET = baseMET * intensity.metMultiplier
        let calories = (Double(duration) * adjustedMET * weight) / 200.0
        return max(0, calories.rounded())
    }
}
```

**Formula Explanation**:
- Standard MET formula: Calories = (Duration × MET × Weight) / 200
- Intensity multiplier adjusts base MET value
- Result rounded to nearest whole number
- Non-negative constraint enforced

### ExerciseLibrary Service

**Location**: `CountMe/Services/ExerciseLibrary.swift`

```swift
class ExerciseLibrary {
    static let shared = ExerciseLibrary()
    
    private let exercises: [Exercise] = [
        // Predefined exercise list
    ]
    
    func getAllExercises() -> [Exercise] {
        exercises
    }
    
    func getExercises(by category: ExerciseCategory) -> [Exercise] {
        exercises.filter { $0.category == category }
    }
    
    func searchExercises(query: String) -> [Exercise] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { 
            $0.name.localizedCaseInsensitiveContains(query) 
        }
    }
}
```

### DataStore Extensions

**Location**: `CountMe/Services/DataStore.swift` (extend existing actor)

```swift
extension DataStore {
    // MARK: - Workout Entry Operations
    
    func fetchWorkoutEntries(for date: Date) async throws -> [WorkoutEntry] {
        let normalizedDate = normalizeDate(date)
        
        guard let log = try await fetchDailyLog(for: normalizedDate) else {
            return []
        }
        
        return log.workoutEntries
    }
    
    func saveWorkoutEntry(_ entry: WorkoutEntry, to log: DailyLog) async throws {
        entry.timestamp = Date()
        log.workoutEntries.append(entry)
        try modelContext.save()
    }
    
    func deleteWorkoutEntry(_ entry: WorkoutEntry, from log: DailyLog) async throws {
        if let index = log.workoutEntries.firstIndex(where: { $0.id == entry.id }) {
            log.workoutEntries.remove(at: index)
            try modelContext.save()
        }
    }
    
    func updateWorkoutEntry(_ entry: WorkoutEntry) async throws {
        try modelContext.save()
    }
}
```

## User Interface Components

### WorkoutEntryView

**Location**: `CountMe/Views/WorkoutEntryView.swift`

**Purpose**: Modal sheet for creating/editing workout entries

**Components**:
- Exercise picker (searchable list)
- Duration input (numeric, minutes)
- Intensity selector (segmented control)
- Calories burned display (read-only, auto-calculated)
- Save/Cancel buttons

**Validation**:
- Duration: 1-1440 minutes
- All fields required
- No future timestamps

### WorkoutEntryRow

**Location**: `CountMe/Views/WorkoutEntryRow.swift`

**Purpose**: Display workout entry in daily log list

**Layout**:
```
[Icon] Exercise Name                    -XXX cal
       Duration • Intensity             HH:MM
```

**Styling**:
- Consistent with FoodItemRow
- SF Symbol: "figure.run" (or category-specific)
- Negative calorie value (red text)
- Swipe actions: Edit, Delete

### MainCalorieView Extension

**Modification**: Extend existing view to display workout entries

**Changes**:
- Add "Add Workout" button alongside "Add Food"
- Display workout entries in same list as food items
- Show total calories burned section
- Display net calories with color coding:
  - Green: Net negative (calorie deficit)
  - Red: Net positive (calorie surplus)
  - Gray: Net zero

**Layout**:
```
Daily Summary
├── Consumed: XXXX cal
├── Burned: XXX cal
└── Net: ±XXX cal (colored)

Today's Entries
├── [Food items]
└── [Workout entries]
```

### HistoricalView Extension

**Modification**: Add workout data to historical view

**Changes**:
- Display workout entries for past dates
- Show daily calories burned totals
- Maintain existing date navigation

## Input Validation

### WorkoutEntryValidator

**Location**: `CountMe/Utilities/WorkoutEntryValidator.swift`

```swift
struct WorkoutEntryValidator {
    enum ValidationError: LocalizedError {
        case durationTooShort
        case durationTooLong
        case missingExercise
        case missingIntensity
        case futureTimestamp
        
        var errorDescription: String? {
            switch self {
            case .durationTooShort:
                return "Duration must be at least 1 minute"
            case .durationTooLong:
                return "Duration cannot exceed 24 hours"
            case .missingExercise:
                return "Please select an exercise"
            case .missingIntensity:
                return "Please select an intensity level"
            case .futureTimestamp:
                return "Cannot log future workouts"
            }
        }
    }
    
    static func validate(
        exercise: Exercise?,
        duration: Int,
        intensity: IntensityLevel?,
        timestamp: Date
    ) throws {
        guard exercise != nil else {
            throw ValidationError.missingExercise
        }
        
        guard intensity != nil else {
            throw ValidationError.missingIntensity
        }
        
        guard duration >= 1 else {
            throw ValidationError.durationTooShort
        }
        
        guard duration <= 1440 else {
            throw ValidationError.durationTooLong
        }
        
        guard timestamp <= Date() else {
            throw ValidationError.futureTimestamp
        }
    }
}
```

## Firebase Synchronization

### WorkoutEntry Firestore Integration

**Extension**: Add Firestore serialization to WorkoutEntry

```swift
extension WorkoutEntry {
    func toFirestoreData() -> [String: Any] {
        [
            "id": _id.uuidString,
            "exerciseType": exerciseType,
            "exerciseCategory": exerciseCategory.rawValue,
            "duration": duration,
            "intensity": intensity.rawValue,
            "caloriesBurned": caloriesBurned,
            "timestamp": Timestamp(date: timestamp),
            "baseMET": baseMET,
            "userId": userId,
            "lastModified": Timestamp(date: lastModified),
            "syncStatus": syncStatus.rawValue
        ]
    }
    
    static func fromFirestoreData(_ data: [String: Any]) throws -> WorkoutEntry {
        // Deserialization logic
    }
}
```

### DailyLog Firestore Update

**Modification**: Update DailyLog serialization to include workout entries

```swift
extension DailyLog {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            // ... existing fields ...
            "workoutEntryIds": workoutEntries.map { $0.id },
            "totalCaloriesBurned": totalCaloriesBurned
        ]
        return data
    }
}
```

## Error Handling

### Error Types

```swift
enum WorkoutError: LocalizedError {
    case persistenceError(Error)
    case validationError(WorkoutEntryValidator.ValidationError)
    case calculationError
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .persistenceError(let error):
            return "Failed to save workout: \(error.localizedDescription)"
        case .validationError(let error):
            return error.errorDescription
        case .calculationError:
            return "Failed to calculate calories burned"
        case .dataCorruption:
            return "Workout data is corrupted"
        }
    }
}
```

### Error Handling Strategy

1. **Validation Errors**: Display inline in WorkoutEntryView, prevent save
2. **Persistence Errors**: Show alert with retry option, retain user input
3. **Calculation Errors**: Log error, use fallback value (0 calories)
4. **Data Corruption**: Log error, skip corrupted entry, notify user

## Testing Strategy

### Unit Tests

**Location**: `CountMeTests/Services/CalorieBurnCalculatorTests.swift`

- Test calorie calculation formula
- Test intensity multipliers
- Test rounding behavior
- Test non-negative constraint
- Test edge cases (0 duration, extreme values)

**Location**: `CountMeTests/Services/ExerciseLibraryTests.swift`

- Test exercise count (≥20)
- Test category filtering
- Test search functionality
- Test case-insensitive search

**Location**: `CountMeTests/Utilities/WorkoutEntryValidatorTests.swift`

- Test duration validation (min/max)
- Test required field validation
- Test future timestamp rejection
- Test error messages

### Property-Based Tests

**Location**: `CountMeTests/Models/WorkoutEntryPropertyTests.swift`


**Property 1: Calorie Calculation Non-Negativity**
```swift
// For all valid inputs, calories burned ≥ 0
@Test func calorieCalculationNonNegativity() {
    // Generate random duration, MET, intensity, weight
    // Assert: result >= 0
}
```

**Property 2: Duration Bounds**
```swift
// For all workout entries, 1 ≤ duration ≤ 1440
@Test func durationWithinBounds() {
    // Generate random workout entries
    // Assert: 1 <= entry.duration <= 1440
}
```

**Property 3: Daily Log Totals Consistency**
```swift
// Sum of individual workout calories = total calories burned
@Test func dailyLogTotalsConsistency() {
    // Generate random workout entries
    // Assert: sum(entries.calories) == log.totalCaloriesBurned
}
```

**Property 4: Net Calories Calculation**
```swift
// Net calories = consumed - burned
@Test func netCaloriesCalculation() {
    // Generate random food items and workout entries
    // Assert: log.netCalories == log.totalCalories - log.totalCaloriesBurned
}
```

## Implementation Plan

### Phase 1: Data Models & Core Logic
1. Create WorkoutEntry model
2. Create Exercise, ExerciseCategory, IntensityLevel enums
3. Implement CalorieBurnCalculator
4. Implement ExerciseLibrary
5. Extend DailyLog model
6. Write unit tests for core logic

### Phase 2: Data Persistence
1. Extend DataStore with workout operations
2. Implement date normalization for workouts
3. Add cascade deletion support
4. Write persistence tests

### Phase 3: User Interface
1. Create WorkoutEntryView
2. Create WorkoutEntryRow
3. Extend MainCalorieView
4. Extend HistoricalView
5. Implement input validation
6. Write UI tests

### Phase 4: Firebase Integration
1. Add Firestore serialization to WorkoutEntry
2. Update DailyLog Firestore methods
3. Test sync functionality
4. Handle offline scenarios

### Phase 5: Testing & Polish
1. Write property-based tests
2. Verify 90%+ code coverage
3. Test error handling paths
4. Performance testing
5. Accessibility review

## Correctness Properties

### Property 1: Calorie Calculation Accuracy
**Validates: Requirement 3.1**

For all workout entries with valid inputs (duration > 0, MET > 0, weight > 0):
```
calories = round((duration × MET × intensity_multiplier × weight) / 200)
```

### Property 2: Non-Negative Calories
**Validates: Requirement 3.7**

For all workout entries:
```
caloriesBurned ≥ 0
```

### Property 3: Duration Bounds
**Validates: Requirements 8.1, 8.2**

For all workout entries:
```
1 ≤ duration ≤ 1440
```

### Property 4: Daily Log Totals Consistency
**Validates: Requirements 4.2, 4.4, 4.5**

For all daily logs:
```
totalCaloriesBurned = sum(workoutEntries.map(\.caloriesBurned))
```

### Property 5: Net Calories Calculation
**Validates: Requirement 4.3**

For all daily logs:
```
netCalories = totalCalories - totalCaloriesBurned
```

### Property 6: Intensity MET Adjustment
**Validates: Requirements 3.2, 3.3, 3.4, 3.8**

For all workout entries:
- Light intensity: effective MET < 3.0
- Moderate intensity: 3.0 ≤ effective MET < 6.0
- Vigorous intensity: effective MET ≥ 6.0

### Property 7: Date Normalization
**Validates: Requirement 6.6**

For all workout entries in a daily log:
```
normalizeDate(entry.timestamp) == log.date
```

### Property 8: Cascade Deletion
**Validates: Requirement 6.3**

When a daily log is deleted:
```
all associated workout entries are also deleted
```

### Property 9: Timestamp Validity
**Validates: Requirement 8.6**

For all workout entries:
```
entry.timestamp ≤ Date()
```

### Property 10: Exercise Library Completeness
**Validates: Requirement 1.1**

```
ExerciseLibrary.shared.getAllExercises().count ≥ 20
```

## Performance Considerations

### Data Loading
- Workout entries loaded with daily log (single query)
- Exercise library loaded once at app launch (static data)
- Historical data paginated by date range

### Calculation Optimization
- Calories calculated once on save, not on every display
- Daily totals computed via SwiftData relationships
- No redundant calculations in UI layer

### Memory Management
- Exercise library singleton (shared instance)
- Workout entries released when daily log dismissed
- No caching of historical workout data

## Accessibility

### VoiceOver Support
- Workout entry rows: "Exercise name, duration, intensity, calories burned"
- Add workout button: "Add workout entry"
- Intensity selector: "Light intensity", "Moderate intensity", "Vigorous intensity"

### Dynamic Type
- All text scales with system font size
- Minimum touch target: 44x44 points
- Layout adapts to larger text sizes

### Color Contrast
- Net calories color coding meets WCAG AA standards
- Icons have sufficient contrast
- Error messages clearly visible

## Security & Privacy

### Data Protection
- Workout data encrypted at rest (SwiftData default)
- Firebase sync uses authenticated connections
- No third-party analytics for workout data

### User Control
- Users can delete individual workout entries
- Users can delete entire daily logs (cascade deletes workouts)
- Account deletion removes all workout data

## Future Enhancements

### Potential Features (Out of Scope)
- Custom exercise creation
- User-specific weight tracking
- Heart rate integration
- GPS tracking for outdoor activities
- Workout templates/routines
- Social sharing
- Achievement badges
- Weekly/monthly statistics

### Extensibility Points
- Exercise library can be extended with custom exercises
- Calorie calculation can incorporate user weight
- Additional workout metrics (heart rate, distance) can be added
- Integration with HealthKit for automatic tracking

## Conclusion

This design provides a comprehensive, testable implementation of workout tracking that integrates seamlessly with CountMe's existing architecture. The design follows established patterns for data persistence, UI components, and Firebase synchronization while maintaining code quality standards with 90%+ test coverage and property-based testing.
