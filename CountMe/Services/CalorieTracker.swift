//
//  CalorieTracker.swift
//  CountMe
//
//  Business logic layer for calorie tracking functionality
//

import Foundation
import Observation

/// Observable business logic class that coordinates calorie tracking operations
/// between the data store, API client, and UI layer.
///
/// This class manages:
/// - Current daily log state
/// - Food item CRUD operations
/// - Daily goal management
/// - Nutrition API search integration
/// - Date-based log navigation
///
/// Thread Safety: This class is marked @Observable and should be accessed from the main actor.
/// It coordinates with actor-based DataStore and NutritionAPIClient for thread-safe operations.
@Observable
@MainActor
class CalorieTracker {
    // MARK: - Dependencies
    
    private let dataStore: DataStore
    private let apiClient: NutritionAPIClient
    
    // MARK: - Published State
    
    /// The currently loaded daily log
    var currentLog: DailyLog?
    
    /// The date for which the current log is loaded
    var selectedDate: Date
    
    /// Loading state for UI feedback
    var isLoading: Bool = false
    
    /// Error message for UI display
    var errorMessage: String?
    
    /// The last date we checked for date transitions (normalized to start of day)
    private var lastCheckedDate: Date
    
    // MARK: - Initialization
    
    /// Initializes the CalorieTracker with required dependencies
    /// - Parameters:
    ///   - dataStore: Actor for persistence operations
    ///   - apiClient: Actor for nutrition API operations
    ///   - selectedDate: Initial date to load (defaults to today)
    init(
        dataStore: DataStore,
        apiClient: NutritionAPIClient,
        selectedDate: Date = Date()
    ) {
        self.dataStore = dataStore
        self.apiClient = apiClient
        self.selectedDate = selectedDate
        self.lastCheckedDate = Calendar.current.startOfDay(for: Date())
    }
    
    // MARK: - Daily Log Operations
    
    /// Checks if the date has changed since the last check and handles the transition
    /// This should be called when the app comes to foreground
    /// - Throws: Persistence errors from DataStore
    func checkForDateChange() async throws {
        let currentDate = Calendar.current.startOfDay(for: Date())
        
        // Check if the date has changed
        if currentDate != lastCheckedDate {
            // Date has changed, load the log for the new date
            try await loadLog(for: currentDate)
            lastCheckedDate = currentDate
        }
    }
    
    /// Loads the daily log for a specific date
    /// Creates a new log if one doesn't exist for the date
    /// - Parameter date: The date to load the log for
    /// - Throws: Persistence errors from DataStore
    func loadLog(for date: Date) async throws {
        isLoading = true
        errorMessage = nil
        selectedDate = date
        
        do {
            // Try to fetch existing log
            if let existingLog = try await dataStore.fetchDailyLog(for: date) {
                currentLog = existingLog
            } else {
                // Create new log for this date
                let newLog = DailyLog(date: date)
                try await dataStore.saveDailyLog(newLog)
                currentLog = newLog
            }
            
            // Update last checked date to the normalized date
            lastCheckedDate = Calendar.current.startOfDay(for: date)
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load daily log: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Gets the current daily total calories
    /// - Returns: Total calories for the current log, or 0 if no log is loaded
    func getCurrentDailyTotal() -> Double {
        return currentLog?.totalCalories ?? 0.0
    }
    
    /// Gets the remaining calories until the daily goal
    /// - Returns: Remaining calories, or nil if no goal is set
    func getRemainingCalories() -> Double? {
        return currentLog?.remainingCalories
    }
    
    // MARK: - Food Item Management
    
    /// Adds a food item to the current daily log
    /// - Parameter item: The food item to add
    /// - Throws: Error if no current log is loaded or persistence fails
    func addFoodItem(_ item: FoodItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            // Add item to the log's food items array
            log.foodItems.append(item)
            
            // Persist the change
            try await dataStore.saveDailyLog(log)
            
            // Trigger UI update by reassigning currentLog
            currentLog = log
        } catch {
            errorMessage = "Failed to add food item: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Removes a food item from the current daily log
    /// - Parameter item: The food item to remove
    /// - Throws: Error if no current log is loaded or persistence fails
    func removeFoodItem(_ item: FoodItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            // Delete through data store to ensure proper persistence
            try await dataStore.deleteFoodItem(item, from: log)
            
            // Trigger UI update by reassigning currentLog
            currentLog = log
        } catch {
            errorMessage = "Failed to remove food item: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Updates an existing food item in the current daily log
    /// - Parameter item: The food item with updated values
    /// - Throws: Error if no current log is loaded or persistence fails
    func updateFoodItem(_ item: FoodItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            // Update through data store to ensure proper persistence
            try await dataStore.updateFoodItem(item, in: log)
            
            // Trigger UI update by reassigning currentLog
            currentLog = log
        } catch {
            errorMessage = "Failed to update food item: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Goal Management
    
    /// Sets the daily calorie goal for the current log
    /// - Parameter calories: The target calorie goal (must be positive)
    /// - Throws: Error if no current log is loaded, invalid goal, or persistence fails
    func setDailyGoal(_ calories: Double) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        guard calories > 0 else {
            throw CalorieTrackerError.invalidGoal
        }
        
        errorMessage = nil
        
        do {
            // Update the goal
            log.dailyGoal = calories
            
            // Persist the change
            try await dataStore.saveDailyLog(log)
            
            // Trigger UI update by reassigning currentLog
            currentLog = log
        } catch {
            errorMessage = "Failed to set daily goal: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Nutrition API Search
    
    /// Searches for food items using the nutrition API
    /// - Parameter query: The search query string
    /// - Returns: Array of nutrition search results
    /// - Throws: NutritionAPIError if the search fails
    func searchFood(query: String) async throws -> [NutritionSearchResult] {
        guard !query.isEmpty else {
            return []
        }
        
        errorMessage = nil
        
        do {
            return try await apiClient.searchFood(query: query)
        } catch let error as NutritionAPIError {
            errorMessage = error.errorDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred during search"
            throw error
        }
    }
}

// MARK: - Error Types

/// Errors specific to CalorieTracker operations
enum CalorieTrackerError: Error, LocalizedError {
    case noCurrentLog
    case invalidGoal
    
    var errorDescription: String? {
        switch self {
        case .noCurrentLog:
            return "No daily log is currently loaded. Please load a log first."
        case .invalidGoal:
            return "Daily goal must be a positive number."
        }
    }
}
