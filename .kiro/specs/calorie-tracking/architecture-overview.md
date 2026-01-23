# Architecture Overview: Calorie Tracking Feature

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ MainCalorie  │  │ FoodSearch   │  │ FoodItemRow  │      │
│  │    View      │  │    View      │  │ SearchResult │      │
│  │              │  │              │  │     Row      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘      │
│         │                 │                                  │
└─────────┼─────────────────┼──────────────────────────────────┘
          │                 │
          └────────┬────────┘
                   │
┌──────────────────┼──────────────────────────────────────────┐
│                  │      Business Logic Layer                 │
│         ┌────────▼────────┐                                 │
│         │ CalorieTracker  │                                 │
│         │   @Observable   │                                 │
│         │   @MainActor    │                                 │
│         └────┬──────┬─────┘                                 │
│              │      │                                        │
└──────────────┼──────┼────────────────────────────────────────┘
               │      │
        ┌──────┘      └──────┐
        │                    │
┌───────▼────────┐  ┌────────▼──────────┐
│  Data Access   │  │   API Access      │
│     Layer      │  │     Layer         │
│                │  │                   │
│  ┌──────────┐ │  │ ┌───────────────┐ │
│  │DataStore │ │  │ │ NutritionAPI  │ │
│  │  (Actor) │ │  │ │    Client     │ │
│  │          │ │  │ │   (Actor)     │ │
│  └────┬─────┘ │  │ └───────┬───────┘ │
│       │       │  │         │         │
└───────┼───────┘  └─────────┼─────────┘
        │                    │
        │                    │
┌───────▼────────┐  ┌────────▼──────────┐
│   SwiftData    │  │  FatSecret API    │
│  (Local DB)    │  │  (OAuth 1.0)      │
└────────────────┘  └───────────────────┘
```

## Layer Responsibilities

### Presentation Layer (SwiftUI Views)

**Purpose**: User interface and interaction handling

**Components**:
- `MainCalorieView`: Primary dashboard showing daily progress
- `FoodSearchView`: Search interface with debounced queries
- `SearchResultRow`: Reusable search result display
- `FoodItemRow`: Reusable logged item display

**Responsibilities**:
- Render UI based on state
- Handle user gestures and input
- Display loading and error states
- Navigate between screens
- Format data for display

**Rules**:
- No direct data access (use CalorieTracker)
- No business logic (delegate to CalorieTracker)
- Must be MainActor-isolated
- Use @Bindable for CalorieTracker

---

### Business Logic Layer

**Purpose**: Coordinate operations and enforce business rules

**Components**:
- `CalorieTracker`: Observable coordinator class

**Responsibilities**:
- Manage application state (currentLog, selectedDate)
- Coordinate between views, data store, and API
- Enforce business rules (positive goals, valid dates)
- Handle errors and provide user-friendly messages
- Calculate derived values (totals, remaining calories)

**Rules**:
- Must be @MainActor for UI updates
- Must be @Observable for SwiftUI reactivity
- All operations are async/await
- Errors are caught and converted to user messages

---

### Data Access Layer

**Purpose**: Persist and retrieve data from local storage

**Components**:
- `DataStore`: Actor for thread-safe persistence

**Responsibilities**:
- CRUD operations for DailyLog and FoodItem
- Date normalization (to midnight)
- Query historical data
- Ensure data consistency

**Rules**:
- Must be an actor for thread safety
- All operations are async
- Dates normalized before storage
- Automatic persistence on changes

**Data Models**:
- `DailyLog`: @Model class with computed properties
- `FoodItem`: @Model class with nutritional data
- `FoodItemSource`: Enum tracking data origin

---

### API Access Layer

**Purpose**: Communicate with external nutrition API

**Components**:
- `NutritionAPIClient`: Actor for thread-safe API calls
- `OAuth1SignatureGenerator`: OAuth 1.0 signing

**Responsibilities**:
- Search food database
- Parse API responses
- Handle authentication (OAuth 1.0)
- Manage network errors and timeouts
- Rate limiting and retry logic

**Rules**:
- Must be an actor for thread safety
- 30-second timeout on requests
- Graceful error handling
- Returns domain models (NutritionSearchResult)

**Data Models**:
- `NutritionSearchResult`: API response representation
- `NutritionAPIError`: Typed error cases

---

## Data Flow

### Adding Food from Search

```
1. User types in FoodSearchView
   ↓
