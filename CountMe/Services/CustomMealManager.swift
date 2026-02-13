//
//  CustomMealManager.swift
//  CountMe
//
//  Business logic for managing custom meals with AI parsing integration
//

import Foundation
import Observation

/// Manages custom meal lifecycle including AI parsing, CRUD operations, and daily log integration
///
/// CustomMealManager coordinates between the AI recipe parser, data store, sync engine, and UI layer
/// to provide a complete custom meal management experience. It handles recipe parsing,
/// meal persistence, search/filtering, conversion of custom meals to food items, and cloud synchronization.
///
/// The manager maintains an observable state for UI binding and provides user-friendly
/// error messages for all failure scenarios.
///
/// **Thread Safety**: This class is marked @Observable and should be used from the main actor.
/// All async operations internally coordinate with actor-isolated dependencies (DataStore, AIRecipeParser, FirebaseSyncEngine).
///
/// **Validates: Requirements 1.1, 1.5, 2.1, 2.3, 3.3, 5.2, 9.3, 12.1**
@Observable
@MainActor
final class CustomMealManager {
    // MARK: - Dependencies
    
    private let dataStore: DataStore
    private let aiParser: AIRecipeParser
    private var syncEngine: FirebaseSyncEngine?
    private var userId: String?
    
    // MARK: - Observable State
    
    /// Array of all saved custom meals, sorted by most recently used
    var savedMeals: [CustomMeal] = []
    
    /// Indicates whether an async operation is in progress
    var isLoading: Bool = false
    
    /// User-friendly error message for display in UI
    var errorMessage: String?
    
    // MARK: - Initialization
    
    /// Creates a new CustomMealManager with required dependencies
    ///
    /// - Parameters:
    ///   - dataStore: Actor-based persistence layer for custom meals
    ///   - aiParser: AI service for parsing recipe descriptions
    ///   - syncEngine: Optional sync engine for cloud synchronization
    ///   - userId: Optional authenticated user ID for sync operations
    init(
        dataStore: DataStore,
        aiParser: AIRecipeParser,
        syncEngine: FirebaseSyncEngine? = nil,
        userId: String? = nil
    ) {
        self.dataStore = dataStore
        self.aiParser = aiParser
        self.syncEngine = syncEngine
        self.userId = userId
    }
    
    // MARK: - Sync Configuration
    
    /// Updates the sync engine and user ID for cloud synchronization
    /// Call this when authentication state changes
    /// - Parameters:
    ///   - syncEngine: The sync engine instance (nil if signed out)
    ///   - userId: The authenticated user's ID (nil if signed out)
    func configureSyncEngine(_ syncEngine: FirebaseSyncEngine?, userId: String?) {
        self.syncEngine = syncEngine
        self.userId = userId
    }
    
    // MARK: - Recipe Parsing
    
