//
//  ManualEntryView.swift
//  CountMe
//
//  View for manually entering food items with calorie information
//

import SwiftUI
import SwiftData

/// Manual food entry view that allows users to add food items without API search
///
/// This view provides:
/// - Text field for food name
/// - Number field for calories
/// - Optional fields for serving size/unit
/// - Input validation before saving
/// - Save and cancel actions
///
/// Requirements: 2.3, 8.3
struct ManualEntryView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Food name input
    @State private var foodName: String = ""
    
    /// Calorie value input
    @State private var caloriesText: String = ""
    
    /// Optional serving size input
    @State private var servingSize: String = ""
    
    /// Optional serving unit input
    @State private var servingUnit: String = ""
    
    /// Validation error message
    @State private var validationError: String?
    
    /// Saving state
    @State private var isSaving: Bool = false
    
    /// Focus state for text fields
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name
        case calories
        case servingSize
        case servingUnit
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Required fields section
                Section {
                    TextField("Food Name", text: $foodName)
                        .focused($focusedField, equals: .name)
                        .autocorrectionDisabled()
                    
                    HStack {
                        TextField("Calories", text: $caloriesText)
                            .focused($focusedField, equals: .calories)
                            .keyboardType(.decimalPad)
                        
                        Text("kcal")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Required Information")
                } footer: {
                    Text("Enter the food name and calorie amount")
                }
                
                // Optional fields section
                Section {
                    TextField("Serving Size (e.g., 100)", text: $servingSize)
                        .focused($focusedField, equals: .servingSize)
                        .keyboardType(.decimalPad)
                    
                    TextField("Serving Unit (e.g., g, oz, cup)", text: $servingUnit)
                        .focused($focusedField, equals: .servingUnit)
                        .autocorrectionDisabled()
                } header: {
                    Text("Optional Information")
                } footer: {
                    Text("Add serving size details if known")
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
            .navigationTitle("Add Food Manually")
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
                        saveFood()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .disabled(isSaving)
        }
    }
    
    // MARK: - Actions
    
    /// Validates inputs and saves the food item
    private func saveFood() {
        // Clear previous validation errors
        validationError = nil
        
        // Validate food name
        let trimmedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = "Food name is required"
            return
        }
        
        // Validate calories
        let trimmedCalories = caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCalories.isEmpty else {
            validationError = "Calories value is required"
            return
        }
        
        guard let calories = Double(trimmedCalories) else {
            validationError = "Calories must be a valid number"
            return
        }
        
        guard calories >= 0 else {
            validationError = "Calories must be a non-negative number"
            return
        }
        
        // Validate optional serving size if provided
        let trimmedServingSize = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingSizeValue: String? = trimmedServingSize.isEmpty ? nil : trimmedServingSize
        
        // Validate optional serving unit if provided
        let trimmedServingUnit = servingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingUnitValue: String? = trimmedServingUnit.isEmpty ? nil : trimmedServingUnit
        
        // Create and save the food item
        isSaving = true
        
        Task {
            do {
                let foodItem = FoodItem(
                    name: trimmedName,
                    calories: calories,
                    timestamp: Date(),
                    servingSize: servingSizeValue,
                    servingUnit: servingUnitValue,
                    source: .manual
                )
                
                try await tracker.addFoodItem(foodItem)
                
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
                        validationError = "Failed to save food item. Please try again."
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
    
    ManualEntryView(tracker: tracker)
}
