# Testing Guidelines

## Overview

CountMe uses Swift Testing framework with a focus on property-based testing to ensure robust, reliable behavior across all features. This document outlines testing standards, patterns, and best practices.

## Testing Philosophy

- **Property-Based Testing**: Verify behavior holds across many inputs (100+ iterations)
- **Unit Tests**: Test specific examples, edge cases, and error conditions
- **Coverage Goals**: 90%+ for business logic, 100% for error handling
- **Offline-First**: All tests must pass without network connectivity
- **Actor Safety**: Test concurrent access patterns for DataStore and FirebaseSyncEngine

## Test Organization

```
CountMeTests/
├── Models/              # Model validation, calculations, transformations
├── Services/            # Business logic, API clients, sync engine
├── Views/               # UI logic, state management, user flows
└── Utilities/           # Helpers, converters, validators
```

## Naming Conventions

### Unit Tests
```swift
func testFunctionName_Scenario_ExpectedBehavior() async throws {
    // Example: testAddFoodItem_WithValidData_AddsToLog()
}
```

### Property Tests
```swift
@Test("Property: Description", .tags(.property, .featureName))
func testProperty_FeatureName_PropertyNumber() async throws {
    // Example: testProperty_CalorieCalculation_1()
}
```

## Property-Based Testing

### When to Use
- Mathematical calculations (calories, macros, serving sizes)
- Data transformations (date normalization, unit conversions)
- Validation logic (input sanitization, range checks)
- Sync operations (conflict resolution, merge strategies)

### Pattern
```swift
@Test("Property: Total calories equals sum of food items", 
      .tags(.property, .calorieTracking))
func testProperty_CalorieCalculation_1() async throws {
    for _ in 0..<100 {
        // Generate random valid inputs
        let foodItems = generateRandomFoodItems(count: Int.random(in: 1...20))
        
        // Calculate expected result
        let expectedTotal = foodItems.reduce(0) { $0 + $1.calories }
        
        // Execute system under test
        let dailyLog = DailyLog(date: Date(), foodItems: foodItems)
        
        // Verify property holds
        #expect(dailyLog.totalCalories == expectedTotal)
    }
}
```

### Test Data Generation
```swift
// Use realistic ranges
func generateRandomFoodItem() -> FoodItem {
    FoodItem(
        name: "Test Food \(UUID().uuidString.prefix(8))",
        calories: Double.random(in: 0...2000),
        protein: Double.random(in: 0...100),
        carbs: Double.random(in: 0...300),
        fat: Double.random(in: 0...100),
        servingSize: Double.random(in: 0.1...10.0)
    )
}
```

## Unit Testing Patterns

### Testing DataStore (Actor)
```swift
@Test("Add food item persists to SwiftData")
func testAddFoodItem_ValidData_PersistsSuccessfully() async throws {
    let dataStore = DataStore(inMemory: true)
    let foodItem = FoodItem(name: "Apple", calories: 95)
    
    try await dataStore.addFoodItem(foodItem)
    
    let retrieved = try await dataStore.getFoodItem(byId: foodItem.id)
    #expect(retrieved?.name == "Apple")
    #expect(retrieved?.calories == 95)
}
```

### Testing API Clients
```swift
@Test("Search returns valid results")
func testSearch_ValidQuery_ReturnsResults() async throws {
    let client = NutritionAPIClient()
    
    let results = try await client.searchFood(query: "apple")
    
    #expect(!results.isEmpty)
    #expect(results.allSatisfy { $0.calories >= 0 })
}

@Test("Search handles timeout gracefully")
func testSearch_Timeout_ThrowsError() async throws {
    // Create a custom URLSession with very short timeout
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 0.001
    let session = URLSession(configuration: config)
    let client = NutritionAPIClient(session: session)
    
    await #expect(throws: NutritionAPIError.timeout) {
        try await client.searchFood(query: "apple")
    }
}
```

