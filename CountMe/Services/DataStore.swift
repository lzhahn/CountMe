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
        
        print("💾 Saving daily log with \(log.foodItems.count) food items")
        
        modelContext.insert(log)
        try modelContext.save()
        
        print("✅ Daily log saved successfully")
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
    
    // MARK: - Exercise Item Mutation Operations
    
    /// Deletes an exercise item from a daily log
    /// - Parameters:
    ///   - item: The exercise item to delete
    ///   - log: The daily log containing the item
    func deleteExerciseItem(_ item: ExerciseItem, from log: DailyLog) async throws {
        if let index = log.exerciseItems.firstIndex(where: { $0.id == item.id }) {
            log.exerciseItems.remove(at: index)
            try modelContext.save()
        }
    }
    
    /// Updates an exercise item in a daily log
    /// - Parameters:
    ///   - item: The exercise item with updated values
    ///   - log: The daily log containing the item
    func updateExerciseItem(_ item: ExerciseItem, in log: DailyLog) async throws {
        if let index = log.exerciseItems.firstIndex(where: { $0.id == item.id }) {
            log.exerciseItems[index] = item
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
                meal._id == id
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
    
    // MARK: - Migration Support Operations
    
    /// Fetches all daily logs from persistent storage
    ///
    /// Returns all daily logs regardless of date, sorted by date in ascending order.
    /// Used primarily for data migration when a user creates an account.
    ///
    /// - Returns: Array of all daily logs sorted by date (ascending)
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchAllDailyLogs() async throws -> [DailyLog] {
        let descriptor = FetchDescriptor<DailyLog>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches all food items from persistent storage
    ///
    /// Returns all food items regardless of which daily log they belong to.
    /// Used primarily for data migration when a user creates an account.
    ///
    /// - Returns: Array of all food items sorted by timestamp (ascending)
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchAllFoodItems() async throws -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches all exercise items from persistent storage
    ///
    /// Returns all exercise items regardless of which daily log they belong to.
    /// Used primarily for data migration when a user creates an account.
    ///
    /// - Returns: Array of all exercise items sorted by timestamp (ascending)
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchAllExerciseItems() async throws -> [ExerciseItem] {
        let descriptor = FetchDescriptor<ExerciseItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Updates a food item's sync-related properties
    ///
    /// Updates the userId, lastModified, and syncStatus for a food item.
    /// Used during migration to associate anonymous local data with a user account.
    ///
    /// - Parameter item: The food item to update
    /// - Throws: SwiftData errors if save operation fails
    func updateFoodItem(_ item: FoodItem) async throws {
        try modelContext.save()
    }
    
    /// Updates a daily log's sync-related properties
    ///
    /// Updates the userId, lastModified, and syncStatus for a daily log.
    /// Used during migration to associate anonymous local data with a user account.
    ///
    /// - Parameter log: The daily log to update
    /// - Throws: SwiftData errors if save operation fails
    func updateDailyLog(_ log: DailyLog) async throws {
        // Normalize the date to ensure consistent date-based lookups
        log.date = normalizeDate(log.date)
        try modelContext.save()
    }
    
    /// Updates an exercise item's sync-related properties
    ///
    /// Updates the userId, lastModified, and syncStatus for an exercise item.
    /// Used during migration to associate anonymous local data with a user account.
    ///
    /// - Parameter item: The exercise item to update
    /// - Throws: SwiftData errors if save operation fails
    func updateExerciseItem(_ item: ExerciseItem) async throws {
        try modelContext.save()
    }
    
    /// Fetches a food item by its unique identifier
    ///
    /// - Parameter id: The unique identifier string of the food item
    /// - Returns: The food item with the specified ID, or nil if not found
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchFoodItem(byId id: String) async throws -> FoodItem? {
        // Convert String ID to UUID for predicate comparison
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { item in
                item._id == uuid
            }
        )
        
        let items = try modelContext.fetch(descriptor)
        return items.first
    }
    
    /// Fetches an exercise item by its unique identifier
    ///
    /// - Parameter id: The unique identifier string of the exercise item
    /// - Returns: The exercise item with the specified ID, or nil if not found
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchExerciseItem(byId id: String) async throws -> ExerciseItem? {
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<ExerciseItem>(
            predicate: #Predicate { item in
                item._id == uuid
            }
        )
        
        let items = try modelContext.fetch(descriptor)
        return items.first
    }
    
    /// Fetches a daily log by its unique identifier
    ///
    /// - Parameter id: The unique identifier string of the daily log
    /// - Returns: The daily log with the specified ID, or nil if not found
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchDailyLog(byId id: String) async throws -> DailyLog? {
        // Convert String ID to UUID for predicate comparison
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log._id == uuid
            }
        )
        
        let logs = try modelContext.fetch(descriptor)
        return logs.first
    }
    
    /// Fetches a custom meal by its unique identifier string
    ///
    /// - Parameter id: The unique identifier string of the custom meal
    /// - Returns: The custom meal with the specified ID, or nil if not found
    /// - Throws: SwiftData errors if fetch operation fails
    func fetchCustomMeal(byId id: String) async throws -> CustomMeal? {
        // Convert String ID to UUID for predicate comparison
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<CustomMeal>(
            predicate: #Predicate { meal in
                meal._id == uuid
            }
        )
        
        let meals = try modelContext.fetch(descriptor)
        return meals.first
    }
    
    /// Inserts a new food item into persistent storage
    ///
    /// - Parameter item: The food item to insert
    /// - Throws: SwiftData errors if insert operation fails
    func insertFoodItem(_ item: FoodItem) async throws {
        modelContext.insert(item)
        try modelContext.save()
    }
    
    /// Inserts a new exercise item into persistent storage
    ///
    /// - Parameter item: The exercise item to insert
    /// - Throws: SwiftData errors if insert operation fails
    func insertExerciseItem(_ item: ExerciseItem) async throws {
        modelContext.insert(item)
        try modelContext.save()
    }
    
    /// Inserts a new daily log into persistent storage
    ///
    /// - Parameter log: The daily log to insert
    /// - Throws: SwiftData errors if insert operation fails
    func insertDailyLog(_ log: DailyLog) async throws {
        // Normalize the date to ensure consistent date-based lookups
        log.date = normalizeDate(log.date)
        modelContext.insert(log)
        try modelContext.save()
    }
    
    /// Inserts a new custom meal into persistent storage
    ///
    /// - Parameter meal: The custom meal to insert
    /// - Throws: SwiftData errors if insert operation fails
    func insertCustomMeal(_ meal: CustomMeal) async throws {
        modelContext.insert(meal)
        try modelContext.save()
    }
    
    /// Deletes a food item by its unique identifier
    ///
    /// - Parameter id: The unique identifier of the food item to delete
    /// - Throws: SwiftData errors if delete operation fails
    func deleteFoodItem(byId id: String) async throws {
        if let item = try await fetchFoodItem(byId: id) {
            modelContext.delete(item)
            try modelContext.save()
        }
    }
    
    /// Deletes an exercise item by its unique identifier
    ///
    /// - Parameter id: The unique identifier of the exercise item to delete
    /// - Throws: SwiftData errors if delete operation fails
    func deleteExerciseItem(byId id: String) async throws {
        if let item = try await fetchExerciseItem(byId: id) {
            modelContext.delete(item)
            try modelContext.save()
        }
    }
    
    /// Deletes a daily log by its unique identifier
    ///
    /// - Parameter id: The unique identifier of the daily log to delete
    /// - Throws: SwiftData errors if delete operation fails
    func deleteDailyLog(byId id: String) async throws {
        if let log = try await fetchDailyLog(byId: id) {
            modelContext.delete(log)
            try modelContext.save()
        }
    }
    
    /// Deletes a custom meal by its unique identifier
    ///
    /// - Parameter id: The unique identifier of the custom meal to delete
    /// - Throws: SwiftData errors if delete operation fails
    func deleteCustomMeal(byId id: String) async throws {
        if let meal = try await fetchCustomMeal(byId: id) {
            modelContext.delete(meal)
            try modelContext.save()
        }
    }
    
    // MARK: - Account Deletion Support
    
    /// Deletes all local data from persistent storage
    ///
    /// Removes all entities from the local SwiftData store. This is called
    /// during account deletion to ensure complete data removal from the device.
    /// The method deletes:
    /// - All food items
    /// - All daily logs (which cascade deletes associated food items)
    /// - All custom meals
    ///
    /// This operation is irreversible and should only be called after user confirmation.
    ///
    /// - Throws: SwiftData errors if deletion fails
    ///
    /// **Validates: Requirements 14.4 (Clear All Local Data)**
    func deleteAllLocalData() async throws {
        print("🗑️ Starting deletion of all local data...")
        
        // Delete all daily logs (cascade deletes associated food items)
        let dailyLogsDescriptor = FetchDescriptor<DailyLog>()
        let dailyLogs = try modelContext.fetch(dailyLogsDescriptor)
        
        for log in dailyLogs {
            modelContext.delete(log)
        }
        
        print("✓ Deleted \(dailyLogs.count) daily logs from local storage")
        
        // Delete all food items (in case any exist without a daily log)
        let foodItemsDescriptor = FetchDescriptor<FoodItem>()
        let foodItems = try modelContext.fetch(foodItemsDescriptor)
        
        for item in foodItems {
            modelContext.delete(item)
        }
        
        print("✓ Deleted \(foodItems.count) food items from local storage")
        
        // Delete all custom meals
        let customMealsDescriptor = FetchDescriptor<CustomMeal>()
        let customMeals = try modelContext.fetch(customMealsDescriptor)
        
        for meal in customMeals {
            modelContext.delete(meal)
        }
        
        print("✓ Deleted \(customMeals.count) custom meals from local storage")
        
        // Save all deletions
        try modelContext.save()
        
        print("✅ Successfully deleted all local data")
    }
    
    // MARK: - Sign-Out Support
    
    /// Resets sync status for all local data on sign-out
    ///
    /// Clears the userId and resets syncStatus to pendingUpload for all entities
    /// when a user signs out. This ensures:
    /// 1. Local data is retained for potential future sign-in
    /// 2. Data will be re-synced when the user signs in again
    /// 3. No data is lost during sign-out
    ///
    /// The method updates:
    /// - All food items: clears userId, sets syncStatus to pendingUpload
    /// - All daily logs: clears userId, sets syncStatus to pendingUpload
    /// - All custom meals: clears userId, sets syncStatus to pendingUpload
    ///
    /// This operation is called automatically when a user signs out and is
    /// reversible - data can be re-associated with a user on next sign-in.
    ///
    /// - Throws: SwiftData errors if update operation fails
    ///
    /// **Validates: Requirements 3.3 (Property 11: Sign Out Retains Local Data)**
    func resetSyncStatusOnSignOut() async throws {
        print("🔄 Resetting sync status for all local data on sign-out...")
        
        // Reset food items
        let foodItemsDescriptor = FetchDescriptor<FoodItem>()
        let foodItems = try modelContext.fetch(foodItemsDescriptor)
        
        for item in foodItems {
            item.userId = ""
            item.syncStatus = .pendingUpload
        }
        
        print("✓ Reset sync status for \(foodItems.count) food items")
        
        // Reset daily logs
        let dailyLogsDescriptor = FetchDescriptor<DailyLog>()
        let dailyLogs = try modelContext.fetch(dailyLogsDescriptor)
        
        for log in dailyLogs {
            log.userId = ""
            log.syncStatus = .pendingUpload
        }
        
        print("✓ Reset sync status for \(dailyLogs.count) daily logs")
        
        // Reset custom meals
        let customMealsDescriptor = FetchDescriptor<CustomMeal>()
        let customMeals = try modelContext.fetch(customMealsDescriptor)
        
        for meal in customMeals {
            meal.userId = ""
            meal.syncStatus = .pendingUpload
        }
        
        print("✓ Reset sync status for \(customMeals.count) custom meals")
        
        // Save all changes
        try modelContext.save()
        
        print("✅ Successfully reset sync status for all local data")
    }
}
