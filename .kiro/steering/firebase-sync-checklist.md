# Firebase Sync Integration Checklist

## Overview

This checklist ensures that all new models and entities are properly integrated with Firebase sync. When adding a new syncable entity to CountMe, follow these steps to ensure complete integration with the dual-persistence architecture.

## When to Use This Checklist

Use this checklist when:
- Creating a new model that needs to sync to Firestore
- Adding a new entity type to the sync system
- Modifying existing models to add sync capabilities
- Troubleshooting sync issues with existing entities

## Complete Integration Checklist

### 1. Model Implementation

#### ✅ Model Conforms to SyncableEntity Protocol
- [ ] Model is marked with `@Model` for SwiftData
- [ ] Model conforms to `SyncableEntity` protocol
- [ ] Has `_id: UUID` property for unique identification
- [ ] Has `userId: String` property for user ownership
- [ ] Has `lastModified: Date` property for conflict resolution
- [ ] Has `syncStatus: SyncStatus` property for sync state tracking
- [ ] Implements `id: String` computed property returning `_id.uuidString`

**Example:**
```swift
@Model
final class NewItem: SyncableEntity {
    var _id: UUID
    var userId: String = ""
    var lastModified: Date = Date()
    var syncStatus: SyncStatus = .pendingUpload
    
    var id: String {
        _id.uuidString
    }
    
    // ... other properties
}
```

#### ✅ Firestore Serialization Methods
- [ ] Implements `toFirestoreData() -> [String: Any]` method
- [ ] Converts all properties to Firestore-compatible types
- [ ] Uses `Timestamp(date:)` for Date properties
- [ ] Includes all required fields: id, userId, lastModified, syncStatus
- [ ] Handles optional properties correctly

**Example:**
```swift
func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
        "id": _id.uuidString,
        "userId": userId,
        "lastModified": Timestamp(date: lastModified),
        "syncStatus": syncStatus.rawValue
    ]
    
    // Add entity-specific fields
    data["name"] = name
    data["value"] = value
    
    return data
}
```

#### ✅ Firestore Deserialization Methods
- [ ] Implements `static func fromFirestoreData(_ data: [String: Any]) throws -> Self`
- [ ] Validates all required fields are present
- [ ] Converts Firestore types back to Swift types
- [ ] Validates data ranges (e.g., non-negative values)
- [ ] Throws `SyncError.invalidFirestoreData` for missing fields
- [ ] Throws `SyncError.invalidData(reason:)` for invalid values
- [ ] Uses internal validated initializer to skip double validation

**Example:**
```swift
static func fromFirestoreData(_ data: [String: Any]) throws -> NewItem {
    guard let idString = data["id"] as? String,
          let id = UUID(uuidString: idString),
          let userId = data["userId"] as? String,
          let lastModified = (data["lastModified"] as? Timestamp)?.dateValue(),
          let syncStatusRaw = data["syncStatus"] as? String,
          let syncStatus = SyncStatus(rawValue: syncStatusRaw),
          let name = data["name"] as? String,
          let value = data["value"] as? Double
    else {
        throw SyncError.invalidFirestoreData
    }
    
    // Validate ranges
    guard value >= 0 else {
        throw SyncError.invalidData(reason: "NewItem value \(value) is negative")
    }
    
    return NewItem(
        validated: id,
        name: name,
        value: value,
        userId: userId,
        lastModified: lastModified,
        syncStatus: syncStatus
    )
}
```

### 2. EntityType Enum Update

#### ✅ Add to EntityType Enum
- [ ] Add new case to `EntityType` enum in `FirebaseSyncEngine.swift`
- [ ] Use camelCase naming convention
- [ ] Ensure enum conforms to `String, Codable`

**Location:** `CountMe/Services/FirebaseSyncEngine.swift`

**Example:**
```swift
enum EntityType: String, Codable {
    case foodItem
    case exerciseItem
    case dailyLog
    case customMeal
    case userGoal
    case newItem  // Add your new entity here
}
```

### 3. Collection Path Configuration

#### ✅ Update getCollectionPath Method
- [ ] Add case to switch statement in `getCollectionPath(for:userId:)`
- [ ] Use plural form for collection name (e.g., "newItems")
- [ ] Follow existing naming convention

