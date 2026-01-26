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
/// - Display of selected food item
/// - Serving size multiplier adjustment
/// - Real-time calorie calculation based on serving amount
/// - Save and cancel actions
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
    
    /// Saving state
    @State private var isSaving: Bool = false
    
    /// Error message
    @State private var errorMessage: String?
    
    /// Focus state for text field
    @FocusState private var isServingFieldFocused: Bool
    
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
                    
                    if let servingSize = searchResult.servingSize,
                       let servingUnit = searchResult.servingUnit {
                        HStack {
                            Text("Total Amount")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f %@", adjustedServingSize, servingUnit))
                                .foregroundColor(.secondary)
                        }
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
    
    /// Adjusted calories based on serving multiplier
    private var adjustedCalories: Double {
        searchResult.calories * servingMultiplier
    }
    
    /// Adjusted serving size based on multiplier
    private var adjustedServingSize: Double {
        if let servingSize = searchResult.servingSize,
           let size = Double(servingSize) {
            return size * servingMultiplier
        }
        return servingMultiplier
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
                // Calculate adjusted serving size string
                let adjustedServingSizeString: String?
                if let servingSize = searchResult.servingSize,
                   let size = Double(servingSize) {
                    adjustedServingSizeString = String(format: "%.1f", size * servingMultiplier)
                } else {
                    adjustedServingSizeString = String(format: "%.1f", servingMultiplier)
                }
                
                // Calculate adjusted macro values (apply serving multiplier)
                let adjustedProtein = searchResult.protein.map { $0 * servingMultiplier }
                let adjustedCarbs = searchResult.carbohydrates.map { $0 * servingMultiplier }
                let adjustedFats = searchResult.fats.map { $0 * servingMultiplier }
                
                // Create FoodItem with adjusted values
                let foodItem = FoodItem(
                    name: searchResult.name,
                    calories: adjustedCalories,
                    timestamp: Date(),
                    servingSize: adjustedServingSizeString,
                    servingUnit: searchResult.servingUnit,
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
            apiClient: NutritionAPIClient(
                consumerKey: "preview",
                consumerSecret: "preview"
            )
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
            fats: 3.6
        ),
        tracker: tracker
    )
}