2. Debounce (500ms) triggers search
   ↓
3. FoodSearchView calls tracker.searchFood(query:)
   ↓
4. CalorieTracker calls apiClient.searchFood(query:)
   ↓
5. NutritionAPIClient makes OAuth-signed request
   ↓
6. API returns results
   ↓
7. NutritionAPIClient parses to NutritionSearchResult[]
   ↓
8. CalorieTracker returns results
   ↓
9. FoodSearchView displays SearchResultRow for each
   ↓
10. User taps result
   ↓
11. FoodSearchView creates FoodItem from result
   ↓
12. FoodSearchView calls tracker.addFoodItem(item)
   ↓
13. CalorieTracker adds to currentLog.foodItems
   ↓
14. CalorieTracker calls dataStore.saveDailyLog(log)
   ↓
15. DataStore persists to SwiftData
   ↓
16. CalorieTracker updates currentLog (triggers UI update)
   ↓
17. FoodSearchView dismisses
   ↓
18. MainCalorieView shows updated total
```

### Loading Daily Log

```
1. MainCalorieView appears
   ↓
2. Calls tracker.loadLog(for: Date())
   ↓
3. CalorieTracker sets isLoading = true
   ↓
4. CalorieTracker calls dataStore.fetchDailyLog(for:)
   ↓
5. DataStore normalizes date to midnight
   ↓
6. DataStore queries SwiftData with predicate
   ↓
7. If found: returns existing DailyLog
   If not: creates new DailyLog and saves
   ↓
8. CalorieTracker sets currentLog
   ↓
9. CalorieTracker sets isLoading = false
   ↓
10. MainCalorieView updates UI with log data
```

---

## Concurrency Model

### Actor Isolation

**DataStore (Actor)**:
- All methods are async
- Ensures thread-safe access to ModelContext
- Prevents data races during persistence

**NutritionAPIClient (Actor)**:
- All methods are async
- Ensures thread-safe network operations
- Prevents concurrent API requests

**CalorieTracker (@MainActor)**:
- All properties and methods on main thread
- Enables direct UI updates via @Observable
- Coordinates async operations with actors

### Threading Rules

1. **UI Updates**: Always on MainActor (CalorieTracker)
2. **Data Access**: Always through DataStore actor
3. **API Calls**: Always through NutritionAPIClient actor
4. **View Code**: Implicitly MainActor (SwiftUI)

### Async/Await Patterns

```swift
// View calls business logic
Task {
    try await tracker.addFoodItem(item)
}

// Business logic coordinates actors
func addFoodItem(_ item: FoodItem) async throws {
    guard let log = currentLog else { throw ... }
    log.foodItems.append(item)
    try await dataStore.saveDailyLog(log) // Actor call
    currentLog = log // MainActor update
}
```

---

## State Management

### CalorieTracker State

**Published Properties** (trigger UI updates):
- `currentLog: DailyLog?` - Current daily log
- `selectedDate: Date` - Date being viewed
- `isLoading: Bool` - Loading indicator
- `errorMessage: String?` - Error display

**State Transitions**:
```
Initial → Loading → Loaded → [Updating] → Updated
                  ↓
                Error → [Retry] → Loading
```

### View State

**FoodSearchView**:
- `searchQuery: String` - User input
- `searchResults: [NutritionSearchResult]` - API results
- `isSearching: Bool` - Loading state
- `errorMessage: String?` - Error state
- `searchTask: Task?` - Debounce task

**State Machine**:
```
Empty → Typing → Debouncing → Searching → Results
                                        ↓
                                      Error
```

---

## Error Handling Strategy

### Error Types

1. **Business Logic Errors** (CalorieTrackerError):
   - `noCurrentLog`: No log loaded
   - `invalidGoal`: Invalid goal value

2. **API Errors** (NutritionAPIError):
   - `networkError`: Network failure
   - `timeout`: Request timeout
   - `rateLimitExceeded`: Too many requests
   - `invalidResponse`: Bad HTTP response
   - `invalidData`: Parse failure

3. **Persistence Errors** (SwiftData):
   - Caught and wrapped in user-friendly messages

### Error Flow

```
Error Occurs
    ↓
Actor/Function throws
    ↓
CalorieTracker catches
    ↓
Sets errorMessage property
    ↓
