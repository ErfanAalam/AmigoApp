/// Stub re-implementation of flutter_webrtc surface area.
///
/// Only the symbols actually referenced by `lib/services/call/call.service.dart`
/// and friends are defined here. Every method is a no-op or returns a default
/// value — at runtime the WebRTC backend is unreachable in Stream-only builds.
library flutter_webrtc;

import 'dart:async';

// ---- Media ----

class MediaStreamTrack {
  bool enabled = true;
  Future<void> stop() async {}
}

class MediaStream {
  List<MediaStreamTrack> getTracks() => const [];
  List<MediaStreamTrack> getAudioTracks() => const [];
  List<MediaStreamTrack> getVideoTracks() => const [];
}

class _MediaDevices {
  Future<MediaStream> getUserMedia(Map<String, dynamic> constraints) async =>
      MediaStream();
}

class _Navigator {
  final _MediaDevices mediaDevices = _MediaDevices();
}

final _Navigator navigator = _Navigator();

// ---- SDP / ICE ----

class RTCSessionDescription {
  RTCSessionDescription([this.sdp, this.type]);
  final String? sdp;
  final String? type;
}

class RTCIceCandidate {
  RTCIceCandidate([this.candidate, this.sdpMid, this.sdpMLineIndex]);
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
}

// ---- Peer connection ----

enum RTCPeerConnectionState {
  RTCPeerConnectionStateNew,
  RTCPeerConnectionStateConnecting,
  RTCPeerConnectionStateConnected,
  RTCPeerConnectionStateDisconnected,
  RTCPeerConnectionStateFailed,
  RTCPeerConnectionStateClosed,
}

class RTCPeerConnection {
  void Function(MediaStream stream)? onAddStream;
  void Function(RTCIceCandidate candidate)? onIceCandidate;
  void Function(RTCPeerConnectionState state)? onConnectionState;

  Future<void> addStream(MediaStream stream) async {}
  Future<void> addCandidate(RTCIceCandidate candidate) async {}
  Future<void> setRemoteDescription(RTCSessionDescription d) async {}
  Future<void> setLocalDescription(RTCSessionDescription d) async {}
  Future<RTCSessionDescription> createOffer([Map<String, dynamic>? c]) async =>
      RTCSessionDescription();
  Future<RTCSessionDescription> createAnswer([Map<String, dynamic>? c]) async =>
      RTCSessionDescription();
  Future<void> close() async {}
}

Future<RTCPeerConnection> createPeerConnection(
  Map<String, dynamic> configuration, [
  Map<String, dynamic>? constraints,
]) async {
  return RTCPeerConnection();
}

// ---- Misc helpers ----

class Helper {
  /// Stream's audio routing handles speaker toggling internally; this stub
  /// is only here so the existing WebRTC code compiles.
  static Future<void> setSpeakerphoneOn(bool on) async {}
}
