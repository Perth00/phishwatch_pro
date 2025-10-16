# Gemini API Integration Guide

## Overview

PhishWatch Pro now integrates with Google's Gemini AI to provide educational feedback after scanning messages and URLs. This feature helps users understand why content is classified as phishing or legitimate, offering detailed explanations and safety tips.

## Features

- **Educational Explanations**: Clear explanations of why content is phishing or legitimate
- **Key Indicators**: Specific suspicious elements or positive signs identified in the content
- **Safety Tips**: Actionable advice to help users stay safe
- **Detailed Reasoning**: In-depth educational content about phishing techniques
- **Graceful Fallback**: App continues to work even if Gemini API is not configured

## Setup Instructions

### 1. Get a Gemini API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy your API key (it starts with "AI...")

### 2. Configure the API Key

You have two options to configure the API key:

#### Option A: Environment Variable (Recommended for Development)

Create a file named `env.json` in the project root (copy from `env.example.json`):

```json
{
  "HF_SPACE_URL": "",
  "HF_TEXT_SPACE_URL": "your-hf-space-url",
  "HF_URL_SPACE_URL": "your-hf-url-space-url",
  "HF_MODEL_ID": "Perth0603/phishing-email-mobilebert",
  "HF_API_TOKEN": "your-huggingface-token",
  "HF_URL_MODEL_ID": "Perth0603/Random-Forest-Model-for-PhishingDetection",
  "GEMINI_API_KEY": "your-gemini-api-key-here"
}
```

**Important**: This file is already in `.gitignore` to prevent accidentally committing your API keys.

#### Option B: Build-time Configuration

When building the app, pass the API key as a dart-define:

```bash
flutter run --dart-define=GEMINI_API_KEY=your-api-key-here
```

Or for release builds:

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your-api-key-here
```

### 3. Running the App

#### Development Mode

Using `env.json`:

```bash
flutter run --dart-define-from-file=env.json
```

#### Production Mode

For production builds, use secure environment variable management or build-time configuration:

```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

## How It Works

1. **User Scans Content**: User scans a message or URL
2. **Phishing Detection**: HuggingFace model analyzes and classifies the content
3. **Gemini Analysis**: Gemini AI provides educational feedback based on:
   - The content itself
   - Whether it was detected as phishing
   - The confidence level of the detection
4. **Display Results**: Educational feedback is shown in the scan result screen

## Architecture

### Services

- **`GeminiService`** (`lib/services/gemini_service.dart`): Handles communication with Gemini API
  - `analyzeContent()`: Analyzes content and returns educational feedback
  - Includes fallback analysis if API fails

### Models

- **`GeminiAnalysis`**: Data model containing:
  - `explanation`: Brief summary of why content is phishing/legitimate
  - `suspiciousElements`: List of key indicators
  - `safetyTips`: Actionable safety recommendations
  - `reasoning`: Detailed educational explanation

- **`ScanResultData`**: Updated to include optional `geminiAnalysis` field

### Widgets

- **`EducationalFeedbackCard`**: Displays Gemini analysis with:
  - Explanation section
  - Suspicious elements or positive indicators
  - Safety recommendations
  - Expandable "Learn More" section
  
- **`EducationalFeedbackLoading`**: Shows while analysis is in progress

- **`EducationalFeedbackError`**: Displays if analysis fails

## API Usage & Costs

### Gemini 1.5 Flash (Current Model)

- **Free Tier**: 15 requests per minute (RPM)
- **Cost**: Free for most usage, check [Google AI Pricing](https://ai.google.dev/pricing) for details
- **Rate Limits**: 15 RPM, 1 million TPM (tokens per minute)

### Best Practices

1. **Error Handling**: App gracefully handles API failures
2. **Non-Blocking**: Gemini analysis doesn't block scan results
3. **Fallback**: Basic explanations shown if Gemini unavailable
4. **Caching**: Consider implementing response caching for repeated scans

## Troubleshooting

### API Key Not Working

1. Verify your API key is valid at [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Check that the key is properly configured in `gemini.env.json`
3. Ensure you're running with `--dart-define-from-file=gemini.env.json`

### Rate Limiting

If you see rate limit errors:
- Free tier has 15 requests per minute
- Consider implementing request queuing or caching
- Upgrade to paid tier if needed

### No Educational Feedback Shown

This is expected behavior if:
- API key is not configured
- API request fails
- Network connectivity issues

The app will fall back to basic explanations automatically.

## Security Considerations

1. **Never commit API keys** to version control
2. **Use environment variables** in production
3. **Rotate keys regularly** if exposed
4. **Monitor usage** to detect unauthorized use
5. **Use Google Cloud Secret Manager** for production deployments

## Example Response

When a phishing message is scanned, Gemini provides:

```json
{
  "explanation": "This message shows classic phishing characteristics...",
  "suspicious_elements": [
    "Creates false urgency (24-hour deadline)",
    "Suspicious domain (securebank-verify.com)",
    "Requests sensitive information",
    "Threatens account suspension"
  ],
  "safety_tips": [
    "Never click links in suspicious emails",
    "Verify sender through official channels",
    "Look for spelling and grammar errors",
    "Report phishing attempts to IT"
  ],
  "reasoning": "Phishing attacks often create artificial urgency..."
}
```

## Future Enhancements

- [ ] Cache Gemini responses for similar content
- [ ] Implement request queuing for rate limiting
- [ ] Add user feedback to improve analysis quality
- [ ] Support multiple languages
- [ ] Integrate with Gemini Pro for more detailed analysis
- [ ] Add confidence scoring for Gemini analysis

## Support

For issues related to:
- **Gemini API**: Visit [Google AI Documentation](https://ai.google.dev/docs)
- **PhishWatch Pro**: Open an issue on GitHub
- **API Keys**: Check [Google AI Studio](https://makersuite.google.com/)

## References

- [Gemini API Documentation](https://ai.google.dev/docs)
- [Google AI Pricing](https://ai.google.dev/pricing)
- [API Key Management](https://ai.google.dev/gemini-api/docs/api-key)

