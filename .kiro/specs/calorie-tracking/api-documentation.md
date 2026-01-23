# API Documentation: Calorie Tracking Feature

## Overview

This document provides detailed API documentation for the calorie tracking feature's public interfaces, including views, business logic, and data models.

## View Components

### FoodSearchView

**Purpose**: Provides a search interface for finding foods in the FatSecret nutrition database and adding them to the daily log.

**Public Interface**:
```swift
struct FoodSearchView: View {
    @Bindable var tracker: CalorieTracker
}
```

**Parameters**:
- `tracker`: The CalorieTracker instance that manages business logic and state

**Features**:
- **Debounced Search**: Automatically triggers search 500ms after user stops typing
- **Loading States**: Shows spinner during API requests
- **Error Handling**: Displays user-friendly error messages with retry option
- **Empty States**: Helpful messaging when no results found or before search
- **Manual Entry**: Toolbar button to switch to manual food entry
- **Auto-dismiss**: Closes automatically after successful item selection

**Usage Example**:
```swift
@State private var showingSearch = false

Button("Add Food") {
    showingSearch = true
}
.sheet(isPresented: $showingSearch) {
    FoodSearchView(tracker: calorieTracker)
}
```

**State Management**:
- Search query is debounced to avoid excessive API calls
- Results are cleared when query is empty
- Error state is reset on new search attempts
- Loading state prevents multiple concurrent searches

**Navigation**:
- Presented as a sheet from MainCalorieView
- Dismisses on Cancel button tap
- Auto-dismisses after successful food item addition
- Can navigate to ManualEntryView via toolbar button

---

### SearchResultRow

**Purpose**: Displays a single nutrition search result in a list format.

**Public Interface**:
```swift
struct SearchResultRow: View {
    let result: NutritionSearchResult
}
```

**Parameters**:
- `result`: The nutrition search result to display

**Display Elements**:
- Food name (primary text)
- Calorie count (prominent, right-aligned)
- Brand name (secondary text, if available)
- Serving size and unit (secondary text, if available)
- Food icon (visual indicator)

**Usage Example**:
```swift
List(searchResults) { result in
    SearchResultRow(result: result)
        .onTapGesture {
            selectResult(result)
        }
}
```

**Styling**:
- Consistent with FoodItemRow for visual coherence
- Green icon to indicate API source
- Hierarchical text styling (primary/secondary)
- Proper spacing and padding for touch targets

---

### ManualEntryView

**Purpose**: Provides a form-based interface for manually entering food items when API search is unavailable or user prefers manual entry.

**Public Interface**:
```swift
struct ManualEntryView: View {
    @Bindable var tracker: CalorieTracker
}
```

**Parameters**:
- `tracker`: The CalorieTracker instance that manages business logic and state

**Features**:
- **Required Fields**: Food name and calorie value
- **Optional Fields**: Serving size and serving unit
- **Input Validation**: Comprehensive validation before saving
- **Error Display**: Inline validation errors with warning icon
- **Keyboard Management**: Decimal pad for numeric inputs, toolbar with "Done" button
- **Focus State**: Smooth keyboard navigation between fields
- **Loading State**: Disabled UI during save operation
- **Auto-dismiss**: Closes automatically after successful save

**Validation Rules**:
1. **Food Name**: Must not be empty after trimming whitespace
2. **Calories**: 
   - Must not be empty
   - Must be a valid number (parseable as Double)
   - Must be non-negative (>= 0)
3. **Serving Size**: Optional, trimmed if provided
4. **Serving Unit**: Optional, trimmed if provided

**Usage Example**:
```swift
@State private var showingManualEntry = false

Button("Add Manually") {
    showingManualEntry = true
}
.sheet(isPresented: $showingManualEntry) {
    ManualEntryView(tracker: calorieTracker)
}
```

**Form Sections**:
- **Required Information**: Food name and calories
- **Optional Information**: Serving size and unit
- **Validation Errors**: Displayed inline when validation fails

**State Management**:
- Validation errors cleared on new save attempt
- Loading state prevents multiple concurrent saves
- Focus state managed for keyboard navigation
- All inputs trimmed before validation

**Navigation**:
- Presented as a sheet from FoodSearchView toolbar
- Dismisses on Cancel button tap
- Auto-dismisses after successful food item addition

**Error Messages**:
- "Food name is required"
- "Calories value is required"
- "Calories must be a valid number"
- "Calories must be a non-negative number"
- CalorieTracker errors (e.g., "No daily log is currently loaded")

---

### MainCalorieView

