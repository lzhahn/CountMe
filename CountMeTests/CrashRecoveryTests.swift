//
//  CrashRecoveryTests.swift
//  CountMeTests
//
//  Tests for crash recovery and data persistence
//  Validates Requirement 7.3: Data recovery after unexpected termination
//

import XCTest
import SwiftData
@testable import CountMe

/// Tests that verify data persists and can be recovered after unexpected app termination
final class CrashRecoveryTests: XCTestCase {
    
    var testContainer: ModelContainer!
    var testContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a fresh persistent container for each test
        // Using persistent storage (not in-memory) to properly test crash recovery
        let schema = Schema([
            FoodItem.self,
            DailyLog.self,
        ])
        
        // Create a temporary URL for the test database
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelConfiguration = ModelConfiguration(url: tempURL)
        
        testContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        testContext = ModelContext(testContainer)
    }
    
    override func tearDown() async throws {
        // Clean up test data
        testContext = nil
        testContainer = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Crash Recovery Tests
    
    /// Tests that data persists after simulated unexpected termination
    /// Simulates a crash by:
    /// 1. Creating and saving data
    /// 2. Destroying the context (simulating app termination)
    /// 3. Creating a new context with the same container
    /// 4. Verifying all data is recovered
    func testDataRecoveryAfterCrash() async throws {
        // Phase 1: Create and save data before "crash"
        let beforeCrashDate = Date()
        let foodItem1 = try FoodItem(
            name: "Apple",
            calories: 95.0,
            timestamp: beforeCrashDate,
            servingSize: "1",
            servingUnit: "medium",
            source: .manual
        )
        
        let foodItem2 = try FoodItem(
            name: "Banana",
            calories: 105.0,
            timestamp: beforeCrashDate.addingTimeInterval(3600),
            servingSize: "1",
            servingUnit: "medium",
            source: .api
        )
        
        let dailyLog = try DailyLog(
            date: beforeCrashDate,
            foodItems: [foodItem1, foodItem2],
            dailyGoal: 2000.0
        )
        
        // Save data using DataStore
        let dataStore = DataStore(modelContext: testContext)
        try await dataStore.saveDailyLog(dailyLog)
        
        // Verify data was saved
        let savedLog = try await dataStore.fetchDailyLog(for: beforeCrashDate)
        XCTAssertNotNil(savedLog, "Daily log should be saved before crash")
        XCTAssertEqual(savedLog?.foodItems.count, 2, "Should have 2 food items before crash")
        
        // Phase 2: Simulate crash by destroying context and creating new one
        // This simulates the app being terminated unexpectedly
        let originalLogId = dailyLog.id
        testContext = nil
        
        // Create new context (simulating app restart)
        testContext = ModelContext(testContainer)
        let newDataStore = DataStore(modelContext: testContext)
        
        // Phase 3: Verify data recovery after "crash"
        let recoveredLog = try await newDataStore.fetchDailyLog(for: beforeCrashDate)
        
        // Verify the log was recovered
        XCTAssertNotNil(recoveredLog, "Daily log should be recovered after crash")
        XCTAssertEqual(recoveredLog?.id, originalLogId, "Recovered log should have same ID")
        XCTAssertEqual(recoveredLog?.dailyGoal, 2000.0, "Daily goal should be recovered")
        
        // Verify food items were recovered
        XCTAssertEqual(recoveredLog?.foodItems.count, 2, "Should recover all food items")
        
        // Verify first food item
        let recoveredItem1 = recoveredLog?.foodItems.first { $0.name == "Apple" }
        XCTAssertNotNil(recoveredItem1, "Apple should be recovered")
        XCTAssertEqual(recoveredItem1?.calories, 95.0, "Apple calories should be recovered")
        XCTAssertEqual(recoveredItem1?.servingSize, "1", "Apple serving size should be recovered")
        XCTAssertEqual(recoveredItem1?.servingUnit, "medium", "Apple serving unit should be recovered")
        XCTAssertEqual(recoveredItem1?.source, .manual, "Apple source should be recovered")
        
        // Verify second food item
        let recoveredItem2 = recoveredLog?.foodItems.first { $0.name == "Banana" }
        XCTAssertNotNil(recoveredItem2, "Banana should be recovered")
        XCTAssertEqual(recoveredItem2?.calories, 105.0, "Banana calories should be recovered")
        XCTAssertEqual(recoveredItem2?.source, .api, "Banana source should be recovered")
        
        // Verify calculated properties work after recovery
        XCTAssertEqual(recoveredLog?.totalCalories, 200.0, "Total calories should be calculated correctly after recovery")
        XCTAssertEqual(recoveredLog?.remainingCalories, 1800.0, "Remaining calories should be calculated correctly after recovery")
    }
    
    /// Tests recovery of multiple daily logs after crash
    func testMultipleDailyLogsRecoveryAfterCrash() async throws {
        // Create logs for multiple days
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let log1 = try DailyLog(
            date: today,
            foodItems: [try FoodItem(name: "Lunch", calories: 500.0, source: .manual)],
            dailyGoal: 2000.0
        )
        
        let log2 = try DailyLog(
            date: yesterday,
            foodItems: [
                try FoodItem(name: "Breakfast", calories: 300.0, source: .manual),
                try FoodItem(name: "Dinner", calories: 600.0, source: .api)
            ],
            dailyGoal: 1800.0
        )
        
        let log3 = try DailyLog(
            date: twoDaysAgo,
            foodItems: [try FoodItem(name: "Snack", calories: 150.0, source: .manual)],
            dailyGoal: 2200.0
        )
        
        // Save all logs
        let dataStore = DataStore(modelContext: testContext)
        try await dataStore.saveDailyLog(log1)
        try await dataStore.saveDailyLog(log2)
        try await dataStore.saveDailyLog(log3)
        
        // Simulate crash
        testContext = nil
        testContext = ModelContext(testContainer)
        let newDataStore = DataStore(modelContext: testContext)
        
        // Verify all logs are recovered
        let recoveredLog1 = try await newDataStore.fetchDailyLog(for: today)
        let recoveredLog2 = try await newDataStore.fetchDailyLog(for: yesterday)
        let recoveredLog3 = try await newDataStore.fetchDailyLog(for: twoDaysAgo)
        
        XCTAssertNotNil(recoveredLog1, "Today's log should be recovered")
        XCTAssertNotNil(recoveredLog2, "Yesterday's log should be recovered")
        XCTAssertNotNil(recoveredLog3, "Two days ago log should be recovered")
        
        XCTAssertEqual(recoveredLog1?.foodItems.count, 1, "Today's log should have 1 item")
        XCTAssertEqual(recoveredLog2?.foodItems.count, 2, "Yesterday's log should have 2 items")
        XCTAssertEqual(recoveredLog3?.foodItems.count, 1, "Two days ago log should have 1 item")
        
        XCTAssertEqual(recoveredLog1?.dailyGoal, 2000.0, "Today's goal should be recovered")
        XCTAssertEqual(recoveredLog2?.dailyGoal, 1800.0, "Yesterday's goal should be recovered")
        XCTAssertEqual(recoveredLog3?.dailyGoal, 2200.0, "Two days ago goal should be recovered")
    }
    
    /// Tests that modifications made before crash are persisted
    func testModificationsPersistedAfterCrash() async throws {
        // Create initial data
        let date = Date()
        let foodItem = try FoodItem(name: "Original", calories: 100.0, source: .manual)
        let dailyLog = try DailyLog(date: date, foodItems: [foodItem], dailyGoal: 2000.0)
        
        let dataStore = DataStore(modelContext: testContext)
        try await dataStore.saveDailyLog(dailyLog)
        
        // Modify the data
        dailyLog.dailyGoal = 2500.0
        let newFoodItem = try FoodItem(name: "Added", calories: 200.0, source: .api)
        dailyLog.foodItems.append(newFoodItem)
        try await dataStore.saveDailyLog(dailyLog)
        
        // Simulate crash
        testContext = nil
        testContext = ModelContext(testContainer)
        let newDataStore = DataStore(modelContext: testContext)
        
        // Verify modifications persisted
        let recoveredLog = try await newDataStore.fetchDailyLog(for: date)
        XCTAssertNotNil(recoveredLog, "Modified log should be recovered")
        XCTAssertEqual(recoveredLog?.dailyGoal, 2500.0, "Modified goal should be persisted")
        XCTAssertEqual(recoveredLog?.foodItems.count, 2, "Added food item should be persisted")
        
        let addedItem = recoveredLog?.foodItems.first { $0.name == "Added" }
        XCTAssertNotNil(addedItem, "Added item should be recovered")
        XCTAssertEqual(addedItem?.calories, 200.0, "Added item calories should be correct")
    }
    
    /// Tests that deletions made before crash are persisted
    func testDeletionsPersistedAfterCrash() async throws {
        // Create initial data with multiple items
        let date = Date()
        let item1 = try FoodItem(name: "Keep", calories: 100.0, source: .manual)
        let item2 = try FoodItem(name: "Delete", calories: 200.0, source: .manual)
        let dailyLog = try DailyLog(date: date, foodItems: [item1, item2])
        
        let dataStore = DataStore(modelContext: testContext)
        try await dataStore.saveDailyLog(dailyLog)
        
        // Delete one item
        try await dataStore.deleteFoodItem(item2, from: dailyLog)
        
        // Simulate crash
        testContext = nil
        testContext = ModelContext(testContainer)
        let newDataStore = DataStore(modelContext: testContext)
        
        // Verify deletion persisted
        let recoveredLog = try await newDataStore.fetchDailyLog(for: date)
        XCTAssertNotNil(recoveredLog, "Log should be recovered")
        XCTAssertEqual(recoveredLog?.foodItems.count, 1, "Should only have 1 item after deletion")
        XCTAssertEqual(recoveredLog?.foodItems.first?.name, "Keep", "Correct item should remain")
        XCTAssertNil(recoveredLog?.foodItems.first { $0.name == "Delete" }, "Deleted item should not be recovered")
    }
    
    /// Tests recovery with empty daily log (no food items)
    func testEmptyLogRecoveryAfterCrash() async throws {
        // Create empty log with just a goal
        let date = Date()
        let emptyLog = try DailyLog(date: date, foodItems: [], dailyGoal: 2000.0)
        
        let dataStore = DataStore(modelContext: testContext)
        try await dataStore.saveDailyLog(emptyLog)
        
        // Simulate crash
        testContext = nil
        testContext = ModelContext(testContainer)
        let newDataStore = DataStore(modelContext: testContext)
        
        // Verify empty log is recovered
        let recoveredLog = try await newDataStore.fetchDailyLog(for: date)
        XCTAssertNotNil(recoveredLog, "Empty log should be recovered")
        XCTAssertEqual(recoveredLog?.foodItems.count, 0, "Should have no food items")
        XCTAssertEqual(recoveredLog?.dailyGoal, 2000.0, "Goal should be recovered")
        XCTAssertEqual(recoveredLog?.totalCalories, 0.0, "Total should be 0")
    }
    
    /// Tests that timestamps are preserved after crash
    func testTimestampsPreservedAfterCrash() async throws {
        // Create items with specific timestamps
        let baseDate = Date()
        let timestamp1 = baseDate.addingTimeInterval(-7200) // 2 hours ago
        let timestamp2 = baseDate.addingTimeInterval(-3600) // 1 hour ago
        
        let item1 = try FoodItem(name: "First", calories: 100.0, timestamp: timestamp1, source: .manual)
        let item2 = try FoodItem(name: "Second", calories: 200.0, timestamp: timestamp2, source: .api)
        
        let dailyLog = try DailyLog(date: baseDate, foodItems: [item1, item2])
        
        let dataStore = DataStore(modelContext: testContext)
        try await dataStore.saveDailyLog(dailyLog)
        
        // Simulate crash
        testContext = nil
        testContext = ModelContext(testContainer)
        let newDataStore = DataStore(modelContext: testContext)
        
        // Verify timestamps are preserved
        let recoveredLog = try await newDataStore.fetchDailyLog(for: baseDate)
        XCTAssertNotNil(recoveredLog, "Log should be recovered")
        
        let recoveredItem1 = recoveredLog?.foodItems.first { $0.name == "First" }
        let recoveredItem2 = recoveredLog?.foodItems.first { $0.name == "Second" }
        
        XCTAssertNotNil(recoveredItem1, "First item should be recovered")
        XCTAssertNotNil(recoveredItem2, "Second item should be recovered")
        
        // Compare timestamps (allowing 1 second tolerance for floating point precision)
        if let item1 = recoveredItem1 {
            XCTAssertEqual(
                item1.timestamp.timeIntervalSince1970,
                timestamp1.timeIntervalSince1970,
                accuracy: 1.0,
                "First item timestamp should be preserved"
            )
        }
        
        if let item2 = recoveredItem2 {
            XCTAssertEqual(
                item2.timestamp.timeIntervalSince1970,
                timestamp2.timeIntervalSince1970,
                accuracy: 1.0,
                "Second item timestamp should be preserved"
            )
        }
    }
}
