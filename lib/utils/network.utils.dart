import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

import '../env.dart';
import '../services/cookies.service.dart';
import '../api/api_service.dart';
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
  final CookieService _cookieService = CookieService();

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
  static const Duration _pingTimeout = Duration(seconds: 5);
  static const Duration _wsTestTimeout = Duration(seconds: 10);
  static const Duration _pollingTestTimeout = Duration(seconds: 5);
  static const Duration _periodicCheckInterval = Duration(seconds: 30);
  static const int _pingRetries = 2;
  static const int _wsTestRetries = 1;
  static const int _pollingTestRetries = 1;

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
    print("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
    print("[NETWORK] Initialized performing full check...");
    print("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
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

  /// Perform a full network check (ping, WS test, polling test)
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

      // Test server reachability via ping
      final pingResult = await _pingServer();
      final isServerReachable = pingResult.success;
      final quality = NetworkQuality.fromPingLatency(pingResult.latencyMs);

      // Test WebSocket availability (only if server is reachable)
      WebSocketTestResult wsResult;
      if (isServerReachable) {
        wsResult = await _testWebSocketConnectivity();
      } else {
        wsResult = WebSocketTestResult.failure('Server unreachable');
      }

      // Test polling availability (only if server is reachable)
      PollingTestResult pollingResult;
      if (isServerReachable) {
        pollingResult = await _testPollingConnectivity();
      } else {
        pollingResult = PollingTestResult.failure('Server unreachable');
      }

      // Determine preferred transmission mode
      final preferredMode = _determinePreferredTransmissionMode(
        wsResult: wsResult,
        pollingResult: pollingResult,
        quality: quality,
      );

      // Create new state
      final newState = NetworkState(
        connectionType: connectionType,
        quality: quality,
        pingLatencyMs: pingResult.latencyMs,
        lastChecked: DateTime.now(),
        isServerReachable: isServerReachable,
        isWebSocketAvailable: wsResult.isAvailable,
        isPollingAvailable: pollingResult.isAvailable,
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

  /// Ping the server to check reachability and latency
  Future<PingTestResult> _pingServer() async {
    // Use the root endpoint for ping
    final pingUrl = '${Environment.baseUrl}/';

    for (int attempt = 0; attempt < _pingRetries; attempt++) {
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
        if (attempt == _pingRetries - 1) {
          return PingTestResult.failure(e.toString());
        }
        // Wait a bit before retry
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return PingTestResult.failure('All ping attempts failed');
  }

  /// Test WebSocket connectivity
  Future<WebSocketTestResult> _testWebSocketConnectivity() async {
    bool tokenRefreshed = false;

    for (int attempt = 0; attempt < _wsTestRetries; attempt++) {
      try {
        var accessToken = await _cookieService.getAccessToken();
        if (accessToken == null) {
          throw Exception('No access token found in cookies');
        }

        final stopwatch = Stopwatch()..start();

        // Try to connect to WebSocket with proper token encoding
        final wsUrl =
            '${Environment.websocketUrl}?token=${Uri.encodeComponent(accessToken)}';
        debugPrint('[NETWORK] Testing WebSocket connectivity: $wsUrl');

        final socket = await WebSocket.connect(wsUrl).timeout(_wsTestTimeout);

        // Listen for immediate auth errors (server sends error message before closing)
        bool authErrorDetected = false;

        socket.listen(
          (message) {
            try {
              final jsonMap = json.decode(message) as Map<String, dynamic>;
              final messageType = jsonMap['type'] as String?;
              final errorCode = jsonMap['error_code'] as String?;

              if (messageType == 'socket:error' &&
                  (errorCode == 'AUTH_REQUIRED' ||
                      errorCode == 'AUTH_INVALID')) {
                debugPrint(
                  '[NETWORK] Auth error detected in WebSocket test: $errorCode',
                );
                authErrorDetected = true;
              }
            } catch (_) {
              // Ignore parse errors
            }
          },
          onError: (_) {},
          onDone: () {},
        );

        // Wait a bit to check for auth errors (server sends error before closing)
        await Future.delayed(const Duration(milliseconds: 500));

        if (authErrorDetected) {
          await socket.close();

          // Try to refresh token if we haven't already
          if (!tokenRefreshed) {
            debugPrint(
              '[NETWORK] Attempting token refresh for WebSocket test...',
            );
            final refreshSuccess = await _refreshTokenForTest();
            if (refreshSuccess) {
              tokenRefreshed = true;
              // Retry with new token
              await Future.delayed(const Duration(milliseconds: 300));
              continue; // Retry with refreshed token
            }
          }

          // If auth error but endpoint is reachable, consider it available
          return WebSocketTestResult.success(100);
        }

        stopwatch.stop();
        await socket.close();

        return WebSocketTestResult.success(stopwatch.elapsedMilliseconds);
      } on SocketException catch (e) {
        if (attempt == _wsTestRetries - 1) {
          return WebSocketTestResult.failure('Socket error: ${e.message}');
        }
      } on TimeoutException {
        if (attempt == _wsTestRetries - 1) {
          return WebSocketTestResult.failure('Connection timeout');
        }
      } catch (e) {
        // Check if it's an auth-related error
        final errorStr = e.toString();
        if (errorStr.contains('4001') ||
            errorStr.contains('401') ||
            errorStr.contains('403') ||
            errorStr.contains('authentication') ||
            errorStr.contains('token')) {
          // Try to refresh token if we haven't already
          if (!tokenRefreshed) {
            debugPrint(
              '[NETWORK] Auth error in WebSocket test, attempting token refresh...',
            );
            final refreshSuccess = await _refreshTokenForTest();
            if (refreshSuccess) {
              tokenRefreshed = true;
              // Retry with new token
              await Future.delayed(const Duration(milliseconds: 300));
              continue; // Retry with refreshed token
            }
          }

          // Endpoint is reachable, just needs auth - consider it available
          return WebSocketTestResult.success(100);
        }

        if (attempt == _wsTestRetries - 1) {
          return WebSocketTestResult.failure(e.toString());
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    return WebSocketTestResult.failure('WebSocket test failed');
  }

  /// Refresh token for connectivity test
  Future<bool> _refreshTokenForTest() async {
    try {
      final apiService = ApiService();
      final dio = apiService.client.dio;

      final response = await dio.post(
        '${Environment.baseUrl}/auth/refresh-mobile',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 || status == 401 || status == 404),
        ),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '[NETWORK] ✅ Token refreshed successfully for connectivity test',
        );
        return true;
      }

      debugPrint(
        '[NETWORK] ❌ Token refresh failed for connectivity test (Status: ${response.statusCode})',
      );
      return false;
    } catch (e) {
      debugPrint('[NETWORK] ❌ Token refresh error in connectivity test: $e');
      return false;
    }
  }

  /// Test polling connectivity
  Future<PollingTestResult> _testPollingConnectivity() async {
    // Test polling endpoint (might need auth, but we check reachability)
    final pollingUrl = '${Environment.baseUrl}/chat/poll/poll-pending-messages';

    for (int attempt = 0; attempt < _pollingTestRetries; attempt++) {
      try {
        final stopwatch = Stopwatch()..start();

        // Try a simple GET request (will likely fail auth, but checks reachability)
        final response = await http
            .get(Uri.parse(pollingUrl))
            .timeout(_pollingTestTimeout);

        stopwatch.stop();

        // Even if auth fails (401/403), endpoint is reachable
        if (response.statusCode == 200 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          return PollingTestResult.success(stopwatch.elapsedMilliseconds);
        } else {
          return PollingTestResult.failure(
            'Server returned status ${response.statusCode}',
          );
        }
      } catch (e) {
        if (attempt == _pollingTestRetries - 1) {
          return PollingTestResult.failure(e.toString());
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return PollingTestResult.failure('Polling test failed');
  }

  /// Determine preferred transmission mode based on test results
  TransmissionMode _determinePreferredTransmissionMode({
    required WebSocketTestResult wsResult,
    required PollingTestResult pollingResult,
    required NetworkQuality quality,
  }) {
    // If WebSocket is available and quality is acceptable, prefer WebSocket
    if (wsResult.isAvailable && quality.isAcceptable) {
      return TransmissionMode.websocket;
    }

    // If polling is available, use it as fallback
    if (pollingResult.isAvailable) {
      return TransmissionMode.longPolling;
    }

    // No transmission available
    return TransmissionMode.none;
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