**Purpose**: Primary view for displaying daily calorie tracking information and progress.

**Public Interface**:
```swift
struct MainCalorieView: View {
    @Bindable var tracker: CalorieTracker
}
```

**Parameters**:
- `tracker`: The CalorieTracker instance managing daily log state

**Features**:
- **Circular Progress Indicator**: Visual representation of calories consumed vs. goal
- **Color-coded Feedback**: Green (on track), orange (close to goal), red (exceeded)
- **Daily Total Display**: Prominent calorie count in center of progress circle
- **Goal Information**: Shows daily goal and remaining calories
- **Food Items List**: Scrollable list of today's logged items
- **Empty State**: Helpful message when no items logged
- **Add Button**: Toolbar button to open food search

**Usage Example**:
```swift
NavigationStack {
    MainCalorieView(tracker: calorieTracker)
}
```

**Computed Properties**:
- `currentTotal`: Returns current daily calorie total
- `progressPercentage`: Calculates progress as 0.0 to 1.0
- `progressColor`: Determines indicator color based on goal status

**User Interactions**:
- Tap + button: Opens FoodSearchView
- Swipe food item: Deletes item from log
- Tap food item: Opens edit view (placeholder)

---

### FoodItemRow

**Purpose**: Displays a single logged food item with actions.

**Public Interface**:
```swift
struct FoodItemRow: View {
    let item: FoodItem
    let onDelete: () -> Void
    let onEdit: () -> Void
}
```

**Parameters**:
- `item`: The food item to display
- `onDelete`: Callback invoked when user swipes to delete
- `onEdit`: Callback invoked when user taps the row

**Display Elements**:
- Food name (primary text)
- Calorie count (prominent, right-aligned)
- Relative timestamp (e.g., "2 hours ago")
- Serving size and unit (if available)
- Source icon (API vs manual entry)

**Usage Example**:
```swift
List(foodItems) { item in
    FoodItemRow(
        item: item,
        onDelete: {
            Task {
                try? await tracker.removeFoodItem(item)
            }
        },
        onEdit: {
            editingItem = item
        }
    )
}
```

**Gestures**:
- Tap: Triggers onEdit callback
- Swipe left: Shows delete button, triggers onDelete

---

## Business Logic

### CalorieTracker

**Purpose**: Observable class coordinating calorie tracking operations between views, data store, and API client.

**Public Interface**:
```swift
@Observable
@MainActor
class CalorieTracker {
    var currentLog: DailyLog?
    var selectedDate: Date
    var isLoading: Bool
    var errorMessage: String?
    
    init(dataStore: DataStore, apiClient: NutritionAPIClient, selectedDate: Date = Date())
    
    func loadLog(for date: Date) async throws
    func getCurrentDailyTotal() -> Double
    func getRemainingCalories() -> Double?
    func addFoodItem(_ item: FoodItem) async throws
    func removeFoodItem(_ item: FoodItem) async throws
    func updateFoodItem(_ item: FoodItem) async throws
    func setDailyGoal(_ calories: Double) async throws
    func searchFood(query: String) async throws -> [NutritionSearchResult]
}
```

#### Properties

**currentLog**: `DailyLog?`
- The currently loaded daily log
- Nil if no log has been loaded yet
- Updates trigger UI refresh via @Observable

**selectedDate**: `Date`
- The date for which the current log is loaded
- Defaults to today's date
- Used for date-based log retrieval

**isLoading**: `Bool`
- Indicates whether an async operation is in progress
- Used to show loading indicators in UI

**errorMessage**: `String?`
- User-friendly error message for display
- Nil when no error
- Set automatically by operations that fail

#### Methods

**loadLog(for:)**
```swift
func loadLog(for date: Date) async throws
```
Loads the daily log for a specific date, creating a new one if it doesn't exist.

- **Parameters**:
  - `date`: The date to load the log for
- **Throws**: Persistence errors from DataStore
- **Side Effects**: Updates `currentLog`, `selectedDate`, `isLoading`, and `errorMessage`

**Usage**:
```swift
Task {
    try await tracker.loadLog(for: Date())
}
```

---

**getCurrentDailyTotal()**
```swift
func getCurrentDailyTotal() -> Double
```
Gets the current daily total calories.

- **Returns**: Total calories for the current log, or 0.0 if no log is loaded
- **Thread Safety**: Must be called from MainActor

**Usage**:
```swift
let total = tracker.getCurrentDailyTotal()
Text("\(Int(total)) calories")
```

---

