import 'dart:async';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:amigo/utils/call.utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'api/api_service.dart';
import 'package:dio/dio.dart';
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
import 'services/socket/transport.manager.dart';
import 'services/socket/transport.service.dart';
import 'services/socket/ws-message.handler.dart';
import 'services/user-status.service.dart';
import 'ui/loading-dots.widget.dart';
import 'utils/navigation-helper.util.dart';
import 'utils/ringtone.util.dart';

void main() async {
  debugPrint("---------------------------------------------------------------");
  debugPrint("🚀 Starting Amigo Chat App...");
  debugPrint("---------------------------------------------------------------");
  material.WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final cookieService = CookieService();
  await cookieService.init();

  // Initialize API service
  final dio = Dio();
  final authService = AuthService();
  await ApiService.initialize(
    dio: dio,
    cookieService: cookieService,
    authService: authService,
  );

  // Initialize Transport Manager (will be used in MyApp widget)
  TransportManager();

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
  material.runApp(
    ProviderScope(
      child: MyApp(key: MyApp.appStateKey),
    ),
  );
}

/// Public interface for app state methods that can be called from other files
abstract class AppStateInterface {
  Future<void> initializeAuthenticatedUser();
}

class MyApp extends material.StatefulWidget {
  const MyApp({super.key});

  @override
  material.State<MyApp> createState() => _MyAppState();
  
  // Global key to access app state from anywhere
  static final GlobalKey<material.State<MyApp>> appStateKey = GlobalKey<material.State<MyApp>>();
}

class _MyAppState extends material.State<MyApp>
    with material.WidgetsBindingObserver
    implements AppStateInterface {
  final AuthService _authService = AuthService();
  final TransportManager _transportManager = TransportManager();
  final UserStatusService _userStatusService = UserStatusService();
  final NotificationService _notificationService = NotificationService();
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  StreamSubscription? _intentDataStreamSubscription;
  int _notificationRetryCount = 0;
  // String appVersion = '';

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to handle app state changes
    material.WidgetsBinding.instance.addObserver(this);
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
  
  /// Initialize authenticated user - can be called from anywhere after login/signup
  /// This method contains all the logic that should run when a user is authenticated
  Future<void> initializeAuthenticatedUser() async {
    // Update authentication state
    final isAuthenticated = await _authService.isAuthenticated();
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    }

    if (!isAuthenticated) {
      return;
    }

    try {
      // Connect to WebSocket and wait for connection
      final cookieService = CookieService();
      final accessToken = await cookieService.getAccessToken();
      if (accessToken != null) {
        await _transportManager.connect(accessToken);
      }

      // Initialize centralized WebSocket message handler (only once)
      WebSocketMessageHandler().initialize();

      final appVersion = await UserUtils().getAppVersion();
      final updateResult = await _apiService.user.updateUser({
        'app_version': appVersion,
      });
      if (!updateResult.isSuccess) {
        debugPrint(
          '⚠️ Failed to update app version: ${updateResult.message}',
        );
      }

      // await _apiService.updateUserLocationAndIp();
      // Wait a bit for WebSocket to establish connection
      await Future.delayed(const Duration(milliseconds: 500));
      await _requestPermissions();

      final callUtils = CallUtils();
      final callDetails = await callUtils.getCallDetails();
      final callStatus = callDetails?.callStatus;
      final callId = callDetails?.callId;
      final callerId = callDetails?.callerId;

      if (callId != null) {
        // Get caller information from storage
        final callerName = callDetails?.callerName ?? 'Unknown';
        final callerProfilePic = callDetails?.callerProfilePic;

        switch (callStatus) {
          case 'answered':
            // Call was answered, proceed to accept
            await CallService().initialize();
            await CallService().acceptCall(
              callId: callId,
              callerId: callerId,
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
              callId: callId,
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
              callId: callId,
            );
            break;

          default:
            // No action needed
            break;
        }
      }

      await _apiService.auth.updateUserLocationAndIp();
    } catch (e) {
      debugPrint('❌ Failed to establish WebSocket connection: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(material.AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes to manage wakelock properly
    final callService = CallService();
    final isInCall = callService.isInCall;

    switch (state) {
      case material.AppLifecycleState.paused:
      case material.AppLifecycleState.inactive:
      case material.AppLifecycleState.detached:
        // App is going to background or being closed
        // Only keep wakelock if there's an active call in progress
        if (!isInCall) {
          // No active call - disable wakelock to allow screen to lock
          WakelockPlus.disable();
          debugPrint(
            '[APP_LIFECYCLE] App going to background - disabled wakelock (no active call)',
          );
        } else {
          debugPrint(
            '[APP_LIFECYCLE] App going to background - keeping wakelock (active call in progress)',
          );
        }
        break;

      case material.AppLifecycleState.resumed:
        // App is coming to foreground
        // Re-enable wakelock if there's an active call
        if (isInCall) {
          WakelockPlus.enable();
          debugPrint(
            '[APP_LIFECYCLE] App resumed - enabled wakelock (active call in progress)',
          );
        } else {
          // Ensure wakelock is disabled when app resumes without active call
          WakelockPlus.disable();
          debugPrint(
            '[APP_LIFECYCLE] App resumed - disabled wakelock (no active call)',
          );
        }
        break;

      case material.AppLifecycleState.hidden:
        // App is hidden (Android 12+)
        if (!isInCall) {
          WakelockPlus.disable();
          debugPrint(
            '[APP_LIFECYCLE] App hidden - disabled wakelock (no active call)',
          );
        }
        break;
    }
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

    // Initialize authenticated user if already logged in
    if (isAuthenticated) {
      await initializeAuthenticatedUser();
    }
  }

  void _setupWebSocketListeners() {
    // Listen to WebSocket connection state changes
    _transportManager.connectionStateStream.listen((state) {
      if (state == TransportConnectionState.disconnected) {
        // Clear all user online status when disconnected
        _userStatusService.clearAllStatus();
      }
    });

    // Note: WebSocket messages are now handled centrally by WebSocketMessageHandler
    // which is initialized when user is authenticated

    // Listen to WebSocket errors
    _transportManager.errorStream.listen((error) {
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
    Future.delayed(const Duration(milliseconds: 150), () async {
      try {
        final convId = data['conv_id'] as int?;
        final convType = data['conv_type'];
        if (convId == null || convType == null) {
          debugPrint(
            '❌ Either ConversationId Or ConversationType is null in notification data',
          );
          return;
        }

        // Try to fetch the conversation from local DB with retry
        await _fetchAndNavigateToConversationWithRetry(convId, convType);
      } catch (e) {
        debugPrint('❌ Error navigating to conversation from notification: $e');
      }
    });
  }

  /// Fetch conversation details and navigate to appropriate page with retry
  Future<void> _fetchAndNavigateToConversationWithRetry(
    int conversationId,
    ChatType convType, {
    int maxRetries = 5,
    Duration retryDelay = const Duration(milliseconds: 100),
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

        if (convType == ChatType.dm) {
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
        } else if (convType == ChatType.group) {
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
    // Remove lifecycle observer
    material.WidgetsBinding.instance.removeObserver(this);
    // Ensure wakelock is disabled when app is disposed
    WakelockPlus.disable();
    _intentDataStreamSubscription?.cancel();
    _transportManager.dispose();
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
