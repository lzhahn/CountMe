//
//  UIRefreshTests.swift
//  CountMeTests
//
//  Tests for UI refresh behavior after data changes
//
//  These tests verify that the CalorieTracker properly updates its currentLog
//  property after data mutations, ensuring SwiftUI views receive change notifications.
//
//  Background: SwiftUI's @Observable macro tracks property changes, but when
//  SwiftData returns the same object reference from its cache, SwiftUI may not
//  detect the change. These tests verify the workaround is effective.
//

import Testing
import Foundation
import SwiftData
@testable import CountMe

@Suite("UI Refresh Tests")
@MainActor
struct UIRefreshTests {
    
    @Test("Adding food item updates currentLog reference")
    func testAddFoodItem_UpdatesCurrentLogReference() async throws {
        // This test verifies that after adding a food item, the tracker's
        // currentLog property is updated in a way that SwiftUI can detect.
        // The log ID should remain the same (same day), but the food items
        // array should contain the new item.
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient()
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        let initialLogId = tracker.currentLog?.id
        let initialCount = tracker.currentLog?.foodItems.count ?? 0
        let initialCacheCount = tracker.foodItemsCache.count
        
        print("📊 Initial log ID: \(initialLogId ?? "nil")")
        print("📊 Initial food items count: \(initialCount)")
        print("📊 Initial cache count: \(initialCacheCount)")
        
        // Add a food item
        let foodItem = try FoodItem(name: "Test Food", calories: 250, timestamp: Date())
        try await tracker.addFoodItem(foodItem)
        
        let afterAddLogId = tracker.currentLog?.id
        let afterAddCount = tracker.currentLog?.foodItems.count ?? 0
        let afterAddCacheCount = tracker.foodItemsCache.count
        
        print("📊 After add log ID: \(afterAddLogId ?? "nil")")
        print("📊 After add food items count: \(afterAddCount)")
        print("📊 After add cache count: \(afterAddCacheCount)")
        
        // Verify the log reference is the same (same day)
        #expect(initialLogId == afterAddLogId)
        
        // Verify the count increased
        #expect(afterAddCount == initialCount + 1)
        
        // Verify the cache was updated
        #expect(afterAddCacheCount == initialCacheCount + 1)
        
        // Verify the item is in the array
        #expect(tracker.currentLog?.foodItems.contains(where: { $0.name == "Test Food" }) == true)
        
        // Verify the item is in the cache
        #expect(tracker.foodItemsCache.contains(where: { $0.name == "Test Food" }))
    }
    
    @Test("Multiple adds update currentLog correctly")
    func testMultipleAdds_UpdateCurrentLog() async throws {
        // This test verifies that multiple sequential additions all properly
        // update the currentLog property. This is important because SwiftUI
        // needs to detect each change to keep the UI in sync.
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient()
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Add multiple food items
        for i in 1...3 {
            let foodItem = try FoodItem(name: "Food \(i)", calories: Double(i * 100), timestamp: Date())
            try await tracker.addFoodItem(foodItem)
            
            print("📊 After adding Food \(i): \(tracker.currentLog?.foodItems.count ?? 0) items")
        }
        
        // Verify all items are present
        #expect(tracker.currentLog?.foodItems.count == 3)
        #expect(tracker.getCurrentDailyTotal() == 600.0)
    }
    
    @Test("Removing food item updates cache")
    func testRemoveFoodItem_UpdatesCache() async throws {
        // This test verifies that removing a food item updates the cache
        // so SwiftUI views can observe the change
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient()
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Add two food items
        let foodItem1 = try FoodItem(name: "Food 1", calories: 100, timestamp: Date())
        let foodItem2 = try FoodItem(name: "Food 2", calories: 200, timestamp: Date())
        try await tracker.addFoodItem(foodItem1)
        try await tracker.addFoodItem(foodItem2)
        
        let countAfterAdds = tracker.foodItemsCache.count
        #expect(countAfterAdds == 2)
        
        // Remove one item
        try await tracker.removeFoodItem(foodItem1)
        
        let countAfterRemove = tracker.foodItemsCache.count
        
        // Verify cache was updated
        #expect(countAfterRemove == 1)
        #expect(tracker.foodItemsCache.contains(where: { $0.name == "Food 2" }))
        #expect(!tracker.foodItemsCache.contains(where: { $0.name == "Food 1" }))
    }
    
    @Test("Updating food item updates cache")
    func testUpdateFoodItem_UpdatesCache() async throws {
        // This test verifies that updating a food item updates the cache
        // so SwiftUI views can observe the change
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient()
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Add a food item
        let foodItem = try FoodItem(name: "Original Name", calories: 100, timestamp: Date())
        try await tracker.addFoodItem(foodItem)
        
        // Update the item
        foodItem.name = "Updated Name"
        foodItem.calories = 250
        try await tracker.updateFoodItem(foodItem)
        
        // Verify cache reflects the update
        #expect(tracker.foodItemsCache.count == 1)
        #expect(tracker.foodItemsCache.first?.name == "Updated Name")
        #expect(tracker.foodItemsCache.first?.calories == 250)
    }
    
    @Test("Property: Cache always matches currentLog.foodItems", .tags(.property))
    func testProperty_CacheMatchesLog_1() async throws {
        // Property-based test: After any sequence of add/remove operations,
        // the foodItemsCache should always match currentLog.foodItems
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient()
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        // Perform random operations (100+ iterations as per testing guidelines)
        for iteration in 0..<100 {
            let operation = Int.random(in: 0...1)
            
            if operation == 0 || tracker.foodItemsCache.isEmpty {
                // Add operation
                let foodItem = try FoodItem(
                    name: "Food \(iteration)",
                    calories: Double.random(in: 50...500),
                    timestamp: Date()
                )
                try await tracker.addFoodItem(foodItem)
            } else {
                // Remove operation
                if let itemToRemove = tracker.foodItemsCache.randomElement() {
                    try await tracker.removeFoodItem(itemToRemove)
                }
            }
            
            // Verify property: cache matches log
            let cacheIds = Set(tracker.foodItemsCache.map { $0.id })
            let logIds = Set(tracker.currentLog?.foodItems.map { $0.id } ?? [])
            
            #expect(cacheIds == logIds, "Cache IDs should match log IDs after operation \(iteration)")
            #expect(tracker.foodItemsCache.count == tracker.currentLog?.foodItems.count ?? 0)
        }
    }
}
