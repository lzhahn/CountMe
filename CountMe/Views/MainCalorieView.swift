//
//  MainCalorieView.swift
//  CountMe
//
//  Main view for displaying daily calorie tracking information
//

import SwiftUI
import SwiftData

/// Main calorie tracking view that displays daily totals, goals, and progress
///
/// This view shows:
/// - Daily calorie total prominently
/// - Daily goal and remaining calories
/// - Progress indicator (circular)
/// - Visual feedback when goal is exceeded
/// - Navigation to food search
/// - List of today's food items
/// - Macro breakdown (protein, carbs, fats) for daily totals
///
/// Requirements: 3.4, 4.2, 4.3, 4.4, 1.1, 5.1, 5.2
struct MainCalorieView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// The custom meal manager for browsing custom meals
    @Bindable var customMealManager: CustomMealManager
    
    /// Controls navigation to food search view
    @State private var showingFoodSearch = false
    
    /// Controls navigation to goal setting view
    @State private var showingGoalSetting = false
    
    /// The food item currently being edited
    @State private var editingItem: FoodItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Daily total and progress section
                dailyTotalSection
                
                // Macro breakdown section
                if let log = tracker.currentLog {
                    MacroDisplayView(
                        protein: log.totalProtein,
                        carbohydrates: log.totalCarbohydrates,
                        fats: log.totalFats
                    )
                }
                
                // Food items list
                foodItemsList
                
                Spacer()
            }
            .padding()
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFoodSearch = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingGoalSetting = true
                    } label: {
                        Image(systemName: "target")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(tracker: tracker, customMealManager: customMealManager)
            }
            .sheet(isPresented: $showingGoalSetting) {
                GoalSettingView(tracker: tracker)
            }
            .sheet(item: $editingItem) { item in
                // TODO: Replace with ManualEntryView when implemented
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("Edit Food Item")
                            .font(.headline)
                        
                        Text(item.name)
                            .font(.title2)
                        
                        Text("\(Int(item.calories)) calories")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Button("Close") {
                            editingItem = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// Daily total and progress indicator section
    private var dailyTotalSection: some View {
        VStack(spacing: 16) {
            // Progress circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progressPercentage)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progressPercentage)
                
                // Calorie count in center
                VStack(spacing: 4) {
                    Text("\(Int(currentTotal))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(progressColor)
                    
                    Text("calories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Goal and remaining calories
            if let goal = tracker.currentLog?.dailyGoal {
                VStack(spacing: 8) {
                    HStack {
                        Text("Goal:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(goal)) cal")
                            .fontWeight(.semibold)
                    }
                    
                    if let remaining = tracker.getRemainingCalories() {
                        HStack {
                            Text("Remaining:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(remaining)) cal")
                                .fontWeight(.semibold)
                                .foregroundColor(remaining >= 0 ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    /// List of food items for today
    private var foodItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Food")
                .font(.headline)
            
            if let items = tracker.currentLog?.foodItems, !items.isEmpty {
                List {
                    ForEach(items, id: \.id) { item in
                        FoodItemRow(
                            item: item,
                            onDelete: {
                                Task {
                                    try? await tracker.removeFoodItem(item)
                                }
                            },
                            onEdit: {
                                editingItem = item
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 400)
            } else {
                emptyStateView
            }
        }
    }
    
    /// Empty state when no food items are logged
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No food logged yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the + button to add your first meal")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Computed Properties
    
    /// Current daily total calories
    private var currentTotal: Double {
        tracker.getCurrentDailyTotal()
    }
    
    /// Progress percentage for the circular indicator (0.0 to 1.0)
    private var progressPercentage: CGFloat {
        guard let goal = tracker.currentLog?.dailyGoal, goal > 0 else {
            return 0
        }
        return min(CGFloat(currentTotal / goal), 1.0)
    }
    
    /// Color for progress indicator based on goal status
    private var progressColor: Color {
        guard let goal = tracker.currentLog?.dailyGoal else {
            return .blue
        }
        
        if currentTotal > goal {
            return .red // Goal exceeded
        } else if currentTotal >= goal * 0.9 {
            return .orange // Close to goal
        } else {
            return .green // On track
        }
    }
}

// MARK: - Preview

#Preview {
    // Create an in-memory model container for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, CustomMeal.self, Ingredient.self, configurations: config)
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let tracker = CalorieTracker(
        dataStore: dataStore,
        apiClient: NutritionAPIClient(
            consumerKey: "preview",
            consumerSecret: "preview"
        )
    )
    
    let aiParser = AIRecipeParser()
    let customMealManager = CustomMealManager(dataStore: dataStore, aiParser: aiParser)
    
    MainCalorieView(tracker: tracker, customMealManager: customMealManager)
}
