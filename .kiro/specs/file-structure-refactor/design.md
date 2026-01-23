# Design Document: File Structure Refactor

## Overview

This design describes the refactoring of the CountMe iOS application from a flat file structure to a feature-based, type-organized architecture. The refactoring will move Swift source files into Views/, Services/, and Utilities/ folders while maintaining full functionality, preserving git history, and ensuring the Xcode project remains buildable at each step.

The refactoring addresses technical debt accumulated from rapid initial development and aligns the codebase with the documented architecture patterns in project-foundation.md. This will improve code discoverability, maintainability, and onboarding for new developers.

## Architecture

### Current Structure

```
CountMe/
├── Assets.xcassets/
├── Models/                    # ✓ Already organized
│   ├── CustomMeal.swift
│   ├── DailyLog.swift
│   ├── FoodItem.swift
│   ├── FoodItemSource.swift
│   ├── Ingredient.swift
│   └── NutritionSearchResult.swift
├── CalorieTracker.swift       # Service - needs move
├── Config.swift               # Utility - needs move
├── ContentView.swift          # View - needs move
├── CountMeApp.swift           # App entry - stays in root
├── DataStore.swift            # Service - needs move
├── FoodItemRow.swift          # View - needs move
├── FoodSearchView.swift       # View - needs move
├── GoalSettingView.swift      # View - needs move
├── HistoricalView.swift       # View - needs move
├── Item.swift                 # Legacy - evaluate for removal
├── MainCalorieView.swift      # View - needs move
├── ManualEntryView.swift      # View - needs move
├── NutritionAPIClient.swift   # Service - needs move
├── OAuth1SignatureGenerator.swift  # Service - needs move
├── SearchResultRow.swift      # View - needs move
├── Secrets.swift              # Utility - needs move
└── ServingAdjustmentView.swift # View - needs move

CountMeTests/
├── CoreUIFlowsTests.swift           # View tests - needs move
├── CountMeTests.swift               # Keep in root
├── CrashRecoveryTests.swift         # Integration - keep in root
├── FoodItemMacroTests.swift         # Model tests - needs move
├── NutritionAPIClientTests.swift    # Service tests - needs move
└── OAuth1SignatureGeneratorTests.swift  # Service tests - needs move
```

### Target Structure

```
CountMe/
├── Assets.xcassets/
├── Models/                    # ✓ No changes needed
│   ├── CustomMeal.swift
│   ├── DailyLog.swift
│   ├── FoodItem.swift
│   ├── FoodItemSource.swift
│   ├── Ingredient.swift
│   └── NutritionSearchResult.swift
├── Views/                     # ✓ New folder
│   ├── ContentView.swift
│   ├── FoodItemRow.swift
│   ├── FoodSearchView.swift
│   ├── GoalSettingView.swift
│   ├── HistoricalView.swift
│   ├── MainCalorieView.swift
│   ├── ManualEntryView.swift
│   ├── SearchResultRow.swift
│   └── ServingAdjustmentView.swift
├── Services/                  # ✓ New folder
│   ├── CalorieTracker.swift
│   ├── DataStore.swift
│   ├── NutritionAPIClient.swift
│   └── OAuth1SignatureGenerator.swift
├── Utilities/                 # ✓ New folder
│   ├── Config.swift
│   └── Secrets.swift
├── CountMeApp.swift           # App entry - stays in root
└── Item.swift                 # Legacy - evaluate for removal

CountMeTests/
├── Models/                    # ✓ New folder
│   └── FoodItemMacroTests.swift
├── Services/                  # ✓ New folder
│   ├── NutritionAPIClientTests.swift
│   └── OAuth1SignatureGeneratorTests.swift
├── Views/                     # ✓ New folder
│   └── CoreUIFlowsTests.swift
├── CountMeTests.swift         # Keep in root
└── CrashRecoveryTests.swift   # Integration - keep in root
```

### Refactoring Strategy

**Incremental Approach**: Move files in logical groups to maintain buildability at each step:

1. **Phase 1: Create Folders** - Create all target directories in both source and test folders
2. **Phase 2: Move Views** - Move all 9 view files and update Xcode project
3. **Phase 3: Move Services** - Move all 4 service files and update Xcode project
4. **Phase 4: Move Utilities** - Move all 2 utility files and update Xcode project
5. **Phase 5: Move Tests** - Reorganize test files to mirror source structure
6. **Phase 6: Verify** - Build, run tests, verify functionality

**Git Strategy**: Use `git mv` for each file to preserve history, commit after each phase.

**Xcode Project Updates**: After each file move, update project.pbxproj to reflect new paths.

## Components and Interfaces

### File Classification

**Views (9 files)**:
- `ContentView.swift` - Main navigation container
- `MainCalorieView.swift` - Primary calorie tracking interface
- `FoodSearchView.swift` - API search interface
- `ManualEntryView.swift` - Manual food entry form
- `ServingAdjustmentView.swift` - Serving size adjustment UI
- `FoodItemRow.swift` - Individual food item display component
- `SearchResultRow.swift` - Search result display component
- `GoalSettingView.swift` - Daily calorie goal configuration
- `HistoricalView.swift` - Historical data viewing interface

**Services (4 files)**:
- `DataStore.swift` - SwiftData persistence layer (actor-based)
- `NutritionAPIClient.swift` - FatSecret API integration
- `OAuth1SignatureGenerator.swift` - API authentication
- `CalorieTracker.swift` - Business logic for calorie calculations

**Utilities (2 files)**:
- `Config.swift` - Application configuration management
- `Secrets.swift` - API credentials and sensitive data

**Root Files (2 files)**:
- `CountMeApp.swift` - Application entry point (stays in root)
- `Item.swift` - Legacy file (evaluate for removal)

### Import Impact Analysis

**Swift Module System**: Swift uses module-based imports, not file path imports. All files in the CountMe target are part of the same module, so moving files within the target does NOT require import statement changes.

**Example**:
```swift
// Before move: CountMe/DataStore.swift
import SwiftData

// After move: CountMe/Services/DataStore.swift
import SwiftData

// Other files importing DataStore - NO CHANGES NEEDED
// The import is module-based, not path-based
```

**No Import Changes Required**: Because all files remain in the CountMe module, no Swift files need import statement modifications.

### Xcode Project File Structure

**project.pbxproj Format**: The Xcode project file uses a hierarchical structure with:
- `PBXFileReference` - Individual file references with paths
- `PBXGroup` - Folder groupings (visual organization)
- `PBXSourcesBuildPhase` - Files included in compilation

**Update Strategy**:
1. Update `PBXFileReference` path attributes for moved files
2. Create new `PBXGroup` entries for Views/, Services/, Utilities/
3. Move file references to appropriate groups
4. Maintain existing build phase memberships

**Xcode CLI Tools**: Use `xcodebuild` to verify project integrity after changes.

## Data Models

### File Move Operation

```swift
struct FileMoveOperation {
    let sourcePath: String        // Current file path
    let destinationPath: String   // Target file path
    let fileType: FileType        // View, Service, Utility, Test
    let xcodeGroup: String        // Target Xcode group name
}

enum FileType {
    case view
    case service
    case utility
    case test
    case model  // Already organized, no moves needed
}
```

### Refactoring Phase

```swift
struct RefactoringPhase {
    let name: String              // "Move Views", "Move Services", etc.
    let operations: [FileMoveOperation]
    let verificationSteps: [String]
    let rollbackProcedure: String
}
```

### Project State