**Location:** `CountMe/Services/FirebaseSyncEngine.swift`

**Example:**
```swift
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
    case .newItem:
        collectionName = "newItems"  // Add your collection name
    }
    
    return "users/\(userId)/\(collectionName)"
}
```

### 4. FirebaseSyncEngine Methods

#### ✅ Upload Method
- [ ] Create `uploadNewItem(_ item: NewItem, userId: String) async throws` method
- [ ] Mark as private
- [ ] Check network connectivity
- [ ] Call `uploadToFirestore(entity:entityType:userId:)`
- [ ] Handle errors appropriately

**Example:**
```swift
private func uploadNewItem(_ item: NewItem, userId: String) async throws {
    guard await MainActor.run(body: { networkMonitor.isConnected }) else {
        throw SyncError.networkUnavailable
    }
    
    try await uploadToFirestore(
        entity: item,
        entityType: .newItem,
        userId: userId
    )
}
```

#### ✅ Sync Method (Public API)
- [ ] Create `func syncNewItem(_ item: NewItem, userId: String) async throws` method
- [ ] Mark as public
- [ ] Update item metadata (userId, lastModified, syncStatus)
- [ ] Check if item exists locally (fetch by ID)
- [ ] Use upsert pattern: update if exists, insert if new
- [ ] Save to local DataStore first (offline-first)
- [ ] Attempt cloud upload
- [ ] Queue for retry if upload fails
- [ ] Add comprehensive logging

**Example:**
```swift
func syncNewItem(_ item: NewItem, userId: String) async throws {
    var mutableItem = item
    mutableItem.userId = userId
    mutableItem.lastModified = Date()
    mutableItem.syncStatus = .pendingUpload
    
    do {
        // Upsert pattern: check if exists, then update or insert
        if let existing = try await dataStore.fetchNewItem(byId: mutableItem.id) {
            existing.userId = userId
            existing.lastModified = Date()
            existing.syncStatus = .pendingUpload
            try await dataStore.updateNewItem(existing)
            print("Updated NewItem \(mutableItem.id) in local store")
        } else {
            try await dataStore.insertNewItem(mutableItem)
            print("Inserted NewItem \(mutableItem.id) in local store")
        }
    } catch {
        throw SyncError.dataStoreError(error)
    }
    
    // Attempt cloud upload
    do {
        try await uploadNewItem(mutableItem, userId: userId)
        print("Uploaded NewItem \(mutableItem.id) to cloud")
    } catch SyncError.networkUnavailable {
        print("NewItem \(mutableItem.id) queued for sync when online")
    } catch {
        print("NewItem \(mutableItem.id) upload failed, queued for retry: \(error)")
    }
}
```

#### ✅ Download Method
- [ ] Create `private func downloadNewItems(userId: String) async throws -> [NewItem]` method
- [ ] Query Firestore with userId filter
- [ ] Parse each document using `fromFirestoreData`
- [ ] Validate userId matches (defense in depth)
- [ ] Log parsing errors but continue with other documents
- [ ] Return array of downloaded items

**Example:**
```swift
private func downloadNewItems(userId: String) async throws -> [NewItem] {
    let collectionPath = getCollectionPath(for: .newItem, userId: userId)
    
    let snapshot = try await db.collection(collectionPath)
        .whereField("userId", isEqualTo: userId)
        .getDocuments()
    
    var items: [NewItem] = []
    for document in snapshot.documents {
        do {
            let item = try NewItem.fromFirestoreData(document.data())
            
            guard item.userId == userId else {
                print("⚠️ Skipping NewItem \(document.documentID) with mismatched userId")
                continue
            }
            
            items.append(item)
        } catch {
            print("Failed to parse NewItem document \(document.documentID): \(error)")
        }
    }
    
    return items
}
```

#### ✅ Update downloadFromFirestore Method
- [ ] Add async let for downloading new items
- [ ] Include in parallel download tuple
- [ ] Pass to `updateLocalStore` method

