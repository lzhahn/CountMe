//
//  ServingAdjustmentView.swift
//  CountMe
//
//  View for adjusting serving size before adding a food item
//

import SwiftUI
import SwiftData

/// Serving adjustment view that allows users to modify serving amount before adding to log
///
/// This view provides:
/// - Display of selected food item with brand and original serving info
/// - Serving type selection (when multiple options available from USDA API)
/// - Serving size multiplier adjustment via text field and stepper
/// - Real-time calorie and macro calculation based on serving type and amount
/// - Save and cancel actions
///
/// # Serving Type Selection
/// The view always displays the serving type section:
/// - **Single option**: Shows read-only display of the serving type
/// - **Multiple options**: Shows interactive picker using navigation link style for better discoverability
///
/// Each serving option displays its gram weight to help users understand conversions.
///
/// # Calculation Logic
/// Calories and macros are calculated as:
/// ```
/// adjustedCalories = (calories / originalServingGrams) * selectedServingGrams * multiplier
/// adjustedMacros = (originalMacros / originalServingGrams) * selectedServingGrams * multiplier
/// ```
///
/// # Example
/// For chicken breast (165 cal per 100g):
/// - Select "1 breast (174g)" serving type
/// - Set multiplier to 2.0
/// - Result: 574 calories (165 * 1.74 * 2.0)
struct ServingAdjustmentView: View {
    /// The nutrition search result to adjust
    let searchResult: NutritionSearchResult
    
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Serving multiplier (1.0 = original serving size)
    @State private var servingMultiplier: Double = 1.0
    
    /// Text input for serving multiplier
    @State private var servingText: String = "1"
    
    /// Selected serving option
    @State private var selectedServingOption: ServingOption
    
    /// Saving state
    @State private var isSaving: Bool = false
    
    /// Error message
    @State private var errorMessage: String?
    
    /// Focus state for text field
    @FocusState private var isServingFieldFocused: Bool
    
