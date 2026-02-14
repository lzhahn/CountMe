//
//  AIRecipeParser.swift
//  CountMe
//
//  Actor for AI-powered recipe parsing using Google Gemini API
//

import Foundation
import os.log

/// Errors that can occur during AI recipe parsing
enum AIParserError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case parsingFailed
    case timeout
    case insufficientData
    case rateLimited
    
    /// Provides user-friendly error descriptions
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The AI service returned an invalid response. Please try again or enter ingredients manually."
        case .networkError(let error):
            return "Network error occurred: \(error.localizedDescription). Please check your internet connection."
        case .parsingFailed:
            return "Unable to parse the recipe. Please try again or enter ingredients manually."
        case .timeout:
            return "The request took too long to complete. Please check your internet connection and try again."
        case .insufficientData:
            return "Unable to extract enough information from the recipe description. Please provide more details or enter ingredients manually."
        case .rateLimited:
            return "AI service quota exceeded. Please wait a moment and try again, or enter ingredients manually."
        }
    }
}

/// Represents a parsed recipe with ingredients and confidence score
struct ParsedRecipe: Hashable {
    let ingredients: [ParsedIngredient]
    let confidence: Double  // 0.0 to 1.0
}

/// Represents a single parsed ingredient with nutritional data
struct ParsedIngredient: Hashable {
    let name: String
    let quantity: Double
    let unit: String
    let calories: Double
    let protein: Double?
    let carbohydrates: Double?
    let fats: Double?
}

