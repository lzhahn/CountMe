//
//  CustomMealSyncTests.swift
//  CountMeTests
//
//  Tests for custom meal sync behavior when adding meals to daily logs.
//  Validates that CustomMealManager properly creates FoodItems, adds them
//  to the shared daily log, and configures sync engine for cloud upload.
//
//  Bug fix validation: CustomMealDetailView was creating its own DataStore
//  instead of using the shared one, and CustomMealManager was never given
//  a sync engine or userId.
//

import Testing
import SwiftData
import Foundation
@testable import CountMe

/// Tests for custom meal → daily log sync behavior
///
/// Validates:
/// - FoodItem creation from custom meal uses correct DataStore
/// - Serving multiplier math is correct across random inputs
/// - Sync engine and userId are propagated to created FoodItems
/// - addCustomMealToLog adds items to the provided daily log
@Suite("Custom Meal Sync Behavior")
@MainActor
struct CustomMealSyncTests {

    // MARK: - Test Helpers

    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self, ExerciseItem.self,
            configurations: config
        )
    }

    private func createTestIngredient(
        name: String = "Ingredient",
        calories: Double = 100,
        protein: Double = 10,
        carbs: Double = 15,
        fats: Double = 5
    ) -> Ingredient {
        try! Ingredient(name: name, quantity: 1.0, unit: "cup", calories: calories,
                   protein: protein, carbohydrates: carbs, fats: fats)
    }

    // MARK: - Unit Tests

    @Test("addCustomMealToLog creates FoodItem in the provided daily log")
    func testAddCustomMealToLog_CreatesItemInLog() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        let meal = try! CustomMeal(
            name: "Test Meal",
            ingredients: [
                createTestIngredient(name: "Chicken", calories: 200, protein: 30, carbs: 0, fats: 8),
                createTestIngredient(name: "Rice", calories: 150, protein: 3, carbs: 35, fats: 1)
            ],
            servingsCount: 1.0
        )
        try await dataStore.saveCustomMeal(meal)

        let log = try DailyLog(date: Date())
        try await dataStore.saveDailyLog(log)

        let items = try await manager.addCustomMealToLog(meal, servingMultiplier: 1.0, log: log)

        #expect(items.count == 1)
        #expect(log.foodItems.count == 1)
        #expect(log.foodItems.first?.name == "Test Meal")
        #expect(log.foodItems.first?.calories == 350) // 200 + 150
        #expect(log.foodItems.first?.source == .customMeal)
    }

    @Test("addCustomMealToLog with serving multiplier scales nutrition correctly")
    func testAddCustomMealToLog_ServingMultiplierScales() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        let meal = try! CustomMeal(
            name: "Pasta",
            ingredients: [
                createTestIngredient(name: "Pasta", calories: 400, protein: 12, carbs: 80, fats: 2)
            ],
            servingsCount: 2.0
        )
        try await dataStore.saveCustomMeal(meal)

        let log = try DailyLog(date: Date())
        try await dataStore.saveDailyLog(log)

        // Request 1 serving of a 2-serving recipe → half the total
        let items = try await manager.addCustomMealToLog(meal, servingMultiplier: 1.0, log: log)

        let item = try #require(items.first)
        #expect(item.calories == 200) // 400 * (1.0 / 2.0)
        #expect(item.protein == 6)    // 12 * (1.0 / 2.0)
    }

    @Test("addCustomMealToLog rejects zero serving multiplier")
    func testAddCustomMealToLog_ZeroMultiplier_Throws() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        let meal = try! CustomMeal(
            name: "Salad",
            ingredients: [createTestIngredient()],
            servingsCount: 1.0
        )
        try await dataStore.saveCustomMeal(meal)

        let log = try DailyLog(date: Date())
        try await dataStore.saveDailyLog(log)

        do {
            _ = try await manager.addCustomMealToLog(meal, servingMultiplier: 0.0, log: log)
            Issue.record("Expected error for zero serving multiplier")
        } catch {
            #expect(manager.errorMessage?.contains("greater than zero") == true)
        }

        #expect(log.foodItems.isEmpty)
    }

    @Test("addCustomMealToLog updates meal lastUsedAt timestamp")
    func testAddCustomMealToLog_UpdatesLastUsedAt() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        let oldDate = Date().addingTimeInterval(-86400)
        let meal = try! CustomMeal(
            name: "Soup",
            ingredients: [createTestIngredient()],
            lastUsedAt: oldDate,
            servingsCount: 1.0
        )
        try await dataStore.saveCustomMeal(meal)

        let log = try DailyLog(date: Date())
        try await dataStore.saveDailyLog(log)

        _ = try await manager.addCustomMealToLog(meal, servingMultiplier: 1.0, log: log)

        #expect(meal.lastUsedAt > oldDate)
    }

    @Test("configureSyncEngine sets sync engine and userId on manager")
    func testConfigureSyncEngine_SetsProperties() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        let syncEngine = FirebaseSyncEngine(dataStore: dataStore)
        manager.configureSyncEngine(syncEngine, userId: "test-user-123")

        // Verify by adding a meal to log — the food item should get userId set
        let meal = try! CustomMeal(
            name: "Configured Meal",
            ingredients: [createTestIngredient()],
            servingsCount: 1.0
        )
        try await dataStore.saveCustomMeal(meal)

        let log = try DailyLog(date: Date())
        try await dataStore.saveDailyLog(log)

        let items = try await manager.addCustomMealToLog(meal, servingMultiplier: 1.0, log: log)
        let item = try #require(items.first)

        #expect(item.userId == "test-user-123")
        #expect(item.syncStatus == .pendingUpload)
    }

    @Test("CustomMealManager initialized with syncEngine passes it to food items")
    func testInitWithSyncEngine_FoodItemsGetUserId() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let syncEngine = FirebaseSyncEngine(dataStore: dataStore)
        let manager = CustomMealManager(
            dataStore: dataStore,
            aiParser: aiParser,
            syncEngine: syncEngine,
            userId: "init-user-456"
        )

        let meal = try! CustomMeal(
            name: "Init Test Meal",
            ingredients: [createTestIngredient()],
            servingsCount: 1.0
        )
        try await dataStore.saveCustomMeal(meal)

        let log = try DailyLog(date: Date())
        try await dataStore.saveDailyLog(log)

        let items = try await manager.addCustomMealToLog(meal, servingMultiplier: 1.0, log: log)
        let item = try #require(items.first)

        #expect(item.userId == "init-user-456")
    }

    // MARK: - Property-Based Tests

    @Test("Property: Serving multiplier scales all macros proportionally",
          .tags(.property))
    func testProperty_ServingMultiplierScaling_1() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        for _ in 0..<100 {
            let ingredientCount = Int.random(in: 1...5)
            let ingredients = (0..<ingredientCount).map { i in
                createTestIngredient(
                    name: "Ingredient \(i)",
                    calories: Double.random(in: 10...500),
                    protein: Double.random(in: 0...50),
                    carbs: Double.random(in: 0...100),
                    fats: Double.random(in: 0...40)
                )
            }

            let servingsCount = Double.random(in: 1...8)
            let multiplier = Double.random(in: 0.25...5.0)

            let meal = try! CustomMeal(
                name: "Property Test Meal",
                ingredients: ingredients,
                servingsCount: servingsCount
            )
            try await dataStore.saveCustomMeal(meal)

            let log = try DailyLog(date: Date())
            try await dataStore.saveDailyLog(log)

            let items = try await manager.addCustomMealToLog(
                meal, servingMultiplier: multiplier, log: log
            )
            let item = try #require(items.first)

            let perServingFactor = multiplier / servingsCount
            let expectedCalories = meal.totalCalories * perServingFactor
            let expectedProtein = meal.totalProtein * perServingFactor
            let expectedCarbs = meal.totalCarbohydrates * perServingFactor
            let expectedFats = meal.totalFats * perServingFactor

            // Use tolerance for floating point comparison
            #expect(abs(item.calories - expectedCalories) < 0.001)
            #expect(abs((item.protein ?? 0) - expectedProtein) < 0.001)
            #expect(abs((item.carbohydrates ?? 0) - expectedCarbs) < 0.001)
            #expect(abs((item.fats ?? 0) - expectedFats) < 0.001)

            // Clean up for next iteration
            log.foodItems.removeAll()
            try await dataStore.deleteCustomMeal(meal)
        }
    }

    @Test("Property: FoodItem from custom meal always has .customMeal source",
          .tags(.property))
    func testProperty_CustomMealSource_2() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)

        for _ in 0..<100 {
            let meal = try! CustomMeal(
                name: "Source Test \(UUID().uuidString.prefix(6))",
                ingredients: [createTestIngredient(
                    calories: Double.random(in: 1...1000)
                )],
                servingsCount: Double.random(in: 1...4)
            )
            try await dataStore.saveCustomMeal(meal)

            let log = try DailyLog(date: Date())
            try await dataStore.saveDailyLog(log)

            let items = try await manager.addCustomMealToLog(
                meal, servingMultiplier: Double.random(in: 0.25...3.0), log: log
            )

            #expect(items.allSatisfy { $0.source == .customMeal })

            log.foodItems.removeAll()
            try await dataStore.deleteCustomMeal(meal)
        }
    }
}

// MARK: - Tag Extension
// Note: Tag extensions are defined in CalorieEstimatorTests.swift to avoid duplicates
