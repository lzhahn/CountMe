//
//  OAuth1SignatureGeneratorTests.swift
//  CountMeTests
//
//  Tests for OAuth 1.0 signature generation
//

import XCTest
@testable import CountMe

final class OAuth1SignatureGeneratorTests: XCTestCase {
    
    var generator: OAuth1SignatureGenerator!
    
    override func setUp() {
        super.setUp()
        generator = OAuth1SignatureGenerator(
            consumerKey: "test_consumer_key",
            consumerSecret: "test_consumer_secret"
        )
    }
    
    override func tearDown() {
        generator = nil
        super.tearDown()
    }
    
    // MARK: - Timestamp Tests
    
    func testGenerateTimestamp() {
        let timestamp = generator.generateTimestamp()
        
        // Verify it's a valid integer string
        XCTAssertNotNil(Int(timestamp), "Timestamp should be a valid integer")
        
        // Verify it's approximately current time (within 5 seconds)
        let timestampInt = Int(timestamp)!
        let currentTime = Int(Date().timeIntervalSince1970)
        XCTAssertTrue(abs(timestampInt - currentTime) <= 5, "Timestamp should be within 5 seconds of current time")
    }
    
    // MARK: - Nonce Tests
    
    func testGenerateNonce() {
        let nonce = generator.generateNonce()
        
        // Verify it's not empty
        XCTAssertFalse(nonce.isEmpty, "Nonce should not be empty")
        
        // Verify it doesn't contain hyphens (UUID hyphens should be removed)
        XCTAssertFalse(nonce.contains("-"), "Nonce should not contain hyphens")
        
        // Verify uniqueness by generating multiple nonces
        let nonce2 = generator.generateNonce()
        XCTAssertNotEqual(nonce, nonce2, "Nonces should be unique")
    }
    
    // MARK: - Percent Encoding Tests
    
    func testPercentEncoding() {
        // Test basic alphanumeric (should not be encoded)
        XCTAssertEqual("abc123".percentEncoded(), "abc123")
        
        // Test allowed characters (should not be encoded per RFC 3986)
        XCTAssertEqual("-._~".percentEncoded(), "-._~")
        
        // Test space (should be encoded)
        XCTAssertEqual("hello world".percentEncoded(), "hello%20world")
        
        // Test special characters (@ should be encoded, . should not)
        XCTAssertEqual("test@example.com".percentEncoded(), "test%40example.com")
        
        // Test URL with query parameters
        XCTAssertEqual("http://example.com?key=value".percentEncoded(), 
                      "http%3A%2F%2Fexample.com%3Fkey%3Dvalue")
    }
    
    // MARK: - Signature Base String Tests
    
    func testGenerateSignatureBaseString() {
        let httpMethod = "GET"
        let url = "https://platform.fatsecret.com/rest/server.api"
        let parameters = [
            "oauth_consumer_key": "test_key",
            "oauth_nonce": "test_nonce",
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_timestamp": "1234567890",
            "oauth_version": "1.0",
            "method": "foods.search",
            "search_expression": "apple"
        ]
        
        let baseString = generator.generateSignatureBaseString(
            httpMethod: httpMethod,
            url: url,
            parameters: parameters
        )
        
        // Verify base string is not empty
        XCTAssertFalse(baseString.isEmpty, "Base string should not be empty")
        
        // Verify it starts with the HTTP method (GET doesn't need encoding, so it's GET&)
        XCTAssertTrue(baseString.hasPrefix("GET&"), "Base string should start with GET&")
        
        // Verify it contains the URL (. should not be encoded per RFC 3986)
        XCTAssertTrue(baseString.contains("https%3A%2F%2Fplatform.fatsecret.com%2Frest%2Fserver.api"), 
                     "Base string should contain properly encoded URL")
        
        // Verify parameters are present and properly encoded
        // After double encoding: = becomes %3D, & becomes %26, but . stays as .
        XCTAssertTrue(baseString.contains("method%3Dfoods.search"), 
                     "Base string should contain method=foods.search with = encoded as %3D")
    }
    
    // MARK: - Signing Key Tests
    
    func testGenerateSigningKey() {
        let signingKey = generator.generateSigningKey()
        
        // The signing key format is: consumer_secret&token_secret
        // With empty token secret, it should be: consumer_secret&
        XCTAssertEqual(signingKey, "test_consumer_secret&", 
                     "Signing key should be consumer_secret& (with literal & and empty token secret)")
        
        // Test with token secret
        let signingKeyWithToken = generator.generateSigningKey(tokenSecret: "token_secret")
        XCTAssertEqual(signingKeyWithToken, "test_consumer_secret&token_secret",
                     "Signing key should be consumer_secret&token_secret (with literal &)")
    }
    
    // MARK: - HMAC-SHA1 Signing Tests
    
    func testSignWithHMACSHA1() {
        let baseString = "GET&https%3A%2F%2Fapi.example.com&param%3Dvalue"
        let signingKey = "secret&"
        
        let signature = generator.signWithHMACSHA1(baseString: baseString, signingKey: signingKey)
        
        // Verify signature is not empty
        XCTAssertFalse(signature.isEmpty, "Signature should not be empty")
        
        // Verify signature is base64 encoded (should only contain valid base64 characters)
        let base64Pattern = "^[A-Za-z0-9+/]*={0,2}$"
        let regex = try! NSRegularExpression(pattern: base64Pattern)
        let range = NSRange(location: 0, length: signature.utf16.count)
        XCTAssertNotNil(regex.firstMatch(in: signature, range: range), 
                       "Signature should be valid base64")
        
        // Verify consistency - same input should produce same signature
        let signature2 = generator.signWithHMACSHA1(baseString: baseString, signingKey: signingKey)
        XCTAssertEqual(signature, signature2, "Same input should produce same signature")
    }
    
    // MARK: - Complete Signature Generation Tests
    
    func testGenerateSignature() {
        let httpMethod = "GET"
        let url = "https://platform.fatsecret.com/rest/server.api"
        let parameters = [
            "method": "foods.search",
            "search_expression": "apple"
        ]
        
        let result = generator.generateSignature(
            httpMethod: httpMethod,
            url: url,
            parameters: parameters
        )
        
        // Verify signature is not empty
        XCTAssertFalse(result.signature.isEmpty, "Signature should not be empty")
        
        // Verify signature is base64 encoded
        let base64Pattern = "^[A-Za-z0-9+/]*={0,2}$"
        let regex = try! NSRegularExpression(pattern: base64Pattern)
        let range = NSRange(location: 0, length: result.signature.utf16.count)
        XCTAssertNotNil(regex.firstMatch(in: result.signature, range: range), 
                       "Signature should be valid base64")
    }
    
    func testGenerateSignatureWithEmptyParameters() {
        let result = generator.generateSignature(
            httpMethod: "GET",
            url: "https://api.example.com"
        )
        
        // Should still generate a valid signature even with no request parameters
        XCTAssertFalse(result.signature.isEmpty, "Signature should be generated even with empty parameters")
    }
}
