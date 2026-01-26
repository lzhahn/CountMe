# AIRecipeParser - Ollama Setup

The AIRecipeParser uses Ollama for local AI-powered recipe parsing. This provides privacy and offline capability without requiring external API keys.

## Prerequisites

1. **Install Ollama**: Download from [ollama.ai](https://ollama.ai)
   ```bash
   # macOS
   brew install ollama
   ```

2. **Pull the model**: The default model is `llama3.2`
   ```bash
   ollama pull llama3.2
   ```

3. **Start Ollama server**: 
   ```bash
   ollama serve
   ```
   The server runs on `http://localhost:11434` by default. The parser uses the `/api/generate` endpoint.

## Usage

The AIRecipeParser is configured to use Ollama by default:

```swift
let parser = AIRecipeParser()
let result = try await parser.parseRecipe(description: "chicken stir fry with rice and broccoli")
```

## Configuration

You can customize the endpoint and model:

```swift
let parser = AIRecipeParser(
    endpoint: URL(string: "http://localhost:11434/api/generate")!,
    modelName: "llama3.2"
)
```

## Recommended Models

- **llama3.2** (default): Good balance of speed and accuracy
- **llama3.1**: More accurate but slower
- **mistral**: Faster but less accurate for nutrition data

## Testing

The implementation includes comprehensive tests that use mock responses. To test with a real Ollama instance:

1. Ensure Ollama is running
2. Run the app and try the recipe parsing feature
3. Check the console for any errors

## Troubleshooting

**Connection refused**: Make sure Ollama is running (`ollama serve`)

**Model not found**: Pull the model first (`ollama pull llama3.2`)

**Slow responses**: Consider using a smaller model or increasing the timeout

**Inaccurate parsing**: Try a larger model like `llama3.1` or adjust the prompt
