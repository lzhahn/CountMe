# Implementation Plan: Firebase User Authentication and Cloud Sync

## Overview

This implementation plan adds Firebase Authentication and Firestore cloud storage to the CountMe iOS app while maintaining the existing offline-first architecture. The implementation follows a dual-persistence model where all data is stored both locally (SwiftData) and in the cloud (Firestore), with automatic synchronization when online.

The plan is structured to build incrementally: first establishing Firebase infrastructure, then authentication, then sync engine, and finally integrating with existing features. Each major component includes property-based tests to validate correctness properties from the design document.

## Tasks

- [x] 1. Set up Firebase infrastructure and dependencies
  - Add Firebase iOS SDK via Swift Package Manager (FirebaseAuth, FirebaseFirestore)
  - Create GoogleService-Info.plist configuration file
  - Initialize Firebase in CountMeApp.swift
  - Configure Firestore offline persistence settings
  - _Requirements: All requirements depend on Firebase infrastructure_

- [ ] 2. Implement core authentication service
  - [x] 2.1 Create FirebaseAuthService class with authentication state management
    - Implement @MainActor class with @Published properties for currentUser and authState
    - Add authentication state listener setup
    - Implement email and password validation methods
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 12.1, 12.4_
  
  - [ ]* 2.2 Write property tests for authentication validation
    - **Property 1: Valid Account Creation**
    - **Property 2: Invalid Email Rejection**
    - **Property 3: Short Password Rejection**
    - **Validates: Requirements 1.1, 1.2, 1.3**
  
  - [x] 2.3 Implement account creation and sign-in methods
    - Add createAccount(email:password:) async method
    - Add signIn(email:password:) async method
    - Implement error mapping from Firebase errors to AuthError
    - _Requirements: 1.1, 1.4, 2.1_
  
  - [ ]* 2.4 Write property tests for authentication operations
    - **Property 4: Auto Sign-In After Creation**
    - **Property 5: Valid Sign-In**
    - **Property 6: Invalid Credentials Rejection**
    - **Validates: Requirements 1.4, 2.1, 2.2**
  
  - [x] 2.5 Implement sign-out and password reset
    - Add signOut() method with credential clearing
    - Add sendPasswordReset(email:) async method
    - Add deleteAccount() async method
    - _Requirements: 3.1, 3.2, 4.1, 14.2_
  
  - [ ]* 2.6 Write property tests for session management
    - **Property 7: Session Persistence**
    - **Property 8: User ID Availability**
    - **Property 9: Sign Out Terminates Session**
    - **Property 10: Sign Out Clears Credentials**
    - **Validates: Requirements 2.3, 2.5, 3.1, 3.2**

- [ ] 3. Create authentication UI views
  - [x] 3.1 Implement AuthenticationView with state routing
    - Create root view that switches between loading, authenticated, and unauthenticated states
    - Add state observation for authService.authState
    - _Requirements: 12.1, 12.2, 12.3_
  
  - [x] 3.2 Implement SignInView
    - Create form with email and password fields
    - Add sign-in button with async action
    - Add "Forgot Password" link
    - Add "Create Account" navigation
    - Display error messages from authService
    - _Requirements: 2.1, 2.2, 4.1_
  
  - [x] 3.3 Implement SignUpView
    - Create form with email, password, and confirm password fields
    - Add password matching validation
    - Add create account button with async action
    - Display error messages from authService
    - _Requirements: 1.1, 1.2, 1.3, 1.5_
  
  - [x] 3.4 Implement ProfileView
    - Display authenticated user's email
    - Add sign-out button
    - Add delete account button with confirmation dialog
    - _Requirements: 14.1, 3.1, 14.2_
  
  - [ ]* 3.5 Write UI tests for authentication flows
    - Test sign-up flow with valid and invalid inputs
    - Test sign-in flow with valid and invalid credentials
    - Test sign-out flow
    - Test UI state transitions on auth state changes
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 3.1, 12.4_

