//
//  CalorieTracker.swift
//  CountMe
//
//  Business logic layer for calorie tracking functionality
//

import Foundation
import Observation

/// Observable business logic class that coordinates calorie tracking operations
/// between the data store, API client, sync engine, and UI layer.
///
/// This class manages:
/// - Current daily log state
/// - Food item CRUD operations
/// - Daily goal management
/// - Nutrition API search integration
/// - Date-based log navigation
/// - Cloud synchronization when authenticated
///
/// Thread Safety: This class is marked @Observable and should be accessed from the main actor.
/// It coordinates with actor-based DataStore, NutritionAPIClient, and FirebaseSyncEngine for thread-safe operations.
///
/// **Validates: Requirements 5.1, 5.4, 5.5**
@Observable
@MainActor
class CalorieTracker {
    // MARK: - Dependencies
    
    private let dataStore: DataStore
    private let apiClient: NutritionAPIClient
    private var syncEngine: FirebaseSyncEngine?
    private var userId: String?
    
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
    ///   - syncEngine: Optional sync engine for cloud synchronization
    ///   - userId: Optional authenticated user ID for sync operations
    init(
        dataStore: DataStore,
        apiClient: NutritionAPIClient,
        selectedDate: Date = Date(),
        syncEngine: FirebaseSyncEngine? = nil,
        userId: String? = nil
    ) {
        self.dataStore = dataStore
        self.apiClient = apiClient
        self.selectedDate = selectedDate
        self.syncEngine = syncEngine
        self.userId = userId
        self.lastCheckedDate = Calendar.current.startOfDay(for: Date())
    }
    
    // MARK: - Sync Configuration
    
