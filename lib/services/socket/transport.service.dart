import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../env.dart';

/// Transport type enumeration
enum TransportType {
  websocket,
  sse,
  longPolling,
}

/// Connection state for transports
enum TransportConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Abstract transport interface
abstract class TransportService {
  /// The type of transport
  TransportType get transportType;

  /// Current connection state
  TransportConnectionState get connectionState;

  /// Stream of connection state changes
  Stream<TransportConnectionState> get connectionStateStream;

  /// Stream of incoming messages
  Stream<Map<String, dynamic>> get messageStream;

  /// Stream of errors
  Stream<String> get errorStream;

  /// Connect to the server
  Future<bool> connect(String token);

  /// Disconnect from the server
  Future<void> disconnect();

  /// Send a message to the server
  Future<bool> sendMessage(Map<String, dynamic> message);

  /// Check if connected
  bool get isConnected;

  /// Dispose resources
  void dispose();
}

// =============================================================================
// WebSocket Transport Implementation
// =============================================================================

class WebSocketTransport implements TransportService {
  WebSocket? _socket;
  TransportConnectionState _connectionState =
      TransportConnectionState.disconnected;

  final StreamController<TransportConnectionState> _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Heartbeat
  Timer? _pingTimer;
  int _missedPongs = 0;
  static const Duration _pingInterval = Duration(seconds: 30);
  static const int _maxMissedPongs = 3;

  @override
  TransportType get transportType => TransportType.websocket;

  @override
  TransportConnectionState get connectionState => _connectionState;

  @override
  Stream<TransportConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isConnected =>
      _connectionState == TransportConnectionState.connected;

  void _updateConnectionState(TransportConnectionState newState) {
    _connectionState = newState;
    _connectionStateController.add(newState);
  }

