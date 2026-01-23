//
//  FoodItemMacroTests.swift
//  CountMeTests
//
//  Tests for FoodItem macro tracking extension
//

import Testing
import Foundation
@testable import CountMe

/// Tests for FoodItem macro tracking functionality
///
/// Validates:
/// - Backward compatibility with existing FoodItems
/// - Optional macro field handling
/// - New customMeal source type
struct FoodItemMacroTests {
    
    // MARK: - Backward Compatibility Tests
    
    @Test("FoodItem without macros should work (backward compatibility)")
    func testFoodItemWithoutMacros() async throws {
        // Create a FoodItem without macro parameters (legacy behavior)
        let item = FoodItem(
            name: "Apple",
            calories: 95.0,
            source: .manual
        )
        
        // Verify basic properties work
        #expect(item.name == "Apple")
        #expect(item.calories == 95.0)
        #expect(item.source == .manual)
        
        // Verify macro fields default to nil
        #expect(item.protein == nil)
        #expect(item.carbohydrates == nil)
        #expect(item.fats == nil)
    }
    
    @Test("FoodItem with macros should store values correctly")
    func testFoodItemWithMacros() async throws {
        // Create a FoodItem with macro parameters
        let item = FoodItem(
            name: "Chicken Breast",
            calories: 165.0,
            source: .api,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        // Verify all properties work
        #expect(item.name == "Chicken Breast")
        #expect(item.calories == 165.0)
        #expect(item.source == .api)
        
        // Verify macro fields are stored correctly
        #expect(item.protein == 31.0)
        #expect(item.carbohydrates == 0.0)
        #expect(item.fats == 3.6)
    }
    
    @Test("FoodItem with partial macros should work")
    func testFoodItemWithPartialMacros() async throws {
        // Create a FoodItem with only some macro parameters
        let item = FoodItem(
            name: "Mixed Nuts",
            calories: 200.0,
            source: .manual,
            protein: 6.0,
            fats: 18.0
            // carbohydrates intentionally omitted
        )
        
        // Verify provided macros are stored
        #expect(item.protein == 6.0)
        #expect(item.fats == 18.0)
        
        // Verify omitted macro defaults to nil
        #expect(item.carbohydrates == nil)
    }
    
    // MARK: - Custom Meal Source Tests
    
    @Test("FoodItemSource should include customMeal case")
    func testCustomMealSource() async throws {
        // Create a FoodItem with customMeal source
        let item = FoodItem(
            name: "Homemade Stir Fry",
            calories: 450.0,
            source: .customMeal,
            protein: 35.0,
            carbohydrates: 45.0,
            fats: 12.0
        )
        
        // Verify source is set correctly
        #expect(item.source == .customMeal)
        
        // Verify all properties work with customMeal source
        #expect(item.name == "Homemade Stir Fry")
        #expect(item.calories == 450.0)
        #expect(item.protein == 35.0)
        #expect(item.carbohydrates == 45.0)
        #expect(item.fats == 12.0)
    }
    
    @Test("FoodItemSource should support all three cases")
    func testAllFoodItemSources() async throws {
        let apiItem = FoodItem(name: "API Food", calories: 100.0, source: .api)
        let manualItem = FoodItem(name: "Manual Food", calories: 200.0, source: .manual)
        let customMealItem = FoodItem(name: "Custom Meal", calories: 300.0, source: .customMeal)
        
        #expect(apiItem.source == .api)
        #expect(manualItem.source == .manual)
        #expect(customMealItem.source == .customMeal)
    }
}

// MARK: - DailyLog Macro Totals Tests

/// Tests for DailyLog macro tracking computed properties
///
/// Validates:
/// - Total protein calculation
/// - Total carbohydrates calculation
/// - Total fats calculation
/// - Nil macro value handling (treated as zero)
struct DailyLogMacroTests {
    
    @Test("DailyLog should calculate total protein correctly")
    func testTotalProtein() async throws {
        let item1 = FoodItem(
            name: "Chicken",
            calories: 165.0,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        let item2 = FoodItem(
            name: "Rice",
            calories: 206.0,
            protein: 4.3,
            carbohydrates: 45.0,
            fats: 0.4
        )
        
        let log = DailyLog(
            date: Date(),
            foodItems: [item1, item2]
        )
        
        // Total protein should be sum of all items
        #expect(log.totalProtein == 35.3)
    }
    
    @Test("DailyLog should calculate total carbohydrates correctly")
    func testTotalCarbohydrates() async throws {
        let item1 = FoodItem(
            name: "Chicken",
            calories: 165.0,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        let item2 = FoodItem(
            name: "Rice",
            calories: 206.0,
            protein: 4.3,
            carbohydrates: 45.0,
            fats: 0.4
        )
        
        let log = DailyLog(
            date: Date(),
            foodItems: [item1, item2]
        )
        
        // Total carbs should be sum of all items
        #expect(log.totalCarbohydrates == 45.0)
    }
    
    @Test("DailyLog should calculate total fats correctly")
    func testTotalFats() async throws {
        let item1 = FoodItem(
            name: "Chicken",
            calories: 165.0,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        let item2 = FoodItem(
            name: "Rice",
            calories: 206.0,
            protein: 4.3,
            carbohydrates: 45.0,
            fats: 0.4
        )
        
        let log = DailyLog(
            date: Date(),
            foodItems: [item1, item2]
        )
        
        // Total fats should be sum of all items
        #expect(log.totalFats == 4.0)
    }
    
    @Test("DailyLog should treat nil macro values as zero")
    func testNilMacroValuesAsZero() async throws {
        // Item with macros
        let item1 = FoodItem(
            name: "Chicken",
            calories: 165.0,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        // Item without macros (legacy)
        let item2 = FoodItem(
            name: "Apple",
            calories: 95.0,
            source: .manual
            // No macro values - all nil
        )
        
        let log = DailyLog(
            date: Date(),
            foodItems: [item1, item2]
        )
        
        // Totals should only include item1's values (item2's nils treated as 0)
        #expect(log.totalProtein == 31.0)
        #expect(log.totalCarbohydrates == 0.0)
        #expect(log.totalFats == 3.6)
    }
    
    @Test("DailyLog with no food items should have zero macro totals")
    func testEmptyLogMacroTotals() async throws {
        let log = DailyLog(
            date: Date(),
            foodItems: []
        )
        
        // All totals should be zero for empty log
        #expect(log.totalProtein == 0.0)
        #expect(log.totalCarbohydrates == 0.0)
        #expect(log.totalFats == 0.0)
    }
    
    @Test("DailyLog should handle mixed nil and non-nil macro values")
    func testMixedNilAndNonNilMacros() async throws {
        // Item with all macros
        let item1 = FoodItem(
            name: "Chicken",
            calories: 165.0,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        // Item with partial macros
        let item2 = FoodItem(
            name: "Nuts",
            calories: 200.0,
            protein: 6.0,
            fats: 18.0
            // carbohydrates is nil
        )
        
        // Item with no macros
        let item3 = FoodItem(
            name: "Apple",
            calories: 95.0,
            source: .manual
        )
        
        let log = DailyLog(
            date: Date(),
            foodItems: [item1, item2, item3]
        )
        
        // Totals should sum non-nil values, treating nil as 0
        #expect(log.totalProtein == 37.0)  // 31.0 + 6.0 + 0
        #expect(log.totalCarbohydrates == 0.0)  // 0.0 + 0 + 0
        #expect(log.totalFats == 21.6)  // 3.6 + 18.0 + 0
    }
}
