//
//  CalorieTrackerCacheTests.swift
//  CountMeTests
//
//  Created by Kiro on 2/25/26.
//

import Testing
import Foundation
import SwiftData
@testable import CountMe

/// Tests for CalorieTracker cache behavior
///
/// Validates that food and exercise item caches are properly updated
/// to trigger SwiftUI observation when the underlying SwiftData relationships change.
@Suite("CalorieTracker Cache Tests")
@MainActor
struct CalorieTrackerCacheTests {
    
    // MARK: - Test Helpers
    
    func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            DailyLog.self,
            FoodItem.self,
            ExerciseItem.self,
            CustomMeal.self,
            Ingredient.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    // MARK: - Exercise Cache Tests
    
    @Test("loadLog updates exerciseItemsCache with existing items")
    func testLoadLog_WithExerciseItems_UpdatesCache() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: NutritionAPIClient())
        
        // Create a daily log with exercise items
        let today = Calendar.current.startOfDay(for: Date())
        let log = try DailyLog(date: today)
        
        let exercise1 = try ExerciseItem(
            name: "Running",
            caloriesBurned: 300,
            durationMinutes: 30,
            exerciseType: .running,
            intensity: .moderate
        )
        let exercise2 = try ExerciseItem(
            name: "Cycling",
            caloriesBurned: 200,
            durationMinutes: 20,
            exerciseType: .cycling,
            intensity: .light
        )
        
        exercise1.dailyLog = log
        exercise2.dailyLog = log
        log.exerciseItems.append(exercise1)
        log.exerciseItems.append(exercise2)
        
        try await dataStore.saveDailyLog(log)
        
        // Load the log
        try await tracker.loadLog(for: today)
        
        // Verify cache is updated
        #expect(tracker.exerciseItemsCache.count == 2)
        #expect(tracker.exerciseItemsCache.contains { $0.name == "Running" })
        #expect(tracker.exerciseItemsCache.contains { $0.name == "Cycling" })
    }
    
    @Test("loadLog initializes empty exerciseItemsCache for new log")
    func testLoadLog_NewLog_InitializesEmptyCache() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: NutritionAPIClient())
        
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        
        // Load a date with no existing log
        try await tracker.loadLog(for: tomorrow)
        
        // Verify cache is empty
        #expect(tracker.exerciseItemsCache.isEmpty)
    }
    
    @Test("addExerciseItem updates cache via loadLog")
    func testAddExerciseItem_UpdatesCacheThroughReload() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: NutritionAPIClient())
        
        let today = Calendar.current.startOfDay(for: Date())
        try await tracker.loadLog(for: today)
        
        #expect(tracker.exerciseItemsCache.isEmpty)
        
        // Add an exercise item
        let exercise = try ExerciseItem(
            name: "Swimming",
            caloriesBurned: 250,
            durationMinutes: 25,
            exerciseType: .swimming,
            intensity: .vigorous
        )
        
        try await tracker.addExerciseItem(exercise)
        
        // Verify cache is updated (addExerciseItem calls loadLog internally)
        #expect(tracker.exerciseItemsCache.count == 1)
        #expect(tracker.exerciseItemsCache.first?.name == "Swimming")
    }
    
    // MARK: - Food Cache Tests (for comparison)
    
    @Test("loadLog updates foodItemsCache with existing items")
    func testLoadLog_WithFoodItems_UpdatesCache() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: NutritionAPIClient())
        
        // Create a daily log with food items
        let today = Calendar.current.startOfDay(for: Date())
        let log = try DailyLog(date: today)
        
        let food1 = try FoodItem(name: "Apple", calories: 95, protein: 0.5, fats: 0.3)
        let food2 = try FoodItem(name: "Banana", calories: 105, protein: 1.3, fats: 0.4)
        
        food1.dailyLog = log
        food2.dailyLog = log
        log.foodItems.append(food1)
        log.foodItems.append(food2)
        
        try await dataStore.saveDailyLog(log)
        
        // Load the log
        try await tracker.loadLog(for: today)
        
        // Verify cache is updated
        #expect(tracker.foodItemsCache.count == 2)
        #expect(tracker.foodItemsCache.contains { $0.name == "Apple" })
        #expect(tracker.foodItemsCache.contains { $0.name == "Banana" })
    }
    
    @Test("loadLog populates exerciseItemsCache from database")
    func testLoadLog_WithPersistedExercise_PopulatesCache() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: NutritionAPIClient())
        
        // Create and persist a daily log with exercise items directly in the database
        let today = Calendar.current.startOfDay(for: Date())
        let log = try DailyLog(date: today)
        
        let exercise1 = try ExerciseItem(
            name: "Running",
            caloriesBurned: 300,
            durationMinutes: 30,
            exerciseType: .running,
            intensity: .moderate
        )
        let exercise2 = try ExerciseItem(
            name: "Cycling",
            caloriesBurned: 200,
            durationMinutes: 20,
            exerciseType: .cycling,
            intensity: .light
        )
        
        exercise1.dailyLog = log
        exercise2.dailyLog = log
        log.exerciseItems.append(exercise1)
        log.exerciseItems.append(exercise2)
        
        try await dataStore.saveDailyLog(log)
        
        // Load the log (this should populate the cache)
        try await tracker.loadLog(for: today)
        
        // Verify cache is populated with the persisted exercise items
        #expect(tracker.exerciseItemsCache.count == 2)
        #expect(tracker.exerciseItemsCache.contains { $0.name == "Running" && $0.caloriesBurned == 300 })
        #expect(tracker.exerciseItemsCache.contains { $0.name == "Cycling" && $0.caloriesBurned == 200 })
        
        // Verify the cache matches the log's relationship
        #expect(tracker.currentLog?.exerciseItems.count == 2)
        #expect(tracker.exerciseItemsCache.count == tracker.currentLog?.exerciseItems.count)
    }
    
    @Test("Property: Cache always matches relationship count",
          .tags(.property, .calorieTracking))
    func testProperty_CacheMatchesRelationship_1() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: NutritionAPIClient())
        
        for _ in 0..<100 {
            let today = Calendar.current.startOfDay(for: Date())
            let log = try DailyLog(date: today)
            
            // Add random number of exercise items
            let exerciseCount = Int.random(in: 0...5)
            for i in 0..<exerciseCount {
                let exercise = try ExerciseItem(
                    name: "Exercise \(i)",
                    caloriesBurned: Double.random(in: 50...500),
                    durationMinutes: Double.random(in: 10...60),
                    exerciseType: .walking,
                    intensity: .moderate
                )
                exercise.dailyLog = log
                log.exerciseItems.append(exercise)
            }
            
            // Add random number of food items
            let foodCount = Int.random(in: 0...5)
            for i in 0..<foodCount {
                let food = try FoodItem(
                    name: "Food \(i)",
                    calories: Double.random(in: 50...500),
                    protein: Double.random(in: 0...50),
                    fats: Double.random(in: 0...30)
                )
                food.dailyLog = log
                log.foodItems.append(food)
            }
            
            try await dataStore.saveDailyLog(log)
            try await tracker.loadLog(for: today)
            
            // Verify caches match relationship counts
            #expect(tracker.exerciseItemsCache.count == log.exerciseItems.count)
            #expect(tracker.foodItemsCache.count == log.foodItems.count)
            
            // Clean up for next iteration - delete by ID
            try await dataStore.deleteDailyLog(byId: log.id)
        }
    }
}
