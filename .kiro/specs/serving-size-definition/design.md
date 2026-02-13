# Design Document: Serving Size UI Enhancement

## Overview

This feature adds user-facing UI for the existing `servingsCount` field in CustomMeal. Currently, this field exists but defaults to 1.0 and has no UI for users to set or view it. This enhancement allows users to specify serving counts during meal creation and displays per-serving nutrition throughout the app.

**Key Design Principle:** Leverage existing infrastructure. The `servingsCount` field and `servingMultiplier` parameter already exist and work correctly. We only need to add UI.

**Related Documentation:**
- [Requirements Document](requirements.md) - User stories and acceptance criteria
- [Tasks Document](tasks.md) - Implementation plan

## Architecture

### Current State (Already Implemented)

```swift
@Model
class CustomMeal {
    var servingsCount: Double  // Already exists, defaults to 1.0
    
    var totalCalories: Double { /* already computed */ }
    var totalProtein: Double { /* already computed */ }
    var totalCarbohydrates: Double { /* already computed */ }
    var totalFats: Double { /* already computed */ }
}

// Already works correctly
func addCustomMealToLog(
    _ meal: CustomMeal,
    servingMultiplier: Double,  // Already accepts multiplier
    log: DailyLog
) async throws -> [FoodItem]
```

### What We're Adding

**UI Components Only:**
1. Input field for servingsCount during meal creation
2. Per-serving nutrition display in meal detail view
3. Per-serving nutrition display in meal library
4. Better "servings" UI when adding to log (instead of generic "multiplier")

**No Model Changes Required** - CustomMeal already has everything we need.

## Components and Interfaces

### New Computed Properties (Extension)

```swift
extension CustomMeal {
    /// Per-serving nutrition (only if servingsCount > 1)
    var perServingCalories: Double? {
        guard servingsCount > 1 else { return nil }
        return totalCalories / servingsCount
    }
    
    var perServingProtein: Double? {
        guard servingsCount > 1 else { return nil }
        return totalProtein / servingsCount
    }
    
    var perServingCarbohydrates: Double? {
        guard servingsCount > 1 else { return nil }
        return totalCarbohydrates / servingsCount
    }
    
    var perServingFats: Double? {
        guard servingsCount > 1 else { return nil }
        return totalFats / servingsCount
    }
    
    /// Check if meal has multiple servings defined
    var hasMultipleServings: Bool {
        servingsCount > 1
    }
}
```

### Modified View Components

**IngredientReviewView (Add Serving Count Input)**
```swift
// Add after ingredient list, before save button:
VStack(alignment: .leading, spacing: 8) {
    Text("Serving Information (Optional)")
        .font(.headline)
    
    HStack {
        Text("This recipe makes")
        TextField("1", text: $servingCountText)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
        Text("servings")
    }
    
    if let error = servingCountError {
        Text(error)
            .foregroundColor(.red)
            .font(.caption)
    }
}
```

**CustomMealDetailView (Add Per-Serving Section)**
```swift
// Add serving information section
if meal.hasMultipleServings {
    Section("Serving Information") {
        Text("Makes \(Int(meal.servingsCount)) servings")
            .font(.subheadline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Per Serving:")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let perServingCal = meal.perServingCalories {
                HStack {
                    Text("Calories")
                    Spacer()
                    Text(String(format: "%.0f", perServingCal))
                }
            }
            
            if let protein = meal.perServingProtein {
                HStack {
                    Text("Protein")
                    Spacer()
                    Text(String(format: "%.1f g", protein))
                }
            }
            
            // Similar for carbs and fats
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// Always show total recipe nutrition
Section("Total Recipe") {
    // Existing total nutrition display
}
```

**CustomMealsLibraryView (Add Serving Info to Rows)**
```swift
func mealRow(for meal: CustomMeal) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(meal.name)
            .font(.headline)
        
        if meal.hasMultipleServings {
            Text("Makes \(Int(meal.servingsCount)) servings")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let perServing = meal.perServingCalories {
                Text("\(Int(perServing)) cal/serving • \(Int(meal.totalCalories)) cal total")
                    .font(.subheadline)
            }
        } else {
            Text("\(Int(meal.totalCalories)) cal")
                .font(.subheadline)
        }
    }
}
```

**ServingAdjustmentView (Improve Existing UI)**
```swift
// Change from generic "multiplier" to "servings"
struct ServingAdjustmentView: View {
    let meal: CustomMeal
    @Binding var servingCount: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How many servings?")
                .font(.headline)
            
            HStack {
                Stepper("", value: $servingCount, in: 0.5...20, step: 0.5)
                    .labelsHidden()
                
                TextField("Servings", text: $servingCountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                Text("servings")
            }
            
            // Show per-serving nutrition if available
            if meal.hasMultipleServings, let perServing = meal.perServingCalories {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Per Serving:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(perServing)) cal")
                    // Show protein, carbs, fats if available
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Show total consumed
            VStack(alignment: .leading, spacing: 8) {
                Text("Total (\(String(format: "%.1f", servingCount)) servings):")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                let totalConsumed = meal.totalCalories / meal.servingsCount * servingCount
                Text("\(Int(totalConsumed)) cal")
                // Show protein, carbs, fats if available
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
```