**Example:**
```swift
func downloadFromFirestore(userId: String) async throws {
    guard !userId.isEmpty else {
        throw SyncError.notAuthenticated
    }
    
    async let foodItems = downloadFoodItems(userId: userId)
    async let exerciseItems = downloadExerciseItems(userId: userId)
    async let dailyLogs = downloadDailyLogs(userId: userId)
    async let customMeals = downloadCustomMeals(userId: userId)
    async let newItems = downloadNewItems(userId: userId)  // Add this
    
    do {
        let (downloadedFoodItems, downloadedExerciseItems, downloadedDailyLogs, 
             downloadedCustomMeals, downloadedNewItems) = try await (
            foodItems, exerciseItems, dailyLogs, customMeals, newItems
        )
        
        try await updateLocalStore(
            foodItems: downloadedFoodItems,
            exerciseItems: downloadedExerciseItems,
            dailyLogs: downloadedDailyLogs,
            customMeals: downloadedCustomMeals,
            newItems: downloadedNewItems  // Add this
        )
    } catch {
        throw SyncError.firestoreError(error)
    }
}
```

#### ✅ Update updateLocalStore Method
- [ ] Add parameter for new items array
- [ ] Implement merge logic (compare timestamps, keep newer)
- [ ] Update local store with merged data

### 5. DataStore Methods

#### ✅ CRUD Operations
- [ ] `func insertNewItem(_ item: NewItem) async throws`
- [ ] `func updateNewItem(_ item: NewItem) async throws`
- [ ] `func deleteNewItem(_ item: NewItem) async throws`
- [ ] `func fetchNewItem(byId id: String) async throws -> NewItem?`
- [ ] `func fetchAllNewItems() async throws -> [NewItem]`

**Location:** `CountMe/Services/DataStore.swift`

**Example:**
```swift
func insertNewItem(_ item: NewItem) async throws {
    modelContext.insert(item)
    try modelContext.save()
}

func updateNewItem(_ item: NewItem) async throws {
    try modelContext.save()
}

func deleteNewItem(_ item: NewItem) async throws {
    modelContext.delete(item)
    try modelContext.save()
}

func fetchNewItem(byId id: String) async throws -> NewItem? {
    guard let uuid = UUID(uuidString: id) else {
        return nil
    }
    
    let descriptor = FetchDescriptor<NewItem>(
        predicate: #Predicate { item in
            item._id == uuid
        }
    )
    
    let items = try modelContext.fetch(descriptor)
    return items.first
}

func fetchAllNewItems() async throws -> [NewItem] {
    let descriptor = FetchDescriptor<NewItem>(
        sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
    )
    
    return try modelContext.fetch(descriptor)
}
```

### 6. Firestore Security Rules

#### ✅ Add Collection Rules
- [ ] Open `firestore.rules` file
- [ ] Add new collection rules section
- [ ] Follow existing pattern (copy from foodItems or exerciseItems)
- [ ] Ensure userId validation on create
- [ ] Ensure ownership check on read/update/delete
- [ ] Add documentation comments

**Location:** `firestore.rules`

**Example:**
```javascript
// ============================================================================
// New Items Collection
// ============================================================================

/// New items collection - stores [description]
/// Path: users/{userId}/newItems/{itemId}
/// Access: User can only access their own new items
/// Validation: userId in document must match authenticated user
match /users/{userId}/newItems/{itemId} {
  // Read: User can read their own new items
  allow read: if isOwner(userId);
  
  // Update/Delete: User can modify their own new items
  allow update, delete: if isOwner(userId);
  
  // Create: User can create new items with their userId
  allow create: if isAuthenticated() && 
                   request.resource.data.userId == request.auth.uid;
}
```

#### ✅ Deploy Rules
- [ ] Run `firebase deploy --only firestore:rules`
- [ ] Or update via Firebase Console
- [ ] Verify deployment successful

### 7. Testing

#### ✅ Unit Tests
- [ ] Create test file: `CountMeTests/Services/NewItemSyncTests.swift`
- [ ] Test sync method with upsert pattern
- [ ] Test upload method
- [ ] Test download method
- [ ] Test error handling
- [ ] Test offline behavior

