//
//  AuthenticationView.swift
//  CountMe
//
//  Root authentication view that routes between loading, authenticated, and unauthenticated states
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

/// Root view that manages authentication state routing
///
/// This view:
/// - Observes authentication state from FirebaseAuthService
/// - Displays loading indicator during initialization
/// - Shows ContentView when user is authenticated
/// - Shows sign-in/sign-up views when user is unauthenticated
/// - Handles state transitions automatically via auth state listener
/// - Starts/stops sync listeners based on authentication state
/// - Triggers data migration on first sign-in with local data
///
/// Requirements: 12.1, 12.2, 12.3, 2.5, 3.1, 9.1
struct AuthenticationView: View {
    /// Firebase authentication service managing user state
    @EnvironmentObject var authService: FirebaseAuthService
    
    /// Firebase sync engine for cloud synchronization
    @Environment(\.syncEngine) private var syncEngine
    
    /// DataStore for local persistence
    @Environment(\.dataStore) private var dataStore
    
    /// Controls whether to show sign-up or sign-in view
    @State private var showSignUp = false
    
    /// Tracks if migration is in progress
    @State private var isMigrating = false
    
    /// Tracks if migration has been attempted for current session
    @State private var migrationAttempted = false
    
    var body: some View {
        Group {
            switch authService.authState {
            case .loading:
                // Loading state during authentication initialization
                loadingView
                
            case .authenticated(let user):
                // User is authenticated - show main app content
                if isMigrating {
                    // Show migration progress view
                    if let syncEngine = syncEngine {
                        MigrationProgressView(
                            syncEngine: syncEngine,
                            userId: user.uid,
                            onComplete: {
                                isMigrating = false
                            }
                        )
                    } else {
                        // Fallback if syncEngine is not available
                        ContentView()
                            .environmentObject(authService)
                    }
                } else {
                    ContentView()
                        .environmentObject(authService)
                        .task {
                            // Handle authentication state change
                            await handleAuthenticated(userId: user.uid)
                        }
                }
                
            case .unauthenticated:
                // User is not authenticated - show auth screens
                if showSignUp {
                    SignUpView(authService: authService, showSignUp: $showSignUp)
                } else {
                    SignInView(authService: authService, showSignUp: $showSignUp)
                }
        }
        }
        .animation(.easeInOut, value: authService.authState)
        .onChange(of: authService.authState) { oldState, newState in
            // Handle state transitions
            Task {
                await handleAuthStateChange(from: oldState, to: newState)
            }
        }
    }
    
    // MARK: - Loading View
    
    /// Loading view displayed during authentication state initialization
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Authentication State Handlers
    
    /// Handles authenticated state by starting sync listeners and triggering migration if needed
    /// - Parameter userId: The authenticated user's unique identifier
    ///
    /// Requirements: 2.5, 9.1
    private func handleAuthenticated(userId: String) async {
        guard let syncEngine = syncEngine else {
            print("⚠️ SyncEngine not available")
            return
        }
        
        // Start real-time sync listeners
        print("🔄 Starting sync listeners for user: \(userId)")
        await syncEngine.startListening(userId: userId)
        
        // Trigger migration on first sign-in if local data exists and migration not attempted
        if !migrationAttempted {
            migrationAttempted = true
            await attemptMigration(userId: userId, syncEngine: syncEngine)
        }
    }
    
    /// Attempts to migrate local data to cloud on first sign-in
    /// - Parameters:
    ///   - userId: The authenticated user's unique identifier
    ///   - syncEngine: The sync engine to perform migration
    ///
    /// Requirements: 9.1
    private func attemptMigration(userId: String, syncEngine: FirebaseSyncEngine) async {
        do {
            // Check if there's local data to migrate by attempting migration
            print("🔄 Checking for local data to migrate...")
            isMigrating = true
            
            let result = try await syncEngine.migrateLocalData(userId: userId)
            
            if result.totalCount > 0 {
                print("✅ Migration completed: \(result.totalCount - result.failedCount) items migrated")
            } else {
                print("ℹ️ No local data to migrate")
            }
            
            isMigrating = false
        } catch {
            print("❌ Migration failed: \(error.localizedDescription)")
            isMigrating = false
            // Migration failure doesn't prevent app usage - local data is preserved
        }
    }
    
