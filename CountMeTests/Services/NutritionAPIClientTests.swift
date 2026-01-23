//
//  NutritionAPIClientTests.swift
//  CountMeTests
//
//  Tests for NutritionAPIClient
//

import XCTest
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
    
    override func stopLoading() {
        // No-op
    }
    
    static func reset() {
        mockData = nil
        mockResponse = nil
        mockError = nil
    }
}

// MARK: - Tests

final class NutritionAPIClientTests: XCTestCase {
    
    var client: NutritionAPIClient!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Configure mock URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        
        client = NutritionAPIClient(
            consumerKey: "test_key",
            consumerSecret: "test_secret",
            session: mockSession
        )
        
        MockURLProtocol.reset()
    }
    
    override func tearDown() {
        client = nil
        mockSession = nil
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    // MARK: - API Search Tests
    
    func testSearchFoodSuccess() async throws {
        // Mock successful API response
        let mockJSON = """
        {
            "foods": {
                "food": [
                    {
                        "food_id": "123",
                        "food_name": "Apple",
                        "food_type": "Generic",
                        "food_description": "Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g"
                    },
                    {
                        "food_id": "456",
                        "food_name": "Apple Juice",
                        "food_type": "Brand",
                        "brand_name": "Tropicana",
                        "food_description": "Per 1 cup - Calories: 120kcal | Fat: 0.00g | Carbs: 28.00g"
                    }
                ]
            }
        }
        """
        
        MockURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let results = try await client.searchFood(query: "apple")
        
        XCTAssertEqual(results.count, 2, "Should return 2 results")
        
        // Verify first result
        XCTAssertEqual(results[0].id, "123")
        XCTAssertEqual(results[0].name, "Apple")
        XCTAssertEqual(results[0].calories, 52.0)
        XCTAssertEqual(results[0].servingSize, "100")
        XCTAssertEqual(results[0].servingUnit, "g")
        XCTAssertNil(results[0].brandName)
        
        // Verify second result
        XCTAssertEqual(results[1].id, "456")
        XCTAssertEqual(results[1].name, "Apple Juice")
        XCTAssertEqual(results[1].calories, 120.0)
        XCTAssertEqual(results[1].servingSize, "1")
        XCTAssertEqual(results[1].servingUnit, "cup")
        XCTAssertEqual(results[1].brandName, "Tropicana")
    }
    
    func testSearchFoodEmptyResults() async throws {
        // Mock empty results
        let mockJSON = """
        {
            "foods": {
                "food": []
            }
        }
        """
        
        MockURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let results = try await client.searchFood(query: "nonexistent")
        
        XCTAssertEqual(results.count, 0, "Should return empty array")
    }
    
    func testSearchFoodNoFoodsKey() async throws {
        // Mock response without foods key
        let mockJSON = """
        {
            "error": {
                "message": "No results found"
            }
        }
        """
        
        MockURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let results = try await client.searchFood(query: "test")
        
        XCTAssertEqual(results.count, 0, "Should return empty array when no foods key")
    }
    
    func testSearchFoodRateLimitError() async {
        // Mock rate limit response
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw rate limit error")
        } catch let error as NutritionAPIError {
            if case .rateLimitExceeded = error {
                // Expected error
            } else {
                XCTFail("Should throw rateLimitExceeded error, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
    }
    
    func testSearchFoodInvalidResponse() async {
        // Mock invalid HTTP status
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw invalid response error")
        } catch let error as NutritionAPIError {
            if case .invalidResponse = error {
                // Expected error
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
    }
    
    func testSearchFoodInvalidJSON() async {
        // Mock invalid JSON
        MockURLProtocol.mockData = "invalid json".data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw invalid data error")
        } catch let error as NutritionAPIError {
            if case .invalidData = error {
                // Expected error
            } else {
                XCTFail("Should throw invalidData error, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
    }
    
    // MARK: - Network Error Tests (Task 3.6)
    
    func testSearchFoodNetworkError() async {
        // Mock network error
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        MockURLProtocol.mockError = networkError
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw network error")
        } catch let error as NutritionAPIError {
            if case .networkError(let underlyingError) = error {
                XCTAssertEqual((underlyingError as NSError).code, NSURLErrorNotConnectedToInternet)
                // Verify error description is user-friendly
                XCTAssertNotNil(error.errorDescription)
                XCTAssertTrue(error.errorDescription!.contains("Network error"))
            } else {
                XCTFail("Should throw networkError, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
    }
    
    func testSearchFoodTimeoutError() async {
        // Mock timeout error
        let timeoutError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "The request timed out."]
        )
        MockURLProtocol.mockError = timeoutError
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw timeout error")
        } catch let error as NutritionAPIError {
            if case .timeout = error {
                // Verify error description is user-friendly
                XCTAssertNotNil(error.errorDescription)
                XCTAssertTrue(error.errorDescription!.contains("took too long"))
            } else {
                XCTFail("Should throw timeout error, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
    }
    
    func testSearchFoodInvalidResponseScenarios() async {
        // Test various invalid response scenarios
        
        // Scenario 1: 404 Not Found
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw invalid response error for 404")
        } catch let error as NutritionAPIError {
            if case .invalidResponse = error {
                XCTAssertNotNil(error.errorDescription)
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
        
        // Scenario 2: 500 Internal Server Error
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await client.searchFood(query: "test")
            XCTFail("Should throw invalid response error for 500")
        } catch let error as NutritionAPIError {
            if case .invalidResponse = error {
                XCTAssertNotNil(error.errorDescription)
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw NutritionAPIError, got \(error)")
        }
    }
    
    func testErrorDescriptions() {
        // Verify all error types have user-friendly descriptions
        let errors: [NutritionAPIError] = [
            .invalidResponse,
            .networkError(NSError(domain: "test", code: 1)),
            .invalidData,
            .rateLimitExceeded,
            .timeout
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    func testSearchFoodFiltersInvalidCalories() async throws {
        // Mock response with one valid and one invalid food item
        let mockJSON = """
        {
            "foods": {
                "food": [
                    {
                        "food_id": "123",
                        "food_name": "Apple",
                        "food_type": "Generic",
                        "food_description": "Per 100g - Calories: 52kcal | Fat: 0.17g"
                    },
                    {
                        "food_id": "456",
                        "food_name": "Invalid Food",
                        "food_type": "Generic",
                        "food_description": "Per 100g - Fat: 0.17g"
                    }
                ]
            }
        }
        """
        
        MockURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://platform.fatsecret.com/rest/server.api")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let results = try await client.searchFood(query: "test")
        
        XCTAssertEqual(results.count, 1, "Should filter out items without calories")
        XCTAssertEqual(results[0].id, "123")
        XCTAssertEqual(results[0].name, "Apple")
    }
    
    // MARK: - Calorie Extraction Tests
    
    func testExtractCaloriesFromDescription() {
        // Test typical FatSecret format
        let description1 = "Per 100g - Calories: 250kcal | Fat: 10.00g | Carbs: 30.00g | Protein: 8.00g"
        let result1 = extractCaloriesFromDescription(description1)
        XCTAssertEqual(result1, 250.0, "Should extract 250 calories")
        
        // Test with decimal calories
        let description2 = "Per 1 serving - Calories: 150.5kcal | Fat: 5.00g"
        let result2 = extractCaloriesFromDescription(description2)
        XCTAssertEqual(result2, 150.5, "Should extract 150.5 calories")
        
        // Test with space before kcal
        let description3 = "Per 1 cup - Calories: 200 kcal"
        let result3 = extractCaloriesFromDescription(description3)
        XCTAssertEqual(result3, 200.0, "Should extract 200 calories with space")
    }
    
    func testExtractCaloriesInvalidFormat() {
        // Test with no calorie information
        let description = "Per 100g - Fat: 10.00g | Carbs: 30.00g"
        let result = extractCaloriesFromDescription(description)
        XCTAssertNil(result, "Should return nil when no calories found")
    }
    
    // MARK: - Serving Info Parsing Tests
    
    func testParseServingInfo() {
        // Test with grams
        let description1 = "Per 100g - Calories: 250kcal"
        let (size1, unit1) = parseServingInfoFromDescription(description1)
        XCTAssertEqual(size1, "100", "Should extract serving size 100")
        XCTAssertEqual(unit1, "g", "Should extract unit g")
        
        // Test with serving
        let description2 = "Per 1 serving - Calories: 150kcal"
        let (size2, unit2) = parseServingInfoFromDescription(description2)
        XCTAssertEqual(size2, "1", "Should extract serving size 1")
        XCTAssertEqual(unit2, "serving", "Should extract unit serving")
        
        // Test with cup
        let description3 = "Per 2 cups - Calories: 200kcal"
        let (size3, unit3) = parseServingInfoFromDescription(description3)
        XCTAssertEqual(size3, "2", "Should extract serving size 2")
        XCTAssertEqual(unit3, "cups", "Should extract unit cups")
    }
    
    func testParseServingInfoInvalidFormat() {
        // Test with no serving information
        let description = "Calories: 250kcal"
        let (size, unit) = parseServingInfoFromDescription(description)
        XCTAssertNil(size, "Should return nil size when no serving info found")
        XCTAssertNil(unit, "Should return nil unit when no serving info found")
    }
    
    // MARK: - Helper Methods
    
    private func extractCaloriesFromDescription(_ description: String) -> Double? {
        let pattern = "Calories:\\s*(\\d+(?:\\.\\d+)?)\\s*kcal"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let nsString = description as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        guard let match = regex.firstMatch(in: description, options: [], range: range) else {
            return nil
        }
        
        let calorieRange = match.range(at: 1)
        let calorieString = nsString.substring(with: calorieRange)
        
        return Double(calorieString)
    }
    
    private func parseServingInfoFromDescription(_ description: String) -> (String?, String?) {
        let pattern = "Per\\s+(\\d+(?:\\.\\d+)?)\\s*([a-zA-Z]+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (nil, nil)
        }
        
        let nsString = description as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        guard let match = regex.firstMatch(in: description, options: [], range: range) else {
            return (nil, nil)
        }
        
        let sizeRange = match.range(at: 1)
        let unitRange = match.range(at: 2)
        
        let size = nsString.substring(with: sizeRange)
        let unit = nsString.substring(with: unitRange)
        
        return (size, unit)
    }
}
