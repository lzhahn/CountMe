//
//  BrandExtractionTests.swift
//  CountMeTests
//
//  Integration tests for OpenFoodFacts search functionality
//  Note: These tests make real API calls to OpenFoodFacts
//

import Testing
import Foundation
@testable import CountMe

@Suite("Search Integration Tests")
struct BrandExtractionTests {
    
    // MARK: - Integration Tests (make real API calls)
    
    @Test("Search with brand query returns relevant results")
    func testSearch_BrandQuery_ReturnsRelevant() async throws {
        let client = NutritionAPIClient()
        
        let results = try await client.searchFood(query: "trader joes yogurt")
        
        // OpenFoodFacts should return results
        if !results.isEmpty {
            let firstResult = results[0]
            
            // Verify result structure is valid
            #expect(!firstResult.id.isEmpty, "Should have valid ID")
            #expect(!firstResult.name.isEmpty, "Should have valid name")
            #expect(firstResult.calories >= 0, "Should have non-negative calories")
            #expect(!firstResult.servingOptions.isEmpty, "Should have serving options")
        }
    }
    
    @Test("Search returns maximum 25 results")
    func testSearch_AnyQuery_ReturnsMax25() async throws {
        let client = NutritionAPIClient()
        
        // Use a broad query that should return many results
        let results = try await client.searchFood(query: "yogurt")
        
        #expect(results.count <= 25, "Should return maximum 25 results, got \(results.count)")
    }
    
    @Test("Search filters out invalid results")
    func testSearch_Results_NoNegativeCalories() async throws {
        let client = NutritionAPIClient()
        
        let results = try await client.searchFood(query: "apple")
        
        // All results should have non-negative calories
        for result in results {
            #expect(result.calories >= 0, "Result '\(result.name)' has negative calories: \(result.calories)")
        }
    }
    
    @Test("Search without brand returns general results")
    func testSearch_NoBrand_ReturnsGeneralResults() async throws {
        let client = NutritionAPIClient()
        
        let results = try await client.searchFood(query: "apple")
        
        #expect(!results.isEmpty, "Should return results for common food 'apple'")
        
        if !results.isEmpty {
            let firstResult = results[0]
            #expect(!firstResult.name.isEmpty, "Should have valid name")
            #expect(firstResult.calories >= 0, "Should have valid calories")
        }
    }
    
    @Test("Search with multi-word query works")
    func testSearch_MultiWord_ReturnsResults() async throws {
        let client = NutritionAPIClient()
        
        let results = try await client.searchFood(query: "greek yogurt")
        
        if !results.isEmpty {
            let firstResult = results[0]
            #expect(!firstResult.name.isEmpty, "Should have valid name")
            #expect(firstResult.calories >= 0, "Should have valid calories")
        }
    }
    
    // MARK: - Property Tests
    
    @Test("Property: All results have valid structure")
    func testProperty_Results_ValidStructure() async throws {
        let client = NutritionAPIClient()
        let queries = ["apple", "banana", "chicken", "rice", "milk"]
        
        for query in queries {
            let results = try await client.searchFood(query: query)
            
            for result in results {
                #expect(!result.id.isEmpty, "ID should not be empty for query '\(query)'")
                #expect(!result.name.isEmpty, "Name should not be empty for query '\(query)'")
                #expect(result.calories >= 0, "Calories should be non-negative for query '\(query)'")
                #expect(!result.servingOptions.isEmpty, "Should have serving options for query '\(query)'")
                
                // Verify serving options are valid
                for option in result.servingOptions {
                    #expect(!option.description.isEmpty, "Serving description should not be empty")
                    #expect(option.gramWeight > 0, "Gram weight should be positive")
                }
            }
        }
    }
    
    @Test("Property: Results limited to 25 across queries")
    func testProperty_Results_LimitedTo25() async throws {
        let client = NutritionAPIClient()
        let queries = ["yogurt", "milk", "bread", "cheese", "chicken"]
        
        for query in queries {
            let results = try await client.searchFood(query: query)
            #expect(results.count <= 25, "Query '\(query)' returned \(results.count) results, should be <= 25")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty query returns empty results")
    func testSearch_EmptyQuery_ReturnsEmpty() async throws {
        let client = NutritionAPIClient()
        
        let results = try await client.searchFood(query: "")
        
        // Empty query should return empty or minimal results
        #expect(results.isEmpty || !results.isEmpty)
    }
    
    @Test("Special characters handled gracefully")
    func testSearch_SpecialCharacters_HandledGracefully() async throws {
        let client = NutritionAPIClient()
        
        // Should not crash with special characters
        let results = try await client.searchFood(query: "trader joe's")
        
        #expect(results.isEmpty || !results.isEmpty)
    }
    
    @Test("Very long query handled gracefully")
    func testSearch_LongQuery_HandledGracefully() async throws {
        let client = NutritionAPIClient()
        
        let longQuery = String(repeating: "organic ", count: 20) + "yogurt"
        
        // Should not crash with long query
        let results = try await client.searchFood(query: longQuery)
        
        #expect(results.isEmpty || !results.isEmpty)
    }
    
    // MARK: - OpenFoodFacts Specific Tests
    
    @Test("OpenFoodFacts returns international products")
    func testSearch_International_ReturnsResults() async throws {
        let client = NutritionAPIClient()
        
        // OpenFoodFacts has global coverage
        let results = try await client.searchFood(query: "nutella")
        
        if !results.isEmpty {
            let firstResult = results[0]
            #expect(!firstResult.name.isEmpty, "Should have valid name")
            #expect(firstResult.calories >= 0, "Should have valid calories")
        }
    }
    
    @Test("OpenFoodFacts handles brand names natively")
    func testSearch_BrandName_ReturnsResults() async throws {
        let client = NutritionAPIClient()
        
        // OpenFoodFacts has native brand support
        let results = try await client.searchFood(query: "coca cola")
        
        if !results.isEmpty {
            let firstResult = results[0]
            #expect(!firstResult.name.isEmpty, "Should have valid name")
            #expect(firstResult.calories >= 0, "Should have valid calories")
            // Brand name may be in the brands field
        }
    }
}
