import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:amigo/api/api_service.dart';
import 'package:amigo/api/clients/chat_client.dart';
import 'package:amigo/services/socket/ws-message.handler.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

import '../../env.dart';

/// Transport type enumeration
enum TransportType { websocket, longPolling }

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
  static const Duration _pingInterval = Duration(seconds: 12);
  static const int _maxMissedPongs = 2;

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

      _socket = await WebSocket.connect(
        wsUrl,
        compression: CompressionOptions(
          enabled: true,
          clientMaxWindowBits: 15,
          serverMaxWindowBits: 15,
          clientNoContextTakeover:
              false, // keep context between messages (better compression)
          serverNoContextTakeover: false,
        ),
      );

      // Set up a listener to catch auth errors immediately after connection
      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
        cancelOnError: false, // Don't cancel on error, let us handle it
      );

      // Wait a brief moment to check for immediate auth errors
      // The server may send an auth error message before closing
      await Future.delayed(const Duration(milliseconds: 200));

      // Check if we received an auth error (connection would be in error state)
      if (_connectionState == TransportConnectionState.error) {
        debugPrint('[WS-TRANSPORT] Connection failed due to auth error');
        return false;
      }

      _missedPongs = 0;
      _updateConnectionState(TransportConnectionState.connected);
      _startHeartbeat();

      debugPrint('[WS-TRANSPORT] Connected successfully');
      return true;
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Connection failed: $e');
      _updateConnectionState(TransportConnectionState.error);

      // Check if error is related to authentication (close code 4001)
      if (e.toString().contains('4001') ||
          e.toString().contains('authentication') ||
          e.toString().contains('token')) {
        _errorController.add('AUTH_ERROR:CONNECTION_FAILED');
      } else {
        _errorController.add('WebSocket connection failed: $e');
      }
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

      // Handle authentication errors
      if (messageType == 'socket:error') {
        final errorCode = jsonMap['error_code'] as String?;
        if (errorCode == 'AUTH_REQUIRED' || errorCode == 'AUTH_INVALID') {
          debugPrint(
            '[WS-TRANSPORT] Authentication error detected: $errorCode',
          );
          _updateConnectionState(TransportConnectionState.error);
          _errorController.add('AUTH_ERROR:$errorCode');
          return;
        }
      }

      // Handle ping/pong internally
      if (messageType == 'socket:ping') {
        _sendPong();
        return;
      } else if (messageType == 'socket:pong') {
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
        debugPrint(
          '[WS-TRANSPORT] Connection stale, missed $_missedPongs pongs',
        );
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
      _socket!.add(
        json.encode({
          'type': 'socket:ping',
          'ws_timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      _missedPongs++;
    } catch (e) {
      debugPrint('[WS-TRANSPORT] Error sending ping: $e');
    }
  }

  void _sendPong() {
    if (_socket == null) return;
    try {
      _socket!.add(
        json.encode({
          'type': 'socket:pong',
          'ws_timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
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
// HTTP Long Polling Transport Implementation
// =============================================================================

class LongPollingTransport implements TransportService {
  // http.Client? _client;
  TransportConnectionState _connectionState =
      TransportConnectionState.disconnected;
  String? _token;
  String? _lastMessageId;
  bool _isPolling = false;
  bool _isPollingInProgress = false;
  Timer? _pollTimer;

  final StreamController<TransportConnectionState> _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  ChatClient? _chatClient;
  ChatClient get _chats => _chatClient ??= ApiService().chat;

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
      // _client = http.Client();

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

  /// Poll for pending vital WebSocket messages from the cache
  /// This fetches VitalWSMessages that were missed while offline
  Future<void> _poll() async {
    if (!_isPolling || _token == null) return;

    try {
      // Use the new polling endpoint that fetches from cache
      final result = await _chats.pollPendingMessages(
        afterMessageId: _lastMessageId,
      );

      if (!_isPolling) return;

      if (result.isSuccess && result.data != null) {
        final responseData = result.data!;
        final messages = responseData['messages'] as List<dynamic>?;
        final lastMessageId = responseData['last_message_id'] as String?;

        // Update last message ID for cursor-based pagination
        if (lastMessageId != null) {
          _lastMessageId = lastMessageId;
        }

        if (messages != null && messages.isNotEmpty) {
          debugPrint(
            '[POLLING-TRANSPORT] Received ${messages.length} pending vital message(s)',
          );

          // Process each cached message
          for (final cachedMsg in messages) {
            if (cachedMsg is Map<String, dynamic>) {
              // Extract the ws_message from the cached message structure
              final wsMessage =
                  cachedMsg['ws_message'] as Map<String, dynamic>?;
              if (wsMessage != null) {
                // Add the WSMessage to the message stream
                _messageController.add(wsMessage);
              }
            }
          }
        }
      } else if (result.code == 401) {
        debugPrint('[POLLING-TRANSPORT] Authentication error detected (401)');
        _updateConnectionState(TransportConnectionState.error);
        _errorController.add('AUTH_ERROR:401');
        _isPolling = false;
        return;
      }

      // Continue polling every 5 seconds
      if (_isPolling) {
        _pollTimer = Timer(const Duration(seconds: 2), _poll);
      }
    } catch (e) {
      if (!_isPolling) return;

      debugPrint('[POLLING-TRANSPORT] Poll error: $e');

      // Retry with backoff on error (still every 5 seconds)
      if (_isPolling) {
        _pollTimer = Timer(const Duration(seconds: 2), _poll);
      }
    }
  }

  /// Trigger an immediate poll without waiting for the next scheduled interval.
  /// Call this on reconnect to pull any messages missed during the gap.
  void pollNow() {
    if (!_isPolling) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _poll();
  }

  @override
  Future<void> disconnect() async {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    // _client?.close();
    // _client = null;
    _lastMessageId = null;
    _updateConnectionState(TransportConnectionState.disconnected);
  }

  @override
  Future<bool> sendMessage(Map<String, dynamic> message) async {
    if (_token == null) return false;

    try {
      // Use Dio from ApiService to ensure proper cookie handling
      final dio = ApiService().client.dio;
      final pollUrl = '${Environment.baseUrl}/chat/poll/send-message';

      final response = await dio.post(
        pollUrl,
        data: message,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        // Check if there's a response message (like ack)
        try {
          final responseData = response.data['data'];
          if (responseData is Map<String, dynamic> &&
              responseData['type'] != null) {
            _messageController.add(responseData);
          }
        } catch (_) {
          // Ignore parse errors for simple success responses
        }
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('[POLLING-TRANSPORT] Authentication error detected (401)');
        _updateConnectionState(TransportConnectionState.error);
        _errorController.add('AUTH_ERROR:401');
        return false;
      }
      debugPrint(
        '[POLLING-TRANSPORT] Send message failed with status: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      debugPrint('[POLLING-TRANSPORT] Error sending message: $e');
      return false;
    }
  }

  Future<void> syncMissedWsEventsOnReconnect({
    void Function(Map<String, dynamic>)? onMessage,
  }) async {
    if (_isPollingInProgress) return;

    try {
      _isPollingInProgress = true;
      // Use the new polling endpoint that fetches from cache
      final result = await _chats.pollPendingMessages(
        afterMessageId: _lastMessageId,
        forSync: true,
      );

      if (result.isSuccess && result.data != null) {
        final responseData = result.data!;
        final messages = responseData['messages'] as List<dynamic>?;

        if (messages != null && messages.isNotEmpty) {
          debugPrint(
            '[POLLING-TRANSPORT] Synced ${messages.length} missed vital message(s)',
          );

          // Process each cached message
          for (final cachedMsg in messages) {
            if (cachedMsg is Map<String, dynamic>) {
              // Extract the ws_message from the cached message structure
              final wsMessage =
                  cachedMsg['ws_message'] as Map<String, dynamic>?;
              if (wsMessage != null) {
                debugPrint(
                  '[POLLING-TRANSPORT] feeding missed WS message into stream: ${wsMessage['type']} (ID: ${wsMessage['message_id'] ?? 'N/A'})',
                );
                // Route through the provided sink if available (e.g. TransportManager's
                // message controller), otherwise fall back to this transport's own stream.
                if (onMessage != null) {
                  onMessage(wsMessage);
                } else {
                  _messageController.add(wsMessage);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[POLLING-TRANSPORT] Poll error: $e');
    } finally {
      _isPollingInProgress = false;
    }
  }

  @override
  void dispose() {
    _isPolling = false;
    _pollTimer?.cancel();
    // _client?.close();
    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
  }
}
