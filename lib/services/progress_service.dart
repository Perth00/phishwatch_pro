import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../models/learning_content.dart';

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
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(doc);
        if (!snap.exists) {
          tx.set(doc, {
            'level': 'Beginner',
            'goal': goal,
            'name': '',
            'age': null,
            'photoUrl': '',
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
    } catch (e) {
      // Do not block registration if Firestore rules temporarily deny writes
      debugPrint('ensureUserProfile skipped: $e');
    }
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
    try {
      final snap = await _db.collection('users').doc(uid).get();
      return snap.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final snap = await _db.collection('users').doc(uid).get();
      return snap.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> updateUserProfile({
    String? name,
    int? age,
    String? level,
    String? photoUrl,
    String? photoBase64,
    String? bio,
    String? phone,
    String? location,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final Map<String, dynamic> data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (age != null) data['age'] = age;
    if (level != null) data['level'] = level;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (photoBase64 != null) data['photoBase64'] = photoBase64;
    if (bio != null) data['bio'] = bio;
    if (phone != null) data['phone'] = phone;
    if (location != null) data['location'] = location;
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

  // Realtime watch of completed quizzes for a category (optionally by difficulty)
  Stream<int> watchCompletedQuizzesCount({
    required String category,
    String? difficulty,
  }) {
    final uid = _uid;
    if (uid == null) {
      // Emit zero when user is not authenticated
      return Stream<int>.value(0);
    }
    // Count passed attempts (>= 70%) so progress reflects 1/5, 2/5, ...
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .where('category', isEqualTo: category)
        .where('passed', isEqualTo: true);
    if (difficulty != null) {
      query = query.where('difficulty', isEqualTo: difficulty);
    }
    return query.snapshots().map((snap) => snap.docs.length);
  }

  Future<void> recordQuizResult({
    required String quizId,
    required int correct,
    required int total,
    String? category,
    String? difficulty,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = _db.collection('users').doc(uid);
    final resultsRef = userRef.collection('quizzes').doc(quizId);
    final accuracy = total == 0 ? 0.0 : (correct / total) * 100.0;
    await _db.runTransaction((tx) async {
      final passed = total == 0 ? false : (correct / total) * 100.0 >= 70.0;
      tx.set(resultsRef, {
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
        'passed': passed,
        'completedAt': FieldValue.serverTimestamp(),
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
      }, SetOptions(merge: true));
      tx.update(userRef, {'stats.quizzesCompleted': FieldValue.increment(1)});
    });
    notifyListeners();
  }

  // Store a detailed quiz attempt for history and progress
  Future<void> recordQuizAttemptDetailed({
    required String quizId,
    required String category,
    required String difficulty,
    required int correct,
    required int total,
    required List<Map<String, dynamic>> answers,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final attemptsRef = _db.collection('users').doc(uid).collection('attempts');
    final double accuracy = total == 0 ? 0.0 : (correct / total) * 100.0;
    final bool passed = accuracy >= 70.0;
    await attemptsRef.add({
      'quizId': quizId,
      'category': category,
      'difficulty': difficulty,
      'correct': correct,
      'total': total,
      'accuracy': accuracy,
      'passed': passed,
      'answers': answers,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // One-time fixer: ensure attempts have the correct category/difficulty
  // based on the quiz metadata. This updates older records that may have
  // been written with an incorrect category (e.g., all under Basics).
  Future<void> normalizeAttemptCategories({int maxDocs = 500}) async {
    final uid = _uid;
    if (uid == null) return;
    final attemptsRef = _db.collection('users').doc(uid).collection('attempts');
    try {
      final snap = await attemptsRef.limit(maxDocs).get();
      if (snap.docs.isEmpty) return;
      WriteBatch batch = _db.batch();
      int updates = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final String quizId = (data['quizId'] ?? '').toString();
        if (quizId.isEmpty) continue;
        final Quiz? quiz = LearningRepository.getQuiz(quizId);
        if (quiz == null) continue;
        final String desiredCategory = quiz.category;
        final String desiredDifficulty = quiz.difficulty;
        final String currentCategory = (data['category'] ?? '').toString();
        final String currentDifficulty = (data['difficulty'] ?? '').toString();
        if (currentCategory != desiredCategory ||
            currentDifficulty != desiredDifficulty) {
          batch.update(doc.reference, <String, dynamic>{
            'category': desiredCategory,
            'difficulty': desiredDifficulty,
          });
          updates += 1;
        }
      }
      if (updates > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('normalizeAttemptCategories failed: $e');
    }
  }

  // Helper to load CSV-driven questions (assets/questions/<category>_<level>.csv)
  // Expected columns: id,prompt,option1,option2,option3,option4,correct,explanation
  Future<List<MultipleChoiceQuestion>> loadCsvQuestions({
    required String category,
    required String level,
  }) async {
    try {
      final assetPath =
          'assets/questions/${category.toLowerCase().replaceAll(' ', '_')}_${level.toLowerCase()}.csv';
      final csv = await rootBundle.loadString(assetPath);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return <MultipleChoiceQuestion>[];
      final List<MultipleChoiceQuestion> questions = <MultipleChoiceQuestion>[];
      for (int i = 1; i < lines.length; i++) {
        final cols = _safeSplitCsv(lines[i]);
        if (cols.length < 8) continue;
        final correctIndex = int.tryParse(cols[6]) ?? 1;
        questions.add(
          MultipleChoiceQuestion(
            id: cols[0],
            prompt: cols[1],
            options:
                [
                  cols[2],
                  cols[3],
                  cols[4],
                  cols[5],
                ].where((e) => e.isNotEmpty).toList(),
            correctIndex: (correctIndex - 1).clamp(0, 3),
            explanation: cols[7].isEmpty ? null : cols[7],
          ),
        );
      }
      // Ensure at least 50 by repeating if dataset is small
      if (questions.isEmpty) return <MultipleChoiceQuestion>[];
      questions.shuffle();
      while (questions.length < 50) {
        questions.addAll(questions.take(50 - questions.length));
      }
      return questions.take(50).toList();
    } catch (_) {
      return <MultipleChoiceQuestion>[];
    }
  }

  List<String> _safeSplitCsv(String line) {
    // Simple CSV splitter without quotes handling for our controlled content
    final parts = <String>[];
    final buffer = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == ',') {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    parts.add(buffer.toString());
    return parts;
  }

  Future<List<Scenario>> loadScenarioCsv({
    required String category,
    required String level,
  }) async {
    try {
      final assetPath =
          'assets/questions/scenarios_${category.toLowerCase().replaceAll(' ', '_')}_${level.toLowerCase()}.csv';
      final csv = await rootBundle.loadString(assetPath);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return <Scenario>[];
      final List<Scenario> scenarios = <Scenario>[];
      for (int i = 1; i < lines.length; i++) {
        final cols = _safeSplitCsv(lines[i]);
        if (cols.length < 5) continue;
        final isPhishing = (cols[3].toLowerCase() == 'true' || cols[3] == '1');
        scenarios.add(
          Scenario(
            id: cols[0],
            title: cols[1],
            description: cols[2],
            isPhishing: isPhishing,
            rationale: cols[4],
            category: category,
            difficulty: level,
          ),
        );
      }
      if (scenarios.isEmpty) return <Scenario>[];
      scenarios.shuffle();
      while (scenarios.length < 20) {
        scenarios.addAll(scenarios.take(20 - scenarios.length));
      }
      return scenarios.take(20).toList();
    } catch (_) {
      return <Scenario>[];
    }
  }

  // Compute the user's overall level as the minimum across categories,
  // ordered Beginner < Intermediate < Advanced, so the title reflects
  // what they have unlocked consistently.
  static const List<String> _levelOrder = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  String _minLevelFrom(Map<String, String> levels) {
    if (levels.isEmpty) return 'Beginner';
    int minIndex = _levelOrder.length - 1;
    for (final value in levels.values) {
      final idx = _levelOrder.indexOf(value);
      if (idx != -1 && idx < minIndex) minIndex = idx;
    }
    return _levelOrder[minIndex];
  }

  Future<String> computeOverallLevel() async {
    final levels = await getCategoryLevels();
    return _minLevelFrom(levels);
  }

  Stream<String> watchOverallLevel() {
    final uid = _uid;
    if (uid == null) {
      return Stream<String>.value('Beginner');
    }
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      final raw = Map<String, dynamic>.from(
        data['levels'] ?? <String, dynamic>{},
      );
      final levels = raw.map((k, v) => MapEntry(k, (v ?? '').toString()));
      return _minLevelFrom(levels);
    });
  }

  // Check if user has passed prerequisite level in a category
  Future<bool> canSelectLevel({
    required String category,
    required String targetLevel,
  }) async {
    // Beginner is always selectable
    if (targetLevel == 'Beginner') return true;
    final uid = _uid;
    if (uid == null) return false;
    final userRef = _db.collection('users').doc(uid);
    final attempts =
        await userRef
            .collection('attempts')
            .where('category', isEqualTo: category)
            .where('passed', isEqualTo: true)
            .get();
    // New rule: 5 passes unlock Intermediate; 10 passes unlock Advanced.
    final passedCount = attempts.docs.length;
    if (targetLevel == 'Intermediate') return passedCount >= 5;
    if (targetLevel == 'Advanced') return passedCount >= 10;
    return false;
  }

  // Watch recent attempts for a given category
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAttempts({
    required String category,
    int limit = 25,
  }) {
    final uid = _uid;
    if (uid == null) {
      // Empty stream when signed out
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    // Avoid a composite index requirement by not ordering on the server.
    // We will sort by 'completedAt' on the client side in the UI.
    return _db
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .where('category', isEqualTo: category)
        .limit(limit)
        .snapshots();
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
