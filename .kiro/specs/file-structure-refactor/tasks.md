# Implementation Plan: File Structure Refactor

## Overview

This plan outlines the step-by-step refactoring of the CountMe iOS application's file structure from a flat organization to a feature-based, type-organized architecture. The refactoring will proceed in phases (Views → Services → Utilities → Tests) with verification at each step to maintain buildability and preserve functionality.

## Tasks

- [x] 1. Pre-refactoring verification and setup
  - Run full test suite and record baseline results (pass/fail counts)
  - Measure and record code coverage percentage
  - Build project for simulator and device, verify success
  - Create list of all source files with current paths
  - Capture current Xcode project structure
  - Create backup of project.pbxproj file
  - Document current git commit SHA
  - _Requirements: 6.1, 7.1, 7.2, 7.5, 8.4_

- [ ] 2. Create target directory structure
  - [x] 2.1 Create Views/, Services/, and Utilities/ folders in CountMe/
    - Use `mkdir -p CountMe/Views CountMe/Services CountMe/Utilities`
    - Verify folders created successfully
    - _Requirements: 1.1, 2.1, 3.1_
  
  - [x] 2.2 Create Views/, Services/, and Models/ folders in CountMeTests/
    - Use `mkdir -p CountMeTests/Views CountMeTests/Services CountMeTests/Models`
    - Verify folders created successfully
    - _Requirements: 5.1_
  
  - [x] 2.3 Update Xcode project to include new folder groups
    - Open project in Xcode
    - Create group references for new folders
    - Verify groups appear in project navigator
    - _Requirements: 1.5, 2.5, 3.4, 4.2_

- [ ] 3. Phase 1: Move View files
  - [x] 3.1 Move all 9 view files to Views/ folder
    - Use `git mv` for each file: ContentView.swift, MainCalorieView.swift, FoodSearchView.swift, ManualEntryView.swift, ServingAdjustmentView.swift, FoodItemRow.swift, SearchResultRow.swift, GoalSettingView.swift, HistoricalView.swift
    - Update Xcode project file references for each moved file
    - Move files to Views/ group in Xcode project navigator
    - _Requirements: 1.2, 1.3, 4.1_
  
  - [x] 3.2 Verify build success after moving views
    - Run `xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 15' clean build`
    - Verify no compilation errors
    - Check for any warnings related to file moves
    - _Requirements: 1.4, 6.1, 10.1_
  
  - [ ]* 3.3 Run UI tests to verify view functionality preserved
    - Run CoreUIFlowsTests test suite
    - Verify all tests pass with same results as baseline
    - _Requirements: 1.2, 7.1, 7.2_
  
  - [x] 3.4 Commit Phase 1 changes
    - Stage all moved files and project changes
    - Commit with message: "refactor: Move view files to Views/ folder"
    - Verify git log shows moved files
    - _Requirements: 8.1, 8.4_

- [ ] 4. Phase 2: Move Service files
  - [-] 4.1 Move all 4 service files to Services/ folder
    - Use `git mv` for each file: DataStore.swift, NutritionAPIClient.swift, OAuth1SignatureGenerator.swift, CalorieTracker.swift
    - Update Xcode project file references for each moved file
    - Move files to Services/ group in Xcode project navigator
    - _Requirements: 2.2, 2.3, 4.1_
  
  - [~] 4.2 Verify build success after moving services
    - Run `xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 15' clean build`
    - Verify no compilation errors
    - Check for any warnings related to file moves
    - _Requirements: 2.4, 6.1, 10.1_
  
  - [ ]* 4.3 Run service tests to verify functionality preserved
    - Run NutritionAPIClientTests and OAuth1SignatureGeneratorTests
    - Verify all tests pass with same results as baseline
    - _Requirements: 2.3, 7.1, 7.2_
  
  - [~] 4.4 Commit Phase 2 changes
    - Stage all moved files and project changes
    - Commit with message: "refactor: Move service files to Services/ folder"
    - Verify git log shows moved files
    - _Requirements: 8.1, 8.4_