    /// Handles authentication state changes
    /// - Parameters:
    ///   - oldState: Previous authentication state
    ///   - newState: New authentication state
    ///
    /// Requirements: 2.5, 3.1, 3.3
    private func handleAuthStateChange(
        from oldState: FirebaseAuthService.AuthenticationState,
        to newState: FirebaseAuthService.AuthenticationState
    ) async {
        guard let syncEngine = syncEngine else { return }
        
        switch (oldState, newState) {
        case (.authenticated, .unauthenticated):
            // User signed out - stop sync listeners and reset sync status
            print("🔄 Stopping sync listeners (user signed out)")
            await syncEngine.stopListening()
            
            // Reset sync status for all local data to enable re-sync on next sign-in
            if let dataStore = dataStore {
                do {
                    try await dataStore.resetSyncStatusOnSignOut()
                    print("✅ Local data retained with reset sync status")
                } catch {
                    print("⚠️ Failed to reset sync status: \(error.localizedDescription)")
                    // Non-fatal error - local data is still preserved
                }
            }
            
            // Reset migration flag for next sign-in
            migrationAttempted = false
            
        case (.unauthenticated, .authenticated(let user)):
            // User signed in - start sync listeners and attempt migration
            print("🔄 Starting sync listeners (user signed in)")
            await handleAuthenticated(userId: user.uid)
            
        default:
            // No action needed for other state transitions
            break
        }
    }
}

// MARK: - Sign In View

/// Sign-in view for existing users
///
/// This view:
/// - Provides email and password input fields
/// - Validates input and displays errors from authService
/// - Allows navigation to sign-up view
/// - Provides password reset functionality
/// - Handles async sign-in operation
///
/// Requirements: 2.1, 2.2, 4.1
private struct SignInView: View {
    @ObservedObject var authService: FirebaseAuthService
    @Binding var showSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetConfirmation = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Sign-in form
                    signInForm
                    
                    // Forgot password link
                    forgotPasswordButton
                    
                    // Sign-in button
                    signInButton
                    
                    // Divider
                    dividerView
                    
                    // Social sign-in buttons
                    socialSignInButtons
                    
                    // Create account navigation
                    createAccountButton
                    
