import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../utils/network.utils.dart';
import '../../types/network.types.dart';
import '../../api/api_service.dart';
import '../../services/cookies.service.dart';
import '../../utils/navigation-helper.util.dart';
import 'transport.service.dart';

/// Transport manager that handles fallback logic between transports.
/// Priority: WebSocket → HTTP Long Polling
/// When in polling mode, continuously attempts to reconnect to WebSocket in background
class TransportManager {
  static final TransportManager _instance = TransportManager._internal();
  factory TransportManager() => _instance;
  TransportManager._internal();

  // Network connectivity utility
  final NetworkConnectivityUtil _networkUtil = NetworkConnectivityUtil();

  // Services for token refresh
  final CookieService _cookieService = CookieService();
  final ApiService _apiService = ApiService();

  // Transport instances
  TransportService? _currentTransport;
  final WebSocketTransport _wsTransport = WebSocketTransport();
  final LongPollingTransport _pollingTransport = LongPollingTransport();

  // Auth error tracking
  bool _isRefreshingToken = false;
  int _authErrorCount = 0;
  static const int _maxAuthRetries = 2;

  // Connection state
  TransportType? _currentTransportType;
  String? _authToken;
  bool _isConnecting = false;
  bool _allowReconnect = true;

  // Failure tracking for fallback logic
  int _wsFailures = 0;
  static const int _maxFailuresBeforeFallback = 3;

  // Network monitoring subscriptions
  StreamSubscription<TransmissionMode>? _transmissionModeSubscription;
  StreamSubscription<NetworkState>? _networkStateSubscription;

  // Background WebSocket reconnection when in polling mode
  Timer? _wsReconnectTimer;
  static const Duration _wsReconnectInterval = Duration(seconds: 3);

