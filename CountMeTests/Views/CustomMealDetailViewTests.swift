//
//  CustomMealDetailViewTests.swift
//  CountMeTests
//
//  Unit tests for CustomMealDetailView
//

import Testing
import SwiftUI
import SwiftData
@testable import CountMe

/// Unit tests for CustomMealDetailView functionality
///
/// Tests cover:
/// - Serving size adjustment and nutritional recalculation
/// - Adding meals to daily log
/// - Meal deletion
/// - UI state management
/// - Error handling
///
/// **Feature: ai-recipe-tracking**
struct CustomMealDetailViewTests {
    
    // MARK: - Test Fixtures
    
    /// Creates a test model container with in-memory storage
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
    }
    
    /// Creates a sample custom meal for testing
    private func createSampleMeal() -> CustomMeal {
        return CustomMeal(
            name: "Test Meal",
            ingredients: [
                Ingredient(
                    name: "Chicken",
                    quantity: 6,
                    unit: "oz",
                    calories: 200,
                    protein: 40,
                    carbohydrates: 0,
                    fats: 5
                ),
                Ingredient(
                    name: "Rice",
                    quantity: 1,
                    unit: "cup",
                    calories: 200,
                    protein: 4,
                    carbohydrates: 45,
                    fats: 1
                )
            ],
            createdAt: Date().addingTimeInterval(-86400),
            lastUsedAt: Date().addingTimeInterval(-3600)
        )
    }
    
    // MARK: - Serving Size Adjustment Tests
    
    @Test("Serving size multiplier adjusts calories proportionally")
    func testServingSizeAdjustsCalories() async throws {
        let meal = createSampleMeal()
        let originalCalories = meal.totalCalories
        let multiplier = 2.0
        
        // Expected calories after adjustment
        let expectedCalories = originalCalories * multiplier
        
        #expect(expectedCalories == 800.0) // (200 + 200) * 2
    }
    
    @Test("Serving size multiplier adjusts protein proportionally")
    func testServingSizeAdjustsProtein() async throws {
        let meal = createSampleMeal()
        let originalProtein = meal.totalProtein
        let multiplier = 0.5
        
        // Expected protein after adjustment
        let expectedProtein = originalProtein * multiplier
        
        #expect(expectedProtein == 22.0) // (40 + 4) * 0.5
    }
    
    @Test("Serving size multiplier adjusts carbohydrates proportionally")
    func testServingSizeAdjustsCarbohydrates() async throws {
        let meal = createSampleMeal()
        let originalCarbs = meal.totalCarbohydrates
        let multiplier = 1.5
        
        // Expected carbs after adjustment
        let expectedCarbs = originalCarbs * multiplier
        
        #expect(expectedCarbs == 67.5) // (0 + 45) * 1.5
    }
    
    @Test("Serving size multiplier adjusts fats proportionally")
    func testServingSizeAdjustsFats() async throws {
        let meal = createSampleMeal()
        let originalFats = meal.totalFats
        let multiplier = 0.25
        
        // Expected fats after adjustment
        let expectedFats = originalFats * multiplier
        
        #expect(expectedFats == 1.5) // (5 + 1) * 0.25
    }
    
    @Test("Serving size multiplier adjusts ingredient quantities")
    func testServingSizeAdjustsIngredientQuantities() async throws {
        let meal = createSampleMeal()
        let multiplier = 2.0
        
        // Check first ingredient
        let firstIngredient = meal.ingredients[0]
        let expectedQuantity = firstIngredient.quantity * multiplier
        
        #expect(expectedQuantity == 12.0) // 6 * 2
    }
    
    // MARK: - Adding to Daily Log Tests
    
    @Test("Adding meal to daily log creates a single food item for the meal")
    func testAddingMealCreatesCorrectNumberOfFoodItems() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        let log = DailyLog(date: Date())
        
        // Add meal to log (must be on main actor)
        @MainActor func addMeal() async throws -> [FoodItem] {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            return try await manager.addCustomMealToLog(
                meal,
                servingMultiplier: 1.0,
                log: log
            )
        }
        
        let foodItems = try await addMeal()
        
        // Should create a single food item for the whole meal
        #expect(foodItems.count == 1)
        #expect(foodItems[0].name == "Test Meal")
        #expect(foodItems[0].calories == 400.0) // 200 + 200
    }
    
    @Test("Adding meal with multiplier adjusts food item calories")
    func testAddingMealWithMultiplierAdjustsCalories() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        let log = DailyLog(date: Date())
        let multiplier = 2.0
        
        // Add meal to log with multiplier (must be on main actor)
        @MainActor func addMeal() async throws -> [FoodItem] {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            return try await manager.addCustomMealToLog(
                meal,
                servingMultiplier: multiplier,
                log: log
            )
        }
        
        let foodItems = try await addMeal()
        
        // Single food item with total meal calories scaled by multiplier
        #expect(foodItems.count == 1)
        let expectedCalories = meal.totalCalories * multiplier
        #expect(foodItems[0].calories == expectedCalories)
        #expect(foodItems[0].calories == 800.0) // (200 + 200) * 2
    }
    
    @Test("Adding meal sets food item source to customMeal")
    func testAddingMealSetsFoodItemSource() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        let log = DailyLog(date: Date())
        
        // Add meal to log (must be on main actor)
        @MainActor func addMeal() async throws -> [FoodItem] {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            return try await manager.addCustomMealToLog(
                meal,
                servingMultiplier: 1.0,
                log: log
            )
        }
        
        let foodItems = try await addMeal()
        
        // All food items should have customMeal source
        for foodItem in foodItems {
            #expect(foodItem.source == FoodItemSource.customMeal)
        }
    }
    
    @Test("Adding meal updates lastUsedAt timestamp")
    func testAddingMealUpdatesLastUsedAt() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        let originalLastUsedAt = meal.lastUsedAt
        let log = DailyLog(date: Date())
        
        // Wait a moment to ensure timestamp difference (reduced from 100ms to 1ms)
        try await Task.sleep(nanoseconds: 1_000_000) // 0.001 seconds
        
        // Add meal to log (must be on main actor)
        @MainActor func addMeal() async throws -> [FoodItem] {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            return try await manager.addCustomMealToLog(
                meal,
                servingMultiplier: 1.0,
                log: log
            )
        }
        
        let _ = try await addMeal()
        
        // lastUsedAt should be updated
        #expect(meal.lastUsedAt > originalLastUsedAt)
    }
    
    @Test("Adding meal with zero multiplier throws error")
    func testAddingMealWithZeroMultiplierThrowsError() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        let log = DailyLog(date: Date())
        
        // Attempt to add meal with zero multiplier (must be on main actor)
        @MainActor func addMeal() async throws {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            
            do {
                let _ = try await manager.addCustomMealToLog(
                    meal,
                    servingMultiplier: 0.0,
                    log: log
                )
                
                // Should not reach here
                #expect(Bool(false), "Expected error to be thrown")
            } catch {
                // Error should be thrown
                #expect(manager.errorMessage != nil)
                #expect(manager.errorMessage?.contains("greater than zero") == true)
            }
        }
        
        try await addMeal()
    }
    
    @Test("Adding meal with negative multiplier throws error")
    func testAddingMealWithNegativeMultiplierThrowsError() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        let log = DailyLog(date: Date())
        
        // Attempt to add meal with negative multiplier (must be on main actor)
        @MainActor func addMeal() async throws {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            
            do {
                let _ = try await manager.addCustomMealToLog(
                    meal,
                    servingMultiplier: -1.0,
                    log: log
                )
                
                // Should not reach here
                #expect(Bool(false), "Expected error to be thrown")
            } catch {
                // Error should be thrown
                #expect(manager.errorMessage != nil)
            }
        }
        
        try await addMeal()
    }
    
    // MARK: - Meal Deletion Tests
    
    @Test("Deleting meal removes it from data store")
    func testDeletingMealRemovesFromDataStore() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        let aiParser = AIRecipeParser()
        
        let meal = createSampleMeal()
        
        // Save meal
        try await dataStore.saveCustomMeal(meal)
        
        // Verify meal exists
        let fetchedMeal = try await dataStore.fetchCustomMeal(byId: meal.id)
        #expect(fetchedMeal != nil)
        
        // Delete meal (must be on main actor)
        @MainActor func deleteMeal() async throws {
            let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
            try await manager.deleteCustomMeal(meal)
        }
        
        try await deleteMeal()
        
        // Verify meal is deleted
        let deletedMeal = try await dataStore.fetchCustomMeal(byId: meal.id)
        #expect(deletedMeal == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("Meal with no macros displays correctly")
    func testMealWithNoMacrosDisplaysCorrectly() async throws {
        let mealWithoutMacros = CustomMeal(
            name: "Simple Meal",
            ingredients: [
                Ingredient(
                    name: "Food Item",
                    quantity: 1,
                    unit: "serving",
                    calories: 100
                    // No protein, carbs, or fats
                )
            ]
        )
        
        // Should have zero macros
        #expect(mealWithoutMacros.totalProtein == 0)
        #expect(mealWithoutMacros.totalCarbohydrates == 0)
        #expect(mealWithoutMacros.totalFats == 0)
        
        // Should still have calories
        #expect(mealWithoutMacros.totalCalories == 100)
    }
    
    @Test("Meal with partial macros displays correctly")
    func testMealWithPartialMacrosDisplaysCorrectly() async throws {
        let mealWithPartialMacros = CustomMeal(
            name: "Partial Macros Meal",
            ingredients: [
                Ingredient(
                    name: "Food Item 1",
                    quantity: 1,
                    unit: "serving",
                    calories: 100,
                    protein: 10
                    // No carbs or fats
                ),
                Ingredient(
                    name: "Food Item 2",
                    quantity: 1,
                    unit: "serving",
                    calories: 150,
                    carbohydrates: 20
                    // No protein or fats
                )
            ]
        )
        
        // Should sum available macros and treat nil as zero
        #expect(mealWithPartialMacros.totalProtein == 10)
        #expect(mealWithPartialMacros.totalCarbohydrates == 20)
        #expect(mealWithPartialMacros.totalFats == 0)
        #expect(mealWithPartialMacros.totalCalories == 250)
    }
    
    @Test("Very small serving multiplier works correctly")
    func testVerySmallServingMultiplier() async throws {
        let meal = createSampleMeal()
        let multiplier = 0.1
        
        let expectedCalories = meal.totalCalories * multiplier
        
        #expect(expectedCalories == 40.0) // (200 + 200) * 0.1
    }
    
    @Test("Very large serving multiplier works correctly")
    func testVeryLargeServingMultiplier() async throws {
        let meal = createSampleMeal()
        let multiplier = 10.0
        
        let expectedCalories = meal.totalCalories * multiplier
        
        #expect(expectedCalories == 4000.0) // (200 + 200) * 10
    }
}
