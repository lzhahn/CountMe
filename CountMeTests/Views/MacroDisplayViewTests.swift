//
//  MacroDisplayViewTests.swift
//  CountMeTests
//
//  Created by Kiro on 1/21/26.
//

import Testing
import SwiftUI
@testable import CountMe

/// Test suite for MacroDisplayView component
///
/// Tests cover:
/// - Nil value handling (treating nil as zero)
/// - Goal percentage calculations
/// - Visual display with various macro combinations
/// - Edge cases (zero values, over goal, no macros)
struct MacroDisplayViewTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test("MacroDisplayView handles nil protein as zero")
    func testNilProteinHandledAsZero() {
        let view = MacroDisplayView(
            protein: nil,
            carbohydrates: 100.0,
            fats: 50.0
        )
        
        // Verify nil is treated as zero in calculations
        #expect(view.proteinValue == 0.0)
        #expect(view.totalMacros == 150.0) // 0 + 100 + 50
    }
    
    @Test("MacroDisplayView handles nil carbohydrates as zero")
    func testNilCarbsHandledAsZero() {
        let view = MacroDisplayView(
            protein: 50.0,
            carbohydrates: nil,
            fats: 30.0
        )
        
        // Verify nil is treated as zero in calculations
        #expect(view.carbsValue == 0.0)
        #expect(view.totalMacros == 80.0) // 50 + 0 + 30
    }
    
    @Test("MacroDisplayView handles nil fats as zero")
    func testNilFatsHandledAsZero() {
        let view = MacroDisplayView(
            protein: 40.0,
            carbohydrates: 120.0,
            fats: nil
        )
        
        // Verify nil is treated as zero in calculations
        #expect(view.fatsValue == 0.0)
        #expect(view.totalMacros == 160.0) // 40 + 120 + 0
    }
    
    @Test("MacroDisplayView handles all nil values")
    func testAllNilValuesHandledAsZero() {
        let view = MacroDisplayView(
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // Verify all nil values treated as zero
        #expect(view.proteinValue == 0.0)
        #expect(view.carbsValue == 0.0)
        #expect(view.fatsValue == 0.0)
        #expect(view.totalMacros == 0.0)
    }
    
    @Test("MacroDisplayView calculates total macros correctly")
    func testTotalMacrosCalculation() {
        let view = MacroDisplayView(
            protein: 45.0,
            carbohydrates: 120.0,
            fats: 30.0
        )
        
        #expect(view.totalMacros == 195.0) // 45 + 120 + 30
    }
    
    // MARK: - Goal Tracking Tests
    
    @Test("MacroDisplayView detects when goals are set")
    func testHasGoalsDetection() {
        let viewWithGoals = MacroDisplayView(
            protein: 45.0,
            carbohydrates: 120.0,
            fats: 30.0,
            proteinGoal: 150.0,
            carbsGoal: 200.0,
            fatsGoal: 65.0
        )
        
        #expect(viewWithGoals.hasGoals == true)
        
        let viewWithoutGoals = MacroDisplayView(
            protein: 45.0,
            carbohydrates: 120.0,
            fats: 30.0
        )
        
        #expect(viewWithoutGoals.hasGoals == false)
    }
    
    @Test("MacroDisplayView detects partial goals")
    func testPartialGoalsDetection() {
        let viewWithPartialGoals = MacroDisplayView(
            protein: 45.0,
            carbohydrates: 120.0,
            fats: 30.0,
            proteinGoal: 150.0,
            carbsGoal: nil,
            fatsGoal: nil
        )
        
        #expect(viewWithPartialGoals.hasGoals == true)
    }
    
    // MARK: - Edge Cases
    
    @Test("MacroDisplayView handles zero values")
    func testZeroValues() {
        let view = MacroDisplayView(
            protein: 0.0,
            carbohydrates: 0.0,
            fats: 0.0
        )
        
        #expect(view.proteinValue == 0.0)
        #expect(view.carbsValue == 0.0)
        #expect(view.fatsValue == 0.0)
        #expect(view.totalMacros == 0.0)
    }
    
    @Test("MacroDisplayView handles very large values")
    func testVeryLargeValues() {
        let view = MacroDisplayView(
            protein: 500.0,
            carbohydrates: 1000.0,
            fats: 300.0
        )
        
        #expect(view.totalMacros == 1800.0)
    }
    
    @Test("MacroDisplayView handles decimal values")
    func testDecimalValues() {
        let view = MacroDisplayView(
            protein: 45.5,
            carbohydrates: 120.3,
            fats: 30.7
        )
        
        #expect(view.totalMacros == 196.5)
    }
    
    @Test("MacroDisplayView handles mixed nil and zero values")
    func testMixedNilAndZeroValues() {
        let view = MacroDisplayView(
            protein: 0.0,
            carbohydrates: nil,
            fats: 30.0
        )
        
        #expect(view.proteinValue == 0.0)
        #expect(view.carbsValue == 0.0)
        #expect(view.totalMacros == 30.0)
    }
    
    // MARK: - Goal Percentage Calculation Tests
    
    @Test("Goal percentage calculation for protein")
    func testProteinGoalPercentage() {
        let view = MacroDisplayView(
            protein: 75.0,
            carbohydrates: 100.0,
            fats: 50.0,
            proteinGoal: 150.0
        )
        
        // 75 / 150 = 0.5 = 50%
        let percentage = (view.proteinValue / (view.proteinGoal ?? 1)) * 100
        #expect(percentage == 50.0)
    }
    
    @Test("Goal percentage calculation for carbs")
    func testCarbsGoalPercentage() {
        let view = MacroDisplayView(
            protein: 50.0,
            carbohydrates: 150.0,
            fats: 40.0,
            carbsGoal: 200.0
        )
        
        // 150 / 200 = 0.75 = 75%
        let percentage = (view.carbsValue / (view.carbsGoal ?? 1)) * 100
        #expect(percentage == 75.0)
    }
    
    @Test("Goal percentage calculation for fats")
    func testFatsGoalPercentage() {
        let view = MacroDisplayView(
            protein: 50.0,
            carbohydrates: 100.0,
            fats: 32.5,
            fatsGoal: 65.0
        )
        
        // 32.5 / 65 = 0.5 = 50%
        let percentage = (view.fatsValue / (view.fatsGoal ?? 1)) * 100
        #expect(percentage == 50.0)
    }
    
    @Test("Goal percentage over 100%")
    func testGoalPercentageOver100() {
        let view = MacroDisplayView(
            protein: 180.0,
            carbohydrates: 250.0,
            fats: 70.0,
            proteinGoal: 150.0,
            carbsGoal: 200.0,
            fatsGoal: 65.0
        )
        
        // Protein: 180 / 150 = 1.2 = 120%
        let proteinPercentage = (view.proteinValue / (view.proteinGoal ?? 1)) * 100
        #expect(proteinPercentage == 120.0)
        
        // Carbs: 250 / 200 = 1.25 = 125%
        let carbsPercentage = (view.carbsValue / (view.carbsGoal ?? 1)) * 100
        #expect(carbsPercentage == 125.0)
        
        // Fats: 70 / 65 ≈ 1.077 = 107.7%
        let fatsPercentage = (view.fatsValue / (view.fatsGoal ?? 1)) * 100
        #expect(abs(fatsPercentage - 107.69) < 0.1)
    }
    
    @Test("Goal percentage with zero goal")
    func testGoalPercentageWithZeroGoal() {
        let view = MacroDisplayView(
            protein: 50.0,
            carbohydrates: 100.0,
            fats: 30.0,
            proteinGoal: 0.0
        )
        
        // Should handle zero goal gracefully (avoid division by zero in UI)
        #expect(view.proteinGoal == 0.0)
    }
    
    // MARK: - Backward Compatibility Tests
    
    @Test("MacroDisplayView works with legacy data (all nil macros)")
    func testBackwardCompatibilityWithLegacyData() {
        // Simulates FoodItems created before macro tracking was added
        let view = MacroDisplayView(
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // Should handle gracefully without errors
        #expect(view.proteinValue == 0.0)
        #expect(view.carbsValue == 0.0)
        #expect(view.fatsValue == 0.0)
        #expect(view.totalMacros == 0.0)
        #expect(view.hasGoals == false)
    }
    
    @Test("MacroDisplayView works with partial macro data")
    func testPartialMacroData() {
        // Some ingredients may have only some macro values
        let view = MacroDisplayView(
            protein: 45.0,
            carbohydrates: nil,
            fats: nil
        )
        
        #expect(view.proteinValue == 45.0)
        #expect(view.carbsValue == 0.0)
        #expect(view.fatsValue == 0.0)
        #expect(view.totalMacros == 45.0)
    }
    
    // MARK: - Integration with DailyLog Tests
    
    @Test("MacroDisplayView can display DailyLog macros")
    func testDisplayDailyLogMacros() throws {
        // Create a sample daily log with food items
        let foodItem1 = try FoodItem(
            name: "Chicken Breast",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fats: 3.6
        )
        
        let foodItem2 = try FoodItem(
            name: "Brown Rice",
            calories: 216,
            protein: 5,
            carbohydrates: 45,
            fats: 1.8
        )
        
        let dailyLog = try DailyLog(
            date: Date(),
            foodItems: [foodItem1, foodItem2]
        )
        
        // Create view with daily log totals
        let view = MacroDisplayView(
            protein: dailyLog.totalProtein,
            carbohydrates: dailyLog.totalCarbohydrates,
            fats: dailyLog.totalFats
        )
        
        #expect(view.proteinValue == 36.0) // 31 + 5
        #expect(view.carbsValue == 45.0) // 0 + 45
        #expect(view.fatsValue == 5.4) // 3.6 + 1.8
    }
    
    // MARK: - Integration with CustomMeal Tests
    
    @Test("MacroDisplayView can display CustomMeal macros")
    func testDisplayCustomMealMacros() {
        let meal = try! CustomMeal(
            name: "Chicken Stir Fry",
            ingredients: [
                try! Ingredient(
                    name: "Chicken Breast",
                    quantity: 6,
                    unit: "oz",
                    calories: 187,
                    protein: 35,
                    carbohydrates: 0,
                    fats: 4
                ),
                try! Ingredient(
                    name: "White Rice",
                    quantity: 1,
                    unit: "cup",
                    calories: 206,
                    protein: 4,
                    carbohydrates: 45,
                    fats: 0.4
                )
            ]
        )
        
        // Create view with custom meal totals
        let view = MacroDisplayView(
            protein: meal.totalProtein,
            carbohydrates: meal.totalCarbohydrates,
            fats: meal.totalFats
        )
        
        #expect(view.proteinValue == 39.0) // 35 + 4
        #expect(view.carbsValue == 45.0) // 0 + 45
        #expect(view.fatsValue == 4.4) // 4 + 0.4
    }
    
    @Test("MacroDisplayView can display CustomMeal macros with serving multiplier")
    func testDisplayCustomMealMacrosWithServingMultiplier() {
        let meal = try! CustomMeal(
            name: "Protein Shake",
            ingredients: [
                try! Ingredient(
                    name: "Protein Powder",
                    quantity: 1,
                    unit: "scoop",
                    calories: 120,
                    protein: 24,
                    carbohydrates: 3,
                    fats: 1.5
                )
            ]
        )
        
        let servingMultiplier = 2.0
        
        // Create view with adjusted values
        let view = MacroDisplayView(
            protein: meal.totalProtein * servingMultiplier,
            carbohydrates: meal.totalCarbohydrates * servingMultiplier,
            fats: meal.totalFats * servingMultiplier
        )
        
        #expect(view.proteinValue == 48.0) // 24 * 2
        #expect(view.carbsValue == 6.0) // 3 * 2
        #expect(view.fatsValue == 3.0) // 1.5 * 2
    }
}
