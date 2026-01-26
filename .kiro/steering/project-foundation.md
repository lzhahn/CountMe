# CountMe Project Foundation

## Project Overview

CountMe is an iOS calorie tracking application built with SwiftUI and SwiftData. The app helps users monitor daily caloric intake by integrating with the FatSecret Platform API for nutritional data while maintaining local persistence for offline access and historical tracking.

## Technology Stack

- **Platform**: iOS (SwiftUI)
- **Persistence**: SwiftData
- **API Integration**: FatSecret Platform API (OAuth 1.0)
- **Architecture**: MVVM with clear separation of concerns
- **Testing**: Swift Testing framework with property-based testing

## MCP Tooling Configuration

The project uses four MCP servers to enhance development workflow:

### 1. Playwright (`@playwright/mcp@latest`)
- **Purpose**: Browser automation and web scraping
- **Use Cases**: Testing web-based nutrition API documentation, E2E testing of web views
- **Command**: `npx @playwright/mcp@latest`

### 2. Memory (`@modelcontextprotocol/server-memory`)
- **Purpose**: Persistent memory storage across conversations
- **Use Cases**: Maintaining context about project decisions, API integration details, testing strategies
- **Command**: `npx -y @modelcontextprotocol/server-memory`

### 3. Sequential Thinking (`@modelcontextprotocol/server-sequential-thinking`)
- **Purpose**: Enhanced reasoning through step-by-step documentation
- **Use Cases**: Complex problem solving, architectural decisions, debugging multi-step issues
- **Command**: `npx -y @modelcontextprotocol/server-sequential-thinking`

### 4. Context7 (`@upstash/context7-mcp`)
- **Purpose**: Semantic search and knowledge retrieval from Upstash vector database
- **Use Cases**: Finding relevant code patterns, searching documentation, retrieving project context
- **Command**: `npx -y @upstash/context7-mcp`

## Core Architecture Patterns

### Data Flow
```
SwiftUI Views → View Models → Business Logic → Data Store (SwiftData)
                                            → API Client (FatSecret)
```

### Key Components

**Data Models** (`CountMe/Models/`):
- `FoodItem.swift`: Individual food entries with nutritional data
- `DailyLog.swift`: Container for a day's food items with goal tracking
- `NutritionSearchResult.swift`: API response mapping
- `FoodItemSource.swift`: Enum for tracking data origin (API vs manual)
- `CustomMeal.swift`: Custom meal definitions
- `Ingredient.swift`: Ingredient data for custom meals

**Services** (`CountMe/Services/`):
- `DataStore.swift`: Actor-based SwiftData persistence layer
- `NutritionAPIClient.swift`: FatSecret API integration
- `OAuth1SignatureGenerator.swift`: FatSecret API authentication
- `CalorieTracker.swift`: Business logic for calorie calculations

**Views** (`CountMe/Views/`):
- `ContentView.swift`: Main application view
- `MainCalorieView.swift`: Primary calorie tracking interface
- `FoodSearchView.swift`: API search interface
- `ManualEntryView.swift`: Manual food entry form
- `ServingAdjustmentView.swift`: Serving size adjustment UI
- `FoodItemRow.swift`: Individual food item display component
- `SearchResultRow.swift`: Search result display component
- `GoalSettingView.swift`: Daily calorie goal configuration
- `HistoricalView.swift`: Historical data viewing interface

**Utilities** (`CountMe/Utilities/`):
- `Config.swift`: Application configuration management
- `Secrets.swift`: API credentials and sensitive data

**App Entry**:
- `CountMeApp.swift`: Application entry point (root level)

## FatSecret API Integration

### Authentication
- **Method**: OAuth 1.0 signature-based
- **Requirements**: Consumer Key and Consumer Secret
- **Signature**: Each request signed with timestamp and nonce

### Key Endpoints
- `foods.search`: Search for foods by name
- `food.get.v2`: Get detailed nutrition information

### Response Handling
- Parse `foodDescription` for calorie extraction (format: "Per 100g - Calories: 250kcal")
- Handle multiple serving options
- Convert string values to Double
- Graceful fallback for missing/invalid data

## Testing Strategy

### Dual Approach
1. **Unit Tests**: Specific examples, edge cases, error conditions
2. **Property-Based Tests**: Universal properties with 100+ iterations

### Property Test Configuration
- Minimum 100 iterations per property
- Tag format: `Feature: calorie-tracking, Property {N}: {description}`
- Random seed logging for reproducibility
- Shrinking enabled for minimal failing cases

