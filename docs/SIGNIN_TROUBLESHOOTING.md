# Sign-In Troubleshooting Guide

## Issue: Sign-In Hangs or Takes Long Time

### Possible Causes & Solutions

### 1. **Network Connectivity** (Most Common)
Firebase Authentication requires internet access to work.

**Check:**
- Is your Mac connected to the internet?
- Can the simulator access the network?

**Test:**
```bash
# Open Safari in simulator and try loading google.com
```

**Solution:**
- Ensure your Mac has internet connection
- Restart the simulator if needed
- Check macOS firewall settings aren't blocking the simulator

### 2. **Firebase Configuration**
The app needs to connect to Firebase servers.

**Check Console Output:**
```bash
xcrun simctl spawn "iPhone 17" log show --predicate 'process == "CountMe"' --last 30s | grep -i firebase
```

**Look for:**
- ✅ "Firebase initialized successfully"
- ✅ "User signed in successfully"
- ❌ Network errors
- ❌ Authentication errors

### 3. **Email/Password Sign-In**
This method requires:
- Valid Firebase project
- Email/Password provider enabled in Firebase Console
- Network connectivity

**To Test:**
1. Try creating a new account first (Sign Up)
2. Use a simple email like `test@test.com`
3. Use a password with 8+ characters

### 4. **Apple Sign-In**
Should work immediately in simulator.

**To Test:**
1. Tap "Sign in with Apple" button
2. iOS will show Apple ID prompt
3. Use any Apple ID (or create test account)
4. Should complete quickly

**If it hangs:**
- Make sure "Sign in with Apple" capability is added in Xcode
- Check Xcode → Signing & Capabilities → Sign in with Apple

### 5. **Google Sign-In**
Currently shows error message until package is added.

**Status:** Needs GoogleSignIn package
**Error:** "Google Sign-In not yet configured"

**To Enable:**
1. Add GoogleSignIn package in Xcode
2. Uncomment code in FirebaseAuthService.swift
3. See `GOOGLE_SIGNIN_QUICK_SETUP.md`

## Quick Diagnostic Steps

### Step 1: Check App Launch
```bash
xcrun simctl launch --console "iPhone 17" Halu.CountMe 2>&1 | grep -E "Firebase|error"
```

**Expected output:**
```
✅ Firebase initialized successfully
✅ Firestore offline persistence configured
```

### Step 2: Monitor Sign-In Attempt
While attempting sign-in, run:
```bash
xcrun simctl spawn "iPhone 17" log stream --predicate 'process == "CountMe"' --level debug
```

**Look for:**
- "User signed in successfully" = ✅ Working
- Network errors = ❌ Connectivity issue
- Authentication errors = ❌ Firebase config issue

### Step 3: Test Apple Sign-In First
Apple Sign-In is the most reliable for testing:
1. Launch app
2. Tap "Sign in with Apple"
3. Should show Apple ID prompt immediately
4. Complete sign-in
5. Should transition to main app

## Common Error Messages

### "Could not create ModelContainer"
**Cause:** Database migration issue
**Solution:** Already fixed with automatic recovery
**Status:** ✅ Resolved

### "Network unavailable"
**Cause:** No internet connection
**Solution:** Check Mac internet connection

### "Invalid email or password"
**Cause:** Wrong credentials or account doesn't exist
**Solution:** Try creating new account first

### "Google Sign-In not yet configured"
**Cause:** GoogleSignIn package not added
**Solution:** Follow `GOOGLE_SIGNIN_QUICK_SETUP.md`

## Testing Recommendations

### Best Testing Order:
1. **Apple Sign-In** (Works now, no setup needed)
2. **Email/Password** (Works now, needs internet)
3. **Google Sign-In** (Needs package setup)

### Create Test Account:
```
Email: test@countme.app
Password: TestPass123
```

## Debug Mode

To see detailed logs while testing:

```bash
# Terminal 1: Launch app
xcrun simctl launch "iPhone 17" Halu.CountMe

# Terminal 2: Watch logs
xcrun simctl spawn "iPhone 17" log stream --predicate 'process == "CountMe"' --style compact
```

## Still Having Issues?

### Check Firebase Console:
1. Go to https://console.firebase.google.com
2. Select CountMe project
3. Go to Authentication → Users
4. Check if users are being created
5. Go to Authentication → Sign-in method
6. Verify Email/Password and Apple are enabled

### Verify GoogleService-Info.plist:
```bash
cat CountMe/GoogleService-Info.plist | grep -E "PROJECT_ID|CLIENT_ID"
```

**Expected:**
- PROJECT_ID: countme-c6b31
- CLIENT_ID: (should have value)

### Reset Everything:
```bash
# Uninstall app
xcrun simctl uninstall "iPhone 17" Halu.CountMe

# Clean build
xcodebuild -project CountMe.xcodeproj -scheme CountMe clean

# Rebuild and install
xcodebuild -project CountMe.xcodeproj -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
xcrun simctl install "iPhone 17" /path/to/CountMe.app
```

## Expected Behavior

### Successful Sign-In Flow:
1. User enters email/password
2. Taps "Sign In" button
3. Button shows loading spinner
4. **2-5 seconds** - Firebase authenticates
5. View transitions to main app
6. Data syncs from Firestore

### If Taking Longer:
- **5-10 seconds** = Slow network, but normal
- **10-30 seconds** = Network issues, check connection
- **30+ seconds** = Likely hung, check console for errors

## Current Status

✅ **Apple Sign-In** - Ready to use
✅ **Email/Password** - Ready to use (needs internet)
⏳ **Google Sign-In** - Needs package (10 min setup)

✅ **Database** - Auto-recovery working
✅ **Firebase Config** - Properly initialized
✅ **UI** - All buttons visible and functional
