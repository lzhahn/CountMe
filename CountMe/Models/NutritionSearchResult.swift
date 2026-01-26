//
//  NutritionSearchResult.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation

/// Represents a nutrition search result from the FatSecret API
///
/// Contains basic nutritional information including calories and optional macro data.
/// Macro fields (protein, carbohydrates, fats) are optional as they may not always
/// be available in API responses.
struct NutritionSearchResult: Identifiable {
    let id: String
    let name: String
    let calories: Double
    let servingSize: String?
    let servingUnit: String?
    let brandName: String?
    
    // Macro tracking fields (optional, may not be available for all foods)
    let protein: Double?        // grams
    let carbohydrates: Double?  // grams
    let fats: Double?           // grams
}
