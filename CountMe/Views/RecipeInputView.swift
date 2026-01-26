//
//  RecipeInputView.swift
//  CountMe
//
//  View for AI-powered recipe parsing with natural language input
//

import SwiftUI
import SwiftData

/// Recipe input view that allows users to describe recipes in natural language for AI parsing
///
/// This view provides:
/// - Multi-line text field for recipe description
/// - Character count display (10-500 character limit)
/// - Parse Recipe button with AI integration
/// - Loading indicator during AI request
/// - Error display with retry option
/// - Manual entry fallback button
/// - Example prompts to guide user input
/// - Network reachability detection
///
/// Requirements: 1.1, 1.4, 7.3, 11.3
struct RecipeInputView: View {
    /// The custom meal manager business logic
    @Bindable var manager: CustomMealManager
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Recipe description input
    @State private var recipeDescription: String = ""
    
    /// Network reachability monitor
    @State private var networkMonitor = NetworkMonitor()
    
    /// Focus state for text editor
    @FocusState private var isTextEditorFocused: Bool
    
    /// Controls navigation to ingredient review view
    @State private var parsedRecipe: ParsedRecipe?
    
    /// Controls navigation to manual ingredient entry
    @State private var showingManualEntry: Bool = false
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .info
    
    // MARK: - Computed Properties
    
    /// Character count for the recipe description
    private var characterCount: Int {
        recipeDescription.count
    }
    
    /// Whether the recipe description meets minimum length requirement
    private var meetsMinimumLength: Bool {
        characterCount >= 10
    }
    
    /// Whether the recipe description exceeds maximum length
    private var exceedsMaximumLength: Bool {
        characterCount > 500
    }
    
    /// Whether the parse button should be enabled
    private var canParse: Bool {
        meetsMinimumLength && !exceedsMaximumLength && networkMonitor.isConnected && !manager.isLoading
    }
    
