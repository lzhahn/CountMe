# Firestore Security Rules Documentation

## Overview

This document describes the Firestore security rules implemented for the CountMe application. These rules enforce user-scoped data access, ensuring that users can only access their own calorie tracking data.

## Security Model

### Core Principles

1. **Authentication Required**: All data access requires a valid Firebase Authentication token
2. **User-Scoped Access**: Users can only access data associated with their own user ID
3. **Ownership Validation**: All write operations validate that the userId in the data matches the authenticated user
4. **Default Deny**: Any collection not explicitly allowed is denied by default

### Helper Functions

#### `isAuthenticated()`
Checks if the request is from an authenticated user.

```javascript
function isAuthenticated() {
  return request.auth != null;
}
```

**Returns**: `true` if user is authenticated, `false` otherwise

#### `isOwner(userId)`
Checks if the authenticated user owns the resource.

```javascript
function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}
```

**Parameters**:
- `userId`: The user ID to check ownership against

**Returns**: `true` if authenticated user matches userId, `false` otherwise

#### `hasValidUserId()`
Validates that the data being written has the correct userId.

```javascript
function hasValidUserId() {
  return isAuthenticated() && 
         request.resource.data.userId == request.auth.uid;
}
```

**Returns**: `true` if userId in data matches authenticated user

## Collection Rules

### User Profile and Settings

**Path**: `users/{userId}/profile/{document}`

**Access Rules**:
- Read: User can read their own profile
- Write: User can write their own profile

**Validation**: Ownership checked via `isOwner(userId)`

### Daily Logs

**Path**: `users/{userId}/dailyLogs/{logId}`

**Access Rules**:
- Read: User can read their own daily logs
- Update/Delete: User can modify their own daily logs
- Create: User can create daily logs with their userId

**Validation**: 
- Ownership checked via `isOwner(userId)`
- Create operations validate `request.resource.data.userId == request.auth.uid`

**Data Structure**:
```javascript
{
  id: String,
  date: Timestamp,
  totalCalories: Double,
  userId: String,  // Must match authenticated user
  lastModified: Timestamp,
  syncStatus: String
}
```

### Food Items

**Path**: `users/{userId}/foodItems/{itemId}`

**Access Rules**:
- Read: User can read their own food items
- Update/Delete: User can modify their own food items
- Create: User can create food items with their userId

**Validation**: 
- Ownership checked via `isOwner(userId)`
- Create operations validate `request.resource.data.userId == request.auth.uid`

**Data Structure**:
```javascript
{
  id: String,
  name: String,
  calories: Double,
  servingSize: String,
  timestamp: Timestamp,
  source: String,
  dailyLogId: String,
  userId: String,  // Must match authenticated user
  lastModified: Timestamp,
  syncStatus: String
}
```

### Custom Meals

**Path**: `users/{userId}/customMeals/{mealId}`

**Access Rules**:
- Read: User can read their own custom meals
- Update/Delete: User can modify their own custom meals
- Create: User can create custom meals with their userId

**Validation**: 
- Ownership checked via `isOwner(userId)`
- Create operations validate `request.resource.data.userId == request.auth.uid`

**Data Structure**:
```javascript
{
  id: String,
  name: String,
  totalCalories: Double,
  ingredients: Array<Map>,
  userId: String,  // Must match authenticated user
  lastModified: Timestamp,
  syncStatus: String
}
```

## Deployment

### Prerequisites

1. **Firebase CLI**: Install globally
   ```bash
   npm install -g firebase-tools
   ```

2. **Authentication**: Login to Firebase
   ```bash
   firebase login
   ```

3. **Project Initialization**: Initialize Firestore (if not already done)
   ```bash
   firebase init firestore
   ```

### Deploy Rules

Use the provided deployment script:

```bash
./deploy-firestore-rules.sh
```

Or deploy manually:

```bash
firebase deploy --only firestore:rules
```

### Verify Deployment