- [ ] 4. Checkpoint - Ensure authentication works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement SyncableEntity protocol and update data models
  - [x] 5.1 Create SyncableEntity protocol
    - Define protocol with id, userId, lastModified, syncStatus properties
    - Add toFirestoreData() and fromFirestoreData() methods
    - Create SyncStatus enum (synced, pendingUpload, pendingDelete, conflict)
    - _Requirements: 5.1, 5.2, 5.3, 10.3_
  
  - [x] 5.2 Update FoodItem model to conform to SyncableEntity
    - Add userId, lastModified, syncStatus properties
    - Implement toFirestoreData() conversion method
    - Implement fromFirestoreData() static method
    - Update SwiftData schema with new properties
    - _Requirements: 5.1, 10.3_
  
  - [x] 5.3 Update DailyLog model to conform to SyncableEntity
    - Add userId, lastModified, syncStatus properties
    - Implement Firestore conversion methods
    - Update SwiftData schema
    - _Requirements: 5.1, 10.3_
  
  - [x] 5.4 Update CustomMeal model to conform to SyncableEntity
    - Add userId, lastModified, syncStatus properties
    - Implement Firestore conversion methods with ingredients array
    - Update SwiftData schema
    - _Requirements: 5.2, 10.3_
  
  - [ ]* 5.5 Write property tests for data model conversions
    - Test FoodItem round-trip (toFirestoreData → fromFirestoreData)
    - Test DailyLog round-trip
    - Test CustomMeal round-trip
    - Test invalid Firestore data handling
    - _Requirements: 5.1, 5.2, 5.3_

- [x] 6. Implement FirebaseSyncEngine core functionality
  - [x] 6.1 Create FirebaseSyncEngine actor with initialization
    - Define actor with dataStore, db, listeners, syncQueue properties
    - Implement init with Firestore configuration
    - Add configureOfflinePersistence() method
    - Create SyncOperation and EntityType enums
    - _Requirements: 5.1, 7.1_
  
  - [x] 6.2 Implement queue management
    - Add queueOperation(_:) method
    - Add processQueue() async method
    - Implement queue persistence for app restarts
    - _Requirements: 7.2, 13.4_
  
  - [ ]* 6.3 Write property tests for queue management
    - **Property 17: Offline Changes Queued**
    - **Validates: Requirements 7.2, 13.4**
  
  - [x] 6.4 Implement Firestore upload operations
    - Add uploadToFirestore(_:userId:) async method
    - Implement entity-specific upload for FoodItem, DailyLog, CustomMeal
    - Add error handling with retry logic
    - Update syncStatus after successful upload
    - _Requirements: 5.1, 5.2, 5.3, 10.3_
  
  - [x] 6.5 Implement Firestore download operations
    - Add downloadFromFirestore(userId:) async method
    - Implement entity-specific download for all types
    - Parse Firestore documents to local models
    - Update local store with downloaded data
    - _Requirements: 6.1, 10.4_
  
  - [ ]* 6.6 Write property tests for dual persistence
    - **Property 12: CRUD Operations Dual Persistence**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**

- [x] 7. Implement real-time synchronization
  - [x] 7.1 Implement Firestore real-time listeners
    - Add setupRealtimeListener(collection:userId:) method
    - Implement listener for foodItems collection
    - Implement listener for dailyLogs collection
    - Implement listener for customMeals collection
    - Add handleCloudUpdate(_:entityType:) method
    - _Requirements: 6.2_
  
  - [x] 7.2 Implement startListening and stopListening methods
    - Add startListening(userId:) to start all listeners
    - Add stopListening() to remove all listeners
    - Call startListening when user authenticates
    - Call stopListening when user signs out
    - _Requirements: 6.2, 3.1_
  
  - [ ]* 7.3 Write property tests for synchronization
    - **Property 13: Initial Sync Downloads All Data**
    - **Property 14: Data Consistency After Sync**
    - **Property 16: Bidirectional Sync On Reconnect**
    - **Validates: Requirements 6.1, 6.2, 6.5, 7.3, 7.4**

- [x] 8. Implement conflict resolution
  - [x] 8.1 Implement conflict detection
    - Add conflict detection in handleCloudUpdate
    - Compare lastModified timestamps
    - Detect deletion conflicts
    - _Requirements: 8.1, 8.2_
  
  - [x] 8.2 Implement resolveConflict method
    - Add resolveConflict(local:cloud:) method
    - Implement last-write-wins for standard entities
    - Implement deletion-wins logic
    - Update both stores with resolved entity
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [x] 8.3 Implement daily log merging
    - Add mergeDailyLogs(local:cloud:) method
    - Combine food items from both versions
    - Remove duplicates by ID
    - Recalculate total calories
    - _Requirements: 8.4_
  
  - [ ]* 8.4 Write property tests for conflict resolution
    - **Property 19: Last-Write-Wins for Standard Entities**
    - **Property 20: Deletion Wins in Conflicts**
    - **Property 21: Daily Log Merging**
    - **Validates: Requirements 8.1, 8.2, 8.4**

