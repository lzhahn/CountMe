//
//  CountMeApp.swift
//  CountMe
//
//  Created by Lucas Hahn on 1/19/26.
//

import SwiftUI
import SwiftData

@main
struct CountMeApp: App {
    
    // Firebase Authentication Service
    @StateObject private var authService = FirebaseAuthService()
    
    // Initialize Firebase on app startup
    init() {
        FirebaseConfig.shared.configure()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            DailyLog.self,
            ExerciseItem.self,
            CustomMeal.self,
            Ingredient.self
        ])
        
        // Enable automatic migration and allow model changes
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, try to delete the old store and create a new one
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to reset database...")
            
            // Get the default store URL
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            
            // Try to delete the old database files
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            
            // Try creating the container again
            do {
                print("✅ Database reset successful, creating new container...")
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()
    
    // DataStore actor for local persistence
    private var dataStore: DataStore {
        DataStore(modelContext: sharedModelContainer.mainContext)
    }
    
    // Firebase Sync Engine
    private var syncEngine: FirebaseSyncEngine {
        FirebaseSyncEngine(dataStore: dataStore)
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationView()
                .environmentObject(authService)
                .environment(\.syncEngine, syncEngine)
                .environment(\.dataStore, dataStore)
        }
        .modelContainer(sharedModelContainer)
    }
}

// Environment key for FirebaseSyncEngine
private struct SyncEngineKey: EnvironmentKey {
    static let defaultValue: FirebaseSyncEngine? = nil
}

extension EnvironmentValues {
    var syncEngine: FirebaseSyncEngine? {
        get { self[SyncEngineKey.self] }
        set { self[SyncEngineKey.self] = newValue }
    }
}

// Environment key for DataStore
private struct DataStoreKey: EnvironmentKey {
    static let defaultValue: DataStore? = nil
}

extension EnvironmentValues {
    var dataStore: DataStore? {
        get { self[DataStoreKey.self] }
        set { self[DataStoreKey.self] = newValue }
    }
}