1. Visit the Firebase Console: https://console.firebase.google.com
2. Select your project
3. Navigate to Firestore Database → Rules
4. Verify the rules match the `firestore.rules` file

## Testing Security Rules

### Test in Firebase Console

1. Go to Firestore Database → Rules
2. Click the "Rules Playground" tab
3. Test various scenarios:
   - Authenticated user accessing their own data (should succeed)
   - Authenticated user accessing another user's data (should fail)
   - Unauthenticated access (should fail)

### Test Scenarios

#### ✅ Should Succeed

1. **Authenticated user reads their own daily log**
   ```
   Location: /users/user123/dailyLogs/log456
   Auth: user123
   Operation: get
   Expected: Allow
   ```

2. **Authenticated user creates food item with their userId**
   ```
   Location: /users/user123/foodItems/item789
   Auth: user123
   Data: { userId: "user123", ... }
   Operation: create
   Expected: Allow
   ```

#### ❌ Should Fail

1. **Authenticated user reads another user's data**
   ```
   Location: /users/user456/dailyLogs/log789
   Auth: user123
   Operation: get
   Expected: Deny
   ```

2. **Unauthenticated access**
   ```
   Location: /users/user123/dailyLogs/log456
   Auth: null
   Operation: get
   Expected: Deny
   ```

3. **User creates data with wrong userId**
   ```
   Location: /users/user123/foodItems/item789
   Auth: user123
   Data: { userId: "user456", ... }
   Operation: create
   Expected: Deny
   ```

## Security Considerations

### What These Rules Protect Against

1. **Unauthorized Access**: Users cannot read other users' data
2. **Data Tampering**: Users cannot modify other users' data
3. **Impersonation**: Users cannot create data with another user's ID
4. **Unauthenticated Access**: All operations require authentication

### What These Rules Don't Protect Against

1. **Data Validation**: Rules don't validate data types or required fields (handled by client)
2. **Rate Limiting**: No protection against excessive requests (use Firebase App Check)
3. **Cost Control**: No limits on data size or query complexity (monitor usage)

### Additional Security Recommendations

1. **Enable Firebase App Check**: Protects against abuse from unauthorized clients
2. **Monitor Usage**: Set up billing alerts and usage quotas
3. **Regular Audits**: Review Firestore usage logs for suspicious activity
4. **Client-Side Validation**: Always validate data before writing to Firestore
5. **Keep Rules Updated**: Review and update rules as features are added

## Troubleshooting

### Common Issues

#### "Permission Denied" Errors

**Symptom**: Operations fail with permission denied errors

**Possible Causes**:
1. User not authenticated
2. Trying to access another user's data
3. userId in data doesn't match authenticated user
4. Rules not deployed

**Solutions**:
1. Verify user is signed in: `Auth.auth().currentUser != nil`
2. Check userId in path matches authenticated user
3. Verify userId in data matches authenticated user
4. Redeploy rules: `firebase deploy --only firestore:rules`

#### Rules Not Taking Effect

**Symptom**: Old rules still active after deployment

**Solutions**:
1. Wait 1-2 minutes for rules to propagate
2. Clear browser cache
3. Verify deployment succeeded in Firebase Console
4. Check for syntax errors in rules file

#### Testing Issues

**Symptom**: Rules work in console but fail in app

**Solutions**:
1. Verify Firebase SDK is properly initialized
2. Check authentication state in app
3. Verify collection paths match exactly
4. Enable Firestore debug logging to see detailed errors

## Maintenance

### When to Update Rules

Update security rules when:
1. Adding new collections
2. Changing data structure
3. Adding new user roles or permissions
4. Implementing new features that access Firestore

### Version Control

- Keep `firestore.rules` in version control
- Document rule changes in commit messages
- Test rules in development before deploying to production
- Consider using separate Firebase projects for dev/staging/production

## References

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Security Rules Language Reference](https://firebase.google.com/docs/rules/rules-language)
- [Security Rules Testing](https://firebase.google.com/docs/rules/unit-tests)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
