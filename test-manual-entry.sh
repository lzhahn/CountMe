#!/bin/bash

echo "🧹 Resetting simulator..."
xcrun simctl shutdown "iPhone 17 Pro" 2>/dev/null
xcrun simctl erase "iPhone 17 Pro"
xcrun simctl boot "iPhone 17 Pro"

echo "🔨 Building app..."
xcodebuild -project CountMe.xcodeproj -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ./build clean build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded"
    
    echo "📱 Installing app..."
    xcrun simctl install "iPhone 17 Pro" ./build/Build/Products/Debug-iphonesimulator/CountMe.app
    
    echo "🚀 Launching app..."
    xcrun simctl launch --console "iPhone 17 Pro" com.lucashahn.CountMe
    
    echo ""
    echo "✅ App launched! Now:"
    echo "1. Add a manual food entry"
    echo "2. Check if it appears in the list"
    echo "3. Watch the console output above for debug logs"
else
    echo "❌ Build failed"
    exit 1
fi
