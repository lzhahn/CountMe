# Security Implementation Guide

## Overview

This document describes the security implementation for the CountMe Firebase integration, covering both Firestore security rules and application-level security measures.

## Security Architecture

### Defense in Depth

The security implementation follows a defense-in-depth strategy with multiple layers:

1. **Firestore Security Rules** (Server-side): Enforced by Firebase, cannot be bypassed
2. **Application Validation** (Client-side): Validates data before sending to Firestore
3. **Query Filtering** (Client-side): Ensures queries only request user's own data
4. **Data Validation** (Client-side): Validates userId matches authenticated user

### Security Layers

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Firestore Security Rules (Server-Side)        │
│ - Authentication required for all operations           │
│ - User can only access their own data                  │
│ - userId validation on create operations               │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Application Validation (Client-Side)          │
│ - Validate entity has userId before upload             │
│ - Validate userId matches authenticated user           │
│ - Reject invalid data before network call              │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Query Filtering (Client-Side)                 │
│ - All queries filter by userId                         │
│ - Real-time listeners filter by userId                 │
│ - Additional validation on received data               │
└─────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Firestore Security Rules

**Location**: `firestore.rules`

**Key Features**:
- Helper functions for authentication and ownership checks
- User-scoped collections under `users/{userId}/`
- Separate rules for each collection type
- Default deny for all other paths

**Collections Protected**:
- `users/{userId}/profile/{document}` - User profile and settings
- `users/{userId}/dailyLogs/{logId}` - Daily calorie logs
- `users/{userId}/foodItems/{itemId}` - Individual food entries
- `users/{userId}/customMeals/{mealId}` - Custom meal templates

**Deployment**:
```bash
./deploy-firestore-rules.sh
```

See `FIRESTORE_SECURITY_RULES.md` for detailed documentation.

### 2. Application-Level Security

#### Upload Validation

**Location**: `CountMe/Services/FirebaseSyncEngine.swift` - `uploadToFirestore()` method

**Validations Performed**:

1. **Authentication Check**:
   ```swift
   guard !userId.isEmpty else {
       throw SyncError.notAuthenticated
   }
   ```

2. **Entity Has UserId**:
   ```swift
   guard !entity.userId.isEmpty else {
       throw SyncError.invalidData(reason: "Entity missing userId")
   }
   ```

3. **UserId Matches Authenticated User**:
   ```swift
   guard entity.userId == userId else {
       throw SyncError.invalidData(reason: "Entity userId does not match authenticated user")
   }
   ```

**Requirements Validated**: 10.3 (Data Has User ID)

#### Query Filtering

**Location**: `CountMe/Services/FirebaseSyncEngine.swift` - Download methods

**Implementation**:

All Firestore queries include a `whereField("userId", isEqualTo: userId)` filter:

```swift
// Example: downloadFoodItems
let snapshot = try await db.collection(collectionPath)
    .whereField("userId", isEqualTo: userId)
    .getDocuments()
```

**Additional Validation**:

After parsing each document, we validate the userId matches:

```swift
guard foodItem.userId == userId else {
    print("⚠️ Skipping FoodItem with mismatched userId")
    continue
}
```

**Methods with Query Filtering**:
- `downloadFoodItems(userId:)` - Downloads food items
- `downloadDailyLogs(userId:)` - Downloads daily logs
- `downloadCustomMeals(userId:)` - Downloads custom meals
- `setupRealtimeListener(collection:userId:entityType:)` - Real-time updates

**Requirements Validated**: 10.4 (Query Filters By User ID)

#### Real-Time Listener Security

**Location**: `CountMe/Services/FirebaseSyncEngine.swift` - `setupRealtimeListener()` method

**Implementation**:

1. **Query Filtering**:
   ```swift
   let listener = db.collection(collectionPath)
       .whereField("userId", isEqualTo: userId)
       .addSnapshotListener { ... }
   ```

2. **Update Validation**:
   ```swift
   private func handleCloudUpdate(_ snapshot: DocumentSnapshot, 
                                  entityType: EntityType, 
                                  expectedUserId: String) async {
       // Parse entity
       let cloudItem = try FoodItem.fromFirestoreData(data)
       
       // Validate userId matches
       guard cloudItem.userId == expectedUserId else {
           print("⚠️ Skipping cloud update - userId mismatch")
           return
       }
       
       // Process update
       try await handleFoodItemUpdate(cloudItem)
   }
   ```

