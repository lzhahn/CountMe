//
//  ContentView.swift
//  CountMe
//
//  Main content view that initializes and displays the calorie tracking interface
//

import SwiftUI
import SwiftData

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
            } else if let tracker = tracker, let customMealManager = customMealManager {
                // Main navigation structure
                TabView {
                    // Main calorie tracking view
                    MainCalorieView(tracker: tracker, customMealManager: customMealManager)
                        .tabItem {
                            Label("Today", systemImage: "house.fill")
                        }
                    
                    // Historical data view
                    HistoricalView(tracker: tracker)
                        .tabItem {
                            Label("History", systemImage: "calendar")
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
        // Initialize DataStore with model context
        let dataStore = DataStore(modelContext: modelContext)
        
        // Initialize NutritionAPIClient with credentials from Config
        let apiClient = NutritionAPIClient(
            consumerKey: Config.fatSecretConsumerKey,
            consumerSecret: Config.fatSecretConsumerSecret
        )
        
        // Initialize AIRecipeParser
        let aiParser = AIRecipeParser()
        
        // Create CalorieTracker instance
        let newTracker = CalorieTracker(
            dataStore: dataStore,
            apiClient: apiClient,
            selectedDate: Date()
        )
        
        // Create CustomMealManager instance
        let newCustomMealManager = CustomMealManager(
            dataStore: dataStore,
            aiParser: aiParser
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
        .modelContainer(for: [DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self], inMemory: true)
}