    /// Parses a natural language recipe description into structured ingredients
    ///
    /// Sends the recipe description to the AI service for parsing. The AI returns
    /// structured ingredient data with nutritional information. If parsing fails,
    /// the error is captured in `errorMessage` for UI display.
    ///
    /// - Parameter description: Natural language recipe description (10-500 characters)
    /// - Returns: ParsedRecipe with ingredients and confidence score
    /// - Throws: AIParserError if parsing fails
    ///
    /// **Usage Example:**
    /// ```swift
    /// do {
    ///     let parsed = try await manager.parseRecipe(description: "chicken stir fry with rice")
    ///     // Display parsed ingredients for user review
    /// } catch {
    ///     // Error message is automatically set in manager.errorMessage
    /// }
    /// ```
    ///
    /// **Validates: Requirements 1.1, 7.1, 7.2**
    func parseRecipe(description: String) async throws -> ParsedRecipe {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let parsed = try await aiParser.parseRecipe(description: description)
            return parsed
        } catch let error as AIParserError {
            errorMessage = error.errorDescription ?? "Unable to parse recipe. Please try again or enter ingredients manually."
            throw error
        } catch {
            errorMessage = "An unexpected error occurred. Please try again or enter ingredients manually."
            throw AIParserError.networkError(error)
        }
    }
    
    // MARK: - Custom Meal CRUD Operations
    
    /// Saves a new custom meal with ingredients to persistent storage
    /// Syncs to cloud if authenticated
    ///
    /// Creates a CustomMeal object with the provided name and ingredients, then
    /// persists it to the data store. The meal becomes immediately available for
    /// browsing and adding to daily logs.
    ///
    /// - Parameters:
    ///   - name: User-provided name for the meal
    ///   - ingredients: Array of ingredients that compose the meal
    /// - Returns: The newly created and persisted CustomMeal
    /// - Throws: SwiftData errors if save operation fails
    ///
    /// **Usage Example:**
    /// ```swift
    /// let ingredients = [/* parsed ingredients */]
    /// let meal = try await manager.saveCustomMeal(name: "My Stir Fry", ingredients: ingredients)
    /// ```
    ///
    /// **Validates: Requirements 1.5, 2.1, 5.2**
    func saveCustomMeal(name: String, ingredients: [Ingredient], servingsCount: Double = 1.0) async throws -> CustomMeal {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        // Validate servingsCount
        guard servingsCount > 0 else {
            let error = ValidationError.invalidServingCount
            errorMessage = error.localizedDescription
            throw error
        }
        
        do {
            let meal = CustomMeal(
                name: name,
                ingredients: ingredients,
                createdAt: Date(),
                lastUsedAt: Date(),
                servingsCount: servingsCount
            )
            
            // Save locally
            try await dataStore.saveCustomMeal(meal)
            
            // Sync to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                meal.userId = userId
                meal.lastModified = Date()
                meal.syncStatus = .pendingUpload
                
                do {
                    try await syncEngine.syncCustomMeal(meal, userId: userId)
                } catch let error as SyncError {
                    // Handle sync errors gracefully - local data is already saved
                    print("⚠️ Sync error while saving custom meal: \(error.localizedDescription)")
                    // Don't throw - the meal was saved locally successfully
                }
            }
            
            // Reload all meals to update UI
            await loadAllCustomMeals()
            
            return meal
        } catch {
            errorMessage = "Unable to save custom meal. Please try again."
            throw error
        }
    }
    
    /// Updates an existing custom meal in persistent storage
    /// Syncs update to cloud if authenticated
    ///
    /// Updates the meal's data including ingredients, name, and timestamps.
    /// The lastUsedAt timestamp is automatically updated to the current time.
    ///
    /// **Important**: Editing a custom meal template does not affect previously
    /// logged meal instances in daily logs (Property 6: Custom Meal Data Independence).
    ///
    /// - Parameter meal: The custom meal with updated values
    /// - Throws: SwiftData errors if update operation fails
    ///
    /// **Usage Example:**
    /// ```swift
    /// meal.name = "Updated Name"
    /// meal.ingredients.append(newIngredient)
    /// try await manager.updateCustomMeal(meal)
    /// ```
    ///
    /// **Validates: Requirements 9.3, 2.4, 5.2**
    func updateCustomMeal(_ meal: CustomMeal) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Update the lastUsedAt timestamp
            meal.lastUsedAt = Date()
            
            // Update locally
            try await dataStore.updateCustomMeal(meal)
            
            // Sync to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                meal.userId = userId
                meal.lastModified = Date()
                meal.syncStatus = .pendingUpload
                
                do {
                    try await syncEngine.syncCustomMeal(meal, userId: userId)
                } catch let error as SyncError {
                    // Handle sync errors gracefully - local data is already updated
                    print("⚠️ Sync error while updating custom meal: \(error.localizedDescription)")
                    // Don't throw - the meal was updated locally successfully
                }
            }
            
            // Reload all meals to update UI
            await loadAllCustomMeals()
        } catch {
            errorMessage = "Unable to update custom meal. Please try again."
            throw error
        }
    }
    
    /// Deletes a custom meal and all associated ingredients
    /// Syncs deletion to cloud if authenticated
    ///
    /// Removes the custom meal from persistent storage with cascade deletion
    /// of all ingredients. Previously logged meal instances in daily logs are
    /// not affected.
    ///
    /// - Parameter meal: The custom meal to delete
    /// - Throws: SwiftData errors if delete operation fails
    ///
    /// **Usage Example:**
    /// ```swift
    /// try await manager.deleteCustomMeal(mealToDelete)
    /// // Meal and all ingredients are removed from storage
    /// ```
    ///
    /// **Validates: Requirements 2.3, 5.2 (Property 5: Cascade Deletion Completeness)**
    func deleteCustomMeal(_ meal: CustomMeal) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Delete locally
            try await dataStore.deleteCustomMeal(meal)
            
            // Sync deletion to cloud if authenticated
            if let syncEngine = syncEngine, let userId = userId {
                do {
                    try await syncEngine.deleteEntity(
                        entityId: meal.id,
                        entityType: .customMeal,
                        userId: userId
                    )
                } catch let error as SyncError {
                    // Handle sync errors gracefully - local data is already deleted
                    print("⚠️ Sync error while deleting custom meal: \(error.localizedDescription)")
                    // Don't throw - the meal was deleted locally successfully
                }
            }
            
            // Reload all meals to update UI
            await loadAllCustomMeals()
        } catch {
            errorMessage = "Unable to delete custom meal. Please try again."
            throw error
        }
    }
    
    /// Loads all custom meals from persistent storage
    ///
    /// Fetches all saved custom meals and populates the `savedMeals` array.
    /// Meals are sorted by most recently used (lastUsedAt descending).
    /// This method should be called on app launch and after any meal modifications.
    ///
    /// **Usage Example:**
    /// ```swift
    /// await manager.loadAllCustomMeals()
    /// // savedMeals array is now populated for UI display
    /// ```
    ///
    /// **Validates: Requirements 2.2, 11.1**
    func loadAllCustomMeals() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            savedMeals = try await dataStore.fetchAllCustomMeals()
        } catch {
            errorMessage = "Unable to load custom meals. Please try again."
            savedMeals = []
        }
    }
    
    // MARK: - Meal Usage
    
    /// Adds a custom meal to a daily log with optional serving size adjustment
    ///
    /// Converts each ingredient in the custom meal to a FoodItem and adds it to
    /// the specified daily log. Nutritional values are scaled by the serving multiplier.
    /// The meal's lastUsedAt timestamp is updated to track usage.
    ///
    /// **Important**: This creates independent FoodItem copies. Editing the custom meal
    /// template later will not affect these logged items (Property 6).
    ///
    /// - Parameters:
    ///   - meal: The custom meal to add
    ///   - servingMultiplier: Multiplier for serving size (e.g., 0.5 for half, 2.0 for double)
    ///   - log: The daily log to add the meal to
    /// - Returns: Array of FoodItems created from the meal's ingredients
    /// - Throws: SwiftData errors if persistence fails, or validation errors if multiplier is invalid
    ///
    /// **Usage Example:**
    /// ```swift
    /// let foodItems = try await manager.addCustomMealToLog(
    ///     meal,
    ///     servingMultiplier: 1.5,
    ///     log: todayLog
    /// )
    /// // 1.5 servings of the meal are now in todayLog
    /// ```
    ///
    /// **Validates: Requirements 3.3, 4.1, 4.3 (Property 7: Meal-to-FoodItems Conversion Completeness)**
    func addCustomMealToLog(
        _ meal: CustomMeal,
        servingMultiplier: Double,
        log: DailyLog
    ) async throws -> [FoodItem] {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        // Validate serving multiplier
        guard servingMultiplier > 0 else {
            errorMessage = "Serving size must be greater than zero."
            throw NSError(
                domain: "CustomMealManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Serving size must be greater than zero."]
            )
        }
        
        do {
            var createdFoodItems: [FoodItem] = []
            
            // Convert each ingredient to a FoodItem with adjusted serving size
            for ingredient in meal.ingredients {
                let foodItem = FoodItem(
                    name: ingredient.name,
                    calories: ingredient.calories * servingMultiplier,
                    timestamp: Date(),
                    servingSize: "\(ingredient.quantity * servingMultiplier)",
                    servingUnit: ingredient.unit,
                    source: .customMeal,
                    protein: ingredient.protein.map { $0 * servingMultiplier },
                    carbohydrates: ingredient.carbohydrates.map { $0 * servingMultiplier },
                    fats: ingredient.fats.map { $0 * servingMultiplier }
                )
                
                log.foodItems.append(foodItem)
                createdFoodItems.append(foodItem)
            }
            
            // Update the meal's lastUsedAt timestamp
            meal.lastUsedAt = Date()
            try await dataStore.updateCustomMeal(meal)
            
            // Reload meals to reflect updated lastUsedAt
            await loadAllCustomMeals()
            
            return createdFoodItems
        } catch {
            errorMessage = "Unable to add custom meal to log. Please try again."
            throw error
        }
    }
    
    // MARK: - Search and Filtering
    
    /// Searches custom meals by name with case-insensitive filtering
    ///
    /// Returns all custom meals whose names contain the search query (case-insensitive).
    /// Results are sorted by lastUsedAt in descending order (most recent first).
    /// An empty query returns all custom meals.
    ///
    /// - Parameter query: The search string to filter meal names
    /// - Returns: Array of matching custom meals sorted by lastUsedAt (descending)
    ///
    /// **Usage Example:**
    /// ```swift
    /// let results = await manager.searchCustomMeals(query: "chicken")
    /// // Returns all meals with "chicken" in the name
    /// ```
    ///
    /// **Validates: Requirements 12.1, 12.2 (Property 20: Custom Meal Search Correctness)**
    func searchCustomMeals(query: String) async -> [CustomMeal] {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            return try await dataStore.searchCustomMeals(query: query)
        } catch {
            errorMessage = "Unable to search custom meals. Please try again."
            return []
        }
    }
}
