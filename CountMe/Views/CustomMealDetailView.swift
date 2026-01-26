//
//  CustomMealDetailView.swift
//  CountMe
//
//  Detail view for viewing and adding custom meals to daily log
//

import SwiftUI
import SwiftData

/// Detail view for viewing a custom meal and adding it to the daily log
///
/// This view provides:
/// - Meal name and creation date display
/// - Full ingredient list with quantities and units
/// - Total nutritional breakdown (calories, protein, carbs, fats)
/// - Serving size adjustment control (stepper, default 1.0)
/// - Real-time recalculation of nutritional values as serving size changes
/// - "Add to Today" button that adds meal to current daily log
/// - Delete button with confirmation alert
/// - Updates lastUsedAt timestamp when meal is added to log
///
/// **Note**: Edit functionality is not yet implemented. This requires extending
/// IngredientReviewView to support editing existing meals (Task 9.1).
///
/// **Validates: Requirements 3.2, 3.4, 4.1, 9.1**
struct CustomMealDetailView: View {
    /// The custom meal to display
    let meal: CustomMeal
    
    /// The custom meal manager business logic
    @Bindable var manager: CustomMealManager
    
    /// Optional callback to dismiss the entire sheet stack
    var onDismissAll: (() -> Void)? = nil
    
    /// SwiftData model context for fetching/creating daily logs
    @Environment(\.modelContext) private var modelContext
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Serving size multiplier (default 1.0)
    @State private var servingMultiplier: Double = 1.0
    
    /// Controls display of delete confirmation alert
    @State private var showingDeleteAlert: Bool = false
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                headerSection
                
                // Serving size adjustment
                servingSizeSection
                
                // Nutritional summary
                nutritionalSummarySection
                
                // Ingredients list
                ingredientsSection
                
                // Action buttons
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Delete Custom Meal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMeal()
            }
        } message: {
            Text("Are you sure you want to delete '\(meal.name)'? This action cannot be undone.")
        }
        .toast(
            isPresented: $showingToast,
            message: toastMessage,
            style: toastStyle
        )
    }
    
    // MARK: - View Components
    
    /// Header section with creation date and last used date
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Label {
                    Text("Created \(meal.createdAt, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Label {
                    Text("Used \(meal.lastUsedAt, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("\(meal.ingredients.count) ingredient\(meal.ingredients.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// Serving size adjustment section
    private var servingSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Serving Size")
                .font(.headline)
            
            HStack {
                Stepper(
                    value: $servingMultiplier,
                    in: 0.25...10.0,
                    step: 0.25
                ) {
                    HStack {
                        Text("Servings:")
                            .font(.subheadline)
                        
                        Text(String(format: "%.2f", servingMultiplier))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if servingMultiplier != 1.0 {
                Text("Nutritional values are adjusted based on serving size")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Nutritional summary section with adjusted values
    private var nutritionalSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutritional Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Calories
                nutritionalRow(
                    label: "Calories",
                    value: Int(meal.totalCalories * servingMultiplier),
                    unit: "cal",
                    color: .blue
                )
                
                // Protein
                if meal.totalProtein > 0 {
                    nutritionalRow(
                        label: "Protein",
                        value: Int(meal.totalProtein * servingMultiplier),
                        unit: "g",
                        color: .blue
                    )
                }
                
                // Carbohydrates
                if meal.totalCarbohydrates > 0 {
                    nutritionalRow(
                        label: "Carbohydrates",
                        value: Int(meal.totalCarbohydrates * servingMultiplier),
                        unit: "g",
                        color: .green
                    )
                }
                
                // Fats
                if meal.totalFats > 0 {
                    nutritionalRow(
                        label: "Fats",
                        value: Int(meal.totalFats * servingMultiplier),
                        unit: "g",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    /// Nutritional row component
    private func nutritionalRow(label: String, value: Int, unit: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Ingredients list section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(meal.ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }
        }
    }
    
    /// Individual ingredient row with adjusted values
    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ingredient.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1f %@", ingredient.quantity * servingMultiplier, ingredient.unit))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                nutritionalBadge(
                    value: Int(ingredient.calories * servingMultiplier),
                    unit: "cal",
                    color: .blue
                )
                
                if let protein = ingredient.protein, protein > 0 {
                    nutritionalBadge(
                        value: Int(protein * servingMultiplier),
                        unit: "g protein",
                        color: .blue
                    )
                }
                
                if let carbs = ingredient.carbohydrates, carbs > 0 {
                    nutritionalBadge(
                        value: Int(carbs * servingMultiplier),
                        unit: "g carbs",
                        color: .green
                    )
                }
                
                if let fats = ingredient.fats, fats > 0 {
                    nutritionalBadge(
                        value: Int(fats * servingMultiplier),
                        unit: "g fats",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    /// Nutritional value badge
    private func nutritionalBadge(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
    
    /// Action buttons section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                addToToday()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Today")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(manager.isLoading)
            
            if manager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            if let error = manager.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Actions
    
    /// Adds the custom meal to today's daily log
    private func addToToday() {
        Task {
            do {
                // Get or create today's daily log
                let today = Date()
                let dataStore = DataStore(modelContext: modelContext)
                
                var todayLog = try await dataStore.fetchDailyLog(for: today)
                
                if todayLog == nil {
                    // Create a new daily log for today
                    todayLog = DailyLog(date: today)
                    try await dataStore.saveDailyLog(todayLog!)
                }
                
                guard let log = todayLog else {
                    manager.errorMessage = "Unable to create daily log"
                    return
                }
                
                // Add the custom meal to the log with serving multiplier
                let _ = try await manager.addCustomMealToLog(
                    meal,
                    servingMultiplier: servingMultiplier,
                    log: log
                )
                
                // Dismiss the entire sheet stack to return to main page
                await MainActor.run {
                    if let onDismissAll = onDismissAll {
                        // Use callback to dismiss entire sheet stack
                        onDismissAll()
                    } else {
                        // Fallback to just dismissing this view
                        dismiss()
                    }
                }
            } catch {
                // Show error toast
                toastMessage = manager.errorMessage ?? "Unable to add meal to log"
                toastStyle = .error
                withAnimation {
                    showingToast = true
                }
            }
        }
    }
    
    /// Deletes the custom meal
    private func deleteMeal() {
        Task {
            do {
                try await manager.deleteCustomMeal(meal)
                
                // Show success toast before dismissing
                toastMessage = "'\(meal.name)' deleted successfully"
                toastStyle = .success
                withAnimation {
                    showingToast = true
                }
                
                // Dismiss after toast is shown
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                // Show error toast
                toastMessage = manager.errorMessage ?? "Unable to delete meal"
                toastStyle = .error
                withAnimation {
                    showingToast = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let aiParser = AIRecipeParser()
    let manager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    let sampleMeal = CustomMeal(
        name: "Chicken Stir Fry",
        ingredients: [
            Ingredient(name: "Chicken Breast", quantity: 6, unit: "oz", calories: 187, protein: 35, carbohydrates: 0, fats: 4),
            Ingredient(name: "White Rice", quantity: 1, unit: "cup", calories: 206, protein: 4, carbohydrates: 45, fats: 0.4),
            Ingredient(name: "Broccoli", quantity: 1, unit: "cup", calories: 31, protein: 2.5, carbohydrates: 6, fats: 0.3)
        ],
        createdAt: Date().addingTimeInterval(-86400 * 7),
        lastUsedAt: Date().addingTimeInterval(-3600)
    )
    
    NavigationStack {
        CustomMealDetailView(
            meal: sampleMeal,
            manager: manager,
            onDismissAll: nil
        )
            .modelContainer(container)
    }
}
