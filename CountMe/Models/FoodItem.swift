//
//  FoodItem.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class FoodItem: SyncableEntity {
    var _id: UUID
    var name: String
    var calories: Double
    var timestamp: Date
    var servingSize: String?
    var servingUnit: String?
    var source: FoodItemSource
    
    // Macro tracking fields (optional for backward compatibility)
    var protein: Double?
    var carbohydrates: Double?
    var fats: Double?
    
    // Relationship to DailyLog
    var dailyLog: DailyLog?
    
    // SyncableEntity properties
    var userId: String = ""
    var lastModified: Date = Date()
    var syncStatus: SyncStatus = SyncStatus.pendingUpload
    
    /// String representation of the UUID for SyncableEntity conformance
    var id: String {
        _id.uuidString
    }
    
    /// Public throwing initializer with validation
    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        timestamp: Date = Date(),
        servingSize: String? = nil,
        servingUnit: String? = nil,
        source: FoodItemSource = .manual,
        protein: Double? = nil,
        carbohydrates: Double? = nil,
        fats: Double? = nil,
        userId: String = "",
        lastModified: Date = Date(),
        syncStatus: SyncStatus = .pendingUpload
    ) throws {
        // Validate name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName(modelType: "FoodItem")
        }
        
        // Validate calories
        guard calories >= 0 else {
            throw ValidationError.negativeCalories(modelType: "FoodItem", value: calories)
        }
        guard calories <= ValidationConstants.maxCalories else {
            throw ValidationError.caloriesExceedMax(modelType: "FoodItem", value: calories, max: ValidationConstants.maxCalories)
        }
        
        // Validate optional macros
        if let protein = protein {
            guard protein >= 0 else {
                throw ValidationError.negativeMacro(modelType: "FoodItem", field: "protein", value: protein)
            }
            guard protein <= ValidationConstants.maxMacroGrams else {
                throw ValidationError.macroExceedMax(modelType: "FoodItem", field: "protein", value: protein, max: ValidationConstants.maxMacroGrams)
            }
        }
        
        if let carbohydrates = carbohydrates {
            guard carbohydrates >= 0 else {
                throw ValidationError.negativeMacro(modelType: "FoodItem", field: "carbohydrates", value: carbohydrates)
            }
            guard carbohydrates <= ValidationConstants.maxMacroGrams else {
                throw ValidationError.macroExceedMax(modelType: "FoodItem", field: "carbohydrates", value: carbohydrates, max: ValidationConstants.maxMacroGrams)
            }
        }
        
        if let fats = fats {
            guard fats >= 0 else {
                throw ValidationError.negativeMacro(modelType: "FoodItem", field: "fats", value: fats)
            }
            guard fats <= ValidationConstants.maxMacroGrams else {
                throw ValidationError.macroExceedMax(modelType: "FoodItem", field: "fats", value: fats, max: ValidationConstants.maxMacroGrams)
            }
        }
        
        // Assign properties after validation
        self._id = id
        self.name = name
        self.calories = calories
        self.timestamp = timestamp
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.source = source
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fats = fats
        self.userId = userId
        self.lastModified = lastModified
        self.syncStatus = syncStatus
    }
    
    /// Internal non-throwing initializer for deserialization (skips validation)
    internal init(
        validated id: UUID,
        name: String,
        calories: Double,
        timestamp: Date,
        servingSize: String?,
        servingUnit: String?,
        source: FoodItemSource,
        protein: Double?,
        carbohydrates: Double?,
        fats: Double?,
        userId: String,
        lastModified: Date,
        syncStatus: SyncStatus
    ) {
        self._id = id
        self.name = name
        self.calories = calories
        self.timestamp = timestamp
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.source = source
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fats = fats
        self.userId = userId
        self.lastModified = lastModified
        self.syncStatus = syncStatus
    }
}

// MARK: - SyncableEntity Conformance

