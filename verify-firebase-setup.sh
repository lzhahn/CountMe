#!/bin/bash

# Firebase Setup Verification Script
# This script checks if Firebase is properly configured in the CountMe project

set -e

echo "🔍 Verifying Firebase Setup for CountMe..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: GoogleService-Info.plist exists
echo "1️⃣  Checking GoogleService-Info.plist..."
if [ -f "CountMe/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ GoogleService-Info.plist found${NC}"
    
    # Check if it's still the placeholder
    if grep -q "YOUR_API_KEY_HERE" "CountMe/GoogleService-Info.plist"; then
        echo -e "${YELLOW}⚠️  WARNING: GoogleService-Info.plist appears to be a placeholder${NC}"
        echo "   Please replace it with your actual Firebase configuration file"
        echo "   See FIREBASE_SETUP.md for instructions"
    else
        echo -e "${GREEN}✅ GoogleService-Info.plist appears to be configured${NC}"
    fi
else
    echo -e "${RED}❌ GoogleService-Info.plist not found${NC}"
    echo "   Expected location: CountMe/GoogleService-Info.plist"
    exit 1
fi
echo ""

# Check 2: FirebaseConfig.swift exists
echo "2️⃣  Checking FirebaseConfig.swift..."
if [ -f "CountMe/Services/FirebaseConfig.swift" ]; then
    echo -e "${GREEN}✅ FirebaseConfig.swift found${NC}"
else
    echo -e "${RED}❌ FirebaseConfig.swift not found${NC}"
    echo "   Expected location: CountMe/Services/FirebaseConfig.swift"
    exit 1
fi
echo ""

# Check 3: CountMeApp.swift has Firebase initialization
echo "3️⃣  Checking Firebase initialization in CountMeApp.swift..."
if grep -q "FirebaseConfig.shared.configure()" "CountMe/CountMeApp.swift"; then
    echo -e "${GREEN}✅ Firebase initialization found in CountMeApp.swift${NC}"
else
    echo -e "${RED}❌ Firebase initialization not found in CountMeApp.swift${NC}"
    echo "   Expected: FirebaseConfig.shared.configure() in init()"
    exit 1
fi
echo ""

# Check 4: Xcode project exists
echo "4️⃣  Checking Xcode project..."
if [ -f "CountMe.xcodeproj/project.pbxproj" ]; then
    echo -e "${GREEN}✅ Xcode project found${NC}"
else
    echo -e "${RED}❌ Xcode project not found${NC}"
    exit 1
fi
echo ""

# Check 5: Swift Package Manager dependencies (manual check required)
echo "5️⃣  Checking Swift Package Manager dependencies..."
echo -e "${YELLOW}⚠️  Manual verification required:${NC}"
echo "   Open CountMe.xcodeproj in Xcode and verify:"
echo "   - FirebaseAuth package is added"
echo "   - FirebaseFirestore package is added"
echo "   Path: Project Settings → Package Dependencies"
echo ""

# Check 6: Build the project (optional, can be slow)
echo "6️⃣  Build verification (optional)..."
read -p "Do you want to build the project to verify compilation? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Building project..."
    if xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' build > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Project builds successfully${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        echo "   Run 'xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' build' for details"
        exit 1
    fi
else
    echo "Skipping build verification"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Setup Verification Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Configuration files are in place"
echo "✅ Firebase initialization code is present"
echo ""
echo "📝 Next Steps:"
echo "   1. Open CountMe.xcodeproj in Xcode"
echo "   2. Add Firebase SDK packages (see FIREBASE_SETUP.md)"
echo "   3. Replace GoogleService-Info.plist with your Firebase config"
echo "   4. Build and run the app"
echo ""
echo "📚 For detailed instructions, see: FIREBASE_SETUP.md"
echo ""