### Modified Business Logic

**CustomMealManager (Update saveCustomMeal)**
```swift
// Add servingsCount parameter
func saveCustomMeal(
    name: String, 
    ingredients: [Ingredient],
    servingsCount: Double = 1.0  // NEW parameter
) async throws -> CustomMeal {
    // Validate servingsCount
    guard servingsCount > 0 else {
        throw ValidationError.invalidServingCount
    }
    
    let meal = CustomMeal(
        name: name,
        ingredients: ingredients,
        servingsCount: servingsCount  // Pass to initializer
    )
    
    // Rest of existing save logic...
}
```

## Data Flow

### Meal Creation Flow
```
User inputs recipe → AI parses ingredients → IngredientReviewView
                                                    ↓
                                    User enters "Makes 4 servings"
                                                    ↓
                                    Save with servingsCount = 4.0
                                                    ↓
                                    CustomMeal stored with servingsCount
```

### Add to Log Flow
```
User selects meal → CustomMealDetailView shows per-serving nutrition
                                    ↓
                    User taps "Add to Today"
                                    ↓
                    ServingAdjustmentView: "How many servings?"
                                    ↓
                    User enters 1.5 servings
                                    ↓
                    Calls addCustomMealToLog(meal, servingMultiplier: 1.5)
                                    ↓
                    Creates FoodItems with nutrition × 1.5
```

## Validation

```swift
enum ValidationError: Error, LocalizedError {
    case invalidServingCount
    
    var errorDescription: String? {
        switch self {
        case .invalidServingCount:
            return "Serving count must be a positive number greater than zero"
        }
    }
}

func validateServingCount(_ count: Double) throws {
    guard count > 0 else {
        throw ValidationError.invalidServingCount
    }
}
```

## Calculations

**Per-Serving Nutrition:**
```swift
perServingCalories = totalCalories / servingsCount
perServingProtein = totalProtein / servingsCount
perServingCarbohydrates = totalCarbohydrates / servingsCount
perServingFats = totalFats / servingsCount
```

**Consumed Nutrition (when adding to log):**
```swift
// User says they ate 1.5 servings of a meal that makes 4 servings
consumedCalories = (totalCalories / servingsCount) × servingsConsumed
consumedCalories = (totalCalories / 4.0) × 1.5

// This is equivalent to the existing servingMultiplier calculation:
consumedCalories = totalCalories × (1.5 / 4.0)
consumedCalories = totalCalories × 0.375
```

**Key Insight:** The existing `servingMultiplier` parameter already does the right math. We just need to present it better in the UI.

## Testing Strategy

### Unit Tests
- Test per-serving calculation with various servingsCount values
- Test validation of serving count input
- Test backward compatibility (servingsCount = 1.0)
- Test UI state updates when servingsCount changes

### Property Tests (Optional)
- Property: Per-serving nutrition × servingsCount = total nutrition
- Property: Consumed nutrition = (total / servingsCount) × servingsConsumed
- Property: servingsCount > 0 always holds for saved meals

### Manual Testing
1. Create meal with "Makes 4 servings" → verify per-serving display
2. Add meal with 1.5 servings → verify correct nutrition in log
3. Edit meal servingsCount → verify recalculation
4. Load existing meals → verify backward compatibility

## Error Handling

**Invalid Serving Count:**
- Display inline error: "Serving count must be a positive number"
- Prevent save until valid
- Highlight field in red

**Division by Zero:**
- Should never occur (validation prevents servingsCount ≤ 0)
- Guard clauses in computed properties return nil if servingsCount ≤ 0

## Backward Compatibility

**Existing Meals:**
- All existing CustomMeals have servingsCount = 1.0 (default)
- Per-serving display only shows when servingsCount > 1
- No migration required
- No breaking changes to existing functionality

## UI/UX Considerations

**When to Show Per-Serving:**
- Only show per-serving section when servingsCount > 1
- When servingsCount = 1, showing "per serving" is redundant
- Always show total recipe nutrition

**Number Formatting:**
- Serving counts: Remove unnecessary decimals (4 not 4.0)
- Calories: Round to whole numbers
- Macros: Round to 1 decimal place

**Default Values:**
- servingsCount defaults to 1.0 (entire recipe)
- User can skip serving input (optional)
- When adding to log, default to 1.0 servings
