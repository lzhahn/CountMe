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
/// - Empty results state handling
///
/// Requirements: 2.1, 2.2
struct FoodSearchView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content area
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
        }
    }
    
    // MARK: - View Components
    
    /// Search bar with query binding
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search for food...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchQuery) { oldValue, newValue in
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
        VStack(spacing: 16) {
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
    
    // MARK: - Actions
    
    /// Performs a search using the current query
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
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

// MARK: - Preview

#Preview {
    // Create an in-memory model container for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, configurations: config)
    let context = ModelContext(container)
    
    let tracker = CalorieTracker(
        dataStore: DataStore(modelContext: context),
        apiClient: NutritionAPIClient(
            consumerKey: "preview",
            consumerSecret: "preview"
        )
    )
    
    FoodSearchView(tracker: tracker)
}
