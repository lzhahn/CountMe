//
//  SearchResultRow.swift
//  CountMe
//
//  Row component for displaying a nutrition search result
//

import SwiftUI

/// A row view component that displays a nutrition search result
///
/// This view shows:
/// - Food name
/// - Calorie count
/// - Brand name (if available)
/// - Tap gesture to select item
///
/// Requirements: 2.2
struct SearchResultRow: View {
    /// The search result to display
    let result: NutritionSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Food icon
            Image(systemName: "fork.knife.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40)
            
            // Food details
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if let brandName = result.brandName {
                        Text(brandName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if result.brandName != nil,
                       result.servingSize != nil || result.servingUnit != nil {
                        Text("•")
                            .foregroundColor(.secondary)
                    }
                    
                    if let servingSize = result.servingSize,
                       let servingUnit = result.servingUnit {
                        Text("\(servingSize) \(servingUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Calorie count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(result.calories))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    List {
        SearchResultRow(
            result: NutritionSearchResult(
                id: "1",
                name: "Chicken Breast",
                calories: 165,
                servingSize: "100",
                servingUnit: "g",
                brandName: "Generic"
            )
        )
        
        SearchResultRow(
            result: NutritionSearchResult(
                id: "2",
                name: "Apple",
                calories: 95,
                servingSize: "1",
                servingUnit: "medium",
                brandName: nil
            )
        )
        
        SearchResultRow(
            result: NutritionSearchResult(
                id: "3",
                name: "Protein Bar",
                calories: 200,
                servingSize: "1",
                servingUnit: "bar",
                brandName: "Quest"
            )
        )
    }
}
