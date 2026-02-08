//
//  FirebaseAuthService.swift
//  CountMe
//
//  Firebase Authentication service managing user identity and session state
//

import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit
// import GoogleSignIn // Uncomment after adding GoogleSignIn package

/// Actor responsible for all Firebase Authentication operations
/// Manages user authentication state, account creation, sign-in, and sign-out
@MainActor
class FirebaseAuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authenticated Firebase user, nil if not authenticated
    @Published var currentUser: User?
    
    /// Current authentication state of the application
    @Published var authState: AuthenticationState = .loading
    
    /// Error message to display in UI, nil if no error
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// Firebase authentication state listener handle
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Current nonce for Apple Sign-In
    private var currentNonce: String?
    
    // MARK: - Authentication State Enum
    
    /// Represents the current authentication state of the user
    enum AuthenticationState: Equatable {
        case authenticated(User)
        case unauthenticated
        case loading
        
        static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
            switch (lhs, rhs) {
            case (.authenticated(let lUser), .authenticated(let rUser)):
                return lUser.uid == rUser.uid
            case (.unauthenticated, .unauthenticated):
                return true
            case (.loading, .loading):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Initializes the authentication service and sets up the auth state listener
    init() {
        setupAuthListener()
    }
    
    deinit {
        // Remove the auth state listener when the service is deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Authentication State Listener
    
    /// Sets up the Firebase authentication state listener
    /// This listener monitors authentication state changes and updates the published properties
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.currentUser = user
                
                if let user = user {
                    self.authState = .authenticated(user)
                    print("✅ User authenticated: \(user.email ?? "unknown")")
                } else {
                    self.authState = .unauthenticated
                    print("ℹ️ User not authenticated")
                }
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates an email address format
    /// - Parameter email: The email address to validate
    /// - Throws: AuthError.invalidEmail if the email format is invalid
    func validateEmail(_ email: String) throws {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            throw AuthError.invalidEmail
        }
    }
    
    /// Validates a password meets minimum requirements
    /// - Parameter password: The password to validate
    /// - Throws: AuthError.weakPassword if the password is shorter than 8 characters
    func validatePassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
    }
    
    // MARK: - Authentication Operations
    
    /// Creates a new user account with email and password
    /// Automatically signs in the user upon successful account creation
    /// - Parameters:
    ///   - email: User's email address (must be valid format)
    ///   - password: User's password (minimum 8 characters)
    /// - Returns: Firebase User object for the newly created account
    /// - Throws: AuthError for validation failures or Firebase errors
    func createAccount(email: String, password: String) async throws -> User {
        // Clear any previous error messages
        errorMessage = nil
        
        // Validate email and password before attempting creation
        try validateEmail(email)
        try validatePassword(password)
        
        do {
            // Create the account with Firebase Authentication
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            
            print("✅ Account created successfully for: \(email)")
            
            // Return the user object (auth state listener will update currentUser)
            return authResult.user
            
        } catch let error as NSError {
            // Map Firebase errors to AuthError
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Signs in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Firebase User object for the authenticated user
    /// - Throws: AuthError for invalid credentials or Firebase errors
    func signIn(email: String, password: String) async throws -> User {
        // Clear any previous error messages
        errorMessage = nil
        
        do {
            // Attempt to sign in with Firebase Authentication
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            
            print("✅ User signed in successfully: \(email)")
            
            // Return the user object (auth state listener will update currentUser)
            return authResult.user
            
        } catch let error as NSError {
            // Map Firebase errors to AuthError
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Signs out the current user and clears all cached authentication credentials
    /// Terminates the active user session and transitions to unauthenticated state
    /// - Throws: AuthError if sign out operation fails
    func signOut() throws {
        // Clear any previous error messages
        errorMessage = nil
        
        do {
            // Sign out from Firebase Authentication
            try Auth.auth().signOut()
            
            // Clear the current user reference
            currentUser = nil
            
            print("✅ User signed out successfully")
            
        } catch let error as NSError {
            // Map Firebase errors to AuthError
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Sends a password reset email to the specified email address
    /// For security, displays success message even if email is not registered
    /// - Parameter email: User's email address to send password reset link
    /// - Throws: AuthError if email sending fails
    func sendPasswordReset(email: String) async throws {
        // Clear any previous error messages
        errorMessage = nil
        
        do {
            // Send password reset email via Firebase Authentication
            try await Auth.auth().sendPasswordReset(withEmail: email)
            
            print("✅ Password reset email sent to: \(email)")
            
        } catch let error as NSError {
            // Map Firebase errors to AuthError
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    // MARK: - Apple Sign-In
    
    /// Signs in with Apple using Sign in with Apple
    /// - Parameter authorization: The ASAuthorization object from Apple
    /// - Returns: Firebase User object for the authenticated user
    /// - Throws: AuthError if sign-in fails
    func signInWithApple(_ authorization: ASAuthorization) async throws -> User {
        // Clear any previous error messages
        errorMessage = nil
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            let error = AuthError.invalidCredentials
            errorMessage = error.errorDescription
            throw error
        }
        
        guard let nonce = currentNonce else {
            let error = AuthError.invalidCredentials
            errorMessage = error.errorDescription
            throw error
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            let error = AuthError.invalidCredentials
            errorMessage = error.errorDescription
            throw error
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            let error = AuthError.invalidCredentials
            errorMessage = error.errorDescription
            throw error
        }
        
        do {
            // Create Firebase credential with Apple ID token
            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce,
                accessToken: nil
            )
            
            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("✅ User signed in with Apple: \(authResult.user.uid)")
            
            return authResult.user
            
        } catch let error as NSError {
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Prepares for Apple Sign-In by generating a nonce
    /// - Returns: The nonce string to use for the request
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    // MARK: - Google Sign-In
    
    /// Signs in with Google
    /// - Returns: Firebase User object for the authenticated user
    /// - Throws: AuthError if sign-in fails
    func signInWithGoogle() async throws -> User {
        // Clear any previous error messages
        errorMessage = nil
        
        // TODO: Uncomment after adding GoogleSignIn package
        /*
        guard let clientID = Auth.auth().app?.options.clientID else {
            let error = AuthError.invalidCredentials
            errorMessage = error.errorDescription
            throw error
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            // Get the presenting view controller
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = await windowScene.windows.first?.rootViewController else {
                let error = AuthError.unknown(NSError(domain: "CountMe", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"]))
                errorMessage = error.errorDescription
                throw error
            }
            
            // Start Google Sign-In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                let error = AuthError.invalidCredentials
                errorMessage = error.errorDescription
                throw error
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Create Firebase credential with Google tokens
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("✅ User signed in with Google: \(authResult.user.email ?? "unknown")")
            
            return authResult.user
            
        } catch let error as NSError {
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
        */
        
        // Temporary implementation until GoogleSignIn package is added
        let error = AuthError.unknown(NSError(domain: "CountMe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In not yet configured. Please add GoogleSignIn package."]))
        errorMessage = error.errorDescription
        throw error
    }
    
    // MARK: - Helper Methods
    
    /// Generates a random nonce string for Apple Sign-In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    /// Hashes a string using SHA256
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    /// Deletes the current user's account and all associated authentication data
    /// This operation requires recent authentication and will sign out the user
    /// 
    /// This method performs a complete account deletion:
    /// 1. Deletes all user data from Firestore (cloud storage)
    /// 2. Clears all local data from SwiftData
    /// 3. Deletes the Firebase Authentication account
    /// 4. Signs out the user
    ///
    /// Note: This method requires syncEngine and dataStore to be injected.
    /// Call deleteAccountWithCleanup(syncEngine:dataStore:) instead for full deletion.
    ///
    /// - Throws: AuthError if account deletion fails
    func deleteAccount() async throws {
        // Clear any previous error messages
        errorMessage = nil
        
        guard let user = currentUser else {
            let error = AuthError.accountDeletionFailed
            errorMessage = error.errorDescription
            throw error
        }
        
        do {
            // Delete the user account from Firebase Authentication
            try await user.delete()
            
            // Clear the current user reference
            currentUser = nil
            
            print("✅ User account deleted successfully")
            
        } catch let error as NSError {
            // Map Firebase errors to AuthError
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Deletes the current user's account with complete data cleanup
    ///
    /// This method performs a complete account deletion:
    /// 1. Deletes all user data from Firestore (cloud storage)
    /// 2. Clears all local data from SwiftData
    /// 3. Deletes the Firebase Authentication account
    /// 4. Signs out the user
    ///
    /// This operation is irreversible and should only be called after user confirmation.
    ///
    /// - Parameters:
    ///   - syncEngine: The FirebaseSyncEngine for deleting cloud data
    ///   - dataStore: The DataStore for deleting local data
    /// - Throws: AuthError if account deletion fails
    ///
    /// **Validates: Requirements 14.2, 14.3, 14.4**
    func deleteAccountWithCleanup(syncEngine: FirebaseSyncEngine, dataStore: DataStore) async throws {
        // Clear any previous error messages
        errorMessage = nil
        
        guard let user = currentUser else {
            let error = AuthError.accountDeletionFailed
            errorMessage = error.errorDescription
            throw error
        }
        
        let userId = user.uid
        
        do {
            // Step 1: Delete all user data from Firestore
            print("Step 1/4: Deleting cloud data...")
            do {
                try await syncEngine.deleteAllUserData(userId: userId)
            } catch {
                // Log error but continue - we want to delete local data and account even if cloud deletion fails
                print("⚠️ Failed to delete cloud data: \(error.localizedDescription)")
                print("Continuing with local data and account deletion...")
            }
            
            // Step 2: Clear all local data from DataStore
            print("Step 2/4: Clearing local data...")
            try await dataStore.deleteAllLocalData()
            
            // Step 3: Delete the Firebase Authentication account
            print("Step 3/4: Deleting Firebase account...")
            try await user.delete()
            
            // Step 4: Clear the current user reference (sign out)
            print("Step 4/4: Signing out...")
            currentUser = nil
            
            print("✅ Account deletion completed successfully")
            
        } catch let error as NSError {
            // Map Firebase errors to AuthError
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    // MARK: - Error Mapping
    
    /// Maps Firebase authentication errors to AuthError cases
    /// - Parameter error: The NSError from Firebase Authentication
    /// - Returns: Corresponding AuthError with user-friendly message
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(_bridgedNSError: error) else {
            return .unknown(error)
        }
        
        switch errorCode.code {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .wrongPassword, .invalidCredential:
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .networkError:
            return .networkError
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Authentication Errors

/// Errors that can occur during authentication operations
enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case invalidCredentials
    case networkError
    case userNotFound
    case accountDeletionFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please check your connection"
        case .userNotFound:
            return "No account found with this email"
        case .accountDeletionFailed:
            return "Failed to delete account. Please try again"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidEmail, .invalidEmail),
             (.weakPassword, .weakPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.invalidCredentials, .invalidCredentials),
             (.networkError, .networkError),
             (.userNotFound, .userNotFound),
             (.accountDeletionFailed, .accountDeletionFailed):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
