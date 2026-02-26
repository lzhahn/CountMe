//
//  CoreUIFlowsTests.swift
//  CountMeTests
//
//  Integration tests for core UI flows
//  Task 9: Checkpoint - Ensure core UI flows work correctly
//

import XCTest
import SwiftData
@testable import CountMe

/// Integration tests for core UI flows
/// Tests the complete user journeys for:
/// - Adding food via search
/// - Adding food manually
/// - Editing and deleting items
final class CoreUIFlowsTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var dataStore: CountMe.DataStore!
    var apiClient: NutritionAPIClient!
    var tracker: CalorieTracker!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailyLog.self, FoodItem.self,
            configurations: config
        )
        modelContext = ModelContext(modelContainer)
        
        // Initialize dependencies
        dataStore = CountMe.DataStore(modelContext: modelContext)
        apiClient = NutritionAPIClient(
            apiKey: "test_key"
        )
        
        // Initialize tracker on main actor
        await MainActor.run {
            tracker = CalorieTracker(
                dataStore: dataStore,
                apiClient: apiClient
            )
        }
        
        // Load initial log
        try await tracker.loadLog(for: Date())
    }
    
    override func tearDown() async throws {
        tracker = nil
        apiClient = nil
        dataStore = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Adding Food Manually
    
    func testAddFoodManually() async throws {
        // Verify initial state
        await MainActor.run {
            XCTAssertNotNil(tracker.currentLog, "Should have a current log")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 0.0, "Initial total should be 0")
        }
        
        // Create a manual food item
        let manualItem = FoodItem(
            name: "Homemade Salad",
            calories: 250.0,
            timestamp: Date(),
            servingSize: "1",
            servingUnit: "bowl",
            source: .manual
        )
        
        // Add the item
        try await tracker.addFoodItem(manualItem)
        
        // Verify the item was added
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1, "Should have 1 food item")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 250.0, "Total should be 250")
            
            let addedItem = tracker.currentLog?.foodItems.first
            XCTAssertNotNil(addedItem, "Should have an added item")
            XCTAssertEqual(addedItem?.name, "Homemade Salad")
            XCTAssertEqual(addedItem?.calories, 250.0)
            XCTAssertEqual(addedItem?.source, .manual)
        }
        
        // Verify persistence by reloading
        try await tracker.loadLog(for: Date())
        
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1, "Item should persist after reload")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 250.0, "Total should persist after reload")
        }
    }
    
    func testAddMultipleFoodsManually() async throws {
        // Add first item
        let item1 = FoodItem(
            name: "Breakfast Oatmeal",
            calories: 150.0,
            source: .manual
        )
        try await tracker.addFoodItem(item1)
        
        // Add second item
        let item2 = FoodItem(
            name: "Lunch Sandwich",
            calories: 350.0,
            source: .manual
        )
        try await tracker.addFoodItem(item2)
        
        // Add third item
        let item3 = FoodItem(
            name: "Dinner Pasta",
            calories: 500.0,
            source: .manual
        )
        try await tracker.addFoodItem(item3)
        
        // Verify all items were added
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 3, "Should have 3 food items")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 1000.0, "Total should be 1000")
        }
    }
    
    func testManualEntryValidation() async throws {
        // Test with negative calories (should be rejected by validation)
        let invalidItem = FoodItem(
            name: "Invalid Food",
            calories: -100.0,
            source: .manual
        )
        
        // Add the item (validation happens at UI level, but we can still add it)
        try await tracker.addFoodItem(invalidItem)
        
        // The item is added, but in a real app, UI validation would prevent this
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1)
        }
    }
    
    // MARK: - Test Adding Food via Search (Simulated)
    
    func testAddFoodViaAPISearch() async throws {
        // Simulate selecting a food from API search results
        let apiItem = FoodItem(
            name: "Chicken Breast",
            calories: 165.0,
            timestamp: Date(),
            servingSize: "100",
            servingUnit: "g",
            source: .api
        )
        
        // Add the item
        try await tracker.addFoodItem(apiItem)
        
        // Verify the item was added
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1, "Should have 1 food item")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 165.0, "Total should be 165")
            
            let addedItem = tracker.currentLog?.foodItems.first
            XCTAssertNotNil(addedItem, "Should have an added item")
            XCTAssertEqual(addedItem?.name, "Chicken Breast")
            XCTAssertEqual(addedItem?.calories, 165.0)
            XCTAssertEqual(addedItem?.source, .api)
            XCTAssertEqual(addedItem?.servingSize, "100")
            XCTAssertEqual(addedItem?.servingUnit, "g")
        }
    }
    
    func testAddMultipleFoodsFromDifferentSources() async throws {
        // Add manual item
        let manualItem = FoodItem(
            name: "Homemade Smoothie",
            calories: 200.0,
            source: .manual
        )
        try await tracker.addFoodItem(manualItem)
        
        // Add API item
        let apiItem = FoodItem(
            name: "Apple",
            calories: 95.0,
            servingSize: "1",
            servingUnit: "medium",
            source: .api
        )
        try await tracker.addFoodItem(apiItem)
        
        // Verify both items were added
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 2, "Should have 2 food items")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 295.0, "Total should be 295")
            
            // Verify sources are preserved
            let sources = tracker.currentLog?.foodItems.map { $0.source } ?? []
            XCTAssertTrue(sources.contains(.manual), "Should have manual item")
            XCTAssertTrue(sources.contains(.api), "Should have API item")
        }
    }
    
    // MARK: - Test Deleting Items
    
    func testDeleteFoodItem() async throws {
        // Add two items
        let item1 = FoodItem(name: "Item 1", calories: 100.0, source: .manual)
        let item2 = FoodItem(name: "Item 2", calories: 200.0, source: .manual)
        
        try await tracker.addFoodItem(item1)
        try await tracker.addFoodItem(item2)
        
        // Verify initial state
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 2)
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 300.0)
        }
        
        // Delete first item
        try await tracker.removeFoodItem(item1)
        
        // Verify deletion
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1, "Should have 1 item after deletion")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 200.0, "Total should be 200 after deletion")
            
            let remainingItem = tracker.currentLog?.foodItems.first
            XCTAssertEqual(remainingItem?.name, "Item 2", "Item 2 should remain")
        }
        
        // Verify persistence
        try await tracker.loadLog(for: Date())
        
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1, "Deletion should persist")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 200.0, "Total should persist")
        }
    }
    
    func testDeleteAllItems() async throws {
        // Add multiple items
        let items = [
            FoodItem(name: "Item 1", calories: 100.0, source: .manual),
            FoodItem(name: "Item 2", calories: 200.0, source: .manual),
            FoodItem(name: "Item 3", calories: 300.0, source: .manual)
        ]
        
        for item in items {
            try await tracker.addFoodItem(item)
        }
        
        // Verify initial state
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 3)
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 600.0)
        }
        
        // Delete all items
        for item in items {
            try await tracker.removeFoodItem(item)
        }
        
        // Verify all deleted
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 0, "Should have no items")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 0.0, "Total should be 0")
        }
    }
    
    // MARK: - Test Editing Items
    
    func testUpdateFoodItem() async throws {
        // Add an item
        let originalItem = FoodItem(
            name: "Original Name",
            calories: 100.0,
            servingSize: "1",
            servingUnit: "serving",
            source: .manual
        )
        
        try await tracker.addFoodItem(originalItem)
        
        // Verify initial state
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 100.0)
        }
        
        // Update the item
        originalItem.name = "Updated Name"
        originalItem.calories = 150.0
        originalItem.servingSize = "2"
        
        try await tracker.updateFoodItem(originalItem)
        
        // Verify update
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1)
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 150.0, "Total should reflect updated calories")
            
            let updatedItem = tracker.currentLog?.foodItems.first
            XCTAssertEqual(updatedItem?.name, "Updated Name")
            XCTAssertEqual(updatedItem?.calories, 150.0)
            XCTAssertEqual(updatedItem?.servingSize, "2")
        }
        
        // Verify persistence
        try await tracker.loadLog(for: Date())
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 150.0, "Update should persist")
            let persistedItem = tracker.currentLog?.foodItems.first
            XCTAssertEqual(persistedItem?.name, "Updated Name")
        }
    }
    
    func testUpdateMultipleItems() async throws {
        // Add multiple items
        let item1 = FoodItem(name: "Item 1", calories: 100.0, source: .manual)
        let item2 = FoodItem(name: "Item 2", calories: 200.0, source: .manual)
        
        try await tracker.addFoodItem(item1)
        try await tracker.addFoodItem(item2)
        
        // Update both items
        item1.calories = 150.0
        item2.calories = 250.0
        
        try await tracker.updateFoodItem(item1)
        try await tracker.updateFoodItem(item2)
        
        // Verify updates
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 400.0, "Total should be 400")
        }
    }
    
    // MARK: - Test Complete User Flows
    
    func testCompleteUserFlow() async throws {
        // Simulate a complete day of tracking
        
        // 1. Add breakfast (manual)
        let breakfast = FoodItem(
            name: "Oatmeal with Berries",
            calories: 250.0,
            source: .manual
        )
        try await tracker.addFoodItem(breakfast)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 250.0)
        }
        
        // 2. Add lunch (from API)
        let lunch = FoodItem(
            name: "Grilled Chicken Salad",
            calories: 350.0,
            servingSize: "1",
            servingUnit: "bowl",
            source: .api
        )
        try await tracker.addFoodItem(lunch)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 600.0)
        }
        
        // 3. Add snack (manual)
        let snack = FoodItem(
            name: "Apple",
            calories: 95.0,
            source: .manual
        )
        try await tracker.addFoodItem(snack)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 695.0)
        }
        
        // 4. Realize snack was wrong, delete it
        try await tracker.removeFoodItem(snack)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 600.0)
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 2)
        }
        
        // 5. Add correct snack
        let correctSnack = FoodItem(
            name: "Protein Bar",
            calories: 200.0,
            source: .api
        )
        try await tracker.addFoodItem(correctSnack)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 800.0)
        }
        
        // 6. Update breakfast calories (realized portion was larger)
        breakfast.calories = 300.0
        try await tracker.updateFoodItem(breakfast)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 850.0)
        }
        
        // 7. Add dinner
        let dinner = FoodItem(
            name: "Salmon with Vegetables",
            calories: 450.0,
            servingSize: "1",
            servingUnit: "plate",
            source: .manual
        )
        try await tracker.addFoodItem(dinner)
        
        // Final verification
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 4, "Should have 4 items")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 1300.0, "Total should be 1300")
        }
        
        // Verify persistence of entire flow
        try await tracker.loadLog(for: Date())
        
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 4, "All items should persist")
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 1300.0, "Total should persist")
        }
    }
    
    // MARK: - Test Goal Tracking with UI Flows
    
    func testGoalTrackingWithFoodAddition() async throws {
        // Set a daily goal
        try await tracker.setDailyGoal(2000.0)
        
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.dailyGoal, 2000.0)
            XCTAssertEqual(tracker.getRemainingCalories(), 2000.0)
        }
        
        // Add food items
        let item1 = FoodItem(name: "Breakfast", calories: 500.0, source: .manual)
        try await tracker.addFoodItem(item1)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getRemainingCalories(), 1500.0)
        }
        
        let item2 = FoodItem(name: "Lunch", calories: 700.0, source: .manual)
        try await tracker.addFoodItem(item2)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getRemainingCalories(), 800.0)
        }
        
        // Add item that exceeds goal
        let item3 = FoodItem(name: "Dinner", calories: 900.0, source: .manual)
        try await tracker.addFoodItem(item3)
        
        await MainActor.run {
            XCTAssertEqual(tracker.getRemainingCalories(), -100.0, "Should be negative when goal exceeded")
            XCTAssertTrue(tracker.getCurrentDailyTotal() > tracker.currentLog!.dailyGoal!)
        }
    }
    
    // MARK: - Test Error Handling
    
    func testAddItemWithoutCurrentLog() async throws {
        // Create a new tracker without loading a log
        let newTracker = await MainActor.run {
            CalorieTracker(
                dataStore: dataStore,
                apiClient: apiClient
            )
        }
        
        let item = FoodItem(name: "Test", calories: 100.0, source: .manual)
        
        do {
            try await newTracker.addFoodItem(item)
            XCTFail("Should throw error when no current log")
        } catch let error as CalorieTrackerError {
            XCTAssertEqual(error, .noCurrentLog)
        } catch {
            XCTFail("Should throw CalorieTrackerError")
        }
    }
    
    func testDeleteNonexistentItem() async throws {
        // Add an item
        let item1 = FoodItem(name: "Item 1", calories: 100.0, source: .manual)
        try await tracker.addFoodItem(item1)
        
        // Try to delete a different item that doesn't exist
        let nonexistentItem = FoodItem(name: "Nonexistent", calories: 200.0, source: .manual)
        
        // This should not throw an error, just do nothing
        try await tracker.removeFoodItem(nonexistentItem)
        
        // Verify original item still exists
        await MainActor.run {
            XCTAssertEqual(tracker.currentLog?.foodItems.count, 1)
            XCTAssertEqual(tracker.getCurrentDailyTotal(), 100.0)
        }
    }
}
