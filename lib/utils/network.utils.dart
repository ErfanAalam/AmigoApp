import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../env.dart';
import '../types/network.types.dart';

/// Comprehensive network connectivity utility
/// Provides network type detection, quality assessment, and transmission mode recommendations
class NetworkConnectivityUtil {
  static final NetworkConnectivityUtil _instance =
      NetworkConnectivityUtil._internal();
  factory NetworkConnectivityUtil() => _instance;
  NetworkConnectivityUtil._internal() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();

  // Current state
  NetworkState _currentState = NetworkState.offline();
  NetworkConnectionType _lastConnectionType = NetworkConnectionType.none;
  NetworkQuality _lastQuality = NetworkQuality.offline;
  TransmissionMode _lastTransmissionMode = TransmissionMode.none;

  // Stream controllers
  final StreamController<NetworkState> _stateController =
      StreamController<NetworkState>.broadcast();
  final StreamController<NetworkConnectionType> _connectionTypeController =
      StreamController<NetworkConnectionType>.broadcast();
  final StreamController<NetworkQuality> _qualityController =
      StreamController<NetworkQuality>.broadcast();
  final StreamController<TransmissionMode> _transmissionModeController =
      StreamController<TransmissionMode>.broadcast();

  // Subscriptions
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicCheckTimer;

  // Configuration
  static const Duration _pingTimeout = Duration(seconds: 3);
  static const Duration _periodicCheckInterval = Duration(seconds: 15);

  // Getters
  NetworkState get currentState => _currentState;
  NetworkConnectionType get currentConnectionType =>
      _currentState.connectionType;
  NetworkQuality get currentQuality => _currentState.quality;
  TransmissionMode get currentTransmissionMode =>
      _currentState.preferredTransmissionMode;

  // Streams
  Stream<NetworkState> get stateStream => _stateController.stream;
  Stream<NetworkConnectionType> get connectionTypeStream =>
      _connectionTypeController.stream;
  Stream<NetworkQuality> get qualityStream => _qualityController.stream;
  Stream<TransmissionMode> get transmissionModeStream =>
      _transmissionModeController.stream;

  void _initialize() {
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) {
        debugPrint('[NETWORK] Connectivity stream error: $error');
      },
    );

    // Start periodic checks
    _startPeriodicChecks();

    // Initial check
    _performFullCheck();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final newType = NetworkConnectionType.fromConnectivityResult(results);

    if (newType != _lastConnectionType) {
      _lastConnectionType = newType;
      _connectionTypeController.add(newType);
      debugPrint('[NETWORK] Connection type changed: ${newType.name}');

      // Perform full check when connection type changes
      _performFullCheck();
    }
  }

  void _startPeriodicChecks() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(
      _periodicCheckInterval,
      (_) => _performFullCheck(),
    );
  }

  /// Perform a lightweight network check (single HTTP ping)
  Future<NetworkState> _performFullCheck() async {
    try {
      // Get current connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final connectionType = NetworkConnectionType.fromConnectivityResult(
        connectivityResults,
      );

      // If offline, set offline state
      if (connectionType == NetworkConnectionType.none) {
        final offlineState = NetworkState.offline();
        _updateState(offlineState);
        return offlineState;
      }

      // Single lightweight ping to check server reachability
      final pingResult = await pingServer();
      final isServerReachable = pingResult.success;
      final quality = NetworkQuality.fromPingLatency(pingResult.latencyMs);

      // Determine preferred transmission mode:
      // If server is reachable, prefer WebSocket; never go to none based on quality alone.
      final TransmissionMode preferredMode;
      if (isServerReachable) {
        preferredMode = TransmissionMode.websocket;
      } else {
        preferredMode = TransmissionMode.none;
      }

      // Create new state
      final newState = NetworkState(
        connectionType: connectionType,
        quality: quality,
        pingLatencyMs: pingResult.latencyMs,
        lastChecked: DateTime.now(),
        isServerReachable: isServerReachable,
        isWebSocketAvailable: isServerReachable,
        isPollingAvailable: isServerReachable,
        preferredTransmissionMode: preferredMode,
      );

      _updateState(newState);
      return newState;
    } catch (e) {
      debugPrint('[NETWORK] Error performing full check: $e');
      final errorState = NetworkState.offline();
      _updateState(errorState);
      return errorState;
    }
  }

  void _updateState(NetworkState newState) {
    _currentState = newState;

    // Emit state change
    _stateController.add(newState);

    // Emit quality change if different
    if (newState.quality != _lastQuality) {
      _lastQuality = newState.quality;
      _qualityController.add(newState.quality);
      debugPrint('[NETWORK] Quality changed: ${newState.quality.name}');
    }

    // Emit transmission mode change if different
    if (newState.preferredTransmissionMode != _lastTransmissionMode) {
      _lastTransmissionMode = newState.preferredTransmissionMode;
      _transmissionModeController.add(newState.preferredTransmissionMode);
      debugPrint(
        '[NETWORK] Transmission mode changed: ${newState.preferredTransmissionMode.name}',
      );
    }
  }

  /// Ping the server to check reachability and latency (single attempt, 3s timeout)
  Future<PingTestResult> pingServer() async {
    final pingUrl = '${Environment.baseUrl}/';

    try {
      final stopwatch = Stopwatch()..start();

      final response = await http
          .get(Uri.parse(pingUrl))
          .timeout(_pingTimeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        return PingTestResult.success(stopwatch.elapsedMilliseconds);
      } else {
        return PingTestResult.failure(
          'Server returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      return PingTestResult.failure(e.toString());
    }
  }

  /// Manually trigger a full network check
  Future<NetworkState> checkNetwork() async {
    return await _performFullCheck();
  }

  /// Check if network is currently available
  Future<bool> isNetworkAvailable() async {
    final state = await checkNetwork();
    return state.isAvailable;
  }

  /// Check if WebSocket is currently available
  Future<bool> isWebSocketAvailable() async {
    final state = await checkNetwork();
    return state.isWebSocketAvailable;
  }

  /// Check if polling is currently available
  Future<bool> isPollingAvailable() async {
    final state = await checkNetwork();
    return state.isPollingAvailable;
  }

  /// Get recommended transmission mode
  Future<TransmissionMode> getRecommendedTransmissionMode() async {
    final state = await checkNetwork();
    return state.preferredTransmissionMode;
  }

  /// Check if network is suitable for real-time communication
  Future<bool> isSuitableForRealtime() async {
    final state = await checkNetwork();
    return state.isSuitableForRealtime;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicCheckTimer?.cancel();
    _stateController.close();
    _connectionTypeController.close();
    _qualityController.close();
    _transmissionModeController.close();
  }
}
