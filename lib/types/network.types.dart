import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connection type (wrapper around ConnectivityResult for easier use)
enum NetworkConnectionType {
  wifi,
  mobile,
  ethernet,
  vpn,
  other,
  none;

  /// Convert from ConnectivityResult list
  static NetworkConnectionType fromConnectivityResult(
    List<ConnectivityResult> results,
  ) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkConnectionType.none;
    }

    // Priority order: wifi > mobile > ethernet > vpn > bluetooth > other
    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkConnectionType.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkConnectionType.mobile;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkConnectionType.ethernet;
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return NetworkConnectionType.vpn;
    }
    // if (results.contains(ConnectivityResult.bluetooth)) {
    //   return NetworkConnectionType.bluetooth;
    // }
    if (results.contains(ConnectivityResult.other)) {
      return NetworkConnectionType.other;
    }

    return NetworkConnectionType.none;
  }

  /// Check if network is available
  bool get isAvailable => this != NetworkConnectionType.none;

  /// Check if network is likely to be fast (wifi, ethernet)
  bool get isLikelyFast =>
      this == NetworkConnectionType.wifi ||
      this == NetworkConnectionType.ethernet;

  /// Check if network is likely to be slow (mobile, bluetooth)
  bool get isLikelySlow => this == NetworkConnectionType.mobile;
  // this == NetworkConnectionType.bluetooth;
}

/// Network quality based on ping latency and reliability
enum NetworkQuality {
  excellent, // < 100ms ping, very stable
  good, // 100-300ms ping, stable
  fair, // 300-1000ms ping, somewhat stable
  poor, // 1000-3000ms ping, unstable
  veryPoor, // > 3000ms ping or frequent failures
  offline; // No connectivity

  /// Determine quality from ping latency in milliseconds
  static NetworkQuality fromPingLatency(int? latencyMs) {
    if (latencyMs == null) return NetworkQuality.offline;

    if (latencyMs < 100) return NetworkQuality.excellent;
    if (latencyMs < 300) return NetworkQuality.good;
    if (latencyMs < 1000) return NetworkQuality.fair;
    if (latencyMs < 3000) return NetworkQuality.poor;
    return NetworkQuality.veryPoor;
  }

  /// Check if quality is acceptable for real-time communication
  bool get isAcceptable =>
      this == NetworkQuality.excellent ||
      this == NetworkQuality.good ||
      this == NetworkQuality.fair;

  /// Check if quality is too poor for reliable communication
  bool get isUnacceptable =>
      this == NetworkQuality.poor ||
      this == NetworkQuality.veryPoor ||
      this == NetworkQuality.offline;
}

/// Network state combining connection type and quality
class NetworkState {
  final NetworkConnectionType connectionType;
  final NetworkQuality quality;
  final int? pingLatencyMs;
  final DateTime lastChecked;
  final bool isServerReachable;
  final bool isWebSocketAvailable;
  final bool isPollingAvailable;
  final TransmissionMode preferredTransmissionMode;

  NetworkState({
    required this.connectionType,
    required this.quality,
    this.pingLatencyMs,
    required this.lastChecked,
    required this.isServerReachable,
    required this.isWebSocketAvailable,
    required this.isPollingAvailable,
    required this.preferredTransmissionMode,
  });

  /// Check if network is available
  bool get isAvailable => connectionType.isAvailable && isServerReachable;

  /// Check if network is suitable for real-time communication
  bool get isSuitableForRealtime =>
      isAvailable && quality.isAcceptable && isWebSocketAvailable;

  /// Create offline state
  factory NetworkState.offline() {
    return NetworkState(
      connectionType: NetworkConnectionType.none,
      quality: NetworkQuality.offline,
      lastChecked: DateTime.now(),
      isServerReachable: false,
      isWebSocketAvailable: false,
      isPollingAvailable: false,
      preferredTransmissionMode: TransmissionMode.none,
    );
  }

  NetworkState copyWith({
    NetworkConnectionType? connectionType,
    NetworkQuality? quality,
    int? pingLatencyMs,
    DateTime? lastChecked,
    bool? isServerReachable,
    bool? isWebSocketAvailable,
    bool? isPollingAvailable,
    TransmissionMode? preferredTransmissionMode,
  }) {
    return NetworkState(
      connectionType: connectionType ?? this.connectionType,
      quality: quality ?? this.quality,
      pingLatencyMs: pingLatencyMs ?? this.pingLatencyMs,
      lastChecked: lastChecked ?? this.lastChecked,
      isServerReachable: isServerReachable ?? this.isServerReachable,
      isWebSocketAvailable: isWebSocketAvailable ?? this.isWebSocketAvailable,
      isPollingAvailable: isPollingAvailable ?? this.isPollingAvailable,
      preferredTransmissionMode:
          preferredTransmissionMode ?? this.preferredTransmissionMode,
    );
  }

  @override
  String toString() {
    return 'NetworkState('
        'type: ${connectionType.name}, '
        'quality: ${quality.name}, '
        'ping: ${pingLatencyMs ?? 'N/A'}ms, '
        'server: ${isServerReachable ? 'reachable' : 'unreachable'}, '
        'ws: ${isWebSocketAvailable ? 'available' : 'unavailable'}, '
        'polling: ${isPollingAvailable ? 'available' : 'unavailable'}, '
        'preferred: ${preferredTransmissionMode.name}'
        ')';
  }
}

/// Transmission mode preference
enum TransmissionMode {
  websocket, // WebSocket is preferred and available
  longPolling, // Long polling is preferred (WebSocket unavailable)
  none; // No transmission available

  /// Check if transmission is available
  bool get isAvailable => this != TransmissionMode.none;
}

/// WebSocket connectivity test result

class WebSocketTestResult {
  final bool isAvailable;
  final int? connectionTimeMs;
  final String? error;
  final DateTime testedAt;

  WebSocketTestResult({
    required this.isAvailable,
    this.connectionTimeMs,
    this.error,
    required this.testedAt,
  });

  factory WebSocketTestResult.success(int connectionTimeMs) {
    return WebSocketTestResult(
      isAvailable: true,
      connectionTimeMs: connectionTimeMs,
      testedAt: DateTime.now(),
    );
  }

  factory WebSocketTestResult.failure(String error) {
    return WebSocketTestResult(
      isAvailable: false,
      error: error,
      testedAt: DateTime.now(),
    );
  }
}

/// Ping test result
class PingTestResult {
  final bool success;
  final int? latencyMs;
  final String? error;
  final DateTime testedAt;

  PingTestResult({
    required this.success,
    this.latencyMs,
    this.error,
    required this.testedAt,
  });

  factory PingTestResult.success(int latencyMs) {
    return PingTestResult(
      success: true,
      latencyMs: latencyMs,
      testedAt: DateTime.now(),
    );
  }

  factory PingTestResult.failure(String error) {
    return PingTestResult(
      success: false,
      error: error,
      testedAt: DateTime.now(),
    );
  }
}
