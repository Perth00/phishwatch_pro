import 'dart:convert';

import 'package:http/http.dart' as http;

class HuggingFaceService {
  HuggingFaceService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  // Provide your model repo id, e.g. "Perth0603/phishing-email-mobilebert"
  static const String defaultModelId = 'Perth0603/phishing-email-mobilebert';

  Future<Map<String, dynamic>> classifyText({
    required String text,
    String? modelId,
    String? apiToken,
  }) async {
    // Optional Space override: prefer text-specific Space, then fallback to generic
    final String textSpaceUrl = const String.fromEnvironment(
      'HF_TEXT_SPACE_URL',
    );
    final String spaceUrl =
        textSpaceUrl.trim().isNotEmpty
            ? textSpaceUrl
            : const String.fromEnvironment('HF_SPACE_URL');
    if (spaceUrl.trim().isNotEmpty) {
      final Uri predictUrl = Uri.parse(
        spaceUrl.endsWith('/predict')
            ? spaceUrl
            : (spaceUrl.endsWith('/')
                ? (spaceUrl + 'predict')
                : (spaceUrl + '/predict')),
      );
      final Map<String, String> headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final Map<String, dynamic> body = <String, dynamic>{'inputs': text};
      final http.Response res = await _client.post(
        predictUrl,
        headers: headers,
        body: jsonEncode(body),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'Space API error: ' + res.statusCode.toString() + ' - ' + res.body,
        );
      }
      final dynamic j = jsonDecode(res.body);
      if (j is Map<String, dynamic> &&
          j.containsKey('label') &&
          j.containsKey('score')) {
        return <String, dynamic>{
          'label': j['label'],
          'score': (j['score'] as num).toDouble(),
        };
      }
      if (j is List) {
        return _parseBest(j);
      }
      throw Exception('Unexpected response from Space API');
    }

