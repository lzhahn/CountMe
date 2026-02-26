//
//  NutritionAPIClient.swift
//  CountMe
//
//  Actor for interacting with the OpenFoodFacts API
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

/// Actor for thread-safe nutrition API operations using OpenFoodFacts
actor NutritionAPIClient {
    private let session: URLSession
    private let userAgent: String
    
    private let baseURL = "https://world.openfoodfacts.org"
    
    /// Initializes the nutrition API client
    /// - Parameters:
    ///   - userAgent: User-Agent string for API requests (required by OpenFoodFacts)
    ///   - session: URLSession for network requests (defaults to configured session with 30s timeout)
    init(
        userAgent: String = "CountMe/1.0 (iOS calorie tracker)",
        session: URLSession? = nil
    ) {
        self.userAgent = userAgent
        
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30.0
            configuration.timeoutIntervalForResource = 30.0
            self.session = URLSession(configuration: configuration)
        }
    }
    
    /// Searches for food items by name using OpenFoodFacts
    ///
    /// Sends the query to the OpenFoodFacts API and returns matching products.
    /// OpenFoodFacts is a global, community-driven food database with barcode support.
    ///
    /// - Parameter query: The search query string (e.g., "trader joes yogurt")
    /// - Returns: Array of nutrition search results sorted by relevance (max 25)
    /// - Throws: NutritionAPIError if the request fails
    func searchFood(query: String) async throws -> [NutritionSearchResult] {
        let searchURL = "\(baseURL)/cgi/search.pl"
        
        guard var urlComponents = URLComponents(string: searchURL) else {
            throw NutritionAPIError.invalidResponse
        }
        
        // OpenFoodFacts search parameters
        let queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "50"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,serving_size,serving_quantity,serving_quantity_unit,quantity")
        ]
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NutritionAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as NSError {
            if error.code == NSURLErrorTimedOut {
                throw NutritionAPIError.timeout
            }
            throw NutritionAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw NutritionAPIError.rateLimitExceeded
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NutritionAPIError.invalidResponse
        }
        
        let results = try parseSearchResponse(data)
        
        // Apply simple client-side relevance ranking
        return rankSearchResults(results, query: query)
    }
    
    /// Parses the OpenFoodFacts search response into NutritionSearchResult objects
    private func parseSearchResponse(_ data: Data) throws -> [NutritionSearchResult] {
        do {
            let response = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
            
            guard let products = response.products else {
                return []
            }
            
            return products.compactMap { product in
                // Extract calories from nutriments
                guard let nutriments = product.nutriments,
                      let calories = nutriments.energyKcal ?? nutriments.energy else {
                    return nil
                }
                
                // Validate calories are non-negative
                guard calories >= 0 else {
                    return nil
                }
                
                // Extract macros
                let protein = nutriments.proteins
                let carbs = nutriments.carbohydrates
                let fat = nutriments.fat
                
                // Build serving info
                let servingSize: String?
                let servingUnit: String?
                
                if let servingQuantity = product.servingQuantity {
                    servingSize = String(format: "%.0f", servingQuantity)
                    servingUnit = product.servingQuantityUnit ?? "g"
                } else if let servingSizeStr = product.servingSize {
                    // Parse serving size string (e.g., "100g", "1 cup")
                    servingSize = servingSizeStr
                    servingUnit = nil
                } else {
                    servingSize = "100"
                    servingUnit = "g"
                }
                
                // Parse serving options
                var servingOptions: [ServingOption] = []
                
                // Add default 100g option
                servingOptions.append(ServingOption(description: "100g", gramWeight: 100))
                
                // Add serving size option if available
                if let servingQuantity = product.servingQuantity {
                    let unit = product.servingQuantityUnit ?? "g"
                    let description = "\(String(format: "%.0f", servingQuantity))\(unit)"
                    servingOptions.append(ServingOption(description: description, gramWeight: servingQuantity))
                }
                
                // Parse quantity field for additional serving info (e.g., "3 x 150 g")
                if let quantity = product.quantity, !quantity.isEmpty {
                    // Try to extract gram weight from quantity string
                    if let gramWeight = extractGramWeight(from: quantity) {
                        servingOptions.append(ServingOption(description: quantity, gramWeight: gramWeight))
                    }
                }
                
                // Remove duplicates based on description
                servingOptions = servingOptions.reduce(into: [ServingOption]()) { result, option in
                    if !result.contains(where: { $0.description.lowercased() == option.description.lowercased() }) {
                        result.append(option)
                    }
                }
                
                return NutritionSearchResult(
                    id: product.code ?? UUID().uuidString,
                    name: product.productName?.capitalized(with: .current) ?? "Unknown Product",
                    calories: calories,
                    servingSize: servingSize,
                    servingUnit: servingUnit,
                    brandName: product.brands,
                    protein: protein,
                    carbohydrates: carbs,
                    fats: fat,
                    servingOptions: servingOptions
                )
            }
        } catch {
            throw NutritionAPIError.invalidData
        }
    }
    
    /// Extracts gram weight from quantity string (e.g., "3 x 150 g" -> 150)
    private func extractGramWeight(from quantity: String) -> Double? {
        // Look for patterns like "150g", "150 g", "3 x 150g"
        let pattern = #"(\d+(?:\.\d+)?)\s*g"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let nsString = quantity as NSString
        let matches = regex.matches(in: quantity, range: NSRange(location: 0, length: nsString.length))
        
        if let match = matches.first, match.numberOfRanges > 1 {
            let numberRange = match.range(at: 1)
            let numberString = nsString.substring(with: numberRange)
            return Double(numberString)
        }
        
        return nil
    }
}

// MARK: - OpenFoodFacts API Response Models

struct OpenFoodFactsSearchResponse: Codable {
    let count: Int?
    let page: Int?
    let pageSize: Int?
    let products: [OpenFoodFactsProduct]?
    
    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageSize = "page_size"
        case products
    }
}

struct OpenFoodFactsProduct: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let quantity: String?
    let servingSize: String?
    let servingQuantity: Double?
    let servingQuantityUnit: String?
    let nutriments: OpenFoodFactsNutriments?
    
    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case quantity
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
        case nutriments
    }
}

struct OpenFoodFactsNutriments: Codable {
    let energy: Double?
    let energyKcal: Double?
    let proteins: Double?
    let carbohydrates: Double?
    let fat: Double?
    
    enum CodingKeys: String, CodingKey {
        case energy
        case energyKcal = "energy-kcal"
        case proteins
        case carbohydrates
        case fat
    }
}

// MARK: - Search Result Ranking

extension NutritionAPIClient {
    /// Ranks search results by relevance to the query
    ///
    /// Simple scoring algorithm:
    /// - Returns results as-is from OpenFoodFacts API (they handle relevance)
    /// - Filters out results with no calories
    /// - Limits to top 25 results
    ///
    /// - Parameters:
    ///   - results: Raw search results from API
    ///   - query: User's search query (unused, kept for compatibility)
    /// - Returns: Filtered results (max 25)
    private func rankSearchResults(_ results: [NutritionSearchResult], query: String) -> [NutritionSearchResult] {
        // OpenFoodFacts API already returns results in relevance order
        // Just filter out invalid results and limit to 25
        return results
            .filter { $0.calories >= 0 } // Filter out invalid data
            .prefix(25)
            .map { $0 }
    }
}
