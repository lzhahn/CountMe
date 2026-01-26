//
//  CustomMeal.swift
//  CountMe
//
//  Created by Kiro on 1/21/26.
//

import Foundation
import SwiftData

/// Represents a reusable custom meal template with multiple ingredients
///
/// A custom meal is a user-created recipe that contains multiple ingredients with
/// full nutritional information. Custom meals can be saved, browsed, and added to
/// daily logs with optional serving size adjustments.
///
/// The model maintains computed properties for total nutritional values across all
/// ingredients, ensuring consistency with the meal's composition.
///
/// - Note: Editing a custom meal template does not affect previously logged instances
///         (Property 6: Custom Meal Data Independence)
@Model
final class CustomMeal {
    /// Unique identifier for the custom meal
    var id: UUID
    
    /// User-provided name for the meal (e.g., "Chicken Stir Fry")
    var name: String
    
    /// List of ingredients that make up this meal
    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]
    
    /// Timestamp when the meal was first created
    var createdAt: Date
    
    /// Timestamp when the meal was last added to a daily log
    var lastUsedAt: Date
    
    /// Base serving size (default 1.0, can be adjusted when adding to log)
    var servingsCount: Double
    
    /// Total calories across all ingredients
    ///
    /// Computed by summing the calories of all ingredients in the meal.
    /// This value updates automatically when ingredients are added, removed, or modified.
    ///
    /// - Returns: Sum of all ingredient calories
    var totalCalories: Double {
        ingredients.reduce(0) { $0 + $1.calories }
    }
    
    /// Total protein across all ingredients in grams
    ///
    /// Computed by summing the protein values of all ingredients, treating nil as zero.
    /// This ensures backward compatibility with ingredients that lack macro data.
    ///
    /// - Returns: Sum of all ingredient protein values (nil treated as 0)
    var totalProtein: Double {
        ingredients.reduce(0) { $0 + ($1.protein ?? 0) }
    }
    
    /// Total carbohydrates across all ingredients in grams
    ///
    /// Computed by summing the carbohydrate values of all ingredients, treating nil as zero.
    /// This ensures backward compatibility with ingredients that lack macro data.
    ///
    /// - Returns: Sum of all ingredient carbohydrate values (nil treated as 0)
    var totalCarbohydrates: Double {
        ingredients.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }
    
    /// Total fats across all ingredients in grams
    ///
    /// Computed by summing the fat values of all ingredients, treating nil as zero.
    /// This ensures backward compatibility with ingredients that lack macro data.
    ///
    /// - Returns: Sum of all ingredient fat values (nil treated as 0)
    var totalFats: Double {
        ingredients.reduce(0) { $0 + ($1.fats ?? 0) }
    }
    
    /// Creates a new custom meal with ingredients and metadata
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: User-provided name for the meal
    ///   - ingredients: Array of ingredients that compose the meal
    ///   - createdAt: Creation timestamp (defaults to current date)
    ///   - lastUsedAt: Last used timestamp (defaults to current date)
    ///   - servingsCount: Base serving size (defaults to 1.0)
    init(
        id: UUID = UUID(),
        name: String,
        ingredients: [Ingredient],
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        servingsCount: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.servingsCount = servingsCount
    }
}
