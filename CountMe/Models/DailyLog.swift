//
//  DailyLog.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class DailyLog: SyncableEntity {
    var _id: UUID
    var date: Date
    
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.dailyLog)
    var foodItems: [FoodItem]
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseItem.dailyLog)
    var exerciseItems: [ExerciseItem]
    
    var dailyGoal: Double?
    
    // SyncableEntity properties
    var userId: String = ""
    var lastModified: Date = Date()
    var syncStatus: SyncStatus = SyncStatus.pendingUpload
    
    /// String representation of the UUID for SyncableEntity conformance
    var id: String {
        _id.uuidString
    }
    
    var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }
    
    var totalExerciseCalories: Double {
        exerciseItems.reduce(0) { $0 + $1.caloriesBurned }
    }
    
    var netCalories: Double {
        totalCalories - totalExerciseCalories
    }
    
    var remainingCalories: Double? {
        guard let goal = dailyGoal else { return nil }
        return goal - netCalories
    }
    
    // Macro tracking computed properties
    var totalProtein: Double {
        foodItems.reduce(0) { $0 + ($1.protein ?? 0) }
    }
    
    var totalCarbohydrates: Double {
        foodItems.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }
    
    var totalFats: Double {
        foodItems.reduce(0) { $0 + ($1.fats ?? 0) }
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        foodItems: [FoodItem] = [],
        exerciseItems: [ExerciseItem] = [],
        dailyGoal: Double? = nil,
        userId: String = "",
        lastModified: Date = Date(),
        syncStatus: SyncStatus = .pendingUpload
    ) {
        self._id = id
        self.date = date
        self.foodItems = foodItems
        self.exerciseItems = exerciseItems
        self.dailyGoal = dailyGoal
        self.userId = userId
        self.lastModified = lastModified
        self.syncStatus = syncStatus
    }
}

// MARK: - SyncableEntity Conformance

extension DailyLog {
    /// Converts the daily log to a Firestore-compatible dictionary
    ///
    /// Serializes the daily log including date, goal, and references to food items.
    /// Food items are stored as a separate collection and referenced by ID.
    ///
    /// - Returns: Dictionary with all daily log data in Firestore-compatible format
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": _id.uuidString,
            "date": Timestamp(date: date),
            "totalCalories": totalCalories,
            "foodItemIds": foodItems.map { $0.id },
            "exerciseItemIds": exerciseItems.map { $0.id },
            "userId": userId,
            "lastModified": Timestamp(date: lastModified),
            "syncStatus": syncStatus.rawValue
        ]
        
        // Add optional daily goal if set
        if let dailyGoal = dailyGoal {
            data["dailyGoal"] = dailyGoal
        }
        
        return data
    }
    
    /// Creates a DailyLog instance from Firestore data
    ///
    /// Deserializes a Firestore document into a DailyLog instance.
    /// Note: Food items must be fetched separately and associated after creation.
    ///
    /// - Parameter data: Dictionary containing Firestore document data
    /// - Returns: Fully initialized DailyLog instance (without food items)
    /// - Throws: SyncError.invalidFirestoreData if required fields are missing or invalid
    static func fromFirestoreData(_ data: [String: Any]) throws -> DailyLog {
        // Extract required fields
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let date = (data["date"] as? Timestamp)?.dateValue(),
              let userId = data["userId"] as? String,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue(),
              let syncStatusRaw = data["syncStatus"] as? String,
              let syncStatus = SyncStatus(rawValue: syncStatusRaw)
        else {
            throw SyncError.invalidFirestoreData
        }
        
        // Extract optional fields
        let dailyGoal = data["dailyGoal"] as? Double
        
        // Note: foodItems will be populated separately by the sync engine
        // using the foodItemIds array from the data
        return DailyLog(
            id: id,
            date: date,
            foodItems: [],
            exerciseItems: [],
            dailyGoal: dailyGoal,
            userId: userId,
            lastModified: lastModified,
            syncStatus: syncStatus
        )
    }
}
