//
//  DailyLog.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var foodItems: [FoodItem]
    var dailyGoal: Double?
    
    var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }
    
    var remainingCalories: Double? {
        guard let goal = dailyGoal else { return nil }
        return goal - totalCalories
    }
    
    // Macro tracking computed properties
    var totalProtein: Double {
        foodItems.reduce(0) { $0 + ($1.protein ?? 0) }
    }
    
    var totalCarbohydrates: Double {
        foodItems.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }
    
    var totalFats: Double {
        foodItems.reduce(0) { $0 + ($1.fats ?? 0) }
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        foodItems: [FoodItem] = [],
        dailyGoal: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.foodItems = foodItems
        self.dailyGoal = dailyGoal
    }
}
