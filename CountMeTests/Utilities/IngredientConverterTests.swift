//
//  IngredientConverterTests.swift
//  CountMeTests
//
//  Created by Kiro on 1/28/26.
//

import Testing
import Foundation
@testable import CountMe

/// Tests for ingredient conversion utilities
///
/// Validates that NutritionSearchResult and FoodItem instances can be correctly
/// converted to Ingredient instances with all nutritional data preserved.
struct IngredientConverterTests {
    
    // MARK: - NutritionSearchResult Conversion Tests
    
    @Test("Convert search result with all fields to ingredient")
    func convertSearchResultWithAllFields() throws {
        // Given: A search result with complete nutritional data
        let searchResult = NutritionSearchResult(
            id: "123",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: "Generic",
            protein: 31,
            carbohydrates: 0,
            fats: 3.6
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertSearchResultToIngredient(searchResult)
        
        // Then: All fields should be preserved
        #expect(ingredient.name == "Chicken Breast")
        #expect(ingredient.quantity == 100)
        #expect(ingredient.unit == "g")
        #expect(ingredient.calories == 165)
        #expect(ingredient.protein == 31)
        #expect(ingredient.carbohydrates == 0)
        #expect(ingredient.fats == 3.6)
    }
    
    @Test("Convert search result with missing macro data")
    func convertSearchResultWithMissingMacros() throws {
        // Given: A search result without macro data
        let searchResult = NutritionSearchResult(
            id: "456",
            name: "Apple",
            calories: 95,
            servingSize: "1",
            servingUnit: "medium",
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertSearchResultToIngredient(searchResult)
        
        // Then: Required fields should be present, macros should be nil
        #expect(ingredient.name == "Apple")
        #expect(ingredient.quantity == 1)
        #expect(ingredient.unit == "medium")
        #expect(ingredient.calories == 95)
        #expect(ingredient.protein == nil)
        #expect(ingredient.carbohydrates == nil)
        #expect(ingredient.fats == nil)
    }
    
    @Test("Convert search result with missing serving size defaults to 1.0")
    func convertSearchResultWithMissingServingSize() throws {
        // Given: A search result without serving size
        let searchResult = NutritionSearchResult(
            id: "789",
            name: "Banana",
            calories: 105,
            servingSize: nil,
            servingUnit: nil,
            brandName: nil,
            protein: 1.3,
            carbohydrates: 27,
            fats: 0.4
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertSearchResultToIngredient(searchResult)
        
        // Then: Should default to 1.0 serving
        #expect(ingredient.quantity == 1.0)
        #expect(ingredient.unit == "serving")
        #expect(ingredient.calories == 105)
    }
    
    @Test("Convert search result with invalid serving size defaults to 1.0")
    func convertSearchResultWithInvalidServingSize() throws {
        // Given: A search result with non-numeric serving size
        let searchResult = NutritionSearchResult(
            id: "101",
            name: "Orange",
            calories: 62,
            servingSize: "one",
            servingUnit: "fruit",
            brandName: nil,
            protein: 1.2,
            carbohydrates: 15,
            fats: 0.2
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertSearchResultToIngredient(searchResult)
        
        // Then: Should default to 1.0 when parsing fails
        #expect(ingredient.quantity == 1.0)
        #expect(ingredient.unit == "fruit")
    }
    
    @Test("Convert search result rejects empty name")
    func convertSearchResultRejectsEmptyName() throws {
        // Given: A search result with empty name
        let searchResult = NutritionSearchResult(
            id: "999",
            name: "",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // When/Then: Should throw missing required field error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertSearchResultToIngredient(searchResult)
        }
    }
    
    @Test("Convert search result rejects negative calories")
    func convertSearchResultRejectsNegativeCalories() throws {
        // Given: A search result with negative calories
        let searchResult = NutritionSearchResult(
            id: "888",
            name: "Invalid Food",
            calories: -50,
            servingSize: "1",
            servingUnit: "serving",
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertSearchResultToIngredient(searchResult)
        }
    }
    
    @Test("Convert search result rejects negative protein")
    func convertSearchResultRejectsNegativeProtein() throws {
        // Given: A search result with negative protein
        let searchResult = NutritionSearchResult(
            id: "777",
            name: "Bad Food",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            brandName: nil,
            protein: -5,
            carbohydrates: 10,
            fats: 2
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertSearchResultToIngredient(searchResult)
        }
    }
    
    @Test("Convert search result rejects negative carbohydrates")
    func convertSearchResultRejectsNegativeCarbs() throws {
        // Given: A search result with negative carbs
        let searchResult = NutritionSearchResult(
            id: "666",
            name: "Bad Food",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            brandName: nil,
            protein: 5,
            carbohydrates: -10,
            fats: 2
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertSearchResultToIngredient(searchResult)
        }
    }
    
    @Test("Convert search result rejects negative fats")
    func convertSearchResultRejectsNegativeFats() throws {
        // Given: A search result with negative fats
        let searchResult = NutritionSearchResult(
            id: "555",
            name: "Bad Food",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            brandName: nil,
            protein: 5,
            carbohydrates: 10,
            fats: -2
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertSearchResultToIngredient(searchResult)
        }
    }
    
    // MARK: - FoodItem Conversion Tests
    
    @Test("Convert food item with all fields to ingredient")
    func convertFoodItemWithAllFields() throws {
        // Given: A food item with complete nutritional data
        let foodItem = FoodItem(
            name: "Brown Rice",
            calories: 216,
            servingSize: "1",
            servingUnit: "cup",
            protein: 5,
            carbohydrates: 45,
            fats: 1.8
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertFoodItemToIngredient(foodItem)
        
        // Then: All fields should be preserved
        #expect(ingredient.name == "Brown Rice")
        #expect(ingredient.quantity == 1)
        #expect(ingredient.unit == "cup")
        #expect(ingredient.calories == 216)
        #expect(ingredient.protein == 5)
        #expect(ingredient.carbohydrates == 45)
        #expect(ingredient.fats == 1.8)
    }
    
    @Test("Convert food item with missing macro data")
    func convertFoodItemWithMissingMacros() throws {
        // Given: A food item without macro data (backward compatibility)
        let foodItem = FoodItem(
            name: "Pasta",
            calories: 200,
            servingSize: "2",
            servingUnit: "oz",
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertFoodItemToIngredient(foodItem)
        
        // Then: Required fields should be present, macros should be nil
        #expect(ingredient.name == "Pasta")
        #expect(ingredient.quantity == 2)
        #expect(ingredient.unit == "oz")
        #expect(ingredient.calories == 200)
        #expect(ingredient.protein == nil)
        #expect(ingredient.carbohydrates == nil)
        #expect(ingredient.fats == nil)
    }
    
    @Test("Convert food item with missing serving size defaults to 1.0")
    func convertFoodItemWithMissingServingSize() throws {
        // Given: A food item without serving size
        let foodItem = FoodItem(
            name: "Salad",
            calories: 150,
            servingSize: nil,
            servingUnit: nil,
            protein: 5,
            carbohydrates: 10,
            fats: 8
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertFoodItemToIngredient(foodItem)
        
        // Then: Should default to 1.0 serving
        #expect(ingredient.quantity == 1.0)
        #expect(ingredient.unit == "serving")
        #expect(ingredient.calories == 150)
    }
    
    @Test("Convert food item with invalid serving size defaults to 1.0")
    func convertFoodItemWithInvalidServingSize() throws {
        // Given: A food item with non-numeric serving size
        let foodItem = FoodItem(
            name: "Soup",
            calories: 120,
            servingSize: "one bowl",
            servingUnit: "bowl",
            protein: 6,
            carbohydrates: 15,
            fats: 3
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertFoodItemToIngredient(foodItem)
        
        // Then: Should default to 1.0 when parsing fails
        #expect(ingredient.quantity == 1.0)
        #expect(ingredient.unit == "bowl")
    }
    
    @Test("Convert food item rejects empty name")
    func convertFoodItemRejectsEmptyName() throws {
        // Given: A food item with empty name
        let foodItem = FoodItem(
            name: "",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving"
        )
        
        // When/Then: Should throw missing required field error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertFoodItemToIngredient(foodItem)
        }
    }
    
    @Test("Convert food item rejects negative calories")
    func convertFoodItemRejectsNegativeCalories() throws {
        // Given: A food item with negative calories
        let foodItem = FoodItem(
            name: "Invalid Food",
            calories: -75,
            servingSize: "1",
            servingUnit: "serving"
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertFoodItemToIngredient(foodItem)
        }
    }
    
    @Test("Convert food item rejects negative protein")
    func convertFoodItemRejectsNegativeProtein() throws {
        // Given: A food item with negative protein
        let foodItem = FoodItem(
            name: "Bad Food",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            protein: -3,
            carbohydrates: 10,
            fats: 2
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertFoodItemToIngredient(foodItem)
        }
    }
    
    @Test("Convert food item rejects negative carbohydrates")
    func convertFoodItemRejectsNegativeCarbs() throws {
        // Given: A food item with negative carbs
        let foodItem = FoodItem(
            name: "Bad Food",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            protein: 3,
            carbohydrates: -15,
            fats: 2
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertFoodItemToIngredient(foodItem)
        }
    }
    
    @Test("Convert food item rejects negative fats")
    func convertFoodItemRejectsNegativeFats() throws {
        // Given: A food item with negative fats
        let foodItem = FoodItem(
            name: "Bad Food",
            calories: 100,
            servingSize: "1",
            servingUnit: "serving",
            protein: 3,
            carbohydrates: 15,
            fats: -4
        )
        
        // When/Then: Should throw invalid value error
        #expect(throws: IngredientConversionError.self) {
            try IngredientConverter.convertFoodItemToIngredient(foodItem)
        }
    }
    
    @Test("Convert food item with zero serving size defaults to 1.0")
    func convertFoodItemWithZeroServingSize() throws {
        // Given: A food item with zero serving size
        let foodItem = FoodItem(
            name: "Snack",
            calories: 80,
            servingSize: "0",
            servingUnit: "piece",
            protein: 2,
            carbohydrates: 10,
            fats: 3
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertFoodItemToIngredient(foodItem)
        
        // Then: Should default to 1.0 for zero or negative serving size
        #expect(ingredient.quantity == 1.0)
        #expect(ingredient.unit == "piece")
    }
    
    @Test("Convert search result with zero serving size defaults to 1.0")
    func convertSearchResultWithZeroServingSize() throws {
        // Given: A search result with zero serving size
        let searchResult = NutritionSearchResult(
            id: "444",
            name: "Snack",
            calories: 80,
            servingSize: "0",
            servingUnit: "piece",
            brandName: nil,
            protein: 2,
            carbohydrates: 10,
            fats: 3
        )
        
        // When: Converting to ingredient
        let ingredient = try IngredientConverter.convertSearchResultToIngredient(searchResult)
        
        // Then: Should default to 1.0 for zero or negative serving size
        #expect(ingredient.quantity == 1.0)
        #expect(ingredient.unit == "piece")
    }
}