                    // Error message display
                    if let errorMessage = authService.errorMessage {
                        errorView(message: errorMessage)
                    }
                }
                .padding()
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.large)
            .disabled(isSigningIn)
            .sheet(isPresented: $showForgotPassword) {
                forgotPasswordSheet
            }
            .alert("Password Reset Email Sent", isPresented: $showResetConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Check your email for instructions to reset your password.")
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Welcome Back")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Sign in to access your calorie tracking data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Sign-In Form
    
    private var signInForm: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await performSignIn()
                        }
                    }
            }
        }
    }
    
    // MARK: - Forgot Password Button
    
    private var forgotPasswordButton: some View {
        Button {
            resetEmail = email
            showForgotPassword = true
        } label: {
            Text("Forgot Password?")
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Sign-In Button
    
    private var signInButton: some View {
        Button {
            Task {
                await performSignIn()
            }
        } label: {
            HStack {
                if isSigningIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSignIn ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!canSignIn || isSigningIn)
    }
    
    // MARK: - Create Account Button
    
    private var createAccountButton: some View {
        HStack {
            Text("Don't have an account?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showSignUp = true
            } label: {
                Text("Create Account")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Divider View
    
    private var dividerView: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
            
            Text("OR")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Social Sign-In Buttons
    
    private var socialSignInButtons: some View {
        VStack(spacing: 12) {
            // Apple Sign-In Button
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = authService.prepareAppleSignIn()
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = nonce
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            
            // Google Sign-In Button
            Button {
                Task {
                    await performGoogleSignIn()
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Forgot Password Sheet
    
    private var forgotPasswordSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your email address and we'll send you instructions to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter your email", text: $resetEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                Button {
                    Task {
                        await performPasswordReset()
                    }
                } label: {
                    Text("Send Reset Email")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(resetEmail.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(resetEmail.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showForgotPassword = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    // MARK: - Actions
    
    /// Performs sign-in operation with current email and password
    private func performSignIn() async {
        guard canSignIn else { return }
        
        isSigningIn = true
        focusedField = nil
        
        do {
            _ = try await authService.signIn(email: email, password: password)
            // Success - authService will update authState automatically
            // Note: Don't set isSigningIn = false here, let the view disappear naturally
        } catch {
            // Error is already set in authService.errorMessage
            isSigningIn = false
        }
    }
    
    /// Performs password reset operation
    private func performPasswordReset() async {
        guard !resetEmail.isEmpty else { return }
        
        do {
            try await authService.sendPasswordReset(email: resetEmail)
            showForgotPassword = false
            showResetConfirmation = true
        } catch {
            // Error is already set in authService.errorMessage
        }
    }
    
    /// Handles Apple Sign-In result
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            do {
                _ = try await authService.signInWithApple(authorization)
                // Success - authService will update authState automatically
            } catch {
                // Error is already set in authService.errorMessage
            }
        case .failure(let error):
            authService.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
        }
    }
    
    /// Performs Google Sign-In
    private func performGoogleSignIn() async {
        do {
            _ = try await authService.signInWithGoogle()
            // Success - authService will update authState automatically
        } catch {
            // Error is already set in authService.errorMessage
        }
    }
}

// MARK: - Sign Up View

/// Sign-up view for new users
///
/// This view:
/// - Provides email, password, and confirm password input fields
/// - Validates password matching before submission
/// - Validates input and displays errors from authService
/// - Allows navigation back to sign-in view
/// - Handles async account creation operation
///
/// Requirements: 1.1, 1.2, 1.3, 1.5
private struct SignUpView: View {
    @ObservedObject var authService: FirebaseAuthService
    @Binding var showSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isCreatingAccount = false
    @State private var passwordMismatchError: String?
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
        case confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Sign-up form
                    signUpForm
                    
                    // Create account button
                    createAccountButton
                    
                    // Divider
                    dividerView
                    
                    // Social sign-in buttons
                    socialSignInButtons
                    
                    // Sign-in navigation
                    signInButton
                    
                    // Error message display
                    if let errorMessage = authService.errorMessage {
                        errorView(message: errorMessage)
                    }
                    
                    // Password mismatch error
                    if let mismatchError = passwordMismatchError {
                        errorView(message: mismatchError)
                    }
                }
                .padding()
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.large)
            .disabled(isCreatingAccount)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Join CountMe")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create an account to sync your calorie tracking data across devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Sign-Up Form
    
    private var signUpForm: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    .onChange(of: email) {
                        // Clear errors when user starts typing
                        authService.errorMessage = nil
                    }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .confirmPassword
                    }
                    .onChange(of: password) {
                        // Clear errors when user starts typing
                        authService.errorMessage = nil
                        passwordMismatchError = nil
                    }
                
                Text("Must be at least 8 characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Confirm password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField("Re-enter your password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await performCreateAccount()
                        }
                    }
                    .onChange(of: confirmPassword) {
                        // Clear errors when user starts typing
                        passwordMismatchError = nil
                    }
            }
        }
    }
    
    // MARK: - Create Account Button
    
    private var createAccountButton: some View {
        Button {
            Task {
                await performCreateAccount()
            }
        } label: {
            HStack {
                if isCreatingAccount {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreateAccount ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!canCreateAccount || isCreatingAccount)
    }
    
    // MARK: - Sign-In Button
    
    private var signInButton: some View {
        HStack {
            Text("Already have an account?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showSignUp = false
            } label: {
                Text("Sign In")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Divider View
    
    private var dividerView: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
            
            Text("OR")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Social Sign-In Buttons
    
    private var socialSignInButtons: some View {
        VStack(spacing: 12) {
            // Apple Sign-In Button
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = authService.prepareAppleSignIn()
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = nonce
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            
            // Google Sign-In Button
            Button {
                Task {
                    await performGoogleSignIn()
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Properties
    
    private var canCreateAccount: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }
    
    // MARK: - Actions
    
    /// Performs account creation with validation
    private func performCreateAccount() async {
        guard canCreateAccount else { return }
        
        // Clear previous errors
        authService.errorMessage = nil
        passwordMismatchError = nil
        
        // Validate password matching
        guard password == confirmPassword else {
            passwordMismatchError = "Passwords do not match"
            return
        }
        
        isCreatingAccount = true
        focusedField = nil
        
        do {
            _ = try await authService.createAccount(email: email, password: password)
            // Success - authService will update authState automatically
            // User will be automatically signed in per requirement 1.4
        } catch {
            // Error is already set in authService.errorMessage
            isCreatingAccount = false
        }
    }
    
    /// Handles Apple Sign-In result
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            do {
                _ = try await authService.signInWithApple(authorization)
                // Success - authService will update authState automatically
            } catch {
                // Error is already set in authService.errorMessage
            }
        case .failure(let error):
            authService.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
        }
    }
    
    /// Performs Google Sign-In
    private func performGoogleSignIn() async {
        do {
            _ = try await authService.signInWithGoogle()
            // Success - authService will update authState automatically
        } catch {
            // Error is already set in authService.errorMessage
        }
    }
}

#Preview("Loading State") {
    AuthenticationView()
}

#Preview("Unauthenticated State") {
    AuthenticationView()
}
