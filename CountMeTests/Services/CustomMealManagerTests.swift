//
//  CustomMealManagerTests.swift
//  CountMeTests
//
//  Tests for CustomMealManager business logic
//

import Testing
import SwiftData
@testable import CountMe

/// Tests for CustomMealManager functionality
///
/// **Validates: Requirements 1.5, 1.6, 6.1, 7.3**
@MainActor
struct CustomMealManagerTests {
    
    // MARK: - Test Helpers
    
    /// Creates an in-memory test container
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
    }
    
    /// Creates a test ingredient
    private func createTestIngredient(
        name: String = "Test Ingredient",
        quantity: Double = 100,
        unit: String = "g",
        calories: Double = 100
    ) -> Ingredient {
        return try! Ingredient(
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            protein: 10,
            carbohydrates: 15,
            fats: 5
        )
    }
    
    // MARK: - Tests for servingsCount Parameter
    
    @Test("Save custom meal with servingsCount = 4")
    func testSaveCustomMealWithServingsCount() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        
        let ingredients = [
            createTestIngredient(name: "Chicken", calories: 200),
            createTestIngredient(name: "Rice", calories: 150)
        ]
        
        // Execute
        let meal = try await manager.saveCustomMeal(
            name: "Chicken and Rice",
            ingredients: ingredients,
            servingsCount: 4.0
        )
        
        // Verify
        #expect(meal.name == "Chicken and Rice")
        #expect(meal.servingsCount == 4.0)
        #expect(meal.ingredients.count == 2)
        
        // Verify it was persisted
        let fetchedMeal = try await dataStore.fetchCustomMeal(id: meal._id)
        #expect(fetchedMeal != nil)
        #expect(fetchedMeal?.servingsCount == 4.0)
    }
    
    @Test("Save custom meal with default servingsCount = 1")
    func testSaveCustomMealWithDefaultServingsCount() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        
        let ingredients = [createTestIngredient(name: "Pasta", calories: 300)]
        
        // Execute - not passing servingsCount, should default to 1.0
        let meal = try await manager.saveCustomMeal(
            name: "Simple Pasta",
            ingredients: ingredients
        )
        
        // Verify
        #expect(meal.servingsCount == 1.0)
        
        // Verify it was persisted with default value
        let fetchedMeal = try await dataStore.fetchCustomMeal(id: meal._id)
        #expect(fetchedMeal?.servingsCount == 1.0)
    }
    
    @Test("Save custom meal rejects servingsCount = 0")
    func testSaveCustomMealRejectsZeroServingsCount() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        
        let ingredients = [createTestIngredient(name: "Salad", calories: 100)]
        
        // Execute & Verify - should throw ValidationError.invalidServingCount
        do {
            _ = try await manager.saveCustomMeal(
                name: "Invalid Meal",
                ingredients: ingredients,
                servingsCount: 0.0
            )
            Issue.record("Expected ValidationError.nonPositiveServings to be thrown")
        } catch let error as ValidationError {
            // Verify it's the specific nonPositiveServings case
            if case .nonPositiveServings = error {
                // Success - correct error type
            } else {
                Issue.record("Expected ValidationError.nonPositiveServings, got \(error)")
            }
        } catch {
            Issue.record("Expected ValidationError.nonPositiveServings, got \(error)")
        }
        
        // Verify error message was set
        #expect(manager.errorMessage != nil)
        #expect(manager.errorMessage?.contains("greater than zero") == true)
    }
    
    @Test("Save custom meal rejects negative servingsCount")
    func testSaveCustomMealRejectsNegativeServingsCount() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        
        let ingredients = [createTestIngredient(name: "Soup", calories: 150)]
        
        // Execute & Verify - should throw ValidationError.invalidServingCount
        do {
            _ = try await manager.saveCustomMeal(
                name: "Invalid Meal",
                ingredients: ingredients,
                servingsCount: -2.0
            )
            Issue.record("Expected ValidationError.nonPositiveServings to be thrown")
        } catch let error as ValidationError {
            // Verify it's the specific nonPositiveServings case
            if case .nonPositiveServings = error {
                // Success - correct error type
            } else {
                Issue.record("Expected ValidationError.nonPositiveServings, got \(error)")
            }
        } catch {
            Issue.record("Expected ValidationError.nonPositiveServings, got \(error)")
        }
        
        // Verify error message was set
        #expect(manager.errorMessage != nil)
        #expect(manager.errorMessage?.contains("positive") == true)
    }
    
    @Test("Save custom meal with fractional servingsCount")
    func testSaveCustomMealWithFractionalServingsCount() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        
        let ingredients = [createTestIngredient(name: "Smoothie", calories: 200)]
        
        // Execute - fractional servings should be allowed
        let meal = try await manager.saveCustomMeal(
            name: "Smoothie Recipe",
            ingredients: ingredients,
            servingsCount: 2.5
        )
        
        // Verify
        #expect(meal.servingsCount == 2.5)
        
        // Verify it was persisted
        let fetchedMeal = try await dataStore.fetchCustomMeal(id: meal._id)
        #expect(fetchedMeal?.servingsCount == 2.5)
    }
    
    @Test("Backward compatibility - existing code without servingsCount works")
    func testBackwardCompatibility() async throws {
        // Setup
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        
        let ingredients = [createTestIngredient(name: "Eggs", calories: 140)]
        
        // Execute - calling without servingsCount parameter (backward compatibility)
        let meal = try await manager.saveCustomMeal(
            name: "Scrambled Eggs",
            ingredients: ingredients
        )
        
        // Verify - should default to 1.0
        #expect(meal.servingsCount == 1.0)
        #expect(meal.name == "Scrambled Eggs")
        #expect(meal.ingredients.count == 1)
    }
}
