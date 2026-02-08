# Sync Status UI Integration Guide

This document explains how to integrate the sync status UI components into your views.

## Components

### SyncStatusViewModel
A view model that tracks and publishes synchronization status. It observes the FirebaseSyncEngine and NetworkMonitor to provide real-time updates.

**Published Properties:**
- `syncState: SyncState` - Current sync state (synced, syncing, error, offline)
- `isOffline: Bool` - Whether the device is offline
- `lastSyncTime: Date?` - Timestamp of last successful sync
- `pendingOperationCount: Int` - Number of operations pending sync

### SyncStatusBadge
A visual badge component that displays the current sync status with icon and text.

**Variants:**
- `SyncStatusBadge` - Full badge with icon, text, and pending count
- `SyncStatusBadgeCompact` - Icon-only badge with tooltip

## Integration Steps

### 1. Create SyncStatusViewModel Instance

In your root view or app entry point, create a SyncStatusViewModel instance:

```swift
@StateObject private var syncStatusViewModel = SyncStatusViewModel()
```

### 2. Pass to Child Views

Pass the view model to views that need to display sync status:

```swift
MainCalorieView(
    tracker: tracker,
    customMealManager: customMealManager,
    syncStatusViewModel: syncStatusViewModel
)
```

### 3. Start Observing Sync Engine

When the sync engine is available (after authentication), start observing:

```swift
.task {
    if let syncEngine = syncEngine {
        await syncStatusViewModel.observeSyncEngine(syncEngine)
    }
    
    if let networkMonitor = networkMonitor {
        syncStatusViewModel.observeNetworkStatus(networkMonitor)
    }
}
```

### 4. Add Badge to Toolbar

Add the sync status badge to your navigation toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        SyncStatusBadge(viewModel: syncStatusViewModel)
    }
}
```

Or use the compact variant for space-constrained areas:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        SyncStatusBadgeCompact(viewModel: syncStatusViewModel)
    }
}
```

## Example: MainCalorieView Integration

```swift
struct MainCalorieView: View {
    @Bindable var tracker: CalorieTracker
    @Bindable var customMealManager: CustomMealManager
    
    // Add sync status view model parameter
    @ObservedObject var syncStatusViewModel: SyncStatusViewModel
    
    var syncEngine: FirebaseSyncEngine?
    var userId: String?
    
    var body: some View {
        NavigationStack {
            // ... existing content ...
            
            .toolbar {
                // Existing toolbar items...
                
                // Add sync status badge
                ToolbarItem(placement: .navigationBarTrailing) {
                    SyncStatusBadge(viewModel: syncStatusViewModel)
                }
            }
        }
        .task {
            // Start observing sync engine when view appears
            if let syncEngine = syncEngine {
                await syncStatusViewModel.observeSyncEngine(syncEngine)
            }
        }
        .onDisappear {
            // Stop observing when view disappears
            syncStatusViewModel.stopObserving()
        }
    }
}
```

## Example: ContentView Integration

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: FirebaseAuthService
    
    // Add sync status view model
    @StateObject private var syncStatusViewModel = SyncStatusViewModel()
    
    @State private var tracker: CalorieTracker?
    @State private var customMealManager: CustomMealManager?
    @State private var syncEngine: FirebaseSyncEngine?
    @State private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        Group {
            if let tracker = tracker, let customMealManager = customMealManager {
                TabView {
                    MainCalorieView(
                        tracker: tracker,
                        customMealManager: customMealManager,
                        syncStatusViewModel: syncStatusViewModel,
                        syncEngine: syncEngine,
                        userId: authService.currentUser?.uid
                    )
                    .tabItem {
                        Label("Today", systemImage: "house.fill")
                    }
                    
                    // ... other tabs ...
                }
            }
        }
        .task {
            await initializeTracker()
            
            // Start network monitoring
            networkMonitor.start()
            
            // Start observing sync status
            if let syncEngine = syncEngine {
                await syncStatusViewModel.observeSyncEngine(syncEngine)
            }
            syncStatusViewModel.observeNetworkStatus(networkMonitor)
        }
        .onDisappear {
            networkMonitor.stop()
            syncStatusViewModel.stopObserving()
        }
    }
    
    private func initializeTracker() async {
        let dataStore = DataStore(modelContext: modelContext)
        
        // Create sync engine if user is authenticated
        if authService.currentUser != nil {
            syncEngine = FirebaseSyncEngine(dataStore: dataStore)
        }
        
        // ... rest of initialization ...
    }
}
```

## Manual Sync Trigger

You can manually trigger sync status updates from pull-to-refresh or button actions:

```swift
.refreshable {
    await syncStatusViewModel.refreshStatus()
    
    // Trigger actual sync operation
    if let syncEngine = syncEngine, let userId = userId {
        do {
            try await syncEngine.forceSyncNow()
            syncStatusViewModel.reportSyncCompleted()
        } catch {
            syncStatusViewModel.reportError("Sync failed: \(error.localizedDescription)")
        }
    }
}
```

## Error Reporting

Report sync errors to the view model:

```swift
do {
    try await syncEngine.syncFoodItem(foodItem, userId: userId)
} catch {
    syncStatusViewModel.reportError("Failed to sync: \(error.localizedDescription)")
}
```

## Customization

The badge appearance can be customized by modifying the `SyncStatusBadge` view:

- Change colors in `statusColor` computed property
- Adjust icon names in `iconName` computed property
- Modify text format in `statusText` computed property
- Customize background in `backgroundColor` computed property

## Requirements Validated

- **Requirement 6.4**: Sync status indicator displayed during synchronization
- **Requirement 7.5**: Offline indicator displayed when network unavailable
- **Requirement 13.5**: Manual sync trigger via pull-to-refresh

## Notes

- The view model polls the sync engine every 2 seconds for status updates
- Network status is monitored via the NetworkMonitor's @Observable property
- The badge automatically updates when sync state changes
- Rotation animation is applied to the icon during syncing state
- Relative time display shows "just now", "2m ago", "1h ago", etc.
