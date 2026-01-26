# API Documentation: AI-Powered Recipe Tracking

## Overview

This document provides comprehensive API documentation for the AI-Powered Recipe Tracking feature, including all public interfaces, usage examples, and integration patterns.

## DataStore Extensions

The DataStore actor has been extended with CustomMeal persistence operations, following the same actor-based concurrency patterns established in the calorie tracking feature.

### Custom Meal Operations

All CustomMeal operations are asynchronous and throw SwiftData errors if persistence operations fail. These methods maintain thread-safety through the actor model.

---

#### `fetchAllCustomMeals()`

Retrieves all saved custom meals sorted by most recently used.

**Signature:**
```swift
func fetchAllCustomMeals() async throws -> [CustomMeal]
```

**Parameters:**
- None

**Returns:**
- `[CustomMeal]`: Array of custom meals sorted by `lastUsedAt` in descending order (most recent first)

**Throws:**
- SwiftData errors if fetch operation fails

**Usage Example:**
```swift
let dataStore = DataStore(modelContext: modelContext)

do {
    let meals = try await dataStore.fetchAllCustomMeals()
    print("Found \(meals.count) custom meals")
    
    // Display meals in UI
    for meal in meals {
        print("\(meal.name): \(meal.totalCalories) calories")
    }
} catch {
    print("Failed to fetch custom meals: \(error)")
}
```

**Requirements Validated:**
- Requirement 2.1: Custom meal persistence
- Requirement 2.2: Sort by most recently used

**Related Properties:**
- Property 4: Custom Meal Sort Order

---

#### `fetchCustomMeal(id:)`

Retrieves a specific custom meal by its unique identifier.

**Signature:**
```swift
func fetchCustomMeal(id: UUID) async throws -> CustomMeal?
```

**Parameters:**
- `id: UUID` - The unique identifier of the custom meal to retrieve

**Returns:**
- `CustomMeal?`: The custom meal with the specified ID, or `nil` if not found

**Throws:**
- SwiftData errors if fetch operation fails

**Usage Example:**
```swift
let dataStore = DataStore(modelContext: modelContext)
let mealId = UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!

do {
    if let meal = try await dataStore.fetchCustomMeal(id: mealId) {
        print("Found meal: \(meal.name)")
        print("Ingredients: \(meal.ingredients.count)")
    } else {
        print("Meal not found")
    }
} catch {
    print("Failed to fetch custom meal: \(error)")
}
```

**Requirements Validated:**
- Requirement 2.1: Custom meal retrieval

---

#### `saveCustomMeal(_:)`

Saves a new custom meal to persistent storage.

**Signature:**
```swift
func saveCustomMeal(_ meal: CustomMeal) async throws
```

**Parameters:**
- `meal: CustomMeal` - The custom meal to persist with all ingredient details

**Returns:**
- `Void`

**Throws:**
- SwiftData errors if save operation fails

**Usage Example:**
```swift
let dataStore = DataStore(modelContext: modelContext)

// Create ingredients
let ingredient1 = Ingredient(
    name: "Chicken Breast",
    quantity: 6,
    unit: "oz",
    calories: 187,
    protein: 35,
    carbohydrates: 0,
    fats: 4
)

let ingredient2 = Ingredient(
    name: "White Rice",
    quantity: 1,
    unit: "cup",
    calories: 206,
    protein: 4,
    carbohydrates: 45,
    fats: 0.4
)

// Create custom meal
let meal = CustomMeal(
    name: "Chicken and Rice",
    ingredients: [ingredient1, ingredient2]
)

do {
    try await dataStore.saveCustomMeal(meal)
    print("Custom meal saved successfully")
    print("Total calories: \(meal.totalCalories)")
} catch {
    print("Failed to save custom meal: \(error)")
}
```

**Requirements Validated:**
- Requirement 2.1: Custom meal persistence

**Related Properties:**
- Property 3: Custom Meal Persistence Round-Trip

---

#### `updateCustomMeal(_:)`

Updates an existing custom meal in persistent storage.

