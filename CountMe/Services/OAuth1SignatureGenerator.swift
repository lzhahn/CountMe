//
//  OAuth1SignatureGenerator.swift
//  CountMe
//
//  OAuth 1.0 signature generator (retained for potential future use)
//

import Foundation
import CryptoKit

/// Generates OAuth 1.0 signatures for API requests
struct OAuth1SignatureGenerator {
    let consumerKey: String
    let consumerSecret: String
    
    /// Generates a timestamp for OAuth 1.0 (seconds since Unix epoch)
    func generateTimestamp() -> String {
        return String(Int(Date().timeIntervalSince1970))
    }
    
    /// Generates a unique nonce (random string)
    func generateNonce() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    /// Generates the signature base string according to OAuth 1.0 spec
    /// - Parameters:
    ///   - httpMethod: The HTTP method (e.g., "GET", "POST")
    ///   - url: The base URL without query parameters
    ///   - parameters: All OAuth and request parameters
    /// - Returns: The signature base string
    func generateSignatureBaseString(
        httpMethod: String,
        url: String,
        parameters: [String: String]
    ) -> String {
        // 1. Percent encode keys and values
        let encodedParams = parameters.map { (key, value) in
            (key.percentEncoded(), value.percentEncoded())
        }
        
        // 2. Sort parameters alphabetically by encoded key
        let sortedParams = encodedParams.sorted { $0.0 < $1.0 }
        
        // 3. Create parameter string (encodedKey=encodedValue&...)
        let parameterString = sortedParams
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
        
        // 4. Percent encode the HTTP method, URL, and parameter string
        let encodedMethod = httpMethod.uppercased().percentEncoded()
        let encodedURL = url.percentEncoded()
        let encodedParamString = parameterString.percentEncoded()
        
        // 5. Concatenate with & separator
        return "\(encodedMethod)&\(encodedURL)&\(encodedParamString)"
    }
    
    /// Generates the signing key from consumer secret and token secret
    /// - Parameter tokenSecret: The OAuth token secret (empty string for 2-legged OAuth)
    /// - Returns: The signing key
    func generateSigningKey(tokenSecret: String = "") -> String {
        let encodedConsumerSecret = consumerSecret.percentEncoded()
        let encodedTokenSecret = tokenSecret.percentEncoded()
        // The & separator is literal, not percent-encoded
        return "\(encodedConsumerSecret)&\(encodedTokenSecret)"
    }
    
    /// Signs the signature base string using HMAC-SHA1
    /// - Parameters:
    ///   - baseString: The signature base string
    ///   - signingKey: The signing key
    /// - Returns: The base64-encoded signature
    func signWithHMACSHA1(baseString: String, signingKey: String) -> String {
        guard let keyData = signingKey.data(using: .utf8),
              let baseStringData = baseString.data(using: .utf8) else {
            return ""
        }
        
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: baseStringData, using: key)
        return Data(signature).base64EncodedString()
    }
    
    /// Generates a complete OAuth 1.0 signature for a request
    /// - Parameters:
    ///   - httpMethod: The HTTP method (e.g., "GET", "POST")
    ///   - url: The base URL without query parameters
    ///   - parameters: Request-specific parameters (not including OAuth parameters)
    ///   - timestamp: Optional timestamp (generated if not provided)
    ///   - nonce: Optional nonce (generated if not provided)
    /// - Returns: Tuple of (signature, timestamp, nonce) used for the signature
    func generateSignature(
        httpMethod: String,
        url: String,
        parameters: [String: String] = [:],
        timestamp: String? = nil,
        nonce: String? = nil
    ) -> (signature: String, timestamp: String, nonce: String) {
        // Use provided or generate new OAuth parameters
        let finalTimestamp = timestamp ?? generateTimestamp()
        let finalNonce = nonce ?? generateNonce()
        
        // Add OAuth parameters
        var allParameters = parameters
        allParameters["oauth_consumer_key"] = consumerKey
        allParameters["oauth_signature_method"] = "HMAC-SHA1"
        allParameters["oauth_timestamp"] = finalTimestamp
        allParameters["oauth_nonce"] = finalNonce
        allParameters["oauth_version"] = "1.0"
        
        // Generate signature base string
        let baseString = generateSignatureBaseString(
            httpMethod: httpMethod,
            url: url,
            parameters: allParameters
        )
        
        // Generate signing key and sign
        let signingKey = generateSigningKey()
        let signature = signWithHMACSHA1(baseString: baseString, signingKey: signingKey)
        
        return (signature, finalTimestamp, finalNonce)
    }
}

// MARK: - String Extension for Percent Encoding

extension String {
    /// Percent encodes a string according to OAuth 1.0 spec (RFC 3986)
    func percentEncoded() -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? self
    }
}