extension FoodItem {
    /// Converts the food item to a Firestore-compatible dictionary
    ///
    /// Serializes all properties including nutritional data, serving information,
    /// and sync metadata for cloud storage.
    ///
    /// - Returns: Dictionary with all food item data in Firestore-compatible format
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": _id.uuidString,
            "name": name,
            "calories": calories,
            "timestamp": Timestamp(date: timestamp),
            "source": source.rawValue,
            "userId": userId,
            "lastModified": Timestamp(date: lastModified),
            "syncStatus": syncStatus.rawValue
        ]
        
        // Add optional fields only if they have values
        if let servingSize = servingSize {
            data["servingSize"] = servingSize
        }
        if let servingUnit = servingUnit {
            data["servingUnit"] = servingUnit
        }
        if let protein = protein {
            data["protein"] = protein
        }
        if let carbohydrates = carbohydrates {
            data["carbohydrates"] = carbohydrates
        }
        if let fats = fats {
            data["fats"] = fats
        }
        
        return data
    }
    
    /// Creates a FoodItem instance from Firestore data
    ///
    /// Deserializes a Firestore document into a fully-formed FoodItem instance.
    /// Handles both required and optional fields with appropriate validation.
    ///
    /// - Parameter data: Dictionary containing Firestore document data
    /// - Returns: Fully initialized FoodItem instance
    /// - Throws: SyncError.invalidFirestoreData if required fields are missing or invalid
    static func fromFirestoreData(_ data: [String: Any]) throws -> FoodItem {
        // Extract required fields
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let calories = data["calories"] as? Double,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
              let sourceRaw = data["source"] as? String,
              let source = FoodItemSource(rawValue: sourceRaw),
              let userId = data["userId"] as? String,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue(),
              let syncStatusRaw = data["syncStatus"] as? String,
              let syncStatus = SyncStatus(rawValue: syncStatusRaw)
        else {
            throw SyncError.invalidFirestoreData
        }
        
        // Extract optional fields
        let servingSize = data["servingSize"] as? String
        let servingUnit = data["servingUnit"] as? String
        let protein = data["protein"] as? Double
        let carbohydrates = data["carbohydrates"] as? Double
        let fats = data["fats"] as? Double
        
        // Range validation (Requirement 6.1, 6.2, 6.3, 6.8)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SyncError.invalidData(reason: "FoodItem name is empty")
        }
        guard calories >= 0 else {
            throw SyncError.invalidData(reason: "FoodItem calories \(calories) is negative")
        }
        guard calories <= ValidationConstants.maxCalories else {
            throw SyncError.invalidData(reason: "FoodItem calories \(calories) exceeds maximum of \(ValidationConstants.maxCalories)")
        }
        
        // Validate optional macros
        if let protein = protein {
            guard protein >= 0 else {
                throw SyncError.invalidData(reason: "FoodItem protein \(protein) is negative")
            }
            guard protein <= ValidationConstants.maxMacroGrams else {
                throw SyncError.invalidData(reason: "FoodItem protein \(protein)g exceeds maximum of \(ValidationConstants.maxMacroGrams)g")
            }
        }
        
        if let carbohydrates = carbohydrates {
            guard carbohydrates >= 0 else {
                throw SyncError.invalidData(reason: "FoodItem carbohydrates \(carbohydrates) is negative")
            }
            guard carbohydrates <= ValidationConstants.maxMacroGrams else {
                throw SyncError.invalidData(reason: "FoodItem carbohydrates \(carbohydrates)g exceeds maximum of \(ValidationConstants.maxMacroGrams)g")
            }
        }
        
        if let fats = fats {
            guard fats >= 0 else {
                throw SyncError.invalidData(reason: "FoodItem fats \(fats) is negative")
            }
            guard fats <= ValidationConstants.maxMacroGrams else {
                throw SyncError.invalidData(reason: "FoodItem fats \(fats)g exceeds maximum of \(ValidationConstants.maxMacroGrams)g")
            }
        }
        
        // Use internal validated initializer (skips validation since we just validated)
        return FoodItem(
            validated: id,
            name: name,
            calories: calories,
            timestamp: timestamp,
            servingSize: servingSize,
            servingUnit: servingUnit,
            source: source,
            protein: protein,
            carbohydrates: carbohydrates,
            fats: fats,
            userId: userId,
            lastModified: lastModified,
            syncStatus: syncStatus
        )
    }
}

// MARK: - SyncError

/// Errors that can occur during synchronization operations
enum SyncError: LocalizedError {
    case invalidFirestoreData
    case notAuthenticated
    case networkUnavailable
    case firestoreError(Error)
    case dataStoreError(Error)
    case conflictResolutionFailed
    case migrationFailed(reason: String)
    case queueProcessingFailed(count: Int)
    case maxRetriesExceeded(operationId: String, attempts: Int)
    case invalidData(reason: String)
    case accountDeletionFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFirestoreData:
            return "Invalid data format from cloud"
        case .notAuthenticated:
            return "You must be signed in to sync data"
        case .networkUnavailable:
            return "Network unavailable. Changes will sync when online"
        case .firestoreError(let error):
            return "Cloud sync error: \(error.localizedDescription)"
        case .dataStoreError(let error):
            return "Local storage error: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflict"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .queueProcessingFailed(let count):
            return "Failed to sync \(count) pending operations"
        case .maxRetriesExceeded(let operationId, let attempts):
            return "Sync failed after \(attempts) retry attempts for operation: \(operationId)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .accountDeletionFailed(let reason):
            return "Failed to delete account data: \(reason)"
        }
    }
}
