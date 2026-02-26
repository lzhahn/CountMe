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
/// - Character count display (10-2000 character limit)
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
    
    /// Callback to dismiss the entire sheet stack and optionally show a meal detail
    var onDismiss: ((CustomMeal?) -> Void)? = nil
    
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
        characterCount > 2000
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
                    parsedRecipe: recipe,
                    onDismissAll: { savedMeal in
                        // Dismiss the entire sheet stack and pass the saved meal
                        onDismiss?(savedMeal)
                        dismiss()
                    }
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
            Text("\(characterCount) / 2000 characters")
                .font(.caption)
                .foregroundColor(characterCountColor)
            
            Spacer()
            
            if !meetsMinimumLength && characterCount > 0 {
                Text("Minimum 10 characters")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if exceedsMaximumLength {
                Text("Maximum 2000 characters")
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
    
    /// Callback to dismiss the entire sheet stack with the saved meal
    var onDismissAll: ((CustomMeal?) -> Void)? = nil
    
    /// Editable ingredients list
    @State private var ingredients: [EditableIngredient] = []
    
    /// Controls meal name prompt sheet
    @State private var showingSaveSheet = false
    
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
    
    /// Serving count input text
    @State private var servingCountText: String = "1"
    
    /// Serving count validation error
    @State private var servingCountError: String?
    
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
                
                // Serving information section
                servingInformationSection
                
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
        .sheet(isPresented: $showingSaveSheet) {
            SaveMealNameSheet(
                mealName: $mealName,
                errorMessage: $mealNameError,
                onSave: { name in
                    mealName = name
                    saveMeal()
                },
                onCancel: {
                    mealName = ""
                    mealNameError = nil
                    showingSaveSheet = false
                }
            )
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
            
            // Quick add hint
            Text("Tip: Use Quick Add to save immediately, or Review & Save to customize")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
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
    
    /// Serving information section
    private var servingInformationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Serving Information (Optional)")
                .font(.headline)
            
            HStack {
                Text("This recipe makes")
                    .font(.subheadline)
                
                TextField("1", text: $servingCountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .onChange(of: servingCountText) { _, newValue in
                        validateServingCount(newValue)
                    }
                
                Text("servings")
                    .font(.subheadline)
            }
            
            if let error = servingCountError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Text("Leave as 1 if the entire recipe is one serving")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Action buttons section
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Quick Add button
            Button {
                quickAddMeal()
            } label: {
                HStack {
                    if manager.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.circle.fill")
                    }
                    
                    Text(manager.isLoading ? "Adding..." : "Quick Add")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!canSave || manager.isLoading)
            
            // Save button (with review)
            Button {
                showingSaveSheet = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Review & Save")
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
        guard ingredients.allSatisfy({ $0.isValid }) else { return false }
        
        // Serving count must be valid (no error)
        guard servingCountError == nil else { return false }
        
        return true
    }
    
    // MARK: - Actions
    
    /// Validates the serving count input
    private func validateServingCount(_ text: String) {
        // Allow empty (will default to 1.0)
        if text.isEmpty {
            servingCountError = nil
            return
        }
        
        // Try to parse as Double
        guard let value = Double(text) else {
            servingCountError = "Must be a valid number"
            return
        }
        
        // Must be positive and greater than zero
        if value <= 0 {
            servingCountError = "Must be greater than 0"
            return
        }
        
        // Valid
        servingCountError = nil
    }
    
    /// Quick adds the meal with an auto-generated name based on ingredients
    ///
    /// This method provides a fast workflow for saving AI-parsed recipes without
    /// requiring the user to enter a custom name. The name is generated from the
    /// first 2-3 ingredients using the format:
    /// - 1 ingredient: "Chicken Breast"
    /// - 2 ingredients: "Chicken Breast & Brown Rice"
    /// - 3+ ingredients: "Chicken Breast, Brown Rice & More"
    ///
    /// The method validates all ingredients, respects the serving count, and
    /// saves the meal to local storage with automatic Firebase sync when authenticated.
    ///
    /// Requirements: 1.4, 9.1, 9.2
    private func quickAddMeal() {
        // Generate a default name from the first few ingredients
        let defaultName = generateDefaultMealName()
        
        // Convert editable ingredients to Ingredient models
        let ingredientModels = ingredients.compactMap { $0.toIngredient() }
        
        // Ensure we have valid ingredients
        guard ingredientModels.count == ingredients.count else {
            return
        }
        
        // Parse serving count (default to 1.0 if empty or invalid)
        let servingsCount: Double
        if servingCountText.isEmpty {
            servingsCount = 1.0
        } else if let parsed = Double(servingCountText), parsed > 0 {
            servingsCount = parsed
        } else {
            servingsCount = 1.0
        }
        
        Task {
            do {
                let savedMeal = try await manager.saveCustomMeal(
                    name: defaultName,
                    ingredients: ingredientModels,
                    servingsCount: servingsCount
                )
                
                await MainActor.run {
                    // Show success toast
                    toastMessage = "'\(defaultName)' added successfully"
                    toastStyle = .success
                    showingToast = true
                    
                    // Delay dismissal to show toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Dismiss the entire sheet stack and pass the saved meal
                        if let onDismissAll = onDismissAll {
                            onDismissAll(savedMeal)
                        } else {
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    toastMessage = manager.errorMessage ?? "Failed to save meal"
                    toastStyle = .error
                    showingToast = true
                }
            }
        }
    }
    
    /// Generates a default meal name from the first 2-3 ingredients
    ///
    /// Uses a smart naming strategy to create readable meal names:
    /// - Empty: "Custom Meal"
    /// - Single ingredient: Uses the ingredient name directly
    /// - Two ingredients: Joins with " & " (e.g., "Chicken & Rice")
    /// - Three or more: Shows first two plus " & More"
    ///
    /// - Returns: A human-readable meal name suitable for display
    private func generateDefaultMealName() -> String {
        let maxIngredients = 3
        let ingredientNames = ingredients.prefix(maxIngredients).map { $0.name }
        
        if ingredientNames.isEmpty {
            return "Custom Meal"
        } else if ingredientNames.count == 1 {
            return ingredientNames[0]
        } else if ingredientNames.count == 2 {
            return "\(ingredientNames[0]) & \(ingredientNames[1])"
        } else {
            let firstTwo = ingredientNames.prefix(2).joined(separator: ", ")
            return "\(firstTwo) & More"
        }
    }
    
    /// Saves the custom meal
    private func saveMeal() {
        // Validate meal name
        let trimmedName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            mealNameError = "Meal name cannot be empty"
            return
        }
        
        // Convert editable ingredients to Ingredient models
        let ingredientModels = ingredients.compactMap { $0.toIngredient() }
        
        // Ensure we have valid ingredients
        guard ingredientModels.count == ingredients.count else {
            mealNameError = "Some ingredients have invalid data"
            return
        }
        
        // Parse serving count (default to 1.0 if empty or invalid)
        let servingsCount: Double
        if servingCountText.isEmpty {
            servingsCount = 1.0
        } else if let parsed = Double(servingCountText), parsed > 0 {
            servingsCount = parsed
        } else {
            servingsCount = 1.0
        }
        
        Task {
            do {
                let savedMeal = try await manager.saveCustomMeal(
                    name: trimmedName,
                    ingredients: ingredientModels,
                    servingsCount: servingsCount
                )
                
                await MainActor.run {
                    // Close the sheet
                    showingSaveSheet = false
                    mealName = ""
                    mealNameError = nil
                    
                    // Show success toast
                    toastMessage = "'\(trimmedName)' saved successfully"
                    toastStyle = .success
                    showingToast = true
                    
                    // Delay dismissal to show toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Dismiss the entire sheet stack and pass the saved meal
                        if let onDismissAll = onDismissAll {
                            onDismissAll(savedMeal)
                        } else {
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    mealNameError = manager.errorMessage ?? "Failed to save meal"
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
        
        // Calories must be non-negative (allow 0 for spices, extracts, etc.)
        guard let cal = calories, cal >= 0 else {
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

    /// Whether the ingredient is completely empty (untouched by user)
    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && quantity == nil
            && calories == nil
            && protein == nil
            && carbohydrates == nil
            && fats == nil
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

    /// Creates an editable ingredient from a nutrition search result
    init(from result: NutritionSearchResult) {
        self.name = result.name
        self.quantity = Double(result.servingSize ?? "1") ?? 1
        self.unit = result.servingUnit ?? "serving"
        self.calories = result.calories
        self.protein = result.protein
        self.carbohydrates = result.carbohydrates
        self.fats = result.fats
    }
    
    /// Converts to an Ingredient model
    func toIngredient() -> Ingredient? {
        guard isValid else { return nil }
        
        return try? Ingredient(
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
            if cal < 0 {
                ingredient.caloriesError = "Must be >= 0"
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

/// Manual ingredient entry view for creating custom meals without AI parsing
///
/// This view allows users to manually add ingredients one by one with full control
/// over quantities and nutritional values. Users can also search the USDA nutrition
/// database to add ingredients with pre-filled nutritional data.
///
/// Requirements: 1.3, 1.5, 2.3, 9.1, 9.2
struct ManualIngredientEntryView: View {
    @Bindable var manager: CustomMealManager
    @Environment(\.dismiss) private var dismiss

    /// Optional API client for ingredient search (nil disables search)
    var apiClient: NutritionAPIClient?

    /// Callback to dismiss the entire sheet stack with the saved meal
    var onDismiss: ((CustomMeal?) -> Void)? = nil

    /// Editable ingredients list
    @State private var ingredients: [EditableIngredient] = [EditableIngredient()]

    /// Controls meal name prompt sheet
    @State private var showingSaveSheet = false

    /// Controls ingredient search sheet
    @State private var showingIngredientSearch = false

    /// Meal name input
    @State private var mealName = ""

    /// Validation error for meal name
    @State private var mealNameError: String?

    /// Serving count input text
    @State private var servingCountText: String = "1"

    /// Serving count validation error
    @State private var servingCountError: String?

    /// Controls toast notification display
    @State private var showingToast: Bool = false

    /// Toast message
    @State private var toastMessage: String = ""

    /// Toast style
    @State private var toastStyle: ToastStyle = .success

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Guidance text
                    guidanceSection

                    // Total nutritional summary
                    if !ingredients.isEmpty && ingredients.contains(where: { $0.calories != nil && ($0.calories ?? 0) > 0 }) {
                        nutritionalSummaryCard
                    }

                    // Ingredients list
                    ingredientsSection

                    // Add ingredient buttons
                    addIngredientButtons

                    // Serving information section
                    servingInformationSection

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(manager.isLoading)
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                SaveMealNameSheet(
                    mealName: $mealName,
                    errorMessage: $mealNameError,
                    onSave: { name in
                        mealName = name
                        saveMeal()
                    },
                    onCancel: {
                        mealName = ""
                        mealNameError = nil
                        showingSaveSheet = false
                    }
                )
            }
            .sheet(isPresented: $showingIngredientSearch) {
                if let apiClient = apiClient {
                    IngredientSearchView(apiClient: apiClient) { results in
                        for result in results {
                            ingredients.append(EditableIngredient(from: result))
                        }
                    }
                }
            }
            .toast(
                isPresented: $showingToast,
                message: toastMessage,
                style: toastStyle
            )
            .disabled(manager.isLoading)
        }
    }

    // MARK: - View Components

    /// Guidance text at the top
    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Ingredients")
                .font(.headline)

            Text("Enter each ingredient manually, or search the nutrition database to add items with pre-filled data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Ingredients (\(ingredients.count))")
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

    /// Add ingredient buttons (manual + search)
    private var addIngredientButtons: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation {
                    ingredients.append(EditableIngredient())
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Blank Ingredient")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.blue)
                .cornerRadius(10)
            }

            if apiClient != nil {
                Button {
                    showingIngredientSearch = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search & Add Ingredient")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
            }
        }
    }

    /// Serving information section
    private var servingInformationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Serving Information (Optional)")
                .font(.headline)

            HStack {
                Text("This recipe makes")
                    .font(.subheadline)

                TextField("1", text: $servingCountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .onChange(of: servingCountText) { _, newValue in
                        validateServingCount(newValue)
                    }

                Text("servings")
                    .font(.subheadline)
            }

            if let error = servingCountError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Text("Leave as 1 if the entire recipe is one serving")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    /// Action buttons section
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingSaveSheet = true
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
        }
        .padding(.top, 8)
    }

    // MARK: - Computed Properties

    private var totalCalories: Double {
        ingredients.reduce(0) { $0 + ($1.calories ?? 0) }
    }

    private var totalProtein: Double {
        ingredients.reduce(0) { $0 + ($1.protein ?? 0) }
    }

    private var totalCarbs: Double {
        ingredients.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }

    private var totalFats: Double {
        ingredients.reduce(0) { $0 + ($1.fats ?? 0) }
    }

    private var canSave: Bool {
        guard !ingredients.isEmpty else { return false }
        // Need at least one valid ingredient; empty ones are skipped
        let validIngredients = ingredients.filter { !$0.isEmpty }
        guard !validIngredients.isEmpty else { return false }
        // Non-empty ingredients must all be valid (partially filled = invalid)
        guard validIngredients.allSatisfy({ $0.isValid }) else { return false }
        guard servingCountError == nil else { return false }
        return true
    }

    // MARK: - Actions

    private func validateServingCount(_ text: String) {
        if text.isEmpty {
            servingCountError = nil
            return
        }
        guard let value = Double(text) else {
            servingCountError = "Must be a valid number"
            return
        }
        if value <= 0 {
            servingCountError = "Must be greater than 0"
            return
        }
        servingCountError = nil
    }

    private func saveMeal() {
        let trimmedName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            mealNameError = "Meal name cannot be empty"
            return
        }

        // Filter out empty ingredients, convert the rest
        let nonEmpty = ingredients.filter { !$0.isEmpty }
        let ingredientModels = nonEmpty.compactMap { $0.toIngredient() }
        guard !ingredientModels.isEmpty else {
            mealNameError = "At least one valid ingredient is required"
            return
        }
        guard ingredientModels.count == nonEmpty.count else {
            mealNameError = "Some ingredients have invalid data"
            return
        }

        let servingsCount: Double
        if servingCountText.isEmpty {
            servingsCount = 1.0
        } else if let parsed = Double(servingCountText), parsed > 0 {
            servingsCount = parsed
        } else {
            servingsCount = 1.0
        }

        Task {
            do {
                let savedMeal = try await manager.saveCustomMeal(
                    name: trimmedName,
                    ingredients: ingredientModels,
                    servingsCount: servingsCount
                )

                await MainActor.run {
                    showingSaveSheet = false
                    mealName = ""
                    mealNameError = nil

                    if let onDismiss = onDismiss {
                        onDismiss(savedMeal)
                    } else {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    mealNameError = manager.errorMessage ?? "Failed to save meal"
                }
            }
        }
    }
}

// MARK: - Save Meal Name Sheet

/// Sheet for entering the custom meal name
struct SaveMealNameSheet: View {
    @Binding var mealName: String
    @Binding var errorMessage: String?
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter a name for this custom meal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                TextField("Meal Name", text: $mealName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal)
                    .submitLabel(.done)
                    .onSubmit {
                        if !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(mealName)
                        }
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Save Custom Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(mealName)
                    }
                    .disabled(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.height(200)])
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
