import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import '../services/gemini_service.dart';
import '../models/history_item.dart';
import '../models/scan_result_data.dart';

class HistoryService extends ChangeNotifier {
  static const String _prefsBaseKey = 'scan_history_v1';
  static const String _firestoreCollection = 'history';

  HistoryService() {
    _initAuthListenerAndLoad();
  }

  final List<HistoryItem> _items = <HistoryItem>[];
  String _currentPrefsKey = '${_prefsBaseKey}_anon';
  StreamSubscription<fba.User?>? _authSub;

  // Firestore accessor
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  List<HistoryItem> get items => List.unmodifiable(_items);
  HistoryItem? get latest => _items.isEmpty ? null : _items.last;

  void _setPrefsKeyForUser(fba.User? user) {
    _currentPrefsKey =
        user == null ? '${_prefsBaseKey}_anon' : '${_prefsBaseKey}_${user.uid}';
  }

  Future<void> _initAuthListenerAndLoad() async {
    final auth = fba.FirebaseAuth.instance;
    _setPrefsKeyForUser(auth.currentUser);
    await _load();
    _authSub = auth.userChanges().listen((fba.User? user) async {
      _setPrefsKeyForUser(user);
      await _load();
      if (user != null) {
        await syncWithCloud();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _dedupeInPlace() {
    // Deduplicate by semantic key to avoid duplicates from local+cloud merge
    // Keep the newest item (by timestamp) for each unique content signature
    final Map<String, HistoryItem> bySignature = <String, HistoryItem>{};
    for (final HistoryItem item in _items) {
      final String normalizedMessage = item.message.trim().toLowerCase();
      final String signature =
          '${item.source}|${item.classification}|${item.isPhishing}|$normalizedMessage';
      final HistoryItem? existing = bySignature[signature];
      if (existing == null ||
          item.timestamp.isAfter(existing.timestamp)) {
        bySignature[signature] = item;
      }
    }
    _items
      ..clear()
      ..addAll(bySignature.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp)));
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_currentPrefsKey) ?? '[]';
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)),
        );
      _dedupeInPlace();
      notifyListeners();
    } catch (_) {
      // ignore corrupted data
    }
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_currentPrefsKey, raw);
  }

  Future<void> add(HistoryItem item) async {
    _items.add(item);
    await _save();
    // Also upload to Firestore if signed in
    await _uploadToCloudIfSignedIn(item);
    notifyListeners();
  }

  Future<void> addFromScanResult(ScanResultData data) async {
    await add(HistoryItem.fromScanResult(data));
  }

  Future<void> updateLatest(HistoryItem updatedItem) async {
    if (_items.isNotEmpty) {
      _items[_items.length - 1] = updatedItem;
      await _save();
      notifyListeners();
    }
  }

  /// Update the Gemini analysis for a specific history item by id
  Future<void> updateGeminiById(String id, GeminiAnalysis analysis) async {
    final int index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(geminiAnalysis: analysis);
      await _save();
      await _updateCloudGeminiIfSignedIn(_items[index]);
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  /// Merge local history with Firestore for the signed-in user.
  /// - Downloads remote-only items to local
  /// - Uploads local-only items to remote
  /// - Skips items present on both sides (by id)
  Future<void> syncWithCloud() async {
    final fba.User? user = fba.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _db
              .collection('users')
              .doc(user.uid)
              .collection(_firestoreCollection)
              .get();

      // Build maps for quick lookup by id
      final Map<String, HistoryItem> localById = {
        for (final item in _items) item.id: item,
      };
      final Map<String, HistoryItem> remoteById = {
        for (final d in snap.docs)
          d.id: HistoryItem.fromJson(<String, dynamic>{
            ...d.data(),
            'id': d.id,
          }),
      };

      bool changed = false;

      // Pull remote-only to local
      for (final String id in remoteById.keys) {
        if (!localById.containsKey(id)) {
          _items.add(remoteById[id]!);
          changed = true;
        }
      }

      // Push local-only to remote
      for (final String id in localById.keys) {
        if (!remoteById.containsKey(id)) {
          await _db
              .collection('users')
              .doc(user.uid)
              .collection(_firestoreCollection)
              .doc(id)
              .set(localById[id]!.toJson());
        }
      }

      if (changed) {
        _dedupeInPlace();
        await _save();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('History sync failed: $e');
    }
  }

  Future<void> _uploadToCloudIfSignedIn(HistoryItem item) async {
    final fba.User? user = fba.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection(_firestoreCollection)
          .doc(item.id)
          .set(item.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Upload history failed: $e');
    }
  }

  Future<void> _updateCloudGeminiIfSignedIn(HistoryItem item) async {
    final fba.User? user = fba.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection(_firestoreCollection)
          .doc(item.id)
          .set(<String, dynamic>{
            if (item.geminiAnalysis != null)
              'geminiAnalysis': item.geminiAnalysis!.toJson(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Update history gemini failed: $e');
    }
  }
}