**Signature:**
```swift
func updateCustomMeal(_ meal: CustomMeal) async throws
```

**Parameters:**
- `meal: CustomMeal` - The custom meal with updated values (name, ingredients, timestamps)

**Returns:**
- `Void`

**Throws:**
- SwiftData errors if save operation fails

**Usage Example:**
```swift
let dataStore = DataStore(modelContext: modelContext)

do {
    // Fetch existing meal
    guard var meal = try await dataStore.fetchCustomMeal(id: mealId) else {
        print("Meal not found")
        return
    }
    
    // Update meal properties
    meal.name = "Updated Chicken and Rice"
    
    // Add a new ingredient
    let newIngredient = Ingredient(
        name: "Broccoli",
        quantity: 1,
        unit: "cup",
        calories: 31,
        protein: 2.5,
        carbohydrates: 6,
        fats: 0.3
    )
    meal.ingredients.append(newIngredient)
    
    // Save changes
    try await dataStore.updateCustomMeal(meal)
    print("Custom meal updated successfully")
} catch {
    print("Failed to update custom meal: \(error)")
}
```

**Important Notes:**
- Updating a custom meal template does NOT affect previously logged meal instances in daily logs
- This maintains data independence (Property 6: Custom Meal Data Independence)

**Requirements Validated:**
- Requirement 2.4: Custom meal updates
- Requirement 9.3: Edit saved custom meals

**Related Properties:**
- Property 6: Custom Meal Data Independence

---

#### `deleteCustomMeal(_:)`

Deletes a custom meal and all associated ingredients from persistent storage.

**Signature:**
```swift
func deleteCustomMeal(_ meal: CustomMeal) async throws
```

**Parameters:**
- `meal: CustomMeal` - The custom meal to delete

**Returns:**
- `Void`

**Throws:**
- SwiftData errors if delete operation fails

**Usage Example:**
```swift
let dataStore = DataStore(modelContext: modelContext)

do {
    // Fetch meal to delete
    guard let meal = try await dataStore.fetchCustomMeal(id: mealId) else {
        print("Meal not found")
        return
    }
    
    // Delete meal (cascade deletes all ingredients)
    try await dataStore.deleteCustomMeal(meal)
    print("Custom meal deleted successfully")
} catch {
    print("Failed to delete custom meal: \(error)")
}
```

**Important Notes:**
- SwiftData automatically handles cascade deletion of all associated ingredients
- No orphaned ingredient records will remain after deletion
- Previously logged meal instances in daily logs are NOT affected

**Requirements Validated:**
- Requirement 2.3: Custom meal deletion with cascade delete

**Related Properties:**
- Property 5: Cascade Deletion Completeness
- Property 6: Custom Meal Data Independence

---

#### `searchCustomMeals(query:)`

Searches custom meals by name with case-insensitive filtering.

**Signature:**
```swift
func searchCustomMeals(query: String) async throws -> [CustomMeal]
```

**Parameters:**
- `query: String` - The search string to filter meal names (case-insensitive)

**Returns:**
- `[CustomMeal]`: Array of matching custom meals sorted by `lastUsedAt` in descending order

**Throws:**
- SwiftData errors if fetch operation fails

**Behavior:**
- Empty or whitespace-only queries return all custom meals
- Search is case-insensitive
- Uses `localizedStandardContains` for natural language matching
- Results maintain sort order (most recently used first)

**Usage Example:**
```swift
let dataStore = DataStore(modelContext: modelContext)

do {
    // Search for meals containing "chicken"
    let results = try await dataStore.searchCustomMeals(query: "chicken")
    print("Found \(results.count) meals matching 'chicken'")
    
    for meal in results {
        print("- \(meal.name)")
    }
    
    // Empty query returns all meals
    let allMeals = try await dataStore.searchCustomMeals(query: "")
    print("Total meals: \(allMeals.count)")
} catch {
    print("Failed to search custom meals: \(error)")
}
```