  @override
  Future<bool> connect(String token) async {
    if (_connectionState == TransportConnectionState.connecting ||
        _connectionState == TransportConnectionState.connected) {
      return true;
    }

    try {
      _updateConnectionState(TransportConnectionState.connecting);

      final wsUrl =
          '${Environment.websocketUrl}?token=${Uri.encodeComponent(token)}';
      debugPrint('[WS-TRANSPORT] Connecting to: $wsUrl');

      _socket = await WebSocket.connect(wsUrl);

      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _missedPongs = 0;
      _updateConnectionState(TransportConnectionState.connected);
      _startHeartbeat();

      debugPrint('[WS-TRANSPORT] Connected successfully');
      return true;
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Connection failed: $e');
      _updateConnectionState(TransportConnectionState.error);
      _errorController.add('WebSocket connection failed: $e');
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      Map<String, dynamic>? jsonMap;

      if (message is String) {
        jsonMap = json.decode(message) as Map<String, dynamic>;
      } else if (message is Map<String, dynamic>) {
        jsonMap = message;
      } else {
        return;
      }

      final messageType = jsonMap['type'] as String?;

      // Handle ping/pong internally
      if (messageType == 'ping') {
        _sendPong();
        return;
      } else if (messageType == 'pong') {
        _handlePongReceived();
        return;
      }

      _messageController.add(jsonMap);
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Error parsing message: $e');
      _errorController.add('Error parsing message: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('[WS-TRANSPORT] Error: $error');
    _updateConnectionState(TransportConnectionState.error);
    _errorController.add(error.toString());
  }

  void _handleDisconnection() {
    debugPrint('[WS-TRANSPORT] Disconnected');
    _stopHeartbeat();
    _updateConnectionState(TransportConnectionState.disconnected);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (_connectionState != TransportConnectionState.connected) {
        _stopHeartbeat();
        return;
      }

      if (_missedPongs >= _maxMissedPongs) {
        debugPrint('[WS-TRANSPORT] Connection stale, missed $_missedPongs pongs');
        _stopHeartbeat();
        _handleError('Connection stale - missed pongs');
        return;
      }

      _sendPing();
    });
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _sendPing() {
    if (_socket == null) return;
    try {
      _socket!.add(json.encode({
        'type': 'ping',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _missedPongs++;
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Error sending ping: $e');
    }
  }

  void _sendPong() {
    if (_socket == null) return;
    try {
      _socket!.add(json.encode({
        'type': 'pong',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Error sending pong: $e');
    }
  }

  void _handlePongReceived() {
    _missedPongs = 0;
  }

  @override
  Future<void> disconnect() async {
    _stopHeartbeat();
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    _missedPongs = 0;
    _updateConnectionState(TransportConnectionState.disconnected);
  }

  @override
  Future<bool> sendMessage(Map<String, dynamic> message) async {
    if (_socket == null || !isConnected) {
      return false;
    }

    try {
      _socket!.add(json.encode(message));
      return true;
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Error sending message: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _socket?.close();
    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
  }
}

// =============================================================================
// SSE (Server-Sent Events) Transport Implementation
// =============================================================================

class SSETransport implements TransportService {
  http.Client? _client;
  StreamSubscription? _subscription;
  TransportConnectionState _connectionState =
      TransportConnectionState.disconnected;
  String? _token;

  final StreamController<TransportConnectionState> _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  @override
  TransportType get transportType => TransportType.sse;

  @override
  TransportConnectionState get connectionState => _connectionState;

  @override
  Stream<TransportConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isConnected =>
      _connectionState == TransportConnectionState.connected;

  void _updateConnectionState(TransportConnectionState newState) {
    _connectionState = newState;
    _connectionStateController.add(newState);
  }

  @override
  Future<bool> connect(String token) async {
    if (_connectionState == TransportConnectionState.connecting ||
        _connectionState == TransportConnectionState.connected) {
      return true;
    }

    try {
      _updateConnectionState(TransportConnectionState.connecting);
      _token = token;

      final sseUrl =
          '${Environment.sseUrl}?token=${Uri.encodeComponent(token)}';
      debugPrint('[SSE-TRANSPORT] Connecting to: $sseUrl');

      _client = http.Client();
      final request = http.Request('GET', Uri.parse(sseUrl));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('SSE connection failed with status ${response.statusCode}');
      }

      _updateConnectionState(TransportConnectionState.connected);
      debugPrint('[SSE-TRANSPORT] Connected successfully');

      // Listen to SSE stream
      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String dataBuffer = '';

      _subscription = lineStream.listen(
        (line) {
          // Handle SSE format
          if (line.startsWith('data: ')) {
            dataBuffer = line.substring(6);
          } else if (line.isEmpty && dataBuffer.isNotEmpty) {
            // End of event
            try {
              final jsonData = json.decode(dataBuffer) as Map<String, dynamic>;
              _messageController.add(jsonData);
            } catch (e) {
              debugPrint('[SSE-TRANSPORT] Error parsing SSE data: $e');
            }
            dataBuffer = '';
          } else if (line.startsWith(':')) {
            // Comment/keepalive, ignore
          }
        },
        onError: (error) {
          debugPrint('[SSE-TRANSPORT] Stream error: $error');
          _updateConnectionState(TransportConnectionState.error);
          _errorController.add(error.toString());
        },
        onDone: () {
          debugPrint('[SSE-TRANSPORT] Stream closed');
          _updateConnectionState(TransportConnectionState.disconnected);
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      debugPrint('[SSE-TRANSPORT] Connection failed: $e');
      _updateConnectionState(TransportConnectionState.error);
      _errorController.add('SSE connection failed: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _updateConnectionState(TransportConnectionState.disconnected);
  }

  @override
  Future<bool> sendMessage(Map<String, dynamic> message) async {
    // SSE is receive-only, need to use HTTP POST for sending
    if (_token == null) return false;

    try {
      final pollUrl =
          '${Environment.pollingUrl}?token=${Uri.encodeComponent(_token!)}';
      final response = await http.post(
        Uri.parse(pollUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(message),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SSE-TRANSPORT] Error sending message: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.close();
    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
  }
}

// =============================================================================
// HTTP Long Polling Transport Implementation
// =============================================================================

class LongPollingTransport implements TransportService {
  http.Client? _client;
  TransportConnectionState _connectionState =
      TransportConnectionState.disconnected;
  String? _token;
  String? _lastMessageId;
  bool _isPolling = false;
  Timer? _pollTimer;

  final StreamController<TransportConnectionState> _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  @override
  TransportType get transportType => TransportType.longPolling;

  @override
  TransportConnectionState get connectionState => _connectionState;

  @override
  Stream<TransportConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isConnected =>
      _connectionState == TransportConnectionState.connected;

  void _updateConnectionState(TransportConnectionState newState) {
    _connectionState = newState;
    _connectionStateController.add(newState);
  }

  @override
  Future<bool> connect(String token) async {
    if (_connectionState == TransportConnectionState.connecting ||
        _connectionState == TransportConnectionState.connected) {
      return true;
    }

    try {
      _updateConnectionState(TransportConnectionState.connecting);
      _token = token;
      _client = http.Client();

      debugPrint('[POLLING-TRANSPORT] Starting long polling');

      // Start polling loop
      _isPolling = true;
      _startPolling();

      _updateConnectionState(TransportConnectionState.connected);
      debugPrint('[POLLING-TRANSPORT] Connected successfully');
      return true;
    } catch (e) {
      debugPrint('[POLLING-TRANSPORT] Connection failed: $e');
      _updateConnectionState(TransportConnectionState.error);
      _errorController.add('Long polling connection failed: $e');
      return false;
    }
  }

  void _startPolling() {
    _poll();
  }

  Future<void> _poll() async {
    if (!_isPolling || _token == null) return;

    try {
      var pollUrl = '${Environment.pollingUrl}?token=${Uri.encodeComponent(_token!)}';
      if (_lastMessageId != null) {
        pollUrl += '&last_message_id=${Uri.encodeComponent(_lastMessageId!)}';
      }

      final response = await _client!
          .get(Uri.parse(pollUrl))
          .timeout(const Duration(seconds: 35)); // Slightly longer than server timeout

      if (!_isPolling) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messages = data['messages'] as List<dynamic>?;
        _lastMessageId = data['last_message_id'] as String?;

        if (messages != null) {
          for (final msg in messages) {
            if (msg is Map<String, dynamic>) {
              _messageController.add(msg);
            }
          }
        }
      } else if (response.statusCode == 401) {
        _updateConnectionState(TransportConnectionState.error);
        _errorController.add('Authentication failed');
        _isPolling = false;
        return;
      }

      // Continue polling
      if (_isPolling) {
        // Small delay before next poll to prevent tight loop on errors
        _pollTimer = Timer(const Duration(milliseconds: 100), _poll);
      }
    } catch (e) {
      if (!_isPolling) return;

      debugPrint('[POLLING-TRANSPORT] Poll error: $e');

      // Retry with backoff on error
      if (_isPolling) {
        _pollTimer = Timer(const Duration(seconds: 5), _poll);
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _client?.close();
    _client = null;
    _lastMessageId = null;
    _updateConnectionState(TransportConnectionState.disconnected);
  }

  @override
  Future<bool> sendMessage(Map<String, dynamic> message) async {
    if (_token == null) return false;

    try {
      final pollUrl =
          '${Environment.pollingUrl}?token=${Uri.encodeComponent(_token!)}';
      final response = await http.post(
        Uri.parse(pollUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(message),
      );

      if (response.statusCode == 200) {
        // Check if there's a response message (like ack)
        try {
          final responseData = json.decode(response.body) as Map<String, dynamic>;
          if (responseData['type'] != null) {
            _messageController.add(responseData);
          }
        } catch (_) {
          // Ignore parse errors for simple success responses
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[POLLING-TRANSPORT] Error sending message: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _isPolling = false;
    _pollTimer?.cancel();
    _client?.close();
    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
  }
}

