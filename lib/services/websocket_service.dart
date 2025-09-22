import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'cookie_service.dart';
import '../env.dart';

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

  // Connection management
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectInterval = Duration(seconds: 5);

  // Stream controllers for different events
  final StreamController<WebSocketConnectionState> _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Getters
  WebSocketConnectionState get connectionState => _connectionState;
  Stream<WebSocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  /// Initialize WebSocket connection with access token from cookies
  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connecting ||
        _connectionState == WebSocketConnectionState.connected) {
      return;
    }

    try {
      _updateConnectionState(WebSocketConnectionState.connecting);

      // Get access token from cookies
      final accessToken = await _getAccessTokenFromCookies();
      if (accessToken == null) {
        throw Exception('No access token found in cookies');
      }

      // Build WebSocket URL with access token as query parameter
      final wsUrl = _buildWebSocketUrl(accessToken);

      print(
        '🔌 Connecting to WebSocket: ${wsUrl.replaceAll(accessToken, '[TOKEN_HIDDEN]')}',
      );
      print('🔑 Token length: ${accessToken.length} characters');

      // Parse the URI and verify it's correct
      final uri = Uri.parse(wsUrl);
      print('🔍 Parsed WebSocket URI: ${uri.toString()}');
      print('🔍 URI Scheme: ${uri.scheme}');
      print('🔍 URI Host: ${uri.host}');
      print('🔍 URI Port: ${uri.port}');
      print('🔍 URI Path: ${uri.path}');
      print('🔍 URI Query: ${uri.query}');

      // Create WebSocket connection using native WebSocket
      print('🔍 About to connect to: $wsUrl');
      print('🔍 WebSocket.connect() will be called with this exact URL');
      _socket = await WebSocket.connect(wsUrl);
      print('🔍 WebSocket.connect() completed successfully');

      // Listen to messages
      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _reconnectAttempts = 0;
      _updateConnectionState(WebSocketConnectionState.connected);
      print('✅ WebSocket connected successfully');
    } catch (e) {
      _handleConnectionError(e.toString());
    }
  }

  /// Extract access token from cookie jar
  Future<String?> _getAccessTokenFromCookies() async {
    return await _cookieService.getAccessToken();
  }

  /// Build WebSocket URL with access token as query parameter
  String _buildWebSocketUrl(String accessToken) {
    // Extract the base host and port from the API URL
    final websocketUrl = Environment.websocketUrl;
    final uri = Uri.parse(websocketUrl);

    print('🔍 Base URL: $websocketUrl');
    print(
      '🔍 Parsed URI - Scheme: ${uri.scheme}, Host: ${uri.host}, Port: ${uri.port}',
    );

    // Build WebSocket URL with the correct protocol and path
    final wsUrl =
        '${uri.scheme == 'https' ? 'wss' : 'ws'}://${uri.host}:${uri.port}/chat';

    print('🔍 Built WebSocket URL: $wsUrl');

    // Add access token as query parameter
    final finalUrl = '$wsUrl?token=${Uri.encodeComponent(accessToken)}';
    print(
      '🔍 Final WebSocket URL: ${finalUrl.replaceAll(accessToken, '[TOKEN_HIDDEN]')}',
    );

    return finalUrl;
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data;

      if (message is String) {
        data = json.decode(message);
      } else if (message is Map<String, dynamic>) {
        data = message;
      } else {
        print('⚠️ Received unexpected message type: ${message.runtimeType}');
        return;
      }

      _messageController.add(data);
    } catch (e) {
      print('❌ Error parsing WebSocket message: $e');
      _errorController.add('Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    print('❌ WebSocket error: $error');
    _handleConnectionError(error.toString());
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    print('🔌 WebSocket disconnected');
    _updateConnectionState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  /// Handle connection errors
  void _handleConnectionError(String error) {
    print('❌ WebSocket connection error: $error');
    _updateConnectionState(WebSocketConnectionState.error);
    _errorController.add(error);
    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    _updateConnectionState(WebSocketConnectionState.reconnecting);
    _reconnectTimer = Timer(reconnectInterval, () {
      connect();
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

      print('📤 Sending WebSocket message: $jsonMessage');
      _socket!.add(jsonMessage);
      // print('📤 Sent WebSocket message dfdfg: $jsonMessage');
    } catch (e) {
      print('❌ Error sending WebSocket message: $e');
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
    print('🔌 WebSocket disconnected manually');
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
