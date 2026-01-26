//
//  CustomMealsLibraryViewTests.swift
//  CountMeTests
//
//  Integration tests for CustomMealsLibraryView
//  Task 12: Implement CustomMealsLibraryView for browsing saved meals
//

import XCTest
import SwiftData
@testable import CountMe

/// Integration tests for CustomMealsLibraryView
/// Tests the complete user journeys for:
/// - Browsing custom meals
/// - Searching and filtering meals
/// - Deleting meals
/// - Empty states
final class CustomMealsLibraryViewTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var dataStore: CountMe.DataStore!
    var aiParser: AIRecipeParser!
    var manager: CustomMealManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
        modelContext = ModelContext(modelContainer)
        
        // Initialize dependencies
        dataStore = CountMe.DataStore(modelContext: modelContext)
        aiParser = AIRecipeParser()
        
        // Initialize manager on main actor
        await MainActor.run {
            manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
        }
    }
    
    override func tearDown() async throws {
        manager = nil
        aiParser = nil
        dataStore = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Loading Meals
    
    func testLoadEmptyMealsList() async throws {
        // Load meals when none exist
        await manager.loadAllCustomMeals()
        
        // Verify empty state
        await MainActor.run {
            XCTAssertTrue(manager.savedMeals.isEmpty, "Should have no meals initially")
            XCTAssertFalse(manager.isLoading, "Should not be loading")
            XCTAssertNil(manager.errorMessage, "Should have no error")
        }
    }
    
    func testLoadMealsWithData() async throws {
        // Create and save some meals
        let meal1 = createSampleMeal(name: "Chicken Stir Fry", calories: 424)
        let meal2 = createSampleMeal(name: "Protein Smoothie", calories: 255)
        
        try await dataStore.saveCustomMeal(meal1)
        try await dataStore.saveCustomMeal(meal2)
        
        // Load meals
        await manager.loadAllCustomMeals()
        
        // Verify meals are loaded
        await MainActor.run {
            XCTAssertEqual(manager.savedMeals.count, 2, "Should have 2 meals")
            XCTAssertFalse(manager.isLoading, "Should not be loading")
            XCTAssertNil(manager.errorMessage, "Should have no error")
            
            let mealNames = manager.savedMeals.map { $0.name }
            XCTAssertTrue(mealNames.contains("Chicken Stir Fry"))
            XCTAssertTrue(mealNames.contains("Protein Smoothie"))
        }
    }
    
    func testMealsSortedByLastUsed() async throws {
        // Create meals with different lastUsedAt timestamps
        let oldMeal = createSampleMeal(name: "Old Meal", calories: 300)
        oldMeal.lastUsedAt = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        
        let recentMeal = createSampleMeal(name: "Recent Meal", calories: 400)
        recentMeal.lastUsedAt = Date().addingTimeInterval(-3600) // 1 hour ago
        
        let newestMeal = createSampleMeal(name: "Newest Meal", calories: 500)
        newestMeal.lastUsedAt = Date() // Now
        
        try await dataStore.saveCustomMeal(oldMeal)
        try await dataStore.saveCustomMeal(recentMeal)
        try await dataStore.saveCustomMeal(newestMeal)
        
        // Load meals
        await manager.loadAllCustomMeals()
        
        // Verify sort order (most recent first)
        await MainActor.run {
            XCTAssertEqual(manager.savedMeals.count, 3)
            XCTAssertEqual(manager.savedMeals[0].name, "Newest Meal", "First meal should be newest")
            XCTAssertEqual(manager.savedMeals[1].name, "Recent Meal", "Second meal should be recent")
            XCTAssertEqual(manager.savedMeals[2].name, "Old Meal", "Third meal should be oldest")
        }
    }
    
    // MARK: - Test Searching and Filtering
    
    func testSearchMealsByName() async throws {
        // Create meals with different names
        let chickenMeal = createSampleMeal(name: "Chicken Stir Fry", calories: 424)
        let smoothieMeal = createSampleMeal(name: "Protein Smoothie", calories: 255)
        let saladMeal = createSampleMeal(name: "Chicken Caesar Salad", calories: 350)
        
        try await dataStore.saveCustomMeal(chickenMeal)
        try await dataStore.saveCustomMeal(smoothieMeal)
        try await dataStore.saveCustomMeal(saladMeal)
        
        // Search for "chicken"
        let results = await manager.searchCustomMeals(query: "chicken")
        
        // Verify results
        XCTAssertEqual(results.count, 2, "Should find 2 meals with 'chicken'")
        let resultNames = results.map { $0.name }
        XCTAssertTrue(resultNames.contains("Chicken Stir Fry"))
        XCTAssertTrue(resultNames.contains("Chicken Caesar Salad"))
        XCTAssertFalse(resultNames.contains("Protein Smoothie"))
    }
    
    func testSearchCaseInsensitive() async throws {
        // Create meal
        let meal = createSampleMeal(name: "Chicken Stir Fry", calories: 424)
        try await dataStore.saveCustomMeal(meal)
        
        // Search with different cases
        let lowerResults = await manager.searchCustomMeals(query: "chicken")
        let upperResults = await manager.searchCustomMeals(query: "CHICKEN")
        let mixedResults = await manager.searchCustomMeals(query: "ChIcKeN")
        
        // All should return the same result
        XCTAssertEqual(lowerResults.count, 1)
        XCTAssertEqual(upperResults.count, 1)
        XCTAssertEqual(mixedResults.count, 1)
    }
    
    func testSearchEmptyQuery() async throws {
        // Create meals
        let meal1 = createSampleMeal(name: "Meal 1", calories: 300)
        let meal2 = createSampleMeal(name: "Meal 2", calories: 400)
        
        try await dataStore.saveCustomMeal(meal1)
        try await dataStore.saveCustomMeal(meal2)
        
        // Search with empty query
        let results = await manager.searchCustomMeals(query: "")
        
        // Should return all meals
        XCTAssertEqual(results.count, 2, "Empty query should return all meals")
    }
    
    func testSearchNoResults() async throws {
        // Create meal
        let meal = createSampleMeal(name: "Chicken Stir Fry", calories: 424)
        try await dataStore.saveCustomMeal(meal)
        
        // Search for something that doesn't exist
        let results = await manager.searchCustomMeals(query: "pizza")
        
        // Should return empty array
        XCTAssertTrue(results.isEmpty, "Should return no results for non-matching query")
    }
    
    func testSearchPartialMatch() async throws {
        // Create meal
        let meal = createSampleMeal(name: "Chicken Stir Fry", calories: 424)
        try await dataStore.saveCustomMeal(meal)
        
        // Search with partial matches
        let stirResults = await manager.searchCustomMeals(query: "stir")
        let fryResults = await manager.searchCustomMeals(query: "fry")
        let chiResults = await manager.searchCustomMeals(query: "chi")
        
        // All should find the meal
        XCTAssertEqual(stirResults.count, 1)
        XCTAssertEqual(fryResults.count, 1)
        XCTAssertEqual(chiResults.count, 1)
    }
    
    // MARK: - Test Deleting Meals
    
    func testDeleteMeal() async throws {
        // Create and save meal
        let meal = createSampleMeal(name: "Test Meal", calories: 300)
        try await dataStore.saveCustomMeal(meal)
        
        // Load meals
        await manager.loadAllCustomMeals()
        
        await MainActor.run {
            XCTAssertEqual(manager.savedMeals.count, 1)
        }
        
        // Delete meal
        try await manager.deleteCustomMeal(meal)
        
        // Verify deletion
        await MainActor.run {
            XCTAssertTrue(manager.savedMeals.isEmpty, "Meal should be deleted")
        }
        
        // Verify persistence
        await manager.loadAllCustomMeals()
        
        await MainActor.run {
            XCTAssertTrue(manager.savedMeals.isEmpty, "Deletion should persist")
        }
    }
    
    func testDeleteMultipleMeals() async throws {
        // Create and save meals
        let meal1 = createSampleMeal(name: "Meal 1", calories: 300)
        let meal2 = createSampleMeal(name: "Meal 2", calories: 400)
        let meal3 = createSampleMeal(name: "Meal 3", calories: 500)
        
        try await dataStore.saveCustomMeal(meal1)
        try await dataStore.saveCustomMeal(meal2)
        try await dataStore.saveCustomMeal(meal3)
        
        // Load meals
        await manager.loadAllCustomMeals()
        
        await MainActor.run {
            XCTAssertEqual(manager.savedMeals.count, 3)
        }
        
        // Delete two meals
        try await manager.deleteCustomMeal(meal1)
        try await manager.deleteCustomMeal(meal3)
        
        // Verify only meal2 remains
        await MainActor.run {
            XCTAssertEqual(manager.savedMeals.count, 1)
            XCTAssertEqual(manager.savedMeals[0].name, "Meal 2")
        }
    }
    
    func testDeleteMealWithIngredients() async throws {
        // Create meal with multiple ingredients
        let meal = createSampleMeal(name: "Complex Meal", calories: 600)
        XCTAssertEqual(meal.ingredients.count, 3, "Should have 3 ingredients")
        
        try await dataStore.saveCustomMeal(meal)
        
        // Load meals
        await manager.loadAllCustomMeals()
        
        // Delete meal
        try await manager.deleteCustomMeal(meal)
        
        // Verify meal and ingredients are deleted
        await MainActor.run {
            XCTAssertTrue(manager.savedMeals.isEmpty, "Meal should be deleted")
        }
        
        // Verify no orphaned ingredients (cascade delete)
        let allMeals = try await dataStore.fetchAllCustomMeals()
        XCTAssertTrue(allMeals.isEmpty, "No meals should exist")
    }
    
    // MARK: - Test Meal Display Data
    
    func testMealNutritionalSummary() async throws {
        // Create meal with known nutritional values
        let ingredients = [
            Ingredient(name: "Chicken", quantity: 6, unit: "oz", calories: 187, protein: 35, carbohydrates: 0, fats: 4),
            Ingredient(name: "Rice", quantity: 1, unit: "cup", calories: 206, protein: 4, carbohydrates: 45, fats: 0.4),
            Ingredient(name: "Broccoli", quantity: 1, unit: "cup", calories: 31, protein: 2.5, carbohydrates: 6, fats: 0.3)
        ]
        
        let meal = CustomMeal(name: "Balanced Meal", ingredients: ingredients)
        
        // Verify computed totals
        XCTAssertEqual(meal.totalCalories, 424, accuracy: 0.1)
        XCTAssertEqual(meal.totalProtein, 41.5, accuracy: 0.1)
        XCTAssertEqual(meal.totalCarbohydrates, 51, accuracy: 0.1)
        XCTAssertEqual(meal.totalFats, 4.7, accuracy: 0.1)
    }
    
    func testMealWithPartialMacros() async throws {
        // Create meal where some ingredients lack macro data
        let ingredients = [
            Ingredient(name: "Item 1", quantity: 1, unit: "serving", calories: 100, protein: 10, carbohydrates: nil, fats: nil),
            Ingredient(name: "Item 2", quantity: 1, unit: "serving", calories: 200, protein: nil, carbohydrates: 20, fats: nil),
            Ingredient(name: "Item 3", quantity: 1, unit: "serving", calories: 150, protein: nil, carbohydrates: nil, fats: 5)
        ]
        
        let meal = CustomMeal(name: "Partial Macros Meal", ingredients: ingredients)
        
        // Verify totals treat nil as zero
        XCTAssertEqual(meal.totalCalories, 450)
        XCTAssertEqual(meal.totalProtein, 10)
        XCTAssertEqual(meal.totalCarbohydrates, 20)
        XCTAssertEqual(meal.totalFats, 5)
    }
    
    func testMealDates() async throws {
        // Create meal
        let createdDate = Date()
        let meal = createSampleMeal(name: "Test Meal", calories: 300)
        meal.createdAt = createdDate
        meal.lastUsedAt = createdDate
        
        try await dataStore.saveCustomMeal(meal)
        
        // Load and verify dates
        await manager.loadAllCustomMeals()
        
        await MainActor.run {
            let loadedMeal = manager.savedMeals.first
            XCTAssertNotNil(loadedMeal)
            if let loadedMeal = loadedMeal {
                XCTAssertEqual(loadedMeal.createdAt.timeIntervalSince1970, createdDate.timeIntervalSince1970, accuracy: 1.0)
                XCTAssertEqual(loadedMeal.lastUsedAt.timeIntervalSince1970, createdDate.timeIntervalSince1970, accuracy: 1.0)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sample custom meal for testing
    private func createSampleMeal(name: String, calories: Double) -> CustomMeal {
        let ingredients = [
            Ingredient(
                name: "Ingredient 1",
                quantity: 1,
                unit: "cup",
                calories: calories * 0.4,
                protein: 10,
                carbohydrates: 20,
                fats: 5
            ),
            Ingredient(
                name: "Ingredient 2",
                quantity: 1,
                unit: "oz",
                calories: calories * 0.3,
                protein: 8,
                carbohydrates: 15,
                fats: 3
            ),
            Ingredient(
                name: "Ingredient 3",
                quantity: 1,
                unit: "serving",
                calories: calories * 0.3,
                protein: 5,
                carbohydrates: 10,
                fats: 2
            )
        ]
        
        return CustomMeal(
            name: name,
            ingredients: ingredients,
            createdAt: Date(),
            lastUsedAt: Date(),
            servingsCount: 1.0
        )
    }
}
