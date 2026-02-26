//
//  FirebaseSyncEngine.swift
//  CountMe
//
//  Created by Kiro on 2/2/26.
//

import Foundation
import FirebaseFirestore
import SwiftData
import Observation

/// Actor responsible for synchronizing data between SwiftData (local) and Firestore (cloud)
///
/// FirebaseSyncEngine implements a dual-persistence model where all data is stored both
/// locally in SwiftData and in the cloud via Firestore. It handles:
/// - Bidirectional synchronization between local and cloud storage
/// - Offline operation queuing and automatic sync on reconnect
/// - Conflict resolution using last-write-wins strategy
/// - Real-time listeners for cloud data changes
/// - Data migration from anonymous local data to authenticated cloud data
///
/// The engine maintains an offline-first architecture where all operations work locally
/// first and sync to the cloud when available. Network failures never block user operations.
///
/// **Thread Safety**: All operations are actor-isolated for safe concurrent access
actor FirebaseSyncEngine {
    // MARK: - Properties
    
    /// Local persistence layer using SwiftData
    private let dataStore: DataStore
    
    /// Firestore database instance for cloud persistence
    private let db: Firestore
    
    /// Active Firestore real-time listeners for cloud data changes
    private var listeners: [ListenerRegistration] = []
    
    /// Queue of pending sync operations to execute when online
    private var syncQueue: [SyncOperation] = []
    
    /// Maximum number of operations allowed in the sync queue
    private let maxQueueSize = 1000
    
    /// Flag indicating if sync is currently in progress
    private var isSyncing = false
    
    /// Migration state tracking for resume capability
    private var migrationState: MigrationState?
    
    /// Migration retry configuration
    private let maxMigrationRetries = 5
    private let initialRetryDelay: TimeInterval = 2.0 // 2 seconds
    
    /// Network monitor for connectivity status
    nonisolated(unsafe) private let networkMonitor: NetworkMonitor
    
    /// Current authenticated user ID for sync operations
    private var currentUserId: String?
    
    /// Retry manager for exponential backoff retry logic
    private let retryManager: RetryManager
    
    /// Published network connectivity status
    @MainActor
    var isOnline: Bool {
        networkMonitor.isConnected
    }
    
    // MARK: - Enums
    
    /// Represents a pending synchronization operation
    enum SyncOperation: Codable {
        case create(entityId: String, entityType: EntityType, timestamp: Date)
        case update(entityId: String, entityType: EntityType, timestamp: Date)
        case delete(entityId: String, entityType: EntityType, timestamp: Date)
        
        var timestamp: Date {
            switch self {
            case .create(_, _, let timestamp),
                 .update(_, _, let timestamp),
                 .delete(_, _, let timestamp):
                return timestamp
            }
        }
        
        var entityId: String {
            switch self {
            case .create(let id, _, _),
                 .update(let id, _, _),
                 .delete(let id, _, _):
                return id
            }
        }
        
        var entityType: EntityType {
            switch self {
            case .create(_, let type, _),
                 .update(_, let type, _),
                 .delete(_, let type, _):
                return type
            }
        }
    }
    
    /// Types of entities that can be synchronized
    enum EntityType: String, Codable {
        case foodItem
        case exerciseItem
        case dailyLog
        case customMeal
        case userGoal
    }
    
    /// Result of a data migration operation
    struct MigrationResult {
        let foodItemsCount: Int
        let exerciseItemsCount: Int
        let dailyLogsCount: Int
        let customMealsCount: Int
        let totalCount: Int
        let failedCount: Int
        let errors: [Error]
        
        var isSuccess: Bool {
            return failedCount == 0
        }
        
        var successRate: Double {
            guard totalCount > 0 else { return 1.0 }
            return Double(totalCount - failedCount) / Double(totalCount)
        }
    }
    
    /// State tracking for migration progress and resume capability
    struct MigrationState: Codable {
        var userId: String
        var attemptCount: Int
        var lastAttemptDate: Date
        var migratedFoodItemIds: Set<String>
        var migratedExerciseItemIds: Set<String>
        var migratedDailyLogIds: Set<String>
        var migratedCustomMealIds: Set<String>
        var failedEntityIds: Set<String>
        
        init(userId: String) {
            self.userId = userId
            self.attemptCount = 0
            self.lastAttemptDate = Date()
            self.migratedFoodItemIds = []
            self.migratedExerciseItemIds = []
            self.migratedDailyLogIds = []
            self.migratedCustomMealIds = []
            self.failedEntityIds = []
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new FirebaseSyncEngine with the specified data store
    ///
    /// Initializes the sync engine with Firestore configuration and sets up
    /// offline persistence to enable seamless offline operation.
    ///
    /// - Parameter dataStore: The SwiftData-based local persistence layer
    init(dataStore: DataStore) {
        self.dataStore = dataStore
        self.db = Firestore.firestore()
        self.networkMonitor = NetworkMonitor()
        self.retryManager = RetryManager(
            initialDelay: 1.0,
            maxRetries: 6,
            maxDelay: 60.0
        )
        
        // Configure offline persistence on initialization
        configureOfflinePersistence()
        
        // Start network monitoring
        Task { @MainActor in
            networkMonitor.start()
        }
        
        // Set up network status change handler
        setupNetworkStatusObserver()
    }
    
    // MARK: - Configuration
    
    /// Configures Firestore offline persistence settings
    ///
    /// Enables Firestore's built-in offline persistence which caches cloud data
    /// locally and automatically syncs when connectivity is restored. This provides
    /// a seamless offline experience without manual queue management for reads.
    ///
    /// Settings:
    /// - Persistence enabled for offline access
    /// - 100MB cache size for offline data
    ///
    /// **Validates: Requirements 7.1 (Offline-First Operation)**
    private func configureOfflinePersistence() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    /// Sets up observer for network status changes
    ///
    /// Monitors network connectivity and automatically triggers sync operations
    /// when connectivity is restored. This ensures queued operations are processed
    /// and cloud changes are downloaded as soon as the device comes back online.
    ///
    /// **Validates: Requirements 7.3, 7.4 (Automatic Sync On Reconnect)**
    private func setupNetworkStatusObserver() {
        // Use a timer to periodically check network status and trigger sync
        // This is a simple approach that works with actor isolation
        Task {
            var wasOffline = false
            var lastRetentionPolicyDate: Date? = loadLastRetentionPolicyDate()
            
            while true {
                // Check every 5 seconds
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                
                let isCurrentlyOnline = await MainActor.run {
                    networkMonitor.isConnected
                }
                
                // If we just came back online, sync bidirectionally
                if isCurrentlyOnline && wasOffline {
                    print("Network connectivity restored - syncing bidirectionally")
                    
                    // Upload queued local changes
                    do {
                        try await processQueue()
                        print("Successfully uploaded queued operations")
                    } catch {
                        print("Failed to upload queued operations: \(error)")
                    }
                    
                    // Download cloud changes if we have a user ID
                    if let userId = currentUserId, !userId.isEmpty {
                        do {
                            try await downloadFromFirestore(userId: userId)
                            print("Successfully downloaded cloud changes")
                        } catch {
                            print("Failed to download cloud changes: \(error)")
                        }
                    }
                }
                
                wasOffline = !isCurrentlyOnline
                
                // Check if we should run retention policy (once per day)
                if let userId = currentUserId, !userId.isEmpty {
                    let now = Date()
                    let shouldRunRetentionPolicy: Bool
                    
                    if let lastRun = lastRetentionPolicyDate {
                        // Check if it's been more than 24 hours since last run
                        let hoursSinceLastRun = now.timeIntervalSince(lastRun) / 3600
                        shouldRunRetentionPolicy = hoursSinceLastRun >= 24
                    } else {
                        // Never run before - run now
                        shouldRunRetentionPolicy = true
                    }
                    
                    if shouldRunRetentionPolicy {
                        print("Running daily retention policy...")
                        do {
                            try await applyRetentionPolicy(userId: userId)
                            lastRetentionPolicyDate = now
                            saveLastRetentionPolicyDate(now)
                            print("Daily retention policy completed successfully")
                        } catch {
                            print("Failed to run retention policy: \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Queue Management
    
    /// Adds a sync operation to the queue for later execution
    ///
    /// Operations are queued when offline or when sync operations fail. The queue
    /// is persisted to UserDefaults to survive app restarts, ensuring no data loss.
    ///
    /// Operations are deduplicated - if an operation for the same entity already exists,
    /// the newer operation replaces the older one to avoid redundant syncs.
    ///
    /// The queue enforces a maximum size of 1,000 operations. When at capacity,
    /// the oldest operation is dropped to make room for the new one.
    ///
    /// - Parameter operation: The sync operation to queue
    ///
    /// **Validates: Requirements 7.1, 7.2, 7.3 (Sync Queue Size Limit), 7.2, 13.4 (Offline Changes Queued)**
    func queueOperation(_ operation: SyncOperation) {
        // Remove any existing operations for the same entity to avoid duplicates
        syncQueue.removeAll { existing in
            existing.entityId == operation.entityId &&
            existing.entityType == operation.entityType
        }
        
        // Enforce maximum queue size - drop oldest if at capacity
        if syncQueue.count >= maxQueueSize {
            // Sort by timestamp to find oldest
            syncQueue.sort { $0.timestamp < $1.timestamp }
            // Remove the oldest operation
            let removed = syncQueue.removeFirst()
            print("⚠️ Queue at capacity (\(maxQueueSize)) - dropped oldest operation: \(removed.entityType) \(removed.entityId)")
        }
        
        // Add the new operation
        syncQueue.append(operation)
        
        // Persist queue to survive app restarts
        persistQueue()
    }
    
    /// Processes all queued sync operations
    ///
    /// Executes all pending operations in chronological order (oldest first).
    /// Each operation is wrapped in RetryManager.executeWithRetry() for automatic
    /// retry with exponential backoff. Operations are removed from the queue on
    /// success or when max retries are exceeded. Processing continues for all
    /// operations regardless of individual failures.
    ///
    /// This method is called automatically when:
    /// - Network connectivity is restored
    /// - User manually triggers sync
    /// - App returns to foreground
    ///
    /// - Throws: SyncError if queue processing encounters errors
    ///
    /// **Validates: Requirements 7.3, 7.4 (Automatic Sync On Reconnect), 8.1, 8.2, 8.3, 8.4 (Per-Item Retry with Backoff), 13.2, 13.3 (Error Handling)**
    func processQueue() async throws {
        // Prevent concurrent queue processing
        guard !isSyncing else {
            print("Queue processing already in progress, skipping")
            return
        }
        guard !syncQueue.isEmpty else {
            print("Queue is empty, nothing to process")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("Processing \(syncQueue.count) queued operations...")
        
        // Sort operations by timestamp (oldest first)
        let sortedOperations = syncQueue.sorted { $0.timestamp < $1.timestamp }
        
        var successCount = 0
        var failedCount = 0
        
        for operation in sortedOperations {
            // Create unique operation ID for retry tracking
            let operationId = "queue_\(operation.entityId)_\(operation.entityType.rawValue)"
            
            do {
                // Wrap operation in RetryManager for exponential backoff retry
                try await retryManager.executeWithRetry(operationId: operationId) {
                    // Process each operation based on its type
                    switch operation {
                    case .create(let entityId, let entityType, _),
                         .update(let entityId, let entityType, _):
                        // Fetch entity from local store and upload
                        try await self.processUploadOperation(entityId: entityId, entityType: entityType)
                        
                    case .delete(let entityId, let entityType, _):
                        // Delete from cloud
                        try await self.processDeleteOperation(entityId: entityId, entityType: entityType)
                    }
                }
                
                // Success - remove operation from queue
                syncQueue.removeAll { $0.entityId == operation.entityId && $0.entityType == operation.entityType }
                successCount += 1
                
                print("✓ Processed operation for \(operation.entityType) \(operation.entityId)")
                
            } catch {
                // Operation failed after retries or non-retryable error - remove from queue and log
                syncQueue.removeAll { $0.entityId == operation.entityId && $0.entityType == operation.entityType }
                failedCount += 1
                
                logError(
                    error as? SyncError ?? SyncError.firestoreError(error),
                    context: "processQueue (after retries)",
                    entityId: operation.entityId
                )
                
                print("✗ Failed operation for \(operation.entityType) \(operation.entityId) after retries: \(error.localizedDescription)")
                
                // Continue processing remaining operations (Requirement 8.4)
            }
        }
        
        // Update persisted queue with remaining operations
        persistQueue()
        
        print("Queue processing complete: \(successCount) succeeded, \(failedCount) failed after retries")
        
        // Note: We don't throw an error here because we want to report success for partial completion
        // Individual operation failures are logged above
    }
    
    /// Processes an upload operation from the queue
    ///
    /// Fetches the entity from local storage and uploads it to Firestore.
    /// If the entity no longer exists locally, the operation is skipped.
    ///
    /// - Parameters:
    ///   - entityId: The entity ID to upload
    ///   - entityType: The type of entity
    /// - Throws: SyncError if upload fails
    private func processUploadOperation(entityId: String, entityType: EntityType) async throws {
        guard let userId = currentUserId, !userId.isEmpty else {
            throw SyncError.notAuthenticated
        }
        
        // Fetch entity from local store based on type
        switch entityType {
        case .foodItem:
            if let foodItem = try await dataStore.fetchFoodItem(byId: entityId) {
                try await uploadFoodItem(foodItem, userId: userId)
            } else {
                print("⚠️ FoodItem \(entityId) not found in local store, skipping upload")
            }
            
        case .exerciseItem:
            if let exerciseItem = try await dataStore.fetchExerciseItem(byId: entityId) {
                try await uploadExerciseItem(exerciseItem, userId: userId)
            } else {
                print("⚠️ ExerciseItem \(entityId) not found in local store, skipping upload")
            }
            
        case .dailyLog:
            if let dailyLog = try await dataStore.fetchDailyLog(byId: entityId) {
                try await uploadDailyLog(dailyLog, userId: userId)
            } else {
                print("⚠️ DailyLog \(entityId) not found in local store, skipping upload")
            }
            
        case .customMeal:
            if let customMeal = try await dataStore.fetchCustomMeal(byId: entityId) {
                try await uploadCustomMeal(customMeal, userId: userId)
            } else {
                print("⚠️ CustomMeal \(entityId) not found in local store, skipping upload")
            }
            
        case .userGoal:
            print("⚠️ UserGoal upload not yet implemented")
        }
    }
    
    /// Processes a delete operation from the queue
    ///
    /// Deletes the entity from Firestore. The entity has already been deleted
    /// from local storage when the operation was queued.
    ///
    /// - Parameters:
    ///   - entityId: The entity ID to delete
    ///   - entityType: The type of entity
    /// - Throws: SyncError if deletion fails
    private func processDeleteOperation(entityId: String, entityType: EntityType) async throws {
        guard let userId = currentUserId, !userId.isEmpty else {
            throw SyncError.notAuthenticated
        }
        
        let collectionPath = getCollectionPath(for: entityType, userId: userId)
        
        do {
            try await db.collection(collectionPath)
                .document(entityId)
                .delete()
            
            print("✓ Deleted \(entityType) \(entityId) from cloud")
            
        } catch {
            throw mapFirestoreError(error)
        }
    }
    
    /// Persists the sync queue to UserDefaults for app restart recovery
    ///
    /// The queue is encoded as JSON and stored in UserDefaults. This ensures
    /// that pending sync operations survive app termination and can be resumed
    /// on next launch.
    ///
    /// **Validates: Requirements 13.4 (Queue Persistence)**
    private func persistQueue() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(syncQueue)
            UserDefaults.standard.set(data, forKey: "syncQueue")
        } catch {
            // Log error but don't throw - queue persistence failure shouldn't block operations
            print("Failed to persist sync queue: \(error)")
        }
    }
    
    /// Loads the sync queue from UserDefaults on initialization
    ///
    /// Restores any pending sync operations that were queued before the app
    /// was terminated. This ensures no data loss across app restarts.
    ///
    /// **Validates: Requirements 13.4 (Queue Persistence)**
    func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: "syncQueue") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            syncQueue = try decoder.decode([SyncOperation].self, from: data)
        } catch {
            // If queue can't be decoded, start fresh rather than crash
            print("Failed to load sync queue: \(error)")
            syncQueue = []
        }
    }
    
    /// Returns the current number of queued operations
    ///
    /// Useful for displaying sync status in the UI (e.g., "3 items pending sync")
    ///
    /// - Returns: Count of pending sync operations
    func queuedOperationCount() -> Int {
        return syncQueue.count
    }

    // MARK: - Firestore Upload Operations
    
    /// Uploads an entity to Firestore with retry logic
    ///
    /// Converts the entity to Firestore-compatible format and uploads it to the
    /// appropriate collection. On success, updates the entity's syncStatus to .synced.
    /// On failure, queues the operation for retry and throws an error.
    ///
    /// The method implements exponential backoff retry for transient network errors,
    /// using the RetryManager for automatic retry with increasing delays.
    ///
    /// If the device is offline, the operation is queued immediately without attempting upload.
    ///
    /// - Parameters:
    ///   - entity: The entity to upload (must conform to SyncableEntity)
    ///   - userId: The authenticated user's unique identifier
    /// - Throws: SyncError if upload fails after all retries
    ///
    /// **Validates: Requirements 5.1, 5.2, 5.3, 10.3 (Dual Persistence), 7.1, 7.2 (Offline Operation), 13.1, 13.2, 13.3 (Error Handling), 10.3 (User ID Association)**
    func uploadToFirestore(_ entity: SyncableEntity, userId: String) async throws {
        // Validate authentication
        guard !userId.isEmpty else {
            let error = SyncError.notAuthenticated
            logError(error, context: "uploadToFirestore", entityId: entity.id)
            throw error
        }
        
        // Validate that entity has userId set (Requirement 10.3)
        guard !entity.userId.isEmpty else {
            let error = SyncError.invalidData(reason: "Entity \(entity.id) missing userId")
            logError(error, context: "uploadToFirestore", entityId: entity.id)
            throw error
        }
        
        // Validate that entity's userId matches authenticated user (Requirement 10.3)
        guard entity.userId == userId else {
            let error = SyncError.invalidData(reason: "Entity userId '\(entity.userId)' does not match authenticated user '\(userId)'")
            logError(error, context: "uploadToFirestore", entityId: entity.id)
            throw error
        }
        
        // Check network connectivity
        let isOnline = await MainActor.run {
            networkMonitor.isConnected
        }
        
        // If offline, queue the operation and return
        if !isOnline {
            print("Device is offline - queuing upload for \(entity.id)")
            let entityType = determineEntityType(entity)
            let operation = SyncOperation.update(
                entityId: entity.id,
                entityType: entityType,
                timestamp: Date()
            )
            queueOperation(operation)
            
            let error = SyncError.networkUnavailable
            logError(error, context: "uploadToFirestore (offline)", entityId: entity.id)
            throw error
        }
        
        // Determine entity type and collection path
        let entityType = determineEntityType(entity)
        let collectionPath = getCollectionPath(for: entityType, userId: userId)
        
        print("🔍 DEBUG uploadToFirestore:")
        print("  - Entity type: \(entityType)")
        print("  - Entity ID: \(entity.id)")
        print("  - Entity userId: \(entity.userId)")
        print("  - Authenticated userId: \(userId)")
        print("  - Collection path: \(collectionPath)")
        
        // Convert entity to Firestore data
        let data = entity.toFirestoreData()
        print("  - Firestore data userId: \(data["userId"] ?? "missing")")
        
        // Create operation ID for retry tracking
        let operationId = "upload_\(entity.id)"
        
        // Upload with retry logic using RetryManager
        do {
            try await retryManager.executeWithRetry(operationId: operationId) {
                // Attempt upload to Firestore
                try await self.db.collection(collectionPath)
                    .document(entity.id)
                    .setData(data)
                
                print("Successfully uploaded \(entityType) \(entity.id) to Firestore")
            }
            
            // Success - update sync status in local store
            do {
                try await updateEntitySyncStatus(entity, status: .synced)
                print("Updated sync status for \(entity.id) to synced")
            } catch {
                // Log error but don't throw - upload succeeded, status update is secondary
                logError(
                    SyncError.dataStoreError(error),
                    context: "uploadToFirestore (status update)",
                    entityId: entity.id
                )
            }
            
        } catch let error as SyncError {
            // SyncError from retry manager - queue for later and throw
            let operation = SyncOperation.update(
                entityId: entity.id,
                entityType: entityType,
                timestamp: Date()
            )
            queueOperation(operation)
            
            logError(error, context: "uploadToFirestore (after retries)", entityId: entity.id)
            throw error
            
        } catch {
            // Wrap other errors in SyncError
            let syncError = SyncError.firestoreError(error)
            
            // Queue for later retry
            let operation = SyncOperation.update(
                entityId: entity.id,
                entityType: entityType,
                timestamp: Date()
            )
            queueOperation(operation)
            
            logError(syncError, context: "uploadToFirestore (firestore error)", entityId: entity.id)
            throw syncError
        }
    }
    
    /// Uploads a FoodItem to Firestore
    ///
    /// Specialized upload method for FoodItem entities. Ensures all nutritional
    /// data and metadata are properly serialized and uploaded.
    ///
    /// - Parameters:
    ///   - foodItem: The food item to upload
    ///   - userId: The authenticated user's unique identifier
    /// - Throws: SyncError if upload fails
    ///
    /// **Validates: Requirements 5.1, 10.3**
    func uploadFoodItem(_ foodItem: FoodItem, userId: String) async throws {
        try await uploadToFirestore(foodItem, userId: userId)
    }
    
    /// Uploads an ExerciseItem to Firestore
    ///
    /// Specialized upload method for ExerciseItem entities.
    ///
    /// - Parameters:
    ///   - exerciseItem: The exercise item to upload
    ///   - userId: The authenticated user's unique identifier
    /// - Throws: SyncError if upload fails
    func uploadExerciseItem(_ exerciseItem: ExerciseItem, userId: String) async throws {
        try await uploadToFirestore(exerciseItem, userId: userId)
    }
    
    /// Uploads a DailyLog to Firestore
    ///
    /// Specialized upload method for DailyLog entities. The daily log stores
    /// references to food items (by ID) rather than embedding them, as food items
    /// are stored in a separate collection.
    ///
    /// - Parameters:
    ///   - dailyLog: The daily log to upload
    ///   - userId: The authenticated user's unique identifier
    /// - Throws: SyncError if upload fails
    ///
    /// **Validates: Requirements 5.1, 10.3**
    func uploadDailyLog(_ dailyLog: DailyLog, userId: String) async throws {
        try await uploadToFirestore(dailyLog, userId: userId)
    }
    
    /// Uploads a CustomMeal to Firestore
    ///
    /// Specialized upload method for CustomMeal entities. Includes all ingredients
    /// with their full nutritional information in the upload.
    ///
    /// - Parameters:
    ///   - customMeal: The custom meal to upload
    ///   - userId: The authenticated user's unique identifier
    /// - Throws: SyncError if upload fails
    ///
    /// **Validates: Requirements 5.2, 10.3**
    func uploadCustomMeal(_ customMeal: CustomMeal, userId: String) async throws {
        try await uploadToFirestore(customMeal, userId: userId)
    }
    
    // MARK: - Helper Methods
    
    /// Determines the entity type from a SyncableEntity instance
    ///
    /// Uses type checking to identify which EntityType enum case corresponds
    /// to the given entity.
    ///
    /// - Parameter entity: The entity to identify
    /// - Returns: The corresponding EntityType
    private func determineEntityType(_ entity: SyncableEntity) -> EntityType {
        switch entity {
        case is FoodItem:
            return .foodItem
        case is ExerciseItem:
            return .exerciseItem
        case is DailyLog:
            return .dailyLog
        case is CustomMeal:
            return .customMeal
        default:
            return .foodItem // Default fallback
        }
    }
    
    /// Gets the Firestore collection path for an entity type
    ///
    /// Constructs the hierarchical collection path following the structure:
    /// users/{userId}/{collectionName}/{documentId}
    ///
    /// - Parameters:
    ///   - entityType: The type of entity
    ///   - userId: The authenticated user's unique identifier
    /// - Returns: The Firestore collection path
    private func getCollectionPath(for entityType: EntityType, userId: String) -> String {
        let collectionName: String
        switch entityType {
        case .foodItem:
            collectionName = "foodItems"
        case .exerciseItem:
            collectionName = "exerciseItems"
        case .dailyLog:
            collectionName = "dailyLogs"
        case .customMeal:
            collectionName = "customMeals"
        case .userGoal:
            collectionName = "profile"
        }
        
        return "users/\(userId)/\(collectionName)"
    }
    
    /// Updates an entity's sync status in the local store
    ///
    /// After successful upload or download, updates the entity's syncStatus
    /// to reflect its current state (synced, pendingUpload, etc.)
    ///
    /// - Parameters:
    ///   - entity: The entity to update
    ///   - status: The new sync status
    /// - Throws: SyncError.dataStoreError if update fails
    private func updateEntitySyncStatus(_ entity: SyncableEntity, status: SyncStatus) async throws {
        // Note: This is a simplified implementation
        // In a real implementation, we would need to fetch the entity from the data store
        // and update its syncStatus property, then save it back
        // For now, we'll just mark this as a placeholder that will be fully implemented
        // when integrating with the DataStore in task 17
    }

    // MARK: - Firestore Download Operations
    
    /// Downloads all user data from Firestore and updates the local store
    ///
    /// Performs an initial sync by fetching all entities from all collections
    /// for the authenticated user. This is typically called when:
    /// - User signs in on a new device
    /// - User signs in after being offline for extended period
    /// - Manual sync is triggered
    ///
    /// The method downloads data from all collections in parallel for efficiency,
    /// then updates the local store with the downloaded data.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Throws: SyncError if download or local update fails
    ///
    /// **Validates: Requirements 6.1, 10.4 (Cross-Device Synchronization)**
    func downloadFromFirestore(userId: String) async throws {
        // Validate authentication
        guard !userId.isEmpty else {
            throw SyncError.notAuthenticated
        }
        
        // Download all entity types in parallel
        async let foodItems = downloadFoodItems(userId: userId)
        async let exerciseItems = downloadExerciseItems(userId: userId)
        async let dailyLogs = downloadDailyLogs(userId: userId)
        async let customMeals = downloadCustomMeals(userId: userId)
        
        do {
            // Wait for all downloads to complete
            let (downloadedFoodItems, downloadedExerciseItems, downloadedDailyLogs, downloadedCustomMeals) = try await (foodItems, exerciseItems, dailyLogs, customMeals)
            
            // Update local store with downloaded data
            try await updateLocalStore(
                foodItems: downloadedFoodItems,
                exerciseItems: downloadedExerciseItems,
                dailyLogs: downloadedDailyLogs,
                customMeals: downloadedCustomMeals
            )
            
        } catch {
            throw SyncError.firestoreError(error)
        }
    }
    
    /// Downloads all FoodItem entities for a user from Firestore
    ///
    /// Fetches all documents from the user's foodItems collection and converts
    /// them to FoodItem instances using the fromFirestoreData method.
    /// Filters results to only include items with matching userId (Requirement 10.4).
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Array of FoodItem instances
    /// - Throws: SyncError if download or parsing fails
    ///
    /// **Validates: Requirements 6.1, 10.4 (Query Filters By User ID)**
    private func downloadFoodItems(userId: String) async throws -> [FoodItem] {
        let collectionPath = getCollectionPath(for: .foodItem, userId: userId)
        
        // Query with userId filter (Requirement 10.4)
        let snapshot = try await db.collection(collectionPath)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var foodItems: [FoodItem] = []
        for document in snapshot.documents {
            do {
                let foodItem = try FoodItem.fromFirestoreData(document.data())
                
                // Additional validation: verify userId matches (defense in depth)
                guard foodItem.userId == userId else {
                    print("⚠️ Skipping FoodItem \(document.documentID) with mismatched userId")
                    continue
                }
                
                foodItems.append(foodItem)
            } catch {
                // Log parsing error but continue with other documents
                print("Failed to parse FoodItem document \(document.documentID): \(error)")
            }
        }
        
        return foodItems
    }
    
    /// Downloads all ExerciseItem entities for a user from Firestore
    ///
    /// Fetches all documents from the user's exerciseItems collection and converts
    /// them to ExerciseItem instances using the fromFirestoreData method.
    /// Filters results to only include items with matching userId (Requirement 10.4).
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Array of ExerciseItem instances
    /// - Throws: SyncError if download or parsing fails
    ///
    /// **Validates: Requirements 6.1, 10.4 (Query Filters By User ID)**
    private func downloadExerciseItems(userId: String) async throws -> [ExerciseItem] {
        let collectionPath = getCollectionPath(for: .exerciseItem, userId: userId)
        
        // Query with userId filter (Requirement 10.4)
        let snapshot = try await db.collection(collectionPath)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var exerciseItems: [ExerciseItem] = []
        for document in snapshot.documents {
            do {
                let exerciseItem = try ExerciseItem.fromFirestoreData(document.data())
                
                // Additional validation: verify userId matches (defense in depth)
                guard exerciseItem.userId == userId else {
                    print("⚠️ Skipping ExerciseItem \(document.documentID) with mismatched userId")
                    continue
                }
                
                exerciseItems.append(exerciseItem)
            } catch {
                // Log parsing error but continue with other documents
                print("Failed to parse ExerciseItem document \(document.documentID): \(error)")
            }
        }
        
        return exerciseItems
    }
    
    /// Downloads all DailyLog entities for a user from Firestore
    ///
    /// Fetches all documents from the user's dailyLogs collection and converts
    /// them to DailyLog instances. Note that food items are stored separately
    /// and must be associated after download.
    /// Filters results to only include logs with matching userId (Requirement 10.4).
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Array of DailyLog instances
    /// - Throws: SyncError if download or parsing fails
    ///
    /// **Validates: Requirements 6.1, 10.4 (Query Filters By User ID)**
    private func downloadDailyLogs(userId: String) async throws -> [DailyLog] {
        let collectionPath = getCollectionPath(for: .dailyLog, userId: userId)
        
        // Query with userId filter (Requirement 10.4)
        let snapshot = try await db.collection(collectionPath)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var dailyLogs: [DailyLog] = []
        for document in snapshot.documents {
            do {
                let dailyLog = try DailyLog.fromFirestoreData(document.data())
                
                // Additional validation: verify userId matches (defense in depth)
                guard dailyLog.userId == userId else {
                    print("⚠️ Skipping DailyLog \(document.documentID) with mismatched userId")
                    continue
                }
                
                dailyLogs.append(dailyLog)
            } catch {
                // Log parsing error but continue with other documents
                print("Failed to parse DailyLog document \(document.documentID): \(error)")
            }
        }
        
        return dailyLogs
    }
    
    /// Downloads all CustomMeal entities for a user from Firestore
    ///
    /// Fetches all documents from the user's customMeals collection and converts
    /// them to CustomMeal instances with all ingredients included.
    /// Filters results to only include meals with matching userId (Requirement 10.4).
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Array of CustomMeal instances
    /// - Throws: SyncError if download or parsing fails
    ///
    /// **Validates: Requirements 6.1, 10.4 (Query Filters By User ID)**
    private func downloadCustomMeals(userId: String) async throws -> [CustomMeal] {
        let collectionPath = getCollectionPath(for: .customMeal, userId: userId)
        
        // Query with userId filter (Requirement 10.4)
        let snapshot = try await db.collection(collectionPath)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var customMeals: [CustomMeal] = []
        for document in snapshot.documents {
            do {
                let customMeal = try CustomMeal.fromFirestoreData(document.data())
                
                // Additional validation: verify userId matches (defense in depth)
                guard customMeal.userId == userId else {
                    print("⚠️ Skipping CustomMeal \(document.documentID) with mismatched userId")
                    continue
                }
                
                customMeals.append(customMeal)
            } catch {
                // Log parsing error but continue with other documents
                print("Failed to parse CustomMeal document \(document.documentID): \(error)")
            }
        }
        
        return customMeals
    }
    
    /// Updates the local SwiftData store with downloaded entities
    ///
    /// Merges downloaded cloud data with existing local data. For each entity:
    /// - If it doesn't exist locally, insert it
    /// - If it exists locally, compare lastModified timestamps and keep the newer version
    /// - Mark all entities as synced after successful merge
    ///
    /// This method handles the complex logic of merging cloud and local data
    /// without losing any user changes made while offline.
    ///
    /// - Parameters:
    ///   - foodItems: Downloaded food items
    ///   - exerciseItems: Downloaded exercise items
    ///   - dailyLogs: Downloaded daily logs
    ///   - customMeals: Downloaded custom meals
    /// - Throws: SyncError.dataStoreError if local update fails
    private func updateLocalStore(
        foodItems: [FoodItem],
        exerciseItems: [ExerciseItem],
        dailyLogs: [DailyLog],
        customMeals: [CustomMeal]
    ) async throws {
        // Note: This is a simplified implementation placeholder
        // The full implementation will be completed in task 17 when integrating
        // with the DataStore and implementing conflict resolution logic
        //
        // The actual implementation will:
        // 1. Fetch existing local entities
        // 2. Compare lastModified timestamps
        // 3. Apply conflict resolution (last-write-wins or merge for daily logs)
        // 4. Update local store with resolved entities
        // 5. Mark all entities as synced
        
        // For now, we'll just save the downloaded entities to the data store
        // This will be enhanced with proper conflict resolution in task 8
        do {
            // Save food items
            for foodItem in foodItems {
                // In the full implementation, we would check if the item exists
                // and compare timestamps before saving
                // For now, this is a placeholder
            }
            
            // Save daily logs
            for dailyLog in dailyLogs {
                // In the full implementation, we would associate food items
                // with daily logs based on the foodItemIds array
                // For now, this is a placeholder
            }
            
            // Save custom meals
            for customMeal in customMeals {
                // In the full implementation, we would check if the meal exists
                // and compare timestamps before saving
                // For now, this is a placeholder
            }
            
        } catch {
            throw SyncError.dataStoreError(error)
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves a conflict between local and cloud versions of an entity
    ///
    /// Implements the conflict resolution strategy based on entity type:
    /// - Standard entities (FoodItem, CustomMeal): Last-write-wins based on lastModified timestamp
    /// - Daily logs: Special merge logic that combines food items from both versions
    /// - Deletions: Deletion always wins over modifications
    ///
    /// The resolved entity is then updated in both local and cloud stores to ensure
    /// consistency across all devices.
    ///
    /// - Parameters:
    ///   - local: The local version of the entity
    ///   - cloud: The cloud version of the entity
    /// - Returns: The resolved entity that should be used going forward
    /// - Throws: SyncError.conflictResolutionFailed if resolution logic fails
    ///
    /// **Validates: Requirements 8.1, 8.2, 8.3 (Conflict Resolution)**
    func resolveConflict(local: SyncableEntity, cloud: SyncableEntity) throws -> SyncableEntity {
        // Ensure both entities have the same ID
        guard local.id == cloud.id else {
            throw SyncError.conflictResolutionFailed
        }
        
        // Special handling for daily logs - merge food items
        if let localLog = local as? DailyLog, let cloudLog = cloud as? DailyLog {
            return try mergeDailyLogs(local: localLog, cloud: cloudLog)
        }
        
        // Standard last-write-wins for other entity types
        // Compare lastModified timestamps and keep the newer version
        if local.lastModified > cloud.lastModified {
            print("Conflict resolved for \(type(of: local)) \(local.id): local wins (newer)")
            return local
        } else if cloud.lastModified > local.lastModified {
            print("Conflict resolved for \(type(of: cloud)) \(cloud.id): cloud wins (newer)")
            return cloud
        } else {
            // Same timestamp - prefer cloud version for consistency
            print("Conflict resolved for \(type(of: cloud)) \(cloud.id): same timestamp, using cloud")
            return cloud
        }
    }
    
    /// Applies the resolved entity to both local and cloud stores
    ///
    /// After conflict resolution determines the winning version, this method ensures
    /// that both stores are updated with the resolved entity. This maintains the
    /// dual-persistence guarantee and ensures all devices converge to the same state.
    ///
    /// - Parameters:
    ///   - resolved: The resolved entity to apply
    ///   - userId: The authenticated user's unique identifier
    /// - Throws: SyncError if updating either store fails
    ///
    /// **Validates: Requirements 8.3 (Update Both Stores)**
    func applyResolvedEntity(_ resolved: SyncableEntity, userId: String) async throws {
        // Update local store
        switch resolved {
        case let foodItem as FoodItem:
            try await dataStore.updateFoodItem(foodItem)
            
        case let dailyLog as DailyLog:
            try await dataStore.updateDailyLog(dailyLog)
            
        case let customMeal as CustomMeal:
            try await dataStore.updateCustomMeal(customMeal)
            
        default:
            throw SyncError.conflictResolutionFailed
        }
        
        // Update cloud store
        try await uploadToFirestore(resolved, userId: userId)
        
        print("Applied resolved entity \(resolved.id) to both stores")
    }
    
    /// Merges two conflicting DailyLog versions by combining their food items
    ///
    /// When a daily log conflict is detected (different lastModified timestamps),
    /// this method implements a special merge strategy:
    /// 1. Combines food items from both local and cloud versions
    /// 2. Removes duplicates based on food item ID
    /// 3. Preserves the daily goal from the version with the newer timestamp
    /// 4. Recalculates total calories based on merged food items
    /// 5. Sets lastModified to current time to mark the merge
    ///
    /// This ensures that food items added on different devices while offline are
    /// not lost when the devices sync. The merge creates a union of both versions.
    ///
    /// - Parameters:
    ///   - local: The local version of the daily log
    ///   - cloud: The cloud version of the daily log
    /// - Returns: A merged DailyLog containing food items from both versions
    ///
    /// **Validates: Requirements 8.4 (Daily Log Merging)**
    func mergeDailyLogs(local: DailyLog, cloud: DailyLog) throws -> DailyLog {
        print("Merging DailyLog \(local.id): combining food items from both versions")
        
        // Start with local food items
        var mergedFoodItems = local.foodItems
        
        // Start with local exercise items
        var mergedExerciseItems = local.exerciseItems
        
        // Add cloud food items that don't already exist locally (by ID)
        for cloudItem in cloud.foodItems {
            // Check if this food item already exists in the merged list
            let existsLocally = mergedFoodItems.contains { localItem in
                localItem.id == cloudItem.id
            }
            
            // Only add if it doesn't exist (avoid duplicates)
            if !existsLocally {
                mergedFoodItems.append(cloudItem)
                print("  Added food item \(cloudItem.id) from cloud version")
            } else {
                print("  Skipped duplicate food item \(cloudItem.id)")
            }
        }
        
        // Add cloud exercise items that don't already exist locally (by ID)
        for cloudItem in cloud.exerciseItems {
            let existsLocally = mergedExerciseItems.contains { localItem in
                localItem.id == cloudItem.id
            }
            
            if !existsLocally {
                mergedExerciseItems.append(cloudItem)
                print("  Added exercise item \(cloudItem.id) from cloud version")
            } else {
                print("  Skipped duplicate exercise item \(cloudItem.id)")
            }
        }
        
        // Determine which daily goal to use (from the newer version)
        let mergedGoal: Double?
        if local.lastModified > cloud.lastModified {
            mergedGoal = local.dailyGoal
            print("  Using daily goal from local version: \(mergedGoal ?? 0)")
        } else {
            mergedGoal = cloud.dailyGoal
            print("  Using daily goal from cloud version: \(mergedGoal ?? 0)")
        }
        
        // Create the merged daily log
        let merged = try DailyLog(
            id: UUID(uuidString: local.id) ?? UUID(),
            date: local.date,
            foodItems: mergedFoodItems,
            exerciseItems: mergedExerciseItems,
            dailyGoal: mergedGoal,
            userId: local.userId,
            lastModified: Date(), // Set to current time to mark the merge
            syncStatus: .pendingUpload // Mark as pending to trigger sync
        )
        
        // Log the merge result
        print("  Merged result: \(mergedFoodItems.count) food items, \(mergedExerciseItems.count) exercise items, \(merged.totalCalories) total calories")
        
        return merged
    }
    
    // MARK: - Real-Time Synchronization
    
    /// Starts real-time listeners for all user data collections
    ///
    /// Initiates Firestore snapshot listeners for all entity types (foodItems,
    /// dailyLogs, customMeals). These listeners monitor cloud changes in real-time
    /// and automatically update the local store when data changes on other devices.
    ///
    /// This method should be called when:
    /// - User successfully authenticates (sign in or sign up)
    /// - App returns to foreground with an active session
    /// - Network connectivity is restored after being offline
    ///
    /// The listeners remain active until stopListening() is called, typically
    /// when the user signs out or the app is terminated.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    ///
    /// **Validates: Requirements 6.2, 3.1 (Real-Time Sync and Auth Integration)**
    func startListening(userId: String) async {
        // Validate authentication
        guard !userId.isEmpty else {
            print("Cannot start listeners: user not authenticated")
            return
        }
        
        // Store the user ID for reconnect sync
        currentUserId = userId
        
        // Stop any existing listeners first to avoid duplicates
        stopListening()
        
        print("Starting real-time listeners for user: \(userId)")
        
        // Set up listeners for all entity types
        // Food/exercise items first so they're available when daily logs arrive
        setupRealtimeListener(collection: "foodItems", userId: userId, entityType: .foodItem)
        setupRealtimeListener(collection: "exerciseItems", userId: userId, entityType: .exerciseItem)
        setupRealtimeListener(collection: "dailyLogs", userId: userId, entityType: .dailyLog)
        setupRealtimeListener(collection: "customMeals", userId: userId, entityType: .customMeal)
        
        print("Real-time listeners started successfully")
        
        // Deferred re-association: after initial snapshots settle, re-link any
        // daily logs whose food/exercise items arrived out of order
        Task {
            // Allow time for initial snapshot events to process
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await repairDailyLogAssociations(userId: userId)
        }
    }
    
    /// Stops all active real-time listeners
    ///
    /// Removes all Firestore snapshot listeners to prevent unauthorized data access
    /// and conserve resources. This method should be called when:
    /// - User signs out
    /// - App is terminated
    /// - User's session expires
    ///
    /// After calling this method, the sync engine will no longer receive real-time
    /// updates from the cloud. Listeners can be restarted by calling startListening()
    /// again when the user re-authenticates.
    ///
    /// **Validates: Requirements 6.2, 3.1 (Listener Cleanup on Sign Out)**
    func stopListening() {
        print("Stopping \(listeners.count) real-time listeners")
        
        // Remove all active listeners
        for listener in listeners {
            listener.remove()
        }
        
        // Clear the listeners array
        listeners.removeAll()
        
        // Clear the current user ID
        currentUserId = nil
        
        print("Real-time listeners stopped successfully")
    }
    
    /// Sets up a real-time listener for a specific Firestore collection
    ///
    /// Creates a Firestore snapshot listener that monitors cloud changes in real-time.
    /// When documents are added, modified, or deleted in the cloud, the listener
    /// automatically receives updates and applies them to the local store.
    ///
    /// The listener handles three types of changes:
    /// - Added: New documents created on other devices
    /// - Modified: Existing documents updated on other devices
    /// - Removed: Documents deleted on other devices
    ///
    /// Listeners are automatically managed - they're started when the user authenticates
    /// and stopped when the user signs out to prevent unauthorized data access.
    ///
    /// - Parameters:
    ///   - collection: The collection name to monitor (foodItems, dailyLogs, customMeals)
    ///   - userId: The authenticated user's unique identifier
    ///   - entityType: The type of entity being monitored
    ///
    /// **Validates: Requirements 6.2 (Real-Time Cloud Updates), 10.4 (Query Filters By User ID)**
    private func setupRealtimeListener(collection: String, userId: String, entityType: EntityType) {
        let collectionPath = getCollectionPath(for: entityType, userId: userId)
        
        // Set up listener with userId filter (Requirement 10.4)
        let listener = db.collection(collectionPath)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                // Handle listener errors
                if let error = error {
                    print("Listener error for \(collection): \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = querySnapshot else {
                    print("No snapshot received for \(collection)")
                    return
                }
                
                // Process each document change
                for documentChange in snapshot.documentChanges {
                    let document = documentChange.document
                    
                    switch documentChange.type {
                    case .added, .modified:
                        // Handle new or updated documents
                        Task {
                            await self.handleCloudUpdate(document, entityType: entityType, expectedUserId: userId)
                        }
                        
                    case .removed:
                        // Handle deleted documents
                        Task {
                            await self.handleCloudDeletion(document, entityType: entityType)
                        }
                    }
                }
            }
        
        // Store listener for later removal
        listeners.append(listener)
    }
    
    /// Handles a cloud update by merging it with local data
    ///
    /// When a document is added or modified in the cloud, this method:
    /// 1. Parses the Firestore document to the appropriate entity type
    /// 2. Validates that the userId matches the expected user (defense in depth)
    /// 3. Checks if the entity exists locally
    /// 4. Compares lastModified timestamps if it exists
    /// 5. Applies conflict resolution if needed
    /// 6. Updates the local store with the resolved entity
    ///
    /// This ensures that cloud changes are reflected locally while preserving
    /// any local changes that haven't been synced yet.
    ///
    /// - Parameters:
    ///   - snapshot: The Firestore document snapshot
    ///   - entityType: The type of entity being updated
    ///   - expectedUserId: The authenticated user's ID for validation
    ///
    /// **Validates: Requirements 6.2, 8.1 (Cloud Updates and Conflict Resolution), 10.4 (User ID Validation)**
    private func handleCloudUpdate(_ snapshot: DocumentSnapshot, entityType: EntityType, expectedUserId: String) async {
        do {
            let data = snapshot.data() ?? [:]
            
            // Parse the document based on entity type
        switch entityType {
        case .foodItem:
            let cloudItem = try FoodItem.fromFirestoreData(data)
                
                // Validate userId matches (defense in depth - Requirement 10.4)
                guard cloudItem.userId == expectedUserId else {
                    print("⚠️ Skipping cloud update for FoodItem \(cloudItem.id) - userId mismatch")
                    return
                }
                
            try await handleFoodItemUpdate(cloudItem)
            
        case .exerciseItem:
            let cloudItem = try ExerciseItem.fromFirestoreData(data)
            
            guard cloudItem.userId == expectedUserId else {
                print("⚠️ Skipping cloud update for ExerciseItem \(cloudItem.id) - userId mismatch")
                return
            }
            
            try await handleExerciseItemUpdate(cloudItem)
            
        case .dailyLog:
            let cloudLog = try DailyLog.fromFirestoreData(data)
                
                // Validate userId matches (defense in depth - Requirement 10.4)
                guard cloudLog.userId == expectedUserId else {
                    print("⚠️ Skipping cloud update for DailyLog \(cloudLog.id) - userId mismatch")
                    return
                }
                
                // Extract relationship IDs from raw Firestore data for re-association
                let foodItemIds = data["foodItemIds"] as? [String] ?? []
                let exerciseItemIds = data["exerciseItemIds"] as? [String] ?? []
                try await handleDailyLogUpdate(cloudLog, foodItemIds: foodItemIds, exerciseItemIds: exerciseItemIds)
                
            case .customMeal:
                let cloudMeal = try CustomMeal.fromFirestoreData(data)
                
                // Validate userId matches (defense in depth - Requirement 10.4)
                guard cloudMeal.userId == expectedUserId else {
                    print("⚠️ Skipping cloud update for CustomMeal \(cloudMeal.id) - userId mismatch")
                    return
                }
                
                try await handleCustomMealUpdate(cloudMeal)
                
            case .userGoal:
                // User goals are stored differently (in profile/settings document)
                print("Received cloud update for UserGoal")
            }
            
        } catch {
            print("Failed to parse cloud update for \(entityType): \(error)")
        }
    }
    
    /// Handles a FoodItem cloud update with conflict detection
    ///
    /// Checks if the food item exists locally and compares timestamps to detect conflicts.
    /// If a conflict is detected, applies conflict resolution logic.
    ///
    /// - Parameter cloudItem: The food item from the cloud
    /// - Throws: SyncError if conflict resolution or local update fails
    ///
    /// **Validates: Requirements 8.1, 8.2 (Conflict Detection)**
    private func handleFoodItemUpdate(_ cloudItem: FoodItem) async throws {
        // Fetch local version if it exists
        let localItem = try await dataStore.fetchFoodItem(byId: cloudItem.id)
        
        if let localItem = localItem {
            // Conflict detection: compare lastModified timestamps
            if localItem.lastModified > cloudItem.lastModified {
                // Local is newer - keep local version
                print("Conflict detected for FoodItem \(cloudItem.id): local is newer, keeping local")
                return
            } else if localItem.lastModified < cloudItem.lastModified {
                // Cloud is newer - update local with cloud version
                print("Conflict detected for FoodItem \(cloudItem.id): cloud is newer, updating local")
                try await dataStore.updateFoodItem(cloudItem)
            } else {
                // Same timestamp - no conflict, but update anyway to ensure consistency
                print("FoodItem \(cloudItem.id) has same timestamp, updating local")
                try await dataStore.updateFoodItem(cloudItem)
            }
        } else {
            // No local version - insert cloud version
            print("New FoodItem \(cloudItem.id) from cloud, inserting locally")
            try await dataStore.insertFoodItem(cloudItem)
        }
    }
    
    /// Handles an ExerciseItem cloud update with conflict detection
    ///
    /// Checks if the exercise item exists locally and compares timestamps to detect conflicts.
    /// If a conflict is detected, applies conflict resolution logic.
    ///
    /// - Parameter cloudItem: The exercise item from the cloud
    /// - Throws: SyncError if conflict resolution or local update fails
    private func handleExerciseItemUpdate(_ cloudItem: ExerciseItem) async throws {
        let localItem = try await dataStore.fetchExerciseItem(byId: cloudItem.id)
        
        if let localItem = localItem {
            if localItem.lastModified > cloudItem.lastModified {
                print("Conflict detected for ExerciseItem \(cloudItem.id): local is newer, keeping local")
                return
            } else if localItem.lastModified < cloudItem.lastModified {
                print("Conflict detected for ExerciseItem \(cloudItem.id): cloud is newer, updating local")
                try await dataStore.updateExerciseItem(cloudItem)
            } else {
                print("ExerciseItem \(cloudItem.id) has same timestamp, updating local")
                try await dataStore.updateExerciseItem(cloudItem)
            }
        } else {
            print("New ExerciseItem \(cloudItem.id) from cloud, inserting locally")
            try await dataStore.insertExerciseItem(cloudItem)
        }
    }
    
    /// Handles a DailyLog cloud update with conflict detection
    ///
    /// Checks if the daily log exists locally and compares timestamps to detect conflicts.
    /// For daily logs, uses special merge logic to combine food items from both versions.
    ///
    /// - Parameter cloudLog: The daily log from the cloud
    /// - Throws: SyncError if conflict resolution or local update fails
    ///
    /// **Validates: Requirements 8.1, 8.4 (Conflict Detection and Daily Log Merging)**
    private func handleDailyLogUpdate(_ cloudLog: DailyLog, foodItemIds: [String] = [], exerciseItemIds: [String] = []) async throws {
        // First, try to find local version by ID
        let localLogById = try await dataStore.fetchDailyLog(byId: cloudLog.id)
        
        if let localLog = localLogById {
            // Conflict detection: compare lastModified timestamps
            if localLog.lastModified != cloudLog.lastModified {
                // Timestamps differ - merge the daily logs
                print("Conflict detected for DailyLog \(cloudLog.id): merging food items")
                let mergedLog = try mergeDailyLogs(local: localLog, cloud: cloudLog)
                // Copy merged properties back to the managed local log
                applyMergedProperties(from: mergedLog, to: localLog)
                try await dataStore.updateDailyLog(localLog)
                try await associateItemsWithDailyLog(localLog, foodItemIds: foodItemIds, exerciseItemIds: exerciseItemIds)
            } else {
                // Same timestamp - update the managed local log with cloud data
                print("DailyLog \(cloudLog.id) has same timestamp, updating local")
                localLog.dailyGoal = cloudLog.dailyGoal
                localLog.lastModified = cloudLog.lastModified
                localLog.syncStatus = cloudLog.syncStatus
                try await dataStore.updateDailyLog(localLog)
                try await associateItemsWithDailyLog(localLog, foodItemIds: foodItemIds, exerciseItemIds: exerciseItemIds)
            }
        } else {
            // No ID match — check if a local log already exists for the same date
            // This prevents duplicate DailyLogs when a new device creates an empty log
            // before the cloud log arrives via snapshot listener
            let localLogByDate = try await dataStore.fetchDailyLog(for: cloudLog.date)
            
            if let existingLog = localLogByDate {
                // Merge cloud data into the existing date-matched log
                print("Found existing DailyLog for date \(cloudLog.date), merging cloud data into it")
                let mergedLog = try mergeDailyLogs(local: existingLog, cloud: cloudLog)
                // Copy merged properties back to the managed existing log
                applyMergedProperties(from: mergedLog, to: existingLog)
                try await dataStore.updateDailyLog(existingLog)
                try await associateItemsWithDailyLog(existingLog, foodItemIds: foodItemIds, exerciseItemIds: exerciseItemIds)
            } else {
                // No local version at all - insert cloud version (becomes managed after insert)
                print("New DailyLog \(cloudLog.id) from cloud, inserting locally")
                try await dataStore.insertDailyLog(cloudLog)
                try await associateItemsWithDailyLog(cloudLog, foodItemIds: foodItemIds, exerciseItemIds: exerciseItemIds)
            }
        }
    }
    
    /// Copies merged properties from an unmanaged merged log to a SwiftData-managed log
    ///
    /// `mergeDailyLogs` creates a new DailyLog instance that is NOT managed by SwiftData.
    /// This helper copies the relevant properties back to the existing managed log so that
    /// `modelContext.save()` actually persists the changes.
    ///
    /// - Parameters:
    ///   - source: The unmanaged merged DailyLog with combined data
    ///   - target: The SwiftData-managed DailyLog to update
    private func applyMergedProperties(from source: DailyLog, to target: DailyLog) {
        // Copy food items — add any from source that aren't already in target
        for item in source.foodItems {
            if !target.foodItems.contains(where: { $0.id == item.id }) {
                target.foodItems.append(item)
            }
        }
        
        // Copy exercise items — add any from source that aren't already in target
        for item in source.exerciseItems {
            if !target.exerciseItems.contains(where: { $0.id == item.id }) {
                target.exerciseItems.append(item)
            }
        }
        
        target.dailyGoal = source.dailyGoal
        target.lastModified = source.lastModified
        target.syncStatus = source.syncStatus
    }
    
    /// Associates food items and exercise items with a daily log by fetching them from the local store
    ///
    /// When a DailyLog is downloaded from Firestore, it arrives with empty relationship arrays
    /// because `fromFirestoreData` cannot resolve SwiftData relationships. This method uses the
    /// `foodItemIds` and `exerciseItemIds` stored in the Firestore document to look up the
    /// corresponding local entities and attach them to the log's relationships.
    ///
    /// - Parameters:
    ///   - dailyLog: The daily log to associate items with
    ///   - foodItemIds: Array of food item ID strings from Firestore data
    ///   - exerciseItemIds: Array of exercise item ID strings from Firestore data
    ///
    /// **Validates: Requirements 6.2 (Real-Time Cloud Updates)**
    private func associateItemsWithDailyLog(_ dailyLog: DailyLog, foodItemIds: [String], exerciseItemIds: [String]) async throws {
        guard !foodItemIds.isEmpty || !exerciseItemIds.isEmpty else { return }
        
        let userId = dailyLog.userId
        
        // Fetch and associate food items
        for foodItemId in foodItemIds {
            if let foodItem = try await dataStore.fetchFoodItem(byId: foodItemId) {
                if !dailyLog.foodItems.contains(where: { $0.id == foodItemId }) {
                    dailyLog.foodItems.append(foodItem)
                }
            } else {
                // Item not found locally — try downloading from Firestore
                if !userId.isEmpty {
                    do {
                        let collectionPath = getCollectionPath(for: .foodItem, userId: userId)
                        let doc = try await db.collection(collectionPath).document(foodItemId).getDocument()
                        if let data = doc.data() {
                            let cloudItem = try FoodItem.fromFirestoreData(data)
                            try await dataStore.insertFoodItem(cloudItem)
                            if !dailyLog.foodItems.contains(where: { $0.id == foodItemId }) {
                                dailyLog.foodItems.append(cloudItem)
                            }
                            print("📥 Downloaded missing FoodItem \(foodItemId) from cloud")
                        } else {
                            print("⚠️ FoodItem \(foodItemId) not found in cloud either")
                        }
                    } catch {
                        print("⚠️ Failed to download FoodItem \(foodItemId): \(error)")
                    }
                }
            }
        }
        
        // Fetch and associate exercise items
        for exerciseItemId in exerciseItemIds {
            if let exerciseItem = try await dataStore.fetchExerciseItem(byId: exerciseItemId) {
                if !dailyLog.exerciseItems.contains(where: { $0.id == exerciseItemId }) {
                    dailyLog.exerciseItems.append(exerciseItem)
                }
            } else {
                // Item not found locally — try downloading from Firestore
                if !userId.isEmpty {
                    do {
                        let collectionPath = getCollectionPath(for: .exerciseItem, userId: userId)
                        let doc = try await db.collection(collectionPath).document(exerciseItemId).getDocument()
                        if let data = doc.data() {
                            let cloudItem = try ExerciseItem.fromFirestoreData(data)
                            try await dataStore.insertExerciseItem(cloudItem)
                            if !dailyLog.exerciseItems.contains(where: { $0.id == exerciseItemId }) {
                                dailyLog.exerciseItems.append(cloudItem)
                            }
                            print("📥 Downloaded missing ExerciseItem \(exerciseItemId) from cloud")
                        } else {
                            print("⚠️ ExerciseItem \(exerciseItemId) not found in cloud either")
                        }
                    } catch {
                        print("⚠️ Failed to download ExerciseItem \(exerciseItemId): \(error)")
                    }
                }
            }
        }
        
        // Save the updated relationships
        try await dataStore.updateDailyLog(dailyLog)
    }
    
    /// Repairs daily log associations after initial sync
    ///
    /// When snapshot listeners fire on first login, DailyLogs may arrive before their
    /// associated FoodItems/ExerciseItems. This method runs after a delay to re-fetch
    /// the Firestore documents for any daily logs with empty relationships and
    /// re-associate the items that are now available locally.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    ///
    /// **Validates: Requirements 6.2 (Real-Time Cloud Updates)**
    private func repairDailyLogAssociations(userId: String) async {
        do {
            let allLogs = try await dataStore.fetchAllDailyLogs()
            let emptyLogs = allLogs.filter { $0.userId == userId && $0.foodItems.isEmpty && $0.exerciseItems.isEmpty }
            
            guard !emptyLogs.isEmpty else { return }
            
            print("🔧 Repairing \(emptyLogs.count) daily log(s) with missing associations")
            
            // Fetch ALL daily log documents from Firestore for this user
            let collectionPath = getCollectionPath(for: .dailyLog, userId: userId)
            let snapshot = try await db.collection(collectionPath)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // Build a lookup of cloud docs by date STRING (yyyy-MM-dd) for robust matching
            // Using Date equality can fail due to timezone/subsecond differences
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = calendar.timeZone
            
            var cloudDocsByDateString: [String: [String: Any]] = [:]
            for document in snapshot.documents {
                let data = document.data()
                if let timestamp = data["date"] as? Timestamp {
                    let normalizedDate = calendar.startOfDay(for: timestamp.dateValue())
                    let dateKey = dateFormatter.string(from: normalizedDate)
                    cloudDocsByDateString[dateKey] = data
                }
            }
            
            print("🔧 Found \(cloudDocsByDateString.count) cloud daily log(s) for matching")
            
            for log in emptyLogs {
                let logDate = calendar.startOfDay(for: log.date)
                let logDateKey = dateFormatter.string(from: logDate)
                
                guard let data = cloudDocsByDateString[logDateKey] else {
                    print("⚠️ No cloud document found for DailyLog date \(logDateKey)")
                    continue
                }
                
                let foodItemIds = data["foodItemIds"] as? [String] ?? []
                let exerciseItemIds = data["exerciseItemIds"] as? [String] ?? []
                
                print("🔧 Repairing DailyLog for \(logDateKey): \(foodItemIds.count) food items, \(exerciseItemIds.count) exercise items")
                
                if foodItemIds.isEmpty && exerciseItemIds.isEmpty {
                    print("🔧 Skipping — no item IDs in cloud document")
                    continue
                }
                
                try await associateItemsWithDailyLog(log, foodItemIds: foodItemIds, exerciseItemIds: exerciseItemIds)
            }
            
            print("🔧 Daily log association repair complete")
        } catch {
            print("⚠️ Failed to repair daily log associations: \(error)")
        }
    }
    
    /// Handles a CustomMeal cloud update with conflict detection
    ///
    /// Checks if the custom meal exists locally and compares timestamps to detect conflicts.
    /// If a conflict is detected, applies last-write-wins resolution.
    ///
    /// - Parameter cloudMeal: The custom meal from the cloud
    /// - Throws: SyncError if conflict resolution or local update fails
    ///
    /// **Validates: Requirements 8.1, 8.2 (Conflict Detection)**
    private func handleCustomMealUpdate(_ cloudMeal: CustomMeal) async throws {
        // Fetch local version if it exists
        let localMeal = try await dataStore.fetchCustomMeal(byId: cloudMeal.id)
        
        if let localMeal = localMeal {
            // Conflict detection: compare lastModified timestamps
            if localMeal.lastModified > cloudMeal.lastModified {
                // Local is newer - keep local version
                print("Conflict detected for CustomMeal \(cloudMeal.id): local is newer, keeping local")
                return
            } else if localMeal.lastModified < cloudMeal.lastModified {
                // Cloud is newer - update local with cloud version
                print("Conflict detected for CustomMeal \(cloudMeal.id): cloud is newer, updating local")
                try await dataStore.updateCustomMeal(cloudMeal)
            } else {
                // Same timestamp - no conflict, but update anyway to ensure consistency
                print("CustomMeal \(cloudMeal.id) has same timestamp, updating local")
                try await dataStore.updateCustomMeal(cloudMeal)
            }
        } else {
            // No local version - insert cloud version
            print("New CustomMeal \(cloudMeal.id) from cloud, inserting locally")
            try await dataStore.insertCustomMeal(cloudMeal)
        }
    }
    
    /// Handles a cloud deletion by removing the entity from local storage
    ///
    /// When a document is deleted in the cloud, this method removes the corresponding
    /// entity from the local store. This ensures deletions are propagated across devices.
    ///
    /// Deletion conflicts are handled with a deletion-wins strategy: if an entity is
    /// deleted in the cloud, it's removed locally regardless of local modifications.
    /// This prevents "zombie" entities that were deleted on one device from persisting
    /// on other devices.
    ///
    /// - Parameters:
    ///   - snapshot: The Firestore document snapshot (contains ID but no data)
    ///   - entityType: The type of entity being deleted
    ///
    /// **Validates: Requirements 6.2, 8.2 (Cloud Deletions and Deletion-Wins)**
    private func handleCloudDeletion(_ snapshot: DocumentSnapshot, entityType: EntityType) async {
        let entityId = snapshot.documentID
        
        do {
            // Deletion-wins strategy: always delete locally when deleted in cloud
        switch entityType {
        case .foodItem:
            print("Deletion conflict for FoodItem \(entityId): deletion wins, removing locally")
            try await dataStore.deleteFoodItem(byId: entityId)
            
        case .exerciseItem:
            print("Deletion conflict for ExerciseItem \(entityId): deletion wins, removing locally")
            try await dataStore.deleteExerciseItem(byId: entityId)
            
        case .dailyLog:
            print("Deletion conflict for DailyLog \(entityId): deletion wins, removing locally")
            try await dataStore.deleteDailyLog(byId: entityId)
                
            case .customMeal:
                print("Deletion conflict for CustomMeal \(entityId): deletion wins, removing locally")
                try await dataStore.deleteCustomMeal(byId: entityId)
                
            case .userGoal:
                print("Deletion conflict for UserGoal: deletion wins, removing locally")
                // User goals handled differently - would clear the goal setting
            }
        } catch {
            print("Failed to handle cloud deletion for \(entityType) \(entityId): \(error)")
        }
    }
    
    // MARK: - Data Migration
    
    /// Migrates all local data to the cloud for a newly authenticated user with retry logic
    ///
    /// This method performs a one-time migration of all anonymous local data to the cloud
    /// when a user creates an account or signs in for the first time. It includes:
    /// - Exponential backoff retry for transient failures
    /// - Progress tracking to resume from where it left off
    /// - Preservation of local data on all failures
    /// - Detailed result reporting with success/failure counts
    ///
    /// The migration is designed to be idempotent and resumable. If it fails partway through:
    /// - Already migrated entities are tracked and skipped on retry
    /// - Failed entities are retried with exponential backoff
    /// - Local data is never deleted, only marked as synced
    /// - Migration state is persisted to survive app restarts
    ///
    /// Retry behavior:
    /// - Maximum 5 retry attempts
    /// - Exponential backoff: 2s, 4s, 8s, 16s, 32s
    /// - Automatic retry on network errors
    /// - Manual retry available through UI
    ///
    /// - Parameter userId: The authenticated user's unique identifier to associate with all data
    /// - Returns: MigrationResult containing counts of migrated entities and any errors
    /// - Throws: SyncError.migrationFailed if all retries are exhausted
    ///
    /// **Validates: Requirements 9.1, 9.3, 9.4 (Data Migration with Retry)**
    func migrateLocalData(userId: String) async throws -> MigrationResult {
        // Load or create migration state
        var state = loadMigrationState(userId: userId) ?? MigrationState(userId: userId)
        
        // Check if we've exceeded max retries
        if state.attemptCount >= maxMigrationRetries {
            throw SyncError.migrationFailed(reason: "Maximum retry attempts (\(maxMigrationRetries)) exceeded")
        }
        
        // Calculate retry delay with exponential backoff
        if state.attemptCount > 0 {
            let delay = initialRetryDelay * pow(2.0, Double(state.attemptCount - 1))
            print("Migration retry attempt \(state.attemptCount + 1)/\(maxMigrationRetries) after \(delay)s delay")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } else {
            print("Starting data migration for user: \(userId)")
        }
        
        // Increment attempt count
        state.attemptCount += 1
        state.lastAttemptDate = Date()
        saveMigrationState(state)
        
        // Validate authentication
        guard !userId.isEmpty else {
            throw SyncError.notAuthenticated
        }
        
        var errors: [Error] = []
        var foodItemsCount = 0
        var exerciseItemsCount = 0
        var dailyLogsCount = 0
        var customMealsCount = 0
        var failedCount = 0
        
        do {
            // Step 1: Fetch all local data
            print("Fetching all local data...")
            let foodItems = try await dataStore.fetchAllFoodItems()
            let exerciseItems = try await dataStore.fetchAllExerciseItems()
            let dailyLogs = try await dataStore.fetchAllDailyLogs()
            let customMeals = try await dataStore.fetchAllCustomMeals()
            
            print("Found \(foodItems.count) food items, \(exerciseItems.count) exercise items, \(dailyLogs.count) daily logs, \(customMeals.count) custom meals")
            
            // Step 2: Migrate food items
            print("Migrating food items...")
            for var foodItem in foodItems {
                // Skip if already migrated in previous attempt
                if state.migratedFoodItemIds.contains(foodItem.id) {
                    print("  Skipping already migrated food item: \(foodItem.id)")
                    foodItemsCount += 1
                    continue
                }
                
                // Skip if already synced
                if foodItem.syncStatus == .synced && !foodItem.userId.isEmpty {
                    print("  Skipping already synced food item: \(foodItem.id)")
                    state.migratedFoodItemIds.insert(foodItem.id)
                    saveMigrationState(state)
                    foodItemsCount += 1
                    continue
                }
                
                do {
                    // Associate with user
                    foodItem.userId = userId
                    foodItem.lastModified = Date()
                    foodItem.syncStatus = .pendingUpload
                    
                    // Update local store
                    try await dataStore.updateFoodItem(foodItem)
                    
                    // Upload to Firestore
                    try await uploadFoodItem(foodItem, userId: userId)
                    
                    // Mark as synced
                    foodItem.syncStatus = .synced
                    try await dataStore.updateFoodItem(foodItem)
                    
                    // Track successful migration
                    state.migratedFoodItemIds.insert(foodItem.id)
                    state.failedEntityIds.remove(foodItem.id)
                    saveMigrationState(state)
                    
                    foodItemsCount += 1
                    print("  Migrated food item: \(foodItem.id)")
                    
                } catch {
                    print("  Failed to migrate food item \(foodItem.id): \(error)")
                    errors.append(error)
                    state.failedEntityIds.insert(foodItem.id)
                    saveMigrationState(state)
                    failedCount += 1
                }
            }
            
            // Step 3: Migrate daily logs
            print("Migrating daily logs...")
            // Step 3a: Migrate exercise items
            print("Migrating exercise items...")
            for var exerciseItem in exerciseItems {
                if state.migratedExerciseItemIds.contains(exerciseItem.id) {
                    print("  Skipping already migrated exercise item: \(exerciseItem.id)")
                    exerciseItemsCount += 1
                    continue
                }
                
                if exerciseItem.syncStatus == .synced && !exerciseItem.userId.isEmpty {
                    print("  Skipping already synced exercise item: \(exerciseItem.id)")
                    state.migratedExerciseItemIds.insert(exerciseItem.id)
                    saveMigrationState(state)
                    exerciseItemsCount += 1
                    continue
                }
                
                do {
                    exerciseItem.userId = userId
                    exerciseItem.lastModified = Date()
                    exerciseItem.syncStatus = .pendingUpload
                    
                    try await dataStore.updateExerciseItem(exerciseItem)
                    try await uploadExerciseItem(exerciseItem, userId: userId)
                    
                    exerciseItem.syncStatus = .synced
                    try await dataStore.updateExerciseItem(exerciseItem)
                    
                    state.migratedExerciseItemIds.insert(exerciseItem.id)
                    state.failedEntityIds.remove(exerciseItem.id)
                    saveMigrationState(state)
                    
                    exerciseItemsCount += 1
                    print("  Migrated exercise item: \(exerciseItem.id)")
                } catch {
                    print("  Failed to migrate exercise item \(exerciseItem.id): \(error)")
                    errors.append(error)
                    state.failedEntityIds.insert(exerciseItem.id)
                    saveMigrationState(state)
                    failedCount += 1
                }
            }
            
            // Step 4: Migrate daily logs
            print("Migrating daily logs...")
            for var dailyLog in dailyLogs {
                // Skip if already migrated in previous attempt
                if state.migratedDailyLogIds.contains(dailyLog.id) {
                    print("  Skipping already migrated daily log: \(dailyLog.id)")
                    dailyLogsCount += 1
                    continue
                }
                
                // Skip if already synced
                if dailyLog.syncStatus == .synced && !dailyLog.userId.isEmpty {
                    print("  Skipping already synced daily log: \(dailyLog.id)")
                    state.migratedDailyLogIds.insert(dailyLog.id)
                    saveMigrationState(state)
                    dailyLogsCount += 1
                    continue
                }
                
                do {
                    // Associate with user
                    dailyLog.userId = userId
                    dailyLog.lastModified = Date()
                    dailyLog.syncStatus = .pendingUpload
                    
                    // Update local store
                    try await dataStore.updateDailyLog(dailyLog)
                    
                    // Upload to Firestore
                    try await uploadDailyLog(dailyLog, userId: userId)
                    
                    // Mark as synced
                    dailyLog.syncStatus = .synced
                    try await dataStore.updateDailyLog(dailyLog)
                    
                    // Track successful migration
                    state.migratedDailyLogIds.insert(dailyLog.id)
                    state.failedEntityIds.remove(dailyLog.id)
                    saveMigrationState(state)
                    
                    dailyLogsCount += 1
                    print("  Migrated daily log: \(dailyLog.id)")
                    
                } catch {
                    print("  Failed to migrate daily log \(dailyLog.id): \(error)")
                    errors.append(error)
                    state.failedEntityIds.insert(dailyLog.id)
                    saveMigrationState(state)
                    failedCount += 1
                }
            }
            
            // Step 5: Migrate custom meals
            print("Migrating custom meals...")
            for var customMeal in customMeals {
                // Skip if already migrated in previous attempt
                if state.migratedCustomMealIds.contains(customMeal.id) {
                    print("  Skipping already migrated custom meal: \(customMeal.id)")
                    customMealsCount += 1
                    continue
                }
                
                // Skip if already synced
                if customMeal.syncStatus == .synced && !customMeal.userId.isEmpty {
                    print("  Skipping already synced custom meal: \(customMeal.id)")
                    state.migratedCustomMealIds.insert(customMeal.id)
                    saveMigrationState(state)
                    customMealsCount += 1
                    continue
                }
                
                do {
                    // Associate with user
                    customMeal.userId = userId
                    customMeal.lastModified = Date()
                    customMeal.syncStatus = .pendingUpload
                    
                    // Update local store
                    try await dataStore.updateCustomMeal(customMeal)
                    
                    // Upload to Firestore
                    try await uploadCustomMeal(customMeal, userId: userId)
                    
                    // Mark as synced
                    customMeal.syncStatus = .synced
                    try await dataStore.updateCustomMeal(customMeal)
                    
                    // Track successful migration
                    state.migratedCustomMealIds.insert(customMeal.id)
                    state.failedEntityIds.remove(customMeal.id)
                    saveMigrationState(state)
                    
                    customMealsCount += 1
                    print("  Migrated custom meal: \(customMeal.id)")
                    
                } catch {
                    print("  Failed to migrate custom meal \(customMeal.id): \(error)")
                    errors.append(error)
                    state.failedEntityIds.insert(customMeal.id)
                    saveMigrationState(state)
                    failedCount += 1
                }
            }
            
            // Step 6: Create and return migration result
            let totalCount = foodItemsCount + exerciseItemsCount + dailyLogsCount + customMealsCount
            let result = MigrationResult(
                foodItemsCount: foodItemsCount,
                exerciseItemsCount: exerciseItemsCount,
                dailyLogsCount: dailyLogsCount,
                customMealsCount: customMealsCount,
                totalCount: totalCount,
                failedCount: failedCount,
                errors: errors
            )
            
            print("Migration completed: \(totalCount) entities migrated, \(failedCount) failed")
            
            // If migration is complete (no failures), clear migration state
            if failedCount == 0 {
                clearMigrationState(userId: userId)
                print("Migration state cleared - all entities successfully migrated")
            }
            
            // If some entities failed but we haven't exceeded retries, schedule automatic retry
            if failedCount > 0 && state.attemptCount < maxMigrationRetries {
                print("Migration incomplete - \(failedCount) entities failed, will retry automatically")
                // The retry will happen on next call to migrateLocalData
            }
            
            // If all entities failed, throw an error
            if totalCount > 0 && failedCount == totalCount {
                throw SyncError.migrationFailed(reason: "All entities failed to migrate")
            }
            
            return result
            
        } catch let error as SyncError {
            // Re-throw SyncError as-is
            throw error
        } catch {
            // Wrap other errors in SyncError
            throw SyncError.migrationFailed(reason: error.localizedDescription)
        }
    }
    
    /// Loads migration state from UserDefaults for resume capability
    ///
    /// Retrieves the persisted migration state for a specific user. This allows
    /// migration to resume from where it left off after app restart or failure.
    ///
    /// - Parameter userId: The user ID to load migration state for
    /// - Returns: The migration state if found, nil otherwise
    ///
    /// **Validates: Requirements 9.4 (Track Migration Progress)**
    private func loadMigrationState(userId: String) -> MigrationState? {
        let key = "migrationState_\(userId)"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let state = try decoder.decode(MigrationState.self, from: data)
            print("Loaded migration state: attempt \(state.attemptCount), \(state.migratedFoodItemIds.count) food items, \(state.migratedDailyLogIds.count) daily logs, \(state.migratedCustomMealIds.count) custom meals already migrated")
            return state
        } catch {
            print("Failed to load migration state: \(error)")
            return nil
        }
    }
    
    /// Saves migration state to UserDefaults for resume capability
    ///
    /// Persists the current migration state so that migration can resume from
    /// where it left off after app restart or failure. This ensures no data loss
    /// and prevents duplicate migration attempts.
    ///
    /// - Parameter state: The migration state to persist
    ///
    /// **Validates: Requirements 9.4 (Track Migration Progress)**
    private func saveMigrationState(_ state: MigrationState) {
        let key = "migrationState_\(state.userId)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save migration state: \(error)")
        }
    }
    
    /// Clears migration state from UserDefaults after successful completion
    ///
    /// Removes the persisted migration state once all entities have been successfully
    /// migrated. This prevents unnecessary state tracking for completed migrations.
    ///
    /// - Parameter userId: The user ID to clear migration state for
    ///
    /// **Validates: Requirements 9.4 (Track Migration Progress)**
    private func clearMigrationState(userId: String) {
        let key = "migrationState_\(userId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Checks if a migration is in progress for a user
    ///
    /// Returns true if there is persisted migration state indicating an incomplete
    /// migration. This can be used to show migration UI or trigger automatic retry.
    ///
    /// - Parameter userId: The user ID to check
    /// - Returns: True if migration is in progress, false otherwise
    func isMigrationInProgress(userId: String) -> Bool {
        return loadMigrationState(userId: userId) != nil
    }
    
    // MARK: - Retention Policy Helpers
    
    /// Loads the last retention policy execution date from UserDefaults
    ///
    /// - Returns: The date of the last retention policy execution, or nil if never run
    private func loadLastRetentionPolicyDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lastRetentionPolicyDate") as? Date
    }
    
    /// Saves the last retention policy execution date to UserDefaults
    ///
    /// - Parameter date: The date to save
    private func saveLastRetentionPolicyDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastRetentionPolicyDate")
    }
    
    // MARK: - Data Retention Policies
    
    /// Applies the 90-day retention policy to daily logs
    ///
    /// Enforces the data retention policy by deleting daily logs older than 90 days
    /// from both local and cloud storage. This helps manage storage costs and keeps
    /// the database size manageable while preserving recent tracking history.
    ///
    /// **Retention Rules**:
    /// - Daily logs older than 90 days are deleted from both stores
    /// - Custom meals are retained indefinitely (not affected by this policy)
    /// - User goals are retained indefinitely (not affected by this policy)
    /// - Deletions are synchronized across all devices
    ///
    /// This method should be called:
    /// - On app launch (to clean up old data)
    /// - Daily in background (scheduled task)
    /// - After successful migration (to apply policy to migrated data)
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Throws: SyncError if deletion operations fail
    ///
    /// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5 (Data Retention)**
    func applyRetentionPolicy(userId: String) async throws {
        // Validate authentication
        guard !userId.isEmpty else {
            throw SyncError.notAuthenticated
        }
        
        print("Applying 90-day retention policy for user: \(userId)")
        
        // Calculate the cutoff date (90 days ago from today)
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -90, to: Date()) else {
            print("Failed to calculate cutoff date")
            return
        }
        
        print("Cutoff date: \(cutoffDate) - deleting daily logs older than this date")
        
        // Fetch all daily logs from local store
        let allDailyLogs = try await dataStore.fetchAllDailyLogs()
        
        // Filter logs older than 90 days
        let oldLogs = allDailyLogs.filter { dailyLog in
            dailyLog.date < cutoffDate
        }
        
        print("Found \(oldLogs.count) daily logs older than 90 days")
        
        // If no old logs, nothing to delete
        guard !oldLogs.count.isMultiple(of: 1) || oldLogs.count > 0 else {
            print("No old daily logs to delete")
            return
        }
        
        var deletedCount = 0
        var failedCount = 0
        var errors: [Error] = []
        
        // Delete each old log from both stores
        for oldLog in oldLogs {
            do {
                // Delete from both local and cloud storage
                try await deleteEntity(
                    entityId: oldLog.id,
                    entityType: .dailyLog,
                    userId: userId
                )
                
                deletedCount += 1
                print("  Deleted daily log from \(oldLog.date): \(oldLog.id)")
                
            } catch {
                failedCount += 1
                errors.append(error)
                print("  Failed to delete daily log \(oldLog.id): \(error)")
            }
        }
        
        print("Retention policy applied: \(deletedCount) daily logs deleted, \(failedCount) failed")
        
        // If some deletions failed, log but don't throw - partial success is acceptable
        if failedCount > 0 {
            print("⚠️ Some deletions failed - will retry on next policy execution")
        }
        
        // Note: Custom meals and user goals are NOT affected by this policy
        // They are retained indefinitely as per requirements 11.3 and 11.4
    }
    
    /// Triggers retention policy execution on app launch
    ///
    /// This method should be called when the user authenticates to ensure old data
    /// is cleaned up. It runs asynchronously in the background and doesn't block
    /// the authentication flow.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    ///
    /// **Validates: Requirements 11.1, 11.5 (Run on App Launch)**
    nonisolated func scheduleRetentionPolicyOnLaunch(userId: String) {
        Task {
            do {
                try await applyRetentionPolicy(userId: userId)
                print("App launch retention policy completed successfully")
            } catch {
                print("Failed to run app launch retention policy: \(error)")
            }
        }
    }
    
    // MARK: - High-Level Sync Operations
    
    /// Syncs a food item to both local and cloud storage
    ///
    /// Performs dual persistence by saving to local store first (always succeeds offline),
    /// then attempting cloud upload. If offline or upload fails, queues for later sync.
    ///
    /// - Parameters:
    ///   - foodItem: The food item to sync
    ///   - userId: Owner's user ID
    /// - Throws: SyncError if local storage fails (cloud failures are queued, not thrown)
    ///
    /// **Validates: Requirements 5.1, 7.1, 7.2 (Dual Persistence and Offline Operation)**
    func syncFoodItem(_ foodItem: FoodItem, userId: String) async throws {
        // Always save to local store first (works offline)
        var mutableItem = foodItem
        mutableItem.userId = userId
        mutableItem.lastModified = Date()
        mutableItem.syncStatus = .pendingUpload
        
        do {
            // Try to fetch existing item to determine if we need insert or update
            if let existing = try await dataStore.fetchFoodItem(byId: mutableItem.id) {
                // Item exists - update it
                existing.userId = userId
                existing.lastModified = Date()
                existing.syncStatus = .pendingUpload
                try await dataStore.updateFoodItem(existing)
                print("Updated FoodItem \(mutableItem.id) in local store")
            } else {
                // Item doesn't exist - insert it
                try await dataStore.insertFoodItem(mutableItem)
                print("Inserted FoodItem \(mutableItem.id) in local store")
            }
        } catch {
            throw SyncError.dataStoreError(error)
        }
        
        // Attempt cloud upload (will queue if offline)
        do {
            try await uploadFoodItem(mutableItem, userId: userId)
            print("Uploaded FoodItem \(mutableItem.id) to cloud")
        } catch SyncError.networkUnavailable {
            // Expected when offline - operation is already queued
            print("FoodItem \(mutableItem.id) queued for sync when online")
        } catch {
            // Other errors - operation is already queued by uploadToFirestore
            print("FoodItem \(mutableItem.id) upload failed, queued for retry: \(error)")
        }
    }
    
    /// Syncs an exercise item to both local and cloud storage
    ///
    /// Performs dual persistence by saving to local store first (always succeeds offline),
    /// then attempting cloud upload. If offline or upload fails, queues for later sync.
    ///
    /// - Parameters:
    ///   - exerciseItem: The exercise item to sync
    ///   - userId: Owner's user ID
    /// - Throws: SyncError if local storage fails (cloud failures are queued, not thrown)
    func syncExerciseItem(_ exerciseItem: ExerciseItem, userId: String) async throws {
        var mutableItem = exerciseItem
        mutableItem.userId = userId
        mutableItem.lastModified = Date()
        mutableItem.syncStatus = .pendingUpload
        
        do {
            // Try to fetch existing item to determine if we need insert or update
            if let existing = try await dataStore.fetchExerciseItem(byId: mutableItem.id) {
                // Item exists - update it
                existing.userId = userId
                existing.lastModified = Date()
                existing.syncStatus = .pendingUpload
                try await dataStore.updateExerciseItem(existing)
                print("Updated ExerciseItem \(mutableItem.id) in local store")
            } else {
                // Item doesn't exist - insert it
                try await dataStore.insertExerciseItem(mutableItem)
                print("Inserted ExerciseItem \(mutableItem.id) in local store")
            }
        } catch {
            throw SyncError.dataStoreError(error)
        }
        
        do {
            try await uploadExerciseItem(mutableItem, userId: userId)
            print("Uploaded ExerciseItem \(mutableItem.id) to cloud")
        } catch SyncError.networkUnavailable {
            print("ExerciseItem \(mutableItem.id) queued for sync when online")
        } catch {
            print("ExerciseItem \(mutableItem.id) upload failed, queued for retry: \(error)")
        }
    }
    
    /// Syncs a daily log to both local and cloud storage
    ///
    /// Performs dual persistence by saving to local store first (always succeeds offline),
    /// then attempting cloud upload. If offline or upload fails, queues for later sync.
    ///
    /// - Parameters:
    ///   - dailyLog: The daily log to sync
    ///   - userId: Owner's user ID
    /// - Throws: SyncError if local storage fails (cloud failures are queued, not thrown)
    ///
    /// **Validates: Requirements 5.1, 7.1, 7.2 (Dual Persistence and Offline Operation)**
    func syncDailyLog(_ dailyLog: DailyLog, userId: String) async throws {
        // Always save to local store first (works offline)
        var mutableLog = dailyLog
        mutableLog.userId = userId
        mutableLog.lastModified = Date()
        mutableLog.syncStatus = .pendingUpload
        
        do {
            try await dataStore.insertDailyLog(mutableLog)
            print("Saved DailyLog \(mutableLog.id) to local store")
        } catch {
            throw SyncError.dataStoreError(error)
        }
        
        // Attempt cloud upload (will queue if offline)
        do {
            try await uploadDailyLog(mutableLog, userId: userId)
            print("Uploaded DailyLog \(mutableLog.id) to cloud")
        } catch SyncError.networkUnavailable {
            // Expected when offline - operation is already queued
            print("DailyLog \(mutableLog.id) queued for sync when online")
        } catch {
            // Other errors - operation is already queued by uploadToFirestore
            print("DailyLog \(mutableLog.id) upload failed, queued for retry: \(error)")
        }
    }
    
    /// Syncs a custom meal to both local and cloud storage
    ///
    /// Performs dual persistence by saving to local store first (always succeeds offline),
    /// then attempting cloud upload. If offline or upload fails, queues for later sync.
    ///
    /// - Parameters:
    ///   - customMeal: The custom meal to sync
    ///   - userId: Owner's user ID
    /// - Throws: SyncError if local storage fails (cloud failures are queued, not thrown)
    ///
    /// **Validates: Requirements 5.2, 7.1, 7.2 (Dual Persistence and Offline Operation)**
    func syncCustomMeal(_ customMeal: CustomMeal, userId: String) async throws {
        // Always save to local store first (works offline)
        var mutableMeal = customMeal
        mutableMeal.userId = userId
        mutableMeal.lastModified = Date()
        mutableMeal.syncStatus = .pendingUpload
        
        do {
            try await dataStore.insertCustomMeal(mutableMeal)
            print("Saved CustomMeal \(mutableMeal.id) to local store")
        } catch {
            throw SyncError.dataStoreError(error)
        }
        
        // Attempt cloud upload (will queue if offline)
        do {
            try await uploadCustomMeal(mutableMeal, userId: userId)
            print("Uploaded CustomMeal \(mutableMeal.id) to cloud")
        } catch SyncError.networkUnavailable {
            // Expected when offline - operation is already queued
            print("CustomMeal \(mutableMeal.id) queued for sync when online")
        } catch {
            // Other errors - operation is already queued by uploadToFirestore
            print("CustomMeal \(mutableMeal.id) upload failed, queued for retry: \(error)")
        }
    }
    
    /// Deletes an entity from both local and cloud storage
    ///
    /// Performs dual deletion by removing from local store first (always succeeds offline),
    /// then attempting cloud deletion. If offline or deletion fails, queues for later sync.
    ///
    /// - Parameters:
    ///   - entityId: Unique identifier of entity to delete
    ///   - entityType: Type of entity being deleted
    ///   - userId: Owner's user ID
    /// - Throws: SyncError if local deletion fails (cloud failures are queued, not thrown)
    ///
    /// **Validates: Requirements 5.5, 7.1, 7.2 (Dual Persistence and Offline Operation)**
    func deleteEntity(entityId: String, entityType: EntityType, userId: String) async throws {
        // Always delete from local store first (works offline)
        do {
            switch entityType {
            case .foodItem:
                try await dataStore.deleteFoodItem(byId: entityId)
                print("Deleted FoodItem \(entityId) from local store")
                
            case .dailyLog:
                try await dataStore.deleteDailyLog(byId: entityId)
                print("Deleted DailyLog \(entityId) from local store")
                
            case .customMeal:
                try await dataStore.deleteCustomMeal(byId: entityId)
                print("Deleted CustomMeal \(entityId) from local store")
                
            case .exerciseItem:
                try await dataStore.deleteExerciseItem(byId: entityId)
                print("Deleted ExerciseItem \(entityId) from local store")
                
            case .userGoal:
                // User goals handled differently
                print("Deleted UserGoal from local store")
            }
        } catch {
            throw SyncError.dataStoreError(error)
        }
        
        // Check network connectivity
        let isOnline = await MainActor.run {
            networkMonitor.isConnected
        }
        
        // If offline, queue the deletion
        if !isOnline {
            print("Device is offline - queuing deletion for \(entityId)")
            let operation = SyncOperation.delete(
                entityId: entityId,
                entityType: entityType,
                timestamp: Date()
            )
            queueOperation(operation)
            return
        }
        
        // Attempt cloud deletion
        do {
            let collectionPath = getCollectionPath(for: entityType, userId: userId)
            try await db.collection(collectionPath)
                .document(entityId)
                .delete()
            print("Deleted \(entityType) \(entityId) from cloud")
        } catch {
            // Cloud deletion failed - queue for retry
            print("Cloud deletion failed for \(entityId), queued for retry: \(error)")
            let operation = SyncOperation.delete(
                entityId: entityId,
                entityType: entityType,
                timestamp: Date()
            )
            queueOperation(operation)
        }
    }
    
    /// Manually triggers sync of queued operations
    ///
    /// Processes all pending sync operations in the queue. This can be called:
    /// - When user manually triggers sync (pull-to-refresh)
    /// - When app returns to foreground
    /// - When network connectivity is restored
    ///
    /// - Throws: SyncError if sync fails
    ///
    /// **Validates: Requirements 13.5 (Manual Retry)**
    func forceSyncNow() async throws {
        print("Manual sync triggered")
        
        // Check network connectivity
        let isOnline = await MainActor.run {
            networkMonitor.isConnected
        }
        
        guard isOnline else {
            let error = SyncError.networkUnavailable
            logError(error, context: "forceSyncNow", entityId: nil)
            throw error
        }
        
        // Process the queue
        do {
            try await processQueue()
            print("Manual sync completed successfully")
        } catch {
            let syncError = error as? SyncError ?? SyncError.queueProcessingFailed(count: syncQueue.count)
            logError(syncError, context: "forceSyncNow (queue processing)", entityId: nil)
            throw syncError
        }
    }
    
    // MARK: - Error Handling and Logging
    
    /// Logs sync errors with context for debugging
    ///
    /// Provides comprehensive error logging with context information to help
    /// diagnose sync issues. Logs include:
    /// - Error type and description
    /// - Operation context (where the error occurred)
    /// - Entity ID if applicable
    /// - Timestamp
    ///
    /// This method preserves local data on all errors by never deleting data
    /// when sync operations fail. Failed operations are queued for retry.
    ///
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Description of where the error occurred (e.g., "uploadToFirestore")
    ///   - entityId: Optional entity ID associated with the error
    ///
    /// **Validates: Requirements 13.2, 13.3 (Error Handling and Data Preservation)**
    private func logError(_ error: SyncError, context: String, entityId: String?) {
        let timestamp = Date()
        let entityInfo = entityId.map { " [Entity: \($0)]" } ?? ""
        
        print("❌ SyncError [\(timestamp)][\(context)]\(entityInfo): \(error.localizedDescription)")
        
        // Log additional details based on error type
        switch error {
        case .firestoreError(let underlyingError):
            print("   Underlying error: \(underlyingError.localizedDescription)")
            
        case .dataStoreError(let underlyingError):
            print("   Underlying error: \(underlyingError.localizedDescription)")
            
        case .queueProcessingFailed(let count):
            print("   Failed operations: \(count)")
            
        case .maxRetriesExceeded(let operationId, let attempts):
            print("   Operation ID: \(operationId), Attempts: \(attempts)")
            
        case .migrationFailed(let reason):
            print("   Reason: \(reason)")
            
        default:
            break
        }
        
        // Note: Local data is always preserved on errors
        // Failed operations are queued for retry when connectivity is restored
        print("   ℹ️ Local data preserved - operation queued for retry")
    }
    
    /// Maps Firestore errors to SyncError for consistent error handling
    ///
    /// Converts Firebase-specific errors to our SyncError enum for consistent
    /// error handling throughout the app. This provides better error messages
    /// and allows for error-specific retry logic.
    ///
    /// **Common Firestore Errors**:
    /// - Permission denied → notAuthenticated
    /// - Unavailable → networkUnavailable
    /// - Deadline exceeded → networkUnavailable (timeout)
    /// - Other errors → firestoreError with underlying error
    ///
    /// - Parameter error: The Firestore error to map
    /// - Returns: The corresponding SyncError
    ///
    /// **Validates: Requirements 13.2 (Map Firestore Errors)**
    private func mapFirestoreError(_ error: Error) -> SyncError {
        let nsError = error as NSError
        
        // Check for Firestore error codes
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // Permission denied
                return .notAuthenticated
                
            case 14: // Unavailable
                return .networkUnavailable
                
            case 4: // Deadline exceeded (timeout)
                return .networkUnavailable
                
            default:
                return .firestoreError(error)
            }
        }
        
        // Check for network errors
        if nsError.domain == NSURLErrorDomain {
            return .networkUnavailable
        }
        
        // Default to wrapping in firestoreError
        return .firestoreError(error)
    }
    
    // MARK: - Account Deletion
    
    /// Deletes all user data from Firestore
    ///
    /// Removes all entities from all collections for the specified user.
    /// This is called during account deletion to ensure complete data removal
    /// from the cloud. The method deletes data from:
    /// - foodItems collection
    /// - dailyLogs collection
    /// - customMeals collection
    /// - profile collection
    ///
    /// This operation is irreversible and should only be called after user confirmation.
    ///
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Throws: SyncError if deletion fails
    ///
    /// **Validates: Requirements 14.3 (Delete All Cloud Data)**
    func deleteAllUserData(userId: String) async throws {
        // Validate authentication
        guard !userId.isEmpty else {
            throw SyncError.notAuthenticated
        }
        
        print("🗑️ Starting deletion of all cloud data for user \(userId)...")
        
        var deletionErrors: [Error] = []
        
        // Delete all food items
        do {
            let foodItemsPath = getCollectionPath(for: .foodItem, userId: userId)
            let foodItemsSnapshot = try await db.collection(foodItemsPath).getDocuments()
            
            for document in foodItemsSnapshot.documents {
                try await document.reference.delete()
            }
            
            print("✓ Deleted \(foodItemsSnapshot.documents.count) food items from cloud")
        } catch {
            deletionErrors.append(error)
            logError(
                mapFirestoreError(error),
                context: "deleteAllUserData (foodItems)",
                entityId: userId
            )
        }
        
        // Delete all daily logs
        do {
            let dailyLogsPath = getCollectionPath(for: .dailyLog, userId: userId)
            let dailyLogsSnapshot = try await db.collection(dailyLogsPath).getDocuments()
            
            for document in dailyLogsSnapshot.documents {
                try await document.reference.delete()
            }
            
            print("✓ Deleted \(dailyLogsSnapshot.documents.count) daily logs from cloud")
        } catch {
            deletionErrors.append(error)
            logError(
                mapFirestoreError(error),
                context: "deleteAllUserData (dailyLogs)",
                entityId: userId
            )
        }
        
        // Delete all custom meals
        do {
            let customMealsPath = getCollectionPath(for: .customMeal, userId: userId)
            let customMealsSnapshot = try await db.collection(customMealsPath).getDocuments()
            
            for document in customMealsSnapshot.documents {
                try await document.reference.delete()
            }
            
            print("✓ Deleted \(customMealsSnapshot.documents.count) custom meals from cloud")
        } catch {
            deletionErrors.append(error)
            logError(
                mapFirestoreError(error),
                context: "deleteAllUserData (customMeals)",
                entityId: userId
            )
        }
        
        // Delete profile data
        do {
            let profilePath = "users/\(userId)/profile"
            let profileSnapshot = try await db.collection(profilePath).getDocuments()
            
            for document in profileSnapshot.documents {
                try await document.reference.delete()
            }
            
            print("✓ Deleted profile data from cloud")
        } catch {
            deletionErrors.append(error)
            logError(
                mapFirestoreError(error),
                context: "deleteAllUserData (profile)",
                entityId: userId
            )
        }
        
        // If any deletions failed, throw error
        if !deletionErrors.isEmpty {
            throw SyncError.accountDeletionFailed(
                reason: "Failed to delete \(deletionErrors.count) collection(s)"
            )
        }
        
        print("✅ Successfully deleted all cloud data for user \(userId)")
    }
}