    /// Updates the sync engine and user ID for cloud synchronization
    /// Call this when authentication state changes
    /// - Parameters:
    ///   - syncEngine: The sync engine instance (nil if signed out)
    ///   - userId: The authenticated user's ID (nil if signed out)
    func configureSyncEngine(_ syncEngine: FirebaseSyncEngine?, userId: String?) {
        self.syncEngine = syncEngine
        self.userId = userId
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
        
        print("📅 Loading log for date: \(date)")
        
        do {
            // Try to fetch existing log
            if let existingLog = try await dataStore.fetchDailyLog(for: date) {
                print("✅ Found existing log with \(existingLog.foodItems.count) food items")
                currentLog = existingLog
            } else {
                // Create new log for this date
                print("➕ Creating new log for date")
                let newLog = DailyLog(date: date)
                try await dataStore.saveDailyLog(newLog)
                currentLog = newLog
            }
            
            // Update last checked date to the normalized date
            lastCheckedDate = Calendar.current.startOfDay(for: date)
            
            isLoading = false
        } catch {
            print("❌ Error loading log: \(error)")
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
    
    /// Gets the current daily total exercise calories
    /// - Returns: Total exercise calories for the current log, or 0 if no log is loaded
    func getCurrentExerciseTotal() -> Double {
        return currentLog?.totalExerciseCalories ?? 0.0
    }
    
    /// Gets the net calories (food - exercise)
    /// - Returns: Net calories for the current log, or 0 if no log is loaded
    func getNetCalories() -> Double {
        return currentLog?.netCalories ?? 0.0
    }
    
    /// Gets the remaining calories until the daily goal
    /// - Returns: Remaining calories, or nil if no goal is set
    func getRemainingCalories() -> Double? {
        return currentLog?.remainingCalories
    }
    
    // MARK: - Food Item Management
    
    /// Adds a food item to the current daily log
    /// Syncs to cloud if authenticated
    /// - Parameter item: The food item to add
    /// - Throws: Error if no current log is loaded or persistence fails
    ///
    /// **Validates: Requirements 5.1, 5.4**
    func addFoodItem(_ item: FoodItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        print("🍔 Adding food item: \(item.name) with \(item.calories) calories")
        print("📋 Current log has \(log.foodItems.count) items before adding")
        
        errorMessage = nil
        
        do {
            // Set the relationship between food item and daily log
            item.dailyLog = log
            
            // Add item to the log's food items array
            log.foodItems.append(item)
            
            print("📋 Current log now has \(log.foodItems.count) items after appending")
            
            // Persist the change locally
            try await dataStore.saveDailyLog(log)
            
            print("✅ Successfully saved daily log to database")
            
            // Sync to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                // Associate userId with the item
                item.userId = userId
                item.lastModified = Date()
                item.syncStatus = .pendingUpload
                
                // Sync the food item
                try await syncEngine.syncFoodItem(item, userId: userId)
                
                // Also sync the updated daily log
                log.userId = userId
                log.lastModified = Date()
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            // Force UI update by reloading the log
            try await loadLog(for: selectedDate)
            
            print("🔄 Triggered UI update by reloading log")
        } catch let error as SyncError {
            // Handle sync errors gracefully - local data is already saved
            print("⚠️ Sync error while adding food item: \(error.localizedDescription)")
            // Reload to ensure UI is in sync
            try? await loadLog(for: selectedDate)
        } catch {
            print("❌ Error adding food item: \(error)")
            errorMessage = "Failed to add food item: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Removes a food item from the current daily log
    /// Syncs deletion to cloud if authenticated
    /// - Parameter item: The food item to remove
    /// - Throws: Error if no current log is loaded or persistence fails
    ///
    /// **Validates: Requirements 5.5**
    func removeFoodItem(_ item: FoodItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            // Delete through data store to ensure proper persistence
            try await dataStore.deleteFoodItem(item, from: log)
            
            // Sync deletion to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                try await syncEngine.deleteEntity(
                    entityId: item.id,
                    entityType: .foodItem,
                    userId: userId
                )
                
                // Also sync the updated daily log
                log.userId = userId
                log.lastModified = Date()
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            // Force UI update by reloading the log
            try await loadLog(for: selectedDate)
        } catch let error as SyncError {
            // Handle sync errors gracefully - local data is already deleted
            print("⚠️ Sync error while removing food item: \(error.localizedDescription)")
            // Reload to ensure UI is in sync
            try? await loadLog(for: selectedDate)
        } catch {
            errorMessage = "Failed to remove food item: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Updates an existing food item in the current daily log
    /// Syncs update to cloud if authenticated
    /// - Parameter item: The food item with updated values
    /// - Throws: Error if no current log is loaded or persistence fails
    ///
    /// **Validates: Requirements 5.4**
    func updateFoodItem(_ item: FoodItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            // Update through data store to ensure proper persistence
            try await dataStore.updateFoodItem(item, in: log)
            
            // Sync update to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                item.userId = userId
                item.lastModified = Date()
                item.syncStatus = .pendingUpload
                
                try await syncEngine.syncFoodItem(item, userId: userId)
                
                // Also sync the updated daily log
                log.userId = userId
                log.lastModified = Date()
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            // Force UI update by reloading the log
            try await loadLog(for: selectedDate)
        } catch let error as SyncError {
            // Handle sync errors gracefully - local data is already updated
            print("⚠️ Sync error while updating food item: \(error.localizedDescription)")
            // Reload to ensure UI is in sync
            try? await loadLog(for: selectedDate)
        } catch {
            errorMessage = "Failed to update food item: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Exercise Item Management
    
    /// Adds an exercise item to the current daily log
    /// - Parameter item: The exercise item to add
    /// - Throws: Error if no current log is loaded or persistence fails
    func addExerciseItem(_ item: ExerciseItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            item.dailyLog = log
            log.exerciseItems.append(item)
            
            try await dataStore.saveDailyLog(log)
            
            if let syncEngine = syncEngine, let userId = userId {
                item.userId = userId
                item.lastModified = Date()
                item.syncStatus = .pendingUpload
                
                try await syncEngine.syncExerciseItem(item, userId: userId)
                
                log.userId = userId
                log.lastModified = Date()
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            // Force UI update by reloading the log
            try await loadLog(for: selectedDate)
        } catch {
            errorMessage = "Failed to add exercise item: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Removes an exercise item from the current daily log
    /// - Parameter item: The exercise item to remove
    /// - Throws: Error if no current log is loaded or persistence fails
    func removeExerciseItem(_ item: ExerciseItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            try await dataStore.deleteExerciseItem(item, from: log)
            
            if let syncEngine = syncEngine, let userId = userId {
                try await syncEngine.deleteEntity(
                    entityId: item.id,
                    entityType: .exerciseItem,
                    userId: userId
                )
                
                log.userId = userId
                log.lastModified = Date()
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            try await loadLog(for: selectedDate)
        } catch {
            errorMessage = "Failed to remove exercise item: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Updates an existing exercise item in the current daily log
    /// - Parameter item: The exercise item with updated values
    /// - Throws: Error if no current log is loaded or persistence fails
    func updateExerciseItem(_ item: ExerciseItem) async throws {
        guard let log = currentLog else {
            throw CalorieTrackerError.noCurrentLog
        }
        
        errorMessage = nil
        
        do {
            try await dataStore.updateExerciseItem(item, in: log)
            
            if let syncEngine = syncEngine, let userId = userId {
                item.userId = userId
                item.lastModified = Date()
                item.syncStatus = .pendingUpload
                
                try await syncEngine.syncExerciseItem(item, userId: userId)
                
                log.userId = userId
                log.lastModified = Date()
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            try await loadLog(for: selectedDate)
        } catch {
            errorMessage = "Failed to update exercise item: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Goal Management
    
    /// Sets the daily calorie goal for the current log
    /// Syncs goal to cloud if authenticated
    /// - Parameter calories: The target calorie goal (must be positive)
    /// - Throws: Error if no current log is loaded, invalid goal, or persistence fails
    ///
    /// **Validates: Requirements 5.3**
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
            
            // Persist the change locally
            try await dataStore.saveDailyLog(log)
            
            // Sync to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                log.userId = userId
                log.lastModified = Date()
                log.syncStatus = .pendingUpload
                
                try await syncEngine.syncDailyLog(log, userId: userId)
            }
            
            // Trigger UI update by reassigning currentLog
            currentLog = log
        } catch let error as SyncError {
            // Handle sync errors gracefully - local data is already saved
            print("⚠️ Sync error while setting daily goal: \(error.localizedDescription)")
            // Don't throw - the goal was set locally successfully
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
