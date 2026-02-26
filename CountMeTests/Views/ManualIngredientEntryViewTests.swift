//
//  ManualIngredientEntryViewTests.swift
//  CountMeTests
//
//  Tests for ManualIngredientEntryView and EditableIngredient validation logic
//

import Testing
import SwiftData
import Foundation
@testable import CountMe

// MARK: - Test Tags
// Note: Tag extensions are defined in CalorieEstimatorTests.swift to avoid duplicates

/// Tests for the manual ingredient entry flow used when creating custom meals
///
/// Validates:
/// - EditableIngredient validation (name, quantity, calories, macros)
/// - EditableIngredient to Ingredient conversion
/// - Saving custom meals via manual entry path through CustomMealManager
/// - Property: valid EditableIngredient always converts to non-nil Ingredient
/// - Property: invalid EditableIngredient never converts to non-nil Ingredient
///
/// Validates Requirements: 1.3, 1.5, 2.3, 9.1, 9.2
@MainActor
struct ManualIngredientEntryViewTests {

    // MARK: - Test Helpers

    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
    }

    private func createTestManager(container: ModelContainer) -> CustomMealManager {
        let dataStore = DataStore(modelContext: container.mainContext)
        let aiParser = AIRecipeParser()
        return CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    }

    // MARK: - EditableIngredient Validation Tests

    @Test("EditableIngredient with valid data is valid")
    func testEditableIngredient_ValidData_IsValid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Chicken Breast"
        ingredient.quantity = 6
        ingredient.unit = "oz"
        ingredient.calories = 187
        ingredient.protein = 35
        ingredient.carbohydrates = 0
        ingredient.fats = 4

        #expect(ingredient.isValid == true)
    }

    @Test("EditableIngredient with empty name is invalid")
    func testEditableIngredient_EmptyName_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = ""
        ingredient.quantity = 1
        ingredient.calories = 100

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with whitespace-only name is invalid")
    func testEditableIngredient_WhitespaceName_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "   "
        ingredient.quantity = 1
        ingredient.calories = 100

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with nil quantity is invalid")
    func testEditableIngredient_NilQuantity_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = nil
        ingredient.calories = 200

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with zero quantity is invalid")
    func testEditableIngredient_ZeroQuantity_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 0
        ingredient.calories = 200

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with negative quantity is invalid")
    func testEditableIngredient_NegativeQuantity_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = -1
        ingredient.calories = 200

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with nil calories is invalid")
    func testEditableIngredient_NilCalories_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 1
        ingredient.calories = nil

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with negative calories is invalid")
    func testEditableIngredient_NegativeCalories_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 1
        ingredient.calories = -50

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with zero calories is valid (spices, extracts)")
    func testEditableIngredient_ZeroCalories_IsValid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Cinnamon"
        ingredient.quantity = 1
        ingredient.unit = "tsp"
        ingredient.calories = 0

        #expect(ingredient.isValid == true)
    }

    @Test("EditableIngredient with negative protein is invalid")
    func testEditableIngredient_NegativeProtein_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 1
        ingredient.calories = 200
        ingredient.protein = -5

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with negative carbs is invalid")
    func testEditableIngredient_NegativeCarbs_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 1
        ingredient.calories = 200
        ingredient.carbohydrates = -10

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with negative fats is invalid")
    func testEditableIngredient_NegativeFats_IsInvalid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 1
        ingredient.calories = 200
        ingredient.fats = -3

        #expect(ingredient.isValid == false)
    }

    @Test("EditableIngredient with nil macros is valid")
    func testEditableIngredient_NilMacros_IsValid() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Mystery Food"
        ingredient.quantity = 1
        ingredient.calories = 150
        ingredient.protein = nil
        ingredient.carbohydrates = nil
        ingredient.fats = nil

        #expect(ingredient.isValid == true)
    }

    // MARK: - EditableIngredient isEmpty Tests

    @Test("Default EditableIngredient is empty")
    func testEditableIngredient_Default_IsEmpty() async throws {
        let ingredient = EditableIngredient()
        #expect(ingredient.isEmpty == true)
    }

    @Test("EditableIngredient with only name is not empty")
    func testEditableIngredient_WithName_IsNotEmpty() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Apple"
        #expect(ingredient.isEmpty == false)
    }

    @Test("EditableIngredient with only calories is not empty")
    func testEditableIngredient_WithCalories_IsNotEmpty() async throws {
        var ingredient = EditableIngredient()
        ingredient.calories = 100
        #expect(ingredient.isEmpty == false)
    }

    @Test("Fully valid EditableIngredient is not empty")
    func testEditableIngredient_Valid_IsNotEmpty() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Rice"
        ingredient.quantity = 1
        ingredient.calories = 200
        #expect(ingredient.isEmpty == false)
        #expect(ingredient.isValid == true)
    }

    // MARK: - EditableIngredient Conversion Tests

    @Test("Valid EditableIngredient converts to Ingredient")
    func testEditableIngredient_Valid_ConvertsToIngredient() async throws {
        var ingredient = EditableIngredient()
        ingredient.name = "Salmon"
        ingredient.quantity = 4
        ingredient.unit = "oz"
        ingredient.calories = 233
        ingredient.protein = 25
        ingredient.carbohydrates = 0
        ingredient.fats = 14

        let converted = ingredient.toIngredient()
        #expect(converted != nil)
        #expect(converted?.name == "Salmon")
        #expect(converted?.quantity == 4)
        #expect(converted?.unit == "oz")
        #expect(converted?.calories == 233)
        #expect(converted?.protein == 25)
        #expect(converted?.carbohydrates == 0)
        #expect(converted?.fats == 14)
    }

    @Test("Invalid EditableIngredient returns nil on conversion")
    func testEditableIngredient_Invalid_ReturnsNilOnConversion() async throws {
        let ingredient = EditableIngredient() // empty, invalid
        let converted = ingredient.toIngredient()
        #expect(converted == nil)
    }

    // MARK: - EditableIngredient from NutritionSearchResult Tests

    @Test("EditableIngredient from NutritionSearchResult maps all fields")
    func testEditableIngredient_FromSearchResult_MapsAllFields() async throws {
        let result = NutritionSearchResult(
            id: "123",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31,
            carbohydrates: 0,
            fats: 3.6
        )

        let ingredient = EditableIngredient(from: result)

        #expect(ingredient.name == "Chicken Breast")
        #expect(ingredient.quantity == 100)
        #expect(ingredient.unit == "g")
        #expect(ingredient.calories == 165)
        #expect(ingredient.protein == 31)
        #expect(ingredient.carbohydrates == 0)
        #expect(ingredient.fats == 3.6)
        #expect(ingredient.isValid == true)
    }

    @Test("EditableIngredient from NutritionSearchResult with nil serving defaults to 1 serving")
    func testEditableIngredient_FromSearchResult_NilServingDefaults() async throws {
        let result = NutritionSearchResult(
            id: "456",
            name: "Mystery Food",
            calories: 200,
            servingSize: nil,
            servingUnit: nil,
            brandName: nil,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )

        let ingredient = EditableIngredient(from: result)

        #expect(ingredient.name == "Mystery Food")
        #expect(ingredient.quantity == 1)
        #expect(ingredient.unit == "serving")
        #expect(ingredient.calories == 200)
        #expect(ingredient.protein == nil)
        #expect(ingredient.carbohydrates == nil)
        #expect(ingredient.fats == nil)
        #expect(ingredient.isValid == true)
    }

    @Test("EditableIngredient from NutritionSearchResult with non-numeric serving defaults to 1")
    func testEditableIngredient_FromSearchResult_NonNumericServing() async throws {
        let result = NutritionSearchResult(
            id: "789",
            name: "Salad",
            calories: 50,
            servingSize: "1 cup",
            servingUnit: "cup",
            brandName: nil,
            protein: 3,
            carbohydrates: 8,
            fats: 0.5
        )

        let ingredient = EditableIngredient(from: result)

        // "1 cup" can't be parsed as Double, so defaults to 1
        #expect(ingredient.quantity == 1)
        #expect(ingredient.unit == "cup")
        #expect(ingredient.isValid == true)
    }

    @Test("Property: NutritionSearchResult to EditableIngredient always produces valid ingredient",
          .tags(.property, .manualIngredientEntry))
    func testProperty_SearchResultToEditableIngredient_AlwaysValid() async throws {
        for _ in 0..<100 {
            let calories = Double.random(in: 0...2000)
            let result = NutritionSearchResult(
                id: UUID().uuidString,
                name: "Food \(UUID().uuidString.prefix(8))",
                calories: calories,
                servingSize: Bool.random() ? String(Int.random(in: 1...500)) : nil,
                servingUnit: Bool.random() ? ["g", "oz", "cup", "ml"].randomElement()! : nil,
                brandName: nil,
                protein: Bool.random() ? Double.random(in: 0...100) : nil,
                carbohydrates: Bool.random() ? Double.random(in: 0...300) : nil,
                fats: Bool.random() ? Double.random(in: 0...100) : nil
            )

            let ingredient = EditableIngredient(from: result)

            #expect(ingredient.isValid == true)
            #expect(ingredient.name == result.name)
            #expect(ingredient.calories == result.calories)

            let converted = ingredient.toIngredient()
            #expect(converted != nil)
        }
    }

    // MARK: - Manual Save Flow Tests

    @Test("Manual entry saves custom meal with ingredients via CustomMealManager")
    func testManualEntry_SavesMealWithIngredients() async throws {
        let container = try createTestContainer()
        let manager = createTestManager(container: container)

        let ingredients = [
            try! Ingredient(name: "Chicken", quantity: 6, unit: "oz", calories: 187, protein: 35, carbohydrates: 0, fats: 4),
            try! Ingredient(name: "Rice", quantity: 1, unit: "cup", calories: 206, protein: 4, carbohydrates: 45, fats: 0.4)
        ]

        let meal = try await manager.saveCustomMeal(
            name: "Chicken and Rice",
            ingredients: ingredients,
            servingsCount: 1.0
        )

        #expect(meal.name == "Chicken and Rice")
        #expect(meal.ingredients.count == 2)
        #expect(meal.servingsCount == 1.0)
        #expect(meal.totalCalories == 393)
    }

    @Test("Manual entry saves custom meal with multiple servings")
    func testManualEntry_SavesMealWithMultipleServings() async throws {
        let container = try createTestContainer()
        let manager = createTestManager(container: container)

        let ingredients = [
            try! Ingredient(name: "Pasta", quantity: 2, unit: "cups", calories: 400, protein: 14, carbohydrates: 80, fats: 2)
        ]

        let meal = try await manager.saveCustomMeal(
            name: "Big Pasta",
            ingredients: ingredients,
            servingsCount: 4.0
        )

        #expect(meal.servingsCount == 4.0)
        #expect(meal.totalCalories == 400)
    }

    // MARK: - Property Tests

    @Test("Property: valid EditableIngredient always converts to non-nil Ingredient",
          .tags(.property, .manualIngredientEntry))
    func testProperty_ValidEditableIngredient_AlwaysConverts() async throws {
        for _ in 0..<100 {
            var ingredient = EditableIngredient()
            ingredient.name = "Food \(UUID().uuidString.prefix(8))"
            ingredient.quantity = Double.random(in: 0.1...100)
            ingredient.unit = ["g", "oz", "cup", "tbsp", "serving"].randomElement()!
            ingredient.calories = Double.random(in: 0...2000)
            ingredient.protein = Bool.random() ? Double.random(in: 0...100) : nil
            ingredient.carbohydrates = Bool.random() ? Double.random(in: 0...300) : nil
            ingredient.fats = Bool.random() ? Double.random(in: 0...100) : nil

            #expect(ingredient.isValid == true)
            let converted = ingredient.toIngredient()
            #expect(converted != nil)
            #expect(converted?.name == ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines))
            #expect(converted?.calories == ingredient.calories)
        }
    }

    @Test("Property: invalid EditableIngredient never converts to non-nil Ingredient",
          .tags(.property, .manualIngredientEntry))
    func testProperty_InvalidEditableIngredient_NeverConverts() async throws {
        for _ in 0..<100 {
            var ingredient = EditableIngredient()

            // Randomly make it invalid in one of several ways
            let invalidationType = Int.random(in: 0...4)
            switch invalidationType {
            case 0:
                // Empty name
                ingredient.name = ""
                ingredient.quantity = Double.random(in: 0.1...10)
                ingredient.calories = Double.random(in: 0...500)
            case 1:
                // Nil quantity
                ingredient.name = "Food"
                ingredient.quantity = nil
                ingredient.calories = Double.random(in: 0...500)
            case 2:
                // Zero quantity
                ingredient.name = "Food"
                ingredient.quantity = 0
                ingredient.calories = Double.random(in: 0...500)
            case 3:
                // Negative calories
                ingredient.name = "Food"
                ingredient.quantity = Double.random(in: 0.1...10)
                ingredient.calories = -Double.random(in: 0.1...500)
            case 4:
                // Negative macro
                ingredient.name = "Food"
                ingredient.quantity = Double.random(in: 0.1...10)
                ingredient.calories = Double.random(in: 0...500)
                ingredient.protein = -Double.random(in: 0.1...50)
            default:
                break
            }

            #expect(ingredient.isValid == false)
            #expect(ingredient.toIngredient() == nil)
        }
    }
}
