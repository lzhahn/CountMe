//
//  NutritionAPIClientTests.swift
//  CountMeTests
//
//  Tests for NutritionAPIClient (USDA FoodData Central)
//

import Testing
import Foundation
@testable import CountMe

// MARK: - Mock URLSession

class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: HTTPURLResponse?
    static var mockError: Error?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if let response = MockURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        
        if let data = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}

    static func reset() {
        mockData = nil
        mockResponse = nil
        mockError = nil
    }
}

// MARK: - Test Tags
// Note: Tag extensions are defined in CalorieEstimatorTests.swift to avoid duplicates

// MARK: - Tests

@Suite("NutritionAPIClient Tests", .serialized)
struct NutritionAPIClientTests {
    
    private static let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    
    private func makeClient() -> NutritionAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return NutritionAPIClient(session: session)
    }
    
    private func mockSuccess(json: String) {
        MockURLProtocol.reset()
        MockURLProtocol.mockData = json.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: Self.baseURL)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
    }
    
    private func mockHTTPError(statusCode: Int) {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: Self.baseURL)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
    }
    
    // MARK: - API Search Tests
    
    @Test("Search returns correctly parsed USDA food results")
    func testSearchFood_ValidResponse_ReturnsResults() async throws {
        let client = makeClient()
        mockSuccess(json: """
        {
            "totalHits": 2,
            "foods": [
                {
                    "fdcId": 123,
                    "description": "APPLE, RAW",
                    "dataType": "SR Legacy",
                    "foodNutrients": [
                        {"nutrientId": 1008, "nutrientName": "Energy", "nutrientNumber": "208", "unitName": "KCAL", "value": 52.0},
                        {"nutrientId": 1003, "nutrientName": "Protein", "nutrientNumber": "203", "unitName": "G", "value": 0.26},
                        {"nutrientId": 1005, "nutrientName": "Carbohydrate, by difference", "nutrientNumber": "205", "unitName": "G", "value": 13.81},
                        {"nutrientId": 1004, "nutrientName": "Total lipid (fat)", "nutrientNumber": "204", "unitName": "G", "value": 0.17}
                    ]
                },
                {
                    "fdcId": 456,
                    "description": "APPLE JUICE",
                    "dataType": "Branded",
                    "brandOwner": "Tropicana",
                    "servingSize": 240.0,
                    "servingSizeUnit": "ml",
                    "foodNutrients": [
                        {"nutrientId": 1008, "nutrientName": "Energy", "nutrientNumber": "208", "unitName": "KCAL", "value": 120.0},
                        {"nutrientId": 1005, "nutrientName": "Carbohydrate, by difference", "nutrientNumber": "205", "unitName": "G", "value": 28.0},
                        {"nutrientId": 1004, "nutrientName": "Total lipid (fat)", "nutrientNumber": "204", "unitName": "G", "value": 0.0}
                    ]
                }
            ]
        }
        """)
        
        let results = try await client.searchFood(query: "apple")
        
        #expect(results.count == 2)
        
        // First result
        #expect(results[0].id == "123")
        #expect(results[0].name == "Apple, Raw")
        #expect(results[0].calories == 52.0)
        #expect(results[0].servingSize == "100")
        #expect(results[0].servingUnit == "g")
        #expect(results[0].brandName == nil)
        #expect(results[0].protein != nil)
        #expect(abs(results[0].protein! - 0.26) < 0.01)
        #expect(abs(results[0].carbohydrates! - 13.81) < 0.01)
        #expect(abs(results[0].fats! - 0.17) < 0.01)
        
        // Second result (branded with serving size)
        #expect(results[1].id == "456")
        #expect(results[1].name == "Apple Juice")
        #expect(results[1].calories == 120.0)
        #expect(results[1].servingSize == "240")
        #expect(results[1].servingUnit == "ml")
        #expect(results[1].brandName == "Tropicana")
        #expect(results[1].protein == nil)
        #expect(abs(results[1].carbohydrates! - 28.0) < 0.01)
        #expect(abs(results[1].fats! - 0.0) < 0.01)
    }
    
    @Test("Search with empty results returns empty array")
    func testSearchFood_EmptyResults_ReturnsEmptyArray() async throws {
        let client = makeClient()
        mockSuccess(json: """
        { "totalHits": 0, "foods": [] }
        """)
        
        let results = try await client.searchFood(query: "nonexistent")
        #expect(results.count == 0)
    }
    
    @Test("Search with missing foods key returns empty array")
    func testSearchFood_NoFoodsKey_ReturnsEmptyArray() async throws {
        let client = makeClient()
        mockSuccess(json: """
        { "totalHits": 0 }
        """)
        
        let results = try await client.searchFood(query: "test")
        #expect(results.count == 0)
    }

    // MARK: - Error Handling Tests
    
    @Test("Rate limit (429) throws rateLimitExceeded")
    func testSearchFood_RateLimit_ThrowsError() async throws {
        let client = makeClient()
        mockHTTPError(statusCode: 429)
        
        await #expect(throws: NutritionAPIError.self) {
            try await client.searchFood(query: "test")
        }
    }
    
    @Test("Server error (500) throws invalidResponse")
    func testSearchFood_ServerError_ThrowsError() async throws {
        let client = makeClient()
        mockHTTPError(statusCode: 500)
        
        await #expect(throws: NutritionAPIError.self) {
            try await client.searchFood(query: "test")
        }
    }
    
    @Test("Not found (404) throws invalidResponse")
    func testSearchFood_NotFound_ThrowsError() async throws {
        let client = makeClient()
        mockHTTPError(statusCode: 404)
        
        await #expect(throws: NutritionAPIError.self) {
            try await client.searchFood(query: "test")
        }
    }
    
    @Test("Invalid JSON throws invalidData")
    func testSearchFood_InvalidJSON_ThrowsError() async throws {
        let client = makeClient()
        MockURLProtocol.reset()
        MockURLProtocol.mockData = "invalid json".data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: Self.baseURL)!, statusCode: 200, httpVersion: nil, headerFields: nil
        )
        
        await #expect(throws: NutritionAPIError.self) {
            try await client.searchFood(query: "test")
        }
    }
    
    @Test("Network offline throws networkError")
    func testSearchFood_NetworkOffline_ThrowsError() async throws {
        let client = makeClient()
        MockURLProtocol.reset()
        MockURLProtocol.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        
        await #expect(throws: NutritionAPIError.self) {
            try await client.searchFood(query: "test")
        }
    }
    
    @Test("Timeout throws timeout error")
    func testSearchFood_Timeout_ThrowsError() async throws {
        let client = makeClient()
        MockURLProtocol.reset()
        MockURLProtocol.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "The request timed out."]
        )
        
        await #expect(throws: NutritionAPIError.self) {
            try await client.searchFood(query: "test")
        }
    }
    
    @Test("All NutritionAPIError cases have non-empty descriptions")
    func testErrorDescriptions_AllCases_HaveDescriptions() {
        let errors: [NutritionAPIError] = [
            .invalidResponse,
            .networkError(NSError(domain: "test", code: 1)),
            .invalidData,
            .rateLimitExceeded,
            .timeout
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription!.isEmpty == false)
        }
    }
    
    // MARK: - Nutrient Parsing Tests
    
    @Test("Foods without Energy nutrient are filtered out")
    func testSearchFood_NoEnergyNutrient_FilteredOut() async throws {
        let client = makeClient()
        mockSuccess(json: """
        {
            "totalHits": 2,
            "foods": [
                {
                    "fdcId": 123,
                    "description": "APPLE",
                    "foodNutrients": [
                        {"nutrientNumber": "208", "value": 52.0},
                        {"nutrientNumber": "204", "value": 0.17}
                    ]
                },
                {
                    "fdcId": 456,
                    "description": "UNKNOWN FOOD",
                    "foodNutrients": [
                        {"nutrientNumber": "204", "value": 0.17}
                    ]
                }
            ]
        }
        """)
        
        let results = try await client.searchFood(query: "test")
        #expect(results.count == 1, "Should filter out items without Energy nutrient")
        #expect(results[0].id == "123")
    }
    
    @Test("Partial macros are nil when not in response")
    func testSearchFood_PartialMacros_MissingAreNil() async throws {
        let client = makeClient()
        mockSuccess(json: """
        {
            "totalHits": 1,
            "foods": [{
                "fdcId": 789,
                "description": "PARTIAL MACROS FOOD",
                "foodNutrients": [
                    {"nutrientNumber": "208", "value": 100.0},
                    {"nutrientNumber": "205", "value": 20.0}
                ]
            }]
        }
        """)
        
        let results = try await client.searchFood(query: "test")
        #expect(results.count == 1)
        #expect(results[0].calories == 100.0)
        #expect(results[0].carbohydrates != nil)
        #expect(abs(results[0].carbohydrates! - 20.0) < 0.01)
        #expect(results[0].protein == nil, "Protein should be nil when not in response")
        #expect(results[0].fats == nil, "Fats should be nil when not in response")
    }
    
    @Test("Default serving size is 100g when not provided")
    func testSearchFood_NoServingSize_DefaultsTo100g() async throws {
        let client = makeClient()
        mockSuccess(json: """
        {
            "totalHits": 1,
            "foods": [{
                "fdcId": 100,
                "description": "GENERIC FOOD",
                "foodNutrients": [{"nutrientNumber": "208", "value": 200.0}]
            }]
        }
        """)
        
        let results = try await client.searchFood(query: "test")
        #expect(results.count == 1)
        #expect(results[0].servingSize == "100", "Should default to 100 when no serving size")
        #expect(results[0].servingUnit == "g", "Should default to g when no serving unit")
    }
    
    @Test("Branded food uses provided serving size and brand")
    func testSearchFood_BrandedFood_UsesProvidedServingAndBrand() async throws {
        let client = makeClient()
        mockSuccess(json: """
        {
            "totalHits": 1,
            "foods": [{
                "fdcId": 200,
                "description": "PROTEIN BAR",
                "dataType": "Branded",
                "brandOwner": "Quest",
                "servingSize": 60.0,
                "servingSizeUnit": "g",
                "foodNutrients": [
                    {"nutrientNumber": "208", "value": 200.0},
                    {"nutrientNumber": "203", "value": 20.0},
                    {"nutrientNumber": "205", "value": 22.0},
                    {"nutrientNumber": "204", "value": 8.0}
                ]
            }]
        }
        """)
        
        let results = try await client.searchFood(query: "protein bar")
        #expect(results.count == 1)
        #expect(results[0].name == "Protein Bar")
        #expect(results[0].servingSize == "60")
        #expect(results[0].servingUnit == "g")
        #expect(results[0].brandName == "Quest")
        #expect(abs(results[0].protein! - 20.0) < 0.01)
        #expect(abs(results[0].carbohydrates! - 22.0) < 0.01)
        #expect(abs(results[0].fats! - 8.0) < 0.01)
    }

    // MARK: - Property-Based Tests
    
    /// Property: Foods with Energy nutrient (208) are always included in results,
    /// foods without Energy are always excluded.
    @Test("Property: Energy nutrient presence determines inclusion in results",
          .tags(.property, .nutritionAPI))
    func testProperty_EnergyNutrientFiltering_1() async throws {
        let client = makeClient()
        
        for _ in 0..<100 {
            let hasEnergy = Bool.random()
            let calories = Double.random(in: 1...2000)
            let fdcId = Int.random(in: 1...999999)
            
            var nutrients = "["
            if hasEnergy {
                nutrients += "{\"nutrientNumber\": \"208\", \"value\": \(calories)}"
            }
            if Bool.random() {
                if hasEnergy { nutrients += "," }
                nutrients += "{\"nutrientNumber\": \"203\", \"value\": \(Double.random(in: 0...100))}"
            }
            nutrients += "]"
            
            mockSuccess(json: """
            {
                "totalHits": 1,
                "foods": [{
                    "fdcId": \(fdcId),
                    "description": "FOOD \(fdcId)",
                    "foodNutrients": \(nutrients)
                }]
            }
            """)
            
            let results = try await client.searchFood(query: "test")
            
            if hasEnergy {
                #expect(results.count == 1, "Food with Energy nutrient should be included (fdcId: \(fdcId))")
                #expect(abs(results[0].calories - calories) < 0.01)
            } else {
                #expect(results.count == 0, "Food without Energy nutrient should be excluded (fdcId: \(fdcId))")
            }
        }
    }
    
    /// Property: Macro values from the API are faithfully preserved in results —
    /// protein, carbs, and fat values match their source nutrients exactly.
    @Test("Property: Macro nutrient values are faithfully preserved from API response",
          .tags(.property, .nutritionAPI))
    func testProperty_MacroValuesPreserved_2() async throws {
        let client = makeClient()
        
        for _ in 0..<100 {
            let calories = Double.random(in: 1...2000)
            let protein = Double.random(in: 0...100)
            let carbs = Double.random(in: 0...300)
            let fat = Double.random(in: 0...100)
            
            mockSuccess(json: """
            {
                "totalHits": 1,
                "foods": [{
                    "fdcId": \(Int.random(in: 1...999999)),
                    "description": "FOOD",
                    "foodNutrients": [
                        {"nutrientNumber": "208", "value": \(calories)},
                        {"nutrientNumber": "203", "value": \(protein)},
                        {"nutrientNumber": "205", "value": \(carbs)},
                        {"nutrientNumber": "204", "value": \(fat)}
                    ]
                }]
            }
            """)
            
            let results = try await client.searchFood(query: "test")
            
            #expect(results.count == 1)
            #expect(abs(results[0].calories - calories) < 0.001, "Calories should be preserved")
            #expect(abs(results[0].protein! - protein) < 0.001, "Protein should be preserved")
            #expect(abs(results[0].carbohydrates! - carbs) < 0.001, "Carbs should be preserved")
            #expect(abs(results[0].fats! - fat) < 0.001, "Fat should be preserved")
        }
    }
    
    /// Property: Serving size from the API is correctly formatted as a string,
    /// and defaults to "100" / "g" when not provided.
    @Test("Property: Serving size formatting and defaults are consistent",
          .tags(.property, .nutritionAPI))
    func testProperty_ServingSizeFormatting_3() async throws {
        let client = makeClient()
        
        for _ in 0..<100 {
            let hasServingSize = Bool.random()
            let servingSize = Double.random(in: 1...500)
            
            var foodFields = """
            "fdcId": \(Int.random(in: 1...999999)),
            "description": "FOOD",
            "foodNutrients": [{"nutrientNumber": "208", "value": 100.0}]
            """
            
            if hasServingSize {
                foodFields += """
                ,
                "servingSize": \(servingSize),
                "servingSizeUnit": "ml"
                """
            }
            
            mockSuccess(json: """
            {
                "totalHits": 1,
                "foods": [{\(foodFields)}]
            }
            """)
            
            let results = try await client.searchFood(query: "test")
            
            #expect(results.count == 1)
            
            if hasServingSize {
                #expect(results[0].servingSize == String(format: "%.0f", servingSize))
                #expect(results[0].servingUnit == "ml")
            } else {
                #expect(results[0].servingSize == "100", "Should default to 100")
                #expect(results[0].servingUnit == "g", "Should default to g")
            }
        }
    }
}
