//
//  CustomMealsLibraryView.swift
//  CountMe
//
//  View for browsing and managing saved custom meals
//

import SwiftUI
import SwiftData

/// Library view for browsing, searching, and managing saved custom meals
///
/// This view provides:
/// - Search bar with real-time filtering (case-insensitive)
/// - List of custom meals with nutritional summaries
/// - Creation and last used dates for each meal
/// - Swipe-to-delete for meal removal
/// - Add button to create new custom meals
/// - Empty state with helpful messaging
/// - "No results" message for empty searches
/// - Sort by most recently used (lastUsedAt descending)
///
/// **Validates: Requirements 2.2, 3.1, 12.1, 12.2, 12.4**
struct CustomMealsLibraryView: View {
    /// The custom meal manager business logic
    @Bindable var manager: CustomMealManager
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Search query text
    @State private var searchQuery: String = ""
    
    /// Controls navigation to recipe input view
    @State private var showingRecipeInput: Bool = false
    
    /// Task for debounced search
    @State private var searchTask: Task<Void, Never>?
    
    /// Filtered meals based on search query
    @State private var filteredMeals: [CustomMeal] = []
    
    /// Network reachability monitor
    @State private var networkMonitor = NetworkMonitor()
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    /// Meal pending deletion (for confirmation)
    @State private var mealToDelete: CustomMeal?
    
    /// Controls delete confirmation alert
    @State private var showingDeleteAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Network status banner (informational only - custom meals work offline)
                if !networkMonitor.isConnected {
                    offlineInfoBanner
                }
                
                // Search bar
                searchBar
                