  // Reconnection with exponential backoff
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 50;
  static const Duration _baseReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);

  // Track if disconnectivity popup is shown
  bool _isDisconnectivityPopupShown = false;

  // Stream controllers
  final StreamController<TransportConnectionState> _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<TransportType> _transportTypeController =
      StreamController<TransportType>.broadcast();

  StreamSubscription? _transportConnectionSub;
  StreamSubscription? _transportMessageSub;
  StreamSubscription? _transportErrorSub;

  // Getters
  TransportType? get currentTransportType => _currentTransportType;
  bool get isConnected => _currentTransport?.isConnected ?? false;
  TransportConnectionState get connectionState =>
      _currentTransport?.connectionState ??
      TransportConnectionState.disconnected;

  Stream<TransportConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<TransportType> get transportTypeStream =>
      _transportTypeController.stream;

  /// Get current network state
  NetworkState get currentNetworkState => _networkUtil.currentState;

  /// Get network state stream
  Stream<NetworkState> get networkStateStream => _networkUtil.stateStream;

  /// Get transmission mode stream
  Stream<TransmissionMode> get transmissionModeStream =>
      _networkUtil.transmissionModeStream;

  /// Connect using the best available transport with automatic fallback
  /// Uses network utility to determine optimal transport mode
  Future<bool> connect(String token) async {
    if (_isConnecting) {
      debugPrint('[TRANSPORT-MGR] Already connecting, skipping');
      return false;
    }

    _isConnecting = true;
    _authToken = token;
    _allowReconnect = true;

    debugPrint('[TRANSPORT-MGR] Starting connection attempt');

    // Check network state first
    final networkState = await _networkUtil.checkNetwork();
    debugPrint('[TRANSPORT-MGR] Network state: $networkState');

    // If network is not available, schedule reconnect
    if (!networkState.isAvailable) {
      debugPrint('[TRANSPORT-MGR] Network not available, scheduling reconnect');
      _isConnecting = false;
      if (_allowReconnect) {
        _scheduleReconnect();
      }
      return false;
    }

    // Determine preferred transport based on network state
    final preferredMode = networkState.preferredTransmissionMode;
    bool connected = false;

    // Try preferred transport first, then fallback
    if (preferredMode == TransmissionMode.websocket &&
        networkState.isWebSocketAvailable &&
        _wsFailures < _maxFailuresBeforeFallback) {
      debugPrint(
        '[TRANSPORT-MGR] Network recommends WebSocket, attempting connection',
      );
      connected = await _tryTransport(_wsTransport, TransportType.websocket);
      if (connected) {
        _wsFailures = 0;
        _isConnecting = false;
        _stopBackgroundWsReconnect();
        return true;
      }
      _wsFailures++;
      debugPrint('[TRANSPORT-MGR] WebSocket failed (failures: $_wsFailures)');
    }

    // Fallback to polling if WebSocket failed or not preferred
    // Try polling if server is reachable (internet available), even if network check says polling unavailable
    // This ensures fallback works when WebSocket is blocked but HTTP works
    if (!connected && networkState.isServerReachable) {
      debugPrint(
        '[TRANSPORT-MGR] Attempting Long Polling connection (fallback from WebSocket)',
      );
      connected = await _tryTransport(
        _pollingTransport,
        TransportType.longPolling,
      );
      if (connected) {
        _isConnecting = false;
        _startBackgroundWsReconnect();
        return true;
      }
    }

    // If preferred mode is polling but it failed, try WebSocket as last resort
    if (!connected &&
        preferredMode == TransmissionMode.longPolling &&
        networkState.isWebSocketAvailable &&
        _wsFailures < _maxFailuresBeforeFallback) {
      debugPrint(
        '[TRANSPORT-MGR] Polling failed, trying WebSocket as fallback',
      );
      connected = await _tryTransport(_wsTransport, TransportType.websocket);
      if (connected) {
        _wsFailures = 0;
        _isConnecting = false;
        _stopBackgroundWsReconnect();
        return true;
      }
      _wsFailures++;
    }

    _isConnecting = false;
    debugPrint('[TRANSPORT-MGR] All transports failed');

    // Schedule reconnect
    if (_allowReconnect) {
      _scheduleReconnect();
    }

    return false;
  }

  Future<bool> _tryTransport(
    TransportService transport,
    TransportType type,
  ) async {
    final startTime = DateTime.now();
    try {
      // Clean up previous transport
      await _cleanupCurrentTransport();

      final success = await transport.connect(_authToken!);
      final duration = DateTime.now().difference(startTime);

      if (success) {
        _currentTransport = transport;
        _currentTransportType = type;
        _reconnectAttempts = 0;
        _authErrorCount = 0; // Reset auth error count on successful connection
        _isDisconnectivityPopupShown =
            false; // Reset popup flag on successful connection

        // Subscribe to transport events
        _subscribeToTransport(transport);

        _connectionStateController.add(TransportConnectionState.connected);
        _transportTypeController.add(type);

        // Gap-fill: immediately poll for any messages missed during the gap.
        // Pass _messageController.add so synced messages are routed through
        // the manager's stream regardless of which transport is now active.
        debugPrint(
          '[TRANSPORT-MGR] Performing gap-fill poll after successful connection',
        );
        _pollingTransport.syncMissedWsEventsOnReconnect(
          onMessage: _messageController.add,
        );
        debugPrint('[TRANSPORT-MGR] Performed Gap-fill poll re-connection');

        _logConnectionSuccess(type, duration);
        return true;
      } else {
        _logConnectionFailure(type, 'Connection returned false', duration);
      }
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _logConnectionFailure(type, e.toString(), duration, stackTrace);
    }
    return false;
  }

  void _logConnectionSuccess(TransportType type, Duration duration) {
    debugPrint('[TRANSPORT-MGR] ✅ Connected via ${type.name}');
    debugPrint('[TRANSPORT-MGR] Connection time: ${duration.inMilliseconds}ms');
    debugPrint('[TRANSPORT-MGR] Reconnect attempts: $_reconnectAttempts');
    debugPrint('[TRANSPORT-MGR] WS failures: $_wsFailures');
  }

  void _logConnectionFailure(
    TransportType type,
    String error,
    Duration duration, [
    StackTrace? stackTrace,
  ]) {
    debugPrint('[TRANSPORT-MGR] ❌ Failed to connect via ${type.name}');
    debugPrint('[TRANSPORT-MGR] Error: $error');
    debugPrint('[TRANSPORT-MGR] Duration: ${duration.inMilliseconds}ms');
    debugPrint('[TRANSPORT-MGR] Reconnect attempts: $_reconnectAttempts');
    debugPrint('[TRANSPORT-MGR] WS failures: $_wsFailures');
    if (stackTrace != null) {
      debugPrint('[TRANSPORT-MGR] Stack trace: $stackTrace');
    }
  }

  /// Trigger an immediate gap-fill poll on the current polling transport.
  /// Safe to call even when using WebSocket (no-op if not in polling mode).
  void pollNow() {
    _pollingTransport.syncMissedWsEventsOnReconnect(
      onMessage: _messageController.add,
    );
  }

  void _subscribeToTransport(TransportService transport) {
    _transportConnectionSub?.cancel();
    _transportMessageSub?.cancel();
    _transportErrorSub?.cancel();

    _transportConnectionSub = transport.connectionStateStream.listen((state) {
      _connectionStateController.add(state);

      // Handle disconnection
      if (state == TransportConnectionState.disconnected ||
          state == TransportConnectionState.error) {
        debugPrint('[TRANSPORT-MGR] Transport disconnected/error, handling...');
        _handleTransportDisconnection();
      }
    });

    _transportMessageSub = transport.messageStream.listen((message) {
      print("-----------------------------------------------------------");
      print('[TRANSPORT-MGR] Received message: $message');
      print("-----------------------------------------------------------");
      _messageController.add(message);
    });

    _transportErrorSub = transport.errorStream.listen((error) {
      // Check for authentication errors
      if (error.toString().startsWith('AUTH_ERROR:')) {
        debugPrint('[TRANSPORT-MGR] Authentication error detected: $error');
        _handleAuthenticationError();
      } else {
        _errorController.add(error);
      }
    });
  }

  void _handleTransportDisconnection() {
    if (!_allowReconnect) {
      debugPrint('[TRANSPORT-MGR] Reconnect not allowed, skipping');
      return;
    }

    // Increment failure count for current transport type
    if (_currentTransportType == TransportType.websocket) {
      _wsFailures++;
      _stopBackgroundWsReconnect();
    }

    _scheduleReconnect();
  }

  /// Handle authentication errors by refreshing token and retrying connection
  Future<void> _handleAuthenticationError() async {
    if (_isRefreshingToken) {
      debugPrint('[TRANSPORT-MGR] Token refresh already in progress');
      return;
    }

    if (_authErrorCount >= _maxAuthRetries) {
      debugPrint('[TRANSPORT-MGR] Max auth retries reached, giving up');
      _errorController.add('Authentication failed after multiple attempts');
      return;
    }

    _isRefreshingToken = true;
    _authErrorCount++;

    try {
      debugPrint('[TRANSPORT-MGR] Attempting to refresh token...');

      // Refresh token using the API client
      final dio = _apiService.client.dio;
      final response = await dio.post(
        '${dio.options.baseUrl}/auth/refresh-mobile',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 || status == 401 || status == 404),
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('[TRANSPORT-MGR] ✅ Token refreshed successfully');

        // Get new access token from cookies
        final newToken = await _cookieService.getAccessToken();

        if (newToken != null) {
          // Reset auth error count on successful refresh
          _authErrorCount = 0;

          // Disconnect current transport
          await _cleanupCurrentTransport();

          // Retry connection with new token
          debugPrint(
            '[TRANSPORT-MGR] Retrying connection with refreshed token...',
          );
          _authToken = newToken;

          // Small delay before retry
          await Future.delayed(const Duration(milliseconds: 500));

          final success = await connect(newToken);
          if (success) {
            debugPrint(
              '[TRANSPORT-MGR] ✅ Reconnected successfully after token refresh',
            );
          } else {
            debugPrint(
              '[TRANSPORT-MGR] ❌ Reconnection failed after token refresh',
            );
          }
        } else {
          debugPrint('[TRANSPORT-MGR] ❌ No access token found after refresh');
          _errorController.add('Failed to get new access token after refresh');
        }
      } else {
        debugPrint(
          '[TRANSPORT-MGR] ❌ Token refresh failed (Status: ${response.statusCode})',
        );
        _errorController.add('Token refresh failed - please login again');
      }
    } catch (e) {
      debugPrint('[TRANSPORT-MGR] ❌ Token refresh error: $e');
      _errorController.add('Token refresh error: $e');
    } finally {
      _isRefreshingToken = false;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[TRANSPORT-MGR] Max reconnect attempts reached');
      _errorController.add('Maximum reconnection attempts reached');

      // Show disconnectivity popup if not already shown
      if (!_isDisconnectivityPopupShown) {
        _showDisconnectivityPopup();
      }
      return;
    }

    // Calculate delay with exponential backoff + jitter
    // final baseDelay =
    //     _baseReconnectDelay.inMilliseconds *
    //     (1 << min(_reconnectAttempts, 5)); // Cap exponential at 2^5
    // final jitter = Random().nextInt(1000); // Add up to 1 second jitter
    // final delay = Duration(
    //   milliseconds: min(baseDelay + jitter, _maxReconnectDelay.inMilliseconds),
    // );
    final delay = Duration(seconds: 2);

    _reconnectAttempts++;
    debugPrint(
      '[TRANSPORT-MGR] Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s',
    );

    _connectionStateController.add(TransportConnectionState.reconnecting);

    _reconnectTimer = Timer(delay, () {
      if (_allowReconnect && _authToken != null) {
        connect(_authToken!);
      }
    });
  }

  /// Restart reconnect cycle after popup is closed
  void _restartReconnectCycle() {
    debugPrint('[TRANSPORT-MGR] Restarting reconnect cycle after popup closed');
    _isDisconnectivityPopupShown = false;
    _reconnectAttempts = 0; // Reset attempts to allow new cycle

    // Start reconnecting again
    if (_allowReconnect && _authToken != null) {
      connect(_authToken!);
    }
  }

  /// Show internet disconnectivity popup
  void _showDisconnectivityPopup() {
    final navigator = NavigationHelper.navigator;
    final context = navigator?.context;
    if (context == null) {
      debugPrint('[TRANSPORT-MGR] Navigator not available, cannot show popup');
      return;
    }

    _isDisconnectivityPopupShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'No Internet Connection',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: const Text(
              'Unable to connect to the server. Please check your internet connection and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Reconnect'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // This callback is called when dialog is closed (via back button or button press)
      _restartReconnectCycle();
    });
  }

  /// Start background WebSocket reconnection attempts when in polling mode
  /// This keeps trying to reconnect to WebSocket when network conditions improve
  void _startBackgroundWsReconnect() {
    _stopBackgroundWsReconnect();

    // Listen to network state changes to upgrade when WebSocket becomes available
    _networkStateSubscription?.cancel();
    _networkStateSubscription = _networkUtil.stateStream.listen((networkState) {
      // Only upgrade if we're in polling mode and WebSocket becomes available
      if (_currentTransportType == TransportType.longPolling &&
          !_isConnecting &&
          networkState.isWebSocketAvailable &&
          networkState.preferredTransmissionMode ==
              TransmissionMode.websocket &&
          _wsFailures < _maxFailuresBeforeFallback) {
        debugPrint(
          '[TRANSPORT-MGR] Network conditions improved, attempting WebSocket upgrade',
        );
        _attemptWebSocketUpgrade();
      }
    });

    // Also use periodic timer as backup
    _wsReconnectTimer = Timer.periodic(_wsReconnectInterval, (timer) async {
      // Only try if we're still in polling mode and not already connecting
      if (_currentTransportType != TransportType.longPolling || _isConnecting) {
        return;
      }

      // Check network state before attempting
      final networkState = _networkUtil.currentState;
      if (!networkState.isWebSocketAvailable ||
          networkState.preferredTransmissionMode !=
              TransmissionMode.websocket) {
        return; // Don't try if network doesn't support WebSocket
      }

      // Don't try if we've had too many failures recently
      if (_wsFailures >= _maxFailuresBeforeFallback) {
        // Reset failures after some time to allow retry
        if (_reconnectAttempts % 5 == 0) {
          _wsFailures = 0;
        }
        return;
      }

      debugPrint('[TRANSPORT-MGR] Background WebSocket reconnection attempt');
      await _attemptWebSocketUpgrade();
    });

    debugPrint('[TRANSPORT-MGR] Background WebSocket reconnection started');
  }

  /// Attempt to upgrade from polling to WebSocket
  Future<void> _attemptWebSocketUpgrade() async {
    if (_authToken == null || _isConnecting) return;

    final testWsTransport = WebSocketTransport();
    final success = await testWsTransport.connect(_authToken!);

    if (success) {
      debugPrint(
        '[TRANSPORT-MGR] Background WebSocket reconnection successful, switching transport',
      );
      await _switchTransport(testWsTransport, TransportType.websocket);
      _stopBackgroundWsReconnect(); // Stop timer since we've upgraded
    } else {
      testWsTransport.dispose();
      _wsFailures++;
    }
  }

  void _stopBackgroundWsReconnect() {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _networkStateSubscription?.cancel();
    _networkStateSubscription = null;
  }

  Future<void> _switchTransport(
    TransportService newTransport,
    TransportType newType,
  ) async {
    debugPrint(
      '[TRANSPORT-MGR] Switching from ${_currentTransportType?.name} to ${newType.name}',
    );

    // Clean up old transport
    await _cleanupCurrentTransport();

    // Set new transport
    _currentTransport = newTransport;
    _currentTransportType = newType;
    _wsFailures = 0; // Reset failures on successful switch

    if (newType == TransportType.websocket) {
      _stopBackgroundWsReconnect(); // Stop background reconnection when on WebSocket
    } else if (newType == TransportType.longPolling) {
      _startBackgroundWsReconnect(); // Start background reconnection when in polling
    }

    // Subscribe to new transport
    _subscribeToTransport(newTransport);

    _transportTypeController.add(newType);
    debugPrint('[TRANSPORT-MGR] Successfully switched to ${newType.name}');
  }

  Future<void> _cleanupCurrentTransport() async {
    _stopBackgroundWsReconnect();
    _transportConnectionSub?.cancel();
    _transportMessageSub?.cancel();
    _transportErrorSub?.cancel();

    if (_currentTransport != null) {
      await _currentTransport!.disconnect();
    }
  }

  /// Send a message through the current transport
  Future<bool> sendMessage(Map<String, dynamic> message) async {
    if (_currentTransport == null || !isConnected) {
      debugPrint('[TRANSPORT-MGR] Cannot send message - not connected');
      return false;
    }

    return await _currentTransport!.sendMessage(message);
  }

  /// Disconnect and stop all reconnection attempts
  Future<void> disconnect() async {
    _allowReconnect = false;
    _reconnectTimer?.cancel();
    _stopBackgroundWsReconnect();
    await _cleanupCurrentTransport();
    _currentTransport = null;
    _currentTransportType = null;
    _connectionStateController.add(TransportConnectionState.disconnected);
    debugPrint('[TRANSPORT-MGR] Disconnected');
  }

  /// Shutdown completely (e.g., for logout)
  Future<void> shutdown() async {
    await disconnect();
    _authToken = null;
    _wsFailures = 0;
    _reconnectAttempts = 0;
    _isDisconnectivityPopupShown = false;
    debugPrint('[TRANSPORT-MGR] Shutdown complete');
  }

  /// Force reconnect with fresh state
  /// Checks network state first and uses optimal transport
  Future<bool> reconnect() async {
    _allowReconnect = true;
    _wsFailures = 0;
    _reconnectAttempts = 0;
    _isDisconnectivityPopupShown = false; // Reset popup flag

    await _cleanupCurrentTransport();

    // Check network before reconnecting
    final networkState = await _networkUtil.checkNetwork();
    if (!networkState.isAvailable) {
      debugPrint('[TRANSPORT-MGR] Network not available for reconnect');
      return false;
    }

    if (_authToken != null) {
      return await connect(_authToken!);
    }
    return false;
  }

  /// Dispose all resources
  void dispose() {
    _reconnectTimer?.cancel();
    _stopBackgroundWsReconnect();
    _transportConnectionSub?.cancel();
    _transportMessageSub?.cancel();
    _transportErrorSub?.cancel();
    _transmissionModeSubscription?.cancel();
    _networkStateSubscription?.cancel();

    _wsTransport.dispose();
    _pollingTransport.dispose();

    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
    _transportTypeController.close();
  }
}