**Requirements Validated**: 10.4 (Query Filters By User ID)

### 3. Error Handling

**New Error Type**: `SyncError.invalidData(reason: String)`

**Usage**:
- Thrown when entity is missing userId
- Thrown when entity's userId doesn't match authenticated user
- Provides descriptive error message for debugging

**Error Message**:
```swift
case .invalidData(let reason):
    return "Invalid data: \(reason)"
```

## Security Requirements Coverage

### Requirement 10.1: Authentication Required
**Implementation**: Firestore security rules require authentication for all operations
**Validation**: `isAuthenticated()` helper function in rules

### Requirement 10.2: User-Scoped Access
**Implementation**: Firestore security rules restrict access to user's own data
**Validation**: `isOwner(userId)` helper function in rules

### Requirement 10.3: Data Has User ID
**Implementation**: 
- Application validates entity has userId before upload
- Application validates userId matches authenticated user
- Firestore rules validate userId on create operations

**Code Locations**:
- `FirebaseSyncEngine.uploadToFirestore()` - Upload validation
- `firestore.rules` - Create operation validation

### Requirement 10.4: Query Filters By User ID
**Implementation**:
- All download queries filter by userId
- All real-time listeners filter by userId
- Additional validation on received data

**Code Locations**:
- `FirebaseSyncEngine.downloadFoodItems()` - Query filtering
- `FirebaseSyncEngine.downloadDailyLogs()` - Query filtering
- `FirebaseSyncEngine.downloadCustomMeals()` - Query filtering
- `FirebaseSyncEngine.setupRealtimeListener()` - Listener filtering
- `FirebaseSyncEngine.handleCloudUpdate()` - Data validation

### Requirement 10.5: Reject Unauthenticated Access
**Implementation**: Firestore security rules reject all unauthenticated requests
**Validation**: Default deny rule in `firestore.rules`

## Testing Security

### Manual Testing

1. **Test Authenticated Access**:
   - Sign in as user A
   - Create food items, daily logs, custom meals
   - Verify all data is saved with correct userId
   - Verify all data can be retrieved

2. **Test Cross-User Access Prevention**:
   - Sign in as user A, create data
   - Sign out, sign in as user B
   - Verify user B cannot see user A's data
   - Verify user B can only see their own data

3. **Test Unauthenticated Access Prevention**:
   - Sign out
   - Attempt to access Firestore directly (should fail)
   - Verify app shows authentication screen

4. **Test UserId Validation**:
   - Attempt to create entity with wrong userId (should fail)
   - Attempt to upload entity without userId (should fail)
   - Verify error messages are descriptive

### Automated Testing

**Property-Based Tests** (Optional Task 15.3):

- **Property 24: Data Has User ID** - Validates all uploaded data has userId
- **Property 25: Query Filters By User ID** - Validates queries only return user's data

### Security Audit Checklist

- [ ] Firestore security rules deployed
- [ ] All collections have user-scoped access rules
- [ ] All queries filter by userId
- [ ] All uploads validate userId
- [ ] Real-time listeners filter by userId
- [ ] Error handling provides security without leaking information
- [ ] No hardcoded credentials in code
- [ ] Firebase configuration properly secured

## Security Best Practices

### Do's

✅ **Always validate userId before upload**
✅ **Always filter queries by userId**
✅ **Use defense in depth - multiple validation layers**
✅ **Log security-related errors for monitoring**
✅ **Keep Firestore rules in version control**
✅ **Test security rules before deploying**
✅ **Use Firebase App Check for additional protection**

### Don'ts

❌ **Don't trust client-side validation alone**
❌ **Don't skip userId validation**
❌ **Don't query without userId filter**
❌ **Don't expose sensitive error details to users**
❌ **Don't hardcode credentials**
❌ **Don't deploy rules without testing**

## Monitoring and Maintenance

### Regular Security Audits

1. **Review Firestore Usage Logs**:
   - Check for unusual access patterns
   - Monitor for permission denied errors
   - Look for suspicious query patterns

