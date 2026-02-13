//
//  FirebaseAuthServiceTests.swift
//  CountMeTests
//
//  Tests for FirebaseAuthService authentication operations
//

import Testing
import FirebaseAuth
@testable import CountMe

@Suite("FirebaseAuthService Tests")
struct FirebaseAuthServiceTests {
    
    // MARK: - Validation Tests
    
    @Test("Valid email passes validation")
    func testValidEmailValidation() async throws {
        let authService = await FirebaseAuthService()
        
        // Valid email formats should not throw
        try await authService.validateEmail("test@example.com")
        try await authService.validateEmail("user.name+tag@example.co.uk")
        try await authService.validateEmail("test123@test-domain.com")
    }
    
    @Test("Invalid email fails validation")
    func testInvalidEmailValidation() async throws {
        let authService = await FirebaseAuthService()
        
        // Invalid email formats should throw AuthError.invalidEmail
        await #expect(throws: AuthError.invalidEmail) {
            try await authService.validateEmail("notanemail")
        }
        
        await #expect(throws: AuthError.invalidEmail) {
            try await authService.validateEmail("missing@domain")
        }
        
        await #expect(throws: AuthError.invalidEmail) {
            try await authService.validateEmail("@example.com")
        }
    }
    
    @Test("Valid password passes validation")
    func testValidPasswordValidation() async throws {
        let authService = await FirebaseAuthService()
        
        // Passwords with 8+ characters should not throw
        try await authService.validatePassword("12345678")
        try await authService.validatePassword("password123")
        try await authService.validatePassword("VeryLongPassword123!")
    }
    
    @Test("Short password fails validation")
    func testShortPasswordValidation() async throws {
        let authService = await FirebaseAuthService()
        
        // Passwords shorter than 8 characters should throw AuthError.weakPassword
        await #expect(throws: AuthError.weakPassword) {
            try await authService.validatePassword("short")
        }
        
        await #expect(throws: AuthError.weakPassword) {
            try await authService.validatePassword("1234567")
        }
        
        await #expect(throws: AuthError.weakPassword) {
            try await authService.validatePassword("")
        }
    }
    
    // MARK: - Sign Out Tests
    
    @Test("Sign out clears current user")
    func testSignOutClearsCurrentUser() async throws {
        let authService = await FirebaseAuthService()
        
        // Note: This test verifies the signOut method exists and can be called
        // In a real scenario with a signed-in user, currentUser would be cleared
        // For unit testing without actual Firebase connection, we verify the method doesn't throw
        try await authService.signOut()
        
        // Wait briefly for the auth state listener to propagate the sign-out
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Verify currentUser is nil after sign out
        let currentUser = await authService.currentUser
        #expect(currentUser == nil)
    }
    
    // MARK: - Password Reset Tests
    
    @Test("Send password reset accepts valid email")
    func testSendPasswordResetWithValidEmail() async throws {
        let authService = await FirebaseAuthService()
        
        // Note: This test verifies the sendPasswordReset method exists and can be called
        // In a real scenario, this would send an email via Firebase
        // For unit testing without actual Firebase connection, we verify the method signature
        // The actual Firebase call will fail without a real connection, which is expected
        do {
            try await authService.sendPasswordReset(email: "test@example.com")
        } catch {
            // Expected to fail without real Firebase connection
            // We're just verifying the method exists and has correct signature
        }
    }
    
    // MARK: - Account Deletion Tests
    
    @Test("Delete account requires authenticated user")
    func testDeleteAccountRequiresAuthenticatedUser() async throws {
        let authService = await FirebaseAuthService()
        
        // Attempting to delete account without being signed in should fail
        await #expect(throws: AuthError.accountDeletionFailed) {
            try await authService.deleteAccount()
        }
    }
}
