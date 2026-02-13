//
//  AIRecipeParserTests.swift
//  CountMeTests
//
//  Tests for AIRecipeParser
//

import XCTest
@testable import CountMe

// MARK: - Mock URLSession

class MockAIURLProtocol: URLProtocol {
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
        if let error = MockAIURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if let response = MockAIURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        
        if let data = MockAIURLProtocol.mockData {
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

final class AIRecipeParserTests: XCTestCase {
    
    var parser: AIRecipeParser!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Configure mock URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockAIURLProtocol.self]
        mockSession = URLSession(configuration: config)
        
        parser = AIRecipeParser(
            endpoint: URL(string: "http://localhost:11434/api/chat")!,
            modelName: "llama3.2",
            session: mockSession
        )
        
        MockAIURLProtocol.reset()
    }
    
    override func tearDown() {
        parser = nil
        mockSession = nil
        MockAIURLProtocol.reset()
        super.tearDown()
    }
    
    // MARK: - Input Validation Tests
    
    func testValidateRecipeDescriptionTooShort() async {
        do {
            _ = try await parser.parseRecipe(description: "short")
            XCTFail("Should throw insufficientData error for short description")
        } catch let error as AIParserError {
            if case .insufficientData = error {
                // Expected error
            } else {
                XCTFail("Should throw insufficientData error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testValidateRecipeDescriptionTooLong() async {
        let longDescription = String(repeating: "a", count: 2001)
        
        do {
            _ = try await parser.parseRecipe(description: longDescription)
            XCTFail("Should throw invalidResponse error for long description")
        } catch let error as AIParserError {
            if case .invalidResponse = error {
                // Expected error
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testValidateRecipeDescriptionOnlyNumbers() async {
        do {
            _ = try await parser.parseRecipe(description: "123456789")
            XCTFail("Should throw insufficientData error for only numbers")
        } catch let error as AIParserError {
            if case .insufficientData = error {
                // Expected error
            } else {
                XCTFail("Should throw insufficientData error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    // MARK: - Successful Parsing Tests
    
    func testParseRecipeSuccess() async throws {
        // Mock successful Ollama generate API response
        let mockJSON = """
        {
            "response": "{\\"ingredients\\":[{\\"name\\":\\"chicken breast\\",\\"quantity\\":6,\\"unit\\":\\"oz\\",\\"calories\\":187,\\"protein\\":35,\\"carbohydrates\\":0,\\"fats\\":4},{\\"name\\":\\"white rice\\",\\"quantity\\":1,\\"unit\\":\\"cup\\",\\"calories\\":206,\\"protein\\":4,\\"carbohydrates\\":45,\\"fats\\":0.4}],\\"confidence\\":0.9}"
        }
        """
        
        MockAIURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let result = try await parser.parseRecipe(description: "chicken stir fry with rice")
        
        XCTAssertEqual(result.ingredients.count, 2, "Should return 2 ingredients")
        XCTAssertEqual(result.confidence, 0.9, "Should have confidence of 0.9")
        
        // Verify first ingredient
        XCTAssertEqual(result.ingredients[0].name, "chicken breast")
        XCTAssertEqual(result.ingredients[0].quantity, 6)
        XCTAssertEqual(result.ingredients[0].unit, "oz")
        XCTAssertEqual(result.ingredients[0].calories, 187)
        XCTAssertEqual(result.ingredients[0].protein, 35)
        XCTAssertEqual(result.ingredients[0].carbohydrates, 0)
        XCTAssertEqual(result.ingredients[0].fats, 4)
        
        // Verify second ingredient
        XCTAssertEqual(result.ingredients[1].name, "white rice")
        XCTAssertEqual(result.ingredients[1].quantity, 1)
        XCTAssertEqual(result.ingredients[1].unit, "cup")
        XCTAssertEqual(result.ingredients[1].calories, 206)
    }
    
    func testParseRecipeWithMarkdownBlocks() async throws {
        // Mock response with markdown code blocks (Ollama generate API format)
        let mockJSON = """
        {
            "response": "```json\\n{\\"ingredients\\":[{\\"name\\":\\"apple\\",\\"quantity\\":1,\\"unit\\":\\"piece\\",\\"calories\\":95,\\"protein\\":0.5,\\"carbohydrates\\":25,\\"fats\\":0.3}],\\"confidence\\":0.95}\\n```"
        }
        """
        
        MockAIURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let result = try await parser.parseRecipe(description: "one apple for snack")
        
        XCTAssertEqual(result.ingredients.count, 1, "Should return 1 ingredient")
        XCTAssertEqual(result.ingredients[0].name, "apple")
        XCTAssertEqual(result.confidence, 0.95)
    }
    
    // MARK: - Error Handling Tests
    
    func testParseRecipeNetworkError() async {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        MockAIURLProtocol.mockError = networkError
        
        do {
            _ = try await parser.parseRecipe(description: "chicken and rice")
            XCTFail("Should throw network error")
        } catch let error as AIParserError {
            if case .networkError = error {
                // Expected error
            } else {
                XCTFail("Should throw networkError, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testParseRecipeTimeout() async {
        let timeoutError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        MockAIURLProtocol.mockError = timeoutError
        
        do {
            _ = try await parser.parseRecipe(description: "chicken and rice")
            XCTFail("Should throw timeout error")
        } catch let error as AIParserError {
            if case .timeout = error {
                // Expected error
            } else {
                XCTFail("Should throw timeout error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testParseRecipeInvalidResponse() async {
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await parser.parseRecipe(description: "chicken and rice")
            XCTFail("Should throw invalid response error")
        } catch let error as AIParserError {
            if case .invalidResponse = error {
                // Expected error
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testParseRecipeEmptyIngredients() async {
        // Mock response with empty ingredients array (Ollama generate API format)
        let mockJSON = """
        {
            "response": "{\\"ingredients\\":[],\\"confidence\\":0.5}"
        }
        """
        
        MockAIURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await parser.parseRecipe(description: "chicken and rice")
            XCTFail("Should throw insufficientData error for empty ingredients")
        } catch let error as AIParserError {
            if case .insufficientData = error {
                // Expected error
            } else {
                XCTFail("Should throw insufficientData error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testParseRecipeInvalidJSON() async {
        // Mock response with invalid JSON (Ollama generate API format)
        let mockJSON = """
        {
            "response": "invalid json content"
        }
        """
        
        MockAIURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await parser.parseRecipe(description: "chicken and rice")
            XCTFail("Should throw parsingFailed error for invalid JSON")
        } catch let error as AIParserError {
            if case .parsingFailed = error {
                // Expected error
            } else {
                XCTFail("Should throw parsingFailed error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    // MARK: - Validation Tests
    
    func testParseRecipeNegativeCalories() async {
        // Mock response with negative calories (Ollama generate API format)
        let mockJSON = """
        {
            "response": "{\\"ingredients\\":[{\\"name\\":\\"test\\",\\"quantity\\":1,\\"unit\\":\\"cup\\",\\"calories\\":-100}],\\"confidence\\":0.9}"
        }
        """
        
        MockAIURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await parser.parseRecipe(description: "test recipe")
            XCTFail("Should throw invalidResponse error for negative calories")
        } catch let error as AIParserError {
            if case .invalidResponse = error {
                // Expected error
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testParseRecipeInvalidUnit() async {
        // Mock response with empty unit (Ollama generate API format)
        // The parser rejects empty units but accepts any non-empty unit string
        let mockJSON = """
        {
            "response": "{\\"ingredients\\":[{\\"name\\":\\"test\\",\\"quantity\\":1,\\"unit\\":\\"\\",\\"calories\\":100}],\\"confidence\\":0.9}"
        }
        """
        
        MockAIURLProtocol.mockData = mockJSON.data(using: .utf8)
        MockAIURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/chat")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await parser.parseRecipe(description: "test recipe")
            XCTFail("Should throw invalidResponse error for empty unit")
        } catch let error as AIParserError {
            if case .invalidResponse = error {
                // Expected error
            } else {
                XCTFail("Should throw invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Should throw AIParserError, got \(error)")
        }
    }
    
    func testErrorDescriptions() {
        // Verify all error types have user-friendly descriptions
        let errors: [AIParserError] = [
            .invalidResponse,
            .networkError(NSError(domain: "test", code: 1)),
            .parsingFailed,
            .timeout,
            .insufficientData
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
}
