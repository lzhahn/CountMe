//
//  CustomMealMethodPickerView.swift
//  CountMe
//
//  Picker view for choosing between AI parsing and manual entry when creating custom meals
//

import SwiftUI
import SwiftData

/// Presents a choice between AI-powered recipe parsing and manual ingredient entry
///
/// This view is the entry point for creating custom meals. Users select their preferred
/// method before proceeding to the appropriate input flow.
///
/// Requirements: 1.1, 2.3
struct CustomMealMethodPickerView: View {
    /// The custom meal manager business logic
    @Bindable var manager: CustomMealManager

    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss

    /// Optional API client for ingredient search in manual entry
    var apiClient: NutritionAPIClient?

    /// Callback to dismiss the entire sheet stack and optionally show a meal detail
    var onDismiss: ((CustomMeal?) -> Void)? = nil

    /// Controls navigation to AI recipe input
    @State private var showingAIInput: Bool = false

    /// Controls navigation to manual ingredient entry
    @State private var showingManualEntry: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)

                    Text("Create Custom Meal")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("How would you like to add your meal?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Method options
                VStack(spacing: 16) {
                    // AI Parse option
                    Button {
                        showingAIInput = true
                    } label: {
                        methodCard(
                            icon: "sparkles",
                            iconColor: .orange,
                            title: "AI Recipe Parser",
                            description: "Describe your meal in plain text and AI will break it down into ingredients with nutrition info."
                        )
                    }
                    .buttonStyle(.plain)

                    // Manual entry option
                    Button {
                        showingManualEntry = true
                    } label: {
                        methodCard(
                            icon: "pencil.circle.fill",
                            iconColor: .green,
                            title: "Manual Entry",
                            description: "Add each ingredient yourself with custom quantities and nutritional values."
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                Spacer()
                Spacer()
            }
            .navigationTitle("New Custom Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAIInput) {
                RecipeInputView(
                    manager: manager,
                    onDismiss: { savedMeal in
                        onDismiss?(savedMeal)
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualIngredientEntryView(
                    manager: manager,
                    apiClient: apiClient,
                    onDismiss: { savedMeal in
                        onDismiss?(savedMeal)
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Components

    /// Card view for a method option
    private func methodCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(iconColor)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
