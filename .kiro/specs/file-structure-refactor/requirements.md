# Requirements Document

## Introduction

This specification defines the requirements for refactoring the CountMe iOS application's file structure from a flat organization to a feature-based, type-organized architecture. The current structure has most Swift files in the root CountMe/ directory, making navigation difficult and violating the documented architecture patterns. This refactoring will reorganize files into Views/, Services/, and Utilities/ folders while maintaining full functionality and test coverage.

## Glossary

- **File_Structure**: The hierarchical organization of source code files within the project directory
- **Xcode_Project**: The .xcodeproj bundle containing project.pbxproj which tracks file references and build settings
- **SwiftUI_View**: A Swift struct conforming to the View protocol that defines user interface components
- **Service**: Business logic components including API clients, data stores, and domain logic
- **Utility**: Helper functions, configuration files, extensions, and shared infrastructure code
- **Import_Path**: The module-based reference used in Swift import statements
- **Build_Phase**: Xcode compilation step that processes source files into executable code
- **Test_Mirror**: The practice of replicating source folder structure in the test directory

## Requirements

### Requirement 1: Reorganize View Files

**User Story:** As a developer, I want all SwiftUI views organized in a Views/ folder, so that I can quickly locate and understand the UI components.

#### Acceptance Criteria

1. THE File_Structure SHALL contain a Views/ directory under CountMe/
2. WHEN moving view files, THE System SHALL preserve all SwiftUI view functionality
3. THE Views/ directory SHALL contain ContentView, FoodSearchView, ManualEntryView, FoodItemRow, SearchResultRow, GoalSettingView, HistoricalView, MainCalorieView, and ServingAdjustmentView
4. WHEN the project builds, THE System SHALL successfully compile all moved view files
5. THE Xcode_Project SHALL reflect the new Views/ folder structure in the project navigator

### Requirement 2: Reorganize Service Files

**User Story:** As a developer, I want business logic and API clients organized in a Services/ folder, so that I can separate concerns and maintain clean architecture.

#### Acceptance Criteria

1. THE File_Structure SHALL contain a Services/ directory under CountMe/
2. THE Services/ directory SHALL contain NutritionAPIClient, OAuth1SignatureGenerator, DataStore, and CalorieTracker
3. WHEN moving service files, THE System SHALL preserve all business logic functionality
4. WHEN the project builds, THE System SHALL successfully compile all moved service files
5. THE Xcode_Project SHALL reflect the new Services/ folder structure in the project navigator

### Requirement 3: Reorganize Utility Files

**User Story:** As a developer, I want configuration and utility files organized in a Utilities/ folder, so that I can easily find shared infrastructure code.

#### Acceptance Criteria

1. THE File_Structure SHALL contain a Utilities/ directory under CountMe/
2. THE Services/ directory SHALL contain Config.swift and Secrets.swift
3. WHEN moving utility files, THE System SHALL preserve all configuration functionality
4. THE Xcode_Project SHALL reflect the new Utilities/ folder structure in the project navigator
5. WHEN the application runs, THE System SHALL successfully load configuration values

### Requirement 4: Update Xcode Project References

**User Story:** As a developer, I want the Xcode project file updated to reflect the new structure, so that the project navigator shows the correct organization.

#### Acceptance Criteria

1. WHEN files are moved, THE Xcode_Project SHALL update all file references in project.pbxproj
2. WHEN opening the project in Xcode, THE System SHALL display the new folder structure in the project navigator
3. THE Xcode_Project SHALL maintain all existing build phases and file memberships
4. WHEN building the project, THE System SHALL locate all source files correctly
5. THE Xcode_Project SHALL preserve all existing build settings and configurations

### Requirement 5: Mirror Structure in Test Folder

**User Story:** As a developer, I want the test folder structure to mirror the source structure, so that I can easily locate tests for specific components.

#### Acceptance Criteria

1. THE File_Structure SHALL contain Views/, Services/, and Utilities/ directories under CountMeTests/
2. WHEN moving test files, THE System SHALL place them in folders matching their source counterparts
3. THE Test_Mirror SHALL organize CoreUIFlowsTests in Views/, NutritionAPIClientTests and OAuth1SignatureGeneratorTests in Services/
4. WHEN running tests, THE System SHALL successfully execute all test cases
5. THE Xcode_Project SHALL reflect the new test folder structure in the project navigator

### Requirement 6: Verify Build Success

**User Story:** As a developer, I want the project to build successfully after refactoring, so that I can ensure no functionality was broken.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE System SHALL compile without errors
2. WHEN the refactoring is complete, THE System SHALL compile without warnings related to file moves
3. WHEN building for iOS simulator, THE System SHALL produce a runnable application
4. WHEN building for iOS device, THE System SHALL produce a valid archive
5. THE Build_Phase SHALL complete in similar time to pre-refactoring builds

### Requirement 7: Verify Test Success

**User Story:** As a developer, I want all tests to pass after refactoring, so that I can ensure no functionality was broken.

#### Acceptance Criteria

1. WHEN running the test suite, THE System SHALL execute all existing tests
2. WHEN running the test suite, THE System SHALL report the same pass/fail results as before refactoring
3. WHEN running property-based tests, THE System SHALL complete all 100+ iterations successfully
4. WHEN running integration tests, THE System SHALL successfully interact with all components
5. THE System SHALL maintain 90%+ code coverage after refactoring

### Requirement 8: Preserve Git History

**User Story:** As a developer, I want git history preserved for moved files, so that I can track changes and understand file evolution.

#### Acceptance Criteria

1. WHEN moving files with git, THE System SHALL use git mv command to preserve history
2. WHEN viewing git log with --follow flag, THE System SHALL show complete file history across the move
3. WHEN viewing git blame, THE System SHALL attribute lines to original authors
4. THE System SHALL create atomic commits for each logical grouping of moves
5. THE System SHALL include descriptive commit messages explaining each refactoring step

### Requirement 9: Update Documentation

**User Story:** As a developer, I want documentation updated to reflect the new structure, so that new team members understand the organization.

#### Acceptance Criteria

1. WHEN refactoring is complete, THE System SHALL update project-foundation.md with actual folder structure
2. THE Documentation SHALL include a migration guide explaining the changes
3. THE Documentation SHALL update the "Project Structure Reference" section
4. THE Documentation SHALL note any import changes or migration steps
5. THE Documentation SHALL include before/after structure diagrams

### Requirement 10: Maintain Zero Downtime

**User Story:** As a developer, I want the build to work at each refactoring step, so that I can verify changes incrementally.

#### Acceptance Criteria

1. WHEN moving each group of files, THE System SHALL maintain a buildable state
2. WHEN committing changes, THE System SHALL ensure the project builds successfully
3. THE Refactoring SHALL proceed in logical increments (Views, then Services, then Utilities)
4. WHEN an error occurs, THE System SHALL allow rollback to the previous working state
5. THE System SHALL verify build success before proceeding to the next file group
