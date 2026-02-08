//
//  ProfileView.swift
//  CountMe
//
//  User profile view displaying account information and management options
//

import SwiftUI
import FirebaseAuth

/// Profile view for authenticated users
///
/// This view:
/// - Displays the authenticated user's email address
/// - Provides sign-out functionality
/// - Provides account deletion with confirmation dialog
/// - Handles async operations with loading states
///
/// Requirements: 14.1, 3.1, 14.2
struct ProfileView: View {
    @ObservedObject var authService: FirebaseAuthService
    let syncEngine: FirebaseSyncEngine?
    let dataStore: DataStore?
    
    @AppStorage("exerciseBodyWeightKg") private var bodyWeightKg: Double = 70
    @AppStorage("exerciseBodyWeightUnit") private var bodyWeightUnit: String = "kg"
    @AppStorage("weightLossLbsPerWeek") private var weightLossLbsPerWeek: Double = 1.0
    
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var isSigningOut = false
    @State private var deletionError: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Account Information Section
                accountInfoSection
                
                // Exercise settings
                exerciseSettingsSection
                
                // Goals
                goalsSection
                
                // Account Actions Section
                accountActionsSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .disabled(isDeletingAccount || isSigningOut)
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                deleteAccountAlert
            } message: {
                deleteAccountMessage
            }
            .alert("Deletion Error", isPresented: .constant(deletionError != nil)) {
                Button("OK") {
                    deletionError = nil
                }
            } message: {
                if let error = deletionError {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Account Information Section
    
    /// Section displaying user account information
    private var accountInfoSection: some View {
        Section {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(authService.currentUser?.email ?? "Unknown")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .padding(.leading, 8)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Account Information")
        }
    }
    
    // MARK: - Exercise Settings Section
    
    private var exerciseSettingsSection: some View {
        Section {
            Picker("Unit", selection: $bodyWeightUnit) {
                Text("kg").tag("kg")
                Text("lb").tag("lb")
            }
            .pickerStyle(.segmented)
            
            HStack {
                Text("Body Weight")
                Spacer()
                TextField(bodyWeightUnit, value: weightBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(bodyWeightUnit)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                Text("≈ \(conversionLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Exercise Estimation")
        } footer: {
            Text("Used to estimate calories burned from exercise duration and intensity.")
                .font(.caption)
        }
    }
    
    // MARK: - Goals Section
    
    private var goalsSection: some View {
        Section {
            HStack {
                Text("Weight Loss Rate")
                Spacer()
                TextField("lb/week", value: $weightLossLbsPerWeek, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("lb/wk")
                    .foregroundColor(.secondary)
            }
            
            if bodyWeightKg > 0 {
                HStack {
                    Text("Estimated Maintenance")
                    Spacer()
                    Text("\(Int(estimatedMaintenanceCalories)) kcal")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Daily Deficit")
                    Spacer()
                    Text("\(Int(dailyCalorieDeficit)) kcal")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Suggested Goal")
                    Spacer()
                    Text("\(Int(suggestedDailyCalories)) kcal")
                        .fontWeight(.semibold)
                }
            }
        } header: {
            Text("Goals")
        } footer: {
            Text("Estimates use body weight and a standard maintenance formula. Adjust as needed for your activity level and results.")
                .font(.caption)
        }
    }
    
    private var estimatedMaintenanceCalories: Double {
        let weightLb = bodyWeightKg * 2.20462
        return max(weightLb * 14.0, 0)
    }
    
    private var dailyCalorieDeficit: Double {
        max(weightLossLbsPerWeek, 0) * 3500.0 / 7.0
    }
    
    private var suggestedDailyCalories: Double {
        max(estimatedMaintenanceCalories - dailyCalorieDeficit, 0)
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
    
    // MARK: - Account Actions Section
    
    /// Section containing account management actions
    private var accountActionsSection: some View {
        Section {
            // Sign Out Button
            signOutButton
            
            // Delete Account Button
            deleteAccountButton
        } header: {
            Text("Account Actions")
        } footer: {
            Text("Deleting your account will permanently remove all your data from the cloud. This action cannot be undone.")
                .font(.caption)
        }
    }
    
    // MARK: - Sign Out Button
    
    /// Button to sign out the current user
    private var signOutButton: some View {
        Button {
            Task {
                await performSignOut()
            }
        } label: {
            HStack {
                if isSigningOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Signing Out...")
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
            }
        }
        .disabled(isSigningOut || isDeletingAccount)
    }
    
    // MARK: - Delete Account Button
    
    /// Button to delete the current user's account
    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                if isDeletingAccount {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Deleting Account...")
                } else {
                    Image(systemName: "trash")
                    Text("Delete Account")
                }
            }
        }
        .disabled(isSigningOut || isDeletingAccount)
    }
    
    // MARK: - Delete Account Alert
    
    /// Alert buttons for account deletion confirmation
    private var deleteAccountAlert: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete", role: .destructive) {
                Task {
                    await performDeleteAccount()
                }
            }
        }
    }
    
    /// Alert message for account deletion confirmation
    private var deleteAccountMessage: some View {
        Text("Are you sure you want to delete your account? This will permanently remove all your data from the cloud and sign you out. This action cannot be undone.")
    }
    
    // MARK: - Actions
    
    /// Performs sign-out operation
    private func performSignOut() async {
        isSigningOut = true
        
        do {
            try authService.signOut()
            // Success - authService will update authState automatically
            // AuthenticationView will handle navigation to sign-in screen
            print("✅ Sign out successful")
        } catch {
            // Error is already set in authService.errorMessage
            print("❌ Sign out failed: \(error.localizedDescription)")
            isSigningOut = false
        }
    }
    
    /// Performs account deletion operation
    private func performDeleteAccount() async {
        isDeletingAccount = true
        deletionError = nil
        
        // Check if we have the required dependencies
        guard let syncEngine = syncEngine, let dataStore = dataStore else {
            print("⚠️ Missing dependencies for account deletion - using basic deletion")
            
            // Fall back to basic account deletion without data cleanup
            do {
                try await authService.deleteAccount()
                print("✅ Account deletion successful (basic)")
            } catch {
                print("❌ Account deletion failed: \(error.localizedDescription)")
                deletionError = error.localizedDescription
                isDeletingAccount = false
            }
            return
        }
        
        // Perform full account deletion with data cleanup
        do {
            try await authService.deleteAccountWithCleanup(
                syncEngine: syncEngine,
                dataStore: dataStore
            )
            // Success - authService will update authState automatically
            // AuthenticationView will handle navigation to sign-in screen
            print("✅ Account deletion successful (with cleanup)")
        } catch {
            // Error is already set in authService.errorMessage
            print("❌ Account deletion failed: \(error.localizedDescription)")
            deletionError = error.localizedDescription
            isDeletingAccount = false
        }
    }
}

#Preview("Profile View") {
    ProfileView(
        authService: FirebaseAuthService(),
        syncEngine: nil,
        dataStore: nil
    )
}
