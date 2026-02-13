//
//  AIRecipeParser.swift
//  CountMe
//
//  Actor for AI-powered recipe parsing using Ollama (local LLM)
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
    private let endpoint: URL
    private let modelName: String
    private let logger = Logger(subsystem: "com.halu.CountMe", category: "AIRecipeParser")
    
    /// Initializes the AI recipe parser
    /// - Parameters:
    ///   - endpoint: API endpoint URL (defaults to local Ollama server)
    ///   - modelName: Ollama model name (defaults to gemma:4b)
    ///   - session: URLSession for network requests (defaults to configured session with 120s timeout)
    init(
        endpoint: URL? = nil,
        modelName: String = "gemma3:4b",
        session: URLSession? = nil
    ) {
        self.endpoint = endpoint ?? URL(string: "http://localhost:11434/api/generate")!
        self.modelName = modelName
        
        // Configure session with 120-second timeout if not provided
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 120.0
            configuration.timeoutIntervalForResource = 120.0
            self.session = URLSession(configuration: configuration)
        }
    }
    
    /// Parses a recipe description into structured ingredients with nutritional data
    /// - Parameter description: Natural language recipe description (10-2000 characters)
    /// - Returns: ParsedRecipe with ingredients and confidence score
    /// - Throws: AIParserError if parsing fails
    func parseRecipe(description: String) async throws -> ParsedRecipe {
        // Validate input
        try validateRecipeDescription(description)
        
        // Sanitize input to prevent prompt injection
        let sanitizedDescription = sanitizeInput(description)
        
        // Attempt parsing with retry logic
        return try await parseWithRetry(sanitizedDescription, maxAttempts: 3)
    }
    
    /// Validates recipe description meets requirements
    private func validateRecipeDescription(_ description: String) throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length constraints
        guard trimmed.count >= 10 else {
            throw AIParserError.insufficientData
        }
        
        guard trimmed.count <= 2000 else {
            throw AIParserError.invalidResponse
        }
        
        // Check for meaningful content (not just numbers or special characters)
        let alphanumericCount = trimmed.filter { $0.isLetter }.count
        guard alphanumericCount >= 5 else {
            throw AIParserError.insufficientData
        }
    }
    
    /// Sanitizes input to prevent prompt injection attacks
    private func sanitizeInput(_ input: String) -> String {
        // Remove potential prompt injection patterns
        var sanitized = input
            .replacingOccurrences(of: "\\n\\n", with: " ")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\"\"\"", with: "")
        
        // Trim whitespace
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
                
                // Don't retry on validation errors or insufficient data
                if case .insufficientData = error {
                    throw error
                }
                
                // Don't retry on timeout after first attempt
                if case .timeout = error, attempt > 0 {
                    throw error
                }
                
                // Exponential backoff: 1s, 2s, 4s
                if attempt < maxAttempts - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = error
                
                // Don't retry on unexpected errors
                throw AIParserError.networkError(error)
            }
        }
        
        // If all retries failed, throw the last error
        throw lastError ?? AIParserError.parsingFailed
    }
    
    /// Performs the actual AI parsing request
    private func performParsing(_ description: String) async throws -> ParsedRecipe {
        logger.info("=== STARTING AI RECIPE PARSING ===")
        logger.info("Recipe description: \(description)")
        logger.info("Endpoint: \(self.endpoint.absoluteString)")
        logger.info("Model: \(self.modelName)")
        
        // Build the request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the prompt
        let prompt = buildPrompt(for: description)
        
        logger.debug("=== PROMPT ===")
        logger.debug("\(prompt)")
        logger.debug("=== END PROMPT ===")
        
        // Build request body for Ollama generate API
        let requestBody: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 1000
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        if let requestData = request.httpBody,
           let requestString = String(data: requestData, encoding: .utf8) {
            logger.debug("=== REQUEST BODY ===")
            logger.debug("\(requestString)")
            logger.debug("=== END REQUEST BODY ===")
        }
        
        // Make the request
        let data: Data
        let response: URLResponse
        
        logger.info("🌐 Making request to Ollama...")
        
        do {
            (data, response) = try await session.data(for: request)
            logger.info("✅ Request completed successfully - Response size: \(data.count) bytes")
        } catch let error as NSError {
            logger.error("❌ ERROR: Network request failed - \(error.localizedDescription) (Code: \(error.code), Domain: \(error.domain))")
            
            // Handle timeout errors specifically
            if error.code == NSURLErrorTimedOut {
                throw AIParserError.timeout
            }
            throw AIParserError.networkError(error)
        }
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ ERROR: Response is not HTTPURLResponse")
            throw AIParserError.invalidResponse
        }
        
        logger.info("📊 HTTP Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("❌ ERROR: HTTP status code indicates failure: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("Error response body: \(errorString)")
            }
            throw AIParserError.invalidResponse
        }
        
        // Parse the response
        return try parseAIResponse(data)
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
    
    /// Parses the AI service response into a ParsedRecipe
    private func parseAIResponse(_ data: Data) throws -> ParsedRecipe {
        // Log the raw response data
        if let rawString = String(data: data, encoding: .utf8) {
            logger.debug("=== RAW OLLAMA RESPONSE ===")
            logger.debug("\(rawString)")
            logger.debug("=== END RAW RESPONSE ===")
        }
        
        // Parse Ollama response wrapper
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("❌ ERROR: Failed to parse response as JSON")
            throw AIParserError.invalidResponse
        }
        
        // Log the parsed JSON structure
        if let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            logger.debug("=== PARSED OLLAMA JSON ===")
            logger.debug("\(prettyString)")
            logger.debug("=== END PARSED JSON ===")
        }
        
        guard let content = json["response"] as? String else {
            logger.error("❌ ERROR: No 'response' field in JSON. Available keys: \(json.keys.joined(separator: ", "))")
            throw AIParserError.invalidResponse
        }
        
        logger.debug("=== EXTRACTED CONTENT ===")
        logger.debug("\(content)")
        logger.debug("=== END CONTENT ===")
        
        // Extract JSON from content (handle markdown blocks)
        let jsonString = extractJSON(from: content)
        
        logger.debug("=== CLEANED JSON STRING ===")
        logger.debug("\(jsonString)")
        logger.debug("=== END CLEANED JSON ===")
        
        // Parse the recipe JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            logger.error("❌ ERROR: Failed to convert cleaned JSON string to data")
            throw AIParserError.parsingFailed
        }
        
        return try parseRecipeJSON(jsonData)
    }
    
    /// Extracts JSON from potentially malformed content
    private func extractJSON(from content: String) -> String {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.debug("=== EXTRACTING JSON - STEP 1: Original ===")
        logger.debug("\(cleaned)")
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.debug("=== EXTRACTING JSON - STEP 2: After markdown removal ===")
        logger.debug("\(cleaned)")
        
        // Try to find JSON object boundaries - look for the outermost braces
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            let range = startIndex...endIndex
            cleaned = String(cleaned[range])
            
            logger.debug("=== EXTRACTING JSON - STEP 3: After brace extraction ===")
            logger.debug("\(cleaned)")
        }
        
        // Additional cleanup: remove any leading/trailing text
        if let firstBrace = cleaned.firstIndex(of: "{") {
            cleaned = String(cleaned[firstBrace...])
        }
        
        if let lastBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[...lastBrace])
        }
        
        logger.debug("=== EXTRACTING JSON - FINAL ===")
        logger.debug("\(cleaned)")
        
        return cleaned
    }
    
    /// Parses and validates the recipe JSON structure
    private func parseRecipeJSON(_ data: Data) throws -> ParsedRecipe {
        let decoder = JSONDecoder()
        
        // Decode the response
        let response: RecipeParseResponse
        do {
            response = try decoder.decode(RecipeParseResponse.self, from: data)
            logger.info("✅ Successfully decoded RecipeParseResponse - Ingredients: \(response.ingredients.count), Confidence: \(response.confidence)")
        } catch {
            logger.error("❌ ERROR: Failed to decode RecipeParseResponse - \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    logger.error("Missing key: \(key.stringValue) - \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    logger.error("Type mismatch: expected \(String(describing: type)) - \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    logger.error("Value not found: \(String(describing: type)) - \(context.debugDescription)")
                case .dataCorrupted(let context):
                    logger.error("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    logger.error("Unknown decoding error")
                }
            }
            throw AIParserError.parsingFailed
        }
        
        // Validate response
        guard !response.ingredients.isEmpty else {
            throw AIParserError.insufficientData
        }
        
        guard response.confidence >= 0.0 && response.confidence <= 1.0 else {
            throw AIParserError.invalidResponse
        }
        
        guard response.ingredients.count <= 20 else {
            throw AIParserError.parsingFailed
        }
        
        // Validate each ingredient
        for ingredient in response.ingredients {
            try validateIngredient(ingredient)
        }
        
        // Convert to ParsedIngredient objects
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
        // Validate name
        guard !ingredient.name.isEmpty else {
            logger.error("❌ ERROR: Ingredient has empty name")
            throw AIParserError.insufficientData
        }
        
        // Validate unit is not empty
        guard !ingredient.unit.isEmpty else {
            logger.error("❌ ERROR: Ingredient '\(ingredient.name)' has empty unit")
            throw AIParserError.invalidResponse
        }
        
        // Validate quantity
        guard ingredient.quantity > 0 else {
            logger.error("❌ ERROR: Ingredient '\(ingredient.name)' has invalid quantity: \(ingredient.quantity)")
            throw AIParserError.invalidResponse
        }
        
        // Validate calories (allow 0 for items like spices/extracts)
        guard ingredient.calories >= 0 else {
            logger.error("❌ ERROR: Ingredient '\(ingredient.name)' has negative calories: \(ingredient.calories)")
            throw AIParserError.invalidResponse
        }
        
        // Validate optional macros are non-negative if present
        if let protein = ingredient.protein, protein < 0 {
            logger.error("❌ ERROR: Ingredient '\(ingredient.name)' has negative protein: \(protein)")
            throw AIParserError.invalidResponse
        }
        if let carbs = ingredient.carbohydrates, carbs < 0 {
            logger.error("❌ ERROR: Ingredient '\(ingredient.name)' has negative carbs: \(carbs)")
            throw AIParserError.invalidResponse
        }
        if let fats = ingredient.fats, fats < 0 {
            logger.error("❌ ERROR: Ingredient '\(ingredient.name)' has negative fats: \(fats)")
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