2. **Review Application Logs**:
   - Check for userId validation failures
   - Monitor for authentication errors
   - Look for data mismatch warnings

3. **Update Security Rules**:
   - Review rules when adding new features
   - Update rules when data structure changes
   - Test rules in development before production

### Security Incident Response

If a security issue is discovered:

1. **Immediate Actions**:
   - Assess the scope of the issue
   - Determine if data was compromised
   - Deploy fix to security rules if needed

2. **Investigation**:
   - Review Firestore usage logs
   - Identify affected users
   - Determine root cause

3. **Remediation**:
   - Fix the vulnerability
   - Test the fix thoroughly
   - Deploy to production
   - Monitor for recurrence

4. **Communication**:
   - Notify affected users if needed
   - Document the incident
   - Update security procedures

## Additional Security Measures

### Firebase App Check

**Recommended**: Enable Firebase App Check to protect against abuse from unauthorized clients.

**Setup**:
1. Enable App Check in Firebase Console
2. Register your app with App Check
3. Add App Check SDK to your app
4. Enforce App Check in Firestore rules

### Rate Limiting

**Recommended**: Implement rate limiting to prevent abuse.

**Options**:
- Firebase App Check (built-in rate limiting)
- Cloud Functions with rate limiting
- Custom rate limiting in application logic

### Data Encryption

**Current**: Data is encrypted in transit (HTTPS) and at rest (Firebase default)

**Additional**: Consider client-side encryption for sensitive data before upload

### Audit Logging

**Recommended**: Enable Firestore audit logging for compliance and security monitoring.

**Setup**:
1. Enable Cloud Audit Logs in Google Cloud Console
2. Configure log retention period
3. Set up log analysis and alerting

## References

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Authentication Best Practices](https://firebase.google.com/docs/auth/best-practices)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

## Appendix: Code Examples

### Example: Secure Upload

```swift
// In FirebaseSyncEngine.swift
func uploadToFirestore(_ entity: SyncableEntity, userId: String) async throws {
    // Layer 1: Validate authentication
    guard !userId.isEmpty else {
        throw SyncError.notAuthenticated
    }
    
    // Layer 2: Validate entity has userId
    guard !entity.userId.isEmpty else {
        throw SyncError.invalidData(reason: "Entity missing userId")
    }
    
    // Layer 3: Validate userId matches
    guard entity.userId == userId else {
        throw SyncError.invalidData(reason: "UserId mismatch")
    }
    
    // Layer 4: Upload (Firestore rules provide final validation)
    try await db.collection(collectionPath)
        .document(entity.id)
        .setData(entity.toFirestoreData())
}
```

### Example: Secure Query

```swift
// In FirebaseSyncEngine.swift
private func downloadFoodItems(userId: String) async throws -> [FoodItem] {
    let collectionPath = getCollectionPath(for: .foodItem, userId: userId)
    
    // Layer 1: Query with userId filter
    let snapshot = try await db.collection(collectionPath)
        .whereField("userId", isEqualTo: userId)
        .getDocuments()
    
    var foodItems: [FoodItem] = []
    for document in snapshot.documents {
        let foodItem = try FoodItem.fromFirestoreData(document.data())
        
        // Layer 2: Additional validation
        guard foodItem.userId == userId else {
            print("⚠️ Skipping item with mismatched userId")
            continue
        }
        
        foodItems.append(foodItem)
    }
    
    return foodItems
}
```

### Example: Secure Real-Time Listener

```swift
// In FirebaseSyncEngine.swift
private func setupRealtimeListener(collection: String, userId: String, entityType: EntityType) {
    let collectionPath = getCollectionPath(for: entityType, userId: userId)
    
    // Layer 1: Listener with userId filter
    let listener = db.collection(collectionPath)
        .whereField("userId", isEqualTo: userId)
        .addSnapshotListener { [weak self] querySnapshot, error in
            // Handle updates
            for documentChange in snapshot.documentChanges {
                Task {
                    // Layer 2: Validate userId in handler
                    await self.handleCloudUpdate(
                        documentChange.document, 
                        entityType: entityType,
                        expectedUserId: userId
                    )
                }
            }
        }
    
    listeners.append(listener)
}
```
