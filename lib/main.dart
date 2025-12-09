import 'dart:async';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'api/auth.api-client.dart';
import 'api/user.api-client.dart';
import 'models/group.model.dart';
import 'screens/auth/login.screen.dart';
import 'screens/call/in-call.screen.dart';
import 'screens/call/incoming-call.screen.dart';
import 'screens/chat/dm/dm-messaging.screen.dart';
import 'screens/chat/group/group-messaging.screen.dart';
import 'screens/home.layout.dart';
import 'screens/share/external-share.screen.dart';
import 'services/auth/auth.service.dart';
import 'services/call/call-foreground.service.dart';
import 'services/call/call.service.dart';
import 'services/cookies.service.dart';
import 'services/notification.service.dart';
import 'services/socket/websocket.service.dart';
import 'services/socket/ws-message.handler.dart';
import 'services/user-status.service.dart';
import 'ui/loading-dots.widget.dart';
import 'utils/navigation-helper.util.dart';
import 'utils/ringtone.util.dart';

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

  // await TestBGService().initializeService();

  // Run the app (with Riverpod)
  material.runApp(const ProviderScope(child: MyApp()));
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
    final userInfo = await UserUtils().getUserDetails();
    if (userInfo != null) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('current_user_name', userInfo.name);
    }
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
    // Add a delay to ensure navigator is ready and app is fully initialized
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        // Convert to integer
        final conversationIdStr = data['conversationId']?.toString();
        if (conversationIdStr == null) {
          debugPrint('❌ ConversationId is null in notification data');
          return;
        }

        final conversationId = int.tryParse(conversationIdStr);
        if (conversationId == null) {
          debugPrint('❌ Failed to parse conversationId: $conversationIdStr');
          return;
        }

        debugPrint('🔔 Navigating to conversation: $conversationId');

        // Try to fetch the conversation from local DB with retry
        await _fetchAndNavigateToConversationWithRetry(conversationId, data);
      } catch (e) {
        debugPrint('❌ Error navigating to conversation from notification: $e');
      }
    });
  }

  /// Fetch conversation details and navigate to appropriate page with retry
  Future<void> _fetchAndNavigateToConversationWithRetry(
    int conversationId,
    Map<String, dynamic> notificationData, {
    int maxRetries = 5,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Check if navigator is ready
        if (NavigationHelper.navigatorKey.currentContext == null) {
          debugPrint(
            '⏳ Navigator not ready, retrying in ${retryDelay.inMilliseconds}ms... (attempt ${attempt + 1}/$maxRetries)',
          );
          await Future.delayed(retryDelay);
          continue;
        }

        // First, try to get it as a DM conversation
        final conversationsRepo = ConversationRepository();
        final convType = await conversationsRepo.getConversationTypeById(
          conversationId,
        );

        if (convType == null) {
          debugPrint(
            '⏳ Conversation not found in DB, retrying... (attempt ${attempt + 1}/$maxRetries)',
          );
          await Future.delayed(retryDelay);
          continue;
        }

        if (convType == 'dm') {
          final dm = await conversationsRepo.getDmByConversationId(
            conversationId,
          );
          if (dm != null) {
            debugPrint('✅ Found DM conversation, navigating...');
            _navigateToDM(dm);
            return;
          } else {
            debugPrint(
              '⏳ DM conversation data incomplete, retrying... (attempt ${attempt + 1}/$maxRetries)',
            );
            await Future.delayed(retryDelay);
            continue;
          }
        } else if (convType == 'group') {
          final group = await conversationsRepo.getGroupWithMembersByConvId(
            conversationId,
          );
          if (group != null) {
            debugPrint('✅ Found group conversation, navigating...');
            _navigateToGroup(group);
            return;
          } else {
            debugPrint(
              '⏳ Group conversation data incomplete, retrying... (attempt ${attempt + 1}/$maxRetries)',
            );
            await Future.delayed(retryDelay);
            continue;
          }
        }
      } catch (e) {
        debugPrint(
          '❌ Error fetching conversation (attempt ${attempt + 1}): $e',
        );
        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }

    debugPrint(
      '❌ Failed to navigate to conversation after $maxRetries attempts',
    );
  }

  /// Navigate to DM conversation
  void _navigateToDM(DmModel dm) {
    // Use NavigationHelper's pushRouteWithRetry for more reliable navigation
    NavigationHelper.pushRouteWithRetry(
      InnerChatPage(dm: dm),
      maxRetries: 10,
      retryDelay: const Duration(milliseconds: 300),
    );
  }

  /// Navigate to group conversation
  void _navigateToGroup(GroupModel group) {
    // Use NavigationHelper's pushRouteWithRetry for more reliable navigation
    NavigationHelper.pushRouteWithRetry(
      InnerGroupChatPage(group: group),
      maxRetries: 10,
      retryDelay: const Duration(milliseconds: 300),
    );
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
      home:
          // CallEnabledApp(
          //   child:
          _isLoading
          ? _buildLoadingScreen()
          : _isAuthenticated
          ? MainScreen()
          : LoginScreen(),
      // ),
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
