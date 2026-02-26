//
//  HistoricalViewTests.swift
//  CountMeTests
//
//  Tests for HistoricalView functionality
//

import Testing
import Foundation
import SwiftData
@testable import CountMe

@Suite("HistoricalView Tests")
@MainActor
struct HistoricalViewTests {
    
    @Test("Fetch historical log for specific date returns correct data")
    func testFetchHistoricalLog_SpecificDate_ReturnsCorrectData() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create logs for different dates
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let todayLog = try DailyLog(date: today)
        let yesterdayLog = try DailyLog(date: yesterday)
        let twoDaysAgoLog = try DailyLog(date: twoDaysAgo)
        
        // Add distinguishing food items
        let todayFood = try FoodItem(name: "Today Food", calories: 100, timestamp: today)
        let yesterdayFood = try FoodItem(name: "Yesterday Food", calories: 200, timestamp: yesterday)
        let twoDaysAgoFood = try FoodItem(name: "Two Days Ago Food", calories: 300, timestamp: twoDaysAgo)
        
        todayLog.foodItems.append(todayFood)
        yesterdayLog.foodItems.append(yesterdayFood)
        twoDaysAgoLog.foodItems.append(twoDaysAgoFood)
        
        try await dataStore.saveDailyLog(todayLog)
        try await dataStore.saveDailyLog(yesterdayLog)
        try await dataStore.saveDailyLog(twoDaysAgoLog)
        
        // Fetch yesterday's log
        let fetchedLog = try await dataStore.fetchDailyLog(for: yesterday)
        
        // Verify
        #expect(fetchedLog != nil)
        #expect(fetchedLog?.foodItems.count == 1)
        #expect(fetchedLog?.foodItems.first?.name == "Yesterday Food")
        #expect(fetchedLog?.totalCalories == 200)
    }
    
    @Test("Fetch historical logs within date range returns all logs")
    func testFetchHistoricalLogs_DateRange_ReturnsAllLogs() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create logs for different dates
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        
        let todayLog = try DailyLog(date: today)
        let yesterdayLog = try DailyLog(date: yesterday)
        let twoDaysAgoLog = try DailyLog(date: twoDaysAgo)
        let threeDaysAgoLog = try DailyLog(date: threeDaysAgo)
        
        try await dataStore.saveDailyLog(todayLog)
        try await dataStore.saveDailyLog(yesterdayLog)
        try await dataStore.saveDailyLog(twoDaysAgoLog)
        try await dataStore.saveDailyLog(threeDaysAgoLog)
        
        // Fetch historical logs from 3 days ago to today
        let logs = try await dataStore.fetchHistoricalLogs(from: threeDaysAgo, to: today)
        
        // Verify
        #expect(logs.count == 4)
        #expect(logs[0].date == Calendar.current.startOfDay(for: threeDaysAgo))
        #expect(logs[1].date == Calendar.current.startOfDay(for: twoDaysAgo))
        #expect(logs[2].date == Calendar.current.startOfDay(for: yesterday))
        #expect(logs[3].date == Calendar.current.startOfDay(for: today))
    }
    
    @Test("Fetch non-existent date returns nil")
    func testFetchHistoricalLog_NonExistentDate_ReturnsNil() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create log for today only
        let today = Date()
        let todayLog = try DailyLog(date: today)
        try await dataStore.saveDailyLog(todayLog)
        
        // Try to fetch yesterday's log (doesn't exist)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let fetchedLog = try await dataStore.fetchDailyLog(for: yesterday)
        
        // Verify
        #expect(fetchedLog == nil)
    }
    
    @Test("Historical log with exercise items calculates net calories correctly")
    func testHistoricalLog_WithExercise_CalculatesNetCalories() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create log with food and exercise
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let log = try DailyLog(date: yesterday)
        
        let food = try FoodItem(name: "Meal", calories: 500, timestamp: yesterday)
        let exercise = try ExerciseItem(
            name: "Running",
            caloriesBurned: 200,
            durationMinutes: 30,
            timestamp: yesterday
        )
        
        log.foodItems.append(food)
        log.exerciseItems.append(exercise)
        
        try await dataStore.saveDailyLog(log)
        
        // Fetch and verify
        let fetchedLog = try await dataStore.fetchDailyLog(for: yesterday)
        
        #expect(fetchedLog != nil)
        #expect(fetchedLog?.totalCalories == 500)
        #expect(fetchedLog?.totalExerciseCalories == 200)
        #expect(fetchedLog?.netCalories == 300)
    }
    
    @Test("Historical log with daily goal calculates remaining calories")
    func testHistoricalLog_WithGoal_CalculatesRemaining() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create log with goal
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let log = try DailyLog(date: yesterday, dailyGoal: 2000)
        
        let food = try FoodItem(name: "Meal", calories: 1500, timestamp: yesterday)
        log.foodItems.append(food)
        
        try await dataStore.saveDailyLog(log)
        
        // Fetch and verify
        let fetchedLog = try await dataStore.fetchDailyLog(for: yesterday)
        
        #expect(fetchedLog != nil)
        #expect(fetchedLog?.dailyGoal == 2000)
        #expect(fetchedLog?.remainingCalories == 500)
    }
    
    @Test("Date normalization ensures consistent retrieval")
    func testDateNormalization_DifferentTimes_SameLog() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyLog.self, FoodItem.self, ExerciseItem.self, configurations: config)
        let context = ModelContext(container)
        let dataStore = DataStore(modelContext: context)
        
        // Create log with specific date
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let log = try DailyLog(date: yesterday)
        
        try await dataStore.saveDailyLog(log)
        
        // Fetch with different times on the same day
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: yesterday)!
        let evening = calendar.date(bySettingHour: 20, minute: 30, second: 45, of: yesterday)!
        
        let fetchedMorning = try await dataStore.fetchDailyLog(for: morning)
        let fetchedEvening = try await dataStore.fetchDailyLog(for: evening)
        
        // Verify both return the same log
        #expect(fetchedMorning != nil)
        #expect(fetchedEvening != nil)
        #expect(fetchedMorning?.id == fetchedEvening?.id)
    }
}