    init(searchResult: NutritionSearchResult, tracker: CalorieTracker) {
        self.searchResult = searchResult
        self.tracker = tracker
        // Initialize with first serving option or create a default
        if let firstOption = searchResult.servingOptions.first {
            _selectedServingOption = State(initialValue: firstOption)
        } else {
            _selectedServingOption = State(initialValue: ServingOption(description: "100g", gramWeight: 100))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Food item details section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(searchResult.name)
                            .font(.headline)
                        
                        if let brandName = searchResult.brandName {
                            Text(brandName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let servingSize = searchResult.servingSize,
                           let servingUnit = searchResult.servingUnit {
                            Text("Original: \(servingSize) \(servingUnit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Food Item")
                }
                
                // Serving type selection
                // Always show this section so users can see what serving type they're using
                Section {
                    if searchResult.servingOptions.count > 1 {
                        // Use navigationLink style for better discoverability
                        // Shows a dedicated screen with all options and their gram weights
                        Picker("Serving Type", selection: $selectedServingOption) {
                            ForEach(searchResult.servingOptions) { option in
                                HStack {
                                    Text(option.description)
                                    Spacer()
                                    Text("(\(Int(option.gramWeight))g)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .tag(option)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } else {
                        // Single option: show read-only display
                        HStack {
                            Text("Serving Type")
                            Spacer()
                            Text(selectedServingOption.description)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Serving Type")
                } footer: {
                    if searchResult.servingOptions.count > 1 {
                        Text("Select the type of serving you want to track. Each option shows its gram weight.")
                    } else {
                        Text("This food has one serving type available.")
                    }
                }
                
                // Serving adjustment section
                Section {
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("Amount", text: $servingText)
                            .focused($isServingFieldFocused)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: servingText) { _, newValue in
                                if let value = Double(newValue), value > 0 {
                                    servingMultiplier = value
                                }
                            }
                    }
                    
                    // Stepper for easier adjustment
                    Stepper(
                        value: $servingMultiplier,
                        in: 0.25...20,
                        step: 0.25
                    ) {
                        Text("Adjust: \(String(format: "%.2f", servingMultiplier))x")
                    }
                    .onChange(of: servingMultiplier) { _, newValue in
                        servingText = String(format: "%.2f", newValue)
                    }
                } header: {
                    Text("Serving Amount")
                } footer: {
                    Text("Adjust the number of servings. 1.0 = one standard serving.")
                }
                
                // Calculated calories section
                Section {
                    HStack {
                        Text("Total Calories")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(Int(adjustedCalories))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Total Amount")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1fg", adjustedServingSize))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Serving Type")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedServingOption.description)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Adjusted Values")
                }
                
                // Error display
                if let error = errorMessage {
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
            .navigationTitle("Adjust Serving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addFoodItem()
                    }
                    .disabled(isSaving || servingMultiplier <= 0)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isServingFieldFocused = false
                        }
                    }
                }
            }
            .disabled(isSaving)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Calories per gram based on the original serving
    private var caloriesPerGram: Double {
        guard let servingSize = searchResult.servingSize,
              let size = Double(servingSize),
              size > 0 else {
            return searchResult.calories / 100.0 // Default to per 100g
        }
        return searchResult.calories / size
    }
    
    /// Adjusted calories based on serving type and multiplier
    private var adjustedCalories: Double {
        caloriesPerGram * selectedServingOption.gramWeight * servingMultiplier
    }
    
    /// Adjusted serving size based on multiplier
    private var adjustedServingSize: Double {
        selectedServingOption.gramWeight * servingMultiplier
    }
    
    // MARK: - Actions
    
    /// Creates and adds the food item with adjusted serving
    private func addFoodItem() {
        guard servingMultiplier > 0 else {
            errorMessage = "Serving amount must be greater than 0"
            return
        }
        
        errorMessage = nil
        isSaving = true
        
        Task {
            do {
                // Calculate serving size string based on selected option
                let adjustedServingSizeString = String(format: "%.1f", selectedServingOption.gramWeight * servingMultiplier)
                
                // Calculate ratio for macro adjustments
                let gramRatio = (selectedServingOption.gramWeight * servingMultiplier) / (Double(searchResult.servingSize ?? "100") ?? 100)
                
                // Calculate adjusted macro values
                let adjustedProtein = searchResult.protein.map { $0 * gramRatio }
                let adjustedCarbs = searchResult.carbohydrates.map { $0 * gramRatio }
                let adjustedFats = searchResult.fats.map { $0 * gramRatio }
                
                // Create FoodItem with adjusted values
                let foodItem = try FoodItem(
                    name: searchResult.name,
                    calories: adjustedCalories,
                    timestamp: Date(),
                    servingSize: adjustedServingSizeString,
                    servingUnit: "g",
                    source: .api,
                    protein: adjustedProtein,
                    carbohydrates: adjustedCarbs,
                    fats: adjustedFats
                )
                
                // Add to current daily log
                try await tracker.addFoodItem(foodItem)
                
                // Navigate back on success
                await MainActor.run {
                    dismiss()
                }
            } catch let error as ValidationError {
                // Display validation error message
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            } catch {
                // Display error message
                await MainActor.run {
                    isSaving = false
                    if let trackerError = error as? CalorieTrackerError {
                        errorMessage = trackerError.errorDescription
                    } else {
                        errorMessage = "Failed to add food item. Please try again."
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var tracker: CalorieTracker = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, configurations: config)
        let context = ModelContext(container)
        
        return CalorieTracker(
            dataStore: DataStore(modelContext: context),
            apiClient: NutritionAPIClient()
        )
    }()
    
    return ServingAdjustmentView(
        searchResult: NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: "Generic",
            protein: 31.0,
            carbohydrates: 0.0,
            fats: 3.6,
            servingOptions: [
                ServingOption(description: "100g", gramWeight: 100),
                ServingOption(description: "1 breast (174g)", gramWeight: 174),
                ServingOption(description: "1 oz (28g)", gramWeight: 28)
            ]
        ),
        tracker: tracker
    )
}
