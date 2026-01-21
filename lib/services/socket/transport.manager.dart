import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'transport.service.dart';

/// Transport manager that handles fallback logic between transports.
/// Priority: WebSocket → SSE → HTTP Long Polling
class TransportManager {
  static final TransportManager _instance = TransportManager._internal();
  factory TransportManager() => _instance;
  TransportManager._internal();

  // Transport instances
  TransportService? _currentTransport;
  final WebSocketTransport _wsTransport = WebSocketTransport();
  final SSETransport _sseTransport = SSETransport();
  final LongPollingTransport _pollingTransport = LongPollingTransport();

  // Connection state
  TransportType? _currentTransportType;
  String? _authToken;
  bool _isConnecting = false;
  bool _allowReconnect = true;

  // Failure tracking for fallback logic
  int _wsFailures = 0;
  int _sseFailures = 0;
  static const int _maxFailuresBeforeFallback = 3;

  // Reconnection with exponential backoff
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 50;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);

  // Upgrade timer - periodically try to upgrade to better transport
  Timer? _upgradeTimer;
  static const Duration _upgradeCheckInterval = Duration(minutes: 5);

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
  bool get isConnected =>
      _currentTransport?.isConnected ?? false;
  TransportConnectionState get connectionState =>
      _currentTransport?.connectionState ?? TransportConnectionState.disconnected;

  Stream<TransportConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<TransportType> get transportTypeStream => _transportTypeController.stream;

  /// Connect using the best available transport with automatic fallback
  Future<bool> connect(String token) async {
    if (_isConnecting) {
      debugPrint('[TRANSPORT-MGR] Already connecting, skipping');
      return false;
    }

    _isConnecting = true;
    _authToken = token;
    _allowReconnect = true;

    debugPrint('[TRANSPORT-MGR] Starting connection attempt');

    // Try transports in order of preference
    bool connected = false;

    // 1. Try WebSocket first (if not too many failures)
    if (_wsFailures < _maxFailuresBeforeFallback) {
      debugPrint('[TRANSPORT-MGR] Attempting WebSocket connection');
      connected = await _tryTransport(_wsTransport, TransportType.websocket);
      if (connected) {
        _wsFailures = 0; // Reset on success
        _isConnecting = false;
        _startUpgradeTimer();
        return true;
      }
      _wsFailures++;
      debugPrint('[TRANSPORT-MGR] WebSocket failed (failures: $_wsFailures)');
    }

    // 2. Try SSE (if not too many failures)
    if (_sseFailures < _maxFailuresBeforeFallback) {
      debugPrint('[TRANSPORT-MGR] Attempting SSE connection');
      connected = await _tryTransport(_sseTransport, TransportType.sse);
      if (connected) {
        _sseFailures = 0;
        _isConnecting = false;
        _startUpgradeTimer();
        return true;
      }
      _sseFailures++;
      debugPrint('[TRANSPORT-MGR] SSE failed (failures: $_sseFailures)');
    }

    // 3. Try Long Polling (always available as last resort)
    debugPrint('[TRANSPORT-MGR] Attempting Long Polling connection');
    connected = await _tryTransport(_pollingTransport, TransportType.longPolling);
    if (connected) {
      _isConnecting = false;
      _startUpgradeTimer();
      return true;
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

        // Subscribe to transport events
        _subscribeToTransport(transport);

        _connectionStateController.add(TransportConnectionState.connected);
        _transportTypeController.add(type);

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
    debugPrint('[TRANSPORT-MGR] WS failures: $_wsFailures, SSE failures: $_sseFailures');
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
    debugPrint('[TRANSPORT-MGR] WS failures: $_wsFailures, SSE failures: $_sseFailures');
    if (stackTrace != null) {
      debugPrint('[TRANSPORT-MGR] Stack trace: $stackTrace');
    }
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
      _messageController.add(message);
    });

    _transportErrorSub = transport.errorStream.listen((error) {
      _errorController.add(error);
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
    } else if (_currentTransportType == TransportType.sse) {
      _sseFailures++;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[TRANSPORT-MGR] Max reconnect attempts reached');
      _errorController.add('Maximum reconnection attempts reached');
      return;
    }

    // Calculate delay with exponential backoff + jitter
    final baseDelay = _baseReconnectDelay.inMilliseconds *
        (1 << min(_reconnectAttempts, 5)); // Cap exponential at 2^5
    final jitter = Random().nextInt(1000); // Add up to 1 second jitter
    final delay = Duration(
      milliseconds: min(baseDelay + jitter, _maxReconnectDelay.inMilliseconds),
    );

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

  /// Start timer to periodically attempt upgrade to better transport
  void _startUpgradeTimer() {
    _upgradeTimer?.cancel();

    // Only start upgrade timer if we're on a fallback transport
    if (_currentTransportType == TransportType.websocket) {
      return; // Already on best transport
    }

    _upgradeTimer = Timer.periodic(_upgradeCheckInterval, (timer) {
      _attemptUpgrade();
    });

    debugPrint('[TRANSPORT-MGR] Upgrade timer started');
  }

  void _stopUpgradeTimer() {
    _upgradeTimer?.cancel();
    _upgradeTimer = null;
  }

  /// Attempt to upgrade to a better transport
  Future<void> _attemptUpgrade() async {
    if (_authToken == null || !isConnected) return;

    debugPrint('[TRANSPORT-MGR] Attempting transport upgrade');

    // Reset failure counters to allow retrying better transports
    _wsFailures = 0;
    _sseFailures = 0;

    // If on polling, try SSE
    if (_currentTransportType == TransportType.longPolling) {
      final sseTransport = SSETransport();
      final success = await sseTransport.connect(_authToken!);
      if (success) {
        await _switchTransport(sseTransport, TransportType.sse);
        return;
      }
    }

    // If on SSE or polling, try WebSocket
    if (_currentTransportType != TransportType.websocket) {
      final wsTransport = WebSocketTransport();
      final success = await wsTransport.connect(_authToken!);
      if (success) {
        await _switchTransport(wsTransport, TransportType.websocket);
        return;
      }
    }

    debugPrint('[TRANSPORT-MGR] Upgrade attempt failed, staying on current transport');
  }

  Future<void> _switchTransport(
    TransportService newTransport,
    TransportType newType,
  ) async {
    debugPrint('[TRANSPORT-MGR] Switching from ${_currentTransportType?.name} to ${newType.name}');

    // Clean up old transport
    await _cleanupCurrentTransport();

    // Set new transport
    _currentTransport = newTransport;
    _currentTransportType = newType;

    // Subscribe to new transport
    _subscribeToTransport(newTransport);

    _transportTypeController.add(newType);
    debugPrint('[TRANSPORT-MGR] Successfully switched to ${newType.name}');
  }

  Future<void> _cleanupCurrentTransport() async {
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
    _stopUpgradeTimer();
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
    _sseFailures = 0;
    _reconnectAttempts = 0;
    debugPrint('[TRANSPORT-MGR] Shutdown complete');
  }

  /// Force reconnect with fresh state
  Future<bool> reconnect() async {
    _allowReconnect = true;
    _wsFailures = 0;
    _sseFailures = 0;
    _reconnectAttempts = 0;

    await _cleanupCurrentTransport();

    if (_authToken != null) {
      return await connect(_authToken!);
    }
    return false;
  }

  /// Dispose all resources
  void dispose() {
    _reconnectTimer?.cancel();
    _stopUpgradeTimer();
    _transportConnectionSub?.cancel();
    _transportMessageSub?.cancel();
    _transportErrorSub?.cancel();

    _wsTransport.dispose();
    _sseTransport.dispose();
    _pollingTransport.dispose();

    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
    _transportTypeController.close();
  }
}

