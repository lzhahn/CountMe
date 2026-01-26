//
//  ServingSizeCalculator.swift
//  CountMe
//
//  Created by Kiro on 1/23/26.
//

import Foundation

/// Utilities for calculating adjusted nutritional values based on serving size multipliers
///
/// This module provides functions to scale ingredient nutritional data proportionally
/// when users adjust serving sizes for custom meals.
enum ServingSizeCalculator {
    
    /// Applies a serving size multiplier to an ingredient, scaling all nutritional values proportionally
    ///
    /// Creates a new ingredient instance with all nutritional values (calories, protein, carbohydrates,
    /// fats, and quantity) multiplied by the specified multiplier. The original ingredient remains unchanged.
    ///
    /// - Parameters:
    ///   - multiplier: The scaling factor to apply (must be positive, > 0)
    ///   - ingredient: The ingredient to scale
    ///
    /// - Returns: A new Ingredient instance with scaled nutritional values
    ///
    /// - Throws: `ServingSizeError.invalidMultiplier` if multiplier is zero or negative
    ///
    /// - Note: This function preserves immutability by creating a new Ingredient instance
    ///         rather than modifying the original.
    ///
    /// **Example Usage:**
    /// ```swift
    /// let originalIngredient = Ingredient(
    ///     name: "chicken breast",
    ///     quantity: 6,
    ///     unit: "oz",
    ///     calories: 187,
    ///     protein: 35,
    ///     carbohydrates: 0,
    ///     fats: 4
    /// )
    ///
    /// // Scale to half serving
    /// let halfServing = try applyServingMultiplier(0.5, to: originalIngredient)
    /// // Result: 3 oz, 93.5 calories, 17.5g protein, 0g carbs, 2g fats
    ///
    /// // Scale to double serving
    /// let doubleServing = try applyServingMultiplier(2.0, to: originalIngredient)
    /// // Result: 12 oz, 374 calories, 70g protein, 0g carbs, 8g fats
    /// ```
    ///
    /// **Validates: Requirements 4.1, 4.2, 4.3**
    static func applyServingMultiplier(_ multiplier: Double, to ingredient: Ingredient) throws -> Ingredient {
        // Validate multiplier is positive (> 0)
        guard multiplier > 0 else {
            throw ServingSizeError.invalidMultiplier(multiplier)
        }
        
        // Create new ingredient with scaled values, preserving immutability
        return Ingredient(
            id: ingredient.id,
            name: ingredient.name,
            quantity: ingredient.quantity * multiplier,
            unit: ingredient.unit,
            calories: ingredient.calories * multiplier,
            protein: ingredient.protein.map { $0 * multiplier },
            carbohydrates: ingredient.carbohydrates.map { $0 * multiplier },
            fats: ingredient.fats.map { $0 * multiplier }
        )
    }
}

/// Errors that can occur during serving size calculations
enum ServingSizeError: Error, LocalizedError {
    /// The multiplier provided was zero or negative
    case invalidMultiplier(Double)
    
    var errorDescription: String? {
        switch self {
        case .invalidMultiplier(let value):
            return "Serving size must be greater than zero (received: \(value))"
        }
    }
}
