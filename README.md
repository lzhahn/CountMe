# CountMe

iOS calorie tracking app with FatSecret API integration.

## Features

### Food Search and Selection
- **Real-time Search**: Search the FatSecret nutrition database with automatic debouncing (500ms delay)
- **Detailed Results**: View food name, calories, serving size, and brand information
- **Quick Add**: Tap any search result to instantly add it to your daily log
- **Manual Entry**: Full-featured form for manually entering food items with validation
  - Required fields: food name and calories
  - Optional fields: serving size and unit
  - Input validation ensures data quality
  - Accessible from search view toolbar
- **Error Handling**: User-friendly error messages with retry options for network issues

### Daily Tracking
- **Visual Progress**: Circular progress indicator showing calories consumed vs. daily goal
- **Real-time Updates**: Daily total updates immediately when adding or removing items
- **Goal Management**: Set and track daily calorie goals with remaining calories display
- **Food History**: View all food items logged for the day with timestamps

### Data Persistence
- **Local Storage**: All data stored locally using SwiftData for offline access
- **Automatic Sync**: Changes persist immediately with no manual save required
- **90-Day History**: Historical data maintained for 90 days

## Setup

1. Copy `CountMe/Config.local.xcconfig` and add your FatSecret credentials:
   ```
   FATSECRET_CONSUMER_KEY = your_actual_key
   FATSECRET_CONSUMER_SECRET = your_actual_secret
   ```

2. In Xcode, link the config file:
   - Select CountMe project → Info tab
   - Under Configurations, set `Config.local` for Debug and Release

3. Build and run

## Architecture

### View Layer
- **MainCalorieView**: Primary view displaying daily totals, progress, and food list
- **FoodSearchView**: Search interface with debounced API queries and result display
- **ManualEntryView**: Form-based interface for manually entering food items with validation
- **SearchResultRow**: Reusable component for displaying nutrition search results
- **FoodItemRow**: Reusable component for displaying logged food items

### Business Logic
- **CalorieTracker**: Observable class coordinating between views, data store, and API client
- **DataStore**: Actor-based persistence layer using SwiftData
- **NutritionAPIClient**: Actor handling FatSecret API communication with OAuth 1.0

### Data Models
- **FoodItem**: Individual food entry with nutritional data (SwiftData model)
- **DailyLog**: Container for a day's food items with computed totals (SwiftData model)
- **NutritionSearchResult**: API response representation for search results

## Usage

### Searching for Food
1. Tap the + button in the main view
2. Type a food name in the search bar
3. Search triggers automatically after 500ms of no typing
4. Tap any result to add it to your daily log
5. Use "Manual Entry" button (pencil icon) in toolbar for custom entries

### Manual Food Entry
1. From the search view, tap the pencil icon in the toolbar
2. Enter the food name (required)
3. Enter the calorie amount (required, must be non-negative)
4. Optionally add serving size and unit
5. Tap "Save" to add to your daily log
6. Validation errors appear inline if inputs are invalid

### Managing Daily Log
- **Add Items**: Use search or manual entry
- **Delete Items**: Swipe left on any food item
- **Edit Items**: Tap on a food item (coming soon)
- **View Progress**: Check the circular indicator for goal progress

### Setting Goals
- Daily calorie goals can be set per day
- Remaining calories update automatically
- Visual feedback when goal is exceeded (red indicator)

## Deployment

For CI/CD or TestFlight, set these as environment variables or Xcode Cloud secrets:
- `FATSECRET_CONSUMER_KEY`
- `FATSECRET_CONSUMER_SECRET`
