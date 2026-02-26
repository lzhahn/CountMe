//
//  ContentView.swift
//  CountMe
//
//  Main content view that initializes and displays the calorie tracking interface
//

import SwiftUI
import SwiftData
import FirebaseAuth

/// Main content view that serves as the entry point for the calorie tracking application
///
/// This view:
/// - Initializes CalorieTracker with required dependencies (DataStore, NutritionAPIClient)
/// - Sets up navigation structure between main views
/// - Loads the current day's log on launch
/// - Handles date transitions when app comes to foreground
///
/// Requirements: All (main integration point)
struct ContentView: View {
    /// SwiftData model context for persistence operations
    @Environment(\.modelContext) private var modelContext
    
    /// Scene phase for detecting app foreground/background transitions
    @Environment(\.scenePhase) private var scenePhase
    
    /// Firebase authentication service from environment
    @EnvironmentObject var authService: FirebaseAuthService
    
    /// Shared sync engine from environment
    @Environment(\.syncEngine) private var envSyncEngine
    
    /// Shared data store from environment
    @Environment(\.dataStore) private var envDataStore
    
    /// The calorie tracker business logic instance
    @State private var tracker: CalorieTracker?
    
    /// The custom meal manager business logic instance
    @State private var customMealManager: CustomMealManager?
    
    /// Loading state during initialization
    @State private var isLoading = true
    
    /// Navigation path for programmatic navigation
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        Group {
            if isLoading {
                // Loading state during initialization
                ProgressView("Loading...")
            } else if let tracker = tracker, 
                      let customMealManager = customMealManager,
                      let syncEngine = envSyncEngine,
                      let dataStore = envDataStore {
                // Main navigation structure
                TabView {
                    // Main calorie tracking view
                    MainCalorieView(
                        tracker: tracker,
                        customMealManager: customMealManager,
                        syncEngine: syncEngine,
                        userId: authService.currentUser?.uid
                    )
                    .tabItem {
                        Label("Log", systemImage: "list.bullet")
                    }
                    
                    // Profile view
                    ProfileView(
                        authService: authService,
                        syncEngine: syncEngine,
                        dataStore: dataStore
                    )
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                }
            } else {
                // Error state if initialization fails
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Failed to Initialize")
                        .font(.headline)
                    
                    Text("Unable to start the calorie tracker. Please restart the app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .task {
            await initializeTracker()
        }
        .task(id: "syncReload") {
            // After initial sync settles, reload the log to pick up cloud data
            // that arrived via snapshot listeners after the initial loadLog
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if let tracker = tracker {
                try? await tracker.loadLog(for: tracker.selectedDate)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Check for date changes when app comes to foreground
            if newPhase == .active, let tracker = tracker {
                Task {
                    try? await tracker.checkForDateChange()
                }
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Initializes the CalorieTracker with dependencies and loads the current day's log
    private func initializeTracker() async {
        // Use the shared DataStore from environment (same instance the sync engine uses)
        guard let sharedDataStore = envDataStore else {
            print("⚠️ DataStore not available from environment")
            isLoading = false
            return
        }
        
        // Initialize NutritionAPIClient for OpenFoodFacts (no API key needed!)
        let apiClient = NutritionAPIClient()
        
        // Initialize AIRecipeParser
        let aiParser = AIRecipeParser()
        
        // Create CalorieTracker using the SHARED data store
        let newTracker = CalorieTracker(
            dataStore: sharedDataStore,
            apiClient: apiClient,
            selectedDate: Date(),
            syncEngine: envSyncEngine,
            userId: authService.currentUser?.uid
        )
        
        // Create CustomMealManager using the SHARED data store
        let newCustomMealManager = CustomMealManager(
            dataStore: sharedDataStore,
            aiParser: aiParser,
            syncEngine: envSyncEngine,
            userId: authService.currentUser?.uid
        )
        
        // Load current day's log
        do {
            try await newTracker.loadLog(for: Date())
            
            // Update state on main actor
            await MainActor.run {
                tracker = newTracker
                customMealManager = newCustomMealManager
                isLoading = false
            }
            
            // Run retention policy on app launch if user is authenticated
            if let userId = authService.currentUser?.uid, let syncEngine = envSyncEngine {
                print("Running retention policy on app launch for user: \(userId)")
                syncEngine.scheduleRetentionPolicyOnLaunch(userId: userId)
            }
            
        } catch {
            print("Failed to load initial log: \(error)")
            
            // Still set tracker even if load fails - user can retry
            await MainActor.run {
                tracker = newTracker
                customMealManager = newCustomMealManager
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DailyLog.self, FoodItem.self, ExerciseItem.self, CustomMeal.self, Ingredient.self], inMemory: true)
}
