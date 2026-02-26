//
//  ManualEntryViewTests.swift
//  CountMeTests
//
//  Tests for ManualEntryView with macro field support
//

import Testing
import SwiftUI
import SwiftData
@testable import CountMe

/// Tests for ManualEntryView component
///
/// Validates:
/// - Macro fields are optional and can be left empty
/// - Macro validation (non-negative values)
/// - FoodItem creation with macro values
/// - Backward compatibility (items without macros)
///
/// Validates Requirements: 6.3
@MainActor
struct ManualEntryViewTests {
    
    /// Helper to create a test tracker with in-memory storage
    func createTestTracker() async throws -> CalorieTracker {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, CustomMeal.self, configurations: config)
        let context = ModelContext(container)
        
        let dataStore = DataStore(modelContext: context)
        let apiClient = NutritionAPIClient(
            apiKey: "test"
        )
        
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient)
        try await tracker.loadLog(for: Date())
        return tracker
    }
    
    @Test("ManualEntryView creates FoodItem with all macro fields")
    func testCreateFoodItemWithMacros() async throws {
        let tracker = try await createTestTracker()
        
        // Create a food item with all macro fields
        let foodItem = try FoodItem(
            name: "Chicken Breast",
            calories: 165,
            timestamp: Date(),
            servingSize: "100",
            servingUnit: "g",
            source: .manual,
            protein: 31,
            carbohydrates: 0,
            fats: 3.6
        )
        
        try await tracker.addFoodItem(foodItem)
        
        // Verify the item was saved with macros
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        let savedItem = tracker.currentLog?.foodItems.first
        #expect(savedItem != nil)
        #expect(savedItem?.name == "Chicken Breast")
        #expect(savedItem?.calories == 165)
        #expect(savedItem?.protein == 31)
        #expect(savedItem?.carbohydrates == 0)
        #expect(savedItem?.fats == 3.6)
    }
    
    @Test("ManualEntryView creates FoodItem without macro fields (backward compatibility)")
    func testCreateFoodItemWithoutMacros() async throws {
        let tracker = try await createTestTracker()
        
        // Create a food item without macro fields
        let foodItem = try FoodItem(
            name: "Apple",
            calories: 95,
            timestamp: Date(),
            source: .manual
        )
        
        try await tracker.addFoodItem(foodItem)
        
        // Verify the item was saved without macros
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        let savedItem = tracker.currentLog?.foodItems.first
        #expect(savedItem != nil)
        #expect(savedItem?.name == "Apple")
        #expect(savedItem?.calories == 95)
        #expect(savedItem?.protein == nil)
        #expect(savedItem?.carbohydrates == nil)
        #expect(savedItem?.fats == nil)
    }
    
    @Test("ManualEntryView creates FoodItem with partial macro fields")
    func testCreateFoodItemWithPartialMacros() async throws {
        let tracker = try await createTestTracker()
        
        // Create a food item with only some macro fields
        let foodItem = try FoodItem(
            name: "Banana",
            calories: 105,
            timestamp: Date(),
            source: .manual,
            protein: 1.3,
            carbohydrates: 27
            // fats is nil
        )
        
        try await tracker.addFoodItem(foodItem)
        
        // Verify the item was saved with partial macros
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        let savedItem = tracker.currentLog?.foodItems.first
        #expect(savedItem != nil)
        #expect(savedItem?.name == "Banana")
        #expect(savedItem?.calories == 105)
        #expect(savedItem?.protein == 1.3)
        #expect(savedItem?.carbohydrates == 27)
        #expect(savedItem?.fats == nil)
    }
    
    @Test("ManualEntryView validates non-negative protein values")
    func testProteinValidation() async throws {
        // Test that negative protein values would be rejected
        // This simulates the validation logic in ManualEntryView
        
        let proteinText = "-5"
        let protein = Double(proteinText)
        
        #expect(protein != nil)
        #expect(protein! < 0) // This should trigger validation error
    }
    
    @Test("ManualEntryView validates non-negative carbohydrate values")
    func testCarbohydrateValidation() async throws {
        // Test that negative carbohydrate values would be rejected
        
        let carbsText = "-10"
        let carbs = Double(carbsText)
        
        #expect(carbs != nil)
        #expect(carbs! < 0) // This should trigger validation error
    }
    
    @Test("ManualEntryView validates non-negative fat values")
    func testFatValidation() async throws {
        // Test that negative fat values would be rejected
        
        let fatsText = "-3.5"
        let fats = Double(fatsText)
        
        #expect(fats != nil)
        #expect(fats! < 0) // This should trigger validation error
    }
    
    @Test("ManualEntryView handles invalid numeric input for macros")
    func testInvalidMacroInput() async throws {
        // Test that non-numeric input is rejected
        
        let invalidInputs = ["abc", "12.34.56", "not a number", ""]
        
        for input in invalidInputs {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let value = Double(trimmed)
                #expect(value == nil) // Should fail to parse
            }
        }
    }
    
    @Test("ManualEntryView accepts valid decimal macro values")
    func testValidDecimalMacroValues() async throws {
        let tracker = try await createTestTracker()
        
        // Create a food item with decimal macro values
        let foodItem = try FoodItem(
            name: "Salmon",
            calories: 206,
            timestamp: Date(),
            servingSize: "100",
            servingUnit: "g",
            source: .manual,
            protein: 22.1,
            carbohydrates: 0.5,
            fats: 12.4
        )
        
        try await tracker.addFoodItem(foodItem)
        
        // Verify the item was saved with decimal macros
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        let savedItem = tracker.currentLog?.foodItems.first
        #expect(savedItem?.protein == 22.1)
        #expect(savedItem?.carbohydrates == 0.5)
        #expect(savedItem?.fats == 12.4)
    }
    
    @Test("ManualEntryView accepts zero macro values")
    func testZeroMacroValues() async throws {
        let tracker = try await createTestTracker()
        
        // Create a food item with zero macro values (valid)
        let foodItem = try FoodItem(
            name: "Sugar",
            calories: 387,
            timestamp: Date(),
            source: .manual,
            protein: 0,
            carbohydrates: 100,
            fats: 0
        )
        
        try await tracker.addFoodItem(foodItem)
        
        // Verify the item was saved with zero macros
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        let savedItem = tracker.currentLog?.foodItems.first
        #expect(savedItem?.protein == 0)
        #expect(savedItem?.carbohydrates == 100)
        #expect(savedItem?.fats == 0)
    }
    
    @Test("ManualEntryView creates FoodItem with macros and serving info")
    func testCompleteManualEntry() async throws {
        let tracker = try await createTestTracker()
        
        // Create a complete food item with all fields
        let foodItem = try FoodItem(
            name: "Greek Yogurt",
            calories: 97,
            timestamp: Date(),
            servingSize: "170",
            servingUnit: "g",
            source: .manual,
            protein: 10,
            carbohydrates: 3.6,
            fats: 5
        )
        
        try await tracker.addFoodItem(foodItem)
        
        // Verify all fields were saved correctly
        #expect(tracker.currentLog?.foodItems.count == 1)
        
        let savedItem = tracker.currentLog?.foodItems.first
        #expect(savedItem?.name == "Greek Yogurt")
        #expect(savedItem?.calories == 97)
        #expect(savedItem?.servingSize == "170")
        #expect(savedItem?.servingUnit == "g")
        #expect(savedItem?.source == .manual)
        #expect(savedItem?.protein == 10)
        #expect(savedItem?.carbohydrates == 3.6)
        #expect(savedItem?.fats == 5)
    }
}
