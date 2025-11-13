import 'dart:async';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_layout.dart';
import 'screens/call/in_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'screens/chat/dm/messaging.dart';
import 'screens/chat/group/messaging.dart';
import 'screens/share/external_share.dart';
import 'services/auth/auth.service.dart';
import 'services/cookie_service.dart';
import 'services/socket/websocket_service.dart';
import 'services/user_status_service.dart';
import 'services/socket/websocket_message_handler.dart';
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
import 'api/user.service.dart';
import 'repositories/user_repository.dart';
import 'widgets/loading_dots_animation.dart';

void main() async {
  material.WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await CookieService().init();

  // Initialize WebSocket service (will be used in MyApp widget)
  WebSocketService();

  // Initialize UserStatusService
  UserStatusService();

  // Initialize WebSocket message handler (will be initialized in MyApp when authenticated)
  WebSocketMessageHandler();

  // Initialize NotificationService
  await NotificationService().initialize();

  // Initialize Foreground Service for keeping microphone active during calls
  await CallForegroundService.initialize();

  // Initialize RingtoneManager for call audio
  await RingtoneManager.init();

  // Run the app (with CallService provider and Riverpod)
  material.runApp(
    ProviderScope(
      child: ChangeNotifierProvider<CallService>(
        create: (_) => CallService()..initialize(),
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends material.StatefulWidget {
  const MyApp({super.key});

  @override
  material.State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends material.State<MyApp> {
  final AuthService _authService = AuthService();
  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  final NotificationService _notificationService = NotificationService();
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();
  final UserRepository _userRepo = UserRepository();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  StreamSubscription? _intentDataStreamSubscription;
  int _notificationRetryCount = 0;
  // String appVersion = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _checkAuthentication();
    _setupWebSocketListeners();
    _initializeSharing();
    // _loadAppVersion();
    _getCurrentUser();

    // Process initial notification after the first frame is rendered
    // This ensures navigator is ready
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      _processInitialNotification();
    });
  }

  Future<void> _getCurrentUser() async {
    final userInfo = await _userRepo.getFirstUser();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('current_user_name', userInfo?.name ?? '');
  }

  /// Process initial notification from terminated state
  Future<void> _processInitialNotification() async {
    // Wait for authentication to complete and UI to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Only process if authenticated and navigator is ready
    if (_isAuthenticated &&
        NavigationHelper.navigatorKey.currentContext != null) {
      await _notificationService.processInitialMessage();
      _notificationRetryCount = 0; // Reset counter
    } else {
      _notificationRetryCount++;

      // Retry up to 5 times
      if (_notificationRetryCount < 5) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _processInitialNotification();
        });
      } else {
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
        // Initialize centralized WebSocket message handler (only once)
        WebSocketMessageHandler().initialize();

        // Connect to WebSocket and wait for connection
        await _websocketService.connect();

        // // Send FCM token to backend
        // final userId = await _authService.getCurrentUserId();
        // if (userId != null) {
        // await _notificationService.sendTokenToBackend(userId.toString());
        // }
        final appVersion = await UserUtils().getAppVersion();
        await _userService.updateUser({'app_version': appVersion});

        // await _apiService.updateUserLocationAndIp();
        // Wait a bit for WebSocket to establish connection
        await Future.delayed(const Duration(milliseconds: 500));
        await _requestPermissions();

        final prefs = await SharedPreferences.getInstance();
        final callStatus = prefs.getString('call_status');
        final callId = prefs.getString('current_call_id');
        final callerId = prefs.getString('current_caller_id');

        if (callId != null) {
          // Get caller information from storage
          final callerName =
              prefs.getString('current_caller_name') ?? 'Unknown';
          final callerProfilePic = prefs.getString(
            'current_caller_profile_pic',
          );

          switch (callStatus) {
            case 'answered':
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
              // No action needed
              break;
          }
        }

        await _apiService.updateUserLocationAndIp();
      } catch (e) {
        debugPrint('❌ Failed to establish WebSocket connection in main.dart');
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

    // Note: WebSocket messages are now handled centrally by WebSocketMessageHandler
    // which is initialized when user is authenticated

    // Listen to WebSocket errors
    _websocketService.errorStream.listen((error) {
      debugPrint('❌ WebSocket error in main app');
    });

    // Listen to notification streams
    _notificationService.messageNotificationStream.listen((data) {
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
    // Add a small delay to ensure navigator is ready
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        // Convert to integer
        final conversationId = int.tryParse(data['conversationId']);

        if (conversationId == null) return;

        // Try to fetch the conversation from local DB
        await _fetchAndNavigateToConversation(conversationId, data);
      } catch (e) {
        debugPrint('❌ Error navigating to conversation from notification');
      }
    });
  }

  /// Fetch conversation details and navigate to appropriate page
  Future<void> _fetchAndNavigateToConversation(
    int conversationId,
    Map<String, dynamic> notificationData,
  ) async {
    try {
      // First, try to get it as a DM conversation
      final conversationsRepo = ConversationsRepository();
      final conversation = await conversationsRepo.getConversationById(
        conversationId,
      );

      if (conversation != null) {
        _navigateToDM(conversation);
        return;
      }

      // If not found as DM, try to get it as a group
      final groupsRepo = GroupsRepository();
      final group = await groupsRepo.getGroupById(conversationId);

      if (group != null) {
        _navigateToGroup(group);
        return;
      }
    } catch (e) {
      debugPrint('❌ Error fetching conversation');
    }
  }

  /// Navigate to DM conversation
  void _navigateToDM(ConversationModel conversation) {
    if (NavigationHelper.navigatorKey.currentContext != null) {
      material.Navigator.of(NavigationHelper.navigatorKey.currentContext!).push(
        material.MaterialPageRoute(
          builder: (_) => InnerChatPage(conversation: conversation),
        ),
      );
    } else {
      print('❌ Navigator context is null, cannot navigate');
    }
  }

  /// Navigate to group conversation
  void _navigateToGroup(GroupModel group) {
    if (NavigationHelper.navigatorKey.currentContext != null) {
      material.Navigator.of(NavigationHelper.navigatorKey.currentContext!).push(
        material.MaterialPageRoute(
          builder: (_) => InnerGroupChatPage(group: group),
        ),
      );
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
            debugPrint("❌ Error receiving shared files");
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
    if (!_isAuthenticated) return;

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
    WebSocketMessageHandler().dispose();
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
      body: material.Center(
        child: LoadingDotsAnimation(color: Colors.blue[400]),
      ),
    );
  }
}
