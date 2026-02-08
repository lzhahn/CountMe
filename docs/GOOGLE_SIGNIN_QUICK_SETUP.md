# Google Sign-In Quick Setup Guide

## ✅ What's Already Done
- ✅ New GoogleService-Info.plist with Google Sign-In enabled
- ✅ Google Sign-In code implemented in FirebaseAuthService
- ✅ Google Sign-In button added to UI
- ✅ REVERSED_CLIENT_ID extracted: `com.googleusercontent.apps.862836525907-emmkh5u8f66q8a83c18734o0hc39l8cl`

## 🔧 3 Steps to Complete Setup (10 minutes)

### Step 1: Add GoogleSignIn Package (5 min)

1. Open `CountMe.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. Paste this URL: `https://github.com/google/GoogleSignIn-iOS`
4. Select version **7.0.0** or higher
5. Click **Add Package**
6. Select **GoogleSignIn** and **GoogleSignInSwift**
7. Make sure they're added to **CountMe** target
8. Click **Add Package**

### Step 2: Configure Xcode Project (3 min)

#### Add URL Scheme:
1. In Xcode, select **CountMe** project in navigator
2. Select **CountMe** target
3. Go to **Info** tab
4. Expand **URL Types** section
5. Click **+** to add new URL Type
6. Enter these values:
   - **Identifier**: `com.google.gid.reverseClientId`
   - **URL Schemes**: `com.googleusercontent.apps.862836525907-emmkh5u8f66q8a83c18734o0hc39l8cl`

#### Add Sign in with Apple Capability:
1. Go to **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **Sign in with Apple**

### Step 3: Uncomment Google Code (2 min)

Open `CountMe/Services/FirebaseAuthService.swift` and make these changes:

**Line 6** - Change:
```swift
// import GoogleSignIn // Uncomment after adding GoogleSignIn package
```
To:
```swift
import GoogleSignIn
```

**Lines 230-280** - Replace the temporary implementation with the commented code:
- Delete the temporary error implementation (lines 268-273)
- Uncomment the full Google Sign-In implementation (lines 230-267)

## 🎯 That's It!

After these 3 steps:
1. Build the project: `⌘ + B`
2. Run on simulator: `⌘ + R`
3. You'll see both Apple and Google sign-in buttons
4. Both will work seamlessly with Firebase

## 🧪 Testing

### Test Apple Sign-In (Works Now):
- Tap "Sign in with Apple"
- Use test Apple ID
- App signs in and syncs data

### Test Google Sign-In (After Setup):
- Tap "Sign in with Google"
- Select Google account
- App signs in and syncs data

## 📱 What You'll See

**Sign-In Screen:**
```
┌─────────────────────────┐
│   Email: [________]     │
│   Password: [______]    │
│   [Sign In Button]      │
│                         │
│   ──────── OR ────────  │
│                         │
│   [Sign in with Apple]  │ ← Black button
│   [Sign in with Google] │ ← White button
│                         │
│   Don't have account?   │
│   [Create Account]      │
└─────────────────────────┘
```

## 🔒 Security Notes

- All authentication goes through Firebase
- No credentials stored locally
- Tokens validated server-side
- Works with existing Firestore security rules

## ❓ Troubleshooting

**"Module not found: GoogleSignIn"**
→ Add the GoogleSignIn package (Step 1)

**Google Sign-In doesn't open**
→ Check URL scheme is correct (Step 2)

**Apple Sign-In not showing**
→ Add "Sign in with Apple" capability (Step 2)

## 📚 Reference

- GoogleSignIn iOS: https://github.com/google/GoogleSignIn-iOS
- Firebase Auth Docs: https://firebase.google.com/docs/auth/ios/google-signin
- Apple Sign-In: https://developer.apple.com/sign-in-with-apple/

---

**Need help?** Check `SETUP_SOCIAL_SIGNIN.md` for detailed instructions.