**getRemainingCalories()**
```swift
func getRemainingCalories() -> Double?
```
Gets the remaining calories until the daily goal.

- **Returns**: Remaining calories, or nil if no goal is set
- **Note**: Can be negative if goal is exceeded

**Usage**:
```swift
if let remaining = tracker.getRemainingCalories() {
    Text("Remaining: \(Int(remaining)) cal")
        .foregroundColor(remaining >= 0 ? .green : .red)
}
```

---

**addFoodItem(_:)**
```swift
func addFoodItem(_ item: FoodItem) async throws
```
Adds a food item to the current daily log.

- **Parameters**:
  - `item`: The food item to add
- **Throws**: 
  - `CalorieTrackerError.noCurrentLog` if no log is loaded
  - Persistence errors from DataStore
- **Side Effects**: Updates `currentLog` and persists changes

**Usage**:
```swift
let foodItem = FoodItem(
    name: "Apple",
    calories: 95,
    source: .manual
)

Task {
    do {
        try await tracker.addFoodItem(foodItem)
    } catch {
        print("Failed to add item: \(error)")
    }
}
```

---

**removeFoodItem(_:)**
```swift
func removeFoodItem(_ item: FoodItem) async throws
```
Removes a food item from the current daily log.

- **Parameters**:
  - `item`: The food item to remove
- **Throws**: 
  - `CalorieTrackerError.noCurrentLog` if no log is loaded
  - Persistence errors from DataStore
- **Side Effects**: Updates `currentLog` and persists changes

**Usage**:
```swift
Task {
    try await tracker.removeFoodItem(selectedItem)
}
```

---

**updateFoodItem(_:)**
```swift
func updateFoodItem(_ item: FoodItem) async throws
```
Updates an existing food item in the current daily log.

- **Parameters**:
  - `item`: The food item with updated values
- **Throws**: 
  - `CalorieTrackerError.noCurrentLog` if no log is loaded
  - Persistence errors from DataStore
- **Side Effects**: Updates `currentLog` and persists changes

**Usage**:
```swift
var updatedItem = existingItem
updatedItem.calories = 200

Task {
    try await tracker.updateFoodItem(updatedItem)
}
```

---

**setDailyGoal(_:)**
```swift
func setDailyGoal(_ calories: Double) async throws
```
Sets the daily calorie goal for the current log.

- **Parameters**:
  - `calories`: The target calorie goal (must be positive)
- **Throws**: 
  - `CalorieTrackerError.noCurrentLog` if no log is loaded
  - `CalorieTrackerError.invalidGoal` if calories <= 0
  - Persistence errors from DataStore
- **Side Effects**: Updates `currentLog` and persists changes

**Usage**:
```swift
Task {
    try await tracker.setDailyGoal(2000)
}
```

---

**searchFood(query:)**
```swift
func searchFood(query: String) async throws -> [NutritionSearchResult]
```
Searches for food items using the nutrition API.

- **Parameters**:
  - `query`: The search query string
- **Returns**: Array of nutrition search results (empty if query is empty)
- **Throws**: `NutritionAPIError` if the search fails
- **Side Effects**: Updates `errorMessage` on failure

**Usage**:
```swift
Task {
    do {
        let results = try await tracker.searchFood(query: "chicken")
        // Display results
    } catch let error as NutritionAPIError {
        // Handle API error
        print(error.errorDescription ?? "Unknown error")
    }
}
```

---

## Data Models

### FoodItem

**Purpose**: Represents a single food entry with nutritional data.

**Definition**:
```swift
@Model
final class FoodItem {
    var id: UUID
    var name: String
    var calories: Double
    var timestamp: Date
    var servingSize: String?
    var servingUnit: String?
    var source: FoodItemSource
    
    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        timestamp: Date = Date(),
        servingSize: String? = nil,
        servingUnit: String? = nil,
        source: FoodItemSource = .manual
    )
}
```

**Properties**:
- `id`: Unique identifier (auto-generated)
- `name`: Food name (required)
- `calories`: Calorie count (required, must be non-negative)
- `timestamp`: When the food was logged (defaults to now)
- `servingSize`: Optional serving size (e.g., "100")
- `servingUnit`: Optional serving unit (e.g., "g", "cup")
- `source`: Origin of the data (.api or .manual)

**Usage**:
```swift
// From API
let apiItem = FoodItem(
    name: "Chicken Breast",
    calories: 165,
    servingSize: "100",
    servingUnit: "g",
    source: .api
)

// Manual entry
let manualItem = FoodItem(
    name: "Homemade Soup",
    calories: 250,
    source: .manual
)
```

