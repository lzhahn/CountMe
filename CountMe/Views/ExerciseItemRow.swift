//
//  ExerciseItemRow.swift
//  CountMe
//
//  Row component for displaying a single exercise item in a list
//

import SwiftUI

/// A row view component that displays an exercise item with its details
struct ExerciseItemRow: View {
    /// The exercise item to display
    let item: ExerciseItem
    
    /// Callback when the item should be deleted
    let onDelete: () -> Void
    
    /// Callback when the item should be edited
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: item.exerciseType.icon)
                    .font(.title2)
                    .foregroundColor(.green)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(relativeTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let minutes = item.durationMinutes {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(Int(minutes)) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item.intensity.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let notes = item.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.caloriesBurned))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var relativeTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(item.timestamp)
        
        if interval < 60 {
            return "Just now"
        }
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        
        let days = Int(interval / 86400)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
