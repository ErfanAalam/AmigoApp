import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/call/in_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'services/auth_service.dart';
import 'services/cookie_service.dart';
import 'services/websocket_service.dart';
import 'services/user_status_service.dart';
import 'services/call_service.dart';
import 'services/notification_service.dart';
// import 'services/call_notification_handler.dart';
import 'widgets/call_manager.dart';
import 'api/api_service.dart';
import 'utils/navigation_helper.dart';

void main() async {
  material.WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final cookieService = CookieService();
  await cookieService.init();

  // Initialize WebSocket service (will be used in MyApp widget)
  WebSocketService();

  // Initialize UserStatusService
  UserStatusService();

  // Initialize NotificationService
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize CallNotificationHandler
  // final callNotificationHandler = CallNotificationHandler();
  // callNotificationHandler.initialize();

  // Initialize API service (which uses the cookie service)
  // final apiService = ApiService();

  material.runApp(
    ChangeNotifierProvider<CallService>(
      create: (_) => CallService()..initialize(),
      child: MyApp(),
    ),
  );
}

class MyApp extends material.StatefulWidget {
  @override
  material.State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends material.State<MyApp> {
  final AuthService _authService = AuthService();
  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  final NotificationService _notificationService = NotificationService();
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _setupWebSocketListeners();
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _authService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuthenticated;
      _isLoading = false;
    });

    // Connect to WebSocket if user is authenticated
    if (isAuthenticated) {
      try {
        // Connect to WebSocket and wait for connection
        await _websocketService.connect();

        // Send FCM token to backend
        final userId = await _authService.getCurrentUserId();
        if (userId != null) {
          await _notificationService.sendTokenToBackend(userId.toString());
        }

        await _apiService.updateUserLocationAndIp();
        // Wait a bit for WebSocket to establish connection
        await Future.delayed(const Duration(milliseconds: 500));

        print('✅ WebSocket connection established in main.dart');

        await _apiService.updateUserLocationAndIp();
      } catch (e) {
        print('❌ Failed to establish WebSocket connection in main.dart: $e');
        // Don't prevent app from loading, but log the error
      }
    }
  }

  void _setupWebSocketListeners() {
    // Listen to WebSocket connection state changes
    _websocketService.connectionStateStream.listen((state) {
      if (state == WebSocketConnectionState.disconnected) {
        // Clear all user online status when disconnected
        _userStatusService.clearAllStatus();
      }
    });

    // Listen to WebSocket messages
    _websocketService.messageStream.listen((message) {
      final type = message['type'] as String?;

      if (type == 'user_online') {
        _userStatusService.handleUserOnlineMessage(message);
      } else if (type == 'user_offline') {
        _userStatusService.handleUserOfflineMessage(message);
      }
    });

    // Listen to WebSocket errors
    _websocketService.errorStream.listen((error) {
      print('❌ WebSocket error in main app: $error');
    });

    // Listen to notification streams
    _notificationService.messageNotificationStream.listen((data) {
      print('📨 Message notification received: $data');
      // Handle message notification - could navigate to specific chat
    });

    _notificationService.callNotificationStream.listen((data) {
      print('📞 Call notification received: $data');
      // Handle call notification - could show incoming call screen
    });
  }

  @override
  void dispose() {
    _websocketService.dispose();
    _userStatusService.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.MaterialApp(
      navigatorKey: NavigationHelper.navigatorKey, // Use NavigationHelper's key
      title: 'Amigo Chat App',
      theme: material.ThemeData(
        primarySwatch: material.Colors.blue,
        visualDensity: material.VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: CallEnabledApp(
        child: _isLoading
            ? _buildLoadingScreen()
            : _isAuthenticated
            ? MainScreen()
            : LoginScreen(),
      ),
      routes: {
        '/call': (context) => const InCallScreen(),
        '/incoming-call': (context) => const IncomingCallScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }

  material.Widget _buildLoadingScreen() {
    return material.Scaffold(
      body: material.Center(child: material.CircularProgressIndicator()),
    );
  }
}
