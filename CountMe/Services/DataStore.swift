//
//  DataStore.swift
//  CountMe
//
//  Created by Kiro on 1/19/26.
//

import Foundation
import SwiftData

actor DataStore {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Date Normalization
    
    /// Normalizes a date to midnight (start of day) in the current timezone
    private func normalizeDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date)
    }
    
    // MARK: - Daily Log Operations
    
    /// Fetches the daily log for a specific date
    /// - Parameter date: The date to fetch the log for (will be normalized to midnight)
    /// - Returns: The daily log for that date, or nil if none exists
    func fetchDailyLog(for date: Date) async throws -> DailyLog? {
        let normalizedDate = normalizeDate(date)
        
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date == normalizedDate
            }
        )
        
        let logs = try modelContext.fetch(descriptor)
        return logs.first
    }
    
    /// Saves a daily log to persistent storage
    /// - Parameter log: The daily log to save
    func saveDailyLog(_ log: DailyLog) async throws {
        // Normalize the log's date to ensure consistency
        log.date = normalizeDate(log.date)
        
        modelContext.insert(log)
        try modelContext.save()
    }
    
    /// Fetches historical logs within a date range
    /// - Parameters:
    ///   - from: Start date (inclusive)
    ///   - to: End date (inclusive)
    /// - Returns: Array of daily logs within the date range, sorted by date
    func fetchHistoricalLogs(from startDate: Date, to endDate: Date) async throws -> [DailyLog] {
        let normalizedStart = normalizeDate(startDate)
        let normalizedEnd = normalizeDate(endDate)
        
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date >= normalizedStart && log.date <= normalizedEnd
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Food Item Mutation Operations
    
    /// Deletes a food item from a daily log
    /// - Parameters:
    ///   - item: The food item to delete
    ///   - log: The daily log containing the item
    func deleteFoodItem(_ item: FoodItem, from log: DailyLog) async throws {
        if let index = log.foodItems.firstIndex(where: { $0.id == item.id }) {
            log.foodItems.remove(at: index)
            try modelContext.save()
        }
    }
    
    /// Updates a food item in a daily log
    /// - Parameters:
    ///   - item: The food item with updated values
    ///   - log: The daily log containing the item
    func updateFoodItem(_ item: FoodItem, in log: DailyLog) async throws {
        if let index = log.foodItems.firstIndex(where: { $0.id == item.id }) {
            log.foodItems[index] = item
            try modelContext.save()
        }
    }
    
    // MARK: - Custom Meal Operations
    
    /// Fetches all saved custom meals sorted by most recently used
    ///
    /// Returns all custom meals from persistent storage, ordered by lastUsedAt
    /// in descending order (most recent first). This ensures users see their
    /// frequently used meals at the top of the list.
    ///
    /// - Returns: Array of custom meals sorted by lastUsedAt (descending)
    /// - Throws: SwiftData errors if fetch operation fails
    ///
    /// **Validates: Requirements 2.1, 2.2**
    func fetchAllCustomMeals() async throws -> [CustomMeal] {
        let descriptor = FetchDescriptor<CustomMeal>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches a specific custom meal by its unique identifier
    ///
    /// - Parameter id: The UUID of the custom meal to retrieve
    /// - Returns: The custom meal with the specified ID, or nil if not found
    /// - Throws: SwiftData errors if fetch operation fails
    ///
    /// **Validates: Requirement 2.1**
    func fetchCustomMeal(id: UUID) async throws -> CustomMeal? {
        let descriptor = FetchDescriptor<CustomMeal>(
            predicate: #Predicate { meal in
                meal.id == id
            }
        )
        
        let meals = try modelContext.fetch(descriptor)
        return meals.first
    }
    
    /// Saves a new custom meal to persistent storage
    ///
    /// Persists a custom meal with all its ingredient details and nutritional
    /// information. The meal becomes available for browsing and adding to daily logs.
    ///
    /// - Parameter meal: The custom meal to persist
    /// - Throws: SwiftData errors if save operation fails
    ///
    /// **Validates: Requirement 2.1**
    func saveCustomMeal(_ meal: CustomMeal) async throws {
        modelContext.insert(meal)
        try modelContext.save()
    }
    
    /// Updates an existing custom meal in persistent storage
    ///
    /// Updates the custom meal's data including ingredients, name, and timestamps.
    /// Note: This does not affect previously logged meal instances (Property 6).
    ///
    /// - Parameter meal: The custom meal with updated values
    /// - Throws: SwiftData errors if save operation fails
    ///
    /// **Validates: Requirement 2.4**
    func updateCustomMeal(_ meal: CustomMeal) async throws {
        try modelContext.save()
    }
    
    /// Deletes a custom meal and all associated ingredients
    ///
    /// Removes the custom meal from persistent storage with cascade deletion
    /// of all ingredients. This ensures no orphaned ingredient records remain.
    /// Previously logged meal instances in daily logs are not affected.
    ///
    /// - Parameter meal: The custom meal to delete
    /// - Throws: SwiftData errors if delete operation fails
    ///
    /// **Validates: Requirements 2.3 (Property 5: Cascade Deletion Completeness)**
    func deleteCustomMeal(_ meal: CustomMeal) async throws {
        modelContext.delete(meal)
        try modelContext.save()
    }
    
    /// Searches custom meals by name with case-insensitive filtering
    ///
    /// Returns all custom meals whose names contain the search query (case-insensitive).
    /// Results are sorted by lastUsedAt in descending order (most recent first).
    /// An empty query returns all custom meals.
    ///
    /// - Parameter query: The search string to filter meal names
    /// - Returns: Array of matching custom meals sorted by lastUsedAt (descending)
    /// - Throws: SwiftData errors if fetch operation fails
    ///
    /// **Validates: Requirements 12.1, 12.2 (Property 20: Custom Meal Search Correctness)**
    func searchCustomMeals(query: String) async throws -> [CustomMeal] {
        // If query is empty, return all meals
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return try await fetchAllCustomMeals()
        }
        
        let lowercaseQuery = query.lowercased()
        
        let descriptor = FetchDescriptor<CustomMeal>(
            predicate: #Predicate { meal in
                meal.name.localizedStandardContains(lowercaseQuery)
            },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
}
