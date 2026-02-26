//
//  HistoricalView.swift
//  CountMe
//
//  View for displaying historical calorie tracking data
//

import SwiftUI
import SwiftData

/// Historical data view that displays calorie logs from previous days
///
/// This view shows:
/// - Date picker for navigation
/// - Selected date prominently displayed
/// - Daily total for selected date
/// - Food items list for that date with sync status
/// - Previous/next day navigation buttons
/// - Offline indicator when network is unavailable
/// - Manual sync trigger via pull-to-refresh
///
/// Requirements: 6.1, 6.2, 6.3, 6.5
struct HistoricalView: View {
    /// DataStore for fetching historical logs
    let dataStore: DataStore
    
    /// Optional sync engine for cloud synchronization
    var syncEngine: FirebaseSyncEngine?
    
    /// Optional authenticated user ID for sync operations
    var userId: String?
    
    /// The currently selected date for viewing historical data
    @State private var selectedDate: Date
    
    /// The currently loaded daily log for the selected date
    @State private var currentLog: DailyLog?
    
    /// Loading state for UI feedback
    @State private var isLoading = false
    
    /// Network reachability monitor
    @State private var networkMonitor = NetworkMonitor()
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    /// Tracks if sync is in progress
    @State private var isSyncing: Bool = false
    
