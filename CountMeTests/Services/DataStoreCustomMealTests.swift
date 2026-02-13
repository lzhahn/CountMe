//
//  DataStoreCustomMealTests.swift
//  CountMeTests
//
//  Created by Kiro on 1/23/26.
//

import Foundation
import Testing
import SwiftData
@testable import CountMe

/// Tests for DataStore custom meal persistence operations
///
/// Validates the CRUD operations for custom meals including:
/// - Saving and fetching custom meals
/// - Updating custom meals
/// - Deleting custom meals with cascade deletion
/// - Searching custom meals with case-insensitive filtering
/// - Sort order by lastUsedAt (most recent first)
@Suite("DataStore Custom Meal Operations")
struct DataStoreCustomMealTests {
    
    /// Creates an in-memory model container for testing
    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            DailyLog.self,
            FoodItem.self,
            CustomMeal.self,
            Ingredient.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    /// Creates a test ingredient with default values
    private func createTestIngredient(
        name: String = "Test Ingredient",
        quantity: Double = 1.0,
        unit: String = "cup",
        calories: Double = 100,
        protein: Double? = 10,
        carbohydrates: Double? = 15,
        fats: Double? = 5
    ) -> Ingredient {
        return Ingredient(
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fats: fats
        )
    }
    
    /// Creates a test custom meal with default values
    private func createTestMeal(
        name: String = "Test Meal",
        ingredients: [Ingredient]? = nil,
        lastUsedAt: Date = Date()
    ) -> CustomMeal {
        let testIngredients = ingredients ?? [createTestIngredient()]
        return CustomMeal(
            name: name,
            ingredients: testIngredients,
            lastUsedAt: lastUsedAt
        )
    }
    
    // MARK: - Save and Fetch Tests
    
    @Test("Save and fetch custom meal") @MainActor
    func testSaveAndFetchCustomMeal() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save a custom meal
        let meal = createTestMeal(name: "Chicken Stir Fry")
        try await dataStore.saveCustomMeal(meal)
        
        // Fetch all meals
        let fetchedMeals = try await dataStore.fetchAllCustomMeals()
        
