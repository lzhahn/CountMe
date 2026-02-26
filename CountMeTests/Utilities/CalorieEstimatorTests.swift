//
//  CalorieEstimatorTests.swift
//  CountMeTests
//
//  Unit and property-based tests for Mifflin-St Jeor calorie estimation
//

import Testing
@testable import CountMe

struct CalorieEstimatorTests {
    
    // MARK: - Unit Tests: Height Conversion
    
    @Test("5 ft 10 in converts to 177.8 cm")
    func testFeetInchesToCm_5ft10in_Returns177_8() {
        let cm = CalorieEstimator.feetInchesToCm(feet: 5, inches: 10)
        #expect(abs(cm - 177.8) < 0.01)
    }
    
    @Test("170 cm converts to 5 ft 6.9 in")
    func testCmToFeetInches_170cm_Returns5ft6_9in() {
        let (feet, inches) = CalorieEstimator.cmToFeetInches(cm: 170)
        #expect(feet == 5)
        #expect(abs(inches - 6.929) < 0.01)
    }
    
    @Test("0 cm converts to 0 ft 0 in")
    func testCmToFeetInches_Zero_ReturnsZero() {
        let (feet, inches) = CalorieEstimator.cmToFeetInches(cm: 0)
        #expect(feet == 0)
        #expect(inches == 0)
    }
    
    // MARK: - Property Tests: Height Conversion
    
    @Test("Property: cm → ft/in → cm roundtrip preserves value",
          .tags(.property, .calorieEstimation))
    func testProperty_HeightConversion_1() {
        for _ in 0..<100 {
            let originalCm = Double.random(in: 50...250)
            let (feet, inches) = CalorieEstimator.cmToFeetInches(cm: originalCm)
            let roundtrippedCm = CalorieEstimator.feetInchesToCm(feet: feet, inches: inches)
            #expect(abs(roundtrippedCm - originalCm) < 0.001)
        }
    }
    
    @Test("Property: ft/in → cm → ft/in roundtrip preserves value",
          .tags(.property, .calorieEstimation))
    func testProperty_HeightConversion_2() {
        for _ in 0..<100 {
            let originalFeet = Int.random(in: 1...7)
            let originalInches = Double.random(in: 0..<12)
            let cm = CalorieEstimator.feetInchesToCm(feet: originalFeet, inches: originalInches)
            let (feet, inches) = CalorieEstimator.cmToFeetInches(cm: cm)
            #expect(feet == originalFeet)
            #expect(abs(inches - originalInches) < 0.001)
        }
    }
    
    @Test("Property: inches component is always in [0, 12)",
          .tags(.property, .calorieEstimation))
    func testProperty_HeightConversion_3() {
        for _ in 0..<100 {
            let cm = Double.random(in: 1...300)
            let (_, inches) = CalorieEstimator.cmToFeetInches(cm: cm)
            #expect(inches >= 0)
            #expect(inches < 12)
        }
    }
    
    // MARK: - Unit Tests: BMR
    
    @Test("BMR for known male values matches Mifflin-St Jeor")
    func testBMR_KnownMaleValues_MatchesExpected() {
        // 80 kg, 175 cm, 30 years, male
        // Expected: (10*80) + (6.25*175) - (5*30) + 5 = 800 + 1093.75 - 150 + 5 = 1748.75
        let result = CalorieEstimator.bmr(weightKg: 80, heightCm: 175, age: 30, sex: .male)
        #expect(result == 1748.75)
    }
    
    @Test("BMR for known female values matches Mifflin-St Jeor")
    func testBMR_KnownFemaleValues_MatchesExpected() {
        // 65 kg, 165 cm, 25 years, female
        // Expected: (10*65) + (6.25*165) - (5*25) - 161 = 650 + 1031.25 - 125 - 161 = 1395.25
        let result = CalorieEstimator.bmr(weightKg: 65, heightCm: 165, age: 25, sex: .female)
        #expect(result == 1395.25)
    }
    
