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
/// - Swipe-to-delete action
/// - Tap gesture for editing
///
/// Requirements: 5.1, 5.2
struct FoodItemRow: View {
    /// The food item to display
    let item: FoodItem
    
    /// Callback when the item should be deleted
    let onDelete: () -> Void
    
    /// Callback when the item should be edited
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
}

// MARK: - Preview

#Preview {
    List {
        FoodItemRow(
            item: FoodItem(
                name: "Chicken Breast",
                calories: 165,
                timestamp: Date().addingTimeInterval(-3600),
                servingSize: "100",
                servingUnit: "g",
                source: .api
            ),
            onDelete: {},
            onEdit: {}
        )
        
        FoodItemRow(
            item: FoodItem(
                name: "Apple",
                calories: 95,
                timestamp: Date().addingTimeInterval(-120),
                source: .manual
            ),
            onDelete: {},
            onEdit: {}
        )
        
        FoodItemRow(
            item: FoodItem(
                name: "Oatmeal",
                calories: 150,
                timestamp: Date().addingTimeInterval(-7200),
                servingSize: "1",
                servingUnit: "cup",
                source: .manual
            ),
            onDelete: {},
            onEdit: {}
        )
    }
}
