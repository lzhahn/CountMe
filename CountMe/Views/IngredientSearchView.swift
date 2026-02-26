//
//  IngredientSearchView.swift
//  CountMe
//
//  Search view for finding and adding ingredients from the USDA nutrition database
//

import SwiftUI

/// Allows users to search the USDA nutrition database and select items to add as ingredients
///
/// This view provides:
/// - Search bar with debounced API queries
/// - Search results list with nutritional info
/// - Multi-select with checkmarks
/// - Add selected items callback
/// - Error handling with retry
/// - Network offline warning
///
/// Requirements: 2.1, 2.2, 5.1
struct IngredientSearchView: View {
    /// The nutrition API client for searching
    let apiClient: NutritionAPIClient

    /// Callback when user confirms selected items
    let onAdd: ([NutritionSearchResult]) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Search query text
    @State private var searchQuery: String = ""

    /// Search results from the API
    @State private var searchResults: [NutritionSearchResult] = []

    /// Loading state during API search
    @State private var isSearching: Bool = false

    /// Error message to display
    @State private var errorMessage: String?

    /// Selected results to add
    @State private var selectedResults: Set<String> = []

    /// Task for debounced search
    @State private var searchTask: Task<Void, Never>?

    /// Network reachability monitor
    @State private var networkMonitor = NetworkMonitor()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if !networkMonitor.isConnected {
                    networkOfflineWarning
                }

                if isSearching {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    emptyResultsView
                } else if searchResults.isEmpty {
                    initialStateView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedResults.count))") {
                        let selected = searchResults.filter { selectedResults.contains($0.id) }
                        onAdd(selected)
                        dismiss()
                    }
                    .disabled(selectedResults.isEmpty)
                }
            }
            .onAppear { networkMonitor.start() }
            .onDisappear { networkMonitor.stop() }
        }
    }

    // MARK: - Components

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search for an ingredient...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { performSearch() }
                .onChange(of: searchQuery) { _, newValue in
                    searchTask?.cancel()
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else {
                        searchResults = []
                        errorMessage = nil
                        isSearching = false
                        return
                    }
                    isSearching = true
                    errorMessage = nil
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run { performSearch() }
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Search Failed").font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button { performSearch() } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Results Found").font(.headline)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var initialStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Search Ingredients").font(.headline)
            Text("Search the nutrition database to add ingredients with pre-filled nutritional data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var resultsList: some View {
        List {
            ForEach(searchResults) { result in
                HStack(spacing: 12) {
                    Image(systemName: selectedResults.contains(result.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedResults.contains(result.id) ? .blue : .gray)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text("\(Int(result.calories)) cal")
                                .font(.caption)
                                .foregroundColor(.blue)

                            if let p = result.protein {
                                Text("\(Int(p))g P")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let c = result.carbohydrates {
                                Text("\(Int(c))g C")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let f = result.fats {
                                Text("\(Int(f))g F")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let serving = result.servingSize, let unit = result.servingUnit {
                            Text("Serving: \(serving) \(unit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedResults.contains(result.id) {
                        selectedResults.remove(result.id)
                    } else {
                        selectedResults.insert(result.id)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var networkOfflineWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("No Internet Connection")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Ingredient search requires an internet connection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            isSearching = false
            return
        }
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection. Please check your network and try again."
            isSearching = false
            return
        }
        errorMessage = nil
        Task {
            do {
                let results = try await apiClient.searchFood(query: searchQuery)
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
}
