#!/bin/bash

# ============================================================================
# Firestore Security Rules Deployment Script
# ============================================================================
#
# This script deploys Firestore security rules to your Firebase project.
#
# Prerequisites:
# 1. Firebase CLI installed (npm install -g firebase-tools)
# 2. Authenticated with Firebase (firebase login)
# 3. Firebase project initialized (firebase init firestore)
#
# Usage:
#   ./deploy-firestore-rules.sh
#
# ============================================================================

set -e  # Exit on error

echo "🔐 Deploying Firestore Security Rules..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Error: Firebase CLI is not installed"
    echo ""
    echo "Install it with:"
    echo "  npm install -g firebase-tools"
    echo ""
    exit 1
fi

# Check if firestore.rules exists
if [ ! -f "firestore.rules" ]; then
    echo "❌ Error: firestore.rules file not found"
    echo ""
    echo "Make sure you're running this script from the project root directory."
    echo ""
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Error: Not authenticated with Firebase"
    echo ""
    echo "Login with:"
    echo "  firebase login"
    echo ""
    exit 1
fi

# Display current Firebase project
echo "📋 Current Firebase project:"
firebase use
echo ""

# Confirm deployment
read -p "Deploy security rules to this project? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

# Deploy rules
echo ""
echo "🚀 Deploying rules..."
firebase deploy --only firestore:rules

echo ""
echo "✅ Firestore security rules deployed successfully!"
echo ""
echo "You can verify the rules in the Firebase Console:"
echo "https://console.firebase.google.com/project/_/firestore/rules"
echo ""