    @Test("BMR returns 0 for invalid inputs")
    func testBMR_InvalidInputs_ReturnsZero() {
        #expect(CalorieEstimator.bmr(weightKg: 0, heightCm: 175, age: 30, sex: .male) == 0)
        #expect(CalorieEstimator.bmr(weightKg: 80, heightCm: 0, age: 30, sex: .male) == 0)
        #expect(CalorieEstimator.bmr(weightKg: 80, heightCm: 175, age: 0, sex: .male) == 0)
        #expect(CalorieEstimator.bmr(weightKg: -10, heightCm: 175, age: 30, sex: .male) == 0)
    }
    
    // MARK: - Unit Tests: Maintenance
    
    @Test("Maintenance equals BMR times activity multiplier")
    func testMaintenance_ModerateActivity_CorrectMultiplier() {
        let bmr = CalorieEstimator.bmr(weightKg: 80, heightCm: 175, age: 30, sex: .male)
        let maintenance = CalorieEstimator.maintenance(weightKg: 80, heightCm: 175, age: 30, sex: .male, activity: .moderate)
        #expect(maintenance == bmr * 1.5)
    }
    
    // MARK: - Unit Tests: Suggested Calories
    
    @Test("Suggested calories subtracts correct deficit")
    func testSuggestedCalories_1_5LbPerWeek_CorrectDeficit() {
        let maintenance = CalorieEstimator.maintenance(weightKg: 80, heightCm: 175, age: 30, sex: .male, activity: .moderate)
        let suggested = CalorieEstimator.suggestedCalories(weightKg: 80, heightCm: 175, age: 30, sex: .male, activity: .moderate, lossPerWeekLbs: 1.5)
        let expectedDeficit = 1.5 * 3500.0 / 7.0 // 750
        #expect(suggested == maintenance - expectedDeficit)
    }
    
    @Test("Suggested calories never goes negative")
    func testSuggestedCalories_ExtremeDeficit_FloorsAtZero() {
        // Very small person with huge loss target
        let result = CalorieEstimator.suggestedCalories(weightKg: 40, heightCm: 150, age: 70, sex: .female, activity: .sedentary, lossPerWeekLbs: 10)
        #expect(result >= 0)
    }
    
    @Test("Suggested calories with zero loss equals maintenance")
    func testSuggestedCalories_ZeroLoss_EqualsMaintenance() {
        let maintenance = CalorieEstimator.maintenance(weightKg: 80, heightCm: 175, age: 30, sex: .male, activity: .moderate)
        let suggested = CalorieEstimator.suggestedCalories(weightKg: 80, heightCm: 175, age: 30, sex: .male, activity: .moderate, lossPerWeekLbs: 0)
        #expect(suggested == maintenance)
    }
    
    // MARK: - Property Tests
    
    @Test("Property: Male BMR always higher than female BMR for same inputs",
          .tags(.property, .calorieEstimation))
    func testProperty_CalorieEstimation_1() {
        for _ in 0..<100 {
            let weight = Double.random(in: 40...150)
            let height = Double.random(in: 140...210)
            let age = Int.random(in: 18...80)
            
            let maleBMR = CalorieEstimator.bmr(weightKg: weight, heightCm: height, age: age, sex: .male)
            let femaleBMR = CalorieEstimator.bmr(weightKg: weight, heightCm: height, age: age, sex: .female)
            
            // Male formula adds +5, female subtracts -161, so male is always 166 higher
            #expect(maleBMR - femaleBMR == 166)
        }
    }
    
    @Test("Property: Higher activity level always produces higher maintenance",
          .tags(.property, .calorieEstimation))
    func testProperty_CalorieEstimation_2() {
        let levels: [CalorieEstimator.ActivityLevel] = [.sedentary, .light, .moderate, .very]
        
        for _ in 0..<100 {
            let weight = Double.random(in: 40...150)
            let height = Double.random(in: 140...210)
            let age = Int.random(in: 18...80)
            let sex: CalorieEstimator.Sex = Bool.random() ? .male : .female
            
            for i in 0..<(levels.count - 1) {
                let lower = CalorieEstimator.maintenance(weightKg: weight, heightCm: height, age: age, sex: sex, activity: levels[i])
                let higher = CalorieEstimator.maintenance(weightKg: weight, heightCm: height, age: age, sex: sex, activity: levels[i + 1])
                #expect(higher > lower)
            }
        }
    }
    
