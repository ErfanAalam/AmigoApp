import 'package:flutter/material.dart' as material;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/call/in_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'screens/main_pages/inner_chat_page.dart';
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
import 'utils/ringing_tone.dart';
import 'models/conversation_model.dart';

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

  // Initialize RingtoneManager for call audio
  await RingtoneManager.init();

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
    _requestPermissions();
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

        // await _apiService.updateUserLocationAndIp();
        // Wait a bit for WebSocket to establish connection
        await Future.delayed(const Duration(milliseconds: 500));
        FlutterCallkitIncoming.requestFullIntentPermission();

        print('✅ WebSocket connection established in main.dart');

        final prefs = await SharedPreferences.getInstance();
        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );
        print("prefs current call id -> ${prefs.getString('current_call_id')}");
        print(
          "prefs current caller id -> ${prefs.getString('current_caller_id')}",
        );
        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );

        final callStatus = prefs.getString('call_status');
        print(
          "--------------------------------------------------------------------------------",
        );
        print("callStatus -> ${callStatus}");
        print(
          "--------------------------------------------------------------------------------",
        );
        final callId = prefs.getString('current_call_id');
        print(
          "--------------------------------------------------------------------------------",
        );
        print("callId -> ${callId}");
        print(
          "--------------------------------------------------------------------------------",
        );
        final callerId = prefs.getString('current_caller_id');
        print(
          "--------------------------------------------------------------------------------",
        );
        print("callerId -> ${callerId}");
        print(
          "--------------------------------------------------------------------------------",
        );

        if (callId != null) {
          print(
            "--------------------------------------------------------------------------------",
          );
          print("inside if callId -> ${callId}");
          print(
            "--------------------------------------------------------------------------------",
          );

          // Get caller information from storage
          final callerId = prefs.getString('current_caller_id');
          final callerName =
              prefs.getString('current_caller_name') ?? 'Unknown';
          final callerProfilePic = prefs.getString(
            'current_caller_profile_pic',
          );

          print("callerId from storage -> $callerId");
          print("callerName from storage -> $callerName");
          print("callerProfilePic from storage -> $callerProfilePic");

          switch (callStatus) {
            case 'answered':
              print(
                "--------------------------------------------------------------------------------",
              );
              print("answered callId -> ${callId}");
              print(
                "--------------------------------------------------------------------------------",
              );
              // Call was answered, proceed to accept
              await CallService().initialize();
              await CallService().acceptCall(
                callId: int.parse(callId),
                callerId: callerId != null ? int.parse(callerId) : null,
                callerName: callerName,
                callerProfilePic: callerProfilePic,
              );

              // // Dispose all notifications from flutter_callkit_incoming
              // await FlutterCallkitIncoming.setCallConnected(callId);
              break;
            case 'declined':
              // Call was rejected, clean up
              await CallService().initialize();
              await CallService().declineCall(
                reason: 'declined',
                callId: int.parse(callId),
              );
              return;
            case 'ended':
              // Call already ended, clean up
              break;
            case 'missed':
              // Call was missed, clean up
              await CallService().initialize();
              await CallService().declineCall(
                reason: 'timeout',
                callId: int.parse(callId),
              );
              break;
            default:
              print(
                "--------------------------------------------------------------------------------",
              );
              print("default case");
              print(
                "--------------------------------------------------------------------------------",
              );
              // No action needed
              break;
          }

          // Request notification permission for callkit incoming
          await FlutterCallkitIncoming.requestNotificationPermission({
            "title": "Notification permission",
            "rationaleMessagePermission":
                "Notification permission is required, to show notification.",
            "postNotificationMessageRequired":
                "Notification permission is required, Please allow notification permission from setting.",
          });
          // Check if can use full screen intent
          await FlutterCallkitIncoming.canUseFullScreenIntent();
          // Request full intent permission
          await FlutterCallkitIncoming.requestFullIntentPermission();

          // clean up after use
          // prefs.remove('current_call_id');
          // prefs.remove('current_caller_id');
          // prefs.remove('call_status');
        }

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
      _handleNotificationNavigation(data);
    });
  }

  Future<void> _requestPermissions() async {
    // Request notification permission for callkit incoming
    await FlutterCallkitIncoming.requestNotificationPermission({
      "title": "Notification permission",
      "rationaleMessagePermission":
          "Notification permission is required, to show notification.",
      "postNotificationMessageRequired":
          "Notification permission is required, Please allow notification permission from setting.",
    });
    // Check if can use full screen intent
    await FlutterCallkitIncoming.canUseFullScreenIntent();
    // Request full intent permission
    await FlutterCallkitIncoming.requestFullIntentPermission();
  }

  /// Handle navigation from notification tap
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Add a delay to ensure the app is fully loaded before navigating
    Future.delayed(const Duration(milliseconds: 3000), () {
      try {
        // Parse string values to integers
        final conversationIdStr = data['conversationId'] as String?;
        final senderIdStr = data['senderId'] as String?;
        final senderName = data['senderName'] as String?;

        if (conversationIdStr == null ||
            senderIdStr == null ||
            senderName == null) {
          print(
            '❌ Missing required data for navigation: conversationId=$conversationIdStr, senderId=$senderIdStr, senderName=$senderName',
          );
          return;
        }

        // Convert string IDs to integers
        final conversationId = int.tryParse(conversationIdStr);
        final senderId = int.tryParse(senderIdStr);

        if (conversationId == null || senderId == null) {
          print(
            '❌ Invalid ID format: conversationId=$conversationIdStr, senderId=$senderIdStr',
          );
          return;
        }

        print(
          '🚀 Navigating to chat from notification: conversationId=$conversationId, senderName=$senderName',
        );

        // Create a conversation model from the notification data
        final conversation = ConversationModel(
          conversationId: conversationId,
          type: 'dm',
          unreadCount: 0,
          joinedAt: DateTime.now().toIso8601String(),
          userId: senderId,
          userName: senderName,
          userProfilePic: data['senderProfilePic'] as String?,
          isOnline: null,
        );

        // Wait for navigator to be available before navigating
        _waitForNavigatorAndNavigate(conversation);
      } catch (e) {
        print('❌ Error navigating to chat from notification: $e');
      }
    });
  }

  /// Wait for navigator to be available and then navigate
  void _waitForNavigatorAndNavigate(ConversationModel conversation) {
    NavigationHelper.pushRouteWithRetry(
      InnerChatPage(conversation: conversation),
      maxRetries: 15,
      retryDelay: const Duration(milliseconds: 500),
    );
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
