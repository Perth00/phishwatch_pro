import '../services/gemini_service.dart';

class ScanResultData {
  final bool isPhishing;
  final double confidence; // 0.0 - 1.0
  final String classification; // e.g., "Phishing" or "Legitimate"
  final String riskLevel; // High, Medium, Low
  final String source; // sender, domain, etc.
  final String message; // original analyzed text
  final GeminiAnalysis? geminiAnalysis; // Educational feedback from Gemini
  final Future<GeminiAnalysis?>? geminiAnalysisFuture; // Async loading

  const ScanResultData({
    required this.isPhishing,
    required this.confidence,
    required this.classification,
    required this.riskLevel,
    required this.source,
    required this.message,
    this.geminiAnalysis,
    this.geminiAnalysisFuture,
  });

  @override
  String toString() {
    return 'ScanResultData(isPhishing: $isPhishing, confidence: $confidence, classification: $classification, riskLevel: $riskLevel, source: $source)';
  }

  static String riskFromConfidence(
    double confidence, {
    required bool isPhishing,
  }) {
    if (!isPhishing) {
      if (confidence >= 0.85) return 'Low';
      if (confidence >= 0.60) return 'Very Low';
      return 'Minimal';
    }
    if (confidence >= 0.85) return 'High';
    if (confidence >= 0.60) return 'Medium';
    return 'Low';
  }
}
