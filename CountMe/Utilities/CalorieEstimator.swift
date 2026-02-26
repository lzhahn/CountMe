//
//  CalorieEstimator.swift
//  CountMe
//
//  Mifflin-St Jeor based calorie estimation utility
//

import Foundation

/// Estimates daily calorie needs using the Mifflin-St Jeor equation
///
/// Provides BMR calculation, TDEE with activity multiplier, and
/// weight-loss adjusted calorie targets.
enum CalorieEstimator {
    
    /// Biological sex for BMR calculation
    enum Sex: String {
        case male
        case female
    }
    
    /// Baseline activity level with corresponding multiplier
    ///
    /// Uses Cronometer-style multipliers where the activity factor represents
    /// baseline daily activity only. Exercise calories are tracked separately
    /// via the exercise tracker, avoiding double-counting.
    enum ActivityLevel: String {
        case sedentary
        case light
        case moderate
        case very
        
        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2    // BMR + BMR×0.2 — desk job, minimal movement
            case .light: return 1.375      // BMR + BMR×0.375 — some walking, light chores
            case .moderate: return 1.5     // BMR + BMR×0.5 — on feet most of the day
            case .very: return 1.9         // BMR + BMR×0.9 — very physical job
            }
        }
    }
    
    // MARK: - Height Conversion
    
    /// Converts feet and inches to centimeters
    /// - Parameters:
    ///   - feet: Whole feet component (e.g. 5 for 5'10")
    ///   - inches: Inches component, can be fractional (e.g. 10.0 for 5'10")
    /// - Returns: Equivalent height in centimeters
    static func feetInchesToCm(feet: Int, inches: Double) -> Double {
        let totalInches = Double(feet) * 12.0 + inches
        return totalInches * 2.54
    }
    
    /// Converts centimeters to feet and inches
    /// - Parameter cm: Height in centimeters
    /// - Returns: Tuple of (feet, inches) where inches is in [0, 12)
    static func cmToFeetInches(cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12.0)
        let inches = totalInches - Double(feet) * 12.0
        return (feet, inches)
    }
    
    // MARK: - BMR
    
    /// Calculates Basal Metabolic Rate using Mifflin-St Jeor equation
    /// - Parameters:
    ///   - weightKg: Body weight in kilograms (must be > 0)
    ///   - heightCm: Height in centimeters (must be > 0)
    ///   - age: Age in years (must be > 0)
    ///   - sex: Biological sex
    /// - Returns: BMR in kcal/day, or 0 if inputs are invalid
    static func bmr(weightKg: Double, heightCm: Double, age: Int, sex: Sex) -> Double {
        guard weightKg > 0, heightCm > 0, age > 0 else { return 0 }
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age))
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }
    
    /// Calculates Total Daily Energy Expenditure (maintenance calories)
    /// - Parameters:
    ///   - weightKg: Body weight in kilograms
    ///   - heightCm: Height in centimeters
    ///   - age: Age in years
    ///   - sex: Biological sex
    ///   - activity: Baseline activity level
    /// - Returns: TDEE in kcal/day, or 0 if BMR inputs are invalid
    static func maintenance(weightKg: Double, heightCm: Double, age: Int, sex: Sex, activity: ActivityLevel) -> Double {
        let baseBmr = bmr(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
        return max(baseBmr * activity.multiplier, 0)
    }
    
    /// Calculates suggested daily calories for a weight loss goal
    /// - Parameters:
    ///   - weightKg: Body weight in kilograms
    ///   - heightCm: Height in centimeters
    ///   - age: Age in years
    ///   - sex: Biological sex
    ///   - activity: Activity level
    ///   - lossPerWeekLbs: Target weight loss in pounds per week
    /// - Returns: Suggested daily calorie intake in kcal
    static func suggestedCalories(weightKg: Double, heightCm: Double, age: Int, sex: Sex, activity: ActivityLevel, lossPerWeekLbs: Double) -> Double {
        let tdee = maintenance(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex, activity: activity)
        let dailyDeficit = max(lossPerWeekLbs, 0) * 3500.0 / 7.0
        return max(tdee - dailyDeficit, 0)
    }
}
