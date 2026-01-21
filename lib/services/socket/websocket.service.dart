import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;

import '../../types/socket.types.dart';
import '../../utils/navigation-helper.util.dart';
import '../cookies.service.dart';
import 'transport.manager.dart';
import 'transport.service.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket service that provides reliable real-time communication.
/// 
/// This service uses the TransportManager internally to automatically handle
/// fallback between different transports (WebSocket → SSE → HTTP Long Polling)
/// ensuring maximum connectivity even in restrictive network environments.
/// 
/// The public interface remains unchanged for backward compatibility.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final CookieService _cookieService = CookieService();
  final TransportManager _transportManager = TransportManager();

  // Connection state tracking
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  bool _isDialogShowing = false;

  // Stream controllers for different events
  final StreamController<WebSocketConnectionState> _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();

  final StreamController<WSMessage> _messageController =
      StreamController<WSMessage>.broadcast();

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Subscriptions to transport manager
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _messageSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _transportTypeSub;

  // Getters
  WebSocketConnectionState get connectionState => _connectionState;

  Stream<WebSocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Stream<WSMessage> get messageStream => _messageController.stream;

  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  /// Get the current transport type being used (for diagnostics)
  TransportType? get currentTransportType => _transportManager.currentTransportType;

  /// Stream of transport type changes (for diagnostics/UI)
  Stream<TransportType> get transportTypeStream => _transportManager.transportTypeStream;

  /// Initialize connection with automatic transport fallback.
  /// 
  /// This will attempt to connect using the best available transport:
  /// 1. WebSocket (preferred)
  /// 2. SSE (Server-Sent Events)
  /// 3. HTTP Long Polling
  Future<void> connect([int? conversationId]) async {
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

      // Set up subscriptions to transport manager
      _setupTransportSubscriptions();

      // Connect via transport manager (handles fallback automatically)
      debugPrint('🔌 Connecting via TransportManager...');
      final success = await _transportManager.connect(accessToken);

      if (success) {
        _isDialogShowing = false;
        _updateConnectionState(WebSocketConnectionState.connected);
        debugPrint('✅ Connected successfully via ${_transportManager.currentTransportType?.name}');
      } else {
        debugPrint('❌ All transport connections failed');
        _updateConnectionState(WebSocketConnectionState.error);
        _errorController.add('Failed to establish connection');
      }
    } catch (e) {
      debugPrint('❌ Connection failed: $e');
      _updateConnectionState(WebSocketConnectionState.error);
      _errorController.add('Connection failed: $e');
    }
  }

  void _setupTransportSubscriptions() {
    // Cancel existing subscriptions
    _connectionStateSub?.cancel();
    _messageSub?.cancel();
    _errorSub?.cancel();
    _transportTypeSub?.cancel();

    // Subscribe to connection state changes
    _connectionStateSub = _transportManager.connectionStateStream.listen((state) {
      final mappedState = _mapTransportState(state);
      _updateConnectionState(mappedState);

      // Show dialog when max reconnect attempts reached
      if (state == TransportConnectionState.error) {
        _showInternetIssueDialog();
      }
    });

    // Subscribe to messages
    _messageSub = _transportManager.messageStream.listen((jsonMap) {
      try {
        // Parse the JSON map into WSMessage
        final data = WSMessage.fromJson(jsonMap);
        _messageController.add(data);
      } catch (e, stackTrace) {
        debugPrint('❌ Error parsing message: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        _errorController.add('Error parsing message: $e');
      }
    });

    // Subscribe to errors
    _errorSub = _transportManager.errorStream.listen((error) {
      _errorController.add(error);
    });

    // Subscribe to transport type changes (for logging)
    _transportTypeSub = _transportManager.transportTypeStream.listen((type) {
      debugPrint('📡 Transport type changed to: ${type.name}');
    });
  }

  WebSocketConnectionState _mapTransportState(TransportConnectionState state) {
    switch (state) {
      case TransportConnectionState.disconnected:
        return WebSocketConnectionState.disconnected;
      case TransportConnectionState.connecting:
        return WebSocketConnectionState.connecting;
      case TransportConnectionState.connected:
        return WebSocketConnectionState.connected;
      case TransportConnectionState.reconnecting:
        return WebSocketConnectionState.reconnecting;
      case TransportConnectionState.error:
        return WebSocketConnectionState.error;
    }
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
            content: material.Text(
              "We're having trouble connecting to the server. Please check your internet connection.\n\n"
              "Current transport: ${_transportManager.currentTransportType?.name ?? 'none'}",
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
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(newState);
    }
  }

  /// Send a message through the current transport
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (!isConnected) {
      throw Exception('Not connected - cannot send message');
    }

    try {
      final jsonMessage = json.encode(message);
      debugPrint('📤 Sending message: $jsonMessage');

      final success = await _transportManager.sendMessage(message);
      if (!success) {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Disconnect from server
  Future<void> disconnect() async {
    _connectionStateSub?.cancel();
    _messageSub?.cancel();
    _errorSub?.cancel();
    _transportTypeSub?.cancel();

    await _transportManager.disconnect();
    _updateConnectionState(WebSocketConnectionState.disconnected);
  }

  /// Disconnect and suppress any automatic reconnects (use for logout)
  Future<void> shutdown() async {
    _connectionStateSub?.cancel();
    _messageSub?.cancel();
    _errorSub?.cancel();
    _transportTypeSub?.cancel();

    await _transportManager.shutdown();
    _updateConnectionState(WebSocketConnectionState.disconnected);
  }

  /// Reconnect with fresh state (useful for token refresh scenarios)
  Future<void> reconnect() async {
    await _transportManager.reconnect();
  }

  /// Dispose all resources
  void dispose() {
    _connectionStateSub?.cancel();
    _messageSub?.cancel();
    _errorSub?.cancel();
    _transportTypeSub?.cancel();

    _transportManager.dispose();
    _connectionStateController.close();
    _messageController.close();
    _errorController.close();
  }
}
