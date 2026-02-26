//
//  ServingSizeCalculatorTests.swift
//  CountMeTests
//
//  Created by Kiro on 1/23/26.
//

import Testing
import Foundation
@testable import CountMe

/// Tests for serving size calculation utilities
///
/// Validates that serving size multipliers correctly scale all nutritional values
/// and that invalid multipliers are properly rejected.
struct ServingSizeCalculatorTests {
    
    // MARK: - Valid Multiplier Tests
    
    @Test("Apply 0.5x multiplier scales all values by half")
    func testHalfServingMultiplier() throws {
        // Given: An ingredient with known nutritional values
        let ingredient = try! Ingredient(
            name: "chicken breast",
            quantity: 6,
            unit: "oz",
            calories: 187,
            protein: 35,
            carbohydrates: 0,
            fats: 4
        )
        
        // When: Applying 0.5x multiplier
        let result = try ServingSizeCalculator.applyServingMultiplier(0.5, to: ingredient)
        
        // Then: All values should be halved
        #expect(result.quantity == 3.0)
        #expect(result.calories == 93.5)
        #expect(result.protein == 17.5)
        #expect(result.carbohydrates == 0.0)
        #expect(result.fats == 2.0)
        
        // And: Name and unit should be preserved
        #expect(result.name == "chicken breast")
        #expect(result.unit == "oz")
    }
    
    @Test("Apply 2.0x multiplier scales all values by double")
    func testDoubleServingMultiplier() throws {
        // Given: An ingredient with known nutritional values
        let ingredient = try! Ingredient(
            name: "white rice",
            quantity: 1,
            unit: "cup",
            calories: 206,
            protein: 4,
            carbohydrates: 45,
            fats: 0.4
        )
        
        // When: Applying 2.0x multiplier
        let result = try ServingSizeCalculator.applyServingMultiplier(2.0, to: ingredient)
        
        // Then: All values should be doubled
        #expect(result.quantity == 2.0)
        #expect(result.calories == 412.0)
        #expect(result.protein == 8.0)
        #expect(result.carbohydrates == 90.0)
        #expect(result.fats == 0.8)
    }
    
    @Test("Apply 1.0x multiplier preserves all values")
    func testIdentityMultiplier() throws {
        // Given: An ingredient
        let ingredient = try! Ingredient(
            name: "broccoli",
            quantity: 1,
            unit: "cup",
            calories: 31,
            protein: 2.5,
            carbohydrates: 6,
            fats: 0.3
        )
        
        // When: Applying 1.0x multiplier
        let result = try ServingSizeCalculator.applyServingMultiplier(1.0, to: ingredient)
        
        // Then: All values should remain the same
        #expect(result.quantity == ingredient.quantity)
        #expect(result.calories == ingredient.calories)
        #expect(result.protein == ingredient.protein)
        #expect(result.carbohydrates == ingredient.carbohydrates)
        #expect(result.fats == ingredient.fats)
    }
    
    @Test("Apply multiplier to ingredient with nil macros")
    func testMultiplierWithNilMacros() throws {
        // Given: An ingredient with nil macro values
        let ingredient = try! Ingredient(
            name: "unknown food",
            quantity: 100,
            unit: "gram",
            calories: 150,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // When: Applying 2.0x multiplier
        let result = try ServingSizeCalculator.applyServingMultiplier(2.0, to: ingredient)
        
        // Then: Calories and quantity should be scaled, macros remain nil
        #expect(result.quantity == 200.0)
        #expect(result.calories == 300.0)
        #expect(result.protein == nil)
        #expect(result.carbohydrates == nil)
        #expect(result.fats == nil)
    }
    
    @Test("Apply multiplier preserves original ingredient immutability")
    func testImmutability() throws {
        // Given: An ingredient
        let original = try! Ingredient(
            name: "test food",
            quantity: 10,
            unit: "oz",
            calories: 100,
            protein: 20,
            carbohydrates: 30,
            fats: 5
        )
        
        let originalQuantity = original.quantity
        let originalCalories = original.calories
        let originalProtein = original.protein
        
        // When: Applying a multiplier
        _ = try ServingSizeCalculator.applyServingMultiplier(3.0, to: original)
        
        // Then: Original ingredient should be unchanged
        #expect(original.quantity == originalQuantity)
        #expect(original.calories == originalCalories)
        #expect(original.protein == originalProtein)
    }
    
    // MARK: - Invalid Multiplier Tests
    
    @Test("Zero multiplier throws error")
    func testZeroMultiplierThrows() {
        // Given: An ingredient
        let ingredient = try! Ingredient(
            name: "test food",
            quantity: 10,
            unit: "oz",
            calories: 100
        )
        
        // When/Then: Applying zero multiplier should throw
        #expect(throws: ServingSizeError.self) {
            try ServingSizeCalculator.applyServingMultiplier(0.0, to: ingredient)
        }
    }
    
    @Test("Negative multiplier throws error")
    func testNegativeMultiplierThrows() {
        // Given: An ingredient
        let ingredient = try! Ingredient(
            name: "test food",
            quantity: 10,
            unit: "oz",
            calories: 100
        )
        
        // When/Then: Applying negative multiplier should throw
        #expect(throws: ServingSizeError.self) {
            try ServingSizeCalculator.applyServingMultiplier(-1.5, to: ingredient)
        }
    }
    
    @Test("Error message contains multiplier value")
    func testErrorMessageContent() {
        // Given: An ingredient
        let ingredient = try! Ingredient(
            name: "test food",
            quantity: 10,
            unit: "oz",
            calories: 100
        )
        
        // When: Attempting to apply invalid multiplier
        do {
            _ = try ServingSizeCalculator.applyServingMultiplier(-2.5, to: ingredient)
            Issue.record("Expected error to be thrown")
        } catch let error as ServingSizeError {
            // Then: Error message should contain the invalid value
            if case .invalidMultiplier(let value) = error {
                #expect(value == -2.5)
                #expect(error.errorDescription?.contains("-2.5") == true)
            } else {
                Issue.record("Wrong error case")
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }
}
