import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:amigo/types/socket.type.dart';
import 'package:flutter/widgets.dart';

import '../cookie_service.dart';
import '../../env.dart';
import 'package:flutter/material.dart' as material;
import '../../utils/navigation_helper.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocket? _socket;
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;

  final CookieService _cookieService = CookieService();

  // If false, do not attempt automatic reconnects (e.g., during logout)
  bool _allowReconnect = true;

  // Connection management
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 50;
  static const Duration reconnectInterval = Duration(seconds: 3);
  bool _isDialogShowing = false;

  // Stream controllers for different events
  final StreamController<WebSocketConnectionState> _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();

  final StreamController<WSMessage> _messageController =
      StreamController<WSMessage>.broadcast();

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Getters
  WebSocketConnectionState get connectionState => _connectionState;

  Stream<WebSocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Stream<WSMessage> get messageStream => _messageController.stream;

  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  // Initialize WebSocket connection with access token from cookies
  Future<void> connect([int? conversationId]) async {
    // Allow reconnects again on any explicit connect
    _allowReconnect = true;
    if (_connectionState == WebSocketConnectionState.connecting ||
        _connectionState == WebSocketConnectionState.connected) {
      return;
    }

    try {
      _updateConnectionState(WebSocketConnectionState.connecting);

      // Get access token from cookies
      final accessToken = await _cookieService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token found in cookies');
      }

      // Build WebSocket URL with access token as query parameter
      final wsUrl = _buildWebSocketUrl(accessToken);

      // Create WebSocket connection using native WebSocket
      debugPrint('🔍 About to connect to: $wsUrl');
      _socket = await WebSocket.connect(wsUrl);

      // Listen to messages
      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _reconnectAttempts = 0;
      _isDialogShowing = false; // Reset dialog flag on successful connection
      _updateConnectionState(WebSocketConnectionState.connected);
      debugPrint('✅ WebSocket connected successfully');

      // If a conversation ID is provided, send active_in_conversation message
      // if (conversationId != null) {
      //   await sendMessage({
      //     'type': 'active_in_conversation',
      //     'conversation_id': conversationId,
      //   });
      // }
    } catch (e) {
      debugPrint('❌ WebSocket connection failed');
      _handleConnectionError(e.toString());
    }
  }

  /// Build WebSocket URL with access token as query parameter
  String _buildWebSocketUrl(String accessToken) {
    // Use the configured WebSocket URL directly
    final websocketUrl = Environment.websocketUrl;
    final uri = Uri.parse(websocketUrl);

    // Build WebSocket URL preserving the original scheme, host, port, and path
    String wsUrl;
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      // wsUrl = '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';
      wsUrl = '${uri.scheme}://${uri.host}${uri.path}';
    } else {
      wsUrl = '${uri.scheme}://${uri.host}${uri.path}';
    }

    // Add access token as query parameter
    final finalUrl = '$wsUrl?token=${Uri.encodeComponent(accessToken)}';

    return finalUrl;
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final WSMessage data;
      Map<String, dynamic>? jsonMap;

      // Handle string messages (JSON strings from WebSocket)
      if (message is String) {
        try {
          jsonMap = json.decode(message) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('⚠️ Failed to parse JSON string: $message');
          debugPrint('❌ JSON decode error: $e');
          return;
        }
      } else if (message is Map<String, dynamic>) {
        jsonMap = message;
      } else {
        debugPrint(
          '⚠️ Received unexpected websocket message type: ${message.runtimeType}',
        );
        debugPrint('⚠️ Message content: $message');
        return;
      }

      // Parse the JSON map into WSMessage
      data = WSMessage.fromJson(jsonMap);
      _messageController.add(data);
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing WebSocket message: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _errorController.add('Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    debugPrint('❌ WebSocket error: $error');
    _handleConnectionError(error.toString());
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    debugPrint('🔌 WebSocket disconnected');
    _updateConnectionState(WebSocketConnectionState.disconnected);
    if (_allowReconnect) {
      _scheduleReconnect();
    }
  }

  /// Handle connection errors
  void _handleConnectionError(String error) {
    debugPrint('❌ WebSocket connection error');
    _updateConnectionState(WebSocketConnectionState.error);
    _errorController.add(error);
    if (_allowReconnect) {
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('❌ Max reconnection attempts reached');
      _showInternetIssueDialog();
      return;
    }

    _reconnectAttempts++;
    _updateConnectionState(WebSocketConnectionState.reconnecting);
    _reconnectTimer = Timer(reconnectInterval, () {
      connect();
    });
  }

  void _showInternetIssueDialog() {
    // Prevent showing multiple dialogs
    if (_isDialogShowing) {
      debugPrint('⚠️ Internet issue dialog is already showing');
      return;
    }

    final context = NavigationHelper.navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        '⚠️ Cannot show internet issue dialog: navigator context is null',
      );
      return;
    }

    _isDialogShowing = true;
    material
        .showDialog(
          context: context,
          builder: (ctx) => material.AlertDialog(
            title: const material.Text('Connection issue'),
            content: const material.Text(
              "We're having trouble connecting to the server. Please check your internet connection.",
            ),
            actions: [
              material.TextButton(
                onPressed: () {
                  _isDialogShowing = false;
                  material.Navigator.of(ctx).pop();
                  reconnect();
                },
                child: const material.Text('Retry'),
              ),
              material.TextButton(
                onPressed: () {
                  _isDialogShowing = false;
                  material.Navigator.of(ctx).pop();
                },
                child: const material.Text('OK'),
              ),
            ],
          ),
        )
        .then((_) {
          // Reset flag if dialog is dismissed by other means (e.g., back button)
          _isDialogShowing = false;
        });
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(WebSocketConnectionState newState) {
    _connectionState = newState;
    _connectionStateController.add(newState);
  }

  /// Send a message through WebSocket
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (_socket == null ||
        _connectionState != WebSocketConnectionState.connected) {
      throw Exception('WebSocket is not connected');
    }

    try {
      final jsonMessage = json.encode(message);

      debugPrint('📤 Sending WebSocket message: $jsonMessage');
      _socket!.add(jsonMessage);
      // print('📤 Sent WebSocket message dfdfg: $jsonMessage');
    } catch (e) {
      debugPrint('❌ Error sending WebSocket message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }

    _updateConnectionState(WebSocketConnectionState.disconnected);
  }

  /// Disconnect and suppress any automatic reconnects (use for logout)
  Future<void> shutdown() async {
    _allowReconnect = false;
    await disconnect();
  }

  /// Reconnect WebSocket (useful for token refresh scenarios)
  Future<void> reconnect() async {
    await disconnect();
    _reconnectAttempts = 0;
    await connect();
  }

  /// Dispose resources
  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.close();
    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
  }
}