### Testing Date Normalization
```swift
@Test("Date normalization removes time component")
func testNormalizeDate_AnyTime_ReturnsMiddnight() async throws {
    let dataStore = DataStore(inMemory: true)
    let date = Date() // Current date with time
    
    let normalized = dataStore.normalizeDate(date)
    
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute, .second], from: normalized)
    #expect(components.hour == 0)
    #expect(components.minute == 0)
    #expect(components.second == 0)
}
```

### Testing Validation
```swift
@Test("Negative calories rejected")
func testValidateCalories_NegativeValue_ThrowsError() async throws {
    await #expect(throws: ValidationError.invalidCalories) {
        try FoodItem(name: "Test", calories: -100)
    }
}

@Test("Empty name rejected")
func testValidateName_EmptyString_ThrowsError() async throws {
    await #expect(throws: ValidationError.emptyName) {
        try FoodItem(name: "", calories: 100)
    }
}
```

## Testing Firebase Sync

### Mock Network Conditions
```swift
@Test("Sync queues changes when offline")
func testSync_Offline_QueuesForLater() async throws {
    let syncEngine = FirebaseSyncEngine(
        dataStore: dataStore,
        networkMonitor: MockNetworkMonitor(isConnected: false)
    )
    
    let foodItem = FoodItem(name: "Apple", calories: 95)
    try await syncEngine.saveFoodItem(foodItem, userId: "test-user")
    
    #expect(foodItem.syncStatus == .pendingUpload)
}
```

### Test Conflict Resolution
```swift
@Test("Last write wins for food items")
func testConflictResolution_FoodItem_LastWriteWins() async throws {
    let local = FoodItem(name: "Apple", calories: 95, lastModified: Date())
    let remote = FoodItem(name: "Apple", calories: 100, lastModified: Date().addingTimeInterval(60))
    
    let resolved = syncEngine.resolveConflict(local: local, remote: remote)
    
    #expect(resolved.calories == 100) // Remote is newer
}
```

## Testing Views

### Test View Models
```swift
@Test("Adding food updates total calories")
func testAddFood_ValidItem_UpdatesTotal() async throws {
    let viewModel = MainCalorieViewModel(dataStore: dataStore)
    
    await viewModel.addFood(name: "Apple", calories: 95)
    
    #expect(viewModel.totalCalories == 95)
}
```

### Test User Flows
```swift
@Test("Complete food entry flow")
func testFoodEntryFlow_SearchToAdd_CompletesSuccessfully() async throws {
    // 1. Search
    let searchResults = try await viewModel.search(query: "apple")
    #expect(!searchResults.isEmpty)
    
    // 2. Select
    let selected = searchResults.first!
    
    // 3. Adjust serving
    let adjusted = viewModel.adjustServing(selected, multiplier: 2.0)
    #expect(adjusted.calories == selected.calories * 2)
    
    // 4. Add to log
    try await viewModel.addToLog(adjusted)
    #expect(viewModel.dailyLog.foodItems.contains(adjusted))
}
```

## Error Handling Tests

### Test All Error Paths
```swift
@Test("API timeout triggers manual entry fallback")
func testAPITimeout_ShowsManualEntry() async throws {
    let viewModel = FoodSearchViewModel(
        apiClient: MockAPIClient(shouldTimeout: true)
    )
    
    await viewModel.search(query: "apple")
    
    #expect(viewModel.showManualEntry == true)
    #expect(viewModel.errorMessage?.contains("timeout") == true)
}
```

### Test Recovery
```swift
@Test("Retry after failure succeeds")
func testRetry_AfterFailure_Succeeds() async throws {
    let client = MockAPIClient(failFirstAttempt: true)
    
    // First attempt fails
    await #expect(throws: APIError.networkError) {
        try await client.search(query: "apple")
    }
    
    // Retry succeeds
    let results = try await client.search(query: "apple")
    #expect(!results.isEmpty)
}
```

## Performance Testing

### Test Response Times
```swift
@Test("Daily log loads within 100ms")
func testLoadDailyLog_Performance() async throws {
    let start = Date()
    
    let log = try await dataStore.getDailyLog(for: Date())
    
    let duration = Date().timeIntervalSince(start)
    #expect(duration < 0.1) // 100ms
}
```

