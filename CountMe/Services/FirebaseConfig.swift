//
//  FirebaseConfig.swift
//  CountMe
//
//  Firebase configuration and initialization
//

import Foundation
import FirebaseCore
import FirebaseFirestore

/// Manages Firebase initialization and configuration
@MainActor
class FirebaseConfig {
    
    /// Shared singleton instance
    static let shared = FirebaseConfig()
    
    /// Firestore database instance
    private(set) var db: Firestore?
    
    /// Indicates whether Firebase has been initialized
    private(set) var isInitialized = false
    
    private init() {}
    
    /// Initializes Firebase with the GoogleService-Info.plist configuration
    /// This should be called once at app startup
    func configure() {
        guard !isInitialized else {
            print("⚠️ Firebase already initialized")
            return
        }
        
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Get Firestore instance
        db = Firestore.firestore()
        
        // Configure Firestore settings for offline persistence
        configureFirestoreOfflinePersistence()
        
        isInitialized = true
        print("✅ Firebase initialized successfully")
    }
    
    /// Configures Firestore for offline persistence
    /// This enables the app to work offline and sync when connectivity is restored
    private func configureFirestoreOfflinePersistence() {
        guard let db = db else {
            print("⚠️ Cannot configure Firestore: database not initialized")
            return
        }
        
        let settings = FirestoreSettings()
        
        // Enable offline persistence with cache size
        // 100 MB cache size (default is 40 MB)
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        
        // Apply settings
        db.settings = settings
        
        print("✅ Firestore offline persistence configured")
    }
    
    /// Returns the Firestore database instance
    /// - Throws: FirebaseConfigError if Firebase is not initialized
    func getFirestore() throws -> Firestore {
        guard isInitialized, let db = db else {
            throw FirebaseConfigError.notInitialized
        }
        return db
    }
}

/// Errors related to Firebase configuration
enum FirebaseConfigError: LocalizedError {
    case notInitialized
    case configurationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Firebase has not been initialized. Call FirebaseConfig.shared.configure() first."
        case .configurationFailed(let reason):
            return "Firebase configuration failed: \(reason)"
        }
    }
}
