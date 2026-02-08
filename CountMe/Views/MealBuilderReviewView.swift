//
//  MealBuilderReviewView.swift
//  CountMe
//
//  View for reviewing and editing selected items before saving as a custom meal
//

import SwiftUI
import SwiftData

/// View for reviewing selected search results or food items before saving as a custom meal
///
/// This view provides:
/// - Display of converted ingredients with nutritional data
/// - Editing capabilities for quantities, serving sizes, and names
/// - Total nutritional summary
/// - Meal name input
/// - Validation and save functionality
///
/// Requirements: 13.7, 13.8, 13.9, 14.5, 14.6, 14.7
struct MealBuilderReviewView: View {
    /// Source items to convert to ingredients (either search results or food items)
    enum SourceItems {
        case searchResults([NutritionSearchResult])
        case foodItems([FoodItem])
    }
    
    /// Selected items to convert to ingredients
    let sourceItems: SourceItems
    
    /// The custom meal manager for saving
    @Bindable var manager: CustomMealManager
    
    /// Callback when meal is successfully saved
    let onComplete: () -> Void
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Converted ingredients (editable)
    @State private var ingredients: [Ingredient] = []
    
    /// Meal name input
    @State private var mealName: String = ""
    
    /// Validation error message
    @State private var validationError: String?
    
    /// Saving state
    @State private var isSaving: Bool = false
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Meal name input section
                mealNameSection
                
                Divider()
                
                // Total nutritional summary
                nutritionalSummarySection
                
                Divider()
                
