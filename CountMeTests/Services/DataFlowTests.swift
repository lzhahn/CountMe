//
//  DataFlowTests.swift
//  CountMeTests
//
//  Tests to verify food items are properly saved and retrieved
//

import Testing
import SwiftData
import Foundation
@testable import CountMe

@Suite("Data Flow Tests")
@MainActor
struct DataFlowTests {
    
    @Test("Food item appears in daily log after adding")
    func foodItemAppearsAfterAdding() async throws {
        // Setup in-memory database
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create dependencies
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient(
            consumerKey: "test",
            consumerSecret: "test"
        )
        
        // Create tracker
        let tracker = CalorieTracker(
            dataStore: dataStore,
            apiClient: apiClient,
            selectedDate: Date()
        )
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Verify log is loaded
        #expect(tracker.currentLog != nil)
        let initialCount = tracker.currentLog?.foodItems.count ?? 0
        print("📊 Initial food items count: \(initialCount)")
        
        // Create a food item
        let foodItem = FoodItem(
            name: "Test Apple",
            calories: 95,
            timestamp: Date(),
            source: .manual
        )
        
        // Add the food item
        try await tracker.addFoodItem(foodItem)
        
        // Verify the item was added
        #expect(tracker.currentLog != nil)
        let finalCount = tracker.currentLog?.foodItems.count ?? 0
        print("📊 Final food items count: \(finalCount)")
        
        #expect(finalCount == initialCount + 1, "Food item should be added to the log")
        
        // Verify the item is in the array
        let addedItem = tracker.currentLog?.foodItems.first { $0.name == "Test Apple" }
        #expect(addedItem != nil, "Added food item should be findable in the log")
        #expect(addedItem?.calories == 95)
        
        // Verify the relationship is set
        #expect(addedItem?.dailyLog != nil, "Food item should have dailyLog relationship set")
        #expect(addedItem?.dailyLog?.id == tracker.currentLog?.id, "Food item should reference the correct daily log")
    }
    
    @Test("Food item persists after reload")
    func foodItemPersistsAfterReload() async throws {
        // Setup in-memory database
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create dependencies
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient(
            consumerKey: "test",
            consumerSecret: "test"
        )
        
        // Create tracker
        let tracker = CalorieTracker(
            dataStore: dataStore,
            apiClient: apiClient,
            selectedDate: Date()
        )
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Add a food item
        let foodItem = FoodItem(
            name: "Test Banana",
            calories: 105,
            timestamp: Date(),
            source: .manual
        )
        try await tracker.addFoodItem(foodItem)
        
        // Verify it was added
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        // Reload the log (simulating app restart)
        try await tracker.loadLog(for: Date())
        
        // Verify the item is still there
        #expect(tracker.currentLog?.foodItems.count == 1, "Food item should persist after reload")
        
        let persistedItem = tracker.currentLog?.foodItems.first
        #expect(persistedItem?.name == "Test Banana")
        #expect(persistedItem?.calories == 105)
    }
    
    @Test("Multiple food items can be added")
    func multipleFoodItemsCanBeAdded() async throws {
        // Setup in-memory database
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create dependencies
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient(
            consumerKey: "test",
            consumerSecret: "test"
        )
        
        // Create tracker
        let tracker = CalorieTracker(
            dataStore: dataStore,
            apiClient: apiClient,
            selectedDate: Date()
        )
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Add multiple food items
        let items = [
            FoodItem(name: "Apple", calories: 95, timestamp: Date(), source: .manual),
            FoodItem(name: "Banana", calories: 105, timestamp: Date(), source: .manual),
            FoodItem(name: "Orange", calories: 62, timestamp: Date(), source: .manual)
        ]
        
        for item in items {
            try await tracker.addFoodItem(item)
        }
        
        // Verify all items were added
        #expect(tracker.currentLog?.foodItems.count == 3, "All three food items should be added")
        
        // Verify total calories
        let totalCalories = tracker.getCurrentDailyTotal()
        #expect(totalCalories == 262, "Total calories should be sum of all items")
    }
}
