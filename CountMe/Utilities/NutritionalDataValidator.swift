//
//  NutritionalDataValidator.swift
//  CountMe
//
//  Created by Kiro on 1/23/26.
//

import Foundation

/// Utilities for validating nutritional data across FoodItems, Ingredients, and manual entries
///
/// This module provides consistent validation logic for all nutritional data in the application,
/// ensuring data integrity and providing field-specific error messages for validation failures.
///
/// **Validates: Requirements 10.1, 10.2, 10.3, 10.5**
enum NutritionalDataValidator {
    
    /// Validates that a nutritional value is non-negative
    ///
    /// Ensures that calorie, protein, carbohydrate, and fat values are not negative.
    /// Nil values are considered valid (representing missing optional data).
    ///
    /// - Parameters:
    ///   - value: The nutritional value to validate (optional)
    ///   - fieldName: The name of the field being validated (for error messages)
    ///
    /// - Throws: `ValidationError.negativeValue` if the value is negative
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Valid cases
    /// try validateNutritionalValue(250.0, fieldName: "Calories")  // OK
    /// try validateNutritionalValue(0.0, fieldName: "Protein")     // OK (zero is valid)
    /// try validateNutritionalValue(nil, fieldName: "Fats")        // OK (nil is valid)
    ///
    /// // Invalid case
    /// try validateNutritionalValue(-10.0, fieldName: "Carbohydrates")  // Throws error
    /// ```
    ///
    /// **Validates: Requirements 10.1, 10.3**
    static func validateNutritionalValue(_ value: Double?, fieldName: String) throws {
        guard let value = value else {
            // Nil is valid (represents missing optional data)
            return
        }
        
        guard value >= 0 else {
            throw ValidationError.negativeValue(fieldName: fieldName, value: value)
        }
    }
    
    /// Validates that a serving size is positive (greater than zero)
    ///
    /// Ensures that serving size multipliers and quantities are positive numbers.
    /// Zero and negative values are rejected.
    ///
    /// - Parameters:
    ///   - value: The serving size value to validate
    ///   - fieldName: The name of the field being validated (for error messages)
    ///
    /// - Throws: `ValidationError.nonPositiveValue` if the value is zero or negative
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Valid case
    /// try validateServingSize(1.5, fieldName: "Serving Multiplier")  // OK
    ///
    /// // Invalid cases
    /// try validateServingSize(0.0, fieldName: "Quantity")    // Throws error
    /// try validateServingSize(-2.0, fieldName: "Quantity")   // Throws error
    /// ```
    ///
    /// **Validates: Requirements 10.3**
    static func validateServingSize(_ value: Double, fieldName: String) throws {
        guard value > 0 else {
            throw ValidationError.nonPositiveValue(fieldName: fieldName, value: value)
        }
    }
    
    /// Validates that required ingredient fields are present and valid
    ///
    /// Ensures that an ingredient has a non-empty name and non-negative calorie value.
    /// This validation applies to all ingredient sources (AI-parsed, manual entry, API).
    ///
    /// - Parameters:
    ///   - name: The ingredient name
    ///   - calories: The calorie value
    ///
    /// - Throws:
    ///   - `ValidationError.missingRequiredField` if name is empty
    ///   - `ValidationError.negativeValue` if calories are negative
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Valid case
    /// try validateRequiredIngredientFields(name: "chicken breast", calories: 187.0)  // OK
    ///
    /// // Invalid cases
    /// try validateRequiredIngredientFields(name: "", calories: 100.0)      // Throws missing field error
    /// try validateRequiredIngredientFields(name: "rice", calories: -50.0)  // Throws negative value error
    /// ```
    ///
    /// **Validates: Requirements 10.2**
    static func validateRequiredIngredientFields(name: String, calories: Double) throws {
        // Validate name is non-empty
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField(fieldName: "Name")
        }
        
        // Validate calories are non-negative
        try validateNutritionalValue(calories, fieldName: "Calories")
    }
    
    /// Validates all nutritional values for a food item or ingredient
    ///
    /// Performs comprehensive validation of all nutritional fields, ensuring consistency
    /// across FoodItems, Ingredients, and manual entries.
    ///
    /// - Parameters:
    ///   - calories: The calorie value (required)
    ///   - protein: The protein value in grams (optional)
    ///   - carbohydrates: The carbohydrate value in grams (optional)
    ///   - fats: The fat value in grams (optional)
    ///
    /// - Throws: `ValidationError.negativeValue` if any value is negative
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Valid case
    /// try validateAllNutritionalValues(
    ///     calories: 250.0,
    ///     protein: 35.0,
    ///     carbohydrates: 0.0,
    ///     fats: 4.0
    /// )  // OK
    ///
    /// // Invalid case
    /// try validateAllNutritionalValues(
    ///     calories: 250.0,
    ///     protein: -5.0,  // Invalid
    ///     carbohydrates: 0.0,
    ///     fats: 4.0
    /// )  // Throws error
    /// ```
    ///
    /// **Validates: Requirements 10.1, 10.5**
    static func validateAllNutritionalValues(
        calories: Double,
        protein: Double? = nil,
        carbohydrates: Double? = nil,
        fats: Double? = nil
    ) throws {
        try validateNutritionalValue(calories, fieldName: "Calories")
        try validateNutritionalValue(protein, fieldName: "Protein")
        try validateNutritionalValue(carbohydrates, fieldName: "Carbohydrates")
        try validateNutritionalValue(fats, fieldName: "Fats")
    }
}

/// Errors that can occur during nutritional data validation
enum ValidationError: Error, LocalizedError {
    /// A nutritional value is negative
    case negativeValue(fieldName: String, value: Double)
    
    /// A serving size or quantity is zero or negative
    case nonPositiveValue(fieldName: String, value: Double)
    
    /// A required field is missing or empty
    case missingRequiredField(fieldName: String)
    
    /// A serving count is invalid (zero, negative, or non-numeric)
    case invalidServingCount
    
    var errorDescription: String? {
        switch self {
        case .negativeValue(let fieldName, let value):
            return "\(fieldName) must be non-negative (received: \(value))"
        case .nonPositiveValue(let fieldName, let value):
            return "\(fieldName) must be greater than zero (received: \(value))"
        case .missingRequiredField(let fieldName):
            return "\(fieldName) is required and cannot be empty"
        case .invalidServingCount:
            return "Serving count must be a positive number greater than zero"
        }
    }
}
