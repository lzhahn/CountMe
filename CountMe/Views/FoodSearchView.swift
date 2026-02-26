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
    
    /// Build custom meal mode state
    @State private var isBuildingMeal: Bool = false
    
    /// Selected search results for building a custom meal
    @State private var selectedResults: [NutritionSearchResult] = []
    
    /// Controls navigation to meal builder review view
    @State private var showingMealBuilderReview: Bool = false
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    /// Controls navigation to barcode scanner
    @State private var showingBarcodeScanner: Bool = false
    
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
                    if isBuildingMeal {
                        Button("Cancel Build") {
                            cancelBuildMode()
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isBuildingMeal {
                        Button {
                            showingMealBuilderReview = true
                        } label: {
                            Label("Review & Save", systemImage: "checkmark.circle")
                        }
                        .disabled(selectedResults.isEmpty)
                    } else {
                        Menu {
                            Button {
                                showingBarcodeScanner = true
                            } label: {
                                Label("Scan Barcode", systemImage: "barcode.viewfinder")
                            }
                            
                            Button {
                                showingManualEntry = true
                            } label: {
                                Label("Manual Entry", systemImage: "pencil.circle")
                            }
                            
                            if selectedTab == .api {
                                Button {
                                    enterBuildMode()
                                } label: {
                                    Label("Build Custom Meal", systemImage: "square.stack.3d.up")
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(tracker: tracker)
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(tracker: tracker)
            }
            .sheet(item: $selectedResult) { result in
                ServingAdjustmentView(searchResult: result, tracker: tracker)
            }
            .sheet(isPresented: $showingMealBuilderReview) {
                MealBuilderReviewView(
                    sourceItems: .searchResults(selectedResults),
                    manager: customMealManager,
                    onComplete: {
                        // Exit build mode, clear selections, and show success toast
                        isBuildingMeal = false
                        selectedResults = []
                        toastMessage = "Custom meal created successfully"
                        toastStyle = .success
                        showingToast = true
                    }
                )
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
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
            searchTask?.cancel()
            searchQuery = ""
            searchResults = []
            errorMessage = nil
            isSearching = false
        }
    }
    
    /// API search content area
    @ViewBuilder
    private var apiSearchContent: some View {
        VStack(spacing: 0) {
            // Build mode banner
            if isBuildingMeal {
                buildModeBanner
            }
            
            // Search results or states
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
            
            // Selected items summary (shown at bottom when building)
            if isBuildingMeal && !selectedResults.isEmpty {
                selectedItemsSummary
            }
        }
    }
    
    /// Custom meals content area
    @ViewBuilder
    private var customMealsContent: some View {
        CustomMealsLibraryContentView(
            manager: customMealManager,
            apiClient: tracker.nutritionAPIClient,
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
                        
                        let trimmedQuery = newValue.trimmingCharacters(in: .whitespaces)
                        
                        guard !trimmedQuery.isEmpty else {
                            searchResults = []
                            errorMessage = nil
                            isSearching = false
                            return
                        }
                        
                        // Show loading immediately when user starts typing
                        isSearching = true
                        errorMessage = nil
                        
                        searchTask = Task {
                            // Wait 500ms before searching
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            
                            // Check if task was cancelled - but don't reset isSearching here
                            // because a new task may have already started
                            guard !Task.isCancelled else {
                                return
                            }
                            
                            await MainActor.run {
                                performSearch()
                            }
                        }
                    }
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchTask?.cancel()
                    searchQuery = ""
                    searchResults = []
                    errorMessage = nil
                    isSearching = false
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
                HStack(spacing: 12) {
                    // Selection checkbox (only in build mode)
                    if isBuildingMeal {
                        Button {
                            toggleSelection(result)
                        } label: {
                            Image(systemName: isSelected(result) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected(result) ? .blue : .gray)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Search result row
                    SearchResultRow(result: result)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isBuildingMeal {
                                toggleSelection(result)
                            } else {
                                selectResult(result)
                            }
                        }
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
    
    /// Build mode banner
    private var buildModeBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build Custom Meal Mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Select multiple items to create a custom meal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
        }
    }
    
    /// Selected items summary at bottom
    private var selectedItemsSummary: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Selected Items (\(selectedResults.count))")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        selectedResults = []
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
                
                // Nutritional summary
                HStack(spacing: 16) {
                    nutritionalSummaryBadge(
                        label: "Calories",
                        value: totalSelectedCalories,
                        unit: "cal",
                        color: .blue
                    )
                    
                    if totalSelectedProtein > 0 {
                        nutritionalSummaryBadge(
                            label: "Protein",
                            value: totalSelectedProtein,
                            unit: "g",
                            color: .blue
                        )
                    }
                    
                    if totalSelectedCarbs > 0 {
                        nutritionalSummaryBadge(
                            label: "Carbs",
                            value: totalSelectedCarbs,
                            unit: "g",
                            color: .green
                        )
                    }
                    
                    if totalSelectedFats > 0 {
                        nutritionalSummaryBadge(
                            label: "Fats",
                            value: totalSelectedFats,
                            unit: "g",
                            color: .orange
                        )
                    }
                }
                
                // Selected items list (scrollable if many)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedResults) { result in
                            selectedItemChip(result)
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        // Continue building - just dismiss this summary, stay in build mode
                    } label: {
                        Text("Continue Building")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        showingMealBuilderReview = true
                    } label: {
                        Text("Review & Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    /// Nutritional summary badge
    private func nutritionalSummaryBadge(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text("\(Int(value))")
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Selected item chip with remove button
    private func selectedItemChip(_ result: NutritionSearchResult) -> some View {
        HStack(spacing: 6) {
            Text(result.name)
                .font(.caption)
                .lineLimit(1)
            
            Button {
                toggleSelection(result)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties for Selected Items
    
    /// Total calories of selected items
    private var totalSelectedCalories: Double {
        selectedResults.reduce(0) { $0 + $1.calories }
    }
    
    /// Total protein of selected items
    private var totalSelectedProtein: Double {
        selectedResults.reduce(0) { $0 + ($1.protein ?? 0) }
    }
    
    /// Total carbs of selected items
    private var totalSelectedCarbs: Double {
        selectedResults.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }
    
    /// Total fats of selected items
    private var totalSelectedFats: Double {
        selectedResults.reduce(0) { $0 + ($1.fats ?? 0) }
    }
    
    // MARK: - Actions
    
    /// Enters build custom meal mode
    private func enterBuildMode() {
        isBuildingMeal = true
        selectedResults = []
    }
    
    /// Cancels build custom meal mode
    private func cancelBuildMode() {
        isBuildingMeal = false
        selectedResults = []
    }
    
    /// Checks if a result is selected
    private func isSelected(_ result: NutritionSearchResult) -> Bool {
        selectedResults.contains { $0.id == result.id }
    }
    
    /// Toggles selection of a search result
    private func toggleSelection(_ result: NutritionSearchResult) {
        if let index = selectedResults.firstIndex(where: { $0.id == result.id }) {
            selectedResults.remove(at: index)
        } else {
            selectedResults.append(result)
        }
    }
    
    /// Performs a search using the current query
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            isSearching = false
            return
        }
        
        // Check network connectivity before searching
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection. Please check your network and try again."
            isSearching = false
            return
        }
        
        // isSearching is already set to true in onChange, so don't set it again
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

    /// Optional API client for ingredient search in manual entry
    var apiClient: NutritionAPIClient?
    
    /// Search query text (bound from parent)
    @Binding var searchQuery: String
    
    /// Task for debounced search
    @State private var searchTask: Task<Void, Never>?
    
    /// Filtered meals based on search query
    @State private var filteredMeals: [CustomMeal] = []
    
    /// Controls navigation to custom meal method picker
    @State private var showingMealMethodPicker: Bool = false
    
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
        .sheet(isPresented: $showingMealMethodPicker) {
            CustomMealMethodPickerView(manager: manager, apiClient: apiClient)
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
            
            Text("Create your first custom meal using AI parsing or manual entry.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingMealMethodPicker = true
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
        apiClient: NutritionAPIClient()
    )
    
    let aiParser = AIRecipeParser()
    let customMealManager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    FoodSearchView(tracker: tracker, customMealManager: customMealManager)
}
