import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class AuthService extends ChangeNotifier {
  final Completer<void> _initCompleter = Completer<void>();

  fba.User? get currentUser =>
      Firebase.apps.isNotEmpty ? fba.FirebaseAuth.instance.currentUser : null;
  bool get isAuthenticated => currentUser != null;

  AuthService() {
    _ensureInitAndListen().whenComplete(() {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    });
  }

  Future<void> _ensureInitialized() => _initCompleter.future;

  Future<void> _ensureInitAndListen() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final auth = fba.FirebaseAuth.instance;
      await auth.setLanguageCode('en');
      auth.userChanges().listen((_) => notifyListeners());
    } catch (_) {
      // Constructor must not crash; UI can retry later
    }
  }

  Future<fba.User?> registerWithEmail(String email, String password) async {
    await _ensureInitialized();
    final credential = await fba.FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<fba.User?> signInWithEmail(String email, String password) async {
    await _ensureInitialized();
    final credential = await fba.FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<void> sendEmailVerification() async {
    await _ensureInitialized();
    final user = fba.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No authenticated user to verify');
    }
    if (user.emailVerified) return;
    try {
      // Use default Firebase verification link; do not pass ActionCodeSettings
      await user.sendEmailVerification();
    } on fba.FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw Exception(
          '[too-many-requests] Too many requests. Please try again later.',
        );
      }
      throw Exception(
        '[${e.code}] ${e.message ?? 'Failed to send verification email'}',
      );
    }
  }

  Future<void> reloadCurrentUser() async {
    await _ensureInitialized();
    final user = fba.FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _ensureInitialized();
    await fba.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<fba.User?> signInAnonymously() async {
    await _ensureInitialized();
    final cred = await fba.FirebaseAuth.instance.signInAnonymously();
    return cred.user;
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await fba.FirebaseAuth.instance.signOut();
  }
}
