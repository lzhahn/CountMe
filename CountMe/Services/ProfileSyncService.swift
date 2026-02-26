//
//  ProfileSyncService.swift
//  CountMe
//
//  Syncs user profile settings (body weight, height, age, goals, etc.)
//  between local AppStorage and Firestore so they persist across devices.
//

import Foundation
import FirebaseFirestore

/// Service responsible for syncing user profile settings to/from Firestore
///
/// Profile data is stored locally in UserDefaults (via @AppStorage) and mirrored
/// to a single Firestore document at `users/{userId}/profile/settings`.
/// On login, the cloud version is downloaded and applied to local storage.
/// On profile changes, the local values are uploaded to the cloud.
///
/// This uses last-write-wins conflict resolution based on a `lastModified` timestamp.
actor ProfileSyncService {
    
    private let db: Firestore
    
    /// All profile keys synced to Firestore
    static let profileKeys: [String] = [
        "exerciseBodyWeightKg",
        "exerciseBodyWeightUnit",
        "weightLossLbsPerWeek",
        "userHeightCm",
        "userHeightUnit",
        "userAge",
        "userSex",
        "userActivityLevel"
    ]
    
    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }
    
    // MARK: - Firestore Path
    
    /// Returns the Firestore document path for a user's profile settings
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Firestore document reference
    private func profileDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("profile").document("settings")
    }
    
    // MARK: - Upload
    
    /// Uploads current local profile settings to Firestore
    ///
    /// Reads all profile keys from UserDefaults and writes them as a single
    /// Firestore document. Includes a `lastModified` timestamp for conflict resolution.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Throws: Firestore errors if the upload fails
    func uploadProfile(userId: String) async throws {
        guard !userId.isEmpty else { return }
        
        let defaults = UserDefaults.standard
        var data: [String: Any] = [
            "lastModified": Timestamp(date: Date()),
            "userId": userId
        ]
        
        // Read each profile key from UserDefaults
        data["exerciseBodyWeightKg"] = defaults.double(forKey: "exerciseBodyWeightKg")
        data["exerciseBodyWeightUnit"] = defaults.string(forKey: "exerciseBodyWeightUnit") ?? "kg"
        data["weightLossLbsPerWeek"] = defaults.double(forKey: "weightLossLbsPerWeek")
        data["userHeightCm"] = defaults.double(forKey: "userHeightCm")
        data["userHeightUnit"] = defaults.string(forKey: "userHeightUnit") ?? "cm"
        data["userAge"] = defaults.integer(forKey: "userAge")
        data["userSex"] = defaults.string(forKey: "userSex") ?? "male"
        data["userActivityLevel"] = defaults.string(forKey: "userActivityLevel") ?? "moderate"
        
        try await profileDocument(userId: userId).setData(data, merge: true)
        print("✅ Profile settings uploaded to cloud")
    }
    
    // MARK: - Download
    
    /// Downloads profile settings from Firestore and applies them to local storage
    ///
    /// Fetches the user's profile document from Firestore. If the cloud version
    /// is newer than the local version (or no local version exists), applies the
    /// cloud values to UserDefaults so @AppStorage picks them up automatically.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Throws: Firestore errors if the download fails
    func downloadProfile(userId: String) async throws {
        guard !userId.isEmpty else { return }
        
        let document = try await profileDocument(userId: userId).getDocument()
        
        guard let data = document.data(), !data.isEmpty else {
            print("ℹ️ No cloud profile found for user — using local defaults")
            return
        }
        
        // Validate userId matches (defense in depth)
        if let docUserId = data["userId"] as? String, docUserId != userId {
            print("⚠️ Profile document userId mismatch, skipping download")
            return
        }
        
        // Check if cloud is newer than local
        let cloudModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date.distantPast
        let localModified = UserDefaults.standard.object(forKey: "profileLastModified") as? Date ?? Date.distantPast
        
        guard cloudModified > localModified else {
            print("ℹ️ Local profile is newer than cloud — skipping download")
            return
        }
        
        // Apply cloud values to UserDefaults
        let defaults = UserDefaults.standard
        
        if let v = data["exerciseBodyWeightKg"] as? Double { defaults.set(v, forKey: "exerciseBodyWeightKg") }
        if let v = data["exerciseBodyWeightUnit"] as? String { defaults.set(v, forKey: "exerciseBodyWeightUnit") }
        if let v = data["weightLossLbsPerWeek"] as? Double { defaults.set(v, forKey: "weightLossLbsPerWeek") }
        if let v = data["userHeightCm"] as? Double { defaults.set(v, forKey: "userHeightCm") }
        if let v = data["userHeightUnit"] as? String { defaults.set(v, forKey: "userHeightUnit") }
        if let v = data["userAge"] as? Int { defaults.set(v, forKey: "userAge") }
        if let v = data["userSex"] as? String { defaults.set(v, forKey: "userSex") }
        if let v = data["userActivityLevel"] as? String { defaults.set(v, forKey: "userActivityLevel") }
        
        // Update local timestamp
        defaults.set(cloudModified, forKey: "profileLastModified")
        
        print("✅ Profile settings downloaded from cloud")
    }
}
