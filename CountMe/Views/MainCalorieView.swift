//
//  MainCalorieView.swift
//  CountMe
//
//  Main view for displaying daily calorie tracking information
//

import SwiftUI
import SwiftData

/// Main calorie tracking view that displays daily totals, goals, and progress
///
/// This view shows:
/// - Daily calorie total prominently
/// - Daily goal and remaining calories
/// - Progress indicator (circular)
/// - Visual feedback when goal is exceeded
/// - Navigation to food search
/// - List of today's food items
/// - Macro breakdown (protein, carbs, fats) for daily totals
/// - Pull-to-refresh for manual sync
///
/// Requirements: 3.4, 4.2, 4.3, 4.4, 1.1, 5.1, 5.2, 13.5
struct MainCalorieView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// The custom meal manager for browsing custom meals
    @Bindable var customMealManager: CustomMealManager
    
    /// Optional sync engine for cloud synchronization
    var syncEngine: FirebaseSyncEngine?
    
    /// Optional authenticated user ID for sync operations
    var userId: String?
    
    /// Controls navigation to food search view
    @State private var showingFoodSearch = false
    
    // Profile values for auto-goal calculation
    @AppStorage("exerciseBodyWeightKg") private var bodyWeightKg: Double = 70
    @AppStorage("weightLossLbsPerWeek") private var weightLossLbsPerWeek: Double = 1.0
    @AppStorage("userHeightCm") private var heightCm: Double = 170
    @AppStorage("userAge") private var age: Int = 30
    @AppStorage("userSex") private var sex: String = "male"
    @AppStorage("userActivityLevel") private var activityLevel: String = "moderate"
    
    /// Controls navigation to custom meals library
    @State private var showingCustomMeals = false
    
    /// Controls navigation to custom meal method picker (AI or manual)
    @State private var showingMealMethodPicker = false
    
    /// The saved meal to show in detail view
    @State private var savedMealToShow: CustomMeal?
    
    /// Controls navigation to manual entry
    @State private var showingManualEntry = false

    /// Controls navigation to exercise entry
    @State private var showingExerciseEntry = false
    
    /// The exercise item currently being edited
    @State private var editingExerciseItem: ExerciseItem?
    
    /// Selected segment for food/exercise toggle
    @State private var selectedSegment: LogSegment = .food
    
    /// Controls the add menu visibility
    @State private var showingAddMenu = false
    
    /// The food item currently being edited
    @State private var editingItem: FoodItem?
    
    /// Controls whether multi-select mode is active
    @State private var isSelectionMode = false
    
    /// Tracks selected food items in selection mode
    @State private var selectedItems: Set<String> = []
    
    /// Controls navigation to meal builder review view
    @State private var showingMealBuilderReview = false
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    /// Tracks if sync is in progress
    @State private var isSyncing: Bool = false
    
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Daily total and progress section
                        dailyTotalSection
                        
                        // Macro breakdown section
                        if let log = tracker.currentLog {
                            MacroDisplayView(
                                protein: log.totalProtein,
                                carbohydrates: log.totalCarbohydrates,
                                fats: log.totalFats
                            )
                        }
                        
                        // Combined food + exercise list
                        combinedItemsList
                        
                        Spacer(minLength: 100) // Space for FAB
                    }
                    .padding()
                }
                .refreshable {
                    await performManualSync()
                }
                
                // Floating action button (hidden in selection mode)
                if !isSelectionMode {
                    floatingActionButton
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    dateNavigationButtons
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSegment == .food {
                        if isSelectionMode {
                            Button("Cancel") {
                                exitSelectionMode()
                            }
                        } else {
                            Button {
                                enterSelectionMode()
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)
                            }
                            .disabled(tracker.currentLog?.foodItems.isEmpty ?? true)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(tracker: tracker, customMealManager: customMealManager)
            }
            .sheet(isPresented: $showingCustomMeals) {
                CustomMealsLibraryView(
                    manager: customMealManager,
                    onDismissAll: {
                        // Dismiss the entire custom meals sheet
                        showingCustomMeals = false
                        // Reload the daily log so the new food item shows up
                        Task {
                            try? await tracker.loadLog(for: tracker.selectedDate)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingMealMethodPicker) {
                CustomMealMethodPickerView(
                    manager: customMealManager,
                    apiClient: tracker.nutritionAPIClient,
                    onDismiss: { savedMeal in
                        showingMealMethodPicker = false
                        // Show the saved meal detail after a brief delay
                        if let meal = savedMeal {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                savedMealToShow = meal
                            }
                        }
                    }
                )
            }
            .sheet(item: $savedMealToShow) { meal in
                NavigationStack {
                    CustomMealDetailView(
                        meal: meal,
                        manager: customMealManager,
                        onDismissAll: {
                            // Dismiss the sheet
                            savedMealToShow = nil
                            // Reload the daily log so the new food item shows up
                            Task {
                                try? await tracker.loadLog(for: tracker.selectedDate)
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(tracker: tracker)
            }
            .sheet(item: $editingItem) { item in
                ManualEntryView(tracker: tracker, editingItem: item)
            }
            .sheet(isPresented: $showingExerciseEntry) {
                ExerciseEntryView(tracker: tracker)
            }
            .sheet(item: $editingExerciseItem) { item in
                ExerciseEntryView(tracker: tracker, editingItem: item)
            }
            .sheet(isPresented: $showingMealBuilderReview) {
                if let log = tracker.currentLog {
                    let selectedFoodItems = log.foodItems.filter { selectedItems.contains($0.id) }
                    MealBuilderReviewView(
                        sourceItems: .foodItems(selectedFoodItems),
                        manager: customMealManager,
                        onComplete: {
                            // Exit selection mode and show success toast
                            exitSelectionMode()
                            toastMessage = "Custom meal created successfully"
                            toastStyle = .success
                            showingToast = true
                        }
                    )
                }
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
            .onAppear {
                applyAutoGoalIfNeeded()
            }
            .onChange(of: tracker.currentLog?.id) {
                applyAutoGoalIfNeeded()
            }
            .onChange(of: suggestedGoal) {
                applyAutoGoalIfNeeded()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Floating action button with add menu
    private var floatingActionButton: some View {
        VStack(spacing: 16) {
            if showingAddMenu {
                VStack(spacing: 12) {
                    // Search food option
                    FloatingMenuButton(
                        icon: "magnifyingglass",
                        title: "Search Food",
                        color: .blue
                    ) {
                        showingAddMenu = false
                        showingFoodSearch = true
                    }
                    
                    // Custom Meal option
                    FloatingMenuButton(
                        icon: "fork.knife.circle",
                        title: "Custom Meal",
                        color: .orange
                    ) {
                        showingAddMenu = false
                        showingMealMethodPicker = true
                    }
                    
                    // Manual entry option
                    FloatingMenuButton(
                        icon: "pencil.circle",
                        title: "Quick Add",
                        color: .green
                    ) {
                        showingAddMenu = false
                        showingManualEntry = true
                    }
                    
                    // Exercise entry option
                    FloatingMenuButton(
                        icon: "figure.walk",
                        title: "Exercise",
                        color: .teal
                    ) {
                        showingAddMenu = false
                        showingExerciseEntry = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Main FAB button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingAddMenu.toggle()
                }
            } label: {
                Image(systemName: showingAddMenu ? "xmark" : "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .rotationEffect(.degrees(showingAddMenu ? 45 : 0))
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    /// Daily total and progress indicator section
    private var dailyTotalSection: some View {
        VStack(spacing: 16) {
            // Progress circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                    .frame(width: 160, height: 160)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progressPercentage)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progressPercentage)
                
                // Calorie count in center
                VStack(spacing: 4) {
                    Text("\(Int(mainDisplayValue))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(progressColor)
                    
                    Text(mainDisplayLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let log = tracker.currentLog {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Food")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(log.totalCalories)) cal")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exercise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(log.totalExerciseCalories)) cal")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(log.netCalories)) cal")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
            }
            
            // Goal and remaining calories
            if let goal = tracker.currentLog?.dailyGoal {
                VStack(spacing: 8) {
                    HStack {
                        Text("Goal:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(goal)) cal")
                            .fontWeight(.semibold)
                    }
                    
                    if let remaining = remainingCaloriesForDisplay {
                        HStack {
                            Text("Remaining:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(remaining)) cal")
                                .fontWeight(.semibold)
                                .foregroundColor(remaining >= 0 ? .green : .red)
                        }
                    }
                    
                    if let remaining = remainingCaloriesForDisplay {
                        HStack {
                            Text("To Stay On Goal:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(max(remaining, 0))) cal")
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    /// Combined list of food and exercise items for today with segment picker
    private var combinedItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Log")
                    .font(.headline)
                
                Spacer()
                
                // Show selection count and Create Meal button when items are selected
                if isSelectionMode && !selectedItems.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(selectedItems.count) selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showingMealBuilderReview = true
                        } label: {
                            Text("Create Meal")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Picker("Log Type", selection: $selectedSegment) {
                ForEach(LogSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            
            switch selectedSegment {
            case .food:
                foodItemsList
            case .exercise:
                exerciseItemsList
            }
        }
    }
    
    /// Food items list section
    private var foodItemsList: some View {
        Group {
            // Use the cached array from tracker instead of accessing the relationship directly
            // This ensures SwiftUI properly observes changes
            if !tracker.foodItemsCache.isEmpty {
                let _ = print("🍽️ Displaying \(tracker.foodItemsCache.count) food items in list")
                List {
                    ForEach(tracker.foodItemsCache, id: \.id) { item in
                        HStack(spacing: 12) {
                            if isSelectionMode {
                                Button {
                                    toggleSelection(for: item)
                                } label: {
                                    Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(selectedItems.contains(item.id) ? .blue : .gray)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            FoodItemRow(
                                item: item,
                                onDelete: {
                                    Task {
                                        try? await tracker.removeFoodItem(item)
                                    }
                                },
                                onEdit: {
                                    editingItem = item
                                },
                                isSelectionMode: isSelectionMode
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isSelectionMode {
                                Button(role: .destructive) {
                                    Task {
                                        try? await tracker.removeFoodItem(item)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .contextMenu {
                            if !isSelectionMode {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    Task {
                                        try? await tracker.removeFoodItem(item)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 260, maxHeight: 520)
            } else {
                emptyFoodState
            }
        }
    }
    
    /// Exercise items list section
    private var exerciseItemsList: some View {
        Group {
            // Exercise summary
            if !tracker.exerciseItemsCache.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Burned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(tracker.currentLog?.totalExerciseCalories ?? 0)) kcal")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        let totalMinutes = tracker.exerciseItemsCache.reduce(0.0) { $0 + ($1.durationMinutes ?? 0) }
                        if totalMinutes > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(totalMinutes)) min")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                List {
                    ForEach(tracker.exerciseItemsCache.sorted { $0.timestamp > $1.timestamp }, id: \.id) { item in
                        ExerciseItemRow(
                            item: item,
                            onDelete: {
                                Task {
                                    try? await tracker.removeExerciseItem(item)
                                }
                            },
                            onEdit: {
                                editingExerciseItem = item
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    try? await tracker.removeExerciseItem(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                editingExerciseItem = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    try? await tracker.removeExerciseItem(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200, maxHeight: 520)
            } else {
                emptyExerciseState
            }
        }
    }
    
    /// Empty state when no food items are logged
    private var emptyFoodState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No food logged yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the + button to add your first meal")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    /// Empty state when no exercise items are logged
    private var emptyExerciseState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No exercise logged yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    /// Date navigation buttons for previous/next day
    private var dateNavigationButtons: some View {
        HStack(spacing: 8) {
            Button {
                changeDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body)
            }
            
            DatePicker(
                "",
                selection: Binding(
                    get: { tracker.selectedDate },
                    set: { newDate in
                        Task {
                            try? await tracker.loadLog(for: newDate)
                        }
                    }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .fixedSize()
            
            Button {
                changeDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body)
            }
            .disabled(Calendar.current.isDateInToday(tracker.selectedDate))
        }
    }
    
    /// Error state view with retry button
    ///
    /// Displays when sync errors occur, providing a manual retry option
    /// for users to attempt sync again.
    ///
    /// **Validates: Requirements 13.5 (Manual Retry UI)**
    private func errorStateView(message: String, onRetry: @escaping () async -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Sync Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await onRetry()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Sync")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Computed Properties
    
    /// Navigation title showing the current date
    private var navigationTitle: String {
        if Calendar.current.isDateInToday(tracker.selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(tracker.selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: tracker.selectedDate)
        }
    }
    
    /// Suggested daily calorie goal based on profile settings
    private var suggestedGoal: Double {
        CalorieEstimator.suggestedCalories(
            weightKg: bodyWeightKg,
            heightCm: heightCm,
            age: age,
            sex: CalorieEstimator.Sex(rawValue: sex) ?? .male,
            activity: CalorieEstimator.ActivityLevel(rawValue: activityLevel) ?? .moderate,
            lossPerWeekLbs: weightLossLbsPerWeek
        )
    }
    
    /// Automatically sets the daily goal from profile settings
    private func applyAutoGoalIfNeeded() {
        guard tracker.currentLog != nil else { return }
        let goal = suggestedGoal
        guard goal > 0 else { return }
        // Skip if already matching to avoid unnecessary saves
        if tracker.currentLog?.dailyGoal == goal { return }
        Task {
            try? await tracker.setDailyGoal(goal)
        }
    }
    
    /// Current daily total calories
    private var currentTotal: Double {
        tracker.getNetCalories()
    }
    
    private var mainDisplayValue: Double {
        if let remaining = remainingCaloriesForDisplay {
            return max(remaining, 0)
        }
        return currentTotal
    }
    
    private var mainDisplayLabel: String {
        remainingCaloriesForDisplay == nil ? "net calories" : "remaining"
    }
    
    private var remainingCaloriesForDisplay: Double? {
        tracker.currentLog?.remainingCalories
    }
    
    /// Progress percentage for the circular indicator (0.0 to 1.0)
    private var progressPercentage: CGFloat {
        guard let goal = tracker.currentLog?.dailyGoal, goal > 0 else {
            return 0
        }
        let remaining = remainingCaloriesForDisplay ?? goal
        let raw = 1.0 - (remaining / goal)
        return min(max(CGFloat(raw), 0.0), 1.0)
    }
    
    /// Color for progress indicator based on goal status
    private var progressColor: Color {
        guard let goal = tracker.currentLog?.dailyGoal else {
            return .blue
        }
        
        if currentTotal > goal {
            return .red // Goal exceeded
        } else if currentTotal >= goal * 0.9 {
            return .orange // Close to goal
        } else {
            return .green // On track
        }
    }
    
    // MARK: - Selection Mode Methods
    
    /// Changes the selected date by the specified number of days
    private func changeDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: tracker.selectedDate) else {
            return
        }
        
        // Don't allow navigating to future dates
        if newDate > Date() {
            return
        }
        
        Task {
            try? await tracker.loadLog(for: newDate)
        }
    }
    
    /// Enter multi-select mode for creating meals from food items
    private func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
    }
    
    /// Exit multi-select mode and clear selections
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
    }
    
    /// Toggle selection state for a food item
    private func toggleSelection(for item: FoodItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    // MARK: - Sync Methods
    
    /// Performs manual sync when user pulls to refresh
    ///
    /// Triggers the sync engine to process all queued operations and download
    /// any cloud changes. Displays toast notifications for success or failure.
    ///
    /// **Validates: Requirements 13.5 (Manual Retry)**
    private func performManualSync() async {
        guard let syncEngine = syncEngine, let userId = userId else {
            // No sync engine configured - just reload local data
            do {
                try await tracker.loadLog(for: tracker.selectedDate)
            } catch {
                print("⚠️ Failed to reload local log: \(error)")
            }
            return
        }
        
        isSyncing = true
        
        do {
            // Push pending local changes
            try await syncEngine.forceSyncNow()
            
            // Pull remote data from Firebase into local store
            try await syncEngine.downloadFromFirestore(userId: userId)
            
            // Reload the tracker's daily log so the UI reflects the latest data
            try await tracker.loadLog(for: tracker.selectedDate)
            
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
}

// MARK: - Floating Menu Button Component

/// Segment options for the food/exercise toggle on the main calorie view
enum LogSegment: String, CaseIterable {
    case food = "Food"
    case exercise = "Exercise"
}

/// Individual button in the floating action menu
struct FloatingMenuButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
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
    
    MainCalorieView(tracker: tracker, customMealManager: customMealManager)
}
