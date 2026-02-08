#!/bin/bash

# Setup Google Sign-In for CountMe
# This script helps configure the URL scheme needed for Google Sign-In

echo "🔧 Google Sign-In Setup for CountMe"
echo "===================================="
echo ""

# Extract REVERSED_CLIENT_ID from GoogleService-Info.plist
REVERSED_CLIENT_ID=$(grep -A 1 "REVERSED_CLIENT_ID" CountMe/GoogleService-Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [ -z "$REVERSED_CLIENT_ID" ]; then
    echo "❌ Error: Could not find REVERSED_CLIENT_ID in GoogleService-Info.plist"
    exit 1
fi

echo "✅ Found REVERSED_CLIENT_ID: $REVERSED_CLIENT_ID"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Open CountMe.xcodeproj in Xcode"
echo ""
echo "2. Select the CountMe project in the navigator"
echo ""
echo "3. Select the CountMe target"
echo ""
echo "4. Go to the 'Info' tab"
echo ""
echo "5. Expand 'URL Types' section"
echo ""
echo "6. Click '+' to add a new URL Type"
echo ""
echo "7. Set the following values:"
echo "   - Identifier: com.google.gid.reverseClientId"
echo "   - URL Schemes: $REVERSED_CLIENT_ID"
echo ""
echo "8. In Xcode, go to 'Signing & Capabilities' tab"
echo ""
echo "9. Click '+ Capability' and add 'Sign in with Apple'"
echo ""
echo "10. Build and run the app!"
echo ""
echo "📝 The URL scheme has been copied to your clipboard (if pbcopy is available)"
echo "$REVERSED_CLIENT_ID" | pbcopy 2>/dev/null && echo "✅ Copied to clipboard!" || echo "⚠️  Copy manually: $REVERSED_CLIENT_ID"
echo ""
echo "🎯 After completing these steps, uncomment the Google Sign-In code in:"
echo "   - CountMe/Services/FirebaseAuthService.swift (line 6 and lines 230-280)"
echo ""
