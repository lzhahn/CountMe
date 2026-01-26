# Error Handling Guide

## Overview

This document describes the comprehensive error handling patterns implemented across the AI-Powered Recipe Tracking feature. All error scenarios are handled with user-friendly messages, actionable feedback, and appropriate visual indicators.

## Error Handling Components

### 1. Toast Notifications (`ToastView.swift`)

Reusable toast notification system for displaying temporary success, error, info, and warning messages.

**Styles:**
- `.success` - Green checkmark for successful operations
- `.error` - Red X for error conditions
- `.info` - Blue info icon for informational messages
- `.warning` - Orange triangle for warnings

**Usage:**
```swift
.toast(
    isPresented: $showingToast,
    message: "Custom meal saved successfully!",
    style: .success,
    duration: 2.5
)
```

**Features:**
- Auto-dismisses after specified duration (default 2.5 seconds)
- Smooth slide-in animation from top
- Shadow and rounded corners for visual prominence
- Consistent styling across all views

### 2. AI Parsing Error Handling (`RecipeInputView.swift`)

**Error Scenarios:**
- Network failures (timeout, no connection)
- Invalid AI responses
- Parsing failures
- Insufficient data

**UI Components:**
- Error display with red background and warning icon
- Retry button for network errors
- Manual entry fallback button
- Network offline warning banner
- Character count validation with color coding

**User Experience:**
- Clear error messages explaining what went wrong
- Actionable buttons (Retry, Enter Manually)
- Disabled AI parsing when offline with tooltip
- Real-time validation feedback

### 3. Validation Error Displays (`IngredientReviewView.swift`)

**Validation Rules:**
- Ingredient name: Required, non-empty
- Quantity: Required, must be > 0
- Calories: Required, must be > 0
- Macros (optional): Must be non-negative if provided

**UI Components:**
- Inline error messages below each field
- Red border highlighting for invalid fields
- Field-specific error text (e.g., "Must be > 0", "Cannot be negative")
- Blue border on focused fields
- Real-time validation as user types

**Features:**
- Validation errors appear immediately on blur
- Save button disabled until all fields valid
- Clear visual distinction between valid/invalid states
- Helpful error messages guide user to fix issues

### 4. Confirmation Alerts for Destructive Actions

**Delete Meal Confirmation:**
- Alert dialog with meal name
- Clear warning: "This action cannot be undone"
- Cancel and Delete buttons (Delete is destructive role)
- Implemented in both `CustomMealDetailView` and `CustomMealsLibraryView`

**Features:**
- Prevents accidental deletions
- Shows meal name in confirmation message
- Destructive button styled in red
- Cancel button as default action

### 5. Success Toast Notifications

**Operations with Success Toasts:**
- Custom meal saved
- Custom meal added to daily log
- Custom meal deleted

**Features:**
- Green checkmark icon
- Descriptive success message
- Auto-dismiss after 2.5 seconds
- Smooth animation
- View dismisses after toast (where appropriate)

### 6. Network Status Indicators

**Offline Mode Handling:**
- Blue informational banner in `CustomMealsLibraryView`
- Orange warning banner in `RecipeInputView`
- Disabled AI parsing button with tooltip
- Clear messaging: "Custom meals are available offline"

**Features:**
- Real-time network monitoring with `NetworkMonitor`
- Automatic UI updates when connectivity changes
- Informational (not blocking) for offline-capable features
- Warning (blocking) for online-only features (AI parsing)

### 7. Loading States

**Loading Indicators:**
- Spinner in buttons during async operations
- Full-screen loading view in library
- Button text changes (e.g., "Parsing Recipe..." vs "Parse Recipe")
- Disabled state for all interactive elements during loading

**Features:**
- Prevents duplicate submissions
- Clear visual feedback that operation is in progress
- Consistent loading patterns across all views

### 8. Error Recovery Patterns

**Retry Logic:**
- Retry buttons for network errors
- Exponential backoff in `AIRecipeParser` (max 3 attempts)
- Clear retry button in error displays
- Automatic retry on connectivity restoration

**Fallback Options:**
- Manual ingredient entry when AI parsing fails
- Search and filter still work when network is down
- Saved meals accessible offline
- Graceful degradation of features

## Error Message Guidelines

### User-Friendly Messages

**Good Examples:**
- ✅ "Unable to parse recipe. Please check your connection or enter ingredients manually."
- ✅ "Serving size must be greater than zero."
- ✅ "No meals match 'chicken'. Try a different search term."

**Bad Examples:**
- ❌ "Error: NSURLErrorDomain -1001"
- ❌ "Validation failed"
- ❌ "Invalid input"

### Message Structure

1. **What went wrong** - Brief description of the error
2. **Why it happened** - Context (if helpful)
3. **What to do next** - Actionable guidance

**Example:**
"Unable to save custom meal. Please check your internet connection and try again."

## Testing Error Scenarios

### Manual Testing Checklist

- [ ] AI parsing with no internet connection
- [ ] AI parsing with invalid recipe description
- [ ] Saving meal with empty name
- [ ] Saving meal with invalid ingredient data
- [ ] Deleting meal (confirm and cancel)
- [ ] Adding meal to log with invalid serving size
- [ ] Network disconnection during operation
- [ ] Rapid successive operations (loading states)

### Edge Cases

- [ ] Very long error messages (text wrapping)
- [ ] Multiple errors simultaneously
- [ ] Error during delete operation
- [ ] Error during save operation
- [ ] Offline mode transitions

## Accessibility Considerations

- Error messages use semantic colors (red for errors, orange for warnings)
- Icons supplement text (not replace it)
- Error text has sufficient contrast ratio
- Focus management for validation errors
- VoiceOver announcements for toast notifications

## Future Enhancements

- [ ] Error logging for debugging
- [ ] Analytics for error frequency
- [ ] Offline queue for failed operations
- [ ] More granular error types
- [ ] Undo functionality for deletions
- [ ] Batch operation error handling

## Related Files

- `CountMe/Views/ToastView.swift` - Toast notification component
- `CountMe/Views/RecipeInputView.swift` - AI parsing error handling
- `CountMe/Views/IngredientReviewView.swift` - Validation error displays
- `CountMe/Views/CustomMealDetailView.swift` - Delete confirmation, success toasts
- `CountMe/Views/CustomMealsLibraryView.swift` - Library error handling, delete confirmation
- `CountMe/Services/AIRecipeParser.swift` - AI error types and retry logic
- `CountMe/Services/CustomMealManager.swift` - Business logic error handling
- `CountMe/Utilities/NetworkMonitor.swift` - Network status monitoring

## Requirements Validation

This implementation validates the following requirements:

- **Requirement 7.3**: AI service error handling with user-friendly messages
- **Requirement 7.4**: Partial data handling and error recovery
- **Requirement 10.4**: Field-specific validation error messages
- **Requirement 11.3**: Offline mode detection and UI adaptation
- **Requirement 2.3**: Delete confirmation for destructive actions

All error messages are user-friendly, actionable, and provide clear guidance on how to proceed.