    final String envModelId = const String.fromEnvironment('HF_MODEL_ID');
    final String resolvedModelId =
        ((modelId ?? '').trim().isNotEmpty)
            ? (modelId ?? '').trim()
            : (envModelId.trim().isNotEmpty
                ? envModelId.trim()
                : defaultModelId);
    final String? token =
        apiToken ?? const String.fromEnvironment('HF_API_TOKEN');

    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ' + token,
    };

    final Map<String, dynamic> body = <String, dynamic>{'inputs': text};

    Future<http.Response> _postToModel(String model) {
      final Uri url = Uri.parse(
        'https://api-inference.huggingface.co/models/' +
            model +
            '?wait_for_model=true',
      );
      return _client.post(url, headers: headers, body: jsonEncode(body));
    }

    http.Response response = await _postToModel(resolvedModelId);

    // Fallbacks for potential slug case-sensitivity issues
    if (response.statusCode == 404 && resolvedModelId.contains('/')) {
      final int idx = resolvedModelId.indexOf('/');
      final String owner = resolvedModelId.substring(0, idx);
      final String repo = resolvedModelId.substring(idx + 1);
      final String alt1 =
          owner.toLowerCase() + '/' + repo; // lowercase owner only
      final String alt2 =
          (owner + '/' + repo).toLowerCase(); // lowercase entire slug

      final List<String> attempts = <String>[resolvedModelId, alt1, alt2];
      for (int i = 1; i < attempts.length; i++) {
        response = await _postToModel(attempts[i]);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          break; // success
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'HuggingFace API error: ' +
              response.statusCode.toString() +
              ' - ' +
              response.body +
              ' (tried: ' +
              resolvedModelId +
              ', ' +
              alt1 +
              ' and ' +
              alt2 +
              ')',
        );
      }
    } else if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HuggingFace API error: ' +
            response.statusCode.toString() +
            ' - ' +
            response.body +
            ' (model: ' +
            resolvedModelId +
            ')',
      );
    }

    final dynamic json = jsonDecode(response.body);
    // Typical text-classification output: [ [ {label: 'LABEL', score: 0.9}, ... ] ] or [ {label, score}, ... ]
    if (json is List) {
      if (json.isNotEmpty && json.first is List) {
        final List<dynamic> inner = json.first as List<dynamic>;
        return _parseBest(inner);
      }
      return _parseBest(json);
    }
    throw Exception('Unexpected response format from HuggingFace API');
  }

  Map<String, dynamic> _parseBest(List<dynamic> items) {
    double bestScore = -1;
    String bestLabel = 'UNKNOWN';
    for (final dynamic item in items) {
      if (item is Map<String, dynamic>) {
        final double score = (item['score'] as num?)?.toDouble() ?? -1;
        final String label = _normalizeLabel(
          (item['label'] as String?) ?? 'UNKNOWN',
        );
        if (score > bestScore) {
          bestScore = score;
          bestLabel = label;
        }
      }
    }
    return <String, dynamic>{'label': bestLabel, 'score': bestScore};
  }

  String _normalizeLabel(String label) {
    final String upper = label.trim().toUpperCase();
    if (upper == 'LABEL_0') return 'LEGIT';
    if (upper == 'LABEL_1') return 'PHISH';
    if (upper.contains('PHISH')) return 'PHISH';
    if (upper.contains('LEGIT')) return 'LEGIT';
    if (upper == 'HAM') return 'LEGIT';
    if (upper == 'SPAM') return 'PHISH';
    return upper;
  }

  /// Classify a URL using either a Space proxy endpoint or the Inference API
  /// for a URL-specific model. Returns a normalized `{ label, score }`.
  Future<Map<String, dynamic>> classifyUrl({
    required String url,
    String? modelId,
    String? apiToken,
  }) async {
    // Optional Space override: prefer URL-specific Space, then fallback to generic
    final String urlSpaceUrl = const String.fromEnvironment('HF_URL_SPACE_URL');
    final String spaceUrl =
        urlSpaceUrl.trim().isNotEmpty
            ? urlSpaceUrl
            : const String.fromEnvironment('HF_SPACE_URL');
    // If Space is provided, prefer dedicated /predict-url if available; fallback to /predict
    if (spaceUrl.trim().isNotEmpty) {
      final String base =
          spaceUrl.endsWith('/')
              ? spaceUrl.substring(0, spaceUrl.length - 1)
              : spaceUrl;
      final Uri predictUrl = Uri.parse(base + '/predict-url');
      final Map<String, String> headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final Map<String, dynamic> body = <String, dynamic>{'url': url};

      http.Response res = await _client.post(
        predictUrl,
        headers: headers,
        body: jsonEncode(body),
      );
      // Fallback to /predict with {inputs: url} if /predict-url is not implemented
      if (res.statusCode == 404) {
        final Uri fallback = Uri.parse(base + '/predict');
        res = await _client.post(
          fallback,
          headers: headers,
          body: jsonEncode(<String, dynamic>{'inputs': url}),
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'Space API error: ' + res.statusCode.toString() + ' - ' + res.body,
        );
      }
      final dynamic j = jsonDecode(res.body);
      if (j is Map<String, dynamic> &&
          j.containsKey('label') &&
          j.containsKey('score')) {
        return <String, dynamic>{
          'label': _normalizeLabel((j['label'] as String?) ?? 'UNKNOWN'),
          'score': (j['score'] as num).toDouble(),
        };
      }
      if (j is List) {
        return _parseBest(j);
      }
      throw Exception('Unexpected response from Space API');
    }

    // Hosted Inference API path (expects a text-classification model trained for URLs)
    final String envUrlModelId = const String.fromEnvironment(
      'HF_URL_MODEL_ID',
    );
    final String resolvedModelId =
        ((modelId ?? '').trim().isNotEmpty)
            ? (modelId ?? '').trim()
            : envUrlModelId.trim();
    if (resolvedModelId.isEmpty) {
      throw Exception(
        'URL model not configured. Provide HF_SPACE_URL or HF_URL_MODEL_ID, or pass modelId.',
      );
    }
    final String? token =
        apiToken ?? const String.fromEnvironment('HF_API_TOKEN');

    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ' + token,
    };
    final Map<String, dynamic> body = <String, dynamic>{'inputs': url};

    final Uri apiUrl = Uri.parse(
      'https://api-inference.huggingface.co/models/' +
          resolvedModelId +
          '?wait_for_model=true',
    );
    final http.Response response = await _client.post(
      apiUrl,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HuggingFace API error: ' +
            response.statusCode.toString() +
            ' - ' +
            response.body,
      );
    }
    final dynamic json = jsonDecode(response.body);
    if (json is List) {
      return _parseBest(json);
    }
    if (json is Map<String, dynamic> &&
        json.containsKey('label') &&
        json.containsKey('score')) {
      return <String, dynamic>{
        'label': _normalizeLabel((json['label'] as String?) ?? 'UNKNOWN'),
        'score': (json['score'] as num).toDouble(),
      };
    }
    throw Exception('Unexpected response format from HuggingFace API');
  }
}
