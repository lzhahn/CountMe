//
//  ExerciseEntryView.swift
//  CountMe
//
//  View for manually entering exercise items
//

import SwiftUI

/// Manual exercise entry view that allows users to add or edit exercise items
struct ExerciseEntryView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Optional exercise item to edit (nil for new entry)
    var editingItem: ExerciseItem?
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Exercise type selection
    @State private var selectedType: ExerciseType = .walking
    
    /// Exercise intensity selection
    @State private var selectedIntensity: ExerciseIntensity = .moderate
    
    /// Duration input (minutes)
    @State private var durationText: String = ""
    
    /// Optional custom label input
    @State private var customLabel: String = ""
    
    /// Optional notes input
    @State private var notes: String = ""
    
    /// User body weight for calorie estimation (kg)
    @AppStorage("exerciseBodyWeightKg") private var bodyWeightKg: Double = 70
    @AppStorage("exerciseBodyWeightUnit") private var bodyWeightUnit: String = "kg"
    
    /// Validation error message
    @State private var validationError: String?
    
    /// Saving state
    @State private var isSaving: Bool = false
    
    /// Focus state for text fields
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name
        case duration
        case notes
    }
    
    // MARK: - Initialization
    
    init(tracker: CalorieTracker, editingItem: ExerciseItem? = nil) {
        self.tracker = tracker
        self.editingItem = editingItem
        
        if let item = editingItem {
            _selectedType = State(initialValue: item.exerciseType)
            _selectedIntensity = State(initialValue: item.intensity)
            _durationText = State(initialValue: item.durationMinutes.map { String(format: "%.0f", $0) } ?? "")
            _customLabel = State(initialValue: item.name)
            _notes = State(initialValue: item.notes ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Exercise Type", selection: $selectedType) {
                        ForEach(ExerciseType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Picker("Intensity", selection: $selectedIntensity) {
                        ForEach(ExerciseIntensity.allCases) { intensity in
                            Text(intensity.displayName)
                                .tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Required Information")
                } footer: {
                    Text("Select the exercise type and intensity")
                }
                
                Section {
                    HStack {
                        TextField("Duration", text: $durationText)
                            .focused($focusedField, equals: .duration)
                            .keyboardType(.decimalPad)
                        
                        Text("minutes")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Time")
                } footer: {
                    Text("Calories are estimated from duration and intensity")
                }
                
                Section {
                    HStack {
                        TextField("Body Weight", value: weightBinding, format: .number)
                            .keyboardType(.decimalPad)
                        
                        Text(bodyWeightUnit)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Estimated Calories")
                        Spacer()
                        Text("\(Int(estimatedCalories)) kcal")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Spacer()
                        Text("≈ \(conversionLabel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Estimation")
                }
                
                Section {
                    TextField("Label (optional)", text: $customLabel)
                        .focused($focusedField, equals: .name)
                        .autocorrectionDisabled()
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    Text("Optional Details")
                }
                
                if let error = validationError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle(editingItem == nil ? "Add Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveExercise() {
        validationError = nil
        
        let trimmedDuration = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDuration.isEmpty, let minutes = Double(trimmedDuration), minutes > 0 else {
            validationError = "Please enter a valid duration."
            return
        }
        
        guard bodyWeightKg > 0 else {
            validationError = "Please enter a valid body weight."
            return
        }
        
        let calories = ExerciseCalorieEstimator.calories(
            for: selectedType,
            intensity: selectedIntensity,
            weightKg: bodyWeightKg,
            durationMinutes: minutes
        )
        
        let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = label.isEmpty ? selectedType.displayName : label
        
        isSaving = true
        
        if let item = editingItem {
            item.name = name
            item.caloriesBurned = calories
            item.durationMinutes = minutes
            item.exerciseTypeRaw = selectedType.rawValue
            item.intensityRaw = selectedIntensity.rawValue
            item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            item.timestamp = Date()
            
            Task {
                try? await tracker.updateExerciseItem(item)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            }
        } else {
            do {
                let newItem = try ExerciseItem(
                    name: name,
                    caloriesBurned: calories,
                    durationMinutes: minutes,
                    exerciseType: selectedType,
                    intensity: selectedIntensity,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                Task {
                    try? await tracker.addExerciseItem(newItem)
                    await MainActor.run {
                        isSaving = false
                        dismiss()
                    }
                }
            } catch let error as ValidationError {
                // Handle validation error synchronously
                isSaving = false
                validationError = error.localizedDescription
            } catch {
                // Validation error - should not happen with UI constraints
                print("Failed to create exercise item: \(error)")
                isSaving = false
            }
        }
    }
    
    private var estimatedCalories: Double {
        guard let minutes = Double(durationText), minutes > 0, bodyWeightKg > 0 else {
            return 0
        }
        
        return ExerciseCalorieEstimator.calories(
            for: selectedType,
            intensity: selectedIntensity,
            weightKg: bodyWeightKg,
            durationMinutes: minutes
        )
    }
    
    private var weightBinding: Binding<Double> {
        Binding(
            get: {
                bodyWeightUnit == "kg" ? bodyWeightKg : bodyWeightKg * 2.20462
            },
            set: { newValue in
                if bodyWeightUnit == "kg" {
                    bodyWeightKg = max(newValue, 0)
                } else {
                    bodyWeightKg = max(newValue / 2.20462, 0)
                }
            }
        )
    }
    
    private var conversionLabel: String {
        if bodyWeightUnit == "kg" {
            let lb = bodyWeightKg * 2.20462
            return String(format: "%.1f lb", lb)
        }
        
        return String(format: "%.1f kg", bodyWeightKg)
    }
}
