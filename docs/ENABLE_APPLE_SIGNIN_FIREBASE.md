# Enable Apple Sign-In in Firebase Console

## Issue
Apple Sign-In is failing because it needs to be enabled in Firebase Console.

## Quick Fix - Enable Apple Sign-In in Firebase

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com
2. Select your **CountMe** project (countme-c6b31)

### Step 2: Enable Apple Sign-In Provider
1. Click **Authentication** in the left sidebar
2. Click **Sign-in method** tab
3. Find **Apple** in the list of providers
4. Click on **Apple**
5. Click the **Enable** toggle
6. Click **Save**

That's it! No additional configuration needed for Apple Sign-In.

### Step 3: Test Again
1. Restart the app in simulator
2. Click "Sign in with Apple"
3. Enter your Apple ID credentials
4. Should work now!

## Why This Is Needed

Firebase needs to know which authentication providers you want to use. Even though the code is implemented, Firebase won't accept Apple Sign-In tokens unless the provider is enabled in the console.

## Current Firebase Providers Status

Based on your GoogleService-Info.plist, you have:
- ✅ Email/Password - Should be enabled
- ⏳ Apple - **Needs to be enabled**
- ⏳ Google - **Needs to be enabled**

## Enable All Providers

While you're in Firebase Console, enable all three:

### Email/Password (Should already be enabled)
1. Authentication → Sign-in method
2. Email/Password → Enable
3. Save

### Apple (Do this now)
1. Authentication → Sign-in method
2. Apple → Enable
3. Save

### Google (For later)
1. Authentication → Sign-in method
2. Google → Enable
3. Note the Web Client ID
4. Save

## After Enabling

The error you're seeing (Authorization failed -7034) might actually be because Firebase is rejecting the Apple token since the provider isn't enabled.

Once you enable Apple Sign-In in Firebase Console:
- The authentication will work
- Firebase will accept Apple ID tokens
- Users can sign in with Apple successfully

## Test Flow After Enabling

1. **Enable Apple in Firebase Console** (2 minutes)
2. **Restart the app**
3. **Click "Sign in with Apple"**
4. **Enter Apple ID password**
5. **Should sign in successfully!**

## Verification

After enabling, you can verify it worked by:
1. Successfully signing in with Apple
2. Going to Firebase Console → Authentication → Users
3. You should see your user listed with Apple as the provider

## Alternative: Test Email/Password First

If you want to test authentication while setting up Apple:
1. Use email: `test@test.com`
2. Password: `TestPass123`
3. Click "Create Account" first
4. Then sign in

This will verify Firebase authentication is working, then you can add Apple Sign-In.
