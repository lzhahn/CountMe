//
//  ExerciseTrackerView.swift
//  CountMe
//
//  View for displaying and managing exercise items for the current day
//

import SwiftUI

struct ExerciseTrackerView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Controls navigation to exercise entry
    @State private var showingExerciseEntry = false
    
    /// The exercise item currently being edited
    @State private var editingItem: ExerciseItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                summaryCard
                
                exerciseList
                
                Spacer()
            }
            .padding()
            .navigationTitle("Exercise")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExerciseEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingExerciseEntry) {
                ExerciseEntryView(tracker: tracker)
            }
            .sheet(item: $editingItem) { item in
                ExerciseEntryView(tracker: tracker, editingItem: item)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var summaryCard: some View {
        VStack(spacing: 8) {
            Text("Total Burned Today")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(Int(totalCaloriesBurned))")
                .font(.system(size: 36, weight: .bold))
            
            Text("kcal")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if totalMinutes > 0 {
                Text("\(Int(totalMinutes)) min total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Exercise")
                .font(.headline)
            
            if !tracker.exerciseItemsCache.isEmpty {
                List {
                    ForEach(sortedItems, id: \.id) { item in
                        ExerciseItemRow(
                            item: item,
                            onDelete: {
                                Task {
                                    try? await tracker.removeExerciseItem(item)
                                }
                            },
                            onEdit: {
                                editingItem = item
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    try? await tracker.removeExerciseItem(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No exercise logged yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
    
    private var sortedItems: [ExerciseItem] {
        tracker.exerciseItemsCache
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private var totalCaloriesBurned: Double {
        tracker.currentLog?.totalExerciseCalories ?? 0
    }
    
    private var totalMinutes: Double {
        tracker.exerciseItemsCache
            .reduce(0) { $0 + ($1.durationMinutes ?? 0) }
    }
}