- [ ] 9. Checkpoint - Ensure sync engine works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement data migration
  - [x] 10.1 Implement migrateLocalData method
    - Add migrateLocalData(userId:) async method
    - Fetch all local data from DataStore
    - Associate userId with all entities
    - Upload all entities to Firestore
    - Mark all entities as synced
    - Return MigrationResult with counts
    - _Requirements: 9.1, 9.3_
  
  - [x] 10.2 Implement migration retry logic
    - Add exponential backoff for migration failures
    - Preserve local data on failure
    - Track migration progress for resume
    - _Requirements: 9.4_
  
  - [x] 10.3 Add migration UI feedback
    - Create MigrationProgressView
    - Display progress indicator during migration
    - Show success confirmation when complete
    - Show error message with retry option on failure
    - _Requirements: 9.2, 9.5_
  
  - [ ]* 10.4 Write property tests for migration
    - **Property 22: Migration Success**
    - **Property 23: Migration Retry and Data Preservation**
    - **Validates: Requirements 9.1, 9.3, 9.4**

- [x] 11. Implement offline functionality
  - [x] 11.1 Add network availability monitoring
    - Create NetworkMonitor class with reachability checking
    - Publish network status changes
    - Integrate with SyncEngine
    - _Requirements: 7.1, 7.5_
  
  - [x] 11.2 Implement offline operation handling
    - Ensure all CRUD operations work offline
    - Queue operations when offline
    - Display offline indicator in UI
    - _Requirements: 7.1, 7.2, 7.5_
  
  - [x] 11.3 Implement automatic sync on reconnect
    - Detect network availability changes
    - Trigger processQueue() when online
    - Download cloud changes when online
    - _Requirements: 7.3, 7.4_
  
  - [ ]* 11.4 Write property tests for offline functionality
    - **Property 15: Offline Operations Work Locally**
    - **Property 18: Sync Failure Preserves Local Data**
    - **Property 30: Intermittent Connectivity Handling**
    - **Validates: Requirements 7.1, 13.3, 13.4**

- [x] 12. Implement error handling and retry logic
  - [x] 12.1 Implement exponential backoff retry
    - Create RetryManager with exponential backoff calculation
    - Add retry logic to sync operations
    - Track retry attempts and max retries
    - _Requirements: 13.1_
  
  - [x] 12.2 Implement error handling for sync operations
    - Add comprehensive error handling in SyncEngine
    - Map Firestore errors to SyncError
    - Preserve local data on all errors
    - Log errors with context
    - _Requirements: 13.2, 13.3_
  
  - [x] 12.3 Add manual retry UI
    - Add pull-to-refresh on main view
    - Add retry button in error states
    - Call forceSyncNow() on manual retry
    - _Requirements: 13.5_
  
  - [ ]* 12.4 Write property tests for error handling
    - **Property 29: Exponential Backoff Retry**
    - **Validates: Requirements 13.1**

- [x] 13. Implement sync status UI
  - [x] 13.1 Create SyncStatusViewModel
    - Add @Published syncState property
    - Add @Published isOffline property
    - Add @Published lastSyncTime property
    - Observe SyncEngine state changes
    - _Requirements: 6.4, 7.5_
  
  - [x] 13.2 Create SyncStatusBadge view
    - Display sync status icon (synced, syncing, error, offline)
    - Display status text
    - Add to navigation bar of main views
    - _Requirements: 6.4, 7.5_
  
  - [ ]* 13.3 Write UI tests for sync status
    - Test sync status updates on state changes
    - Test offline indicator display
    - Test error state display
    - _Requirements: 6.4, 7.5_

- [x] 14. Implement data retention policies
  - [x] 14.1 Implement retention policy enforcement
    - Add applyRetentionPolicy(userId:) async method
    - Query daily logs older than 90 days
    - Delete old daily logs from both stores
    - Preserve custom meals and goals regardless of age
    - _Requirements: 11.1, 11.2, 11.3, 11.4_
  
  - [x] 14.2 Schedule retention policy execution
    - Run retention policy on app launch
    - Run retention policy daily in background
    - Sync deletions to cloud
    - _Requirements: 11.1, 11.5_
  
  - [ ]* 14.3 Write property tests for retention policies
    - **Property 26: 90-Day Retention With Sync**
    - **Property 27: Custom Meals Retained Indefinitely**
    - **Property 28: Goals Retained Indefinitely**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

- [x] 15. Implement security features
  - [x] 15.1 Deploy Firestore security rules
    - Create firestore.rules file with user-scoped access
    - Implement isAuthenticated() and isOwner() helper functions
    - Add rules for all collections (dailyLogs, foodItems, customMeals, profile)
    - Deploy rules to Firebase project
    - _Requirements: 10.1, 10.2, 10.5_
  
  - [x] 15.2 Implement user ID association
    - Ensure all entities have userId before upload
    - Validate userId matches authenticated user
    - Filter queries by userId
    - _Requirements: 10.3, 10.4_
  
  - [ ]* 15.3 Write property tests for security
    - **Property 24: Data Has User ID**
    - **Property 25: Query Filters By User ID**
    - **Validates: Requirements 10.3, 10.4**