**Example:**
```swift
@Test("syncNewItem updates existing item instead of inserting")
func testSyncNewItem_ExistingItem_UpdatesInsteadOfInsert() async throws {
    let container = try createTestContainer()
    let dataStore = DataStore(modelContext: ModelContext(container))
    let syncEngine = FirebaseSyncEngine(dataStore: dataStore)
    
    let item = try NewItem(name: "Test", value: 100)
    try await dataStore.insertNewItem(item)
    
    let fetchedBefore = try await dataStore.fetchNewItem(byId: item.id)
    #expect(fetchedBefore != nil)
    #expect(fetchedBefore?.userId == "")
    
    do {
        try await syncEngine.syncNewItem(item, userId: "test-user")
    } catch {
        // Network errors expected in tests
    }
    
    let fetchedAfter = try await dataStore.fetchNewItem(byId: item.id)
    #expect(fetchedAfter?.userId == "test-user")
    #expect(fetchedAfter?.syncStatus == .pendingUpload)
}
```

#### ✅ Property Tests
- [ ] Test data preservation across sync (100+ iterations)
- [ ] Test with random valid data
- [ ] Verify all properties maintained

### 8. Integration Points

#### ✅ CalorieTracker or Manager Class
- [ ] Add methods to add/remove/update new items
- [ ] Call sync methods when authenticated
- [ ] Handle errors gracefully
- [ ] Reload data after operations

#### ✅ Views
- [ ] Display new items from cache or relationship
- [ ] Trigger sync on user actions
- [ ] Show sync status indicators
- [ ] Handle offline state

### 9. Documentation

#### ✅ Code Documentation
- [ ] Add doc comments to all public methods
- [ ] Document parameters and return values
- [ ] Note any validation requirements
- [ ] Reference requirement numbers if applicable

#### ✅ Update Project Documentation
- [ ] Add to project-foundation.md if needed
- [ ] Update architecture diagrams if applicable
- [ ] Document any special considerations

## Common Pitfalls to Avoid

### ❌ Don't
- Skip the upsert pattern in sync methods (causes duplicates)
- Forget to add Firestore security rules (causes permission errors)
- Use insert when item might already exist (causes conflicts)
- Skip userId validation in Firestore rules (security risk)
- Forget to update downloadFromFirestore (items won't sync down)
- Skip error handling in sync methods (causes silent failures)
- Forget to add to EntityType enum (causes runtime errors)

### ✅ Do
- Always use upsert pattern (check exists, then update or insert)
- Add comprehensive Firestore security rules
- Validate all data in fromFirestoreData
- Handle network errors gracefully
- Log all sync operations for debugging
- Test both upload and download flows
- Update all integration points

## Verification Checklist

After implementing, verify:
- [ ] Item can be created locally
- [ ] Item syncs to Firestore when online
- [ ] Item can be downloaded from Firestore
- [ ] Item appears in UI after sync
- [ ] Manual refresh downloads items
- [ ] Offline operations queue correctly
- [ ] Security rules prevent unauthorized access
- [ ] All tests pass
- [ ] No console errors during sync

## Example: Complete Integration

See `ExerciseItem` as a reference implementation:
- Model: `CountMe/Models/ExerciseItem.swift`
- Sync methods: `CountMe/Services/FirebaseSyncEngine.swift` (search for "ExerciseItem")
- DataStore methods: `CountMe/Services/DataStore.swift` (search for "ExerciseItem")
- Security rules: `firestore.rules` (Exercise Items Collection section)
- Tests: `CountMeTests/Services/ExerciseSyncTests.swift`

## Quick Reference

**Files to Update:**
1. `CountMe/Models/YourModel.swift` - Model implementation
2. `CountMe/Services/FirebaseSyncEngine.swift` - Sync logic
3. `CountMe/Services/DataStore.swift` - CRUD operations
4. `firestore.rules` - Security rules
5. `CountMeTests/Services/YourModelSyncTests.swift` - Tests

**Key Methods:**
- `toFirestoreData()` - Serialize to Firestore
- `fromFirestoreData(_:)` - Deserialize from Firestore
- `syncYourModel(_:userId:)` - Public sync API
- `uploadYourModel(_:userId:)` - Upload to cloud
- `downloadYourModels(userId:)` - Download from cloud

**Security Rule Pattern:**
```javascript
match /users/{userId}/yourCollection/{itemId} {
  allow read: if isOwner(userId);
  allow update, delete: if isOwner(userId);
  allow create: if isAuthenticated() && 
                   request.resource.data.userId == request.auth.uid;
}
```