/// Actor for thread-safe AI recipe parsing operations
actor AIRecipeParser {
    private let session: URLSession
    private let apiKey: String
    private let modelName: String
    private let baseURL: URL?
    private let logger = Logger(subsystem: "com.halu.CountMe", category: "AIRecipeParser")

    /// Initializes the AI recipe parser
    /// - Parameters:
    ///   - apiKey: Google Gemini API key (defaults to Secrets.googleGeminiAPIKey)
    ///   - modelName: Gemini model name (defaults to gemini-2.0-flash)
    ///   - baseURL: Optional override for the API base URL (useful for testing)
    ///   - session: URLSession for network requests (defaults to configured session with 60s timeout)
    init(
        apiKey: String = Secrets.googleGeminiAPIKey,
        modelName: String = "gemini-2.5-flash",
        baseURL: URL? = nil,
        session: URLSession? = nil
    ) {
        self.apiKey = apiKey
        self.modelName = modelName
        self.baseURL = baseURL
        
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60.0
            configuration.timeoutIntervalForResource = 60.0
            self.session = URLSession(configuration: configuration)
        }
    }
    
    /// Builds the full Gemini API endpoint URL
    private func buildEndpointURL() -> URL {
        if let baseURL = baseURL {
            return baseURL
        }
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)")!
    }
    
    /// Parses a recipe description into structured ingredients with nutritional data
    /// - Parameter description: Natural language recipe description (10-2000 characters)
    /// - Returns: ParsedRecipe with ingredients and confidence score
    /// - Throws: AIParserError if parsing fails
    func parseRecipe(description: String) async throws -> ParsedRecipe {
        try validateRecipeDescription(description)
        let sanitizedDescription = sanitizeInput(description)
        return try await parseWithRetry(sanitizedDescription, maxAttempts: 3)
    }
    
    /// Validates recipe description meets requirements
    private func validateRecipeDescription(_ description: String) throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count >= 10 else {
            throw AIParserError.insufficientData
        }
        
        guard trimmed.count <= 2000 else {
            throw AIParserError.invalidResponse
        }
        
        let alphanumericCount = trimmed.filter { $0.isLetter }.count
        guard alphanumericCount >= 5 else {
            throw AIParserError.insufficientData
        }
    }
    
    /// Sanitizes input to prevent prompt injection attacks
    private func sanitizeInput(_ input: String) -> String {
        var sanitized = input
            .replacingOccurrences(of: "\\n\\n", with: " ")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\"\"\"", with: "")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }
    
    /// Parses recipe with exponential backoff retry logic
    private func parseWithRetry(_ description: String, maxAttempts: Int) async throws -> ParsedRecipe {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await performParsing(description)
            } catch let error as AIParserError {
                lastError = error
                
                if case .insufficientData = error { throw error }
                if case .rateLimited = error { throw error }
                if case .timeout = error, attempt > 0 { throw error }
                
                if attempt < maxAttempts - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                throw AIParserError.networkError(error)
            }
        }
        
        throw lastError ?? AIParserError.parsingFailed
    }

    /// Performs the actual Gemini API parsing request
    private func performParsing(_ description: String) async throws -> ParsedRecipe {
        logger.info("=== STARTING AI RECIPE PARSING (Gemini) ===")
        logger.info("Recipe description: \(description)")
        logger.info("Model: \(self.modelName)")
        
        let endpoint = buildEndpointURL()
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = buildPrompt(for: description)
        
        // Build Gemini API request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 8192,
                "thinkingConfig": [
                    "thinkingBudget": 1024
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as NSError {
            if error.code == NSURLErrorTimedOut {
                throw AIParserError.timeout
            }
            throw AIParserError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIParserError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("HTTP \(httpResponse.statusCode) from Gemini API")
            if httpResponse.statusCode == 429 {
                throw AIParserError.rateLimited
            }
            throw AIParserError.invalidResponse
        }
        
        return try parseGeminiResponse(data)
    }
    
    /// Builds the structured prompt for AI parsing
    private func buildPrompt(for description: String) -> String {
        return """
        You are a nutrition data extraction assistant. Parse the following recipe description into structured ingredients with nutritional information.

        Recipe: "\(description)"

        CRITICAL REQUIREMENTS:
        1. Return ONLY valid JSON - no markdown, no explanations, no additional text
        2. Use the exact schema provided below
        3. Normalize ingredient names (e.g., "chicken breast" not "some chicken")
        4. Provide realistic nutritional estimates based on standard USDA data
        5. If you cannot determine nutritional data with confidence, omit optional fields
        6. All numeric values must be positive numbers (no negatives, no zero)

        REQUIRED JSON SCHEMA:
        {
          "ingredients": [
            {
              "name": "string (required, non-empty)",
              "quantity": number (required, positive),
              "unit": "string (required, one of: cup, tbsp, tsp, oz, lb, gram, kg, piece, serving, stalk, clove, bunch, slice, can, jar, bottle, package, or any other common unit)",
              "calories": number (required, positive),
              "protein": number (optional, grams),
              "carbohydrates": number (optional, grams),
              "fats": number (optional, grams)
            }
          ],
          "confidence": number (required, 0.0 to 1.0)
        }

        EXAMPLE INPUT: "chicken stir fry with rice and broccoli"

        EXAMPLE OUTPUT:
        {
          "ingredients": [
            {
              "name": "chicken breast",
              "quantity": 6,
              "unit": "oz",
              "calories": 187,
              "protein": 35,
              "carbohydrates": 0,
              "fats": 4
            },
            {
              "name": "white rice",
              "quantity": 1,
              "unit": "cup",
              "calories": 206,
              "protein": 4,
              "carbohydrates": 45,
              "fats": 0.4
            },
            {
              "name": "broccoli",
              "quantity": 1,
              "unit": "cup",
              "calories": 31,
              "protein": 2.5,
              "carbohydrates": 6,
              "fats": 0.3
            }
          ],
          "confidence": 0.9
        }

        Now parse this recipe:
        "\(description)"

        Return ONLY the JSON object, nothing else.
        """
    }

    /// Parses the Gemini API response into a ParsedRecipe
    private func parseGeminiResponse(_ data: Data) throws -> ParsedRecipe {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to parse Gemini response as JSON")
            throw AIParserError.invalidResponse
        }
        
        // Gemini response: candidates[0].content.parts[0].text
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            logger.error("Unexpected Gemini response structure")
            throw AIParserError.invalidResponse
        }
        
        let jsonString = extractJSON(from: text)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIParserError.parsingFailed
        }
        
        return try parseRecipeJSON(jsonData)
    }
    
    /// Extracts JSON from potentially malformed content
    private func extractJSON(from content: String) -> String {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }
        
        return cleaned
    }
    
    /// Parses and validates the recipe JSON structure
    private func parseRecipeJSON(_ data: Data) throws -> ParsedRecipe {
        let response: RecipeParseResponse
        do {
            response = try JSONDecoder().decode(RecipeParseResponse.self, from: data)
        } catch {
            logger.error("Failed to decode recipe JSON: \(error.localizedDescription)")
            throw AIParserError.parsingFailed
        }
        
        guard !response.ingredients.isEmpty else {
            throw AIParserError.insufficientData
        }
        
        guard response.confidence >= 0.0 && response.confidence <= 1.0 else {
            throw AIParserError.invalidResponse
        }
        
        guard response.ingredients.count <= 20 else {
            throw AIParserError.parsingFailed
        }
        
        for ingredient in response.ingredients {
            try validateIngredient(ingredient)
        }
        
        let parsedIngredients = response.ingredients.map { ingredient in
            ParsedIngredient(
                name: ingredient.name,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                calories: ingredient.calories,
                protein: ingredient.protein,
                carbohydrates: ingredient.carbohydrates,
                fats: ingredient.fats
            )
        }
        
        return ParsedRecipe(
            ingredients: parsedIngredients,
            confidence: response.confidence
        )
    }
    
    /// Validates a single ingredient's data
    private func validateIngredient(_ ingredient: AIIngredient) throws {
        guard !ingredient.name.isEmpty else {
            throw AIParserError.insufficientData
        }
        
        guard !ingredient.unit.isEmpty else {
            throw AIParserError.invalidResponse
        }
        
        guard ingredient.quantity > 0 else {
            throw AIParserError.invalidResponse
        }
        
        guard ingredient.calories >= 0 else {
            throw AIParserError.invalidResponse
        }
        
        if let protein = ingredient.protein, protein < 0 {
            throw AIParserError.invalidResponse
        }
        if let carbs = ingredient.carbohydrates, carbs < 0 {
            throw AIParserError.invalidResponse
        }
        if let fats = ingredient.fats, fats < 0 {
            throw AIParserError.invalidResponse
        }
    }
}

// MARK: - AI Response Models

/// Response structure for AI recipe parsing
struct RecipeParseResponse: Codable {
    let ingredients: [AIIngredient]
    let confidence: Double
}

/// AI-parsed ingredient structure
struct AIIngredient: Codable {
    let name: String
    let quantity: Double
    let unit: String
    let calories: Double
    let protein: Double?
    let carbohydrates: Double?
    let fats: Double?
}
