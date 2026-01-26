#!/bin/bash

# CountMe Build and Run Script
# This script builds the app and launches it in the iOS Simulator

set -e  # Exit on error

# Configuration
SIMULATOR_ID="E8897BA3-19A7-4856-8889-D5AFD3EE8679"  # iPhone 17
PROJECT="CountMe.xcodeproj"
SCHEME="CountMe"
CONFIGURATION="Debug"
BUNDLE_ID="Halu.CountMe"
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/CountMe-cclkaybuifejwjgoaltnbcxndjag/Build/Products/Debug-iphonesimulator/CountMe.app"

echo "🔨 Building CountMe..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    build

echo ""
echo "📱 Installing app on simulator..."
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"

echo ""
echo "🚀 Launching CountMe..."
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo ""
echo "✅ CountMe is now running!"
echo ""
echo "To view logs, run:"
echo "xcrun simctl spawn $SIMULATOR_ID log stream --predicate 'processImagePath contains \"CountMe\"' --level debug"
