//
//  ManualEntryView.swift
//  CountMe
//
//  View for manually entering food items with calorie information
//

import SwiftUI
import SwiftData

/// Manual food entry view that allows users to add or edit food items without API search
///
/// This view provides:
/// - Text field for food name
/// - Number field for calories
/// - Optional fields for serving size/unit
/// - Optional fields for macronutrients (protein, carbohydrates, fats)
/// - Input validation before saving (non-negative values)
/// - Inline validation errors for invalid macro values
/// - Save and cancel actions
/// - Edit mode for existing food items
///
/// Requirements: 2.3, 6.3, 8.3
struct ManualEntryView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Optional food item to edit (nil for new entry)
    var editingItem: FoodItem?
    
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
    
    /// Optional protein input (grams)
    @State private var proteinText: String = ""
    
    /// Optional carbohydrates input (grams)
    @State private var carbohydratesText: String = ""
    
    /// Optional fats input (grams)
    @State private var fatsText: String = ""
    
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
        case protein
        case carbohydrates
        case fats
    }
    
    // MARK: - Initialization
    
    init(tracker: CalorieTracker, editingItem: FoodItem? = nil) {
        self.tracker = tracker
        self.editingItem = editingItem
        
        // Pre-populate fields if editing
        if let item = editingItem {
            _foodName = State(initialValue: item.name)
            _caloriesText = State(initialValue: String(format: "%.0f", item.calories))
            _servingSize = State(initialValue: item.servingSize ?? "")
            _servingUnit = State(initialValue: item.servingUnit ?? "")
            _proteinText = State(initialValue: item.protein.map { String(format: "%.1f", $0) } ?? "")
            _carbohydratesText = State(initialValue: item.carbohydrates.map { String(format: "%.1f", $0) } ?? "")
            _fatsText = State(initialValue: item.fats.map { String(format: "%.1f", $0) } ?? "")
        }
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
                
                // Nutritional Details (Optional) section
                Section {
                    HStack {
                        TextField("Protein", text: $proteinText)
                            .focused($focusedField, equals: .protein)
                            .keyboardType(.decimalPad)
                        
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Carbohydrates", text: $carbohydratesText)
                            .focused($focusedField, equals: .carbohydrates)
                            .keyboardType(.decimalPad)
                        
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Fats", text: $fatsText)
                            .focused($focusedField, equals: .fats)
                            .keyboardType(.decimalPad)
                        
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Nutritional Details (Optional)")
                } footer: {
                    Text("Add macronutrient information if available")
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
            .navigationTitle(editingItem == nil ? "Add Food Manually" : "Edit Food")
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
        
        // Validate optional protein if provided
        let trimmedProtein = proteinText.trimmingCharacters(in: .whitespacesAndNewlines)
        var proteinValue: Double? = nil
        if !trimmedProtein.isEmpty {
            guard let protein = Double(trimmedProtein) else {
                validationError = "Protein must be a valid number"
                return
            }
            guard protein >= 0 else {
                validationError = "Protein must be a non-negative number"
                return
            }
            proteinValue = protein
        }
        
        // Validate optional carbohydrates if provided
        let trimmedCarbs = carbohydratesText.trimmingCharacters(in: .whitespacesAndNewlines)
        var carbsValue: Double? = nil
        if !trimmedCarbs.isEmpty {
            guard let carbs = Double(trimmedCarbs) else {
                validationError = "Carbohydrates must be a valid number"
                return
            }
            guard carbs >= 0 else {
                validationError = "Carbohydrates must be a non-negative number"
                return
            }
            carbsValue = carbs
        }
        
        // Validate optional fats if provided
        let trimmedFats = fatsText.trimmingCharacters(in: .whitespacesAndNewlines)
        var fatsValue: Double? = nil
        if !trimmedFats.isEmpty {
            guard let fats = Double(trimmedFats) else {
                validationError = "Fats must be a valid number"
                return
            }
            guard fats >= 0 else {
                validationError = "Fats must be a non-negative number"
                return
            }
            fatsValue = fats
        }
        
        // Create or update the food item
        isSaving = true
        
        Task {
            do {
                if let existingItem = editingItem {
                    // Update existing item
                    existingItem.name = trimmedName
                    existingItem.calories = calories
                    existingItem.servingSize = servingSizeValue
                    existingItem.servingUnit = servingUnitValue
                    existingItem.protein = proteinValue
                    existingItem.carbohydrates = carbsValue
                    existingItem.fats = fatsValue
                    existingItem.lastModified = Date()
                    existingItem.syncStatus = .pendingUpload
                    
                    try await tracker.updateFoodItem(existingItem)
                } else {
                    // Create new item
                    let foodItem = FoodItem(
                        name: trimmedName,
                        calories: calories,
                        timestamp: Date(),
                        servingSize: servingSizeValue,
                        servingUnit: servingUnitValue,
                        source: .manual,
                        protein: proteinValue,
                        carbohydrates: carbsValue,
                        fats: fatsValue
                    )
                    
                    try await tracker.addFoodItem(foodItem)
                }
                
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
