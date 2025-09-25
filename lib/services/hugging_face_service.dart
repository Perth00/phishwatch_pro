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
    // Optional Space override
    final String spaceUrl = const String.fromEnvironment('HF_SPACE_URL');
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
}
