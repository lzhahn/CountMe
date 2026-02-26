//
//  DailyLogAssociationTests.swift
//  CountMeTests
//
//  Tests for the daily log ↔ food item association fix during cloud sync.
//  Verifies that food items and exercise items are properly linked to daily logs
//  when data arrives from Firestore, reproducing the bug where cloud daily logs
//  had empty foodItems arrays on new device login.
//

import Testing
import SwiftData
import Foundation
import FirebaseFirestore
@testable import CountMe

@Suite("Daily Log Association Tests")
@MainActor
struct DailyLogAssociationTests {
    
    /// Creates an in-memory test container
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DailyLog.self, FoodItem.self, ExerciseItem.self, CustomMeal.self, Ingredient.self,
            configurations: config
        )
    }
    
    // MARK: - Bug Reproduction Tests
    
    @Test("DailyLog from Firestore data has empty foodItems array")
    func testFromFirestoreData_CreatesEmptyFoodItems() async throws {
        // This reproduces the root cause: fromFirestoreData always creates
        // a DailyLog with empty foodItems, even when foodItemIds exist in the data
        let logId = UUID()
        let data: [String: Any] = [
            "id": logId.uuidString,
            "date": FirebaseFirestore.Timestamp(date: Date()),
            "totalCalories": 200.0,
            "foodItemIds": ["some-food-id-1", "some-food-id-2"],
            "exerciseItemIds": [],
            "userId": "test-user",
            "lastModified": FirebaseFirestore.Timestamp(date: Date()),
            "syncStatus": SyncStatus.synced.rawValue
        ]
        
        let dailyLog = try DailyLog.fromFirestoreData(data)
        
        // This is the bug: foodItems is always empty after parsing
        #expect(dailyLog.foodItems.isEmpty, "fromFirestoreData cannot resolve SwiftData relationships")
        #expect(dailyLog.id == logId.uuidString)
    }
    
    @Test("Orphaned food items not visible in daily log without association")
    func testOrphanedFoodItems_NotVisibleInDailyLog() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Simulate what happens during cloud sync: items inserted separately
        let foodItem = try FoodItem(
            name: "Cloud Apple",
            calories: 95,
            timestamp: Date(),
            source: .api,
            userId: "test-user",
            syncStatus: .synced
        )
        try await dataStore.insertFoodItem(foodItem)
        
        // Daily log inserted without the food item relationship
        let dailyLog = try DailyLog(
            date: Date(),
            foodItems: [],
            userId: "test-user",
            syncStatus: .synced
        )
        try await dataStore.insertDailyLog(dailyLog)
        
        // The food item exists but the daily log shows 0 calories
        let fetched = try await dataStore.fetchFoodItem(byId: foodItem.id)
        #expect(fetched != nil, "Food item exists in store")
        #expect(dailyLog.totalCalories == 0, "Daily log has no associated food items")
        #expect(dailyLog.foodItems.isEmpty)
    }
    
    // MARK: - Fix Verification Tests
    
    @Test("Associating food items with daily log restores calories")
    func testAssociateFoodItems_RestoresCalories() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Insert food items (simulating cloud sync of individual items)
        let apple = try FoodItem(name: "Apple", calories: 95, timestamp: Date(), source: .api, userId: "test-user", syncStatus: .synced)
        let banana = try FoodItem(name: "Banana", calories: 105, timestamp: Date(), source: .api, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertFoodItem(apple)
        try await dataStore.insertFoodItem(banana)
        
        // Insert daily log with empty food items (as fromFirestoreData does)
        let dailyLog = try DailyLog(date: Date(), foodItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(dailyLog)
        
        #expect(dailyLog.totalCalories == 0)
        
        // Simulate the fix: associate food items by ID
        let foodItemIds = [apple.id, banana.id]
        for foodItemId in foodItemIds {
            if let item = try await dataStore.fetchFoodItem(byId: foodItemId) {
                if !dailyLog.foodItems.contains(where: { $0.id == foodItemId }) {
                    dailyLog.foodItems.append(item)
                }
            }
        }
        try await dataStore.updateDailyLog(dailyLog)
        
        // Verify the fix works
        #expect(dailyLog.foodItems.count == 2)
        #expect(dailyLog.totalCalories == 200)
    }
    
    @Test("Associating exercise items with daily log restores burned calories")
    func testAssociateExerciseItems_RestoresBurnedCalories() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Insert exercise item
        let run = try ExerciseItem(name: "Morning Run", caloriesBurned: 300, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertExerciseItem(run)
        
        // Insert daily log with empty exercise items
        let dailyLog = try DailyLog(date: Date(), foodItems: [], exerciseItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(dailyLog)
        
        #expect(dailyLog.totalExerciseCalories == 0)
        
        // Associate exercise item
        if let item = try await dataStore.fetchExerciseItem(byId: run.id) {
            dailyLog.exerciseItems.append(item)
        }
        try await dataStore.updateDailyLog(dailyLog)
        
        #expect(dailyLog.exerciseItems.count == 1)
        #expect(dailyLog.totalExerciseCalories == 300)
    }
    
    @Test("Duplicate association is prevented")
    func testDuplicateAssociation_Prevented() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let apple = try FoodItem(name: "Apple", calories: 95, timestamp: Date(), source: .api, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertFoodItem(apple)
        
        let dailyLog = try DailyLog(date: Date(), foodItems: [apple], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(dailyLog)
        
        #expect(dailyLog.foodItems.count == 1)
        
        // Try to associate the same item again (as the fix's guard does)
        let foodItemIds = [apple.id]
        for foodItemId in foodItemIds {
            if let item = try await dataStore.fetchFoodItem(byId: foodItemId) {
                if !dailyLog.foodItems.contains(where: { $0.id == foodItemId }) {
                    dailyLog.foodItems.append(item)
                }
            }
        }
        
        #expect(dailyLog.foodItems.count == 1, "Should not duplicate existing association")
        #expect(dailyLog.totalCalories == 95)
    }
    
    @Test("Missing food item ID is handled gracefully")
    func testMissingFoodItemId_HandledGracefully() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let dailyLog = try DailyLog(date: Date(), foodItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(dailyLog)
        
        // Try to associate a non-existent food item ID
        let bogusId = UUID().uuidString
        let fetched = try await dataStore.fetchFoodItem(byId: bogusId)
        #expect(fetched == nil, "Non-existent ID returns nil")
        
        // Daily log remains unchanged
        #expect(dailyLog.foodItems.isEmpty)
    }
    
    // MARK: - Property-Based Tests
    
    @Test("Property: Associating N food items yields correct total calories",
          .tags(.property, .calorieTracking))
    func testProperty_AssociationCalories_1() async throws {
        for _ in 0..<100 {
            let container = try createTestContainer()
            let context = ModelContext(container)
            let dataStore = DataStore(modelContext: context)
            
            // Generate random food items
            let count = Int.random(in: 1...15)
            var foodItems: [FoodItem] = []
            var foodItemIds: [String] = []
            
            for i in 0..<count {
                let item = try FoodItem(
                    name: "Food \(i)",
                    calories: Double.random(in: 1...500),
                    timestamp: Date(),
                    source: .manual,
                    userId: "test-user",
                    syncStatus: .synced
                )
                try await dataStore.insertFoodItem(item)
                foodItems.append(item)
                foodItemIds.append(item.id)
            }
            
            let expectedTotal = foodItems.reduce(0.0) { $0 + $1.calories }
            
            // Insert daily log with empty food items (simulating cloud parse)
            let dailyLog = try DailyLog(date: Date(), foodItems: [], userId: "test-user", syncStatus: .synced)
            try await dataStore.insertDailyLog(dailyLog)
            
            // Associate items by ID (simulating the fix)
            for foodItemId in foodItemIds {
                if let item = try await dataStore.fetchFoodItem(byId: foodItemId) {
                    if !dailyLog.foodItems.contains(where: { $0.id == foodItemId }) {
                        dailyLog.foodItems.append(item)
                    }
                }
            }
            try await dataStore.updateDailyLog(dailyLog)
            
            #expect(dailyLog.foodItems.count == count)
            #expect(abs(dailyLog.totalCalories - expectedTotal) < 0.001)
        }
    }
    
    @Test("Property: Association never creates duplicates regardless of repeat calls",
          .tags(.property, .calorieTracking))
    func testProperty_NoDuplicates_2() async throws {
        for _ in 0..<100 {
            let container = try createTestContainer()
            let context = ModelContext(container)
            let dataStore = DataStore(modelContext: context)
            
            let itemCount = Int.random(in: 1...10)
            var foodItemIds: [String] = []
            
            for i in 0..<itemCount {
                let item = try FoodItem(
                    name: "Food \(i)",
                    calories: Double.random(in: 1...500),
                    timestamp: Date(),
                    source: .manual,
                    userId: "test-user",
                    syncStatus: .synced
                )
                try await dataStore.insertFoodItem(item)
                foodItemIds.append(item.id)
            }
            
            let dailyLog = try DailyLog(date: Date(), foodItems: [], userId: "test-user", syncStatus: .synced)
            try await dataStore.insertDailyLog(dailyLog)
            
            // Run association multiple times (simulating repeated sync events)
            let repeatCount = Int.random(in: 2...5)
            for _ in 0..<repeatCount {
                for foodItemId in foodItemIds {
                    if let item = try await dataStore.fetchFoodItem(byId: foodItemId) {
                        if !dailyLog.foodItems.contains(where: { $0.id == foodItemId }) {
                            dailyLog.foodItems.append(item)
                        }
                    }
                }
            }
            
            #expect(dailyLog.foodItems.count == itemCount, "No duplicates after \(repeatCount) association passes")
        }
    }
    
    // MARK: - Date-Based Dedup Tests
    
    @Test("Cloud log merges into existing local log for same date instead of creating duplicate")
    func testDateBasedDedup_MergesIntoExisting() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Simulate what loadLog does: create an empty local log for today
        let localLog = try DailyLog(date: today, foodItems: [], userId: "", syncStatus: .pendingUpload)
        try await dataStore.insertDailyLog(localLog)
        
        // Simulate cloud log arriving with a different UUID but same date
        let cloudFoodItem = try FoodItem(name: "Cloud Apple", calories: 95, timestamp: today, source: .api, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertFoodItem(cloudFoodItem)
        
        let cloudLog = try DailyLog(
            id: UUID(), // Different UUID than localLog
            date: today,
            foodItems: [],
            userId: "test-user",
            syncStatus: .synced
        )
        
        // fetchDailyLog(byId:) won't find it (different UUID)
        let byId = try await dataStore.fetchDailyLog(byId: cloudLog.id)
        #expect(byId == nil, "Cloud log UUID should not match local log")
        
        // fetchDailyLog(for:) WILL find the existing local log
        let byDate = try await dataStore.fetchDailyLog(for: today)
        #expect(byDate != nil, "Should find existing log by date")
        #expect(byDate?.id == localLog.id, "Should find the local log, not the cloud one")
    }
    
    @Test("insertDailyLog normalizes date so cloud logs match local date queries")
    func testInsertDailyLog_NormalizesDate() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Simulate a cloud date with a time component (e.g. midnight EST stored as UTC)
        // Feb 21 05:00:00 UTC = Feb 21 00:00:00 EST
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 5
        components.minute = 14
        components.second = 41
        let cloudDate = calendar.date(from: components)!
        
        let cloudLog = try DailyLog(date: cloudDate, foodItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(cloudLog)
        
        // The log's date should now be normalized to midnight local time
        let normalizedToday = calendar.startOfDay(for: cloudDate)
        #expect(cloudLog.date == normalizedToday, "insertDailyLog should normalize the date to midnight")
        
        // fetchDailyLog(for:) should find it using the original non-normalized date
        let fetched = try await dataStore.fetchDailyLog(for: cloudDate)
        #expect(fetched != nil, "Should find the log by date after normalization")
        #expect(fetched?.id == cloudLog.id)
    }
    
    @Test("updateDailyLog normalizes date to prevent drift")
    func testUpdateDailyLog_NormalizesDate() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let log = try DailyLog(date: today, foodItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(log)
        
        // Simulate date getting a time component during merge
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.hour = 3
        components.minute = 30
        log.date = calendar.date(from: components)!
        
        try await dataStore.updateDailyLog(log)
        
        // Date should be re-normalized after update
        #expect(log.date == today, "updateDailyLog should normalize the date back to midnight")
    }
    
    @Test("Reload after sync picks up cloud data in existing log")
    func testReloadAfterSync_PicksUpCloudData() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Create tracker and load initial empty log
        let apiClient = NutritionAPIClient()
        let tracker = CalorieTracker(dataStore: dataStore, apiClient: apiClient, selectedDate: today)
        try await tracker.loadLog(for: today)
        
        #expect(tracker.currentLog != nil)
        #expect(tracker.currentLog?.foodItems.isEmpty == true)
        
        // Simulate cloud food item being inserted into the existing log
        // (as the sync engine would do after merging)
        let cloudItem = try FoodItem(name: "Synced Banana", calories: 105, timestamp: today, source: .api, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertFoodItem(cloudItem)
        tracker.currentLog?.foodItems.append(cloudItem)
        try await dataStore.updateDailyLog(tracker.currentLog!)
        
        // Reload the log (as the delayed reload in ContentView would do)
        try await tracker.loadLog(for: today)
        
        #expect(tracker.currentLog?.foodItems.count == 1)
        #expect(tracker.currentLog?.totalCalories == 105)
    }

    // MARK: - Managed Object Persistence Tests
    
    @Test("Merging cloud data into managed log persists food items after save")
    func testMergeIntoManagedLog_PersistsFoodItems() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Insert a managed daily log (simulating what loadLog creates)
        let managedLog = try DailyLog(date: today, foodItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(managedLog)
        
        // Insert food items that should be associated
        let apple = try FoodItem(name: "Apple", calories: 95, timestamp: today, source: .manual, userId: "test-user", syncStatus: .synced)
        let banana = try FoodItem(name: "Banana", calories: 105, timestamp: today, source: .manual, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertFoodItem(apple)
        try await dataStore.insertFoodItem(banana)
        
        // Simulate what the fixed handleDailyLogUpdate does:
        // append items to the MANAGED log, then save
        managedLog.foodItems.append(apple)
        managedLog.foodItems.append(banana)
        try await dataStore.updateDailyLog(managedLog)
        
        // Re-fetch from store to verify persistence
        let refetched = try await dataStore.fetchDailyLog(for: today)
        #expect(refetched != nil)
        #expect(refetched?.foodItems.count == 2, "Food items should persist after save on managed object")
        #expect(refetched?.totalCalories == 200)
    }
    
    @Test("Unmanaged merged log does NOT persist food items — demonstrates the bug")
    func testUnmanagedMergedLog_DoesNotPersist() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Insert a managed daily log
        let managedLog = try DailyLog(date: today, foodItems: [], userId: "test-user", syncStatus: .synced)
        try await dataStore.insertDailyLog(managedLog)
        
        let apple = try FoodItem(name: "Apple", calories: 95, timestamp: today, source: .manual, userId: "test-user", syncStatus: .synced)
        try await dataStore.insertFoodItem(apple)
        
        // Create an UNMANAGED log (like mergeDailyLogs does) with the same ID
        let unmanagedLog = try DailyLog(
            id: UUID(uuidString: managedLog.id)!,
            date: today,
            foodItems: [apple],
            userId: "test-user",
            syncStatus: .synced
        )
        
        // Calling updateDailyLog on the unmanaged log just calls save() —
        // it doesn't insert the unmanaged object
        try await dataStore.updateDailyLog(unmanagedLog)
        
        // Re-fetch the MANAGED log — it should still be empty
        let refetched = try await dataStore.fetchDailyLog(for: today)
        #expect(refetched != nil)
        #expect(refetched?.foodItems.isEmpty == true, "Unmanaged log changes don't persist to the managed object")
    }
    
    @Test("Property: applyMergedProperties copies all items to managed log",
          .tags(.property, .calorieTracking))
    func testProperty_ApplyMergedProperties_3() async throws {
        for _ in 0..<100 {
            let container = try createTestContainer()
            let context = ModelContext(container)
            let dataStore = DataStore(modelContext: context)
            
            let today = Calendar.current.startOfDay(for: Date())
            
            // Create managed log with some existing items
            let existingCount = Int.random(in: 0...5)
            var existingItems: [FoodItem] = []
            for i in 0..<existingCount {
                let item = try FoodItem(name: "Existing \(i)", calories: Double.random(in: 1...200), timestamp: today, source: .manual, userId: "test-user", syncStatus: .synced)
                try await dataStore.insertFoodItem(item)
                existingItems.append(item)
            }
            
            let managedLog = try DailyLog(date: today, foodItems: existingItems, userId: "test-user", syncStatus: .synced)
            try await dataStore.insertDailyLog(managedLog)
            
            // Create cloud items (some may overlap with existing)
            let cloudCount = Int.random(in: 0...5)
            var cloudItems: [FoodItem] = []
            for i in 0..<cloudCount {
                let item = try FoodItem(name: "Cloud \(i)", calories: Double.random(in: 1...200), timestamp: today, source: .api, userId: "test-user", syncStatus: .synced)
                try await dataStore.insertFoodItem(item)
                cloudItems.append(item)
            }
            
            // Simulate applyMergedProperties: add cloud items that aren't already present
            for item in cloudItems {
                if !managedLog.foodItems.contains(where: { $0.id == item.id }) {
                    managedLog.foodItems.append(item)
                }
            }
            try await dataStore.updateDailyLog(managedLog)
            
            let expectedCount = existingCount + cloudCount
            let expectedCalories = (existingItems + cloudItems).reduce(0.0) { $0 + $1.calories }
            
            #expect(managedLog.foodItems.count == expectedCount)
            #expect(abs(managedLog.totalCalories - expectedCalories) < 0.001)
            
            // Verify persistence
            let refetched = try await dataStore.fetchDailyLog(for: today)
            #expect(refetched?.foodItems.count == expectedCount)
        }
    }
}

// MARK: - Test Tags
// Note: Tag extensions are defined in CalorieEstimatorTests.swift to avoid duplicates