- [ ] 5. Phase 3: Move Utility files
  - [~] 5.1 Move all 2 utility files to Utilities/ folder
    - Use `git mv` for each file: Config.swift, Secrets.swift
    - Update Xcode project file references for each moved file
    - Move files to Utilities/ group in Xcode project navigator
    - _Requirements: 3.2, 3.3, 4.1_
  
  - [~] 5.2 Verify build success after moving utilities
    - Run `xcodebuild -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 15' clean build`
    - Verify no compilation errors
    - Check for any warnings related to file moves
    - _Requirements: 6.1, 10.1_
  
  - [~] 5.3 Verify configuration loading works
    - Run app on simulator
    - Verify Config.swift and Secrets.swift load correctly
    - Check that API credentials are accessible
    - _Requirements: 3.5_
  
  - [~] 5.4 Commit Phase 3 changes
    - Stage all moved files and project changes
    - Commit with message: "refactor: Move utility files to Utilities/ folder"
    - Verify git log shows moved files
    - _Requirements: 8.1, 8.4_

- [~] 6. Checkpoint - Verify source refactoring complete
  - Ensure all source files are in correct locations
  - Verify project builds without errors or warnings
  - Run full test suite and verify all tests pass
  - Ask the user if questions arise

- [ ] 7. Phase 4: Move Test files
  - [~] 7.1 Move CoreUIFlowsTests.swift to CountMeTests/Views/
    - Use `git mv CountMeTests/CoreUIFlowsTests.swift CountMeTests/Views/`
    - Update Xcode project file reference
    - Move to Views/ group in Xcode test navigator
    - _Requirements: 5.2, 5.3_
  
  - [~] 7.2 Move service test files to CountMeTests/Services/
    - Use `git mv` for NutritionAPIClientTests.swift and OAuth1SignatureGeneratorTests.swift
    - Update Xcode project file references
    - Move to Services/ group in Xcode test navigator
    - _Requirements: 5.2, 5.3_
  
  - [~] 7.3 Move FoodItemMacroTests.swift to CountMeTests/Models/
    - Use `git mv CountMeTests/FoodItemMacroTests.swift CountMeTests/Models/`
    - Update Xcode project file reference
    - Move to Models/ group in Xcode test navigator
    - _Requirements: 5.2_
  
  - [~] 7.4 Verify test execution after moving test files
    - Run full test suite
    - Verify all tests execute successfully
    - Compare results to baseline (same pass/fail counts)
    - _Requirements: 5.4, 7.1, 7.2_
  
  - [~] 7.5 Commit Phase 4 changes
    - Stage all moved test files and project changes
    - Commit with message: "refactor: Reorganize test files to mirror source structure"
    - Verify git log shows moved files
    - _Requirements: 8.1, 8.4_

- [ ] 8. Post-refactoring verification
  - [~] 8.1 Verify complete build success
    - Build for iOS Simulator and verify success
    - Build for iOS Device and verify archive creation
    - Check build time is similar to pre-refactoring
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [~] 8.2 Verify all tests pass
    - Run complete test suite
    - Verify test count matches baseline
    - Verify pass/fail results match baseline
    - _Requirements: 7.1, 7.2_
  
  - [~] 8.3 Verify code coverage maintained
    - Measure code coverage after refactoring
    - Compare to baseline coverage
    - Verify coverage is ≥90% and ≥ baseline
    - _Requirements: 7.5_
  
  - [ ]* 8.4 Verify git history preserved
    - For each moved file, run `git log --follow <file>`
    - Verify complete commit history is visible
    - Run `git blame` on moved files and verify author attribution
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [~] 8.5 Verify Xcode project structure
    - Open project in Xcode
    - Verify all folders appear correctly in project navigator
    - Verify all files are in correct groups
    - Verify no red (missing) file references
    - _Requirements: 1.5, 2.5, 3.4, 4.2, 5.5_

