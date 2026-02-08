# CountMe Project Foundation

## Project Overview

CountMe is an iOS calorie tracking app built with SwiftUI and SwiftData. Integrates with FatSecret API for nutrition data, Firebase for auth/sync, with offline-first architecture.

## Technology Stack

- **Platform**: iOS (SwiftUI) - Target: iPhone 17
- **Persistence**: SwiftData (local) + Firestore (cloud)
- **APIs**: FatSecret Platform API (OAuth 1.0), Firebase Auth/Firestore
- **Architecture**: MVVM, actor-based concurrency
- **Testing**: Swift Testing with property-based tests

## Core Architecture

### Data Flow
```
SwiftUI Views → View Models → Services → DataStore (SwiftData) / Firestore
                                      → API Client (FatSecret)
```

### Key Components

**Models** (`CountMe/Models/`): FoodItem, DailyLog, CustomMeal, Ingredient, SyncableEntity

**Services** (`CountMe/Services/`): DataStore, FirebaseAuthService, FirebaseSyncEngine, NutritionAPIClient, OAuth1SignatureGenerator

**Views** (`CountMe/Views/`): AuthenticationView, ContentView, MainCalorieView, FoodSearchView, ProfileView

**Utilities** (`CountMe/Utilities/`): Config, Secrets

## Key Patterns

### Date Normalization
All dates normalized to midnight for consistent daily log retrieval via `DataStore.normalizeDate()`

### Actor-Based Concurrency
DataStore and FirebaseSyncEngine are actors for thread-safe operations. All mutations use async/await.

### Dual Persistence (Firebase)
All data stored locally (SwiftData) AND cloud (Firestore) when authenticated. Offline-first with automatic sync.

### Conflict Resolution
Last-write-wins based on timestamps. Daily logs merge food items from both versions.

## FatSecret API

- OAuth 1.0 signature-based auth
- Key endpoints: `foods.search`, `food.get.v2`
- Parse `foodDescription` for calories (format: "Per 100g - Calories: 250kcal")
- 30-second timeout, manual entry fallback

## Testing Strategy

- **Unit Tests**: Specific examples, edge cases, error conditions
- **Property Tests**: 100+ iterations per property, tagged with feature and property number
- **Coverage**: 90%+ for business logic, 100% for error handling

## Error Handling

- API: 30s timeout, retry option, manual fallback
- Validation: Reject negative calories, validate required fields
- Persistence: Retry logic, backup fallback, user notification

## Development Workflow

### Adding Features
1. Update requirements with user stories
2. Define correctness properties in design
3. Implement with error handling
4. Document all public APIs
5. Write unit + property tests
6. Verify 90%+ coverage
7. Update docs

### Debugging
1. Use getDiagnostics tool
2. Review error logs
3. Verify date normalization
4. Show full command output (no tail/grep)
5. Document root cause

### Testing
1. Run unit tests
2. Run property tests (100+ iterations)
3. Verify all properties pass
4. Test offline scenarios
5. Document coverage gaps

## Project Structure

```
CountMe/
├── Models/              # Data models (FoodItem, DailyLog, CustomMeal, etc.)
├── Views/               # SwiftUI views
├── Services/            # Business logic (DataStore, FirebaseAuthService, etc.)
├── Utilities/           # Helpers (Config, Secrets)
├── CountMeApp.swift     # App entry point

CountMeTests/
├── Models/              # Model tests
├── Services/            # Service tests
├── Views/               # View tests
├── Utilities/           # Utility tests

.kiro/
├── specs/               # Feature specs (requirements.md, design.md, tasks.md)
├── settings/            # MCP config
└── steering/            # Project guidelines
```

## Import Rules

Swift uses module-based imports. Moving files within the CountMe target does NOT require import changes. Reorganize freely without updating imports.

## Common Tasks

- **Add Food**: Validate calories (non-negative) → Create FoodItem → Add to DailyLog → Persist via DataStore
- **Search API**: Generate OAuth signature → Call endpoint → Parse response → Map to FoodItem
- **Daily Log**: Normalize date → Fetch/create DailyLog → Load FoodItems → Calculate total
- **Sign Out**: Stop sync listeners → Reset sync status (clear userId, set pendingUpload) → Retain local data

## Notes

- Always normalize dates before daily log operations
- Use DataStore actor for all persistence
- Validate API responses before parsing
- Implement unit + property tests
- 90-day retention for daily logs only
- Handle offline gracefully
- Manual entry fallback for API failures
- Never truncate console output during testing
- Target device: iPhone 17
