import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService extends ChangeNotifier {
  static const String _onboardingKey = 'onboarding_completed';
  bool _isOnboardingCompleted = false;

  bool get isOnboardingCompleted => _isOnboardingCompleted;

  OnboardingService() {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingCompleted = prefs.getBool(_onboardingKey) ?? false;
      notifyListeners();
    } catch (e) {
      // If SharedPreferences fails, default to false
      _isOnboardingCompleted = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
      _isOnboardingCompleted = true;
      notifyListeners();
    } catch (e) {
      // Handle error gracefully
      debugPrint('Error saving onboarding status: $e');
    }
  }

  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, false);
      _isOnboardingCompleted = false;
      notifyListeners();
    } catch (e) {
      // Handle error gracefully
      debugPrint('Error resetting onboarding status: $e');
    }
  }
}

