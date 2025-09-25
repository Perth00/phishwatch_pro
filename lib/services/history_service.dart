import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';
import '../models/scan_result_data.dart';

class HistoryService extends ChangeNotifier {
  static const String _prefsKey = 'scan_history_v1';

  HistoryService() {
    _load();
  }

  final List<HistoryItem> _items = <HistoryItem>[];

  List<HistoryItem> get items => List.unmodifiable(_items);
  HistoryItem? get latest => _items.isEmpty ? null : _items.last;

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_prefsKey) ?? '[]';
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)),
        );
      notifyListeners();
    } catch (_) {
      // ignore corrupted data
    }
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  Future<void> add(HistoryItem item) async {
    _items.add(item);
    await _save();
    notifyListeners();
  }

  Future<void> addFromScanResult(ScanResultData data) async {
    await add(HistoryItem.fromScanResult(data));
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
    notifyListeners();
  }
}
