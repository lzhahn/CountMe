//
//  NutritionAPIClient.swift
//  CountMe
//
//  Actor for interacting with the FatSecret Platform API
//

import Foundation

/// Errors that can occur during nutrition API operations
enum NutritionAPIError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case invalidData
    case rateLimitExceeded
    case timeout
    
    /// Provides user-friendly error descriptions
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The nutrition API returned an invalid response. Please try again."
        case .networkError(let error):
            return "Network error occurred: \(error.localizedDescription). Please check your internet connection."
        case .invalidData:
            return "Unable to parse nutrition data. The API response format may have changed."
        case .rateLimitExceeded:
            return "Too many requests to the nutrition API. Please wait a moment and try again."
        case .timeout:
            return "The request took too long to complete. Please check your internet connection and try again."
        }
    }
}

/// Actor for thread-safe nutrition API operations
actor NutritionAPIClient {
    private let session: URLSession
    private let consumerKey: String
    private let consumerSecret: String
    private let signatureGenerator: OAuth1SignatureGenerator
    
    private let baseURL = "https://platform.fatsecret.com/rest/server.api"
    
    /// Initializes the nutrition API client
    /// - Parameters:
    ///   - consumerKey: FatSecret API consumer key
    ///   - consumerSecret: FatSecret API consumer secret
    ///   - session: URLSession for network requests (defaults to configured session with 30s timeout)
    init(
        consumerKey: String,
        consumerSecret: String,
        session: URLSession? = nil
    ) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        
        // Configure session with 30-second timeout if not provided
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30.0
            configuration.timeoutIntervalForResource = 30.0
            self.session = URLSession(configuration: configuration)
        }
        
        self.signatureGenerator = OAuth1SignatureGenerator(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret
        )
    }
    
    /// Searches for food items by name
    /// - Parameter query: The search query string
    /// - Returns: Array of nutrition search results
    /// - Throws: NutritionAPIError if the request fails
    func searchFood(query: String) async throws -> [NutritionSearchResult] {
        // Generate OAuth signature with all parameters
        let signatureResult = signatureGenerator.generateSignature(
            httpMethod: "GET",
            url: baseURL,
            parameters: [
                "method": "foods.search",
                "search_expression": query,
                "format": "json"
            ]
        )
        
        // Build request parameters with OAuth credentials
        var parameters: [String: String] = [
            "method": "foods.search",
            "search_expression": query,
            "format": "json",
            "oauth_consumer_key": consumerKey,
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_timestamp": signatureResult.timestamp,
            "oauth_nonce": signatureResult.nonce,
            "oauth_version": "1.0",
            "oauth_signature": signatureResult.signature
        ]
        
        // Build URL with query parameters
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NutritionAPIError.invalidResponse
        }
        
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents.url else {
            throw NutritionAPIError.invalidResponse
        }
        
        // Make the request with error handling
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as NSError {
            // Handle timeout errors specifically
            if error.code == NSURLErrorTimedOut {
                throw NutritionAPIError.timeout
            }
            // Wrap other network errors with descriptive context
            throw NutritionAPIError.networkError(error)
        }
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionAPIError.invalidResponse
        }
        
        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            throw NutritionAPIError.rateLimitExceeded
        }
        
        // Check for successful response
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NutritionAPIError.invalidResponse
        }
        
        // Parse the response
        return try parseSearchResponse(data)
    }
    
    /// Parses the FatSecret search response into NutritionSearchResult objects
    /// - Parameter data: The JSON response data
    /// - Returns: Array of nutrition search results
    /// - Throws: NutritionAPIError if parsing fails
    private func parseSearchResponse(_ data: Data) throws -> [NutritionSearchResult] {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let response = try decoder.decode(FatSecretSearchResponse.self, from: data)
            
            // Handle case where no foods are found
            guard let foods = response.foods?.food else {
                return []
            }
            
            // Map FatSecret foods to NutritionSearchResult
            return foods.compactMap { food in
                // Extract calories from food description
                guard let calories = extractCalories(from: food.foodDescription) else {
                    return nil
                }
                
                // Parse serving information from description
                let (servingSize, servingUnit) = parseServingInfo(from: food.foodDescription)
                
                // Extract macro data from description
                let protein = extractMacro(from: food.foodDescription, macroName: "Protein")
                let carbs = extractMacro(from: food.foodDescription, macroName: "Carbs")
                let fats = extractMacro(from: food.foodDescription, macroName: "Fat")
                
                return NutritionSearchResult(
                    id: food.foodId,
                    name: food.foodName,
                    calories: calories,
                    servingSize: servingSize,
                    servingUnit: servingUnit,
                    brandName: food.brandName,
                    protein: protein,
                    carbohydrates: carbs,
                    fats: fats
                )
            }
        } catch {
            throw NutritionAPIError.invalidData
        }
    }
    
    /// Extracts calorie value from FatSecret food description string
    /// Format examples:
    /// - "Per 100g - Calories: 250kcal | Fat: 10.00g | Carbs: 30.00g | Protein: 8.00g"
    /// - "Per 1 serving - Calories: 150kcal | Fat: 5.00g"
    /// - Parameter description: The food description string
    /// - Returns: The calorie value, or nil if not found
    private func extractCalories(from description: String) -> Double? {
        // Look for pattern "Calories: XXXkcal" or "Calories: XXX kcal"
        let pattern = "Calories:\\s*(\\d+(?:\\.\\d+)?)\\s*kcal"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let nsString = description as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        guard let match = regex.firstMatch(in: description, options: [], range: range) else {
            return nil
        }
        
        // Extract the numeric value
        let calorieRange = match.range(at: 1)
        let calorieString = nsString.substring(with: calorieRange)
        
        return Double(calorieString)
    }
    
    /// Parses serving size and unit from food description
    /// Format: "Per 100g" or "Per 1 serving" or "Per 1 cup"
    /// - Parameter description: The food description string
    /// - Returns: Tuple of (servingSize, servingUnit) or (nil, nil) if not found
    private func parseServingInfo(from description: String) -> (String?, String?) {
        // Look for pattern "Per XXX unit" at the start
        let pattern = "Per\\s+(\\d+(?:\\.\\d+)?)\\s*([a-zA-Z]+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (nil, nil)
        }
        
        let nsString = description as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        guard let match = regex.firstMatch(in: description, options: [], range: range) else {
            return (nil, nil)
        }
        
        // Extract serving size and unit
        let sizeRange = match.range(at: 1)
        let unitRange = match.range(at: 2)
        
        let size = nsString.substring(with: sizeRange)
        let unit = nsString.substring(with: unitRange)
        
        return (size, unit)
    }
    
    /// Extracts a macro value (protein, carbs, or fat) from food description
    /// Format examples:
    /// - "Protein: 8.00g"
    /// - "Fat: 10.00g"
    /// - "Carbs: 30.00g"
    /// - Parameter description: The food description string
    /// - Parameter macroName: The name of the macro to extract (e.g., "Protein", "Fat", "Carbs")
    /// - Returns: The macro value in grams, or nil if not found
    private func extractMacro(from description: String, macroName: String) -> Double? {
        // Look for pattern "MacroName: XXXg" or "MacroName: XXX g"
        let pattern = "\(macroName):\\s*(\\d+(?:\\.\\d+)?)\\s*g"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let nsString = description as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        guard let match = regex.firstMatch(in: description, options: [], range: range) else {
            return nil
        }
        
        // Extract the numeric value
        let valueRange = match.range(at: 1)
        let valueString = nsString.substring(with: valueRange)
        
        return Double(valueString)
    }
}

// MARK: - FatSecret API Response Models

/// Response structure for FatSecret foods.search API
struct FatSecretSearchResponse: Codable {
    let foods: FatSecretFoods?
}

struct FatSecretFoods: Codable {
    let food: [FatSecretFood]?
}

struct FatSecretFood: Codable {
    let foodId: String
    let foodName: String
    let foodType: String
    let brandName: String?
    let foodDescription: String
}
