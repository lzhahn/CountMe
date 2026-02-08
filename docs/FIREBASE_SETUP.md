# Firebase Setup Guide for CountMe

This guide walks you through setting up Firebase Authentication and Firestore for the CountMe iOS app.

## Prerequisites

- Xcode 15.0 or later
- iOS 15.0+ deployment target
- A Firebase account (free tier is sufficient)

## Step 1: Add Firebase SDK via Swift Package Manager

Since Xcode project files are complex to modify programmatically, you'll need to add the Firebase SDK manually through Xcode:

### 1.1 Open the Project in Xcode

```bash
open CountMe.xcodeproj
```

### 1.2 Add Firebase Package

1. In Xcode, select the **CountMe** project in the Project Navigator
2. Select the **CountMe** target
3. Click on the **General** tab
4. Scroll down to **Frameworks, Libraries, and Embedded Content**
5. Click the **+** button
6. Click **Add Package Dependency...**
7. In the search field, enter: `https://github.com/firebase/firebase-ios-sdk`
8. Click **Add Package**
9. Select the following products to add to your target:
   - **FirebaseAuth** (for authentication)
   - **FirebaseFirestore** (for cloud database)
10. Click **Add Package**

### 1.3 Verify Installation

After adding the packages, you should see them listed under:
- Project Navigator → CountMe → Package Dependencies → firebase-ios-sdk

## Step 2: Configure Firebase Project

### 2.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** (or select an existing project)
3. Enter project name: `CountMe` (or your preferred name)
4. Follow the setup wizard:
   - Disable Google Analytics (optional, not needed for this app)
   - Click **Create project**

### 2.2 Add iOS App to Firebase

1. In your Firebase project, click the iOS icon to add an iOS app
2. Register your app:
   - **iOS bundle ID**: `Halu.CountMe` (must match your Xcode project)
   - **App nickname**: `CountMe` (optional)
   - **App Store ID**: Leave blank for now
3. Click **Register app**

### 2.3 Download Configuration File

1. Download the `GoogleService-Info.plist` file
2. **IMPORTANT**: Replace the placeholder file at `CountMe/GoogleService-Info.plist` with your downloaded file
3. In Xcode, verify the file is added to the CountMe target:
   - Select `GoogleService-Info.plist` in Project Navigator
   - In File Inspector (right panel), ensure **Target Membership** includes **CountMe**

### 2.4 Enable Authentication

1. In Firebase Console, go to **Build** → **Authentication**
2. Click **Get started**
3. Click on **Sign-in method** tab
4. Enable **Email/Password** provider:
   - Click on **Email/Password**
   - Toggle **Enable** to ON
   - Click **Save**

### 2.5 Create Firestore Database

1. In Firebase Console, go to **Build** → **Firestore Database**
2. Click **Create database**
3. Select **Start in test mode** (we'll add security rules later)
4. Choose a Cloud Firestore location (select closest to your users)
5. Click **Enable**

## Step 3: Verify Setup

### 3.1 Build the Project

```bash
# From the project root directory
xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Or in Xcode:
- Press `Cmd + B` to build
- Verify there are no build errors

### 3.2 Check Firebase Initialization

The app is configured to initialize Firebase on startup. Check the console logs when running the app:

```
✅ Firebase initialized successfully
✅ Firestore offline persistence configured
```

## Step 4: Deploy Firestore Security Rules (Later)

Security rules will be deployed in a later task. For now, test mode allows all reads/writes, which is fine for development.

## Troubleshooting

### Build Errors

**Error**: `No such module 'FirebaseAuth'` or `No such module 'FirebaseFirestore'`

**Solution**: 
1. Clean build folder: `Product` → `Clean Build Folder` (Shift + Cmd + K)
2. Close and reopen Xcode
3. Verify packages are added in Project Settings → Package Dependencies

**Error**: `GoogleService-Info.plist not found`

**Solution**:
1. Verify the file exists at `CountMe/GoogleService-Info.plist`
2. In Xcode, check Target Membership includes CountMe
3. Rebuild the project

### Runtime Errors

**Error**: `Firebase configuration failed`

**Solution**:
1. Verify `GoogleService-Info.plist` contains valid Firebase configuration (not placeholder values)
2. Ensure the bundle ID in the plist matches your Xcode project: `Halu.CountMe`
3. Restart the app

**Error**: `Firestore offline persistence configuration failed`

**Solution**:
1. This is usually a warning, not a critical error
2. Verify you have internet connectivity for initial Firestore setup
3. Check Firebase Console to ensure Firestore is enabled

## Next Steps

After completing this setup:

1. ✅ Firebase SDK is installed
2. ✅ Firebase is initialized in the app
3. ✅ Firestore offline persistence is configured
4. ✅ Authentication provider is enabled

You can now proceed to implement:
- Task 2: Core authentication service (FirebaseAuthService)
- Task 3: Authentication UI views
- Task 5: Data model updates for sync

## Additional Resources

- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth/ios/start)
- [Cloud Firestore Documentation](https://firebase.google.com/docs/firestore/quickstart)
- [Firestore Offline Persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline)

## Security Notes

- **DO NOT** commit `GoogleService-Info.plist` with real credentials to public repositories
- Add to `.gitignore` if needed: `CountMe/GoogleService-Info.plist`
- Use Firebase App Check in production to prevent abuse
- Deploy proper Firestore security rules before production release