### Coverage Goals
- 90%+ code coverage for business logic
- 100% coverage of error handling paths
- All 15 correctness properties implemented
- Integration tests for API and data store

## Data Persistence Rules

### Date Normalization
- All dates normalized to midnight (start of day) in current timezone
- Ensures consistent daily log retrieval
- Implemented in `DataStore.normalizeDate()`

### SwiftData Schema
- One-to-many: DailyLog → FoodItems
- Cascade delete: removing DailyLog removes associated FoodItems
- Retention: 90 days of historical data
- Automatic persistence on changes

### Actor-Based Concurrency
- `DataStore` is an actor for thread-safe operations
- All mutations go through DataStore methods
- Async/await for all persistence operations

## Error Handling Patterns

### API Errors
- Network failures: 30-second timeout, retry option, manual entry fallback
- Invalid responses: Validation before parsing, specific error messages
- Rate limiting: Exponential backoff, request queuing

### Data Validation
- Reject negative calorie values
- Validate all required fields before save
- Display field-specific error messages

### Persistence Errors
- Catch SwiftData errors with retry logic
- Data corruption recovery with backup fallback
- User notification for data loss scenarios

## Development Workflow

### When Adding Features
1. Update requirements document with user stories and acceptance criteria
2. Define correctness properties in design document
3. Update architecture diagrams if needed
4. Implement with error handling
5. **Document all public APIs, parameters, return values, and usage examples**
6. Write both unit and property-based tests
7. Verify 90%+ code coverage
8. **Update relevant documentation (README, inline comments, architecture notes)**

### When Debugging
1. Check diagnostics with getDiagnostics tool
2. Review error logs for API/persistence issues
3. Verify date normalization for daily log issues
4. Use sequential-thinking MCP for complex problems
5. **Never use grep or tail to filter logs** - these commands can hide valuable debugging information
6. **Document the root cause and solution for future reference**

### When Testing
1. Run unit tests for specific scenarios
2. Run property tests with 100+ iterations
3. Verify all 15 correctness properties pass
4. Check integration with FatSecret API
5. Test offline scenarios and data recovery
6. **Document test coverage gaps and edge cases discovered**

### When Executing Bulk Tasks
**For large task lists create new sessions to maintain clarity:**

1. **Break work into logical chunks** - Group related tasks (e.g., all model changes, all view updates)
2. **Start fresh sessions for each chunk** - Prevents context bloat and token limit issues
3. **Document progress between sessions** - Update task lists with completion status
4. **Reference previous work explicitly** - Link to completed files or decisions from prior sessions
5. **Use Memory MCP to persist context** - Store architectural decisions and implementation notes across sessions

**When to create a new session:**
- Implementing 5+ tasks from a task list
- Working across 10+ files
- Switching between major feature areas (Models → Views → Services)
- After completing a logical milestone (all tests passing, feature complete)
- When context becomes cluttered with debugging output or test results

**Benefits:**
- Cleaner context for better decision-making
- Faster response times with smaller context windows
- Easier to track progress and identify issues
- Reduced risk of token limit errors mid-implementation

## Code Style Guidelines

### Swift Conventions
- Use actors for shared mutable state
- Async/await for asynchronous operations
- SwiftUI @Observable for view models
- Descriptive variable names
- Comprehensive error handling

### Documentation Standards

**Required for All Public APIs**:
- Purpose and responsibility summary
- Parameter descriptions with types and constraints
- Return value description and possible states
- Thrown errors and error conditions
- Usage examples for non-trivial functions
- Thread-safety notes for concurrent code

**Code Comments**:
- Explain "why" not "what" (code shows what)
- Document non-obvious business logic
- Note performance considerations
- Reference related functions/types
- Include links to external documentation (API docs, RFCs)

**Module Documentation**:
- README.md for complex feature folders
- Architecture overview for multi-file features
- Integration points and dependencies
- Known limitations and future improvements

## Project Structure Reference

