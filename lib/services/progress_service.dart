import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class ProgressService extends ChangeNotifier {
  // Lazily obtain Firestore instance to avoid accessing Firebase before
  // Firebase.initializeApp has completed. This prevents core/no-app errors
  // when service objects are constructed early in app boot or tests.
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  AuthService? _auth;

  ProgressService(this._auth);

  void attachAuth(AuthService auth) {
    _auth = auth;
  }

  String? get _uid => _auth?.currentUser?.uid;

  Future<void> ensureUserProfile({String goal = 'Beginner'}) async {
    final uid = _uid;
    if (uid == null) return;
    final doc = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      if (!snap.exists) {
        tx.set(doc, {
          'level': 'Beginner',
          'goal': goal,
          'name': '',
          'age': null,
          'levels': <String, String>{},
          'createdAt': FieldValue.serverTimestamp(),
          'stats': {
            'quizzesCompleted': 0,
            'scenariosCompleted': 0,
            'lessonsCompleted': 0,
            'accuracy': 0,
          },
        });
      }
    });
  }

  Future<void> completeLesson(String lessonId) async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = _db.collection('users').doc(uid);
    final progressRef = userRef.collection('progress').doc('learning');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(progressRef);
      final List<dynamic> completed = List<dynamic>.from(
        (snap.data() ?? const {})['completedLessons'] ?? <dynamic>[],
      );
      if (!completed.contains(lessonId)) {
        completed.add(lessonId);
      }
      tx.set(progressRef, {
        'completedLessons': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.update(userRef, {'stats.lessonsCompleted': FieldValue.increment(1)});
    });
    notifyListeners();
  }

  Future<Map<String, dynamic>> getUserSummary() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data() ?? {};
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data() ?? {};
  }

  Future<void> updateUserProfile({
    String? name,
    int? age,
    String? level,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final Map<String, dynamic> data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (age != null) data['age'] = age;
    if (level != null) data['level'] = level;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    notifyListeners();
  }

  // Per-category level preferences
  Future<Map<String, String>> getCategoryLevels() async {
    final uid = _uid;
    if (uid == null) return <String, String>{};
    final snap = await _db.collection('users').doc(uid).get();
    final Map<String, dynamic> data = (snap.data() ?? <String, dynamic>{});
    final Map<String, dynamic> levels = Map<String, dynamic>.from(
      data['levels'] ?? <String, dynamic>{},
    );
    return levels.map((k, v) => MapEntry(k, (v ?? '').toString()));
  }

  Future<String?> getCategoryLevel(String category) async {
    final levels = await getCategoryLevels();
    return levels[category];
  }

  Future<void> setCategoryLevel({
    required String category,
    required String level,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'levels': {category: level},
    }, SetOptions(merge: true));
    notifyListeners();
  }

  Future<void> recordQuizResult({
    required String quizId,
    required int correct,
    required int total,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = _db.collection('users').doc(uid);
    final resultsRef = userRef.collection('quizzes').doc(quizId);
    final accuracy = total == 0 ? 0.0 : (correct / total) * 100.0;
    await _db.runTransaction((tx) async {
      tx.set(resultsRef, {
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.update(userRef, {'stats.quizzesCompleted': FieldValue.increment(1)});
    });
    notifyListeners();
  }

  Future<void> recordScenarioAttempt({
    required String scenarioId,
    required bool correct,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = _db.collection('users').doc(uid);
    final resultsRef = userRef.collection('scenarios').doc(scenarioId);
    await _db.runTransaction((tx) async {
      tx.set(resultsRef, {
        'correct': correct,
        'attemptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.update(userRef, {'stats.scenariosCompleted': FieldValue.increment(1)});
    });
    notifyListeners();
  }
}
