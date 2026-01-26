//
//  FoodSearchView.swift
//  CountMe
//
//  View for searching and selecting food items from the nutrition API
//

import SwiftUI
import SwiftData

/// Food search view that allows users to search for foods and add them to their daily log
///
/// This view provides:
/// - Search bar with query binding
/// - Loading indicator during API search
/// - Search results list
/// - Manual entry button
/// - Browse custom meals button
/// - Empty results state handling
///
/// Requirements: 2.1, 2.2, 3.1, 5.1
struct FoodSearchView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// The custom meal manager for browsing custom meals
    @Bindable var customMealManager: CustomMealManager
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Search query text
    @State private var searchQuery: String = ""
    
    /// Search results from the API
    @State private var searchResults: [NutritionSearchResult] = []
    
    /// Loading state during API search
    @State private var isSearching: Bool = false
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Controls navigation to manual entry view
    @State private var showingManualEntry: Bool = false
    
    /// The selected search result for serving adjustment
    @State private var selectedResult: NutritionSearchResult?
    
    /// Task for debounced search
    @State private var searchTask: Task<Void, Never>?
    
    /// Network reachability monitor
    @State private var networkMonitor = NetworkMonitor()
    
    /// Selected tab (API search or custom meals)
    @State private var selectedTab: SearchTab = .api
    
    /// Available search tabs
    enum SearchTab: String, CaseIterable {
        case api = "API Search"
        case customMeals = "Custom Meals"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Tab picker
                tabPicker
                
                // Network status warning
                if !networkMonitor.isConnected && selectedTab == .api {
                    networkOfflineWarning
                }
                
                // Content area based on selected tab
                if selectedTab == .api {
                    apiSearchContent
                } else {
                    customMealsContent
                }
            }
            .navigationTitle("Search Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Manual Entry", systemImage: "pencil.circle")
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(tracker: tracker)
            }
            .sheet(item: $selectedResult) { result in
                ServingAdjustmentView(searchResult: result, tracker: tracker)
            }
            .onAppear {
                networkMonitor.start()
            }
            .onDisappear {
                networkMonitor.stop()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Tab picker for switching between API search and custom meals
    private var tabPicker: some View {
        Picker("Search Type", selection: $selectedTab) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onChange(of: selectedTab) { _, _ in
            // Clear search query when switching tabs
            searchQuery = ""
            searchResults = []
            errorMessage = nil
        }
    }
    
    /// API search content area
    @ViewBuilder
    private var apiSearchContent: some View {
        if isSearching {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if searchResults.isEmpty && !searchQuery.isEmpty {
            emptyResultsView
        } else if searchResults.isEmpty {
            initialStateView
        } else {
            searchResultsList
        }
    }
    
    /// Custom meals content area
    @ViewBuilder
    private var customMealsContent: some View {
        CustomMealsLibraryContentView(
            manager: customMealManager,
            searchQuery: $searchQuery
        )
    }
    
    /// Search bar with query binding
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(searchPlaceholder, text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    if selectedTab == .api {
                        performSearch()
                    }
                }
                .onChange(of: searchQuery) { oldValue, newValue in
                    if selectedTab == .api {
                        // Debounce search: cancel previous task and start new one
                        searchTask?.cancel()
                        
                        guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                            searchResults = []
                            errorMessage = nil
                            return
                        }
                        
                        searchTask = Task {
                            // Wait 500ms before searching
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            
                            // Check if task was cancelled
                            guard !Task.isCancelled else { return }
                            
                            performSearch()
                        }
                    }
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                    errorMessage = nil
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
    
    /// Search placeholder text based on selected tab
    private var searchPlaceholder: String {
        switch selectedTab {
        case .api:
            return "Search for food..."
        case .customMeals:
            return "Search meals..."
        }
    }
    
    /// Loading indicator during search
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching...")
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
            
            Text("Search Failed")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                performSearch()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Empty results state
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.headline)
            
            Text("Try a different search term or add manually")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingManualEntry = true
            } label: {
                Label("Add Manually", systemImage: "pencil.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Initial state before any search
    private var initialStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Search for Food")
                .font(.headline)
            
            Text("Enter a food name to search the nutrition database")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// List of search results
    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { result in
                SearchResultRow(result: result)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectResult(result)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    /// Network offline warning
    private var networkOfflineWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No Internet Connection")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Food search requires an internet connection. You can still browse custom meals or add items manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
    
    // MARK: - Actions
    
    /// Performs a search using the current query
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        // Check network connectivity before searching
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection. Please check your network and try again."
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await tracker.searchFood(query: searchQuery)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    if let apiError = error as? NutritionAPIError {
                        errorMessage = apiError.errorDescription
                    } else {
                        errorMessage = "An unexpected error occurred. Please try again."
                    }
                }
            }
        }
    }
    
    /// Handles selection of a search result
    /// Shows the serving adjustment view to allow user to modify serving amount
    /// - Parameter result: The selected nutrition search result
    private func selectResult(_ result: NutritionSearchResult) {
        selectedResult = result
    }
}