- [ ]* 9. Write property-based tests for refactoring verification
  - [ ]* 9.1 Write property test for file move functionality preservation
    - **Property 1: File move preserves functionality**
    - **Validates: Requirements 1.2, 2.3, 3.3**
    - Test that for any moved file, its tests still pass
    - Tag: `Feature: file-structure-refactor, Property 1: File move preserves functionality`
  
  - [ ]* 9.2 Write property test for build success
    - **Property 2: Build success after file moves**
    - **Validates: Requirements 1.4, 2.4, 4.4, 6.1**
    - Test that project compiles after moving any group of files
    - Tag: `Feature: file-structure-refactor, Property 2: Build success after file moves`
  
  - [ ]* 9.3 Write property test for Xcode project references
    - **Property 3: Xcode project references updated**
    - **Validates: Requirements 4.1**
    - Test that project.pbxproj contains correct paths for all moved files
    - Tag: `Feature: file-structure-refactor, Property 3: Xcode project references updated`
  
  - [ ]* 9.4 Write property test for build phase membership
    - **Property 4: Build phase membership preserved**
    - **Validates: Requirements 4.3**
    - Test that moved files retain their build phase memberships
    - Tag: `Feature: file-structure-refactor, Property 4: Build phase membership preserved`
  
  - [ ]* 9.5 Write property test for build settings preservation
    - **Property 5: Build settings preserved**
    - **Validates: Requirements 4.5**
    - Test that all build settings are identical before/after refactoring
    - Tag: `Feature: file-structure-refactor, Property 5: Build settings preserved`
  
  - [ ]* 9.6 Write property test for test file mirroring
    - **Property 6: Test file mirroring**
    - **Validates: Requirements 5.2**
    - Test that test file locations mirror source file locations
    - Tag: `Feature: file-structure-refactor, Property 6: Test file mirroring`
  
  - [ ]* 9.7 Write property test for test execution completeness
    - **Property 7: Test execution completeness**
    - **Validates: Requirements 7.1, 7.2**
    - Test that test count and results match baseline
    - Tag: `Feature: file-structure-refactor, Property 7: Test execution completeness`
  
  - [ ]* 9.8 Write property test for code coverage preservation
    - **Property 8: Code coverage preservation**
    - **Validates: Requirements 7.5**
    - Test that code coverage is ≥90% and ≥ baseline
    - Tag: `Feature: file-structure-refactor, Property 8: Code coverage preservation`
  
  - [ ]* 9.9 Write property test for git history preservation
    - **Property 9: Git history preservation**
    - **Validates: Requirements 8.1, 8.2**
    - Test that `git log --follow` shows complete history for moved files
    - Tag: `Feature: file-structure-refactor, Property 9: Git history preservation`
  
  - [ ]* 9.10 Write property test for git blame preservation
    - **Property 10: Git blame preservation**
    - **Validates: Requirements 8.3**
    - Test that `git blame` attributes lines correctly after moves
    - Tag: `Feature: file-structure-refactor, Property 10: Git blame preservation`
  
  - [ ]* 9.11 Write property test for incremental buildability
    - **Property 11: Incremental buildability**
    - **Validates: Requirements 10.1, 10.2, 10.5**
    - Test that project builds successfully after each refactoring phase
    - Tag: `Feature: file-structure-refactor, Property 11: Incremental buildability`

- [ ] 10. Update documentation
  - [~] 10.1 Update project-foundation.md with new structure
    - Update "Project Structure Reference" section with actual folder layout
    - Document the Views/, Services/, Utilities/ organization
    - Note that no import changes are required (module-based imports)
    - _Requirements: 9.1, 9.3, 9.4_
  
  - [~] 10.2 Create migration guide
    - Document the refactoring process and rationale
    - Include before/after structure diagrams
    - Note that git history is preserved with `git log --follow`
    - Explain that no code changes were needed (only file moves)
    - _Requirements: 9.2, 9.5_
  
  - [~] 10.3 Update README if needed
    - Check if README references file structure
    - Update any outdated file path references
    - Add note about folder organization principles
    - _Requirements: 9.1_

- [~] 11. Final checkpoint - Complete verification
  - Run full test suite one final time
  - Build for simulator and device
  - Verify all documentation is updated
  - Verify git history is clean and complete
  - Ask the user if questions arise or if ready to merge

## Notes

- Tasks marked with `*` are optional and can be skipped for faster completion
- Each phase (Views, Services, Utilities, Tests) maintains buildability
- Git history is preserved using `git mv` command
- No import statement changes are required (module-based imports)
- Xcode project file updates are critical for each phase
- Property tests verify correctness properties across all moved files
- Manual verification steps ensure visual correctness in Xcode
