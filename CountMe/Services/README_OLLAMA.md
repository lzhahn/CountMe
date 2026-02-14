# AIRecipeParser - Google Gemini Setup

The AIRecipeParser uses Google's Gemini API for AI-powered recipe parsing. It extracts structured ingredient and nutritional data from natural language recipe descriptions.

## Prerequisites

1. Get a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
2. Add your key to `CountMe/Utilities/Secrets.swift`:
   ```swift
   static let googleGeminiAPIKey = "YOUR_KEY_HERE"
   ```

## Usage

```swift
let parser = AIRecipeParser()
let result = try await parser.parseRecipe(description: "chicken stir fry with rice and broccoli")
```

## Configuration

You can customize the model:

```swift
let parser = AIRecipeParser(
    apiKey: "your-api-key",
    modelName: "gemini-2.0-flash"
)
```

## Supported Models

- `gemini-2.0-flash` (default): Fast and accurate
- `gemini-2.5-flash`: Latest, best quality/speed tradeoff
- `gemini-2.5-pro`: Most capable, slower

## Troubleshooting

- **401 Unauthorized**: Check your API key in Secrets.swift
- **429 Rate Limited**: You've exceeded the free tier quota. Wait or upgrade your plan
- **Inaccurate parsing**: Try `gemini-2.5-pro` for better nutrition estimates