// MARK: - Custom Meals Library Content View

/// Embedded custom meals library content for use within the search view tabs
///
/// This view provides the same functionality as CustomMealsLibraryView but without
/// the navigation wrapper, allowing it to be embedded in the tab interface.
struct CustomMealsLibraryContentView: View {
    /// The custom meal manager business logic
    @Bindable var manager: CustomMealManager
    
    /// Search query text (bound from parent)
    @Binding var searchQuery: String
    
    /// Task for debounced search
    @State private var searchTask: Task<Void, Never>?
    
    /// Filtered meals based on search query
    @State private var filteredMeals: [CustomMeal] = []
    
    /// Controls navigation to recipe input view
    @State private var showingRecipeInput: Bool = false
    
    /// Meal pending deletion (for confirmation)
    @State private var mealToDelete: CustomMeal?
    
    /// Controls delete confirmation alert
    @State private var showingDeleteAlert: Bool = false
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    var body: some View {
        Group {
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
        .task {
            // Load meals when view appears
            await manager.loadAllCustomMeals()
            updateFilteredMeals()
        }
        .onChange(of: manager.savedMeals) { _, _ in
            updateFilteredMeals()
        }
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
        .sheet(isPresented: $showingRecipeInput) {
            RecipeInputView(manager: manager)
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
    
    // MARK: - View Components
    
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Empty state when no meals are saved
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Custom Meals Yet")
                .font(.headline)
            
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
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
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
                    CustomMealRowCompact(meal: meal)
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

// MARK: - Compact Custom Meal Row Component

/// Compact row component for displaying a custom meal in the embedded list
struct CustomMealRowCompact: View {
    /// The custom meal to display
    let meal: CustomMeal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Meal name
            Text(meal.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Nutritional summary
            HStack(spacing: 12) {
                nutritionalBadge(
                    value: Int(meal.totalCalories),
                    unit: "cal",
                    color: .blue
                )
                
                if meal.totalProtein > 0 {
                    nutritionalBadge(
                        value: Int(meal.totalProtein),
                        unit: "g P",
                        color: .blue
                    )
                }
                
                if meal.totalCarbohydrates > 0 {
                    nutritionalBadge(
                        value: Int(meal.totalCarbohydrates),
                        unit: "g C",
                        color: .green
                    )
                }
                
                if meal.totalFats > 0 {
                    nutritionalBadge(
                        value: Int(meal.totalFats),
                        unit: "g F",
                        color: .orange
                    )
                }
            }
            
            // Ingredient count
            Text("\(meal.ingredients.count) ingredient\(meal.ingredients.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    /// Nutritional value badge
    private func nutritionalBadge(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    // Create an in-memory model container for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self, configurations: config)
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let tracker = CalorieTracker(
        dataStore: dataStore,
        apiClient: NutritionAPIClient(
            consumerKey: "preview",
            consumerSecret: "preview"
        )
    )
    
    let aiParser = AIRecipeParser()
    let customMealManager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    FoodSearchView(tracker: tracker, customMealManager: customMealManager)
}
