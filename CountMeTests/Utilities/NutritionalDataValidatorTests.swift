//
//  NutritionalDataValidatorTests.swift
//  CountMeTests
//
//  Created by Kiro on 1/23/26.
//

import Testing
@testable import CountMe

/// Unit tests for NutritionalDataValidator
///
/// Tests validation logic for nutritional values, serving sizes, and required fields
/// across FoodItems, Ingredients, and manual entries.
struct NutritionalDataValidatorTests {
    
    // MARK: - Nutritional Value Validation Tests
    
    @Test("Valid nutritional values should pass validation")
    func testValidNutritionalValues() throws {
        // Positive values should be valid
        try NutritionalDataValidator.validateNutritionalValue(250.0, fieldName: "Calories")
        try NutritionalDataValidator.validateNutritionalValue(35.0, fieldName: "Protein")
        try NutritionalDataValidator.validateNutritionalValue(0.0, fieldName: "Carbohydrates")
        
        // Nil values should be valid (optional fields)
        try NutritionalDataValidator.validateNutritionalValue(nil, fieldName: "Fats")
    }
    
    @Test("Negative nutritional values should fail validation")
    func testNegativeNutritionalValues() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateNutritionalValue(-10.0, fieldName: "Calories")
        }
        
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateNutritionalValue(-5.0, fieldName: "Protein")
        }
    }
    
    @Test("Validation error messages should be field-specific")
    func testValidationErrorMessages() {
        do {
            try NutritionalDataValidator.validateNutritionalValue(-10.0, fieldName: "Calories")
            Issue.record("Expected validation error")
        } catch let error as ValidationError {
            let message = error.errorDescription ?? ""
            #expect(message.contains("Calories"))
            #expect(message.contains("-10"))
        } catch {
            Issue.record("Expected ValidationError")
        }
    }
    
    // MARK: - Serving Size Validation Tests
    
    @Test("Positive serving sizes should pass validation")
    func testValidServingSizes() throws {
        try NutritionalDataValidator.validateServingSize(1.0, fieldName: "Serving Multiplier")
        try NutritionalDataValidator.validateServingSize(0.5, fieldName: "Quantity")
        try NutritionalDataValidator.validateServingSize(2.5, fieldName: "Serving Size")
    }
    
    @Test("Zero serving size should fail validation")
    func testZeroServingSize() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateServingSize(0.0, fieldName: "Quantity")
        }
    }
    
    @Test("Negative serving size should fail validation")
    func testNegativeServingSize() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateServingSize(-2.0, fieldName: "Serving Multiplier")
        }
    }
    
    // MARK: - Required Fields Validation Tests
    
    @Test("Valid ingredient fields should pass validation")
    func testValidRequiredFields() throws {
        try NutritionalDataValidator.validateRequiredIngredientFields(
            name: "chicken breast",
            calories: 187.0
        )
        
        try NutritionalDataValidator.validateRequiredIngredientFields(
            name: "rice",
            calories: 0.0  // Zero calories is valid
        )
    }
    
    @Test("Empty ingredient name should fail validation")
    func testEmptyIngredientName() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateRequiredIngredientFields(
                name: "",
                calories: 100.0
            )
        }
        
        // Whitespace-only name should also fail
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateRequiredIngredientFields(
                name: "   ",
                calories: 100.0
            )
        }
    }
    
    @Test("Negative calories in required fields should fail validation")
    func testNegativeCaloriesInRequiredFields() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateRequiredIngredientFields(
                name: "rice",
                calories: -50.0
            )
        }
    }
    
    // MARK: - Comprehensive Validation Tests
    
    @Test("Valid complete nutritional data should pass validation")
    func testValidCompleteNutritionalData() throws {
        try NutritionalDataValidator.validateAllNutritionalValues(
            calories: 250.0,
            protein: 35.0,
            carbohydrates: 0.0,
            fats: 4.0
        )
        
        // Optional macros can be nil
        try NutritionalDataValidator.validateAllNutritionalValues(
            calories: 250.0,
            protein: nil,
            carbohydrates: nil,
            fats: nil
        )
    }
    
    @Test("Negative protein should fail comprehensive validation")
    func testNegativeProteinInComprehensiveValidation() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateAllNutritionalValues(
                calories: 250.0,
                protein: -5.0,
                carbohydrates: 0.0,
                fats: 4.0
            )
        }
    }
    
    @Test("Negative carbohydrates should fail comprehensive validation")
    func testNegativeCarbohydratesInComprehensiveValidation() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateAllNutritionalValues(
                calories: 250.0,
                protein: 35.0,
                carbohydrates: -10.0,
                fats: 4.0
            )
        }
    }
    
    @Test("Negative fats should fail comprehensive validation")
    func testNegativeFatsInComprehensiveValidation() {
        #expect(throws: ValidationError.self) {
            try NutritionalDataValidator.validateAllNutritionalValues(
                calories: 250.0,
                protein: 35.0,
                carbohydrates: 0.0,
                fats: -2.0
            )
        }
    }
    
    // MARK: - Validation Rule Consistency Tests
    
    @Test("Same validation rules apply to all nutritional values")
    func testValidationRuleConsistency() {
        // All negative values should be rejected consistently
        let fields = ["Calories", "Protein", "Carbohydrates", "Fats"]
        
        for field in fields {
            #expect(throws: ValidationError.self) {
                try NutritionalDataValidator.validateNutritionalValue(-1.0, fieldName: field)
            }
        }
        
        // All zero values should be accepted consistently
        for field in fields {
            try? NutritionalDataValidator.validateNutritionalValue(0.0, fieldName: field)
        }
        
        // All nil values should be accepted consistently
        for field in fields {
            try? NutritionalDataValidator.validateNutritionalValue(nil, fieldName: field)
        }
    }
    
    @Test("Validation errors provide actionable messages")
    func testValidationErrorMessagesAreActionable() {
        // Test negative value error
        do {
            try NutritionalDataValidator.validateNutritionalValue(-10.0, fieldName: "Protein")
            Issue.record("Expected validation error")
        } catch let error as ValidationError {
            let message = error.errorDescription ?? ""
            #expect(message.contains("non-negative"))
            #expect(message.contains("Protein"))
        } catch {
            Issue.record("Expected ValidationError")
        }
        
        // Test non-positive value error
        do {
            try NutritionalDataValidator.validateServingSize(0.0, fieldName: "Quantity")
            Issue.record("Expected validation error")
        } catch let error as ValidationError {
            let message = error.errorDescription ?? ""
            #expect(message.contains("greater than zero"))
            #expect(message.contains("Quantity"))
        } catch {
            Issue.record("Expected ValidationError")
        }
        
        // Test missing field error
        do {
            try NutritionalDataValidator.validateRequiredIngredientFields(name: "", calories: 100.0)
            Issue.record("Expected validation error")
        } catch let error as ValidationError {
            let message = error.errorDescription ?? ""
            #expect(message.contains("required"))
            #expect(message.contains("Name"))
        } catch {
            Issue.record("Expected ValidationError")
        }
    }
}
