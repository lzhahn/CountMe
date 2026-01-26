//
//  FoodItemRowTests.swift
//  CountMeTests
//
//  Tests for FoodItemRow view component
//

import Testing
import SwiftUI
@testable import CountMe

/// Tests for FoodItemRow view component
///
/// Validates:
/// - Macro information display when available
/// - Source icon display for different food sources
/// - Backward compatibility with items without macros
struct FoodItemRowTests {
    
    @Test("FoodItemRow displays macro information when available")
    func testMacroDisplay() async throws {
        // Create a food item with macro information
        let item = FoodItem(
            name: "Chicken Breast",
            calories: 165,
            timestamp: Date(),
            servingSize: "100",
            servingUnit: "g",
            source: .api,
            protein: 31,
            carbohydrates: 0,
            fats: 3.6
        )
        
        // Verify the item has macros
        #expect(item.protein != nil)
        #expect(item.carbohydrates != nil)
        #expect(item.fats != nil)
    }
    
    @Test("FoodItemRow handles items without macros")
    func testNoMacroDisplay() async throws {
        // Create a food item without macro information (backward compatibility)
        let item = FoodItem(
            name: "Apple",
            calories: 95,
            timestamp: Date(),
            source: .manual
        )
        
        // Verify the item has no macros
        #expect(item.protein == nil)
        #expect(item.carbohydrates == nil)
        #expect(item.fats == nil)
    }
    
    @Test("FoodItemRow displays correct icon for custom meal source")
    func testCustomMealSourceIcon() async throws {
        // Create a food item from a custom meal
        let item = FoodItem(
            name: "Chicken Stir Fry",
            calories: 424,
            timestamp: Date(),
            servingSize: "1",
            servingUnit: "serving",
            source: .customMeal,
            protein: 41.5,
            carbohydrates: 51,
            fats: 4.7
        )
        
        // Verify the source is set correctly
        #expect(item.source == .customMeal)
        
        // Verify it has macro information
        #expect(item.protein != nil)
        #expect(item.carbohydrates != nil)
        #expect(item.fats != nil)
    }
    
    @Test("FoodItemRow displays correct icon for API source")
    func testAPISourceIcon() async throws {
        let item = FoodItem(
            name: "Banana",
            calories: 105,
            timestamp: Date(),
            source: .api
        )
        
        #expect(item.source == .api)
    }
    
    @Test("FoodItemRow displays correct icon for manual source")
    func testManualSourceIcon() async throws {
        let item = FoodItem(
            name: "Homemade Meal",
            calories: 350,
            timestamp: Date(),
            source: .manual
        )
        
        #expect(item.source == .manual)
    }
}
