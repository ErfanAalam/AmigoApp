import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Foreground-state ringtone driver for the Stream backend.
///
/// All actual audio resource ownership lives in Kotlin
/// (AmigoRingtoneManager) — that's where MediaPlayer/ToneGenerator are
/// allocated, mutex-guarded, watchdog'd, and released. This class is a
/// thin Dart-side wrapper that:
///
///   1. Routes mode transitions over a single MethodChannel.
///   2. Serialises calls onto an internal `Future` chain so a
///      `play → stop → play` burst from rapid SDK state events lands in
///      the same order in Kotlin (out-of-order delivery is what made the
///      old flutter_ringtone_player path leak — a play that resolved
///      after a stop would silently win and ring forever).
///   3. Tracks the current mode so duplicate transitions are no-ops and
///      don't bounce through the channel.
///
/// Used as a singleton: [StreamCallRingtones.instance].
enum _RingMode { none, incoming, outgoing }

class StreamCallRingtones {
  StreamCallRingtones._();
  static final StreamCallRingtones instance = StreamCallRingtones._();

  static const MethodChannel _channel =
      MethodChannel('com.aiexch.amigo/stream_ringtone');

  _RingMode _current = _RingMode.none;
  Future<void> _inFlight = Future.value();

  /// Begin the looping incoming-call ringtone (phone's default ringtone).
  /// No-op if already playing the incoming tone.
  Future<void> playIncoming() => _setMode(_RingMode.incoming);

  /// Begin the outgoing ringback tone (telephony "turr.. turr.." cadence).
  /// No-op if already playing the outgoing tone.
  Future<void> playOutgoing() => _setMode(_RingMode.outgoing);

  /// Stop both incoming and outgoing tones. Always safe to call.
  Future<void> stopAll() => _setMode(_RingMode.none);

  /// Plays the connect beep — fires once when remote audio actually starts
  /// flowing (i.e. when [StreamCallService.callConnectedAt] is first
  /// pinned). Transient, self-releasing one-shot — routes through the
  /// in-call audio path on Android (USAGE_VOICE_COMMUNICATION_SIGNALLING)
  /// and does NOT serialise onto the `_setMode` chain because it must
  /// coexist with any outgoing-tone tail-out without blocking transitions.
  Future<void> playConnectBeep() =>
      _playOneShot('assets/sounds/call_connected_beep.mp3');

  /// Plays the disconnect beep — fires once at the terminal transition,
  /// but only for calls that actually connected (see the call site in
  /// `StreamCallService._onCallStateChanged`). Same audio routing as
  /// [playConnectBeep].
  Future<void> playDisconnectBeep() =>
      _playOneShot('assets/sounds/call_disconnected_beep.mp3');

  Future<void> _playOneShot(String asset) async {
    // Fire-and-forget; failures (e.g. iOS, where no handler is registered)
    // are swallowed so the call flow can't be derailed by a missing beep.
    try {
      await _channel.invokeMethod('playOneShot', {'asset': asset});
    } catch (e) {
      debugPrint('[STREAM-RING] playOneShot($asset) failed: $e');
    }
  }

  Future<void> _setMode(_RingMode target) {
    // Chain onto the prior in-flight transition so the channel calls
    // execute in the order they were requested. Without this, two
    // back-to-back transitions can race — playIncoming followed by
    // stopAll would invoke playIncoming and stopAll on the channel
    // concurrently, and the platform-message dispatcher does not
    // guarantee ordering.
    final completer = Completer<void>();
    final lastFuture = _inFlight;
    _inFlight = completer.future;

    () async {
      try {
        await lastFuture;
      } catch (_) {}
      try {
        if (_current == target) {
          debugPrint('[STREAM-RING] no-op (already ${target.name})');
          return;
        }
        debugPrint('[STREAM-RING] ⮕ ${_current.name} → ${target.name}  '
            '(invoking channel)');
        _current = target;
        switch (target) {
          case _RingMode.incoming:
            await _channel.invokeMethod('playIncoming');
          case _RingMode.outgoing:
            await _channel.invokeMethod('playOutgoing');
          case _RingMode.none:
            await _channel.invokeMethod('stop');
        }
        debugPrint('[STREAM-RING] ✓ ${target.name} channel call returned');
      } catch (e, st) {
        debugPrint('[STREAM-RING] ✗ transition to ${target.name} failed: $e\n$st');
      } finally {
        completer.complete();
      }
    }();

    return completer.future;
  }
}
