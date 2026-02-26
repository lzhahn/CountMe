//
//  ServingOptionTests.swift
//  CountMeTests
//
//  Tests for ServingOption model and serving size calculations
//

import Testing
import Foundation
@testable import CountMe

@Suite("ServingOption Tests")
struct ServingOptionTests {
    
    // MARK: - Unit Tests
    
    @Test("ServingOption initializes with valid gram weight")
    func testServingOption_ValidGramWeight_Initializes() throws {
        let option = ServingOption(description: "1 cup", gramWeight: 240)
        
        #expect(option.description == "1 cup")
        #expect(option.gramWeight == 240)
        #expect(!option.id.isEmpty)
    }
    
    @Test("ServingOption rejects zero gram weight")
    func testServingOption_ZeroGramWeight_UsesDefault() throws {
        let option = ServingOption(description: "Invalid", gramWeight: 0)
        
        #expect(option.gramWeight == 100) // Should default to 100g
    }
    
    @Test("ServingOption rejects negative gram weight")
    func testServingOption_NegativeGramWeight_UsesDefault() throws {
        let option = ServingOption(description: "Invalid", gramWeight: -50)
        
        #expect(option.gramWeight == 100) // Should default to 100g
    }
    
    @Test("defaultOptions includes 100g baseline")
    func testDefaultOptions_Always_Includes100g() throws {
        let options = ServingOption.defaultOptions(servingSize: nil, servingUnit: nil)
        
        #expect(options.count >= 1)
        #expect(options.contains { $0.description == "100g" && $0.gramWeight == 100 })
    }
    
    @Test("defaultOptions includes serving size when provided")
    func testDefaultOptions_WithServingSize_IncludesBoth() throws {
        let options = ServingOption.defaultOptions(servingSize: "240", servingUnit: "ml")
        
        #expect(options.count == 2)
        #expect(options.contains { $0.description == "100g" })
        #expect(options.contains { $0.description == "240ml" && $0.gramWeight == 240 })
    }
    
    @Test("defaultOptions handles invalid serving size")
    func testDefaultOptions_InvalidServingSize_OnlyIncludes100g() throws {
        let options = ServingOption.defaultOptions(servingSize: "invalid", servingUnit: "g")
        
        #expect(options.count == 1)
        #expect(options.first?.description == "100g")
    }
    
    @Test("defaultOptions handles zero serving size")
    func testDefaultOptions_ZeroServingSize_OnlyIncludes100g() throws {
        let options = ServingOption.defaultOptions(servingSize: "0", servingUnit: "g")
        
        #expect(options.count == 1)
        #expect(options.first?.description == "100g")
    }
    
    @Test("defaultOptions handles negative serving size")
    func testDefaultOptions_NegativeServingSize_OnlyIncludes100g() throws {
        let options = ServingOption.defaultOptions(servingSize: "-100", servingUnit: "g")
        
        #expect(options.count == 1)
        #expect(options.first?.description == "100g")
    }
    
    // MARK: - Property Tests
    
    @Test("Property: ServingOption gramWeight is always positive", .tags(.property))
    func testProperty_ServingOption_GramWeightAlwaysPositive() async throws {
        for _ in 0..<100 {
            let randomWeight = Double.random(in: -1000...1000)
            let option = ServingOption(description: "Test", gramWeight: randomWeight)
            
            #expect(option.gramWeight > 0, "Gram weight should always be positive, got \(option.gramWeight)")
        }
    }
    
    @Test("Property: defaultOptions always returns at least one option", .tags(.property))
    func testProperty_DefaultOptions_AlwaysReturnsAtLeastOne() async throws {
        for _ in 0..<100 {
            // Generate random serving sizes (including invalid ones)
            let servingSize = Bool.random() ? String(Int.random(in: -100...500)) : "invalid"
            let servingUnit = Bool.random() ? "g" : nil
            
            let options = ServingOption.defaultOptions(servingSize: servingSize, servingUnit: servingUnit)
            
            #expect(!options.isEmpty, "Should always return at least one option")
            #expect(options.contains { $0.description == "100g" }, "Should always include 100g baseline")
        }
    }
    
    @Test("Property: Valid serving sizes produce two options", .tags(.property))
    func testProperty_ValidServingSize_ProducesTwoOptions() async throws {
        for _ in 0..<100 {
            let servingSize = String(Int.random(in: 1...1000))
            let servingUnit = ["g", "ml", "oz", "cup"].randomElement()!
            
            let options = ServingOption.defaultOptions(servingSize: servingSize, servingUnit: servingUnit)
            
            #expect(options.count == 2, "Valid serving size should produce exactly 2 options")
        }
    }
    
    @Test("Property: ServingOption is hashable and equatable", .tags(.property))
    func testProperty_ServingOption_HashableEquatable() async throws {
        for _ in 0..<100 {
            let description = "Test \(UUID().uuidString.prefix(8))"
            let gramWeight = Double.random(in: 1...1000)
            
            let option1 = ServingOption(description: description, gramWeight: gramWeight)
            let option2 = ServingOption(description: description, gramWeight: gramWeight)
            
            // Different IDs mean they're not equal
            #expect(option1.id != option2.id)
            
            // But they can be stored in a Set
            let set: Set<ServingOption> = [option1, option2]
            #expect(set.count == 2)
        }
    }
}
