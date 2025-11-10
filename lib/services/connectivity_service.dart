import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  ConnectivityService() {
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      // Try to make a simple HTTP HEAD request to reliable endpoints
      // If all fail, we assume no internet
      final results = await Future.wait([
        _testConnection('https://www.google.com'),
        _testConnection('https://www.cloudflare.com'),
      ], eagerError: false).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [false, false],
      );

      final newStatus = results.any((connected) => connected);
      if (_isConnected != newStatus) {
        _isConnected = newStatus;
        notifyListeners();
      }
    } catch (_) {
      if (_isConnected != false) {
        _isConnected = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _testConnection(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await client.headUrl(uri);
        final response = await request.close();
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return _isConnected;
  }
}
