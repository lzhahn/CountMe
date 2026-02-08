//
//  IngredientConverter.swift
//  CountMe
//
//  Created by Kiro on 1/28/26.
//

import Foundation

/// Utility functions for converting search results and food items to ingredients
///
/// These conversion utilities enable building custom meals from existing data sources:
/// - NutritionSearchResult: Foods found via FatSecret API search
/// - FoodItem: Previously logged food entries from daily logs
///
/// All conversions preserve nutritional data (calories and macros) and validate
/// that required fields are present before creating Ingredient instances.
enum IngredientConverter {
    
    /// Converts a nutrition search result to an ingredient
    ///
    /// Maps all available nutritional data from the API search result to an Ingredient
    /// instance suitable for inclusion in a CustomMeal. Serving size and unit information
    /// are preserved, and macro values (protein, carbs, fats) are included if available.
    ///
    /// - Parameter result: The nutrition search result from FatSecret API
    /// - Returns: An Ingredient instance with all nutritional data preserved
    /// - Throws: `IngredientConversionError.missingRequiredField` if name or calories are invalid
    ///
    /// # Example
    /// ```swift
    /// let searchResult = NutritionSearchResult(
    ///     id: "123",
    ///     name: "Chicken Breast",
    ///     calories: 165,
    ///     servingSize: "100",
    ///     servingUnit: "g",
    ///     brandName: nil,
    ///     protein: 31,
    ///     carbohydrates: 0,
    ///     fats: 3.6
    /// )
    /// let ingredient = try convertSearchResultToIngredient(searchResult)
    /// // ingredient.name == "Chicken Breast"
    /// // ingredient.calories == 165
    /// // ingredient.protein == 31
    /// ```
    static func convertSearchResultToIngredient(_ result: NutritionSearchResult) throws -> Ingredient {
        // Validate required fields
        guard !result.name.isEmpty else {
            throw IngredientConversionError.missingRequiredField("name")
        }
        
        guard result.calories >= 0 else {
            throw IngredientConversionError.invalidValue("calories", result.calories)
        }
        
        // Determine quantity and unit
        // If servingSize is available, parse it as quantity; otherwise default to 1.0
        let quantity: Double
        if let servingSizeStr = result.servingSize,
           let parsedQuantity = Double(servingSizeStr),
           parsedQuantity > 0 {
            quantity = parsedQuantity
        } else {
            quantity = 1.0
        }
        
        // Use servingUnit if available, otherwise default to "serving"
        let unit = result.servingUnit ?? "serving"
        
        // Validate optional macro values are non-negative if present
        if let protein = result.protein, protein < 0 {
            throw IngredientConversionError.invalidValue("protein", protein)
        }
        if let carbs = result.carbohydrates, carbs < 0 {
            throw IngredientConversionError.invalidValue("carbohydrates", carbs)
        }
        if let fats = result.fats, fats < 0 {
            throw IngredientConversionError.invalidValue("fats", fats)
        }
        
        // Create and return ingredient with all data preserved
        return Ingredient(
            name: result.name,
            quantity: quantity,
            unit: unit,
            calories: result.calories,
            protein: result.protein,
            carbohydrates: result.carbohydrates,
            fats: result.fats
        )
    }
    
    /// Converts a food item to an ingredient
    ///
    /// Maps all nutritional data from a previously logged FoodItem to an Ingredient
    /// instance suitable for inclusion in a CustomMeal. This enables users to build
    /// custom meals from foods they've already tracked in their daily logs.
    ///
    /// - Parameter foodItem: The food item from a daily log
    /// - Returns: An Ingredient instance with all nutritional data preserved
    /// - Throws: `IngredientConversionError.missingRequiredField` if name or calories are invalid
    ///
    /// # Example
    /// ```swift
    /// let foodItem = FoodItem(
    ///     name: "Brown Rice",
    ///     calories: 216,
    ///     servingSize: "1",
    ///     servingUnit: "cup",
    ///     protein: 5,
    ///     carbohydrates: 45,
    ///     fats: 1.8
    /// )
    /// let ingredient = try convertFoodItemToIngredient(foodItem)
    /// // ingredient.name == "Brown Rice"
    /// // ingredient.calories == 216
    /// // ingredient.carbohydrates == 45
    /// ```
    static func convertFoodItemToIngredient(_ foodItem: FoodItem) throws -> Ingredient {
        // Validate required fields
        guard !foodItem.name.isEmpty else {
            throw IngredientConversionError.missingRequiredField("name")
        }
        
        guard foodItem.calories >= 0 else {
            throw IngredientConversionError.invalidValue("calories", foodItem.calories)
        }
        
        // Determine quantity and unit
        // If servingSize is available, parse it as quantity; otherwise default to 1.0
        let quantity: Double
        if let servingSizeStr = foodItem.servingSize,
           let parsedQuantity = Double(servingSizeStr),
           parsedQuantity > 0 {
            quantity = parsedQuantity
        } else {
            quantity = 1.0
        }
        
        // Use servingUnit if available, otherwise default to "serving"
        let unit = foodItem.servingUnit ?? "serving"
        
        // Validate optional macro values are non-negative if present
        if let protein = foodItem.protein, protein < 0 {
            throw IngredientConversionError.invalidValue("protein", protein)
        }
        if let carbs = foodItem.carbohydrates, carbs < 0 {
            throw IngredientConversionError.invalidValue("carbohydrates", carbs)
        }
        if let fats = foodItem.fats, fats < 0 {
            throw IngredientConversionError.invalidValue("fats", fats)
        }
        
        // Create and return ingredient with all data preserved
        return Ingredient(
            name: foodItem.name,
            quantity: quantity,
            unit: unit,
            calories: foodItem.calories,
            protein: foodItem.protein,
            carbohydrates: foodItem.carbohydrates,
            fats: foodItem.fats
        )
    }
}

/// Errors that can occur during ingredient conversion
enum IngredientConversionError: Error, LocalizedError {
    case missingRequiredField(String)
    case invalidValue(String, Double)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidValue(let field, let value):
            return "Invalid value for \(field): \(value). Must be non-negative."
        }
    }
}
