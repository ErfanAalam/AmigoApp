import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class RingtoneManager {
  static final FlutterSoundPlayer _player = FlutterSoundPlayer();
  static bool _isInited = false;
  static String? _ringtonePath;

  /// Init player
  static Future<void> init() async {
    if (!_isInited) {
      await _player.openPlayer();
      _isInited = true;

      // Copy asset to temp directory once
      final byteData = await rootBundle.load('assets/sounds/ringing_tone.mp3');
      final file = File('${(await getTemporaryDirectory()).path}/ringing_tone.mp3');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _ringtonePath = file.path;
    }
  }

  /// Play ringtone in loop
  static Future<void> playRingtone() async {
    await init();
    if (_ringtonePath == null) return;

    await _player.startPlayer(
      fromURI: _ringtonePath,
      codec: Codec.mp3,
      whenFinished: () async {
        // Restart automatically to loop
        await playRingtone();
      },
    );
  }

  /// Stop ringtone
  static Future<void> stopRingtone() async {
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
  }

  /// Dispose when not needed
  static Future<void> dispose() async {
    await _player.closePlayer();
    _isInited = false;
  }
}
