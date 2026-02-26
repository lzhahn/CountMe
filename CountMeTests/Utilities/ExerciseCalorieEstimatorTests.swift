import Testing
import Foundation
@testable import CountMe

@Suite("ExerciseCalorieEstimator Tests")
struct ExerciseCalorieEstimatorTests {
    
    // MARK: - Property Tests
    
    @Test("Property: Calories increase with duration", .tags(.property))
    func testProperty_CaloriesIncreasesWithDuration() async throws {
        for _ in 0..<100 {
            let type = ExerciseType.allCases.randomElement()!
            let intensity = ExerciseIntensity.allCases.randomElement()!
            let weight = Double.random(in: 40...150)
            let duration1 = Double.random(in: 10...60)
            let duration2 = duration1 + Double.random(in: 1...30)
            
            let calories1 = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight,
                durationMinutes: duration1
            )
            
            let calories2 = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight,
                durationMinutes: duration2
            )
            
            #expect(calories2 > calories1)
        }
    }
    
    @Test("Property: Calories increase with weight", .tags(.property))
    func testProperty_CaloriesIncreasesWithWeight() async throws {
        for _ in 0..<100 {
            let type = ExerciseType.allCases.randomElement()!
            let intensity = ExerciseIntensity.allCases.randomElement()!
            let duration = Double.random(in: 10...120)
            let weight1 = Double.random(in: 40...100)
            let weight2 = weight1 + Double.random(in: 1...50)
            
            let calories1 = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight1,
                durationMinutes: duration
            )
            
            let calories2 = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight2,
                durationMinutes: duration
            )
            
            #expect(calories2 > calories1)
        }
    }
    
    @Test("Property: Calories scale linearly with duration", .tags(.property))
    func testProperty_CaloriesScaleLinearlyWithDuration() async throws {
        for _ in 0..<100 {
            let type = ExerciseType.allCases.randomElement()!
            let intensity = ExerciseIntensity.allCases.randomElement()!
            let weight = Double.random(in: 40...150)
            let duration = Double.random(in: 10...60)
            
            let calories1x = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight,
                durationMinutes: duration
            )
            
            let calories2x = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight,
                durationMinutes: duration * 2
            )
            
            // Allow 0.1% tolerance for floating point arithmetic
            let ratio = calories2x / calories1x
            #expect(abs(ratio - 2.0) < 0.001)
        }
    }
    
    @Test("Property: Formula matches MET calculation", .tags(.property))
    func testProperty_FormulaMatchesMETCalculation() async throws {
        for _ in 0..<100 {
            let type = ExerciseType.allCases.randomElement()!
            let intensity = ExerciseIntensity.allCases.randomElement()!
            let weight = Double.random(in: 40...150)
            let duration = Double.random(in: 10...120)
            
            let calculatedCalories = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: intensity,
                weightKg: weight,
                durationMinutes: duration
            )
            
            let met = ExerciseCalorieEstimator.metValue(for: type, intensity: intensity)
            let expectedCalories = met * weight * (duration / 60.0)
            
            // Allow small floating point tolerance
            #expect(abs(calculatedCalories - expectedCalories) < 0.001)
        }
    }
    
    @Test("Property: Higher intensity burns more calories", .tags(.property))
    func testProperty_HigherIntensityBurnsMore() async throws {
        for _ in 0..<100 {
            let type = ExerciseType.allCases.randomElement()!
            let weight = Double.random(in: 40...150)
            let duration = Double.random(in: 10...120)
            
            let light = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: .light,
                weightKg: weight,
                durationMinutes: duration
            )
            
            let moderate = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: .moderate,
                weightKg: weight,
                durationMinutes: duration
            )
            
            let vigorous = ExerciseCalorieEstimator.calories(
                for: type,
                intensity: .vigorous,
                weightKg: weight,
                durationMinutes: duration
            )
            
            #expect(moderate > light)
            #expect(vigorous > moderate)
        }
    }
    
    // MARK: - Unit Tests
    
    @Test("Running 30 min at moderate intensity for 70kg person")
    func testRunning_ModerateIntensity_70kg() async throws {
        let calories = ExerciseCalorieEstimator.calories(
            for: .running,
            intensity: .moderate,
            weightKg: 70,
            durationMinutes: 30
        )
        
        // MET 7.0 * 70kg * 0.5 hours = 245 calories
        #expect(abs(calories - 245) < 1.0)
    }
    
    @Test("Running 59 min at vigorous intensity for 80kg person")
    func testRunning_VigorousIntensity_80kg() async throws {
        let calories = ExerciseCalorieEstimator.calories(
            for: .running,
            intensity: .vigorous,
            weightKg: 80,
            durationMinutes: 59
        )
        
        // MET 8.5 * 80kg * (59/60) hours ≈ 669 calories
        #expect(abs(calories - 669) < 1.0)
    }
    
    @Test("Walking 60 min at light intensity for 60kg person")
    func testWalking_LightIntensity_60kg() async throws {
        let calories = ExerciseCalorieEstimator.calories(
            for: .walking,
            intensity: .light,
            weightKg: 60,
            durationMinutes: 60
        )
        
        // MET 2.8 * 60kg * 1 hour = 168 calories
        #expect(abs(calories - 168) < 1.0)
    }
    
    @Test("Zero duration returns zero calories")
    func testZeroDuration_ReturnsZero() async throws {
        let calories = ExerciseCalorieEstimator.calories(
            for: .running,
            intensity: .vigorous,
            weightKg: 70,
            durationMinutes: 0
        )
        
        #expect(calories == 0)
    }
    
    @Test("MET values are positive for all exercise types")
    func testMETValues_AllPositive() async throws {
        for type in ExerciseType.allCases {
            for intensity in ExerciseIntensity.allCases {
                let met = ExerciseCalorieEstimator.metValue(for: type, intensity: intensity)
                #expect(met > 0)
            }
        }
    }
    
    @Test("MET values are reasonable (between 2 and 12)")
    func testMETValues_ReasonableRange() async throws {
        for type in ExerciseType.allCases {
            for intensity in ExerciseIntensity.allCases {
                let met = ExerciseCalorieEstimator.metValue(for: type, intensity: intensity)
                #expect(met >= 2.0)
                #expect(met <= 12.0)
            }
        }
    }
}
