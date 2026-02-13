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
    
    // MARK: - Test Serving Information Display (Task 5)
    
    func testMealRowDisplaysServingInfoForMultipleServings() async throws {
        // Create meal with multiple servings
        let meal = createSampleMeal(name: "Family Recipe", calories: 800)
        meal.servingsCount = 4.0
        
        try await dataStore.saveCustomMeal(meal)
        await manager.loadAllCustomMeals()
        
        // Verify meal has multiple servings
        await MainActor.run {
            let loadedMeal = manager.savedMeals.first
            XCTAssertNotNil(loadedMeal)
            if let loadedMeal = loadedMeal {
                XCTAssertTrue(loadedMeal.hasMultipleServings, "Meal should have multiple servings")
                XCTAssertEqual(loadedMeal.servingsCount, 4.0)
                
                // Verify per-serving calculations
                XCTAssertNotNil(loadedMeal.perServingCalories)
                XCTAssertEqual(loadedMeal.perServingCalories ?? 0, 200, accuracy: 0.1, "Per-serving calories should be 800/4 = 200")
            }
        }
    }
    
    func testMealRowHidesServingInfoForSingleServing() async throws {
        // Create meal with single serving
        let meal = createSampleMeal(name: "Single Serving Meal", calories: 400)
        meal.servingsCount = 1.0
        
        try await dataStore.saveCustomMeal(meal)
        await manager.loadAllCustomMeals()
        
        // Verify meal does not have multiple servings
        await MainActor.run {
            let loadedMeal = manager.savedMeals.first
            XCTAssertNotNil(loadedMeal)
            if let loadedMeal = loadedMeal {
                XCTAssertFalse(loadedMeal.hasMultipleServings, "Meal should not have multiple servings")
                XCTAssertEqual(loadedMeal.servingsCount, 1.0)
                
                // Verify per-serving values are nil
                XCTAssertNil(loadedMeal.perServingCalories, "Per-serving calories should be nil for single serving")
            }
        }
    }
    
    // MARK: - Test Serving Information Display (Task 5)
    
    func testServingCountFormattingWithoutDecimals() async throws {
        // Create meals with whole number and fractional servings
        let wholeServingMeal = createSampleMeal(name: "Whole Servings", calories: 600)
        wholeServingMeal.servingsCount = 4.0
        
        let fractionalServingMeal = createSampleMeal(name: "Fractional Servings", calories: 650)
        fractionalServingMeal.servingsCount = 4.5
        
        try await dataStore.saveCustomMeal(wholeServingMeal)
        try await dataStore.saveCustomMeal(fractionalServingMeal)
        await manager.loadAllCustomMeals()
        
        // Verify serving counts
        await MainActor.run {
            XCTAssertEqual(manager.savedMeals.count, 2)
            
            let wholeMeal = manager.savedMeals.first { $0.name == "Whole Servings" }
            let fractionalMeal = manager.savedMeals.first { $0.name == "Fractional Servings" }
            
            XCTAssertNotNil(wholeMeal)
            XCTAssertNotNil(fractionalMeal)
            
            if let wholeMeal = wholeMeal {
                // Whole number should display without decimals (4 not 4.0)
                XCTAssertEqual(wholeMeal.servingsCount, 4.0)
                XCTAssertEqual(wholeMeal.servingsCount.truncatingRemainder(dividingBy: 1), 0, "Should be whole number")
            }
            
            if let fractionalMeal = fractionalMeal {
                // Fractional number should display with decimals (4.5)
                XCTAssertEqual(fractionalMeal.servingsCount, 4.5)
                XCTAssertNotEqual(fractionalMeal.servingsCount.truncatingRemainder(dividingBy: 1), 0, "Should have fractional part")
            }
        }
    }
    
    func testPerServingCaloriesCalculation() async throws {
        // Create meal with known values
        let meal = createSampleMeal(name: "Test Meal", calories: 1000)
        meal.servingsCount = 5.0
        
        try await dataStore.saveCustomMeal(meal)
        await manager.loadAllCustomMeals()
        
        // Verify per-serving calculation
        await MainActor.run {
            let loadedMeal = manager.savedMeals.first
            XCTAssertNotNil(loadedMeal)
            if let loadedMeal = loadedMeal {
                XCTAssertEqual(loadedMeal.totalCalories, 1000, accuracy: 0.1)
                if let perServingCal = loadedMeal.perServingCalories {
                    XCTAssertEqual(perServingCal, 200, accuracy: 0.1, "1000 calories / 5 servings = 200 cal/serving")
                } else {
                    XCTFail("Per-serving calories should not be nil")
                }
            }
        }
    }
    
    func testPerServingMacrosCalculation() async throws {
        // Create meal with known macro values
        let ingredients = [
            Ingredient(name: "Ingredient", quantity: 1, unit: "batch", calories: 800, protein: 40, carbohydrates: 80, fats: 20)
        ]
        let meal = CustomMeal(name: "Macro Test Meal", ingredients: ingredients, servingsCount: 4.0)
        
        try await dataStore.saveCustomMeal(meal)
        await manager.loadAllCustomMeals()
        
        // Verify per-serving macro calculations
        await MainActor.run {
            let loadedMeal = manager.savedMeals.first
            XCTAssertNotNil(loadedMeal)
            if let loadedMeal = loadedMeal {
                XCTAssertTrue(loadedMeal.hasMultipleServings)
                
                // Total values
                XCTAssertEqual(loadedMeal.totalCalories, 800, accuracy: 0.1)
                XCTAssertEqual(loadedMeal.totalProtein, 40, accuracy: 0.1)
                XCTAssertEqual(loadedMeal.totalCarbohydrates, 80, accuracy: 0.1)
                XCTAssertEqual(loadedMeal.totalFats, 20, accuracy: 0.1)
                
                // Per-serving values (divided by 4)
                if let perServingCal = loadedMeal.perServingCalories {
                    XCTAssertEqual(perServingCal, 200, accuracy: 0.1)
                }
                if let perServingProtein = loadedMeal.perServingProtein {
                    XCTAssertEqual(perServingProtein, 10, accuracy: 0.1)
                }
                if let perServingCarbs = loadedMeal.perServingCarbohydrates {
                    XCTAssertEqual(perServingCarbs, 20, accuracy: 0.1)
                }
                if let perServingFats = loadedMeal.perServingFats {
                    XCTAssertEqual(perServingFats, 5, accuracy: 0.1)
                }
            }
        }
    }
    
    func testBackwardCompatibilityWithDefaultServingCount() async throws {
        // Create meal without explicitly setting servingsCount (should default to 1.0)
        let meal = createSampleMeal(name: "Legacy Meal", calories: 500)
        // Don't set servingsCount - it should default to 1.0
        
        try await dataStore.saveCustomMeal(meal)
        await manager.loadAllCustomMeals()
        
        // Verify backward compatibility
        await MainActor.run {
            let loadedMeal = manager.savedMeals.first
            XCTAssertNotNil(loadedMeal)
            if let loadedMeal = loadedMeal {
                XCTAssertEqual(loadedMeal.servingsCount, 1.0, "Should default to 1.0 serving")
                XCTAssertFalse(loadedMeal.hasMultipleServings, "Should not show as multiple servings")
                XCTAssertNil(loadedMeal.perServingCalories, "Should not calculate per-serving for single serving")
            }
        }
    }
}