### Test Large Data Sets
```swift
@Test("Handles 1000 food items efficiently")
func testLargeDataSet_1000Items_PerformsWell() async throws {
    let items = (0..<1000).map { _ in generateRandomFoodItem() }
    
    let start = Date()
    for item in items {
        try await dataStore.addFoodItem(item)
    }
    let duration = Date().timeIntervalSince(start)
    
    #expect(duration < 5.0) // Should complete in under 5 seconds
}
```

## Test Utilities

### In-Memory DataStore
```swift
// Always use in-memory for tests
let dataStore = DataStore(inMemory: true)
```

### Mock Network Monitor
```swift
class MockNetworkMonitor: NetworkMonitor {
    var isConnected: Bool
    
    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }
}
```

### Test Fixtures
```swift
extension FoodItem {
    static func fixture(
        name: String = "Test Food",
        calories: Double = 100,
        protein: Double = 10,
        carbs: Double = 15,
        fat: Double = 5
    ) -> FoodItem {
        FoodItem(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}
```

## Running Tests

### Run All Tests
```bash
xcodebuild test -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Run Specific Test
```bash
xcodebuild test -scheme CountMe -only-testing:CountMeTests/CalorieTrackerTests/testAddFood
```

### Run Property Tests Only
```bash
# Property tests are tagged with .property
xcodebuild test -scheme CountMe -only-testing:CountMeTests -test-filter property
```

## Coverage Requirements

### Minimum Coverage
- Business Logic: 90%
- Error Handling: 100%
- Data Transformations: 95%
- API Clients: 85%
- View Models: 80%

### Generate Coverage Report
```bash
xcodebuild test -scheme CountMe -enableCodeCoverage YES
xcrun xccov view --report DerivedData/.../Coverage.xccovreport
```

## Common Pitfalls

### ❌ Don't
- Use `sleep()` or arbitrary delays
- Test implementation details
- Share state between tests
- Use production API keys
- Skip error cases
- Test UI rendering (use view models instead)

### ✅ Do
- Use async/await properly
- Test behavior, not implementation
- Isolate each test
- Use mock/in-memory dependencies
- Test all error paths
- Focus on business logic

## Test Maintenance

### When Adding Features
1. Write property tests for core behavior
2. Add unit tests for edge cases
3. Test error conditions
4. Verify offline behavior
5. Check coverage meets minimums

### When Fixing Bugs
1. Write failing test that reproduces bug
2. Fix the bug
3. Verify test passes
4. Add related edge case tests

### Refactoring
1. Run full test suite before changes
2. Keep tests passing during refactor
3. Update tests if behavior changes
4. Verify coverage maintained

## Debugging Tests

### View Test Output
```bash
# Full output (no truncation)
xcodebuild test -scheme CountMe 2>&1 | tee test-output.log
```

### Debug Single Test
```swift
@Test("Debug specific scenario")
func testDebug() async throws {
    print("Debug info: \(someValue)")
    // Set breakpoint here
    let result = try await functionUnderTest()
    print("Result: \(result)")
}
```

### Check Diagnostics
```bash
# Use getDiagnostics tool in Kiro
# Shows compile errors, warnings, type issues
```

## Best Practices Summary

1. **Property tests** for mathematical operations and transformations
2. **Unit tests** for specific scenarios and edge cases
3. **In-memory** DataStore for all tests
4. **Mock** external dependencies (network, Firebase)
5. **Test** all error paths and recovery
6. **Verify** offline behavior
7. **Measure** performance for critical paths
8. **Maintain** 90%+ coverage for business logic
9. **Run** full suite before commits
10. **Document** complex test scenarios

## Resources

- Swift Testing Documentation: https://developer.apple.com/documentation/testing
- Property-Based Testing: https://en.wikipedia.org/wiki/Property_testing
- Actor Testing: https://developer.apple.com/documentation/swift/actor
- SwiftData Testing: https://developer.apple.com/documentation/swiftdata
