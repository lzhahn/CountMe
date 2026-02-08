//
//  CustomMeal.swift
//  CountMe
//
//  Created by Kiro on 1/21/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

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
final class CustomMeal: SyncableEntity {
    /// Unique identifier for the custom meal (internal UUID)
    var _id: UUID
    
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
    
    // SyncableEntity properties
    var userId: String = ""
    var lastModified: Date = Date()
    var syncStatus: SyncStatus = SyncStatus.pendingUpload
    
    /// String representation of the UUID for SyncableEntity conformance
    var id: String {
        _id.uuidString
    }
    
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
        servingsCount: Double = 1.0,
        userId: String = "",
        lastModified: Date = Date(),
        syncStatus: SyncStatus = .pendingUpload
    ) {
        self._id = id
        self.name = name
        self.ingredients = ingredients
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.servingsCount = servingsCount
        self.userId = userId
        self.lastModified = lastModified
        self.syncStatus = syncStatus
    }
}

// MARK: - SyncableEntity Conformance

extension CustomMeal {
    /// Converts the custom meal to a Firestore-compatible dictionary
    ///
    /// Serializes all properties including the ingredients array with full
    /// nutritional information for each ingredient.
    ///
    /// - Returns: Dictionary with all custom meal data in Firestore-compatible format
    func toFirestoreData() -> [String: Any] {
        let ingredientsData = ingredients.map { ingredient -> [String: Any] in
            var ingredientDict: [String: Any] = [
                "id": ingredient.id.uuidString,
                "name": ingredient.name,
                "quantity": ingredient.quantity,
                "unit": ingredient.unit,
                "calories": ingredient.calories
            ]
            
            // Add optional macro fields
            if let protein = ingredient.protein {
                ingredientDict["protein"] = protein
            }
            if let carbohydrates = ingredient.carbohydrates {
                ingredientDict["carbohydrates"] = carbohydrates
            }
            if let fats = ingredient.fats {
                ingredientDict["fats"] = fats
            }
            
            return ingredientDict
        }
        
        return [
            "id": _id.uuidString,
            "name": name,
            "ingredients": ingredientsData,
            "createdAt": Timestamp(date: createdAt),
            "lastUsedAt": Timestamp(date: lastUsedAt),
            "servingsCount": servingsCount,
            "userId": userId,
            "lastModified": Timestamp(date: lastModified),
            "syncStatus": syncStatus.rawValue
        ]
    }
    
    /// Creates a CustomMeal instance from Firestore data
    ///
    /// Deserializes a Firestore document into a fully-formed CustomMeal instance
    /// including all ingredients with their nutritional information.
    ///
    /// - Parameter data: Dictionary containing Firestore document data
    /// - Returns: Fully initialized CustomMeal instance with ingredients
    /// - Throws: SyncError.invalidFirestoreData if required fields are missing or invalid
    static func fromFirestoreData(_ data: [String: Any]) throws -> CustomMeal {
        // Extract required fields
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let ingredientsData = data["ingredients"] as? [[String: Any]],
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let lastUsedAt = (data["lastUsedAt"] as? Timestamp)?.dateValue(),
              let servingsCount = data["servingsCount"] as? Double,
              let userId = data["userId"] as? String,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue(),
              let syncStatusRaw = data["syncStatus"] as? String,
              let syncStatus = SyncStatus(rawValue: syncStatusRaw)
        else {
            throw SyncError.invalidFirestoreData
        }
        
        // Parse ingredients array
        let ingredients = try ingredientsData.map { ingredientDict -> Ingredient in
            guard let ingredientIdString = ingredientDict["id"] as? String,
                  let ingredientId = UUID(uuidString: ingredientIdString),
                  let ingredientName = ingredientDict["name"] as? String,
                  let quantity = ingredientDict["quantity"] as? Double,
                  let unit = ingredientDict["unit"] as? String,
                  let calories = ingredientDict["calories"] as? Double
            else {
                throw SyncError.invalidFirestoreData
            }
            
            // Extract optional macro fields
            let protein = ingredientDict["protein"] as? Double
            let carbohydrates = ingredientDict["carbohydrates"] as? Double
            let fats = ingredientDict["fats"] as? Double
            
            return Ingredient(
                id: ingredientId,
                name: ingredientName,
                quantity: quantity,
                unit: unit,
                calories: calories,
                protein: protein,
                carbohydrates: carbohydrates,
                fats: fats
            )
        }
        
        return CustomMeal(
            id: id,
            name: name,
            ingredients: ingredients,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            servingsCount: servingsCount,
            userId: userId,
            lastModified: lastModified,
            syncStatus: syncStatus
        )
    }
}
