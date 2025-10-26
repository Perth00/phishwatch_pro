import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static bool _soundEnabled = true;
  static final AudioPlayer _clickPlayer =
      AudioPlayer(playerId: 'click')
        ..setReleaseMode(ReleaseMode.stop)
        ..setPlayerMode(PlayerMode.mediaPlayer)
        ..setVolume(1.0);
  static final AudioPlayer _successPlayer =
      AudioPlayer(playerId: 'success')
        ..setReleaseMode(ReleaseMode.stop)
        ..setPlayerMode(PlayerMode.mediaPlayer)
        ..setVolume(1.0);
  static final AudioPlayer _errorPlayer =
      AudioPlayer(playerId: 'error')
        ..setReleaseMode(ReleaseMode.stop)
        ..setPlayerMode(PlayerMode.mediaPlayer)
        ..setVolume(1.0);

  static Uint8List? _clickBytes;
  static Uint8List? _successBytes;
  static Uint8List? _errorBytes;

  static bool get soundEnabled => _soundEnabled;

  static void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  // Call once at app startup to configure audio session and warm up assets
  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (_) {}
    await preload();
  }

  // Preload all sounds into memory and prime the players to eliminate first-play delay
  static Future<void> preload() async {
    try {
      // Load bytes if not already loaded
      if (_clickBytes == null) {
        final data = await rootBundle.load('assets/sound/clicksound.mp3');
        _clickBytes = data.buffer.asUint8List();
      }
      if (_successBytes == null) {
        final data = await rootBundle.load('assets/sound/correctSound.mp3');
        _successBytes = data.buffer.asUint8List();
      }
      if (_errorBytes == null) {
        final data = await rootBundle.load('assets/sound/wrongSound.mp3');
        _errorBytes = data.buffer.asUint8List();
      }
      // Prime players with their sources so resume() starts instantly later
      if (_clickBytes != null) {
        await _clickPlayer.setSourceBytes(_clickBytes!);
      }
      if (_successBytes != null) {
        await _successPlayer.setSourceBytes(_successBytes!);
      }
      if (_errorBytes != null) {
        await _errorPlayer.setSourceBytes(_errorBytes!);
      }
    } catch (_) {
      // Ignore preload errors silently; playback path still tries lazily
    }
  }

  static void playButtonSound() {
    if (_soundEnabled) {
      debugPrint('[SoundService] playButtonSound');
      // Ensure other channels are silent to avoid overlap perception
      _successPlayer.stop();
      _errorPlayer.stop();
      _playCached(_clickPlayer, 'assets/sound/clicksound.mp3', which: 'click');
    }
  }

  static void playSuccessSound() {
    if (_soundEnabled) {
      debugPrint('[SoundService] playSuccessSound');
      // Ensure no overlap from any channel
      stopAll();
      _playCached(
        _successPlayer,
        'assets/sound/correctSound.mp3',
        which: 'success',
      );
    }
  }

  static void playErrorSound() {
    if (_soundEnabled) {
      debugPrint('[SoundService] playErrorSound');
      // Ensure no overlap from any channel
      stopAll();
      _playCached(_errorPlayer, 'assets/sound/wrongSound.mp3', which: 'error');
    }
  }

  static void playNotificationSound() {
    if (_soundEnabled) {
      // Reserved for future custom sound
    }
  }

  static void playSelectionSound() {
    if (_soundEnabled) {
      // Reserved for future selection sound
    }
  }

  static Future<void> _playCached(
    AudioPlayer player,
    String path, {
    required String which,
  }) async {
    try {
      // Preload into memory for zero-start latency and keep source primed
      Uint8List? bytes;
      bool needSetSource = false;
      if (which == 'click') {
        bytes = _clickBytes;
        if (bytes == null) {
          final data = await rootBundle.load(path);
          _clickBytes = data.buffer.asUint8List();
          bytes = _clickBytes;
          needSetSource = true;
        }
      } else if (which == 'success') {
        bytes = _successBytes;
        if (bytes == null) {
          final data = await rootBundle.load(path);
          _successBytes = data.buffer.asUint8List();
          bytes = _successBytes;
          needSetSource = true;
        }
      } else if (which == 'error') {
        bytes = _errorBytes;
        if (bytes == null) {
          final data = await rootBundle.load(path);
          _errorBytes = data.buffer.asUint8List();
          bytes = _errorBytes;
          needSetSource = true;
        }
      }
      if (bytes == null) return;
      await player.stop();
      if (needSetSource) {
        await player.setSourceBytes(bytes);
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {
      // Ignore audio errors to avoid crashing UX
    }
  }

  static Future<void> stopAll() async {
    try {
      await _clickPlayer.stop();
      await _successPlayer.stop();
      await _errorPlayer.stop();
    } catch (_) {}
  }
}
