//
//  FoodItemPersistenceTests.swift
//  CountMeTests
//
//  Tests for food item persistence and relationships with SwiftData
//
//  These tests verify that:
//  1. Food items are correctly persisted to SwiftData
//  2. Relationships between FoodItem and DailyLog are maintained
//  3. Data can be retrieved after persistence
//
//  All tests use in-memory storage to ensure isolation and speed.
//

import Testing
import Foundation
import SwiftData
@testable import CountMe

@Suite("Food Item Persistence Tests")
@MainActor
struct FoodItemPersistenceTests {
    
    @Test("Add food item to daily log persists relationship")
    func testAddFoodItem_PersistsRelationship() async throws {
        // This test verifies that when a food item is added to a daily log,
        // the bidirectional relationship is correctly maintained in SwiftData.
        // The relationship should persist across save/fetch cycles.
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create a daily log
        let today = Date()
        let log = try DailyLog(date: today)
        try await dataStore.saveDailyLog(log)
        
        // Add a food item
        let foodItem = try FoodItem(name: "Apple", calories: 95, timestamp: today)
        foodItem.dailyLog = log
        log.foodItems.append(foodItem)
        
        // Save the log
        try await dataStore.saveDailyLog(log)
        
        print("✅ Saved log with \(log.foodItems.count) food items")
        
        // Fetch the log again
        let fetchedLog = try await dataStore.fetchDailyLog(for: today)
        
        print("📋 Fetched log has \(fetchedLog?.foodItems.count ?? 0) food items")
        
        // Verify
        #expect(fetchedLog != nil)
        #expect(fetchedLog?.foodItems.count == 1)
        #expect(fetchedLog?.foodItems.first?.name == "Apple")
    }
    
    @Test("Multiple food items persist correctly")
    func testMultipleFoodItems_PersistCorrectly() async throws {
        // This test verifies that multiple food items can be added to a single
        // daily log and all relationships are maintained correctly.
        // It also verifies that calorie totals are calculated correctly.
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create a daily log
        let today = Date()
        let log = try DailyLog(date: today)
        try await dataStore.saveDailyLog(log)
        
        // Add multiple food items
        let item1 = try FoodItem(name: "Breakfast", calories: 300, timestamp: today)
        let item2 = try FoodItem(name: "Lunch", calories: 500, timestamp: today)
        let item3 = try FoodItem(name: "Dinner", calories: 600, timestamp: today)
        
        item1.dailyLog = log
        item2.dailyLog = log
        item3.dailyLog = log
        
        log.foodItems.append(contentsOf: [item1, item2, item3])
        
        // Save
        try await dataStore.saveDailyLog(log)
        
        print("✅ Saved log with \(log.foodItems.count) food items")
        
        // Fetch
        let fetchedLog = try await dataStore.fetchDailyLog(for: today)
        
        print("📋 Fetched log has \(fetchedLog?.foodItems.count ?? 0) food items")
        
        // Verify
        #expect(fetchedLog != nil)
        #expect(fetchedLog?.foodItems.count == 3)
        #expect(fetchedLog?.totalCalories == 1400)
    }
    
    @Test("CalorieTracker addFoodItem maintains relationship")
    func testCalorieTracker_AddFoodItem_MaintainsRelationship() async throws {
        // This test verifies that the CalorieTracker business logic layer
        // correctly maintains relationships when adding food items.
        // It tests the full flow: load log -> add item -> verify persistence.
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient()
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        
        // Load today's log
        try await tracker.loadLog(for: Date())
        
        print("📅 Loaded log, current items: \(tracker.currentLog?.foodItems.count ?? 0)")
        
        // Add a food item
        let foodItem = try FoodItem(name: "Test Food", calories: 250, timestamp: Date())
        try await tracker.addFoodItem(foodItem)
        
        print("✅ Added food item, current items: \(tracker.currentLog?.foodItems.count ?? 0)")
        
        // Verify the item is in the current log
        #expect(tracker.currentLog?.foodItems.count == 1)
        #expect(tracker.currentLog?.foodItems.first?.name == "Test Food")
        #expect(tracker.getCurrentDailyTotal() == 250)
    }
}
