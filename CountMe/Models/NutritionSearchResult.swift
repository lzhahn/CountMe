//
//  NutritionSearchResult.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation

struct NutritionSearchResult: Identifiable {
    let id: String
    let name: String
    let calories: Double
    let servingSize: String?
    let servingUnit: String?
    let brandName: String?
}
