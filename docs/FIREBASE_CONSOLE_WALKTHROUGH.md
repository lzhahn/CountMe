# Firebase Console Setup - Visual Walkthrough

This guide walks you through every click on the Firebase website to set up your CountMe app.

## 📍 Starting Point

**URL**: https://console.firebase.google.com/

---

## Part 1: Create Firebase Project (2 minutes)

### Step 1: Initial Screen

When you first visit Firebase Console, you'll see:
- **If you have no projects**: A big "Create a project" button
- **If you have existing projects**: A "+ Add project" button in the top area

**Action**: Click **"Create a project"** or **"Add project"**

---

### Step 2: Project Name

You'll see a form with:
- **Field**: "Enter your project name"
- **Suggestion**: You can use "CountMe" or any name you prefer

**Actions**:
1. Type: `CountMe` (or your preferred name)
2. Notice: Firebase will auto-generate a unique Project ID below (like `countme-a1b2c`)
3. Click: **"Continue"** button at the bottom

---

### Step 3: Google Analytics (Optional)

You'll see:
- **Toggle**: "Enable Google Analytics for this project"
- **Recommendation**: You can disable this for now (we don't need it)

**Actions**:
1. Toggle **OFF** (gray) - "Enable Google Analytics for this project"
2. Click: **"Create project"** button

**Wait**: Firebase will create your project (takes 10-30 seconds)
- You'll see a progress indicator
- When done, you'll see "Your new project is ready"

3. Click: **"Continue"** button

---

## Part 2: Add iOS App to Project (3 minutes)

### Step 4: Project Dashboard

You're now on your project's main dashboard. You'll see:
- Project name at the top
- Three large icons in the center:
  - 📱 iOS icon (Apple logo)
  - 🤖 Android icon
  - 🌐 Web icon

**Action**: Click the **iOS icon** (Apple logo)

---

### Step 5: Register iOS App

You'll see a form titled "Add Firebase to your Apple app"

**Field 1: iOS bundle ID** (REQUIRED)
- This MUST match your Xcode project exactly
- **Enter**: `Halu.CountMe`
- ⚠️ **Important**: This is case-sensitive and must be exact!

**Field 2: App nickname** (Optional)
- Friendly name for your reference
- **Enter**: `CountMe` (or leave blank)

**Field 3: App Store ID** (Optional)
- Only needed if app is already published
- **Leave blank** for now

**Action**: Click **"Register app"** button

---

### Step 6: Download Config File

You'll see:
- **Step 2 of 4**: "Download config file"
- A blue **"Download GoogleService-Info.plist"** button
- Instructions about adding the file to Xcode

**Actions**:
1. Click: **"Download GoogleService-Info.plist"** button
2. Save the file (it will download to your Downloads folder)
3. **Important**: Remember where you saved it!
4. Click: **"Next"** button (you can skip the Xcode instructions for now)

---

### Step 7: Add Firebase SDK (Skip)

You'll see:
- **Step 3 of 4**: "Add Firebase SDK"
- Code snippets for CocoaPods or Swift Package Manager

**Action**: Click **"Next"** button (we'll do this in Xcode separately)

---

### Step 8: Add Initialization Code (Skip)

You'll see:
- **Step 4 of 4**: "Add initialization code"
- Swift code examples

**Action**: Click **"Continue to console"** button (we already added this code!)

---

## Part 3: Enable Email/Password Authentication (1 minute)

### Step 9: Navigate to Authentication

You're back on the project dashboard. On the left sidebar, you'll see:
- 🏠 Project Overview
- 🔨 **Build** section (expand if collapsed)
  - Authentication
  - Firestore Database
  - Storage
  - etc.

**Action**: Click **"Authentication"** in the left sidebar

---

### Step 10: Get Started with Authentication

You'll see:
- A welcome screen for Authentication
- A big **"Get started"** button

**Action**: Click **"Get started"** button

---

### Step 11: Sign-in Methods Tab

You'll see tabs at the top:
- **Users** tab
- **Sign-in method** tab ← (should be selected)
- **Templates** tab
- **Usage** tab

Below, you'll see a list of sign-in providers:
- Email/Password (Disabled)
- Phone (Disabled)
- Google (Disabled)
- etc.

**Action**: Click on **"Email/Password"** row (the entire row is clickable)

---

### Step 12: Enable Email/Password

A modal/panel will appear titled "Email/Password"

You'll see:
- **Toggle 1**: "Email/Password" (this is what we want)
- **Toggle 2**: "Email link (passwordless sign-in)" (we don't need this)

**Actions**:
1. Toggle **ON** (blue) - "Email/Password" (the first toggle)
2. Leave the second toggle OFF
3. Click: **"Save"** button at the bottom

**Result**: You'll see "Email/Password" now shows "Enabled" in the list

---

## Part 4: Create Firestore Database (2 minutes)

### Step 13: Navigate to Firestore

On the left sidebar:
- 🔨 **Build** section
  - Authentication ✓ (we just did this)
  - **Firestore Database** ← Click this

**Action**: Click **"Firestore Database"** in the left sidebar

---

### Step 14: Create Database

You'll see:
- A welcome screen for Cloud Firestore
- A **"Create database"** button

**Action**: Click **"Create database"** button

---

### Step 15: Security Rules

A modal will appear: "Create database"

**Step 1: Secure rules for Cloud Firestore**

You'll see two options:
- 🔒 **Start in production mode** (Deny all reads/writes by default)
- 🧪 **Start in test mode** (Allow all reads/writes for 30 days)

**Action**: 
1. Select: **"Start in test mode"** (second option)
2. Read the warning (it's okay for development)
3. Click: **"Next"** button

> **Note**: We'll add proper security rules in a later task. Test mode is fine for development.

---

### Step 16: Cloud Firestore Location

**Step 2: Set Cloud Firestore location**

You'll see:
- A dropdown menu to select a location
- Options like:
  - `us-central1 (Iowa)`
  - `us-east1 (South Carolina)`
  - `europe-west1 (Belgium)`
  - etc.

**Actions**:
1. Select a location closest to you or your users
   - **US users**: `us-central1` or `us-east1`
   - **Europe users**: `europe-west1`
   - **Asia users**: `asia-southeast1`
2. Click: **"Enable"** button

**Wait**: Firestore is being created (takes 30-60 seconds)
- You'll see a progress indicator
- When done, you'll see the Firestore console with an empty database

---

## ✅ You're Done with Firebase Console!

You should now see:
- **Firestore Database**: Empty database with "Start collection" button
- **Left sidebar**: 
  - ✓ Authentication (enabled)
  - ✓ Firestore Database (created)

---

## 🎯 Next Steps: Back to Your Computer

### 1. Move the Downloaded File

Open Terminal and run:

```bash
# Navigate to your project
cd /path/to/CountMe

# Move the downloaded file (adjust path to your Downloads folder)
mv ~/Downloads/GoogleService-Info.plist CountMe/GoogleService-Info.plist
```

Or use Finder:
1. Find `GoogleService-Info.plist` in your Downloads folder
2. Drag it to your project's `CountMe` folder
3. Replace the existing placeholder file

### 2. Verify the File

```bash
# Check that it's not the placeholder
grep -q "YOUR_API_KEY_HERE" CountMe/GoogleService-Info.plist && echo "⚠️ Still placeholder" || echo "✅ Real config"
```

You should see: `✅ Real config`

### 3. Add to Xcode

1. Open `CountMe.xcodeproj` in Xcode
2. In Project Navigator, find `GoogleService-Info.plist`
3. Select it and check the File Inspector (right panel)
4. Ensure **Target Membership** includes **CountMe** (checkbox should be checked)

---

## 📸 What You Should See in Firebase Console

After completing all steps, your Firebase Console should show:

**Project Overview** (home screen):
- Project name: CountMe
- 1 app registered (iOS)
- Authentication: Active
- Firestore: Active

**Authentication → Users**:
- Empty list (no users yet - that's normal!)

**Firestore Database → Data**:
- Empty database (no collections yet - that's normal!)

---

## 🆘 Troubleshooting

### "I can't find the iOS icon"

- Make sure you're on the Project Overview page
- Look for the "Get started by adding Firebase to your app" section
- You should see three large icons: iOS (Apple), Android, Web

### "Bundle ID doesn't match"

- The bundle ID MUST be exactly: `Halu.CountMe`
- If you entered it wrong, you can add another iOS app with the correct bundle ID
- Or delete the app and re-add it (Project Settings → General → Your apps)

### "Download button doesn't work"

- Try a different browser (Chrome or Safari work best)
- Check your browser's download settings
- The file is small (~1-2 KB) and should download instantly

### "Can't enable Email/Password"

- Make sure you clicked "Get started" first in Authentication
- Try refreshing the page
- Make sure you're clicking the toggle, not just the row

### "Firestore location is grayed out"

- You can only set this once per project
- If you already created Firestore before, the location is already set
- This is fine - just note what location is shown

---

## 🎉 Success Checklist

Before moving on, verify:

- ✅ Firebase project created
- ✅ iOS app registered with bundle ID `Halu.CountMe`
- ✅ `GoogleService-Info.plist` downloaded
- ✅ Email/Password authentication enabled
- ✅ Firestore database created in test mode
- ✅ File moved to `CountMe/GoogleService-Info.plist`

---

## 📚 What's Next?

Now that Firebase Console is configured, you need to:

1. **Add Firebase SDK in Xcode** (see `FIREBASE_SETUP.md` Step 1)
2. **Verify setup** by running `./verify-firebase-setup.sh`
3. **Build and run** the app to see Firebase initialize

Then you're ready for **Task 2**: Implementing the authentication service!

---

**Need more help?** Check the full guide in `FIREBASE_SETUP.md` or run the verification script.
