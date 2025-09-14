import 'package:flutter/services.dart';

class SoundService {
  static bool _soundEnabled = true;

  static bool get soundEnabled => _soundEnabled;

  static void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  static void playButtonSound() {
    if (_soundEnabled) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void playSuccessSound() {
    if (_soundEnabled) {
      HapticFeedback.mediumImpact();
      // Could add custom sound here
    }
  }

  static void playErrorSound() {
    if (_soundEnabled) {
      HapticFeedback.heavyImpact();
      // Could add custom sound here
    }
  }

  static void playNotificationSound() {
    if (_soundEnabled) {
      HapticFeedback.lightImpact();
      // Could add custom sound here
    }
  }

  static void playSelectionSound() {
    if (_soundEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}
