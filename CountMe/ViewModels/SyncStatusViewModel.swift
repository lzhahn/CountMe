//
//  SyncStatusViewModel.swift
//  CountMe
//
//  View model for managing and displaying sync status in the UI
//

import Foundation
import SwiftUI
import Observation

/// View model that tracks and publishes synchronization status
///
/// This view model observes the FirebaseSyncEngine and NetworkMonitor to provide
/// real-time sync status updates to the UI. It tracks:
/// - Current sync state (synced, syncing, error, offline)
/// - Network connectivity status
/// - Last successful sync timestamp
/// - Number of pending operations
///
/// **Usage:**
/// ```swift
/// @State private var syncStatus = SyncStatusViewModel()
///
/// var body: some View {
///     VStack {
///         SyncStatusBadge(viewModel: syncStatus)
///     }
///     .task {
///         await syncStatus.observeSyncEngine(syncEngine)
///     }
/// }
/// ```
///
/// **Validates: Requirements 6.4, 7.5 (Sync Status Display)**
@MainActor
@Observable
class SyncStatusViewModel {
    // MARK: - Published Properties
    
    /// Current synchronization state
    var syncState: SyncState = .synced
    
    /// Whether the device is currently offline
    var isOffline: Bool = false
    
    /// Timestamp of the last successful sync operation
    var lastSyncTime: Date?
    
    /// Number of operations pending sync
    var pendingOperationCount: Int = 0
    
    // MARK: - Private Properties
    
    /// Reference to the sync engine being observed
    private var syncEngine: FirebaseSyncEngine?
    
    /// Reference to the network monitor
    private var networkMonitor: NetworkMonitor?
    
    /// Timer for periodic status updates
    private var statusUpdateTimer: Timer?
    
    // MARK: - Sync State Enum
    
    /// Represents the current state of synchronization
    enum SyncState: Equatable {
        /// All data is synchronized with the cloud
        case synced
        
        /// Synchronization is currently in progress
        case syncing
        
        /// An error occurred during synchronization
        case error(String)
        
        /// Device is offline, sync unavailable
        case offline
        
        static func == (lhs: SyncState, rhs: SyncState) -> Bool {
            switch (lhs, rhs) {
            case (.synced, .synced),
                 (.syncing, .syncing),
                 (.offline, .offline):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default state
        // Actual state will be updated when observeSyncEngine is called
    }
    
    // MARK: - Public Methods
    
    /// Begins observing the sync engine for state changes
    ///
    /// Sets up periodic polling of the sync engine to update the UI with current
    /// sync status. This method should be called when the view appears.
    ///
    /// - Parameter engine: The FirebaseSyncEngine to observe
    func observeSyncEngine(_ engine: FirebaseSyncEngine) async {
        self.syncEngine = engine
        
        // Start periodic status updates
        startStatusUpdates()
        
        // Perform initial status check
        await updateSyncStatus()
    }
    
    /// Begins observing network status changes
    ///
    /// Sets up monitoring of network connectivity to update the offline status.
    /// This method should be called when the view appears.
    ///
    /// - Parameter monitor: The NetworkMonitor to observe
    func observeNetworkStatus(_ monitor: NetworkMonitor) {
        self.networkMonitor = monitor
        
        // Update offline status immediately
        updateOfflineStatus()
        
        // Network monitor updates isConnected automatically via @Observable
        // We'll check it periodically in our status update loop
    }
    
    /// Stops observing the sync engine and network monitor
    ///
    /// Cleans up resources and stops periodic updates. This method should be
    /// called when the view disappears.
    func stopObserving() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        syncEngine = nil
        networkMonitor = nil
    }
    
    /// Manually triggers a sync status update
    ///
    /// Useful for pull-to-refresh or manual sync button actions.
    func refreshStatus() async {
        await updateSyncStatus()
    }
    
    // MARK: - Private Methods
    
    /// Starts periodic status updates
    ///
    /// Creates a timer that checks sync status every 2 seconds to keep the UI
    /// updated with the latest sync state.
    private func startStatusUpdates() {
        // Invalidate any existing timer
        statusUpdateTimer?.invalidate()
        
        // Create new timer for periodic updates (every 2 seconds)
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateSyncStatus()
            }
        }
    }
    
    /// Updates the sync status by querying the sync engine
    ///
    /// Checks the current state of the sync engine and updates published properties
    /// accordingly. This includes:
    /// - Network connectivity status
    /// - Number of pending operations
    /// - Current sync state (synced, syncing, error, offline)
    private func updateSyncStatus() async {
        guard let engine = syncEngine else { return }
        
        // Update offline status from network monitor
        updateOfflineStatus()
        
        // Get pending operation count from sync engine
        let queuedCount = await engine.queuedOperationCount()
        pendingOperationCount = queuedCount
        
        // Determine sync state based on network and queue status
        if isOffline {
            syncState = .offline
        } else if queuedCount > 0 {
            // If there are queued operations, we're either syncing or have pending items
            syncState = .syncing
        } else {
            // No queued operations and online means we're synced
            syncState = .synced
            lastSyncTime = Date()
        }
    }
    
    /// Updates the offline status from the network monitor
    ///
    /// Checks the network monitor's connectivity status and updates the
    /// isOffline property accordingly.
    private func updateOfflineStatus() {
        if let monitor = networkMonitor {
            isOffline = !monitor.isConnected
        }
    }
    
    /// Updates sync state to indicate an error occurred
    ///
    /// This method can be called by external components when a sync error
    /// is detected (e.g., from error notifications).
    ///
    /// - Parameter message: The error message to display
    func reportError(_ message: String) {
        syncState = .error(message)
    }
    
    /// Updates sync state to indicate syncing is in progress
    ///
    /// This method can be called by external components when a sync operation
    /// begins (e.g., from manual sync trigger).
    func reportSyncInProgress() {
        syncState = .syncing
    }
    
    /// Updates sync state to indicate sync completed successfully
    ///
    /// This method can be called by external components when a sync operation
    /// completes successfully.
    func reportSyncCompleted() {
        syncState = .synced
        lastSyncTime = Date()
    }
}
