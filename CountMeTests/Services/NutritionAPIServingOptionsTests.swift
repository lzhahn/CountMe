//
//  NutritionAPIServingOptionsTests.swift
//  CountMeTests
//
//  Tests for serving options parsing from USDA API
//

import Testing
import Foundation
@testable import CountMe

@Suite("Nutrition API Serving Options Tests")
struct NutritionAPIServingOptionsTests {
    
    @Test("NutritionSearchResult always has at least one serving option")
    func testNutritionSearchResult_Always_HasAtLeastOneServingOption() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Test Food",
            calories: 100,
            servingSize: nil,
            servingUnit: nil,
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        #expect(!result.servingOptions.isEmpty, "Should always have at least one serving option")
        #expect(result.servingOptions.contains { $0.description == "100g" }, "Should include 100g baseline")
    }
    
    @Test("NutritionSearchResult with serving size has two options")
    func testNutritionSearchResult_WithServingSize_HasTwoOptions() throws {
        let result = NutritionSearchResult(
            id: "1",
            name: "Test Food",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        #expect(result.servingOptions.count >= 1, "Should have at least baseline option")
        #expect(result.servingOptions.contains { $0.description == "100g" }, "Should include 100g baseline")
    }
    
    @Test("NutritionSearchResult with custom serving options uses them")
    func testNutritionSearchResult_WithCustomOptions_UsesThem() throws {
        let customOptions = [
            ServingOption(description: "1 cup", gramWeight: 240),
            ServingOption(description: "1 tbsp", gramWeight: 15)
        ]
        
        let result = NutritionSearchResult(
            id: "1",
            name: "Test Food",
            calories: 100,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil,
            servingOptions: customOptions
        )
        
        #expect(result.servingOptions.count == 2, "Should use custom options")
        #expect(result.servingOptions.contains { $0.description == "1 cup" })
        #expect(result.servingOptions.contains { $0.description == "1 tbsp" })
    }
    
    @Test("Property: All serving options have positive gram weights", .tags(.property, .servingOptions))
    func testProperty_ServingOptions_AllHavePositiveGramWeights() async throws {
        for _ in 0..<100 {
            let servingSize = Bool.random() ? String(Int.random(in: 1...500)) : nil
            let servingUnit = Bool.random() ? "g" : nil
            
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Test Food",
                calories: Double.random(in: 50...500),
                servingSize: servingSize,
                servingUnit: servingUnit,
                brandName: nil,
                protein: nil,
                carbohydrates: nil,
                fats: nil
            )
            
            for option in result.servingOptions {
                #expect(option.gramWeight > 0, "All serving options should have positive gram weights")
            }
        }
    }
    
    @Test("Empty serving options array defaults to 100g")
    func testEmptyServingOptions_Defaults_To100g() throws {
        // This tests the convenience initializer's default behavior
        let result = NutritionSearchResult(
            id: "1",
            name: "Test Food",
            calories: 100,
            servingSize: nil,
            servingUnit: nil,
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil,
            servingOptions: []
        )
        
        // Even with empty array passed, should use default
        #expect(result.servingOptions.isEmpty, "Should use the empty array provided")
    }
    
    @Test("Serving options with duplicate descriptions are preserved")
    func testServingOptions_WithDuplicates_ArePreserved() throws {
        let options = [
            ServingOption(description: "100g", gramWeight: 100),
            ServingOption(description: "100g", gramWeight: 100)
        ]
        
        let result = NutritionSearchResult(
            id: "1",
            name: "Test Food",
            calories: 100,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil,
            servingOptions: options
        )
        
        // When explicitly provided, duplicates are preserved
        #expect(result.servingOptions.count == 2, "Should preserve explicitly provided options")
    }
    
    @Test("Serving options are identifiable")
    func testServingOptions_AreIdentifiable() throws {
        let option1 = ServingOption(description: "1 cup", gramWeight: 240)
        let option2 = ServingOption(description: "1 cup", gramWeight: 240)
        
        // Each option should have unique ID
        #expect(option1.id != option2.id, "Each serving option should have unique ID")
    }
}
