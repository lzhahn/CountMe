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

# Check simulator status and boot if needed
echo "📱 Checking simulator status..."
SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -oE '\((Booted|Shutdown)\)' | tr -d '()')

if [[ "$SIMULATOR_STATE" != "Booted" ]]; then
    echo "🔄 Booting simulator..."
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
    echo "⏳ Waiting for simulator to boot..."
    sleep 5
else
    echo "✅ Simulator already running"
fi

# Open Simulator app if not already open
if ! pgrep -x "Simulator" > /dev/null; then
    echo "🖥️  Opening Simulator app..."
    open -a Simulator
    sleep 2
fi

echo ""
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
