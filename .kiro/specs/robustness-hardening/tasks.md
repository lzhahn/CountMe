# Implementation Plan: Robustness Hardening

## Overview

Implement input validation on model constructors, bounds checking on Firestore deserialization, and sync queue hardening (size limit + per-item retry). Work proceeds bottom-up: shared constants first, then model validation, then deserialization, then sync queue, with tests alongside each layer.

## Tasks

- [x] 1. Create ValidationError and ValidationConstants
  - [x] 1.1 Create `CountMe/Models/ValidationConstants.swift` with `maxCalories`, `maxMacroGrams`, `maxDurationMinutes`, `maxDailyGoal` constants
    - _Requirements: 1.2, 1.3, 1.5, 2.2, 2.3, 2.5, 3.4, 3.5, 5.1, 5.2_
  - [x] 1.2 Create `CountMe/Models/ValidationError.swift` with all error cases and `errorDescription` computed property
    - _Requirements: 1.1–1.5, 2.1–2.5, 3.1–3.6, 4.1–4.3, 5.1–5.2_

- [x] 2. Add throwing initializers to FoodItem
  - [x] 2.1 Add a throwing `init` to FoodItem that validates name, calories, and optional macros against ValidationConstants; add an internal `init(validated:...)` that skips validation for use by `fromFirestoreData()`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
  - [ ]* 2.2 Write property test: valid FoodItem construction succeeds (Property 1)
    - **Property 1: Valid FoodItem construction succeeds**
    - **Validates: Requirements 1.6**
  - [ ]* 2.3 Write property test: invalid FoodItem construction is rejected (Property 2)
    - **Property 2: Invalid FoodItem construction is rejected**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

- [ ] 3. Add throwing initializers to ExerciseItem
  - [x] 3.1 Add a throwing `init` to ExerciseItem that validates name, caloriesBurned, and optional durationMinutes; add an internal `init(validated:...)` for deserialization
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  - [ ]* 3.2 Write property test: valid ExerciseItem construction succeeds (Property 3)
    - **Property 3: Valid ExerciseItem construction succeeds**
    - **Validates: Requirements 2.6**
  - [ ]* 3.3 Write property test: invalid ExerciseItem construction is rejected (Property 4)
    - **Property 4: Invalid ExerciseItem construction is rejected**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

- [ ] 4. Add throwing initializers to Ingredient
  - [x] 4.1 Add a throwing `init` to Ingredient that validates name, quantity, unit, calories, and optional macros; add an internal `init(validated:...)` for deserialization
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  - [ ]* 4.2 Write property test: valid Ingredient construction succeeds (Property 5)
    - **Property 5: Valid Ingredient construction succeeds**
    - **Validates: Requirements 3.7**
  - [ ]* 4.3 Write property test: invalid Ingredient construction is rejected (Property 6)
    - **Property 6: Invalid Ingredient construction is rejected**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

- [ ] 5. Add throwing initializers to CustomMeal and DailyLog
  - [x] 5.1 Add a throwing `init` to CustomMeal that validates name, ingredients (non-empty), and servingsCount; add an internal `init(validated:...)` for deserialization
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [x] 5.2 Add a throwing `init` to DailyLog that validates optional dailyGoal; add an internal `init(validated:...)` for deserialization
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - [ ]* 5.3 Write property test: valid CustomMeal construction succeeds (Property 7)
    - **Property 7: Valid CustomMeal construction succeeds**
    - **Validates: Requirements 4.4**
  - [ ]* 5.4 Write property test: invalid CustomMeal construction is rejected (Property 8)
    - **Property 8: Invalid CustomMeal construction is rejected**
    - **Validates: Requirements 4.1, 4.3**
  - [ ]* 5.5 Write property test: valid DailyLog construction succeeds (Property 9)
    - **Property 9: Valid DailyLog construction succeeds**
    - **Validates: Requirements 5.3, 5.4**
  - [ ]* 5.6 Write property test: invalid DailyLog construction is rejected (Property 10)
    - **Property 10: Invalid DailyLog construction is rejected**
    - **Validates: Requirements 5.1, 5.2**

- [x] 6. Checkpoint — Ensure all model validation tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Add bounds checking to fromFirestoreData()
  - [x] 7.1 Add range validation to `FoodItem.fromFirestoreData()` — check name, calories, and macros against ValidationConstants; throw `SyncError.invalidData` on violation; call internal `init(validated:...)` on success
    - _Requirements: 6.1, 6.2, 6.3, 6.8_
  - [x] 7.2 Add range validation to `ExerciseItem.fromFirestoreData()` — check name, caloriesBurned, durationMinutes; throw `SyncError.invalidData` on violation
    - _Requirements: 6.4, 6.5, 6.8_
  - [x] 7.3 Add range validation to `CustomMeal.fromFirestoreData()` — check name, servingsCount, and each ingredient's calories; throw `SyncError.invalidData` on violation
    - _Requirements: 6.6, 6.8_
  - [x] 7.4 Add range validation to `DailyLog.fromFirestoreData()` — check dailyGoal; throw `SyncError.invalidData` on violation
    - _Requirements: 6.7, 6.8_
  - [ ]* 7.5 Write property test: deserialization rejects out-of-range Firestore data (Property 11)
    - **Property 11: Deserialization rejects out-of-range Firestore data**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7**
  - [ ]* 7.6 Write property test: deserialization accepts valid Firestore data (Property 12)
    - **Property 12: Deserialization accepts valid Firestore data**
    - **Validates: Requirements 6.8**

- [x] 8. Checkpoint — Ensure all deserialization tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Harden sync queue
  - [x] 9.1 Add `maxQueueSize` constant (1000) to FirebaseSyncEngine and enforce it in `queueOperation()` — drop oldest when at capacity
    - _Requirements: 7.1, 7.2, 7.3_
  - [x] 9.2 Refactor `processQueue()` to wrap each operation in `retryManager.executeWithRetry()` — remove operation on success or max retries exceeded, continue processing remaining operations
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  - [ ]* 9.3 Write property test: queue size invariant (Property 13)
    - **Property 13: Queue size invariant**
    - **Validates: Requirements 7.1, 7.2, 7.3**
  - [ ]* 9.4 Write property test: queue processing continues despite failures (Property 14)
    - **Property 14: Queue processing continues despite individual failures**
    - **Validates: Requirements 8.4**
  - [ ]* 9.5 Write unit tests for sync queue retry integration
    - Test: operation succeeds after retry removes it from queue (Requirement 8.3)
    - Test: operation exceeding max retries is removed and logged (Requirement 8.2)
    - Test: RetryManager is invoked for each queued operation (Requirement 8.1)
    - _Requirements: 8.1, 8.2, 8.3_

- [x] 10. Fix existing call sites
  - [x] 10.1 Update all existing callers that construct FoodItem, ExerciseItem, Ingredient, CustomMeal, and DailyLog to handle the new throwing initializers (DataStore methods, view models, API response parsing, test fixtures)
    - _Requirements: 1.6, 2.6, 3.7, 4.4, 5.4_

- [ ] 11. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties (100+ iterations each)
- Unit tests validate specific examples and edge cases
- The internal `init(validated:...)` pattern avoids double-validation in deserialization paths