    @Test("Property: Maintenance is always >= BMR for valid inputs",
          .tags(.property, .calorieEstimation))
    func testProperty_CalorieEstimation_3() {
        let allActivities: [CalorieEstimator.ActivityLevel] = [.sedentary, .light, .moderate, .very]
        
        for _ in 0..<100 {
            let weight = Double.random(in: 40...150)
            let height = Double.random(in: 140...210)
            let age = Int.random(in: 18...80)
            let sex: CalorieEstimator.Sex = Bool.random() ? .male : .female
            let activity = allActivities.randomElement()!
            
            let baseBmr = CalorieEstimator.bmr(weightKg: weight, heightCm: height, age: age, sex: sex)
            let tdee = CalorieEstimator.maintenance(weightKg: weight, heightCm: height, age: age, sex: sex, activity: activity)
            
            // All multipliers are >= 1.2, so TDEE >= BMR
            #expect(tdee >= baseBmr)
        }
    }
    
    @Test("Property: Suggested calories decreases as loss rate increases",
          .tags(.property, .calorieEstimation))
    func testProperty_CalorieEstimation_4() {
        for _ in 0..<100 {
            let weight = Double.random(in: 50...120)
            let height = Double.random(in: 150...200)
            let age = Int.random(in: 18...60)
            let sex: CalorieEstimator.Sex = Bool.random() ? .male : .female
            
            let lossA = Double.random(in: 0...1.5)
            let lossB = lossA + Double.random(in: 0.1...2.0)
            
            let suggestedA = CalorieEstimator.suggestedCalories(weightKg: weight, heightCm: height, age: age, sex: sex, activity: .moderate, lossPerWeekLbs: lossA)
            let suggestedB = CalorieEstimator.suggestedCalories(weightKg: weight, heightCm: height, age: age, sex: sex, activity: .moderate, lossPerWeekLbs: lossB)
            
            #expect(suggestedA >= suggestedB)
        }
    }
    
    @Test("Property: BMR increases with weight for same height/age/sex",
          .tags(.property, .calorieEstimation))
    func testProperty_CalorieEstimation_5() {
        for _ in 0..<100 {
            let height = Double.random(in: 140...210)
            let age = Int.random(in: 18...80)
            let sex: CalorieEstimator.Sex = Bool.random() ? .male : .female
            
            let weightA = Double.random(in: 40...100)
            let weightB = weightA + Double.random(in: 0.1...50)
            
            let bmrA = CalorieEstimator.bmr(weightKg: weightA, heightCm: height, age: age, sex: sex)
            let bmrB = CalorieEstimator.bmr(weightKg: weightB, heightCm: height, age: age, sex: sex)
            
            #expect(bmrB > bmrA)
        }
    }
    
    @Test("Property: BMR decreases with age for same weight/height/sex",
          .tags(.property, .calorieEstimation))
    func testProperty_CalorieEstimation_6() {
        for _ in 0..<100 {
            let weight = Double.random(in: 40...150)
            let height = Double.random(in: 140...210)
            let sex: CalorieEstimator.Sex = Bool.random() ? .male : .female
            
            let ageA = Int.random(in: 18...50)
            let ageB = ageA + Int.random(in: 1...30)
            
            let bmrA = CalorieEstimator.bmr(weightKg: weight, heightCm: height, age: ageA, sex: sex)
            let bmrB = CalorieEstimator.bmr(weightKg: weight, heightCm: height, age: ageB, sex: sex)
            
            #expect(bmrA > bmrB)
        }
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var property: Self
    @Tag static var calorieEstimation: Self
    @Tag static var calorieTracking: Self
    @Tag static var nutritionAPI: Self
    @Tag static var manualIngredientEntry: Self
}
