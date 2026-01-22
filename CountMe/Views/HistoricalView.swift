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
/// - Food items list for that date
/// - Previous/next day navigation buttons
///
/// Requirements: 6.1, 6.2, 6.3
struct HistoricalView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// The currently selected date for viewing historical data
    /// Initialized from tracker's selectedDate
    @State private var selectedDate: Date
    
    /// Loading state for UI feedback
    @State private var isLoading = false
    
    /// Initializes the historical view with a calorie tracker
    /// - Parameter tracker: The calorie tracker instance
    init(tracker: CalorieTracker) {
        self.tracker = tracker
        // Initialize selectedDate from tracker's current selectedDate
        _selectedDate = State(initialValue: tracker.selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Date navigation section
                dateNavigationSection
                
                // Daily summary section
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let log = tracker.currentLog {
                    dailySummarySection(log: log)
                    
                    // Food items list
                    foodItemsList(log: log)
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("History")
            .task {
                await loadLogForSelectedDate()
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
            // Total calories display
            VStack(spacing: 8) {
                Text("Total Calories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(Int(log.totalCalories))")
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
                        FoodItemRow(
                            item: item,
                            onDelete: {
                                // Historical view is read-only, no delete action
                            },
                            onEdit: {
                                // Historical view is read-only, no edit action
                            }
                        )
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
            try await tracker.loadLog(for: selectedDate)
        } catch {
            print("Failed to load log for \(selectedDate): \(error)")
        }
        isLoading = false
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
    @Previewable @State var tracker: CalorieTracker = {
        // Create an in-memory model container for preview
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, configurations: config)
        let context = ModelContext(container)
        
        // Create sample data
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let sampleLog = DailyLog(
            date: yesterday,
            foodItems: [
                FoodItem(name: "Breakfast Burrito", calories: 450, timestamp: yesterday.addingTimeInterval(3600)),
                FoodItem(name: "Salad", calories: 250, timestamp: yesterday.addingTimeInterval(21600)),
                FoodItem(name: "Chicken Dinner", calories: 600, timestamp: yesterday.addingTimeInterval(43200))
            ],
            dailyGoal: 2000
        )
        
        context.insert(sampleLog)
        
        return CalorieTracker(
            dataStore: DataStore(modelContext: context),
            apiClient: NutritionAPIClient(
                consumerKey: "preview",
                consumerSecret: "preview"
            ),
            selectedDate: yesterday
        )
    }()
    
    return HistoricalView(tracker: tracker)
}
