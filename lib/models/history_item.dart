import 'scan_result_data.dart';

class HistoryItem {
  final String id;
  final DateTime timestamp;
  final String classification;
  final double confidence;
  final String riskLevel;
  final String source;
  final String preview;
  final bool isPhishing;
  final String message;

  HistoryItem({
    required this.id,
    required this.timestamp,
    required this.classification,
    required this.confidence,
    required this.riskLevel,
    required this.source,
    required this.preview,
    required this.isPhishing,
    required this.message,
  });

  factory HistoryItem.fromScanResult(ScanResultData data) {
    final String msg = data.message;
    final String preview =
        msg.length > 120 ? msg.substring(0, 120) + '...' : msg;
    return HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      classification: data.classification,
      confidence: data.confidence,
      riskLevel: data.riskLevel,
      source: data.source,
      preview: preview,
      isPhishing: data.isPhishing,
      message: msg,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'classification': classification,
      'confidence': confidence,
      'riskLevel': riskLevel,
      'source': source,
      'preview': preview,
      'isPhishing': isPhishing,
      'message': message,
    };
  }

  static HistoryItem fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      classification: json['classification'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      riskLevel: json['riskLevel'] as String,
      source: json['source'] as String,
      preview: json['preview'] as String,
      isPhishing: json['isPhishing'] as bool,
      message: json['message'] as String,
    );
  }

  ScanResultData toScanResultData() {
    return ScanResultData(
      isPhishing: isPhishing,
      confidence: confidence,
      classification: classification,
      riskLevel: riskLevel,
      source: source,
      message: message,
    );
  }
}