                // Ingredients list
                ingredientsList
            }
            .navigationTitle("Review Custom Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveMeal()
                    }
                    .disabled(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ingredients.isEmpty || isSaving)
                }
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
            .onAppear {
                convertSourceItemsToIngredients()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Meal name input section
    private var mealNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal Name")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("Enter meal name", text: $mealName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    /// Nutritional summary section
    private var nutritionalSummarySection: some View {
        VStack(spacing: 12) {
            Text("Total Nutritional Breakdown")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                nutritionalBadge(
                    label: "Calories",
                    value: totalCalories,
                    unit: "cal",
                    color: .blue
                )
                
                if totalProtein > 0 {
                    nutritionalBadge(
                        label: "Protein",
                        value: totalProtein,
                        unit: "g",
                        color: .blue
                    )
                }
                
                if totalCarbs > 0 {
                    nutritionalBadge(
                        label: "Carbs",
                        value: totalCarbs,
                        unit: "g",
                        color: .green
                    )
                }
                
                if totalFats > 0 {
                    nutritionalBadge(
                        label: "Fats",
                        value: totalFats,
                        unit: "g",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    /// Nutritional badge component
    private func nutritionalBadge(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text("\(Int(value))")
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Ingredients list with editing capabilities
    private var ingredientsList: some View {
        List {
            Section {
                ForEach(ingredients.indices, id: \.self) { index in
                    IngredientEditRow(
                        ingredient: $ingredients[index],
                        onDelete: {
                            ingredients.remove(at: index)
                        }
                    )
                }
            } header: {
                Text("Ingredients (\(ingredients.count))")
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Computed Properties
    
    /// Total calories across all ingredients
    private var totalCalories: Double {
        ingredients.reduce(0) { $0 + $1.calories }
    }
    
    /// Total protein across all ingredients
    private var totalProtein: Double {
        ingredients.reduce(0) { $0 + ($1.protein ?? 0) }
    }
    
    /// Total carbs across all ingredients
    private var totalCarbs: Double {
        ingredients.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }
    
    /// Total fats across all ingredients
    private var totalFats: Double {
        ingredients.reduce(0) { $0 + ($1.fats ?? 0) }
    }
    
    // MARK: - Actions
    
    /// Converts source items (search results or food items) to ingredients
    private func convertSourceItemsToIngredients() {
        switch sourceItems {
        case .searchResults(let results):
            ingredients = results.compactMap { result in
                try? IngredientConverter.convertSearchResultToIngredient(result)
            }
        case .foodItems(let items):
            ingredients = items.compactMap { item in
                try? IngredientConverter.convertFoodItemToIngredient(item)
            }
        }
    }
    
    /// Validates and saves the custom meal
    private func saveMeal() {
        // Validate meal name
        let trimmedName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = "Meal name is required"
            return
        }
        
        guard trimmedName.count <= 100 else {
            validationError = "Meal name must be 100 characters or less"
            return
        }
        
        // Validate ingredients
        guard !ingredients.isEmpty else {
            validationError = "At least one ingredient is required"
            return
        }
        
        // Clear validation error
        validationError = nil
        isSaving = true
        
        Task {
            do {
                _ = try await manager.saveCustomMeal(name: trimmedName, ingredients: ingredients)
                
                await MainActor.run {
                    isSaving = false
                    
                    // Show success toast
                    toastMessage = "'\(trimmedName)' saved successfully"
                    toastStyle = .success
                    showingToast = true
                    
                    // Delay dismissal to show toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onComplete()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    validationError = manager.errorMessage ?? "Failed to save custom meal"
                    
                    // Show error toast
                    toastMessage = validationError ?? "Failed to save meal"
                    toastStyle = .error
                    showingToast = true
                }
            }
        }
    }
}

// MARK: - Ingredient Edit Row Component

/// Editable row for an ingredient in the meal builder review
struct IngredientEditRow: View {
    /// Binding to the ingredient being edited
    @Binding var ingredient: Ingredient
    
    /// Callback when delete is requested
    let onDelete: () -> Void
    
    /// Controls expanded state for editing
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with name and delete button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ingredient.name)
                        .font(.headline)
                    
                    Text("\(formatQuantity(ingredient.quantity)) \(ingredient.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            // Nutritional summary
            HStack(spacing: 12) {
                nutritionalValue(label: "Cal", value: ingredient.calories, color: .blue)
                
                if let protein = ingredient.protein, protein > 0 {
                    nutritionalValue(label: "P", value: protein, color: .blue)
                }
                
                if let carbs = ingredient.carbohydrates, carbs > 0 {
                    nutritionalValue(label: "C", value: carbs, color: .green)
                }
                
                if let fats = ingredient.fats, fats > 0 {
                    nutritionalValue(label: "F", value: fats, color: .orange)
                }
            }
            
            // Edit button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide Details" : "Edit Details")
                        .font(.caption)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            // Expanded editing fields
            if isExpanded {
                editingFields
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Nutritional value display
    private func nutritionalValue(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(Int(value))")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
    
    /// Editing fields (shown when expanded)
    private var editingFields: some View {
        VStack(spacing: 12) {
            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Ingredient name", text: $ingredient.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Quantity and unit
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Quantity", value: $ingredient.quantity, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Unit", text: $ingredient.unit)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            // Calories
            VStack(alignment: .leading, spacing: 4) {
                Text("Calories")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Calories", value: $ingredient.calories, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            
            // Macros (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Macros (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    macroField(label: "Protein (g)", value: $ingredient.protein)
                    macroField(label: "Carbs (g)", value: $ingredient.carbohydrates)
                    macroField(label: "Fats (g)", value: $ingredient.fats)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    /// Macro field (optional double)
    private func macroField(label: String, value: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Formats quantity for display
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

// MARK: - Preview

#Preview("From Search Results") {
    let sampleResults = [
        NutritionSearchResult(
            id: "1",
            name: "Chicken Breast",
            calories: 165,
            servingSize: "100",
            servingUnit: "g",
            brandName: nil,
            protein: 31,
            carbohydrates: 0,
            fats: 3.6
        ),
        NutritionSearchResult(
            id: "2",
            name: "Brown Rice",
            calories: 216,
            servingSize: "1",
            servingUnit: "cup",
            brandName: nil,
            protein: 5,
            carbohydrates: 45,
            fats: 1.8
        )
    ]
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self, configurations: config)
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let aiParser = AIRecipeParser()
    let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    MealBuilderReviewView(
        sourceItems: .searchResults(sampleResults),
        manager: manager,
        onComplete: {}
    )
}

#Preview("From Food Items") {
    let sampleFoodItems = [
        FoodItem(
            name: "Grilled Salmon",
            calories: 206,
            servingSize: "100",
            servingUnit: "g",
            source: .api,
            protein: 22,
            carbohydrates: 0,
            fats: 13
        ),
        FoodItem(
            name: "Quinoa",
            calories: 120,
            servingSize: "0.5",
            servingUnit: "cup",
            source: .manual,
            protein: 4,
            carbohydrates: 21,
            fats: 2
        )
    ]
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self, configurations: config)
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let aiParser = AIRecipeParser()
    let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    MealBuilderReviewView(
        sourceItems: .foodItems(sampleFoodItems),
        manager: manager,
        onComplete: {}
    )
}
