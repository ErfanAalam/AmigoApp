import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RingtoneManager {
  static final FlutterSoundPlayer _player = FlutterSoundPlayer();
  static bool _isInited = false;
  static String? _ringtonePath;

  /// Init player
  static Future<void> init() async {
    if (!_isInited) {
      try {
        // Request audio permissions
        await _requestAudioPermissions();

        // Initialize Flutter Sound with proper session
        await _player.openPlayer();

        // Player is now ready for playback
        _isInited = true;

        // Copy asset to temp directory once
        final byteData = await rootBundle.load(
          'assets/sounds/ringing_tone.mp3',
        );
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/ringing_tone.mp3');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        _ringtonePath = file.path;
      } catch (e) {
        debugPrint('[RINGTONE] Error initializing RingtoneManager');
        _isInited = false;
        rethrow;
      }
    }
  }

  /// Request audio permissions
  static Future<void> _requestAudioPermissions() async {
    try {
      // Request microphone permission (needed for Flutter Sound)
      final microphoneStatus = await Permission.microphone.request();

      // Request audio permission (Android 13+)
      await Permission.audio.request();

      if (microphoneStatus != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
    } catch (e) {
      debugPrint('[RINGTONE] Error requesting audio permissions');
      // Continue anyway, some platforms might not need explicit permissions
    }
  }

  /// Play ringtone in loop
  static Future<void> playRingtone() async {
    try {
      await init();
      if (_ringtonePath == null) return;

      // Check if file exists
      final file = File(_ringtonePath!);
      if (!await file.exists()) return;

      // Add a small delay to ensure audio system is ready
      await Future.delayed(const Duration(milliseconds: 200));

      // Use the legacy Flutter Sound API
      await _player.startPlayer(
        fromURI: _ringtonePath,
        codec: Codec.mp3,
        whenFinished: () async {
          await playRingtone(); // Restart automatically to loop
        },
      );
    } catch (e) {
      // Try alternative approach with legacy API
      try {
        await Future.delayed(const Duration(milliseconds: 500));

        await _player.startPlayer(
          fromURI: _ringtonePath,
          codec: Codec.mp3,
          whenFinished: () async {
            await playRingtone();
          },
        );
      } catch (retryError) {
        debugPrint('[RINGTONE] Failed to play ringtone even with legacy API');
      }
    }
  }

  /// Stop ringtone
  static Future<void> stopRingtone() async {
    try {
      if (_player.isPlaying) {
        await _player.stopPlayer();
      } else {
        debugPrint('[RINGTONE] No ringtone playing to stop');
      }
    } catch (e) {
      // Try alternative stop method
      try {
        await _player.pausePlayer();
      } catch (pauseError) {
        debugPrint('[RINGTONE] Error pausing ringtone');
      }
    }
  }

  /// Alternative ringtone using system sound (fallback)
  static Future<void> playSystemRingtone() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 1000));
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('[RINGTONE] System ringtone also failed');
    }
  }

  /// Dispose when not needed
  static Future<void> dispose() async {
    try {
      await _player.closePlayer();
      _isInited = false;
    } catch (e) {
      debugPrint('[RINGTONE] Error disposing RingtoneManager');
    }
  }
}
