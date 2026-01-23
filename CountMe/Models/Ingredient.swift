//
//  Ingredient.swift
//  CountMe
//
//  Created by Kiro on 1/21/26.
//

import Foundation
import SwiftData

/// Represents a single ingredient within a custom meal
/// 
/// An ingredient contains nutritional information and quantity details for a component
/// of a custom meal. All nutritional values are per the specified quantity and unit.
///
/// - Note: Protein, carbohydrates, and fats are optional to handle cases where
///         macro data is unavailable or incomplete from the AI parser.
@Model
final class Ingredient {
    /// Unique identifier for the ingredient
    var id: UUID
    
    /// Name of the ingredient (e.g., "chicken breast", "white rice")
    var name: String
    
    /// Quantity of the ingredient in the specified unit
    var quantity: Double
    
    /// Unit of measurement (e.g., "cup", "oz", "gram", "tbsp")
    var unit: String
    
    /// Total calories for the specified quantity
    var calories: Double
    
    /// Protein content in grams (optional)
    var protein: Double?
    
    /// Carbohydrate content in grams (optional)
    var carbohydrates: Double?
    
    /// Fat content in grams (optional)
    var fats: Double?
    
    /// Creates a new ingredient with nutritional information
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Name of the ingredient
    ///   - quantity: Amount of the ingredient
    ///   - unit: Unit of measurement
    ///   - calories: Total calories for the quantity
    ///   - protein: Protein in grams (optional)
    ///   - carbohydrates: Carbohydrates in grams (optional)
    ///   - fats: Fats in grams (optional)
    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String,
        calories: Double,
        protein: Double? = nil,
        carbohydrates: Double? = nil,
        fats: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fats = fats
    }
}
