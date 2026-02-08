# Test Suite Optimization

## Changes Made to Speed Up Tests

### 1. Disabled Performance Tests
Performance tests use `measure()` which runs code multiple times to get accurate timing. These are slow and rarely needed during regular development.

**Disabled:**
- `CountMeTests/CountMeTests.swift` - `testPerformanceExample()`
- `CountMeUITests/CountMeUITests.swift` - `testLaunchPerformance()`

**To re-enable:** Uncomment the test methods when you need to measure performance.

### 2. Reduced Sleep Durations
Reduced artificial delays in tests from 100ms to 1-10ms where possible.

**Changed:**
- `CountMeTests/Views/CustomMealDetailViewTests.swift` - 100ms → 1ms
- Network monitor tests already commented out

### 3. Additional Optimization Tips

**Run specific test targets:**
```bash
# Run only unit tests (faster)
xcodebuild test -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CountMeTests

# Skip UI tests entirely
xcodebuild test -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:CountMeUITests
```

**Run specific test files:**
```bash
# Test only one file
xcodebuild test -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CountMeTests/CoreUIFlowsTests
```

**Parallel testing:**
```bash
# Enable parallel testing (may already be enabled)
xcodebuild test -scheme CountMe -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled YES
```

### 4. Test File Sizes
Largest test files (most test cases):
1. NutritionAPIClientTests.swift - 628 lines
2. CoreUIFlowsTests.swift - 526 lines
3. IngredientConverterTests.swift - 457 lines
4. AIRecipeParserTests.swift - 419 lines
5. CustomMealDetailViewTests.swift - 417 lines

These are comprehensive but not necessarily slow unless they have network calls or heavy operations.

### 5. What Makes Tests Slow

**Avoid in tests:**
- Long `Task.sleep()` calls
- Performance measurement tests during regular runs
- UI tests (launch full app, very slow)
- Real network calls (use mocks)
- Large data generation without caching

**Fast test practices:**
- In-memory databases (already using `isStoredInMemoryOnly: true`)
- Mock network responses (already doing this)
- Minimal sleep times
- Focused test scope

## Expected Results

Before optimization: Tests likely took 30-60+ seconds
After optimization: Should be 10-30 seconds depending on machine

UI tests are inherently slow (5-10 seconds each) because they launch the full app.
