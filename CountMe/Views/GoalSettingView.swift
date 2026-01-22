//
//  GoalSettingView.swift
//  CountMe
//
//  View for setting daily calorie goals
//

import SwiftUI
import SwiftData

/// Goal setting view that allows users to set their daily calorie target
///
/// This view provides:
/// - Number field for daily calorie goal
/// - Display of current goal if set
/// - Input validation (positive number)
/// - Save and cancel actions
///
/// Requirements: 4.1
struct GoalSettingView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Goal value input
    @State private var goalText: String = ""
    
    /// Validation error message
    @State private var validationError: String?
    
    /// Saving state
    @State private var isSaving: Bool = false
    
    /// Focus state for text field
    @FocusState private var isGoalFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                // Current goal display section
                if let currentGoal = tracker.currentLog?.dailyGoal {
                    Section {
                        HStack {
                            Text("Current Goal")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(currentGoal)) kcal")
                                .fontWeight(.semibold)
                        }
                    } header: {
                        Text("Current Setting")
                    }
                }
                
                // Goal input section
                Section {
                    HStack {
                        TextField("Daily Calorie Goal", text: $goalText)
                            .focused($isGoalFieldFocused)
                            .keyboardType(.numberPad)
                        
                        Text("kcal")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Set New Goal")
                } footer: {
                    Text("Enter your target daily calorie intake. This should be a positive number.")
                }
                
                // Validation error display
                if let error = validationError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isGoalFieldFocused = false
                        }
                    }
                }
            }
            .disabled(isSaving)
            .onAppear {
                // Pre-populate with current goal if set
                if let currentGoal = tracker.currentLog?.dailyGoal {
                    goalText = String(Int(currentGoal))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    /// Validates input and saves the daily goal
    private func saveGoal() {
        // Clear previous validation errors
        validationError = nil
        
        // Validate goal value
        let trimmedGoal = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else {
            validationError = "Goal value is required"
            return
        }
        
        guard let goal = Double(trimmedGoal) else {
            validationError = "Goal must be a valid number"
            return
        }
        
        guard goal > 0 else {
            validationError = "Goal must be a positive number"
            return
        }
        
        // Save the goal
        isSaving = true
        
        Task {
            do {
                try await tracker.setDailyGoal(goal)
                
                // Navigate back on success
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Display error message
                await MainActor.run {
                    isSaving = false
                    if let trackerError = error as? CalorieTrackerError {
                        validationError = trackerError.errorDescription
                    } else {
                        validationError = "Failed to save goal. Please try again."
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
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
    
    GoalSettingView(tracker: tracker)
}
