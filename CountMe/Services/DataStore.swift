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
}