    /// Initializes the historical view with required dependencies
    /// - Parameters:
    ///   - dataStore: DataStore for fetching historical logs
    ///   - syncEngine: Optional sync engine for cloud synchronization
    ///   - userId: Optional authenticated user ID
    ///   - initialDate: Initial date to display (defaults to yesterday)
    init(
        dataStore: DataStore,
        syncEngine: FirebaseSyncEngine? = nil,
        userId: String? = nil,
        initialDate: Date? = nil
    ) {
        self.dataStore = dataStore
        self.syncEngine = syncEngine
        self.userId = userId
        // Default to yesterday if no initial date provided
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        _selectedDate = State(initialValue: initialDate ?? yesterday)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Network status warning
                if !networkMonitor.isConnected {
                    networkOfflineWarning
                }
                
                // Date navigation section
                dateNavigationSection
                
                // Daily summary section
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let log = currentLog {
                    dailySummarySection(log: log)
                    
                    // Food items list
                    foodItemsList(log: log)
                    
                    // Exercise items list
                    exerciseItemsList(log: log)
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let syncEngine = syncEngine, userId != nil {
                        // Show sync status badge
                        syncStatusBadge
                    }
                }
            }
            .refreshable {
                await performManualSync()
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
            .task {
                await loadLogForSelectedDate()
                networkMonitor.start()
            }
            .onDisappear {
                networkMonitor.stop()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Date navigation section with picker and previous/next buttons
    private var dateNavigationSection: some View {
        VStack(spacing: 12) {
            // Date picker
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .onChange(of: selectedDate) { _, newDate in
                Task {
                    await loadLogForSelectedDate()
                }
            }
            
            // Previous/Next day buttons
            HStack(spacing: 20) {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Label("Previous Day", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Text(formattedSelectedDate)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                
                Button {
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    if nextDay <= Date() {
                        selectedDate = nextDay
                    }
                } label: {
                    Label("Next Day", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Daily summary section showing total calories and goal
    private func dailySummarySection(log: DailyLog) -> some View {
        VStack(spacing: 16) {
            // Net calories display
            VStack(spacing: 8) {
                Text("Net Calories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(Int(log.netCalories))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("calories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Food")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(log.totalCalories)) cal")
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Exercise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(log.totalExerciseCalories)) cal")
                        .font(.headline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Goal information if set
            if let goal = log.dailyGoal {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(goal)) cal")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let remaining = log.remainingCalories {
                            Text("\(Int(remaining)) cal")
                                .font(.headline)
                                .foregroundColor(remaining >= 0 ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    /// List of food items for the selected date
    private func foodItemsList(log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Food Items")
                .font(.headline)
            
            if !log.foodItems.isEmpty {
                List {
                    ForEach(log.foodItems, id: \.id) { item in
                        HStack(spacing: 12) {
                            FoodItemRow(
                                item: item,
                                onDelete: {
                                    // Historical view is read-only, no delete action
                                },
                                onEdit: {
                                    // Historical view is read-only, no edit action
                                }
                            )
                            
                            // Show sync status indicator if authenticated
                            if userId != nil {
                                syncStatusIndicator(for: item)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 400)
            } else {
                emptyFoodListView
            }
        }
    }
    
    private func exerciseItemsList(log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise")
                .font(.headline)
            
            if log.exerciseItems.isEmpty {
                Text("No exercise logged")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(log.exerciseItems.sorted { $0.timestamp > $1.timestamp }, id: \.id) { item in
                        ExerciseItemRow(
                            item: item,
                            onDelete: { },
                            onEdit: { }
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
            }
        }
    }
    
    /// Sync status indicator for a food item
    ///
    /// Displays the sync status of a food item with appropriate icon and color.
    ///
    /// **Validates: Requirements 6.5 (Display Sync Status)**
    private func syncStatusIndicator(for item: FoodItem) -> some View {
        Group {
            switch item.syncStatus {
            case .synced:
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            case .pendingUpload:
                Image(systemName: "arrow.clockwise.icloud")
                    .foregroundColor(.orange)
                    .font(.caption)
            case .pendingDelete:
                Image(systemName: "trash.circle")
                    .foregroundColor(.red)
                    .font(.caption)
            case .conflict:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    /// Network offline warning banner
    ///
    /// Displays when the device is offline to inform users that sync is unavailable.
    ///
    /// **Validates: Requirements 7.5 (Offline Indicator)**
    private var networkOfflineWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Offline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Data will sync when connection is restored")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Sync status badge for toolbar
    ///
    /// Shows the current sync state in the navigation bar.
    ///
    /// **Validates: Requirements 6.4 (Sync Status Display)**
    private var syncStatusBadge: some View {
        HStack(spacing: 4) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !networkMonitor.isConnected {
                Image(systemName: "icloud.slash")
                    .foregroundColor(.orange)
                    .font(.caption)
            } else {
                Image(systemName: "checkmark.icloud")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
    
    /// Empty state when no data exists for the selected date
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No data for this date")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("No food items were logged on \(formattedSelectedDate)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    /// Empty state when no food items are logged for the date
    private var emptyFoodListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            
            Text("No food logged")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    // MARK: - Helper Methods
    
    /// Loads the daily log for the currently selected date
    private func loadLogForSelectedDate() async {
        isLoading = true
        do {
            currentLog = try await dataStore.fetchDailyLog(for: selectedDate)
        } catch {
            print("Failed to load log for \(selectedDate): \(error)")
            currentLog = nil
        }
        isLoading = false
    }
    
    /// Performs manual sync when user pulls to refresh
    ///
    /// Triggers the sync engine to process all queued operations and download
    /// any cloud changes. Displays toast notifications for success or failure.
    ///
    /// **Validates: Requirements 13.5 (Manual Retry), 6.5 (Manual Sync Trigger)**
    private func performManualSync() async {
        guard let syncEngine = syncEngine, let userId = userId else {
            // No sync engine configured - skip sync
            return
        }
        
        isSyncing = true
        
        do {
            // Trigger manual sync
            try await syncEngine.forceSyncNow()
            
            // Reload the current log to show updated data
            await loadLogForSelectedDate()
            
            // Show success toast
            await MainActor.run {
                toastMessage = "Sync completed successfully"
                toastStyle = .success
                showingToast = true
                isSyncing = false
            }
            
        } catch let error as SyncError {
            // Handle sync errors
            await MainActor.run {
                switch error {
                case .networkUnavailable:
                    toastMessage = "No internet connection"
                    toastStyle = .error
                    
                case .notAuthenticated:
                    toastMessage = "Please sign in to sync"
                    toastStyle = .error
                    
                case .queueProcessingFailed(let count):
                    toastMessage = "Failed to sync \(count) items"
                    toastStyle = .error
                    
                default:
                    toastMessage = "Sync failed: \(error.localizedDescription)"
                    toastStyle = .error
                }
                
                showingToast = true
                isSyncing = false
            }
            
        } catch {
            // Handle unexpected errors
            await MainActor.run {
                toastMessage = "Sync failed: \(error.localizedDescription)"
                toastStyle = .error
                showingToast = true
                isSyncing = false
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Formatted string for the selected date (e.g., "Monday, Jan 15, 2026")
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var dataStore: DataStore = {
        // Create an in-memory model container for preview
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, configurations: config)
        let context = ModelContext(container)
        let store = DataStore(modelContext: context)
        
        // Create sample data for yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let sampleLog = try! DailyLog(
            date: yesterday,
            foodItems: [
                try! FoodItem(name: "Breakfast Burrito", calories: 450, timestamp: yesterday.addingTimeInterval(3600)),
                try! FoodItem(name: "Salad", calories: 250, timestamp: yesterday.addingTimeInterval(21600)),
                try! FoodItem(name: "Chicken Dinner", calories: 600, timestamp: yesterday.addingTimeInterval(43200))
            ],
            dailyGoal: 2000
        )
        
        Task {
            try! await store.saveDailyLog(sampleLog)
        }
        
        return store
    }()
    
    return HistoricalView(dataStore: dataStore, initialDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()))
}