```
CountMe/
├── Assets.xcassets/     # App assets and resources
├── Models/              # Data models
│   ├── CustomMeal.swift
│   ├── DailyLog.swift
│   ├── FoodItem.swift
│   ├── FoodItemSource.swift
│   ├── Ingredient.swift
│   └── NutritionSearchResult.swift
├── Views/               # SwiftUI views
│   ├── ContentView.swift
│   ├── FoodItemRow.swift
│   ├── FoodSearchView.swift
│   ├── GoalSettingView.swift
│   ├── HistoricalView.swift
│   ├── MainCalorieView.swift
│   ├── ManualEntryView.swift
│   ├── SearchResultRow.swift
│   └── ServingAdjustmentView.swift
├── Services/            # Business logic and API clients
│   ├── CalorieTracker.swift
│   ├── DataStore.swift
│   ├── NutritionAPIClient.swift
│   └── OAuth1SignatureGenerator.swift
├── Utilities/           # Helper functions and configuration
│   ├── Config.swift
│   └── Secrets.swift
├── CountMeApp.swift     # App entry point
└── Item.swift           # Legacy file

CountMeTests/
├── Models/              # Model tests (mirror source structure)
│   └── FoodItemMacroTests.swift
├── Services/            # Service tests
│   ├── NutritionAPIClientTests.swift
│   └── OAuth1SignatureGeneratorTests.swift
├── Views/               # View tests
│   └── CoreUIFlowsTests.swift
├── CountMeTests.swift   # General test utilities
└── CrashRecoveryTests.swift  # Integration tests

.kiro/
├── specs/               # Feature specifications (one folder per feature)
│   ├── calorie-tracking/
│   │   ├── requirements.md      # User stories & acceptance criteria
│   │   ├── design.md           # Architecture & correctness properties
│   │   └── tasks.md            # Implementation tasks
│   ├── ai-recipe-tracking/
│   └── file-structure-refactor/
├── settings/
│   └── mcp.json            # MCP server configuration
└── steering/               # Project guidelines (this file)
```

### Import Statements

**Important**: Swift uses module-based imports, not file path imports. All files in the CountMe target are part of the same module, so moving files within the target does NOT require import statement changes.

Example:
```swift
// Before refactoring: CountMe/DataStore.swift
import SwiftData

// After refactoring: CountMe/Services/DataStore.swift
import SwiftData  // No changes needed!

// Other files importing DataStore - NO CHANGES NEEDED
// The import is module-based, not path-based
```

This means you can reorganize files freely within the CountMe module without updating any import statements in your code.

### Folder Organization Principles

**Group by Feature, Then by Type**:
- Related functionality lives in the same folder
- Mirror folder structure between source and tests
- Keep folder depth shallow (max 3 levels)

**Clear Naming Conventions**:
- Folders use PascalCase for types (Models, Views)
- Feature folders use kebab-case (calorie-tracking)
- Group files by domain (nutrition, logging, goals)

**Documentation Location**:
- Inline documentation for all public APIs
- README.md in feature folders for complex modules
- Architecture diagrams in .kiro/specs/
- API integration notes with the client code

## Key Correctness Properties

The design document defines 15 correctness properties that must hold true. Key examples:

- **Property 2**: Daily total always equals sum of all food item calories
- **Property 3**: Persistence round-trip preserves all data
- **Property 13**: All calorie values must be non-negative
- **Property 14**: All required fields must be present and valid

Refer to `#[[file:.kiro/specs/calorie-tracking/design.md]]` for complete property definitions.

## Common Tasks

### Adding a Food Item
1. Validate calorie value (non-negative)
2. Create FoodItem with timestamp
3. Add to current DailyLog
4. Persist through DataStore
5. Update UI with new total
6. **Document any validation rules or business logic**

### Searching Nutrition API
1. Generate OAuth 1.0 signature
2. Call foods.search endpoint
3. Parse response to NutritionSearchResult
4. Handle errors with manual entry fallback
5. Map selected result to FoodItem
6. **Document API response format and parsing logic**

### Daily Log Transition
1. Normalize date to midnight
2. Fetch or create DailyLog for date
3. Load associated FoodItems
4. Calculate and display total
5. Show goal progress if set
6. **Document date handling edge cases**

### Creating New Features
1. Create feature folder in appropriate location
2. Add README.md explaining feature purpose
3. Implement models in Models/ subfolder
4. Implement views in Views/ subfolder
5. Implement business logic in Services/ subfolder
6. **Document all public interfaces thoroughly**
7. Mirror structure in test folder
8. Update architecture documentation

## Important Notes

- Always normalize dates before daily log operations
- Use DataStore actor for all persistence operations
- Validate API responses before parsing
- Implement both unit and property-based tests
- Maintain 90-day historical data retention
- Handle offline scenarios gracefully
- Provide manual entry fallback for API failures
- Never truncate console testing as it can stifle your understanding of a solution 
