import Foundation

enum ValidationError: LocalizedError, Equatable {
    case emptyName(modelType: String)
    case negativeCalories(modelType: String, value: Double)
    case caloriesExceedMax(modelType: String, value: Double, max: Double)
    case negativeMacro(modelType: String, field: String, value: Double)
    case macroExceedMax(modelType: String, field: String, value: Double, max: Double)
    case negativeDuration(value: Double)
    case durationExceedMax(value: Double, max: Double)
    case nonPositiveQuantity(value: Double)
    case emptyUnit
    case emptyIngredients
    case nonPositiveServings(value: Double)
    case negativeGoal(value: Double)
    case goalExceedMax(value: Double, max: Double)

    var errorDescription: String? {
        switch self {
        case .emptyName(let modelType):
            return "\(modelType) name cannot be empty or whitespace-only."
        case .negativeCalories(let modelType, let value):
            return "\(modelType) calories cannot be negative (got \(value))."
        case .caloriesExceedMax(let modelType, let value, let max):
            return "\(modelType) calories \(value) exceeds maximum of \(max)."
        case .negativeMacro(let modelType, let field, let value):
            return "\(modelType) \(field) cannot be negative (got \(value))."
        case .macroExceedMax(let modelType, let field, let value, let max):
            return "\(modelType) \(field) \(value)g exceeds maximum of \(max)g."
        case .negativeDuration(let value):
            return "Duration cannot be negative (got \(value) minutes)."
        case .durationExceedMax(let value, let max):
            return "Duration \(value) minutes exceeds maximum of \(max) minutes."
        case .nonPositiveQuantity(let value):
            return "Ingredient quantity must be positive (got \(value))."
        case .emptyUnit:
            return "Ingredient unit cannot be empty or whitespace-only."
        case .emptyIngredients:
            return "CustomMeal must have at least one ingredient."
        case .nonPositiveServings(let value):
            return "Servings count must be positive (got \(value))."
        case .negativeGoal(let value):
            return "Daily goal cannot be negative (got \(value))."
        case .goalExceedMax(let value, let max):
            return "Daily goal \(value) exceeds maximum of \(max)."
        }
    }
}