View displays error
    ↓
User can retry or dismiss
```

### User Experience

- **Network Errors**: Show retry button
- **Validation Errors**: Highlight invalid fields
- **Persistence Errors**: Offer to retry save
- **API Errors**: Suggest manual entry fallback

---

## Testing Strategy

### Unit Tests

**Business Logic**:
- Test CalorieTracker methods in isolation
- Mock DataStore and NutritionAPIClient
- Verify state transitions
- Test error handling

**Data Access**:
- Test DataStore with in-memory container
- Verify date normalization
- Test CRUD operations
- Test query predicates

**API Client**:
- Test with mock URLSession
- Verify OAuth signature generation
- Test response parsing
- Test error scenarios

### Integration Tests

**End-to-End Flows**:
- Search → Select → Add → Display
- Load → Display → Delete → Update
- Error → Retry → Success

### Property-Based Tests

**Invariants**:
- Daily total always equals sum of items
- Remaining calories = goal - total
- Date normalization is idempotent
- Search results match query

---

## Performance Considerations

### Debouncing

- Search debounced to 500ms
- Prevents excessive API calls
- Cancels previous search tasks
- Improves user experience

### Caching

- SwiftData provides automatic caching
- No manual cache management needed
- In-memory objects for current session

### Lazy Loading

- Food items loaded with daily log
- No pagination needed (single day)
- Historical data loaded on demand

### Network Optimization

- Single API call per search
- No prefetching
- Timeout after 30 seconds
- Graceful degradation on failure

---

## Security Considerations

### API Credentials

- Stored in Config.local.xcconfig (gitignored)
- Never hardcoded in source
- OAuth 1.0 signature per request
- No credentials in logs

### Data Privacy

- All data stored locally
- No cloud sync (MVP)
- No analytics or tracking
- User data never leaves device

### Input Validation

- Calorie values must be non-negative
- Goals must be positive
- Dates normalized to prevent duplicates
- Query strings sanitized before API call

---

## Future Enhancements

### Planned Features

1. **Manual Entry View** (Task 8)
   - Text fields for name and calories
   - Optional serving size/unit
   - Input validation

2. **Historical View** (Task 10)
   - Date picker navigation
   - Daily summaries
   - Trend visualization

3. **Goal Setting View** (Task 11)
   - Persistent goal management
   - Goal history
   - Recommendations

### Architectural Improvements

1. **Offline Support**:
   - Cache search results
   - Queue failed operations
   - Sync when online

2. **Performance**:
   - Pagination for large lists
   - Image caching for food photos
   - Background data refresh

3. **Testing**:
   - Increase property test coverage
   - Add UI tests
   - Performance benchmarks

---

## Dependencies

### External

- **SwiftUI**: UI framework
- **SwiftData**: Persistence framework
- **Foundation**: Core utilities
- **FatSecret API**: Nutrition data source

### Internal

- **OAuth1SignatureGenerator**: Authentication
- **Config**: API credentials management

### Version Requirements

- iOS 17.0+ (SwiftData requirement)
- Xcode 15.0+
- Swift 5.9+

---

## Deployment Considerations

### Build Configuration

- Debug: Uses Config.local.xcconfig
- Release: Uses environment variables
- TestFlight: Requires secrets in Xcode Cloud

### API Rate Limits

- FatSecret: Check current plan limits
- Implement exponential backoff
- Show user-friendly messages

### Data Migration

- SwiftData handles schema migrations
- No manual migration needed (MVP)
- Future: Add migration tests

---

## Maintenance

### Code Organization

```
CountMe/
├── Models/              # Data models
│   ├── DailyLog.swift
│   ├── FoodItem.swift
│   ├── FoodItemSource.swift
│   └── NutritionSearchResult.swift
├── Views/               # UI components
│   ├── MainCalorieView.swift
│   ├── FoodSearchView.swift
│   ├── SearchResultRow.swift
│   └── FoodItemRow.swift
├── CalorieTracker.swift # Business logic
├── DataStore.swift      # Persistence
└── NutritionAPIClient.swift # API access
```

### Documentation

- Inline comments for complex logic
- API documentation in specs folder
- Architecture overview (this document)
- README for setup instructions

### Monitoring

- No crash reporting (MVP)
- No analytics (MVP)
- Future: Add logging framework
- Future: Add error tracking