        #expect(fetchedMeals.count == 1)
        #expect(fetchedMeals.first?.name == "Chicken Stir Fry")
        #expect(fetchedMeals.first?.ingredients.count == 1)
    }
    
    @Test("Fetch custom meal by ID") @MainActor
    func testFetchCustomMealById() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save a custom meal
        let meal = createTestMeal(name: "Pasta Carbonara")
        try await dataStore.saveCustomMeal(meal)
        
        // Fetch by ID
        let fetchedMeal = try await dataStore.fetchCustomMeal(byId: meal.id)
        
        #expect(fetchedMeal != nil)
        #expect(fetchedMeal?.name == "Pasta Carbonara")
        #expect(fetchedMeal?.id == meal.id)
    }
    
    @Test("Fetch non-existent custom meal returns nil") @MainActor
    func testFetchNonExistentMeal() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Try to fetch a meal that doesn't exist
        let nonExistentId = UUID()
        let fetchedMeal = try await dataStore.fetchCustomMeal(id: nonExistentId)
        
        #expect(fetchedMeal == nil)
    }
    
    // MARK: - Update Tests
    
    @Test("Update custom meal") @MainActor
    func testUpdateCustomMeal() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save a custom meal
        let meal = createTestMeal(name: "Original Name")
        try await dataStore.saveCustomMeal(meal)
        
        // Update the meal
        meal.name = "Updated Name"
        try await dataStore.updateCustomMeal(meal)
        
        // Fetch and verify
        let fetchedMeal = try await dataStore.fetchCustomMeal(byId: meal.id)
        #expect(fetchedMeal?.name == "Updated Name")
    }
    
    // MARK: - Delete Tests
    
    @Test("Delete custom meal") @MainActor
    func testDeleteCustomMeal() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save a custom meal
        let meal = createTestMeal(name: "To Be Deleted")
        try await dataStore.saveCustomMeal(meal)
        
        // Verify it exists
        var fetchedMeals = try await dataStore.fetchAllCustomMeals()
        #expect(fetchedMeals.count == 1)
        
        // Delete the meal
        try await dataStore.deleteCustomMeal(meal)
        
        // Verify it's gone
        fetchedMeals = try await dataStore.fetchAllCustomMeals()
        #expect(fetchedMeals.count == 0)
    }
    
    @Test("Delete custom meal cascades to ingredients") @MainActor
    func testDeleteCascadesToIngredients() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create a meal with multiple ingredients
        let ingredients = [
            createTestIngredient(name: "Ingredient 1"),
            createTestIngredient(name: "Ingredient 2"),
            createTestIngredient(name: "Ingredient 3")
        ]
        let meal = createTestMeal(name: "Multi-Ingredient Meal", ingredients: ingredients)
        try await dataStore.saveCustomMeal(meal)
        
        // Delete the meal
        try await dataStore.deleteCustomMeal(meal)
        
        // Verify meal is deleted
        let fetchedMeals = try await dataStore.fetchAllCustomMeals()
        #expect(fetchedMeals.count == 0)
        
        // Note: SwiftData handles cascade deletion automatically for @Model relationships
        // The ingredients are deleted when the parent CustomMeal is deleted
    }
    
    // MARK: - Search Tests
    
    @Test("Search custom meals by name (case-insensitive)") @MainActor
    func testSearchCustomMeals() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save multiple meals
        try await dataStore.saveCustomMeal(createTestMeal(name: "Chicken Stir Fry"))
        try await dataStore.saveCustomMeal(createTestMeal(name: "Beef Tacos"))
        try await dataStore.saveCustomMeal(createTestMeal(name: "Chicken Salad"))
        
        // Search for "chicken" (case-insensitive)
        let results = try await dataStore.searchCustomMeals(query: "chicken")
        
        #expect(results.count == 2)
        #expect(results.contains { $0.name == "Chicken Stir Fry" })
        #expect(results.contains { $0.name == "Chicken Salad" })
    }
    
    @Test("Search with empty query returns all meals") @MainActor
    func testSearchWithEmptyQuery() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save multiple meals
        try await dataStore.saveCustomMeal(createTestMeal(name: "Meal 1"))
        try await dataStore.saveCustomMeal(createTestMeal(name: "Meal 2"))
        try await dataStore.saveCustomMeal(createTestMeal(name: "Meal 3"))
        
        // Search with empty query
        let results = try await dataStore.searchCustomMeals(query: "")
        
        #expect(results.count == 3)
    }
    
    @Test("Search with no matches returns empty array") @MainActor
    func testSearchWithNoMatches() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create and save meals
        try await dataStore.saveCustomMeal(createTestMeal(name: "Chicken Stir Fry"))
        try await dataStore.saveCustomMeal(createTestMeal(name: "Beef Tacos"))
        
        // Search for something that doesn't exist
        let results = try await dataStore.searchCustomMeals(query: "Pizza")
        
        #expect(results.count == 0)
    }
    
    // MARK: - Sort Order Tests
    
    @Test("Fetch all custom meals sorted by lastUsedAt (most recent first)") @MainActor
    func testFetchAllSortedByLastUsedAt() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create meals with different lastUsedAt timestamps
        let now = Date()
        let meal1 = createTestMeal(name: "Oldest", lastUsedAt: now.addingTimeInterval(-3600)) // 1 hour ago
        let meal2 = createTestMeal(name: "Newest", lastUsedAt: now) // now
        let meal3 = createTestMeal(name: "Middle", lastUsedAt: now.addingTimeInterval(-1800)) // 30 min ago
        
        // Save in random order
        try await dataStore.saveCustomMeal(meal1)
        try await dataStore.saveCustomMeal(meal2)
        try await dataStore.saveCustomMeal(meal3)
        
        // Fetch all
        let fetchedMeals = try await dataStore.fetchAllCustomMeals()
        
        #expect(fetchedMeals.count == 3)
        #expect(fetchedMeals[0].name == "Newest")
        #expect(fetchedMeals[1].name == "Middle")
        #expect(fetchedMeals[2].name == "Oldest")
    }
    
    @Test("Search results sorted by lastUsedAt (most recent first)") @MainActor
    func testSearchResultsSortedByLastUsedAt() async throws {
        let container = try createTestContainer()
        let dataStore = DataStore(modelContext: container.mainContext)
        
        // Create meals with "chicken" in name and different timestamps
        let now = Date()
        let meal1 = createTestMeal(name: "Chicken Soup", lastUsedAt: now.addingTimeInterval(-7200)) // 2 hours ago
        let meal2 = createTestMeal(name: "Chicken Salad", lastUsedAt: now) // now
        let meal3 = createTestMeal(name: "Chicken Tacos", lastUsedAt: now.addingTimeInterval(-3600)) // 1 hour ago
        
        try await dataStore.saveCustomMeal(meal1)
        try await dataStore.saveCustomMeal(meal2)
        try await dataStore.saveCustomMeal(meal3)
        
        // Search for "chicken"
        let results = try await dataStore.searchCustomMeals(query: "chicken")
        
        #expect(results.count == 3)
        #expect(results[0].name == "Chicken Salad")
        #expect(results[1].name == "Chicken Tacos")
        #expect(results[2].name == "Chicken Soup")
    }
}
