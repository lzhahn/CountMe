//
//  ExerciseCatalog.swift
//  CountMe
//
//  Exercise type and intensity catalog with MET values
//

import Foundation

enum ExerciseType: String, CaseIterable, Identifiable {
    case walking
    case running
    case cycling
    case strengthTraining
    case yoga
    case swimming
    case rowing
    case elliptical
    case hiit
    case hiking
    case sports
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .strengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .hiit: return "HIIT"
        case .hiking: return "Hiking"
        case .sports: return "Sports"
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .strengthTraining: return "dumbbell"
        case .yoga: return "figure.yoga"
        case .swimming: return "figure.pool.swim"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .hiit: return "bolt"
        case .hiking: return "figure.hiking"
        case .sports: return "sportscourt"
        }
    }
}

enum ExerciseIntensity: String, CaseIterable, Identifiable {
    case light
    case moderate
    case vigorous
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .vigorous: return "Vigorous"
        }
    }
}

struct ExerciseCalorieEstimator {
    /// Estimates calories burned using MET values
    /// Formula: calories = MET * weight(kg) * duration(hours)
    ///
    /// - Parameters:
    ///   - type: The type of exercise being performed
    ///   - intensity: The intensity level (light, moderate, vigorous)
    ///   - weightKg: User's body weight in kilograms
    ///   - durationMinutes: Duration of exercise in minutes
    /// - Returns: Estimated calories burned
    static func calories(
        for type: ExerciseType,
        intensity: ExerciseIntensity,
        weightKg: Double,
        durationMinutes: Double
    ) -> Double {
        let met = metValue(for: type, intensity: intensity)
        let hours = durationMinutes / 60.0
        return met * weightKg * hours
    }
    
    /// Returns the MET (Metabolic Equivalent of Task) value for a given exercise type and intensity
    ///
    /// MET values represent the energy cost of physical activities as multiples of resting metabolic rate.
    /// Values are calibrated to match real-world calorie burn rates from validated sources like Cronometer.
    ///
    /// - Parameters:
    ///   - type: The type of exercise
    ///   - intensity: The intensity level
    /// - Returns: MET value (typically 2.0-12.0)
    ///
    /// Example MET values:
    /// - Light running (4-5 mph): 6.0
    /// - Moderate running (5-6 mph): 7.0
    /// - Vigorous running (6.5+ mph): 8.5
    static func metValue(for type: ExerciseType, intensity: ExerciseIntensity) -> Double {
        switch type {
        case .walking:
            return intensity == .light ? 2.8 : (intensity == .moderate ? 3.8 : 5.0)
        case .running:
            // Light: jogging ~4-5 mph, Moderate: ~5-6 mph, Vigorous: ~6.5+ mph
            return intensity == .light ? 6.0 : (intensity == .moderate ? 7.0 : 8.5)
        case .cycling:
            return intensity == .light ? 4.0 : (intensity == .moderate ? 6.8 : 10.0)
        case .strengthTraining:
            return intensity == .light ? 3.0 : (intensity == .moderate ? 5.0 : 6.0)
        case .yoga:
            return intensity == .light ? 2.0 : (intensity == .moderate ? 3.0 : 4.0)
        case .swimming:
            return intensity == .light ? 5.8 : (intensity == .moderate ? 7.0 : 9.5)
        case .rowing:
            return intensity == .light ? 4.8 : (intensity == .moderate ? 7.0 : 8.5)
        case .elliptical:
            return intensity == .light ? 4.8 : (intensity == .moderate ? 6.0 : 7.5)
        case .hiit:
            return intensity == .light ? 6.0 : (intensity == .moderate ? 8.0 : 10.0)
        case .hiking:
            return intensity == .light ? 5.0 : (intensity == .moderate ? 6.5 : 8.0)
        case .sports:
            return intensity == .light ? 4.0 : (intensity == .moderate ? 6.0 : 8.0)
        }
    }
}
