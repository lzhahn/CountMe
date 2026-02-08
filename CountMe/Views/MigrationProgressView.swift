//
//  MigrationProgressView.swift
//  CountMe
//
//  Created by Kiro on 2/2/26.
//

import SwiftUI

/// View that displays migration progress and status
///
/// This view provides visual feedback during the data migration process when a user
/// creates an account or signs in for the first time with existing local data. It shows:
/// - Progress indicator during migration
/// - Success confirmation when complete
/// - Error message with retry option on failure
/// - Detailed migration statistics (entities migrated, failed, etc.)
///
/// The view is designed to be presented as a sheet or overlay during the migration
/// process and automatically dismisses on success or allows manual retry on failure.
///
/// **Validates: Requirements 9.2, 9.5 (Migration UI Feedback)**
struct MigrationProgressView: View {
    // MARK: - Properties
    
    /// The sync engine performing the migration
    let syncEngine: FirebaseSyncEngine
    
    /// The user ID to migrate data for
    let userId: String
    
    /// Callback when migration completes successfully
    let onComplete: () -> Void
    
    /// Current migration state
    @State private var migrationState: MigrationState = .idle
    
    /// Migration result when complete
    @State private var migrationResult: FirebaseSyncEngine.MigrationResult?
    
    /// Error message if migration fails
    @State private var errorMessage: String?
    
    // MARK: - Migration State
    
    enum MigrationState {
        case idle
        case migrating
        case success
        case error
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Migrating Your Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Content based on state
            switch migrationState {
            case .idle, .migrating:
                migratingContent
                
            case .success:
                successContent
                
            case .error:
                errorContent
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .onAppear {
            startMigration()
        }
    }
    
    // MARK: - Content Views
    
    /// Content shown during migration
    private var migratingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Uploading your data to the cloud...")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("This may take a moment. Please don't close the app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    /// Content shown on successful migration
    private var successContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Migration Complete!")
                .font(.title3)
                .fontWeight(.semibold)
            
            if let result = migrationResult {
                VStack(spacing: 8) {
                    Text("Successfully migrated:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        migrationStat(count: result.foodItemsCount, label: "Food Items")
                        migrationStat(count: result.dailyLogsCount, label: "Daily Logs")
                        migrationStat(count: result.customMealsCount, label: "Custom Meals")
                    }
                }
                .padding(.vertical, 8)
            }
            
            Button(action: onComplete) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    /// Content shown on migration error
    private var errorContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Migration Error")
                .font(.title3)
                .fontWeight(.semibold)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let result = migrationResult, result.totalCount > 0 {
                VStack(spacing: 8) {
                    Text("Partial migration:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack {
                            Text("\(result.totalCount - result.failedCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Succeeded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(result.failedCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Text("Failed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            VStack(spacing: 12) {
                Button(action: retryMigration) {
                    Text("Retry Migration")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: onComplete) {
                    Text("Continue Anyway")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    /// Helper view for displaying migration statistics
    private func migrationStat(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    /// Starts the migration process
    private func startMigration() {
        migrationState = .migrating
        
        Task {
            do {
                let result = try await syncEngine.migrateLocalData(userId: userId)
                
                await MainActor.run {
                    migrationResult = result
                    
                    if result.isSuccess {
                        migrationState = .success
                    } else {
                        // Partial success - show as error with retry option
                        migrationState = .error
                        errorMessage = "Some items failed to migrate. You can retry or continue anyway."
                    }
                }
            } catch {
                await MainActor.run {
                    migrationState = .error
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Retries the migration process
    private func retryMigration() {
        migrationState = .idle
        errorMessage = nil
        migrationResult = nil
        
        // Small delay before retrying to give user visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startMigration()
        }
    }
}

// MARK: - Preview

#Preview {
    // Mock sync engine for preview
    struct PreviewWrapper: View {
        @State private var showMigration = true
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()
                
                if showMigration {
                    // Note: This preview won't actually work without a real sync engine
                    // but shows the UI layout
                    Text("Migration Preview")
                        .font(.title)
                }
            }
        }
    }
    
    return PreviewWrapper()
}