---

### DailyLog

**Purpose**: Container for a day's worth of food items with computed totals.

**Definition**:
```swift
@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var foodItems: [FoodItem]
    var dailyGoal: Double?
    
    var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }
    
    var remainingCalories: Double? {
        guard let goal = dailyGoal else { return nil }
        return goal - totalCalories
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        foodItems: [FoodItem] = [],
        dailyGoal: Double? = nil
    )
}
```

**Properties**:
- `id`: Unique identifier (auto-generated)
- `date`: Date for this log (normalized to midnight)
- `foodItems`: Array of food items logged for this day
- `dailyGoal`: Optional calorie goal for the day

**Computed Properties**:
- `totalCalories`: Sum of all food item calories
- `remainingCalories`: Goal minus total (nil if no goal set)

**Usage**:
```swift
let log = DailyLog(
    date: Date(),
    dailyGoal: 2000
)

log.foodItems.append(foodItem)
print("Total: \(log.totalCalories)")
print("Remaining: \(log.remainingCalories ?? 0)")
```

---

### NutritionSearchResult

**Purpose**: Represents a search result from the nutrition API.

**Definition**:
```swift
struct NutritionSearchResult: Identifiable {
    let id: String
    let name: String
    let calories: Double
    let servingSize: String?
    let servingUnit: String?
    let brandName: String?
}
```

**Properties**:
- `id`: Unique identifier from API
- `name`: Food name
- `calories`: Calorie count per serving
- `servingSize`: Optional serving size
- `servingUnit`: Optional serving unit
- `brandName`: Optional brand name

**Conversion to FoodItem**:
```swift
func toFoodItem() -> FoodItem {
    FoodItem(
        name: name,
        calories: calories,
        servingSize: servingSize,
        servingUnit: servingUnit,
        source: .api
    )
}
```

---

## Error Handling

### CalorieTrackerError

```swift
enum CalorieTrackerError: Error, LocalizedError {
    case noCurrentLog
    case invalidGoal
    
    var errorDescription: String? {
        switch self {
        case .noCurrentLog:
            return "No daily log is currently loaded. Please load a log first."
        case .invalidGoal:
            return "Daily goal must be a positive number."
        }
    }
}
```

### NutritionAPIError

```swift
enum NutritionAPIError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case invalidData
    case rateLimitExceeded
    case timeout
    
    var errorDescription: String? {
        // User-friendly error messages
    }
}
```

---

## Best Practices

### View Usage

1. **Always provide CalorieTracker**: Views require a properly initialized CalorieTracker instance
2. **Handle loading states**: Check `isLoading` property for UI feedback
3. **Display error messages**: Show `errorMessage` to users when operations fail
4. **Use Task for async operations**: Wrap async calls in Task blocks

### Business Logic

1. **Load log before operations**: Call `loadLog(for:)` before adding/removing items
2. **Handle errors gracefully**: Catch and display user-friendly error messages
3. **Validate input**: Check for positive values, non-empty strings, etc.
4. **Use MainActor**: CalorieTracker must be accessed from main thread

### Data Models

1. **Validate calories**: Ensure non-negative values before creating FoodItem
2. **Normalize dates**: DataStore automatically normalizes dates to midnight
3. **Set source correctly**: Use `.api` for API results, `.manual` for user input
4. **Provide serving info**: Include serving size/unit when available for better UX

---

## Testing

### Unit Testing

```swift
func testAddFoodItem() async throws {
    let tracker = CalorieTracker(
        dataStore: mockDataStore,
        apiClient: mockAPIClient
    )
    
    try await tracker.loadLog(for: Date())
    
    let item = FoodItem(name: "Test", calories: 100)
    try await tracker.addFoodItem(item)
    
    XCTAssertEqual(tracker.getCurrentDailyTotal(), 100)
}
```

### Preview Testing

```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DailyLog.self, FoodItem.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let tracker = CalorieTracker(
        dataStore: DataStore(modelContext: context),
        apiClient: NutritionAPIClient(
            consumerKey: "preview",
            consumerSecret: "preview"
        )
    )
    
    return FoodSearchView(tracker: tracker)
}
```

---

## Migration Notes

### Future Enhancements

1. **ManualEntryView**: Will be added in task 8
2. **HistoricalView**: Will be added in task 10
3. **GoalSettingView**: Will be added in task 11
4. **Edit functionality**: Currently placeholder in FoodItemRow

### Breaking Changes

None - this is the initial implementation of the search feature.
