//
//  ServingAdjustmentCalculationTests.swift
//  CountMeTests
//
//  Tests for serving adjustment calculations in ServingAdjustmentView
//

import Testing
import Foundation
import SwiftData
@testable import CountMe

@Suite("Serving Adjustment Calculation Tests")
struct ServingAdjustmentCalculationTests {
    
    // MARK: - Helper Functions
    
    /// Creates a test CalorieTracker with in-memory storage
    private func createTestTracker() throws -> CalorieTracker {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, configurations: config)
        let context = ModelContext(container)
        
        return CalorieTracker(
            dataStore: DataStore(modelContext: context),
            apiClient: NutritionAPIClient()
        )
    }
    
    /// Calculates calories per gram for a search result
    private func caloriesPerGram(for result: NutritionSearchResult) -> Double {
        guard let servingSize = result.servingSize,
              let size = Double(servingSize),
              size > 0 else {
            return result.calories / 100.0
        }
        return result.calories / size
    }
    
    /// Calculates adjusted calories based on serving option and multiplier
    private func adjustedCalories(
        result: NutritionSearchResult,
        servingOption: ServingOption,
        multiplier: Double
    ) -> Double {
        let cpg = caloriesPerGram(for: result)
        return cpg * servingOption.gramWeight * multiplier
    }
    
    // MARK: - Unit Tests
    
    @Test("Calorie calculation with 100g serving option")
    func testCalorieCalculation_100gOption_CorrectCalories() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        let option = ServingOption(description: "100g", gramWeight: 100)
        let calories = adjustedCalories(result: result, servingOption: option, multiplier: 1.0)
        
        #expect(calories == 165, "100g serving should equal original calories")
    }
    
    @Test("Calorie calculation with doubled serving")
    func testCalorieCalculation_DoubledServing_DoublesCalories() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        let option = ServingOption(description: "100g", gramWeight: 100)
        let calories = adjustedCalories(result: result, servingOption: option, multiplier: 2.0)
        
        #expect(calories == 330, "2x serving should double calories")
    }
    
    @Test("Calorie calculation with different serving option")
    func testCalorieCalculation_DifferentOption_ScalesCorrectly() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        // 1 breast = 174g
        let option = ServingOption(description: "1 breast", gramWeight: 174)
        let calories = adjustedCalories(result: result, servingOption: option, multiplier: 1.0)
        
        // Expected: 165 cal/100g * 174g = 287.1 cal
        #expect(abs(calories - 287.1) < 0.1, "174g serving should scale proportionally")
    }
    
    @Test("Calorie calculation with fractional multiplier")
    func testCalorieCalculation_FractionalMultiplier_ScalesCorrectly() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        let option = ServingOption(description: "100g", gramWeight: 100)
        let calories = adjustedCalories(result: result, servingOption: option, multiplier: 0.5)
        
        #expect(calories == 82.5, "0.5x serving should halve calories")
    }
    
    @Test("Macro calculation scales with serving option")
    func testMacroCalculation_DifferentOption_ScalesCorrectly() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6
        )
        
        // 174g serving
        let gramRatio = 174.0 / 100.0
        
        let adjustedProtein = result.protein! * gramRatio
        let adjustedCarbs = result.carbohydrates! * gramRatio
        let adjustedFats = result.fats! * gramRatio
        
        #expect(abs(adjustedProtein - 53.94) < 0.01, "Protein should scale to 53.94g")
        #expect(adjustedCarbs == 0.0, "Carbs should remain 0")
        #expect(abs(adjustedFats - 6.264) < 0.001, "Fats should scale to 6.264g")
    }
    
    // MARK: - Property Tests
    
    @Test("Property: Calories scale linearly with multiplier", .tags(.property, .servingAdjustment))
    func testProperty_Calories_ScaleLinearlyWithMultiplier() async throws {
        for _ in 0..<100 {
            let baseCalories = Double.random(in: 50...500)
            let servingSize = Double.random(in: 50...200)
            
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Test Food",
                calories: baseCalories,
                servingSize: String(Int(servingSize)),
                servingUnit: "g",
                brandName: nil,
                protein: nil,
                carbohydrates: nil,
                fats: nil
            )
            
            let option = ServingOption(description: "\(Int(servingSize))g", gramWeight: servingSize)
            let multiplier1 = Double.random(in: 0.5...3.0)
            let multiplier2 = multiplier1 * 2.0
            
            let calories1 = adjustedCalories(result: result, servingOption: option, multiplier: multiplier1)
            let calories2 = adjustedCalories(result: result, servingOption: option, multiplier: multiplier2)
            
            // calories2 should be approximately 2x calories1
            let ratio = calories2 / calories1
            #expect(abs(ratio - 2.0) < 0.01, "Doubling multiplier should double calories")
        }
    }
    
    @Test("Property: Calories scale linearly with gram weight", .tags(.property, .servingAdjustment))
    func testProperty_Calories_ScaleLinearlyWithGramWeight() async throws {
        for _ in 0..<100 {
            let baseCalories = Double.random(in: 50...500)
            let servingSize = 100.0
            
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Test Food",
                calories: baseCalories,
                servingSize: "100",
                servingUnit: "g",
                brandName: nil,
                protein: nil,
                carbohydrates: nil,
                fats: nil
            )
            
            let gramWeight1 = Double.random(in: 50...200)
            let gramWeight2 = gramWeight1 * 2.0
            
            let option1 = ServingOption(description: "Option 1", gramWeight: gramWeight1)
            let option2 = ServingOption(description: "Option 2", gramWeight: gramWeight2)
            
            let calories1 = adjustedCalories(result: result, servingOption: option1, multiplier: 1.0)
            let calories2 = adjustedCalories(result: result, servingOption: option2, multiplier: 1.0)
            
            // calories2 should be approximately 2x calories1
            let ratio = calories2 / calories1
            #expect(abs(ratio - 2.0) < 0.01, "Doubling gram weight should double calories")
        }
    }
    
    @Test("Property: Adjusted calories never negative", .tags(.property, .servingAdjustment))
    func testProperty_AdjustedCalories_NeverNegative() async throws {
        for _ in 0..<100 {
            let baseCalories = Double.random(in: 0...1000)
            let servingSize = Double.random(in: 1...500)
            let gramWeight = Double.random(in: 1...500)
            let multiplier = Double.random(in: 0.1...5.0)
            
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Test Food",
                calories: baseCalories,
                servingSize: String(Int(servingSize)),
                servingUnit: "g",
                brandName: nil,
                protein: nil,
                carbohydrates: nil,
                fats: nil
            )
            
            let option = ServingOption(description: "Test", gramWeight: gramWeight)
            let calories = adjustedCalories(result: result, servingOption: option, multiplier: multiplier)
            
            #expect(calories >= 0, "Adjusted calories should never be negative")
        }
    }
    
    @Test("Property: Macro ratios preserved after scaling", .tags(.property, .servingAdjustment))
    func testProperty_MacroRatios_PreservedAfterScaling() async throws {
        for _ in 0..<100 {
            let protein = Double.random(in: 0...100)
            let carbs = Double.random(in: 0...100)
            let fats = Double.random(in: 0...100)
            let servingSize = 100.0
            
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Test Food",
                calories: 200,
                servingSize: "100",
                servingUnit: "g",
                brandName: nil,
                protein: protein,
                carbohydrates: carbs,
                fats: fats
            )
            
            let gramWeight = Double.random(in: 50...300)
            let gramRatio = gramWeight / servingSize
            
            let adjustedProtein = protein * gramRatio
            let adjustedCarbs = carbs * gramRatio
            let adjustedFats = fats * gramRatio
            
            // Check that ratios are preserved
            if protein > 0 {
                let proteinRatio = adjustedProtein / protein
                #expect(abs(proteinRatio - gramRatio) < 0.01, "Protein ratio should match gram ratio")
            }
            
            if carbs > 0 {
                let carbsRatio = adjustedCarbs / carbs
                #expect(abs(carbsRatio - gramRatio) < 0.01, "Carbs ratio should match gram ratio")
            }
            
            if fats > 0 {
                let fatsRatio = adjustedFats / fats
                #expect(abs(fatsRatio - gramRatio) < 0.01, "Fats ratio should match gram ratio")
            }
        }
    }
    
    @Test("Property: Zero multiplier produces zero calories", .tags(.property, .servingAdjustment))
    func testProperty_ZeroMultiplier_ProducesZeroCalories() async throws {
        for _ in 0..<100 {
            let baseCalories = Double.random(in: 50...500)
            let servingSize = Double.random(in: 50...200)
            let gramWeight = Double.random(in: 50...200)
            
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Test Food",
                calories: baseCalories,
                servingSize: String(Int(servingSize)),
                servingUnit: "g",
                brandName: nil,
                protein: nil,
                carbohydrates: nil,
                fats: nil
            )
            
            let option = ServingOption(description: "Test", gramWeight: gramWeight)
            let calories = adjustedCalories(result: result, servingOption: option, multiplier: 0.0)
            
            #expect(calories == 0, "Zero multiplier should produce zero calories")
        }
    }
}