                // Content area
                if manager.isLoading {
                    loadingView
                } else if let error = manager.errorMessage {
                    errorView(error)
                } else if filteredMeals.isEmpty && !searchQuery.isEmpty {
                    noResultsView
                } else if filteredMeals.isEmpty {
                    emptyStateView
                } else {
                    mealsList
                }
            }
            .navigationTitle("Custom Meals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingRecipeInput = true
                    } label: {
                        Label("Add Meal", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingRecipeInput) {
                RecipeInputView(manager: manager)
            }
            .task {
                // Load meals when view appears
                await manager.loadAllCustomMeals()
                updateFilteredMeals()
            }
            .onChange(of: manager.savedMeals) { _, _ in
                updateFilteredMeals()
            }
            .onAppear {
                networkMonitor.start()
            }
            .onDisappear {
                networkMonitor.stop()
            }
            .alert("Delete Custom Meal", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    mealToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let meal = mealToDelete {
                        deleteMeal(meal)
                    }
                    mealToDelete = nil
                }
            } message: {
                if let meal = mealToDelete {
                    Text("Are you sure you want to delete '\(meal.name)'? This action cannot be undone.")
                }
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
        }
    }
    
    // MARK: - View Components
    
    /// Offline information banner (informational only - custom meals work offline)
    private var offlineInfoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Custom meals are available offline. AI parsing requires internet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
    
    /// Search bar with query binding
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search meals...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onChange(of: searchQuery) { _, newValue in
                    // Debounce search: cancel previous task and start new one
                    searchTask?.cancel()
                    
                    searchTask = Task {
                        // Wait 300ms before filtering
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        
                        // Check if task was cancelled
                        guard !Task.isCancelled else { return }
                        
                        updateFilteredMeals()
                    }
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    updateFilteredMeals()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    /// Loading indicator
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading meals...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Error view with retry option
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error Loading Meals")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await manager.loadAllCustomMeals()
                    updateFilteredMeals()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// No results view when search returns empty
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.headline)
            
            Text("No meals match '\(searchQuery)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                searchQuery = ""
                updateFilteredMeals()
            } label: {
                Text("Clear Search")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Empty state when no meals are saved
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Custom Meals Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first custom meal by describing a recipe. Our AI will break it down into ingredients with nutritional information.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingRecipeInput = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Custom Meal")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// List of custom meals
    private var mealsList: some View {
        List {
            ForEach(filteredMeals) { meal in
                NavigationLink {
                    CustomMealDetailView(meal: meal, manager: manager)
                } label: {
                    CustomMealRow(meal: meal)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        mealToDelete = meal
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    /// Updates the filtered meals based on search query
    private func updateFilteredMeals() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if query.isEmpty {
            // Show all meals sorted by most recently used
            filteredMeals = manager.savedMeals
        } else {
            // Filter by name (case-insensitive) and maintain sort order
            filteredMeals = manager.savedMeals.filter { meal in
                meal.name.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    /// Deletes a custom meal
    private func deleteMeal(_ meal: CustomMeal) {
        let mealName = meal.name
        
        Task {
            do {
                try await manager.deleteCustomMeal(meal)
                updateFilteredMeals()
                
                // Show success toast
                toastMessage = "'\(mealName)' deleted successfully"
                toastStyle = .success
                withAnimation {
                    showingToast = true
                }
            } catch {
                // Show error toast
                toastMessage = manager.errorMessage ?? "Unable to delete meal"
                toastStyle = .error
                withAnimation {
                    showingToast = true
                }
            }
        }
    }
}

// MARK: - Custom Meal Row Component

/// Row component for displaying a custom meal in the library list
///
/// Shows:
/// - Meal name
/// - Total calories and macro summary
/// - Creation date
/// - Last used date
struct CustomMealRow: View {
    /// The custom meal to display
    let meal: CustomMeal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meal name
            Text(meal.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Nutritional summary
            HStack(spacing: 16) {
                nutritionalBadge(
                    value: Int(meal.totalCalories),
                    unit: "cal",
                    color: .blue
                )
                
                if meal.totalProtein > 0 {
                    nutritionalBadge(
                        value: Int(meal.totalProtein),
                        unit: "g protein",
                        color: .blue
                    )
                }
                
                if meal.totalCarbohydrates > 0 {
                    nutritionalBadge(
                        value: Int(meal.totalCarbohydrates),
                        unit: "g carbs",
                        color: .green
                    )
                }
                
                if meal.totalFats > 0 {
                    nutritionalBadge(
                        value: Int(meal.totalFats),
                        unit: "g fats",
                        color: .orange
                    )
                }
            }
            
            // Dates
            HStack(spacing: 16) {
                Label {
                    Text("Created \(meal.createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Label {
                    Text("Used \(meal.lastUsedAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Ingredient count
            Text("\(meal.ingredients.count) ingredient\(meal.ingredients.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    /// Nutritional value badge
    private func nutritionalBadge(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let aiParser = AIRecipeParser()
    let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    // Add some sample meals for preview
    let sampleMeal1 = CustomMeal(
        name: "Chicken Stir Fry",
        ingredients: [
            Ingredient(name: "Chicken Breast", quantity: 6, unit: "oz", calories: 187, protein: 35, carbohydrates: 0, fats: 4),
            Ingredient(name: "White Rice", quantity: 1, unit: "cup", calories: 206, protein: 4, carbohydrates: 45, fats: 0.4),
            Ingredient(name: "Broccoli", quantity: 1, unit: "cup", calories: 31, protein: 2.5, carbohydrates: 6, fats: 0.3)
        ],
        createdAt: Date().addingTimeInterval(-86400 * 7),
        lastUsedAt: Date().addingTimeInterval(-3600)
    )
    
    let sampleMeal2 = CustomMeal(
        name: "Protein Smoothie",
        ingredients: [
            Ingredient(name: "Protein Powder", quantity: 1, unit: "scoop", calories: 120, protein: 24, carbohydrates: 3, fats: 1.5),
            Ingredient(name: "Banana", quantity: 1, unit: "piece", calories: 105, protein: 1.3, carbohydrates: 27, fats: 0.4),
            Ingredient(name: "Almond Milk", quantity: 1, unit: "cup", calories: 30, protein: 1, carbohydrates: 1, fats: 2.5)
        ],
        createdAt: Date().addingTimeInterval(-86400 * 3),
        lastUsedAt: Date().addingTimeInterval(-7200)
    )
    
    manager.savedMeals = [sampleMeal1, sampleMeal2]
    
    return CustomMealsLibraryView(manager: manager)
}