    /// Character count color based on validation state
    private var characterCountColor: Color {
        if exceedsMaximumLength {
            return .red
        } else if !meetsMinimumLength && characterCount > 0 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Example prompts section
                    examplePromptsSection
                    
                    // Recipe input section
                    recipeInputSection
                    
                    // Character count display
                    characterCountDisplay
                    
                    // Network status warning
                    if !networkMonitor.isConnected {
                        networkOfflineWarning
                    }
                    
                    // Error message display
                    if let error = manager.errorMessage {
                        errorDisplay(error)
                    }
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Add Custom Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(manager.isLoading)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTextEditorFocused = false
                        }
                    }
                }
            }
            .disabled(manager.isLoading)
            .navigationDestination(item: $parsedRecipe) { recipe in
                IngredientReviewView(
                    manager: manager,
                    parsedRecipe: recipe
                )
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualIngredientEntryView(manager: manager)
            }
            .onAppear {
                networkMonitor.start()
            }
            .onDisappear {
                networkMonitor.stop()
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
        }
    }
    
    // MARK: - View Components
    
    /// Example prompts to guide user input
    private var examplePromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe Your Recipe")
                .font(.headline)
            
            Text("Tell us what's in your meal and we'll break it down into ingredients with nutritional information.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                examplePrompt("Chicken stir fry with rice and broccoli")
                examplePrompt("Grilled salmon with quinoa and asparagus")
                examplePrompt("Pasta with tomato sauce, ground beef, and parmesan")
            }
            .padding(.top, 4)
        }
    }
    
    /// Individual example prompt button
    private func examplePrompt(_ text: String) -> some View {
        Button {
            recipeDescription = text
        } label: {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    /// Recipe description text editor
    private var recipeInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipe Description")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            TextEditor(text: $recipeDescription)
                .focused($isTextEditorFocused)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if recipeDescription.isEmpty {
                        Text("e.g., Chicken breast with brown rice and steamed vegetables...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    /// Border color based on validation state
    private var borderColor: Color {
        if exceedsMaximumLength {
            return .red
        } else if isTextEditorFocused {
            return .blue
        } else {
            return .clear
        }
    }
    
    /// Character count display with validation feedback
    private var characterCountDisplay: some View {
        HStack {
            Text("\(characterCount) / 500 characters")
                .font(.caption)
                .foregroundColor(characterCountColor)
            
            Spacer()
            
            if !meetsMinimumLength && characterCount > 0 {
                Text("Minimum 10 characters")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if exceedsMaximumLength {
                Text("Maximum 500 characters")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    /// Network offline warning
    private var networkOfflineWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No Internet Connection")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("AI parsing requires an internet connection. You can still enter ingredients manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Error display with retry option
    private func errorDisplay(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Button {
                parseRecipe()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Action buttons section
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Parse Recipe button
            Button {
                parseRecipe()
            } label: {
                HStack {
                    if manager.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    
                    Text(manager.isLoading ? "Parsing Recipe..." : "Parse Recipe")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canParse ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!canParse)
            
            // Manual entry button
            Button {
                showingManualEntry = true
            } label: {
                HStack {
                    Image(systemName: "pencil.circle")
                    Text("Enter Manually")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
            .disabled(manager.isLoading)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    /// Parses the recipe description using AI
    private func parseRecipe() {
        // Clear focus from text editor
        isTextEditorFocused = false
        
        Task {
            do {
                let recipe = try await manager.parseRecipe(description: recipeDescription)
                
                await MainActor.run {
                    parsedRecipe = recipe
                }
            } catch {
                // Error is already captured in manager.errorMessage
                // No additional action needed
            }
        }
    }
}

// MARK: - Supporting Views

/// View for reviewing and editing parsed ingredients before saving as a custom meal
///
/// This view provides:
/// - List of parsed ingredients with editable fields
/// - Total nutritional summary at top
/// - Add/remove ingredient functionality
/// - Inline validation with error display
/// - Save custom meal with name prompt
/// - Warning for low AI confidence
///
/// Requirements: 1.3, 1.4, 1.5, 1.6, 9.1, 9.2, 9.4
struct IngredientReviewView: View {
    @Bindable var manager: CustomMealManager
    let parsedRecipe: ParsedRecipe
    
    @Environment(\.dismiss) private var dismiss
    
    /// Editable ingredients list
    @State private var ingredients: [EditableIngredient] = []
    
    /// Controls meal name prompt alert
    @State private var showingSaveAlert = false
    
    /// Meal name input
    @State private var mealName = ""
    
    /// Validation error for meal name
    @State private var mealNameError: String?
    
    /// Controls toast notification display
    @State private var showingToast: Bool = false
    
    /// Toast message
    @State private var toastMessage: String = ""
    
    /// Toast style
    @State private var toastStyle: ToastStyle = .success
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Low confidence warning
                if parsedRecipe.confidence < 0.7 {
                    lowConfidenceWarning
                }
                
                // Total nutritional summary
                nutritionalSummaryCard
                
                // Ingredients list
                ingredientsSection
                
                // Add ingredient button
                addIngredientButton
                
                // Action buttons
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Review Ingredients")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(manager.isLoading)
            }
        }
        .alert("Save Custom Meal", isPresented: $showingSaveAlert) {
            TextField("Meal Name", text: $mealName)
            
            Button("Cancel", role: .cancel) {
                mealName = ""
                mealNameError = nil
            }
            
            Button("Save") {
                saveMeal()
            }
        } message: {
            if let error = mealNameError {
                Text(error)
            } else {
                Text("Enter a name for this custom meal")
            }
        }
        .toast(
            isPresented: $showingToast,
            message: toastMessage,
            style: toastStyle
        )
        .onAppear {
            // Initialize editable ingredients from parsed recipe
            ingredients = parsedRecipe.ingredients.map { EditableIngredient(from: $0) }
        }
        .disabled(manager.isLoading)
    }
    
    // MARK: - View Components
    
    /// Warning displayed when AI confidence is low
    private var lowConfidenceWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Low Confidence Parsing")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("The AI may not have parsed all ingredients accurately. Please review and edit as needed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Nutritional summary card showing totals
    private var nutritionalSummaryCard: some View {
        VStack(spacing: 16) {
            Text("Total Nutritional Values")
                .font(.headline)
            
            HStack(spacing: 20) {
                nutritionalValueColumn(
                    title: "Calories",
                    value: String(format: "%.0f", totalCalories),
                    unit: "kcal",
                    color: .blue
                )
                
                Divider()
                
                nutritionalValueColumn(
                    title: "Protein",
                    value: String(format: "%.1f", totalProtein),
                    unit: "g",
                    color: .blue
                )
                
                Divider()
                
                nutritionalValueColumn(
                    title: "Carbs",
                    value: String(format: "%.1f", totalCarbs),
                    unit: "g",
                    color: .green
                )
                
                Divider()
                
                nutritionalValueColumn(
                    title: "Fats",
                    value: String(format: "%.1f", totalFats),
                    unit: "g",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Individual nutritional value column
    private func nutritionalValueColumn(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Ingredients list section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)
            
            ForEach(Array(ingredients.enumerated()), id: \.offset) { index, _ in
                IngredientRowView(
                    ingredient: $ingredients[index],
                    onDelete: {
                        withAnimation {
                            _ = ingredients.remove(at: index)
                        }
                    }
                )
            }
        }
    }
    
    /// Add ingredient button
    private var addIngredientButton: some View {
        Button {
            withAnimation {
                ingredients.append(EditableIngredient())
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Ingredient")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .foregroundColor(.blue)
            .cornerRadius(10)
        }
    }
    
    /// Action buttons section
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save button
            Button {
                showingSaveAlert = true
            } label: {
                HStack {
                    if manager.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    
                    Text(manager.isLoading ? "Saving..." : "Save Custom Meal")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!canSave || manager.isLoading)
            
            // Cancel button
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .disabled(manager.isLoading)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    
    /// Total calories across all ingredients
    private var totalCalories: Double {
        ingredients.reduce(0) { $0 + ($1.calories ?? 0) }
    }
    
    /// Total protein across all ingredients
    private var totalProtein: Double {
        ingredients.reduce(0) { $0 + ($1.protein ?? 0) }
    }
    
    /// Total carbohydrates across all ingredients
    private var totalCarbs: Double {
        ingredients.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }
    
    /// Total fats across all ingredients
    private var totalFats: Double {
        ingredients.reduce(0) { $0 + ($1.fats ?? 0) }
    }
    
    /// Whether the meal can be saved
    private var canSave: Bool {
        // Must have at least one ingredient
        guard !ingredients.isEmpty else { return false }
        
        // All ingredients must be valid
        return ingredients.allSatisfy { $0.isValid }
    }
    
    // MARK: - Actions
    
    /// Saves the custom meal
    private func saveMeal() {
        // Validate meal name
        let trimmedName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            mealNameError = "Meal name cannot be empty"
            showingSaveAlert = true
            return
        }
        
        // Convert editable ingredients to Ingredient models
        let ingredientModels = ingredients.compactMap { $0.toIngredient() }
        
        // Ensure we have valid ingredients
        guard ingredientModels.count == ingredients.count else {
            mealNameError = "Some ingredients have invalid data"
            showingSaveAlert = true
            return
        }
        
        Task {
            do {
                _ = try await manager.saveCustomMeal(name: trimmedName, ingredients: ingredientModels)
                
                await MainActor.run {
                    mealName = ""
                    mealNameError = nil
                    toastMessage = "Custom meal '\(trimmedName)' saved successfully!"
                    toastStyle = .success
                    showingToast = true
                    
                    // Dismiss after toast is shown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        dismiss()
                    }
                }
            } catch {
                // Error is captured in manager.errorMessage
                await MainActor.run {
                    mealNameError = manager.errorMessage ?? "Failed to save meal"
                    showingSaveAlert = true
                }
            }
        }
    }
}

// MARK: - Editable Ingredient Model

/// Editable ingredient with validation
struct EditableIngredient: Identifiable {
    let id = UUID()
    
    var name: String
    var quantity: Double?
    var unit: String
    var calories: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fats: Double?
    
    /// Validation errors
    var nameError: String?
    var quantityError: String?
    var caloriesError: String?
    var proteinError: String?
    var carbsError: String?
    var fatsError: String?
    
    /// Whether the ingredient is valid
    var isValid: Bool {
        // Name must not be empty
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Quantity must be positive
        guard let qty = quantity, qty > 0 else {
            return false
        }
        
        // Calories must be positive
        guard let cal = calories, cal > 0 else {
            return false
        }
        
        // Optional macros must be non-negative if present
        if let p = protein, p < 0 { return false }
        if let c = carbohydrates, c < 0 { return false }
        if let f = fats, f < 0 { return false }
        
        return true
    }
    
    /// Creates an empty editable ingredient
    init() {
        self.name = ""
        self.quantity = nil
        self.unit = "serving"
        self.calories = nil
        self.protein = nil
        self.carbohydrates = nil
        self.fats = nil
    }
    
    /// Creates an editable ingredient from a parsed ingredient
    init(from parsed: ParsedIngredient) {
        self.name = parsed.name
        self.quantity = parsed.quantity
        self.unit = parsed.unit
        self.calories = parsed.calories
        self.protein = parsed.protein
        self.carbohydrates = parsed.carbohydrates
        self.fats = parsed.fats
    }
    
    /// Converts to an Ingredient model
    func toIngredient() -> Ingredient? {
        guard isValid else { return nil }
        
        return Ingredient(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity!,
            unit: unit,
            calories: calories!,
            protein: protein,
            carbohydrates: carbohydrates,
            fats: fats
        )
    }
}

// MARK: - Ingredient Row View

/// Individual ingredient row with editable fields and validation
struct IngredientRowView: View {
    @Binding var ingredient: EditableIngredient
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    @FocusState private var focusedField: IngredientField?
    
    enum IngredientField {
        case name, quantity, calories, protein, carbs, fats
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Ingredient name", text: $ingredient.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .name)
                        .onChange(of: ingredient.name) { _, _ in
                            validateName()
                        }
                    
                    if let error = ingredient.nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            TextField("Qty", value: $ingredient.quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .quantity)
                                .onChange(of: ingredient.quantity) { _, _ in
                                    validateQuantity()
                                }
                            
                            Text(ingredient.unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let error = ingredient.quantityError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            TextField("Cal", value: $ingredient.calories, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .calories)
                                .onChange(of: ingredient.calories) { _, _ in
                                    validateCalories()
                                }
                            
                            Text("kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let error = ingredient.caloriesError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            
            // Expanded macro fields
            if isExpanded {
                VStack(spacing: 12) {
                    macroField(
                        title: "Protein (g)",
                        value: $ingredient.protein,
                        error: ingredient.proteinError,
                        color: .blue,
                        field: .protein
                    )
                    
                    macroField(
                        title: "Carbs (g)",
                        value: $ingredient.carbohydrates,
                        error: ingredient.carbsError,
                        color: .green,
                        field: .carbs
                    )
                    
                    macroField(
                        title: "Fats (g)",
                        value: $ingredient.fats,
                        error: ingredient.fatsError,
                        color: .orange,
                        field: .fats
                    )
                    
                    // Delete button
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Ingredient")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
        }
    }
    
    /// Border color based on validation state
    private var borderColor: Color {
        if !ingredient.isValid {
            return .red
        } else if focusedField != nil {
            return .blue
        } else {
            return .clear
        }
    }
    
    /// Validation methods
    private func validateName() {
        let trimmed = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            ingredient.nameError = "Name is required"
        } else {
            ingredient.nameError = nil
        }
    }
    
    private func validateQuantity() {
        if let qty = ingredient.quantity {
            if qty <= 0 {
                ingredient.quantityError = "Must be > 0"
            } else {
                ingredient.quantityError = nil
            }
        } else {
            ingredient.quantityError = "Required"
        }
    }
    
    private func validateCalories() {
        if let cal = ingredient.calories {
            if cal <= 0 {
                ingredient.caloriesError = "Must be > 0"
            } else {
                ingredient.caloriesError = nil
            }
        } else {
            ingredient.caloriesError = "Required"
        }
    }
    
    private func validateMacro(_ value: Double?) -> String? {
        if let val = value, val < 0 {
            return "Cannot be negative"
        }
        return nil
    }
    
    /// Macro field row with validation
    private func macroField(
        title: String,
        value: Binding<Double?>,
        error: String?,
        color: Color,
        field: IngredientField
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                
                TextField("Optional", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: field)
                    .onChange(of: value.wrappedValue) { _, newValue in
                        // Validate macro value
                        switch field {
                        case .protein:
                            ingredient.proteinError = validateMacro(newValue)
                        case .carbs:
                            ingredient.carbsError = validateMacro(newValue)
                        case .fats:
                            ingredient.fatsError = validateMacro(newValue)
                        default:
                            break
                        }
                    }
                
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

/// Placeholder for ManualIngredientEntryView
struct ManualIngredientEntryView: View {
    @Bindable var manager: CustomMealManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Manual Ingredient Entry - To be implemented")
                .navigationTitle("Add Ingredients")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
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
    
    RecipeInputView(manager: manager)
}
