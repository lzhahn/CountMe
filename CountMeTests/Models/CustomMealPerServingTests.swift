//
//  CustomMealPerServingTests.swift
//  CountMeTests
//
//  Created by Kiro on 2/7/26.
//

import Testing
import Foundation
@testable import CountMe

/// Tests for CustomMeal per-serving nutrition calculations
///
/// Validates Requirements 2.1, 2.3, 8.1:
/// - Per-serving nutrition calculated correctly when servingsCount > 1
/// - Returns nil when servingsCount ≤ 1 (no redundant display)
/// - hasMultipleServings returns correct boolean
@Suite("CustomMeal Per-Serving Calculations")
struct CustomMealPerServingTests {
    
    // MARK: - Test Fixtures
    
    /// Creates a test custom meal with specified servings count
    func createTestMeal(servingsCount: Double) -> CustomMeal {
        let ingredients = [
            Ingredient(
                name: "Chicken Breast",
                quantity: 200,
                unit: "g",
                calories: 330,
                protein: 62,
                carbohydrates: 0,
                fats: 7.2
            ),
            Ingredient(
                name: "Rice",
                quantity: 150,
                unit: "g",
                calories: 195,
                protein: 4.5,
                carbohydrates: 43,
                fats: 0.3
            ),
            Ingredient(
                name: "Broccoli",
                quantity: 100,
                unit: "g",
                calories: 35,
                protein: 2.8,
                carbohydrates: 7,
                fats: 0.4
            )
        ]
        
        return CustomMeal(
            name: "Chicken and Rice Bowl",
            ingredients: ingredients,
            servingsCount: servingsCount
        )
    }
    
    // MARK: - Per-Serving Calculation Tests (servingsCount = 4)
    
    @Test("Per-serving calories calculated correctly with servingsCount = 4")
    func testPerServingCalories_WithFourServings_CalculatesCorrectly() async throws {
        let meal = createTestMeal(servingsCount: 4.0)
        
        // Total: 330 + 195 + 35 = 560 calories
        // Per serving: 560 / 4 = 140 calories
        let expectedPerServing = 140.0
        
        #expect(meal.perServingCalories == expectedPerServing)
    }
    
    @Test("Per-serving protein calculated correctly with servingsCount = 4")
    func testPerServingProtein_WithFourServings_CalculatesCorrectly() async throws {
        let meal = createTestMeal(servingsCount: 4.0)
        
        // Total: 62 + 4.5 + 2.8 = 69.3g protein
        // Per serving: 69.3 / 4 = 17.325g
        let expectedPerServing = 17.325
        
        #expect(meal.perServingProtein == expectedPerServing)
    }
    
    @Test("Per-serving carbohydrates calculated correctly with servingsCount = 4")
    func testPerServingCarbohydrates_WithFourServings_CalculatesCorrectly() async throws {
        let meal = createTestMeal(servingsCount: 4.0)
        
        // Total: 0 + 43 + 7 = 50g carbs
        // Per serving: 50 / 4 = 12.5g
        let expectedPerServing = 12.5
        
        #expect(meal.perServingCarbohydrates == expectedPerServing)
    }
    
    @Test("Per-serving fats calculated correctly with servingsCount = 4")
    func testPerServingFats_WithFourServings_CalculatesCorrectly() async throws {
        let meal = createTestMeal(servingsCount: 4.0)
        
        // Total: 7.2 + 0.3 + 0.4 = 7.9g fats
        // Per serving: 7.9 / 4 = 1.975g
        let expectedPerServing = 1.975
        
        #expect(meal.perServingFats == expectedPerServing)
    }
    
    // MARK: - Returns Nil When servingsCount = 1
    
    @Test("Per-serving calories returns nil when servingsCount = 1")
    func testPerServingCalories_WithOneServing_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 1.0)
        
        #expect(meal.perServingCalories == nil)
    }
    
    @Test("Per-serving protein returns nil when servingsCount = 1")
    func testPerServingProtein_WithOneServing_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 1.0)
        
        #expect(meal.perServingProtein == nil)
    }
    
    @Test("Per-serving carbohydrates returns nil when servingsCount = 1")
    func testPerServingCarbohydrates_WithOneServing_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 1.0)
        
        #expect(meal.perServingCarbohydrates == nil)
    }
    
    @Test("Per-serving fats returns nil when servingsCount = 1")
    func testPerServingFats_WithOneServing_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 1.0)
        
        #expect(meal.perServingFats == nil)
    }
    
    // MARK: - Edge Case: servingsCount = 0
    
    @Test("Per-serving calories returns nil when servingsCount = 0")
    func testPerServingCalories_WithZeroServings_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 0.0)
        
        #expect(meal.perServingCalories == nil)
    }
    
    @Test("Per-serving protein returns nil when servingsCount = 0")
    func testPerServingProtein_WithZeroServings_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 0.0)
        
        #expect(meal.perServingProtein == nil)
    }
    
    @Test("Per-serving carbohydrates returns nil when servingsCount = 0")
    func testPerServingCarbohydrates_WithZeroServings_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 0.0)
        
        #expect(meal.perServingCarbohydrates == nil)
    }
    
    @Test("Per-serving fats returns nil when servingsCount = 0")
    func testPerServingFats_WithZeroServings_ReturnsNil() async throws {
        let meal = createTestMeal(servingsCount: 0.0)
        
        #expect(meal.perServingFats == nil)
    }
    
    // MARK: - hasMultipleServings Tests
    
    @Test("hasMultipleServings returns true when servingsCount > 1")
    func testHasMultipleServings_WithFourServings_ReturnsTrue() async throws {
        let meal = createTestMeal(servingsCount: 4.0)
        
        #expect(meal.hasMultipleServings == true)
    }
    
    @Test("hasMultipleServings returns false when servingsCount = 1")
    func testHasMultipleServings_WithOneServing_ReturnsFalse() async throws {
        let meal = createTestMeal(servingsCount: 1.0)
        
        #expect(meal.hasMultipleServings == false)
    }
    
    @Test("hasMultipleServings returns false when servingsCount = 0")
    func testHasMultipleServings_WithZeroServings_ReturnsFalse() async throws {
        let meal = createTestMeal(servingsCount: 0.0)
        
        #expect(meal.hasMultipleServings == false)
    }
    
    @Test("hasMultipleServings returns true with fractional servings > 1")
    func testHasMultipleServings_WithFractionalServings_ReturnsTrue() async throws {
        let meal = createTestMeal(servingsCount: 2.5)
        
        #expect(meal.hasMultipleServings == true)
    }
}