- [x] 16. Implement account management features
  - [x] 16.1 Implement account deletion
    - Add deleteAccount() method in FirebaseAuthService
    - Delete all user data from Firestore
    - Clear all local data from DataStore
    - Sign out user after deletion
    - _Requirements: 14.2, 14.3, 14.4_
  
  - [x] 16.2 Add account deletion UI
    - Add delete account button in ProfileView
    - Show confirmation dialog with warning
    - Display progress during deletion
    - Navigate to auth screen after deletion
    - _Requirements: 14.2_
  
  - [ ]* 16.3 Write property tests for account management
    - **Property 31: Account Deletion Cleanup**
    - **Validates: Requirements 14.2, 14.3, 14.4**

- [x] 17. Integrate sync with existing features
  - [x] 17.1 Update CalorieViewModel to use SyncEngine
    - Replace direct DataStore calls with SyncEngine calls
    - Pass userId to all sync operations
    - Handle sync errors gracefully
    - _Requirements: 5.1, 5.4, 5.5_
  
  - [x] 17.2 Update food search to sync results
    - Ensure FatSecret API integration unchanged
    - Sync food items from search results
    - Associate userId with search results
    - _Requirements: 15.1, 15.2, 15.3_
  
  - [x] 17.3 Update manual entry to sync data
    - Sync manually entered food items
    - Sync custom meals
    - Sync goal changes
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [x] 17.4 Update historical view to show synced data
    - Display sync status for each item
    - Show offline indicator when offline
    - Allow manual sync trigger
    - _Requirements: 6.5_
  
  - [ ]* 17.5 Write integration tests
    - Test end-to-end food item creation and sync
    - Test end-to-end custom meal creation and sync
    - Test end-to-end goal setting and sync
    - Test offline → online sync flow
    - _Requirements: 5.1, 5.2, 5.3, 6.5, 7.3, 7.4_

- [x] 18. Update app entry point
  - [x] 18.1 Update CountMeApp.swift
    - Initialize Firebase in app init
    - Replace ContentView with AuthenticationView as root
    - Create and inject FirebaseAuthService
    - Create and inject FirebaseSyncEngine
    - _Requirements: 12.1, 12.2, 12.3_
  
  - [x] 18.2 Handle authentication state changes
    - Start sync listeners when authenticated
    - Stop sync listeners when unauthenticated
    - Trigger migration on first sign-in with local data
    - _Requirements: 2.5, 3.1, 9.1_
  
  - [ ]* 18.3 Write property tests for UI state management
    - **Property 32: UI Updates On Auth State Change**
    - **Validates: Requirements 12.4**

- [x] 19. Add sign-out data retention
  - [x] 19.1 Implement local data retention on sign-out
    - Ensure DataStore retains all data on sign-out
    - Only clear syncStatus, not data itself
    - Allow re-sync on next sign-in
    - _Requirements: 3.3_
  
  - [ ]* 19.2 Write property tests for sign-out behavior
    - **Property 11: Sign Out Retains Local Data**
    - **Validates: Requirements 3.3**

- [ ] 20. Final checkpoint - Comprehensive testing
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 21. Documentation and cleanup
  - [ ] 21.1 Update project documentation
    - Update README with Firebase setup instructions
    - Document Firestore security rules
    - Document data migration process
    - Add troubleshooting guide for sync issues
  
  - [ ] 21.2 Add inline code documentation
    - Document all public APIs in FirebaseAuthService
    - Document all public APIs in FirebaseSyncEngine
    - Document conflict resolution logic
    - Document retention policy logic
  
  - [ ] 21.3 Update architecture documentation
    - Update project-foundation.md with Firebase architecture
    - Add Firebase integration diagrams
    - Document sync flow and conflict resolution
    - Update testing strategy with property-based tests

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at major milestones
- Property tests validate universal correctness properties with 100+ iterations
- Unit tests validate specific examples, edge cases, and error conditions
- Firebase SDK initialization must happen before any Firebase operations
- Firestore security rules must be deployed before production use
- Migration should be triggered automatically on first sign-in with local data
- All sync operations should work offline and queue for later sync
- Conflict resolution uses last-write-wins with special daily log merging
- 90-day retention policy applies only to daily logs, not custom meals or goals
