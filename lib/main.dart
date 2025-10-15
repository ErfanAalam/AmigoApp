import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/call/in_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'screens/main_pages/inner_chat_page.dart';
import 'screens/main_pages/inner_group_chat_page.dart';
import 'screens/share_handler_screen.dart';
import 'services/auth_service.dart';
import 'services/cookie_service.dart';
import 'services/websocket_service.dart';
import 'services/user_status_service.dart';
import 'services/call_service.dart';
import 'services/notification_service.dart';
import 'services/call_foreground_service.dart';
// import 'services/call_notification_handler.dart';
import 'widgets/call_manager.dart';
import 'api/api_service.dart';
import 'utils/navigation_helper.dart';
import 'utils/ringing_tone.dart';
import 'models/conversation_model.dart';
import 'models/group_model.dart';
import 'repositories/conversations_repository.dart';
import 'repositories/groups_repository.dart';

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

  // Initialize Foreground Service for keeping microphone active during calls
  await CallForegroundService.initialize();

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
  StreamSubscription? _intentDataStreamSubscription;
  int _notificationRetryCount = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _checkAuthentication();
    _setupWebSocketListeners();
    _initializeSharing();

    // Process initial notification after the first frame is rendered
    // This ensures navigator is ready
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      _processInitialNotification();
    });
  }

  /// Process initial notification from terminated state
  Future<void> _processInitialNotification() async {
    // Wait for authentication to complete and UI to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    print(
      '🔔 Checking for initial notification (attempt ${_notificationRetryCount + 1}/5)...',
    );
    print('   Is authenticated: $_isAuthenticated');
    print(
      '   Navigator ready: ${NavigationHelper.navigatorKey.currentContext != null}',
    );

    // Only process if authenticated and navigator is ready
    if (_isAuthenticated &&
        NavigationHelper.navigatorKey.currentContext != null) {
      print('✅ Processing initial notification...');
      await _notificationService.processInitialMessage();
      _notificationRetryCount = 0; // Reset counter
    } else {
      print('⚠️ Not ready to process initial notification yet');
      _notificationRetryCount++;

      // Retry up to 5 times
      if (_notificationRetryCount < 5) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _processInitialNotification();
        });
      } else {
        print('❌ Max retries reached for initial notification processing');
        _notificationRetryCount = 0; // Reset counter
      }
    }
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
    print('🔔 _handleNotificationNavigation called with data: $data');

    // Add a small delay to ensure navigator is ready
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        // Parse conversationId - it can be either String or int
        final conversationIdStr = data['conversationId']?.toString();

        if (conversationIdStr == null) {
          print('❌ Missing conversationId in notification data');
          return;
        }

        // Convert to integer
        final conversationId = int.tryParse(conversationIdStr);

        if (conversationId == null) {
          print('❌ Invalid conversationId format: $conversationIdStr');
          return;
        }

        print(
          '🚀 Navigating to conversation from notification: conversationId=$conversationId',
        );

        // Try to fetch the conversation from local DB
        await _fetchAndNavigateToConversation(conversationId, data);
      } catch (e) {
        print('❌ Error navigating to conversation from notification: $e');
        print('   Stack trace: ${StackTrace.current}');
      }
    });
  }

  /// Fetch conversation details and navigate to appropriate page
  Future<void> _fetchAndNavigateToConversation(
    int conversationId,
    Map<String, dynamic> notificationData,
  ) async {
    try {
      print('🔍 Fetching conversation with ID: $conversationId');

      // First, try to get it as a DM conversation
      final conversationsRepo = ConversationsRepository();
      print('   Checking DM conversations...');
      final conversation = await conversationsRepo.getConversationById(
        conversationId,
      );

      if (conversation != null) {
        print('✅ Found DM conversation: ${conversation.userName}');
        _navigateToDM(conversation);
        return;
      }

      print('   Not found in DM conversations, checking groups...');

      // If not found as DM, try to get it as a group
      final groupsRepo = GroupsRepository();
      final group = await groupsRepo.getGroupById(conversationId);

      if (group != null) {
        print('✅ Found group conversation: ${group.title}');
        _navigateToGroup(group);
        return;
      }

      // If not found in local DB
      print(
        '⚠️ Conversation $conversationId not found in local DB (neither DM nor Group)',
      );
      print(
        '   This might be a new conversation. The app will sync it on next refresh.',
      );
    } catch (e) {
      print('❌ Error fetching conversation: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Navigate to DM conversation
  void _navigateToDM(ConversationModel conversation) {
    print('🎯 Navigating to DM conversation: ${conversation.userName}');

    if (NavigationHelper.navigatorKey.currentContext != null) {
      print('   Navigator context is available');
      material.Navigator.of(NavigationHelper.navigatorKey.currentContext!).push(
        material.MaterialPageRoute(
          builder: (_) => InnerChatPage(conversation: conversation),
        ),
      );
      print('✅ Navigation to DM completed');
    } else {
      print('❌ Navigator context is null, cannot navigate');
    }
  }

  /// Navigate to group conversation
  void _navigateToGroup(GroupModel group) {
    print('🎯 Navigating to group conversation: ${group.title}');

    if (NavigationHelper.navigatorKey.currentContext != null) {
      print('   Navigator context is available');
      material.Navigator.of(NavigationHelper.navigatorKey.currentContext!).push(
        material.MaterialPageRoute(
          builder: (_) => InnerGroupChatPage(group: group),
        ),
      );
      print('✅ Navigation to group completed');
    } else {
      print('❌ Navigator context is null, cannot navigate');
    }
  }

  /// Initialize sharing intent listeners
  void _initializeSharing() {
    // Listen for shared media while the app is running
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              _handleSharedMedia(value);
            }
          },
          onError: (err) {
            print("❌ Error receiving shared files: $err");
          },
        );

    // Handle shared media when app is opened from the share sheet (app was closed)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        // Wait for authentication to complete and navigator to be ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleSharedMedia(value);
          ReceiveSharingIntent.instance.reset();
        });
      }
    });
  }

  /// Handle shared media files
  void _handleSharedMedia(List<SharedMediaFile> files) {
    // Only handle if user is authenticated
    if (!_isAuthenticated) {
      print("⚠️ User not authenticated, ignoring shared media");
      return;
    }

    print("📤 Received ${files.length} shared file(s)");
    print("📤 Files: ${files.map((f) => f.path).join(", ")}");

    // Navigate to ShareHandlerScreen with files
    if (NavigationHelper.navigatorKey.currentContext != null) {
      material.Navigator.of(NavigationHelper.navigatorKey.currentContext!).push(
        material.MaterialPageRoute(
          builder: (_) => ShareHandlerScreen(initialFiles: files),
        ),
      );
    } else {
      // If navigator is not ready, wait and try again
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleSharedMedia(files);
      });
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
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