**Real-Time Search Example:**
```swift
struct CustomMealsLibraryView: View {
    @State private var searchQuery = ""
    @State private var searchResults: [CustomMeal] = []
    let dataStore: DataStore
    
    var body: some View {
        VStack {
            TextField("Search meals...", text: $searchQuery)
                .onChange(of: searchQuery) { _, newValue in
                    Task {
                        searchResults = try await dataStore.searchCustomMeals(query: newValue)
                    }
                }
            
            List(searchResults) { meal in
                Text(meal.name)
            }
        }
    }
}
```

**Requirements Validated:**
- Requirement 12.1: Case-insensitive search
- Requirement 12.2: Clear search returns all meals
- Requirement 12.3: Real-time search updates
- Requirement 12.5: Maintain sort order in search results

**Related Properties:**
- Property 20: Custom Meal Search Correctness

---

## Integration Patterns

### Complete Custom Meal Workflow

Here's a complete example showing the typical workflow for creating, saving, and using a custom meal:

```swift
import SwiftUI
import SwiftData

@Observable
class CustomMealManager {
    private let dataStore: DataStore
    var savedMeals: [CustomMeal] = []
    var isLoading = false
    var errorMessage: String?
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    // Load all meals on initialization
    func loadAllMeals() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            savedMeals = try await dataStore.fetchAllCustomMeals()
        } catch {
            errorMessage = "Failed to load meals: \(error.localizedDescription)"
        }
    }
    
    // Create and save a new meal
    func createMeal(name: String, ingredients: [Ingredient]) async {
        let meal = CustomMeal(name: name, ingredients: ingredients)
        
        do {
            try await dataStore.saveCustomMeal(meal)
            savedMeals.insert(meal, at: 0) // Add to front (most recent)
        } catch {
            errorMessage = "Failed to save meal: \(error.localizedDescription)"
        }
    }
    
    // Update an existing meal
    func updateMeal(_ meal: CustomMeal) async {
        do {
            try await dataStore.updateCustomMeal(meal)
            // Reload meals to reflect changes
            await loadAllMeals()
        } catch {
            errorMessage = "Failed to update meal: \(error.localizedDescription)"
        }
    }
    
    // Delete a meal
    func deleteMeal(_ meal: CustomMeal) async {
        do {
            try await dataStore.deleteCustomMeal(meal)
            savedMeals.removeAll { $0.id == meal.id }
        } catch {
            errorMessage = "Failed to delete meal: \(error.localizedDescription)"
        }
    }
    
    // Search meals
    func searchMeals(query: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            savedMeals = try await dataStore.searchCustomMeals(query: query)
        } catch {
            errorMessage = "Failed to search meals: \(error.localizedDescription)"
        }
    }
}
```

### Adding Custom Meal to Daily Log

```swift
extension CustomMealManager {
    func addMealToLog(
        _ meal: CustomMeal,
        servingMultiplier: Double = 1.0,
        log: DailyLog
    ) async throws -> [FoodItem] {
        // Update lastUsedAt timestamp
        meal.lastUsedAt = Date()
        try await dataStore.updateCustomMeal(meal)
        
        // Convert each ingredient to a FoodItem
        var foodItems: [FoodItem] = []
        
        for ingredient in meal.ingredients {
            let foodItem = FoodItem(
                name: ingredient.name,
                calories: ingredient.calories * servingMultiplier,
                servingSize: "\(ingredient.quantity * servingMultiplier)",
                servingUnit: ingredient.unit,
                source: .customMeal,
                protein: ingredient.protein.map { $0 * servingMultiplier },
                carbohydrates: ingredient.carbohydrates.map { $0 * servingMultiplier },
                fats: ingredient.fats.map { $0 * servingMultiplier }
            )
            
            log.foodItems.append(foodItem)
            foodItems.append(foodItem)
        }
        
        return foodItems
    }
}
```

---

## Error Handling

All DataStore methods can throw SwiftData errors. Common error scenarios include:

### Persistence Failures

```swift
do {
    try await dataStore.saveCustomMeal(meal)
} catch {
    // Handle specific error types
    if let swiftDataError = error as? SwiftDataError {
        switch swiftDataError {
        case .storageError:
            print("Storage error: disk full or permissions issue")
        case .corruptedData:
            print("Data corruption detected")
        default:
            print("SwiftData error: \(swiftDataError)")
        }
    } else {
        print("Unexpected error: \(error)")
    }
}
```

