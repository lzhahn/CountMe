//
//  ExercisePermissionsDebugTest.swift
//  CountMeTests
//
//  Debug test to diagnose exercise item permissions issue
//

import Testing
import Foundation
import SwiftData
@testable import CountMe

@Suite("Exercise Permissions Debug Tests")
struct ExercisePermissionsDebugTests {
    
    /// Helper to create test container
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
    
    @Test("Debug: Verify exercise item has correct userId before upload")
    func testDebug_ExerciseItem_UserIdSetCorrectly() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let syncEngine = FirebaseSyncEngine(dataStore: dataStore)
        
        // Create exercise item
        let exercise = try ExerciseItem(
            name: "Running",
            caloriesBurned: 300,
            durationMinutes: 30,
            exerciseType: .running,
            intensity: .moderate
        )
        
        print("🔍 Initial exercise userId: '\(exercise.userId)'")
        print("🔍 Initial exercise id: '\(exercise.id)'")
        
        // Sync with test userId
        let testUserId = "test-user-123"
        
        do {
            try await syncEngine.syncExerciseItem(exercise, userId: testUserId)
        } catch {
            print("⚠️ Sync failed (expected in tests): \(error)")
        }
        
        // Fetch from local store to verify userId was set
        let fetched = try await dataStore.fetchExerciseItem(byId: exercise.id)
        
        print("🔍 After sync - fetched userId: '\(fetched?.userId ?? "nil")'")
        print("🔍 After sync - fetched syncStatus: '\(fetched?.syncStatus.rawValue ?? "nil")'")
        
        // Verify userId was set correctly
        #expect(fetched != nil, "Exercise item should exist in local store")
        #expect(fetched?.userId == testUserId, "Exercise userId should match authenticated user")
        #expect(fetched?.syncStatus == .pendingUpload, "Exercise should be pending upload")
    }
    
    @Test("Debug: Compare food item and exercise item sync behavior")
    func testDebug_CompareFoodAndExerciseSync() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: ModelContext(container))
        let syncEngine = FirebaseSyncEngine(dataStore: dataStore)
        
        let testUserId = "test-user-456"
        
        // Create and sync food item
        let food = try FoodItem(
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbs: 25,
            fat: 0.3,
            servingSize: 1.0
        )
        
        print("🍎 Food item initial userId: '\(food.userId)'")
        
        do {
            try await syncEngine.syncFoodItem(food, userId: testUserId)
        } catch {
            print("⚠️ Food sync failed (expected): \(error)")
        }
        
        let fetchedFood = try await dataStore.fetchFoodItem(byId: food.id)
        print("🍎 Food item after sync userId: '\(fetchedFood?.userId ?? "nil")'")
        
        // Create and sync exercise item
        let exercise = try ExerciseItem(
            name: "Running",
            caloriesBurned: 300,
            durationMinutes: 30,
            exerciseType: .running,
            intensity: .moderate
        )
        
        print("🏃 Exercise item initial userId: '\(exercise.userId)'")
        
        do {
            try await syncEngine.syncExerciseItem(exercise, userId: testUserId)
        } catch {
            print("⚠️ Exercise sync failed (expected): \(error)")
        }
        
        let fetchedExercise = try await dataStore.fetchExerciseItem(byId: exercise.id)
        print("🏃 Exercise item after sync userId: '\(fetchedExercise?.userId ?? "nil")'")
        
        // Both should behave identically
        #expect(fetchedFood?.userId == testUserId, "Food userId should be set")
        #expect(fetchedExercise?.userId == testUserId, "Exercise userId should be set")
    }
    
    @Test("Debug: Verify toFirestoreData includes correct userId")
    func testDebug_ExerciseItem_ToFirestoreData() async throws {
        // Create exercise item
        let exercise = try ExerciseItem(
            name: "Running",
            caloriesBurned: 300,
            durationMinutes: 30,
            exerciseType: .running,
            intensity: .moderate
        )
        
        // Set userId manually (simulating what sync does)
        exercise.userId = "test-user-789"
        
        // Convert to Firestore data
        let firestoreData = exercise.toFirestoreData()
        
        print("🔍 Firestore data keys: \(firestoreData.keys.sorted())")
        print("🔍 Firestore data userId: '\(firestoreData["userId"] ?? "missing")'")
        print("🔍 Firestore data id: '\(firestoreData["id"] ?? "missing")'")
        
        // Verify userId is in the data
        #expect(firestoreData["userId"] as? String == "test-user-789", "userId should be in Firestore data")
        #expect(firestoreData["id"] as? String == exercise.id, "id should match")
    }
}
