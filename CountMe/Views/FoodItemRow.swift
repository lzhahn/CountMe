//
//  FoodItemRow.swift
//  CountMe
//
//  Row component for displaying a single food item in a list
//

import SwiftUI

/// A row view component that displays a food item with its details
///
/// This view shows:
/// - Food name
/// - Calorie count
/// - Timestamp formatted as relative time
/// - Swipe-to-delete action (disabled in selection mode)
/// - Tap gesture for editing (disabled in selection mode)
///
/// Requirements: 5.1, 5.2, 14.1, 14.2
struct FoodItemRow: View {
    /// The food item to display
    let item: FoodItem
    
    /// Callback when the item should be deleted
    let onDelete: () -> Void
    
    /// Callback when the item should be edited
    let onEdit: () -> Void
    
    /// Whether the row is in selection mode (disables edit/delete actions)
    var isSelectionMode: Bool = false
    
    var body: some View {
        Button(action: isSelectionMode ? {} : onEdit) {
            HStack(spacing: 12) {
                // Food icon
                Image(systemName: foodIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                // Food details
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(relativeTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let servingSize = item.servingSize,
                           let servingUnit = item.servingUnit {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(servingSize) \(servingUnit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Macro information if available
                    if hasMacros {
                        HStack(spacing: 8) {
                            if let protein = item.protein {
                                macroLabel(value: protein, label: "P", color: .blue)
                            }
                            if let carbs = item.carbohydrates {
                                macroLabel(value: carbs, label: "C", color: .green)
                            }
                            if let fats = item.fats {
                                macroLabel(value: fats, label: "F", color: .orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Calorie count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.calories))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSelectionMode)
    }
    
    // MARK: - Computed Properties
    
    /// Icon to display based on food source
    private var foodIcon: String {
        switch item.source {
        case .api:
            return "network"
        case .manual:
            return "pencil.circle.fill"
        case .customMeal:
            return "fork.knife.circle.fill"
        }
    }
    
    /// Whether the item has any macro information
    private var hasMacros: Bool {
        item.protein != nil || item.carbohydrates != nil || item.fats != nil
    }
    
    /// Relative timestamp string (e.g., "2 hours ago", "Just now")
    private var relativeTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(item.timestamp)
        
        // Just now (less than 1 minute)
        if interval < 60 {
            return "Just now"
        }
        
        // Minutes ago
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
        
        // Hours ago
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        
        // Days ago
        let days = Int(interval / 86400)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
    
    // MARK: - Helper Views
    
    /// Creates a compact macro label with value and abbreviation
    private func macroLabel(value: Double, label: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    List {
        FoodItemRow(
            item: try! FoodItem(
                name: "Chicken Breast",
                calories: 165,
                timestamp: Date().addingTimeInterval(-3600),
                servingSize: "100",
                servingUnit: "g",
                source: .api,
                protein: 31,
                carbohydrates: 0,
                fats: 3.6
            ),
            onDelete: {},
            onEdit: {}
        )
        
        FoodItemRow(
            item: try! FoodItem(
                name: "Apple",
                calories: 95,
                timestamp: Date().addingTimeInterval(-120),
                source: .manual
            ),
            onDelete: {},
            onEdit: {}
        )
        
        FoodItemRow(
            item: try! FoodItem(
                name: "Chicken Stir Fry",
                calories: 424,
                timestamp: Date().addingTimeInterval(-7200),
                servingSize: "1",
                servingUnit: "serving",
                source: .customMeal,
                protein: 41.5,
                carbohydrates: 51,
                fats: 4.7
            ),
            onDelete: {},
            onEdit: {}
        )
    }
}
