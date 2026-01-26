//
//  MacroDisplayView.swift
//  CountMe
//
//  Created by Kiro on 1/21/26.
//

import SwiftUI

/// A reusable component that displays macronutrient breakdown visually
///
/// This view presents protein, carbohydrates, and fats in a color-coded horizontal bar chart
/// with numeric values and optional goal tracking. The component handles nil macro values
/// gracefully by treating them as zero.
///
/// **Visual Design:**
/// - Horizontal bar chart with proportional segments
/// - Color coding: Blue (protein), Green (carbs), Orange (fats)
/// - Numeric values displayed with units (grams)
/// - Optional percentage of daily goals
///
/// **Usage Examples:**
///
/// Basic usage without goals:
/// ```swift
/// MacroDisplayView(
///     protein: 45.0,
///     carbohydrates: 120.0,
///     fats: 30.0
/// )
/// ```
///
/// With daily goals:
/// ```swift
/// MacroDisplayView(
///     protein: 45.0,
///     carbohydrates: 120.0,
///     fats: 30.0,
///     proteinGoal: 150.0,
///     carbsGoal: 200.0,
///     fatsGoal: 65.0
/// )
/// ```
///
/// With nil values (treated as zero):
/// ```swift
/// MacroDisplayView(
///     protein: 45.0,
///     carbohydrates: nil,  // Treated as 0
///     fats: 30.0
/// )
/// ```
///
/// **Validates: Requirements 5.1, 5.2, 5.3**
struct MacroDisplayView: View {
    // MARK: - Properties
    
    /// Protein consumed in grams (nil treated as 0)
    let protein: Double?
    
    /// Carbohydrates consumed in grams (nil treated as 0)
    let carbohydrates: Double?
    
    /// Fats consumed in grams (nil treated as 0)
    let fats: Double?
    
    /// Optional daily protein goal in grams
    let proteinGoal: Double?
    
    /// Optional daily carbohydrates goal in grams
    let carbsGoal: Double?
    
    /// Optional daily fats goal in grams
    let fatsGoal: Double?
    
    // MARK: - Computed Properties
    
    /// Protein value treating nil as zero
    var proteinValue: Double {
        protein ?? 0
    }
    
    /// Carbohydrates value treating nil as zero
    var carbsValue: Double {
        carbohydrates ?? 0
    }
    
    /// Fats value treating nil as zero
    var fatsValue: Double {
        fats ?? 0
    }
    
    /// Total macros in grams (for proportional bar chart)
    var totalMacros: Double {
        proteinValue + carbsValue + fatsValue
    }
    
    /// Whether any macro goals are set
    var hasGoals: Bool {
        proteinGoal != nil || carbsGoal != nil || fatsGoal != nil
    }
    
    // MARK: - Initialization
    
    /// Creates a macro display view with optional goals
    ///
    /// - Parameters:
    ///   - protein: Protein consumed in grams (nil treated as 0)
    ///   - carbohydrates: Carbohydrates consumed in grams (nil treated as 0)
    ///   - fats: Fats consumed in grams (nil treated as 0)
    ///   - proteinGoal: Optional daily protein goal in grams
    ///   - carbsGoal: Optional daily carbohydrates goal in grams
    ///   - fatsGoal: Optional daily fats goal in grams
    init(
        protein: Double?,
        carbohydrates: Double?,
        fats: Double?,
        proteinGoal: Double? = nil,
        carbsGoal: Double? = nil,
        fatsGoal: Double? = nil
    ) {
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fats = fats
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatsGoal = fatsGoal
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text("Macronutrients")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Horizontal bar chart
            if totalMacros > 0 {
                macroBarChart
            } else {
                Text("No macro data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Macro breakdown with values
            VStack(spacing: 8) {
                macroRow(
                    label: "Protein",
                    value: proteinValue,
                    goal: proteinGoal,
                    color: .blue
                )
                
                macroRow(
                    label: "Carbs",
                    value: carbsValue,
                    goal: carbsGoal,
                    color: .green
                )
                
                macroRow(
                    label: "Fats",
                    value: fatsValue,
                    goal: fatsGoal,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Subviews
    
    /// Horizontal bar chart showing proportional macro distribution
    private var macroBarChart: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Protein segment
                if proteinValue > 0 {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (proteinValue / totalMacros))
                }
                
                // Carbs segment
                if carbsValue > 0 {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * (carbsValue / totalMacros))
                }
                
                // Fats segment
                if fatsValue > 0 {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * (fatsValue / totalMacros))
                }
            }
        }
        .frame(height: 20)
        .cornerRadius(10)
    }
    
    /// Individual macro row with value, goal, and percentage
    ///
    /// - Parameters:
    ///   - label: Macro name (e.g., "Protein")
    ///   - value: Current value in grams
    ///   - goal: Optional goal value in grams
    ///   - color: Color for the indicator dot
    private func macroRow(label: String, value: Double, goal: Double?, color: Color) -> some View {
        HStack {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            // Label
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Value with unit
            Text("\(Int(value))g")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Goal percentage (if goal is set)
            if let goal = goal, goal > 0 {
                let percentage = (value / goal) * 100
                Text("(\(Int(percentage))%)")
                    .font(.caption)
                    .foregroundColor(percentage > 100 ? .red : .secondary)
            }
        }
    }
}

// MARK: - Preview Provider

#Preview("Basic Macros") {
    MacroDisplayView(
        protein: 45.0,
        carbohydrates: 120.0,
        fats: 30.0
    )
    .padding()
}

#Preview("With Goals") {
    MacroDisplayView(
        protein: 45.0,
        carbohydrates: 120.0,
        fats: 30.0,
        proteinGoal: 150.0,
        carbsGoal: 200.0,
        fatsGoal: 65.0
    )
    .padding()
}

#Preview("With Nil Values") {
    MacroDisplayView(
        protein: 45.0,
        carbohydrates: nil,
        fats: 30.0
    )
    .padding()
}

#Preview("No Macros") {
    MacroDisplayView(
        protein: nil,
        carbohydrates: nil,
        fats: nil
    )
    .padding()
}

#Preview("Over Goal") {
    MacroDisplayView(
        protein: 180.0,
        carbohydrates: 250.0,
        fats: 70.0,
        proteinGoal: 150.0,
        carbsGoal: 200.0,
        fatsGoal: 65.0
    )
    .padding()
}
