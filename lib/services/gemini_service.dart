import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model representing the educational analysis from Gemini
class GeminiAnalysis {
  final String explanation;
  final List<String> suspiciousElements;
  final List<String> safetyTips;
  final String reasoning;

  const GeminiAnalysis({
    required this.explanation,
    required this.suspiciousElements,
    required this.safetyTips,
    required this.reasoning,
  });

  factory GeminiAnalysis.fromJson(Map<String, dynamic> json) {
    return GeminiAnalysis(
      explanation: json['explanation'] as String? ?? '',
      suspiciousElements:
          (json['suspicious_elements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      safetyTips:
          (json['safety_tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reasoning: json['reasoning'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'explanation': explanation,
      'suspicious_elements': suspiciousElements,
      'safety_tips': safetyTips,
      'reasoning': reasoning,
    };
  }
}

/// Service for interacting with Google Gemini API
class GeminiService {
  GeminiService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  // API endpoint - will be configured with API key
  static const String _apiBaseUrl =
      'https://generativelanguage.googleapis.com/v1/models/';
  static const String _defaultModel = 'gemini-2.5-flash';

  /// Analyzes a message or URL and provides educational feedback
  ///
  /// Parameters:
  /// - [content]: The message text or URL to analyze
  /// - [isPhishing]: Whether the content was detected as phishing
  /// - [confidence]: The confidence score of the phishing detection
  /// - [isUrl]: Whether the content is a URL (vs text message)
  /// - [apiKey]: The Gemini API key (can also be set via environment variable)
  Future<GeminiAnalysis> analyzeContent({
    required String content,
    required bool isPhishing,
    required double confidence,
    required bool isUrl,
    String? apiKey,
  }) async {
    // Get API key from parameter or environment variable
    final String key =
        apiKey ??
        const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

    debugPrint(
      '🔑 API Key loaded: ${key.isEmpty ? "NO" : "YES (${key.length} chars)"}',
    );

    if (key.isEmpty) {
      throw Exception(
        'Gemini API key not provided. Set GEMINI_API_KEY environment variable or pass apiKey parameter.',
      );
    }

    // Build the prompt for Gemini
    final String prompt = _buildPrompt(
      content: content,
      isPhishing: isPhishing,
      confidence: confidence,
      isUrl: isUrl,
    );

    // Construct the API URL
    final Uri url = Uri.parse(
      '$_apiBaseUrl$_defaultModel:generateContent?key=$key',
    );

    debugPrint('🌐 Calling: $_apiBaseUrl$_defaultModel:generateContent');

    // Prepare the request body
    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 8192, // Increased for gemini-2.5-flash
      },
    };

    try {
      debugPrint('📤 Sending request to Gemini API...');
      final http.Response response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 Gemini API response: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ API Error Body: ${response.body}');
        throw Exception(
          'Gemini API error: ${response.statusCode} - ${response.body}',
        );
      }

      final dynamic jsonResponse = jsonDecode(response.body);
      debugPrint('✓ Response parsed successfully');

      // Extract the generated text from Gemini's response
      final String generatedText = _extractGeneratedText(jsonResponse);
      debugPrint('✓ Generated text extracted (${generatedText.length} chars)');

      // Parse the structured response
      final GeminiAnalysis analysis = _parseGeminiResponse(
        generatedText,
        isPhishing,
      );
      debugPrint(
        '✓ Analysis parsed: ${analysis.explanation.substring(0, 50)}...',
      );
      return analysis;
    } catch (e) {
      debugPrint('❌ Full error: $e');
      throw Exception('Failed to analyze content with Gemini: $e');
    }
  }

  /// Builds the prompt for Gemini based on the scan results
  String _buildPrompt({
    required String content,
    required bool isPhishing,
    required double confidence,
    required bool isUrl,
  }) {
    final String contentType = isUrl ? 'URL' : 'message';
    final String verdict = isPhishing ? 'phishing' : 'legitimate';
    final String confidencePercent = (confidence * 100).toStringAsFixed(1);

    return '''
You are a cybersecurity education assistant. A $contentType has been scanned and detected as $verdict with $confidencePercent% confidence.

${isUrl ? 'URL' : 'Message Content'}:
$content

Please provide educational feedback to help the user understand this result. Your response should be structured as follows:

1. EXPLANATION: A brief, clear explanation (2-3 sentences) of why this $contentType is $verdict.

2. KEY INDICATORS: List 3-5 specific suspicious elements found (if phishing) or positive signs (if legitimate). Be specific to the content provided.

3. SAFETY TIPS: Provide 3-4 actionable safety tips related to this type of ${isPhishing ? 'threat' : 'content'}.

4. REASONING: A more detailed educational explanation (3-4 sentences) about the techniques used ${isPhishing ? 'by attackers in this type of phishing attempt' : 'to verify this is legitimate'}.

Format your response as JSON with these exact keys:
{
  "explanation": "brief explanation here",
  "suspicious_elements": ["element 1", "element 2", "element 3"],
  "safety_tips": ["tip 1", "tip 2", "tip 3"],
  "reasoning": "detailed reasoning here"
}

Important:
- Be specific to the actual content provided
- Use clear, non-technical language
- Focus on educating the user
- Keep each point concise but informative
- Return ONLY the JSON, no additional text
''';
  }

  /// Extracts the generated text from Gemini's API response
  String _extractGeneratedText(dynamic jsonResponse) {
    debugPrint('🔍 Response structure: ${jsonResponse.runtimeType}');

    if (jsonResponse is Map<String, dynamic>) {
      debugPrint('📋 Response keys: ${jsonResponse.keys.toList()}');

      final List<dynamic>? candidates =
          jsonResponse['candidates'] as List<dynamic>?;
      debugPrint('✓ Candidates: ${candidates?.length ?? 0}');

      if (candidates != null && candidates.isNotEmpty) {
        final Map<String, dynamic> candidate =
            candidates[0] as Map<String, dynamic>;
        debugPrint('✓ Candidate keys: ${candidate.keys.toList()}');

        final Map<String, dynamic>? content =
            candidate['content'] as Map<String, dynamic>?;
        debugPrint('✓ Content: ${content != null}');

        if (content != null) {
          debugPrint('✓ Content keys: ${content.keys.toList()}');
          final List<dynamic>? parts = content['parts'] as List<dynamic>?;
          debugPrint('✓ Parts: ${parts?.length ?? 0}');

          if (parts != null && parts.isNotEmpty) {
            final Map<String, dynamic> part = parts[0] as Map<String, dynamic>;
            debugPrint('✓ Part keys: ${part.keys.toList()}');
            final String text = part['text'] as String? ?? '';
            debugPrint('✓ Text length: ${text.length}');
            return text;
          } else {
            // Handle case where parts is missing/empty but content exists
            debugPrint('⚠️ No parts found, checking for text field directly');
            if (content.containsKey('text')) {
              final String text = content['text'] as String? ?? '';
              debugPrint('✓ Text length: ${text.length}');
              return text;
            }
          }
        }
      } else {
        // Check if there's thinking content
        debugPrint('⚠️ No candidates or empty, checking alternative formats');
      }
    }

    debugPrint('❌ Failed to extract text. Full response: $jsonResponse');
    throw Exception('Unexpected response format from Gemini API');
  }

  /// Parses Gemini's response into a GeminiAnalysis object
  GeminiAnalysis _parseGeminiResponse(String generatedText, bool isPhishing) {
    try {
      // Try to extract JSON from the response
      String jsonText = generatedText.trim();
      debugPrint(
        '🔍 Parsing generated text (first 200 chars): ${jsonText.substring(0, jsonText.length > 200 ? 200 : jsonText.length)}',
      );

      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }

      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }

      jsonText = jsonText.trim();

      final Map<String, dynamic> parsed =
          jsonDecode(jsonText) as Map<String, dynamic>;
      debugPrint('✓ JSON parsed successfully');
      return GeminiAnalysis.fromJson(parsed);
    } catch (e) {
      // If parsing fails, return a fallback analysis
      debugPrint('⚠️ Parse error: $e - Using fallback analysis');
      debugPrint('Raw text was: $generatedText');
      return _getFallbackAnalysis(isPhishing);
    }
  }

  /// Provides fallback analysis if Gemini API fails or returns invalid data
  GeminiAnalysis _getFallbackAnalysis(bool isPhishing) {
    if (isPhishing) {
      return const GeminiAnalysis(
        explanation:
            'This content shows characteristics commonly associated with phishing attempts.',
        suspiciousElements: [
          'Urgency or pressure tactics',
          'Requests for sensitive information',
          'Suspicious links or domains',
          'Poor grammar or formatting',
        ],
        safetyTips: [
          'Never click on suspicious links',
          'Verify sender identity through official channels',
          'Look for signs of urgency or threats',
          'Report suspicious messages to authorities',
        ],
        reasoning:
            'Phishing attacks often use psychological manipulation to create urgency and fear. '
            'Attackers impersonate trusted entities to steal credentials or personal information. '
            'Always verify the authenticity of unexpected messages before taking any action.',
      );
    } else {
      return const GeminiAnalysis(
        explanation:
            'This content appears legitimate based on standard verification criteria.',
        suspiciousElements: [
          'Authentic domain or sender',
          'Professional formatting',
          'No requests for sensitive data',
          'Consistent branding',
        ],
        safetyTips: [
          'Still verify important requests independently',
          'Keep your security software updated',
          'Be cautious with any links or attachments',
          'When in doubt, contact the organization directly',
        ],
        reasoning:
            'While this content appears legitimate, always maintain healthy skepticism. '
            'Legitimate organizations have consistent branding and communication patterns. '
            'Even legitimate-looking messages can be sophisticated phishing attempts, so verify through official channels when dealing with sensitive matters.',
      );
    }
  }
}