```swift
struct ProjectState {
    let buildSucceeds: Bool
    let testsPass: Bool
    let filesInCorrectLocation: Bool
    let xcodeProjectValid: Bool
    let gitHistoryPreserved: Bool
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property Reflection

After analyzing all acceptance criteria, I identified several redundant properties:

**Redundancies Identified**:
1. Properties 1.4, 2.4, and 4.4 all test that moved files compile successfully - can be combined into one comprehensive property
2. Properties 1.5, 2.5, 3.4, and 5.5 all test that Xcode project reflects new structure - can be combined
3. Properties 7.2, 7.3, and 7.4 all test that tests still pass - 7.2 subsumes the others
4. Properties 10.1, 10.2, and 10.5 all test that project builds after each phase - can be combined

**Consolidated Properties**:
- Build success property covers all file types (views, services, utilities)
- Xcode project structure property covers all folder types
- Test execution property covers all test types (unit, property, integration)
- Incremental build property covers all refactoring phases

### Properties

Property 1: File move preserves functionality
*For any* source file that is moved to a new directory, all existing tests for that file should continue to pass with the same results as before the move.
**Validates: Requirements 1.2, 2.3, 3.3**

Property 2: Build success after file moves
*For any* group of files moved to a new directory (Views, Services, or Utilities), the project should compile without errors after the move operation completes.
**Validates: Requirements 1.4, 2.4, 4.4, 6.1**

Property 3: Xcode project references updated
*For any* file that is moved, the Xcode project.pbxproj file should contain a PBXFileReference entry with the correct new path.
**Validates: Requirements 4.1**

Property 4: Build phase membership preserved
*For any* file that is moved, its membership in build phases (compile sources, resources, etc.) should remain unchanged after the move.
**Validates: Requirements 4.3**

Property 5: Build settings preserved
*For any* build configuration (Debug, Release), all build settings should have identical values before and after the refactoring.
**Validates: Requirements 4.5**

Property 6: Test file mirroring
*For any* test file that is moved, its new location should mirror the folder structure of the source file it tests (e.g., Services/DataStore.swift → Services/DataStoreTests.swift).
**Validates: Requirements 5.2**

Property 7: Test execution completeness
*For any* test suite run after refactoring, the number of executed tests should equal the number of tests before refactoring, and pass/fail results should be identical.
**Validates: Requirements 7.1, 7.2**

Property 8: Code coverage preservation
*For any* code coverage measurement after refactoring, the coverage percentage should be greater than or equal to the coverage before refactoring (target: 90%+).
**Validates: Requirements 7.5**

Property 9: Git history preservation
*For any* file that is moved using git mv, running `git log --follow <file>` should show the complete commit history from before the move.
**Validates: Requirements 8.1, 8.2**

Property 10: Git blame preservation
*For any* line of code in a moved file, `git blame` should attribute the line to the same author and commit as before the move.
**Validates: Requirements 8.3**

Property 11: Incremental buildability
*For any* refactoring phase (Views, Services, Utilities, Tests), the project should compile successfully after that phase completes and before the next phase begins.
**Validates: Requirements 10.1, 10.2, 10.5**

## Error Handling

### File Move Failures

**Scenario**: File move operation fails due to permissions or file system errors

**Handling**:
- Detect failure immediately using file system error codes
- Log specific error message with file path and error reason
- Halt refactoring process to prevent partial state
- Provide rollback instructions to user
- Verify file system permissions before starting refactoring

### Xcode Project Corruption

**Scenario**: project.pbxproj becomes corrupted or invalid during updates

**Handling**:
- Create backup of project.pbxproj before any modifications
- Validate project file syntax after each modification
- Use `xcodebuild -list` to verify project can be parsed
- If corruption detected, restore from backup
- Provide manual recovery steps if backup fails

### Build Failures

**Scenario**: Project fails to build after file moves

**Handling**:
- Capture full build log with error details
- Identify which files are causing build failures
- Check for missing file references in project.pbxproj
- Verify all import statements are correct
- Provide specific error messages for each failure type
- Offer rollback to last known good state

### Test Failures

**Scenario**: Tests fail after refactoring when they passed before

**Handling**:
- Run tests before refactoring to establish baseline
- Compare test results before/after to identify regressions
- Check for test file path issues in Xcode project
- Verify test target membership for moved test files
- Provide detailed diff of test results
- Halt refactoring if critical tests fail

### Git History Loss

**Scenario**: Git history is not preserved for moved files

**Handling**:
- Verify `git mv` command succeeded for each file
- Test `git log --follow` after each move
- If history lost, undo move and retry with correct command
- Document git version requirements (2.0+ for reliable --follow)
- Provide manual history recovery steps if needed

### Documentation Update Failures

**Scenario**: Documentation files cannot be updated or are missing

**Handling**:
- Check file existence before attempting updates
- Validate markdown syntax after updates
- Create missing documentation files if needed
- Log warnings for documentation issues (non-blocking)
- Provide manual update instructions as fallback

## Testing Strategy

### Dual Testing Approach

This refactoring will use both unit tests and property-based tests to ensure correctness:

**Unit Tests**: Verify specific examples and edge cases
- Test that specific files exist in expected locations
- Test that specific Xcode project groups are created
- Test that documentation contains expected sections
- Test that git commits have expected structure

**Property Tests**: Verify universal properties across all inputs
- Test that all moved files preserve functionality
- Test that all moved files compile successfully
- Test that all moved files preserve git history
- Test that all test files mirror source structure

### Property-Based Testing Configuration

**Library**: Swift Testing framework with custom property test helpers

**Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with feature name and property number
- Tag format: `Feature: file-structure-refactor, Property {N}: {description}`

**Test Organization**:
```
CountMeTests/
├── FileStructureRefactor/
│   ├── PropertyTests/
│   │   ├── FileMovePropertyTests.swift
│   │   ├── BuildPropertyTests.swift
│   │   ├── GitHistoryPropertyTests.swift
│   │   └── TestMirroringPropertyTests.swift
│   └── UnitTests/
│       ├── DirectoryStructureTests.swift
│       ├── XcodeProjectTests.swift
│       └── DocumentationTests.swift
```

### Test Implementation Requirements

**Each correctness property MUST be implemented by a SINGLE property-based test**:

1. Property 1 → `testFileMovePreservesFunctionality()`
2. Property 2 → `testBuildSuccessAfterFileMoves()`
3. Property 3 → `testXcodeProjectReferencesUpdated()`
4. Property 4 → `testBuildPhaseMembershipPreserved()`
5. Property 5 → `testBuildSettingsPreserved()`
6. Property 6 → `testTestFileMirroring()`
7. Property 7 → `testTestExecutionCompleteness()`
8. Property 8 → `testCodeCoveragePreservation()`
9. Property 9 → `testGitHistoryPreservation()`
10. Property 10 → `testGitBlamePreservation()`
11. Property 11 → `testIncrementalBuildability()`

### Verification Steps

**Before Refactoring**:
1. Run full test suite and record results
2. Measure code coverage and record percentage
3. Build project and verify success
4. Record list of all source files and their paths
5. Capture Xcode project structure
6. Document current git commit state

**After Each Phase**:
1. Verify project builds successfully
2. Run affected tests and verify they pass
3. Check Xcode project file is valid
4. Verify git history is preserved for moved files
5. Commit changes with descriptive message

**After Complete Refactoring**:
1. Run full test suite and compare to baseline
2. Measure code coverage and verify ≥90%
3. Build for simulator and device
4. Verify all files in correct locations
5. Verify Xcode project structure matches target
6. Verify git history preserved for all moved files
7. Verify documentation updated correctly
8. Run property-based tests (100+ iterations each)

### Manual Verification

Some aspects require manual verification:
- Visual inspection of Xcode project navigator
- Verification that app runs correctly on simulator/device
- Review of commit messages for clarity
- Review of documentation for completeness
- Performance comparison of build times

### Rollback Testing

Test rollback procedures:
1. Simulate file move failure mid-refactoring
2. Verify project can be restored to previous state
3. Verify no partial changes remain
4. Verify git history is clean after rollback
5. Document rollback steps for each phase
