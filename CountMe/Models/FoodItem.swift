//
//  FoodItem.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var calories: Double
    var timestamp: Date
    var servingSize: String?
    var servingUnit: String?
    var source: FoodItemSource
    
    // Macro tracking fields (optional for backward compatibility)
    var protein: Double?
    var carbohydrates: Double?
    var fats: Double?
    
    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        timestamp: Date = Date(),
        servingSize: String? = nil,
        servingUnit: String? = nil,
        source: FoodItemSource = .manual,
        protein: Double? = nil,
        carbohydrates: Double? = nil,
        fats: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.timestamp = timestamp
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.source = source
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fats = fats
    }
}
