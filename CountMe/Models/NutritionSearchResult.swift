//
//  NutritionSearchResult.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation

/// Represents a serving option for a food item
///
/// A serving option defines a specific way to measure a food item (e.g., "1 cup", "100g", "1 tbsp")
/// along with its equivalent weight in grams for nutritional calculations.
///
/// # Example
/// ```swift
/// let cupOption = ServingOption(description: "1 cup (240ml)", gramWeight: 240)
/// let ouncesOption = ServingOption(description: "1 oz", gramWeight: 28)
/// ```
struct ServingOption: Identifiable, Hashable {
    let id: String
    let description: String
    let gramWeight: Double
    
    /// Creates a serving option with validation
    ///
    /// - Parameters:
    ///   - description: Human-readable description of the serving (e.g., "1 cup", "100g")
    ///   - gramWeight: Weight of this serving in grams (must be positive)
    ///
    /// - Note: The gramWeight must be greater than 0. Invalid values will use 100g as default.
    init(description: String, gramWeight: Double) {
        self.id = UUID().uuidString
        self.description = description
        // Validate gramWeight is positive, default to 100g if invalid
        self.gramWeight = gramWeight > 0 ? gramWeight : 100
    }
    
    /// Creates default serving options based on serving size and unit
    ///
    /// Generates a standard set of serving options including:
    /// - 100g baseline option (always included)
    /// - Original serving size option (if provided and valid)
    ///
    /// - Parameters:
    ///   - servingSize: The numeric serving size (e.g., "100", "1")
    ///   - servingUnit: The unit of measurement (e.g., "g", "cup", "oz")
    ///
    /// - Returns: Array of serving options with at least one option (100g)
    ///
    /// # Example
    /// ```swift
    /// let options = ServingOption.defaultOptions(servingSize: "240", servingUnit: "ml")
    /// // Returns: [ServingOption(description: "100g", gramWeight: 100),
    /// //           ServingOption(description: "240ml", gramWeight: 240)]
    /// ```
    static func defaultOptions(servingSize: String?, servingUnit: String?) -> [ServingOption] {
        var options: [ServingOption] = []
        
        // Always include 100g option
        options.append(ServingOption(description: "100g", gramWeight: 100))
        
        // Add serving size option if available
        if let size = servingSize,
           let sizeValue = Double(size),
           let unit = servingUnit,
           sizeValue > 0 {
            let description = "\(size)\(unit)"
            options.append(ServingOption(description: description, gramWeight: sizeValue))
        }
        
        return options
    }
}

/// Represents a nutrition search result from the USDA FoodData Central API
///
/// Contains basic nutritional information including calories and optional macro data.
/// Macro fields (protein, carbohydrates, fats) are optional as they may not always
/// be available in API responses.
///
/// # Example
/// ```swift
/// let result = NutritionSearchResult(
///     id: "123",
///     name: "Chicken Breast",
///     calories: 165,
///     servingSize: "100",
///     servingUnit: "g",
///     brandName: "Generic",
///     protein: 31.0,
///     carbohydrates: 0.0,
///     fats: 3.6
/// )
/// ```
struct NutritionSearchResult: Identifiable {
    let id: String
    let name: String
    let calories: Double
    let servingSize: String?
    let servingUnit: String?
    let brandName: String?
    
    // Macro tracking fields (optional, may not be available for all foods)
    let protein: Double?        // grams
    let carbohydrates: Double?  // grams
    let fats: Double?           // grams
    
    // Available serving options (e.g., "1 cup", "1 tbsp", "100g")
    let servingOptions: [ServingOption]
    
    /// Convenience initializer that generates default serving options
    ///
    /// If servingOptions is not provided, automatically generates default options
    /// based on the servingSize and servingUnit parameters.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the food item
    ///   - name: Name of the food item
    ///   - calories: Calories per serving
    ///   - servingSize: Numeric serving size (e.g., "100", "1")
    ///   - servingUnit: Unit of measurement (e.g., "g", "cup")
    ///   - brandName: Optional brand name
    ///   - protein: Optional protein content in grams
    ///   - carbohydrates: Optional carbohydrate content in grams
    ///   - fats: Optional fat content in grams
    ///   - servingOptions: Optional array of serving options (auto-generated if nil)
    init(
        id: String,
        name: String,
        calories: Double,
        servingSize: String?,
        servingUnit: String?,
        brandName: String?,
        protein: Double?,
        carbohydrates: Double?,
        fats: Double?,
        servingOptions: [ServingOption]? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.brandName = brandName
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fats = fats
        self.servingOptions = servingOptions ?? ServingOption.defaultOptions(servingSize: servingSize, servingUnit: servingUnit)
    }
}
