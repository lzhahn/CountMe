# Setup Apple and Google Sign-In

I've added Apple Sign-In and Google Sign-In support to CountMe. Follow these steps to complete the setup:

## 1. Add GoogleSignIn Swift Package

1. Open `CountMe.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. In the search bar, enter: `https://github.com/google/GoogleSignIn-iOS`
4. Select the latest version (7.0.0 or higher)
5. Click **Add Package**
6. In the "Choose Package Products" dialog:
   - Select **GoogleSignIn** and **GoogleSignInSwift**
   - Make sure they're added to the **CountMe** target
7. Click **Add Package**

## 2. Configure Apple Sign-In

### Enable in Xcode:
1. Select the **CountMe** project in the navigator
2. Select the **CountMe** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign in with Apple**

### Enable in Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your CountMe project
3. Go to **Authentication → Sign-in method**
4. Click on **Apple**
5. Click **Enable**
6. Click **Save**

## 3. Configure Google Sign-In

### Get OAuth Client ID from Firebase:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your CountMe project
3. Go to **Authentication → Sign-in method**
4. Click on **Google**
5. Click **Enable**
6. Note the **Web client ID** (you'll need this)
7. Click **Save**

### Add URL Scheme to Xcode:
1. Open `CountMe/GoogleService-Info.plist`
2. Find the value for `REVERSED_CLIENT_ID` (looks like `com.googleusercontent.apps.XXXXXXXXX`)
3. In Xcode, select the **CountMe** project
4. Select the **CountMe** target
5. Go to **Info** tab
6. Expand **URL Types**
7. Click **+** to add a new URL Type
8. Set **URL Schemes** to the `REVERSED_CLIENT_ID` value from step 2
9. Set **Identifier** to `com.google.gid.reverseClientId`

### Update Info.plist:
Add the following to your `Info.plist` (or use Xcode's Info tab):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID_HERE</string>
        </array>
    </dict>
</array>
```

## 4. Test the Implementation

### Build and Run:
```bash
xcodebuild -project CountMe.xcodeproj -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' clean build
```

### Test Sign-In Flow:
1. Launch the app
2. You should see:
   - Email/Password fields
   - "Sign in with Apple" button (black)
   - "Sign in with Google" button (white with border)
3. Try signing in with Apple (works in simulator)
4. Try signing in with Google (requires real device or configured simulator)

## 5. Firestore Security Rules

Make sure your Firestore security rules allow authenticated users:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /foodItems/{itemId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    
    match /dailyLogs/{logId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    
    match /customMeals/{mealId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

## What I've Implemented

### FirebaseAuthService.swift:
- ✅ `signInWithApple()` - Handles Apple Sign-In with nonce validation
- ✅ `prepareAppleSignIn()` - Generates secure nonce for Apple Sign-In
- ✅ `signInWithGoogle()` - Handles Google Sign-In flow
- ✅ Helper methods for nonce generation and SHA256 hashing

### AuthenticationView.swift:
- ✅ Added Apple Sign-In button to both Sign-In and Sign-Up views
- ✅ Added Google Sign-In button to both Sign-In and Sign-Up views
- ✅ Added "OR" divider between email/password and social sign-in
- ✅ Proper error handling for both sign-in methods

## Features

- **Apple Sign-In**: Native iOS integration with secure nonce validation
- **Google Sign-In**: Full OAuth flow with Firebase integration
- **Unified Experience**: Both methods integrate seamlessly with existing Firebase auth
- **Error Handling**: Comprehensive error messages for all failure scenarios
- **UI/UX**: Clean, modern design matching iOS standards

## Notes

- Apple Sign-In works in the iOS Simulator
- Google Sign-In requires additional setup for simulator testing
- Both methods automatically sync with Firebase Authentication
- User data is associated with the Firebase UID regardless of sign-in method
- Existing email/password authentication continues to work alongside social sign-in
