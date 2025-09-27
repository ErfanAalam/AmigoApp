import 'dart:io';
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
        print('[RINGTONE] Initializing Flutter Sound player...');

        // Request audio permissions
        await _requestAudioPermissions();

        // Initialize Flutter Sound with proper session
        await _player.openPlayer();

        // Player is now ready for playback

        _isInited = true;

        // Copy asset to temp directory once
        print('[RINGTONE] Loading ringtone asset...');
        final byteData = await rootBundle.load(
          'assets/sounds/ringing_tone.mp3',
        );
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/ringing_tone.mp3');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        _ringtonePath = file.path;

        print('[RINGTONE] Ringtone file saved to: $_ringtonePath');
        print('[RINGTONE] RingtoneManager initialized successfully');
      } catch (e) {
        print('[RINGTONE] Error initializing RingtoneManager: $e');
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
      print('[RINGTONE] Microphone permission status: $microphoneStatus');

      // Request audio permission (Android 13+)
      final audioStatus = await Permission.audio.request();
      print('[RINGTONE] Audio permission status: $audioStatus');

      if (microphoneStatus != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
    } catch (e) {
      print('[RINGTONE] Error requesting audio permissions: $e');
      // Continue anyway, some platforms might not need explicit permissions
    }
  }

  /// Play ringtone in loop
  static Future<void> playRingtone() async {
    try {
      await init();
      if (_ringtonePath == null) {
        print('[RINGTONE] Ringtone path is null, cannot play');
        return;
      }

      // Check if file exists
      final file = File(_ringtonePath!);
      if (!await file.exists()) {
        print('[RINGTONE] Ringtone file does not exist at: $_ringtonePath');
        return;
      }

      print('[RINGTONE] Attempting to play ringtone from: $_ringtonePath');
      print('[RINGTONE] File size: ${await file.length()} bytes');

      // Add a small delay to ensure audio system is ready
      await Future.delayed(const Duration(milliseconds: 200));

      // Use the legacy Flutter Sound API
      await _player.startPlayer(
        fromURI: _ringtonePath,
        codec: Codec.mp3,
        whenFinished: () async {
          print('[RINGTONE] Ringtone finished, restarting...');
          await playRingtone(); // Restart automatically to loop
        },
      );

      print('[RINGTONE] Ringtone started successfully');
    } catch (e) {
      print('[RINGTONE] Error playing ringtone: $e');
      print('[RINGTONE] Error type: ${e.runtimeType}');

      // Try alternative approach with legacy API
      try {
        print('[RINGTONE] Trying legacy API...');
        await Future.delayed(const Duration(milliseconds: 500));

        await _player.startPlayer(
          fromURI: _ringtonePath,
          codec: Codec.mp3,
          whenFinished: () async {
            print('[RINGTONE] Legacy ringtone finished, restarting...');
            await playRingtone();
          },
        );
        print('[RINGTONE] Ringtone started successfully with legacy API');
      } catch (retryError) {
        print(
          '[RINGTONE] Failed to play ringtone even with legacy API: $retryError',
        );
        print('[RINGTONE] Retry error type: ${retryError.runtimeType}');
      }
    }
  }

  /// Stop ringtone
  static Future<void> stopRingtone() async {
    try {
      if (_player.isPlaying) {
        print('[RINGTONE] Stopping ringtone...');
        await _player.stopPlayer();
        print('[RINGTONE] Ringtone stopped successfully');
      } else {
        print('[RINGTONE] No ringtone playing to stop');
      }
    } catch (e) {
      print('[RINGTONE] Error stopping ringtone: $e');
      // Try alternative stop method
      try {
        await _player.pausePlayer();
        print('[RINGTONE] Ringtone paused successfully');
      } catch (pauseError) {
        print('[RINGTONE] Error pausing ringtone: $pauseError');
      }
    }
  }

  /// Test method to debug audio issues
  static Future<void> testAudio() async {
    try {
      print('[RINGTONE] Testing audio system...');
      await init();

      if (_ringtonePath == null) {
        print('[RINGTONE] TEST FAILED: Ringtone path is null');
        return;
      }

      final file = File(_ringtonePath!);
      if (!await file.exists()) {
        print('[RINGTONE] TEST FAILED: File does not exist');
        return;
      }

      print('[RINGTONE] TEST PASSED: File exists at $_ringtonePath');
      print('[RINGTONE] File size: ${await file.length()} bytes');
      print('[RINGTONE] Player initialized: $_isInited');
      print('[RINGTONE] Player is playing: ${_player.isPlaying}');
    } catch (e) {
      print('[RINGTONE] TEST FAILED: $e');
    }
  }

  /// Alternative ringtone using system sound (fallback)
  static Future<void> playSystemRingtone() async {
    try {
      print('[RINGTONE] Playing system ringtone as fallback...');
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 1000));
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      print('[RINGTONE] System ringtone also failed: $e');
    }
  }

  /// Dispose when not needed
  static Future<void> dispose() async {
    try {
      await _player.closePlayer();
      _isInited = false;
      print('[RINGTONE] RingtoneManager disposed');
    } catch (e) {
      print('[RINGTONE] Error disposing RingtoneManager: $e');
    }
  }
}
