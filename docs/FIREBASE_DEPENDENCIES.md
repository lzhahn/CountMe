# Firebase Dependencies

This document lists the Firebase SDK dependencies required for the CountMe project.

## Swift Package Manager Dependencies

Add these packages to your Xcode project via Swift Package Manager:

### Firebase iOS SDK

**Repository URL**: `https://github.com/firebase/firebase-ios-sdk`

**Version**: Latest (or specify a version like `10.20.0`)

**Products to Add**:

1. **FirebaseAuth**
   - Purpose: User authentication (email/password, session management)
   - Used by: `FirebaseAuthService`
   - Features:
     - Email/password authentication
     - Session persistence
     - Password reset
     - Account deletion

2. **FirebaseFirestore**
   - Purpose: Cloud NoSQL database for data synchronization
   - Used by: `FirebaseSyncEngine`, `DataStore`
   - Features:
     - Real-time data synchronization
     - Offline persistence
     - Automatic conflict resolution
     - Security rules

## How to Add in Xcode

1. Open `CountMe.xcodeproj` in Xcode
2. Select the project in the Project Navigator
3. Select the **CountMe** target
4. Go to **General** tab
5. Scroll to **Frameworks, Libraries, and Embedded Content**
6. Click **+** → **Add Package Dependency**
7. Enter repository URL: `https://github.com/firebase/firebase-ios-sdk`
8. Select version (recommend: "Up to Next Major Version" with latest)
9. Select products: **FirebaseAuth** and **FirebaseFirestore**
10. Click **Add Package**

## Minimum iOS Version

Firebase iOS SDK requires:
- iOS 13.0 or later
- Xcode 15.0 or later

Current CountMe deployment target: iOS 26.1 ✅

## Package Size

Approximate download sizes:
- FirebaseAuth: ~2 MB
- FirebaseFirestore: ~5 MB
- Total: ~7 MB

## Import Statements

Once packages are added, use these imports in your Swift files:

```swift
// For authentication
import FirebaseAuth

// For Firestore database
import FirebaseFirestore

// For Firebase core (initialization)
import FirebaseCore
```

## Verification

After adding packages, verify they appear in:
- Project Navigator → Package Dependencies → firebase-ios-sdk

Build the project to ensure packages are properly linked:
```bash
xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Troubleshooting

### Package Resolution Issues

If Xcode fails to resolve packages:
1. File → Packages → Reset Package Caches
2. File → Packages → Update to Latest Package Versions
3. Clean build folder (Shift + Cmd + K)
4. Restart Xcode

### Build Errors

If you see "No such module" errors:
1. Verify packages are added to the correct target (CountMe)
2. Clean and rebuild
3. Check that import statements match package names exactly

## Additional Packages (Future)

These packages may be added in future tasks:
- **FirebaseStorage**: For file uploads (profile pictures, meal images)
- **FirebaseAnalytics**: For usage analytics (optional)
- **FirebaseCrashlytics**: For crash reporting (optional)

## Documentation

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Firebase Auth iOS](https://firebase.google.com/docs/auth/ios/start)
- [Firestore iOS](https://firebase.google.com/docs/firestore/quickstart)