### Retry Logic

```swift
func saveCustomMealWithRetry(_ meal: CustomMeal, maxAttempts: Int = 3) async throws {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            try await dataStore.saveCustomMeal(meal)
            return // Success
        } catch {
            lastError = error
            print("Save attempt \(attempt) failed: \(error)")
            
            if attempt < maxAttempts {
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }
        }
    }
    
    throw lastError ?? NSError(domain: "CustomMeal", code: -1)
}
```

---

## Thread Safety

All DataStore methods are actor-isolated and thread-safe. The actor model ensures:

1. **Serialized Access**: All operations are serialized through the actor's mailbox
2. **No Race Conditions**: Multiple concurrent calls are safely queued
3. **Async/Await**: All methods use Swift's structured concurrency

**Example of Safe Concurrent Access:**

```swift
// These calls are safely serialized by the actor
Task {
    try await dataStore.saveCustomMeal(meal1)
}

Task {
    try await dataStore.saveCustomMeal(meal2)
}

Task {
    let meals = try await dataStore.fetchAllCustomMeals()
}
```

---

## Performance Considerations

### Fetch Optimization

- `fetchAllCustomMeals()` uses a single sorted fetch descriptor
- Results are sorted at the database level (efficient)
- No in-memory sorting required

### Search Optimization

- `searchCustomMeals()` uses predicate-based filtering at the database level
- Case-insensitive search is handled by SwiftData's `localizedStandardContains`
- Empty queries short-circuit to `fetchAllCustomMeals()` for efficiency

### Cascade Delete

- SwiftData handles cascade deletion automatically
- No manual cleanup of ingredients required
- Single transaction ensures atomicity

---

## Testing Considerations

### Unit Testing

```swift
import Testing
import SwiftData

@Test("Save and fetch custom meal")
func testSaveAndFetchCustomMeal() async throws {
    // Setup in-memory model context
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: CustomMeal.self, configurations: config)
    let dataStore = DataStore(modelContext: container.mainContext)
    
    // Create test meal
    let ingredient = Ingredient(
        name: "Test Ingredient",
        quantity: 1,
        unit: "cup",
        calories: 100
    )
    let meal = CustomMeal(name: "Test Meal", ingredients: [ingredient])
    
    // Save meal
    try await dataStore.saveCustomMeal(meal)
    
    // Fetch and verify
    let fetchedMeal = try await dataStore.fetchCustomMeal(id: meal.id)
    #expect(fetchedMeal != nil)
    #expect(fetchedMeal?.name == "Test Meal")
    #expect(fetchedMeal?.ingredients.count == 1)
}
```

### Property-Based Testing

See `tasks.md` for property-based test specifications:
- Property 3: Custom Meal Persistence Round-Trip
- Property 4: Custom Meal Sort Order
- Property 5: Cascade Deletion Completeness
- Property 20: Custom Meal Search Correctness

---

## Migration Notes

### Backward Compatibility

The DataStore extensions are fully backward compatible:

- Existing `DailyLog` and `FoodItem` operations are unchanged
- New CustomMeal operations are additive only
- No schema migrations required for existing data

### Future Enhancements

Potential future additions to the DataStore API:

- `fetchCustomMealsByDateRange(from:to:)` - Fetch meals used in a date range
- `fetchMostUsedCustomMeals(limit:)` - Get top N most frequently used meals
- `duplicateCustomMeal(_:)` - Create a copy of an existing meal
- `exportCustomMeals()` - Export meals for backup/sharing
- `importCustomMeals(_:)` - Import meals from backup

---

## Related Documentation

- [Requirements Document](requirements.md) - User stories and acceptance criteria
- [Design Document](design.md) - Architecture and correctness properties
- [Tasks Document](tasks.md) - Implementation tasks and testing strategy
- [Project Foundation](../../steering/project-foundation.md) - Overall project patterns
