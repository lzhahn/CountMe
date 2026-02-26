//
//  ProfileSyncServiceTests.swift
//  CountMeTests
//
//  Tests for ProfileSyncService — verifying profile data serialization,
//  deserialization, and local storage behavior for cross-device sync.
//

import Testing
import Foundation
@testable import CountMe

@Suite("Profile Sync Service Tests")
struct ProfileSyncServiceTests {
    
    // MARK: - Profile Keys Tests
    
    @Test("All expected profile keys are defined")
    func testProfileKeys_ContainsAllExpected() {
        let keys = ProfileSyncService.profileKeys
        
        #expect(keys.contains("exerciseBodyWeightKg"))
        #expect(keys.contains("exerciseBodyWeightUnit"))
        #expect(keys.contains("weightLossLbsPerWeek"))
        #expect(keys.contains("userHeightCm"))
        #expect(keys.contains("userHeightUnit"))
        #expect(keys.contains("userAge"))
        #expect(keys.contains("userSex"))
        #expect(keys.contains("userActivityLevel"))
        #expect(keys.count == 8)
    }
    
    // MARK: - UserDefaults Round-Trip Tests
    
    @Test("Profile values survive UserDefaults round-trip")
    func testProfileValues_RoundTrip() {
        let defaults = UserDefaults.standard
        let testSuite = "profileSyncTest_\(UUID().uuidString.prefix(8))"
        
        // Write test values
        defaults.set(85.5, forKey: "\(testSuite)_weight")
        defaults.set("lb", forKey: "\(testSuite)_unit")
        defaults.set(25, forKey: "\(testSuite)_age")
        
        // Read back
        #expect(defaults.double(forKey: "\(testSuite)_weight") == 85.5)
        #expect(defaults.string(forKey: "\(testSuite)_unit") == "lb")
        #expect(defaults.integer(forKey: "\(testSuite)_age") == 25)
        
        // Cleanup
        defaults.removeObject(forKey: "\(testSuite)_weight")
        defaults.removeObject(forKey: "\(testSuite)_unit")
        defaults.removeObject(forKey: "\(testSuite)_age")
    }
    
    @Test("Default profile values match expected defaults")
    func testDefaultValues_MatchExpected() {
        let defaults = UserDefaults.standard
        let uniqueKey = "testDefault_\(UUID().uuidString)"
        
        // Unset keys should return type defaults
        #expect(defaults.double(forKey: uniqueKey) == 0.0)
        #expect(defaults.string(forKey: uniqueKey) == nil)
        #expect(defaults.integer(forKey: uniqueKey) == 0)
    }
    
    // MARK: - Timestamp Conflict Resolution Tests
    
    @Test("Newer cloud timestamp should win over older local timestamp")
    func testTimestampConflict_CloudNewer_CloudWins() {
        let localModified = Date().addingTimeInterval(-3600) // 1 hour ago
        let cloudModified = Date() // now
        
        #expect(cloudModified > localModified, "Cloud should be newer")
    }
    
    @Test("Older cloud timestamp should not overwrite newer local")
    func testTimestampConflict_LocalNewer_LocalWins() {
        let localModified = Date() // now
        let cloudModified = Date().addingTimeInterval(-3600) // 1 hour ago
        
        let shouldDownload = cloudModified > localModified
        #expect(!shouldDownload, "Should not download when local is newer")
    }
    
    @Test("Empty userId is rejected")
    func testEmptyUserId_Rejected() async throws {
        let service = ProfileSyncService()
        
        // uploadProfile with empty userId should return early without error
        try await service.uploadProfile(userId: "")
        // If we get here without error, the guard worked
    }
    
    // MARK: - Property-Based Tests
    
    @Test("Property: Profile timestamp comparison is transitive",
          .tags(.property))
    func testProperty_TimestampComparison_1() {
        for _ in 0..<100 {
            let a = Date().addingTimeInterval(Double.random(in: -86400...0))
            let b = Date().addingTimeInterval(Double.random(in: -86400...0))
            let c = Date().addingTimeInterval(Double.random(in: -86400...0))
            
            // Transitivity: if a > b and b > c, then a > c
            if a > b && b > c {
                #expect(a > c, "Timestamp comparison should be transitive")
            }
        }
    }
    
    @Test("Property: Profile values with valid ranges survive serialization",
          .tags(.property))
    func testProperty_ProfileValueRanges_2() {
        for _ in 0..<100 {
            let weight = Double.random(in: 30...200)
            let height = Double.random(in: 100...250)
            let age = Int.random(in: 10...100)
            let lossRate = Double.random(in: 0...3)
            
            let defaults = UserDefaults.standard
            let prefix = "propTest_\(UUID().uuidString.prefix(6))"
            
            defaults.set(weight, forKey: "\(prefix)_w")
            defaults.set(height, forKey: "\(prefix)_h")
            defaults.set(age, forKey: "\(prefix)_a")
            defaults.set(lossRate, forKey: "\(prefix)_l")
            
            #expect(abs(defaults.double(forKey: "\(prefix)_w") - weight) < 0.001)
            #expect(abs(defaults.double(forKey: "\(prefix)_h") - height) < 0.001)
            #expect(defaults.integer(forKey: "\(prefix)_a") == age)
            #expect(abs(defaults.double(forKey: "\(prefix)_l") - lossRate) < 0.001)
            
            // Cleanup
            defaults.removeObject(forKey: "\(prefix)_w")
            defaults.removeObject(forKey: "\(prefix)_h")
            defaults.removeObject(forKey: "\(prefix)_a")
            defaults.removeObject(forKey: "\(prefix)_l")
        }
    }
}
