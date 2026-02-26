//
//  ExerciseItem.swift
//  CountMe
//
//  Created by Codex on 2/5/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class ExerciseItem: SyncableEntity {
    var _id: UUID
    var name: String
    var caloriesBurned: Double
    var durationMinutes: Double?
    var exerciseTypeRaw: String
    var intensityRaw: String
    var notes: String?
    var timestamp: Date
    
    // Relationship to DailyLog
    var dailyLog: DailyLog?
    
    // SyncableEntity properties
    var userId: String = ""
    var lastModified: Date = Date()
    var syncStatus: SyncStatus = SyncStatus.pendingUpload
    
    var id: String {
        _id.uuidString
    }
    
    var exerciseType: ExerciseType {
        ExerciseType(rawValue: exerciseTypeRaw) ?? .walking
    }
    
    var intensity: ExerciseIntensity {
        ExerciseIntensity(rawValue: intensityRaw) ?? .moderate
    }
    
    /// Public throwing initializer with validation
    init(
        id: UUID = UUID(),
        name: String,
        caloriesBurned: Double,
        durationMinutes: Double? = nil,
        exerciseType: ExerciseType = .walking,
        intensity: ExerciseIntensity = .moderate,
        notes: String? = nil,
        timestamp: Date = Date(),
        userId: String = "",
        lastModified: Date = Date(),
        syncStatus: SyncStatus = .pendingUpload
    ) throws {
        // Validate name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName(modelType: "ExerciseItem")
        }
        
        // Validate caloriesBurned
        guard caloriesBurned >= 0 else {
            throw ValidationError.negativeCalories(modelType: "ExerciseItem", value: caloriesBurned)
        }
        guard caloriesBurned <= ValidationConstants.maxCalories else {
            throw ValidationError.caloriesExceedMax(modelType: "ExerciseItem", value: caloriesBurned, max: ValidationConstants.maxCalories)
        }
        
        // Validate optional durationMinutes
        if let durationMinutes = durationMinutes {
            guard durationMinutes >= 0 else {
                throw ValidationError.negativeDuration(value: durationMinutes)
            }
            guard durationMinutes <= ValidationConstants.maxDurationMinutes else {
                throw ValidationError.durationExceedMax(value: durationMinutes, max: ValidationConstants.maxDurationMinutes)
            }
        }
        
        // Assign properties after validation
        self._id = id
        self.name = name
        self.caloriesBurned = caloriesBurned
        self.durationMinutes = durationMinutes
        self.exerciseTypeRaw = exerciseType.rawValue
        self.intensityRaw = intensity.rawValue
        self.notes = notes
        self.timestamp = timestamp
        self.userId = userId
        self.lastModified = lastModified
        self.syncStatus = syncStatus
    }
    
    /// Internal non-throwing initializer for deserialization (skips validation)
    internal init(
        validated id: UUID,
        name: String,
        caloriesBurned: Double,
        durationMinutes: Double?,
        exerciseType: ExerciseType,
        intensity: ExerciseIntensity,
        notes: String?,
        timestamp: Date,
        userId: String,
        lastModified: Date,
        syncStatus: SyncStatus
    ) {
        self._id = id
        self.name = name
        self.caloriesBurned = caloriesBurned
        self.durationMinutes = durationMinutes
        self.exerciseTypeRaw = exerciseType.rawValue
        self.intensityRaw = intensity.rawValue
        self.notes = notes
        self.timestamp = timestamp
        self.userId = userId
        self.lastModified = lastModified
        self.syncStatus = syncStatus
    }
}

// MARK: - SyncableEntity Conformance

extension ExerciseItem {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": _id.uuidString,
            "name": name,
            "caloriesBurned": caloriesBurned,
            "timestamp": Timestamp(date: timestamp),
            "exerciseType": exerciseTypeRaw,
            "intensity": intensityRaw,
            "userId": userId,
            "lastModified": Timestamp(date: lastModified),
            "syncStatus": syncStatus.rawValue
        ]
        
        if let durationMinutes = durationMinutes {
            data["durationMinutes"] = durationMinutes
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any]) throws -> ExerciseItem {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let caloriesBurned = data["caloriesBurned"] as? Double,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
              let exerciseTypeRaw = data["exerciseType"] as? String,
              let intensityRaw = data["intensity"] as? String,
              let userId = data["userId"] as? String,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue(),
              let syncStatusRaw = data["syncStatus"] as? String,
              let syncStatus = SyncStatus(rawValue: syncStatusRaw)
        else {
            throw SyncError.invalidFirestoreData
        }
        
        let durationMinutes = data["durationMinutes"] as? Double
        let notes = data["notes"] as? String
        
        // Range validation (Requirement 6.4, 6.5, 6.8)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SyncError.invalidData(reason: "ExerciseItem name is empty")
        }
        guard caloriesBurned >= 0 else {
            throw SyncError.invalidData(reason: "ExerciseItem caloriesBurned \(caloriesBurned) is negative")
        }
        guard caloriesBurned <= ValidationConstants.maxCalories else {
            throw SyncError.invalidData(reason: "ExerciseItem caloriesBurned \(caloriesBurned) exceeds maximum of \(ValidationConstants.maxCalories)")
        }
        
        // Validate optional durationMinutes
        if let durationMinutes = durationMinutes {
            guard durationMinutes >= 0 else {
                throw SyncError.invalidData(reason: "ExerciseItem durationMinutes \(durationMinutes) is negative")
            }
            guard durationMinutes <= ValidationConstants.maxDurationMinutes else {
                throw SyncError.invalidData(reason: "ExerciseItem durationMinutes \(durationMinutes) exceeds maximum of \(ValidationConstants.maxDurationMinutes)")
            }
        }
        
        // Use internal validated initializer (skips validation since we just validated)
        return ExerciseItem(
            validated: id,
            name: name,
            caloriesBurned: caloriesBurned,
            durationMinutes: durationMinutes,
            exerciseType: ExerciseType(rawValue: exerciseTypeRaw) ?? .walking,
            intensity: ExerciseIntensity(rawValue: intensityRaw) ?? .moderate,
            notes: notes,
            timestamp: timestamp,
            userId: userId,
            lastModified: lastModified,
            syncStatus: syncStatus
        )
    }
}
