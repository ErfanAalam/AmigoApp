import 'dart:async';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:amigo/utils/call.utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
// FlutterCallkitIncoming - commented out, replaced by native call screen
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'services/call/native_call_screen.service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionActions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'api/api_service.dart';
import 'env.dart';
import 'package:dio/dio.dart';
import 'models/group.model.dart';
import 'screens/auth/login.screen.dart';
import 'screens/chat/dm/dm-messaging.screen.dart';
import 'screens/chat/group/group-messaging.screen.dart';
import 'screens/home.layout.dart';
import 'screens/share/external-share.screen.dart';
import 'services/auth/auth.service.dart';
import 'models/call.model.dart';
import 'services/call/call-foreground.service.dart';
import 'services/call/call.service.dart';
import 'services/call/stream/stream_call.service.dart';
import 'services/cookies.service.dart';
import 'services/fcm/fcm-init.service.dart';
import 'services/message/message_gc.service.dart';
import 'services/message/status-ack.service.dart';
import 'services/socket/transport.manager.dart';
import 'services/socket/transport.service.dart';
import 'services/socket/ws-message.handler.dart';
import 'services/user-status.service.dart';
import 'ui/call/call-pill.widget.dart';
import 'ui/loading-dots.widget.dart';
import 'utils/navigation-helper.util.dart';
import 'utils/ringtone.util.dart';

void main() async {
  debugPrint("---------------------------------------------------------------");
  debugPrint("🚀 Starting Amigo Chat App...");
  debugPrint("---------------------------------------------------------------");
  material.WidgetsFlutterBinding.ensureInitialized();

  // Restore guest mode environment before any API calls
  final prefs = await SharedPreferences.getInstance();
  final isGuestMode = prefs.getBool('is_guest_mode') ?? false;
  Environment.setGuestMode(isGuestMode);

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

  // Initialize native call screen event listener
  NativeCallScreen.initialize();

  // await TestBGService().initializeService();

  // Limit Flutter's image decode cache to 80 MB to prevent OOM crashes
  // during fast scrolling with many media messages
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 * 1024 * 1024;

  // Run the app (with Riverpod)
  material.runApp(ProviderScope(child: MyApp(key: MyApp.appStateKey)));
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
  static final GlobalKey<material.State<MyApp>> appStateKey =
      GlobalKey<material.State<MyApp>>();
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
  List<SharedMediaFile>? _pendingSharedFiles;
  // String appVersion = '';

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to handle app state changes
    material.WidgetsBinding.instance.addObserver(this);
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

      // Push the FCM token to the chat backend now that we've confirmed the
      // user is authenticated. NotificationService.initialize() (called from
      // main()) attempts this earlier but it's fire-and-forget — on cold
      // start, the auth cookies may not have been loaded yet so the upload
      // returns 401 and is silently dropped. This re-attempt with a retry
      // budget guarantees the chat backend has a current token before any
      // chat/call notification can be sent. Without it the user has to
      // open the app a second time to "wake up" notifications.
      try {
        await _authService.sendFCMTokenToBackend(3);
      } catch (e) {
        debugPrint('⚠️ FCM token upload after auth failed: $e');
      }

      // Initialize CallService BEFORE WebSocketMessageHandler so it is already
      // subscribed to callRingingStream when the first WS messages arrive.
      await CallService().initialize();

      // Stream Video backend runs side-by-side with the WebRTC one. It only
      // self-initialises if `Environment.callBackend == 'stream'` and a
      // STREAM_API_KEY is configured at build time — otherwise this is a
      // cheap no-op that keeps the WebRTC path the only active provider.
      debugPrint('[STREAM-CALL] main: callBackend=${Environment.callBackend}  '
          'isStreamCallBackend=${Environment.isStreamCallBackend}  '
          'streamApiKey.len=${Environment.streamApiKey.length}');
      if (Environment.isStreamCallBackend) {
        debugPrint('[STREAM-CALL] main: kicking off StreamCallService().initialize()');
        // ignore: unawaited_futures
        StreamCallService().initialize();
      }

      // Initialize centralized WebSocket message handler (only once)
      WebSocketMessageHandler().initialize();
      MessageGarbageCollector.instance.init();

      final appVersion = await UserUtils().getAppVersion();
      final updateResult = await _apiService.user.updateUser({
        'app_version': appVersion,
      });
      if (!updateResult.isSuccess) {
        debugPrint('⚠️ Failed to update app version: ${updateResult.message}');
      }

      // await _apiService.updateUserLocationAndIp();
      // Wait a bit for WebSocket to establish connection
      await Future.delayed(const Duration(milliseconds: 300));
      await _requestPermissions();

      // Initialize RingtoneManager for call audio
      await RingtoneManager.init();

      // The killed-state pending-accept cache is WebRTC-only. With the Stream
      // backend, the SDK + CallKit-style notification own the killed-launch
      // path, so skip this entirely.
      final callUtils = CallUtils();
      final callDetails =
          Environment.isStreamCallBackend ? null : await callUtils.getCallDetails();
      final callStatus = callDetails?.callStatus;
      final callId = callDetails?.callId;
      final callerId = callDetails?.callerId;

      if (callId != null) {
        // Get caller information from storage
        final callerName = callDetails?.callerName ?? 'Unknown';
        final callerProfilePic = callDetails?.callerProfilePic;

        switch (callStatus) {
          case 'declined':
            // Call was rejected, clean up
            await CallService().initialize();
            await CallService().declineCall(reason: 'declined', callId: callId);
            return;

          case 'ended':
            // Call already ended, clean up
            break;

          case 'missed':
            // Call was missed, clean up
            await CallService().initialize();
            await CallService().declineCall(reason: 'timeout', callId: callId);
            break;

          default:
            // 'accepting' is handled by CallService._handlePendingAccept()
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
        // Flush any pending status acks to MissedWsMessages before going to background
        StatusAckService.instance.flushNow();

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
        // Re-enable wakelock if there's an active call
        if (isInCall) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
        // NOTE: Do NOT re-open the native call screen here.
        // Doing so causes it to reopen every time the user presses back.
        // The call pill overlay gives the user a way to tap back into the call.
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
    // Fast local check — reads secure storage only, no network call (~20ms).
    // This makes the app (and any pending share screen) visible immediately.
    final isLocallyAuthenticated = await _authService.isAuthenticatedLocally();
    setState(() {
      _isAuthenticated = isLocallyAuthenticated;
      _isLoading = false;
    });

    if (isLocallyAuthenticated) {
      // Navigate to any pending share screen on the very next frame,
      // before the heavyweight init or server validation begins.
      _tryHandlePendingSharedFiles();
      // Server validation + full init run in the background.
      _runBackgroundInit();
    }
  }

  /// Validates the session with the server and runs full initialization.
  /// Called in the background after the fast local auth check passes.
  Future<void> _runBackgroundInit() async {
    // isAuthenticated() makes the server call and calls logout() internally
    // if the token was revoked (e.g. logged in from another device).
    final isServerAuthenticated = await _authService.isAuthenticated();
    if (!isServerAuthenticated) {
      if (mounted) setState(() => _isAuthenticated = false);
      return;
    }
    await initializeAuthenticatedUser();
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
      _handleNotificationNavigation(data);
    });

    // Check for any pending notification payload that was buffered
    // before this listener was attached (e.g., from background tap)
    final pendingPayload = _notificationService
        .consumePendingNavigationPayload();
    if (pendingPayload != null) {
      debugPrint('📨 Found pending notification payload, navigating...');
      _handleNotificationNavigation(pendingPayload);
    }
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    await Permission.notification.request();
    // FlutterCallkitIncoming permissions - commented out, replaced by native call screen
    // await FlutterCallkitIncoming.requestNotificationPermission({
    //   "title": "Notification permission",
    //   "rationaleMessagePermission":
    //       "Notification permission is required, to show notification.",
    //   "postNotificationMessageRequired":
    //       "Notification permission is required, Please allow notification permission from setting.",
    // });
    // await FlutterCallkitIncoming.canUseFullScreenIntent();
    // await FlutterCallkitIncoming.requestFullIntentPermission();
  }

  /// Handle navigation from notification tap
  void _handleNotificationNavigation(ChatMessagePayload data) async {
    debugPrint('📨 Handling notification navigation: convId=${data.convId}');

    // Ensure user is authenticated before navigating
    if (!_isAuthenticated) {
      debugPrint('⏳ User not authenticated yet, waiting...');
      // Wait for authentication with timeout
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_isAuthenticated) break;
      }
      if (!_isAuthenticated) {
        debugPrint('❌ User not authenticated, cannot navigate');
        return;
      }
    }

    // Add a small delay to ensure navigator is ready
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // Look up conversation type from local DB since ChatMessagePayload
      // no longer carries convType.
      final conversationsRepo = ConversationRepository();
      final conv = await conversationsRepo.getConversationById(data.convId);
      final convType = conv?.type != null
          ? ChatType.fromString(conv!.type) ?? ChatType.dm
          : ChatType.dm;

      // Try to fetch the conversation from local DB with retry
      await _fetchAndNavigateToConversationWithRetry(data.convId, convType);
    } catch (e) {
      debugPrint('❌ Error navigating to conversation from notification: $e');
    }
  }

  /// Fetch conversation details and navigate to appropriate page with retry
  Future<void> _fetchAndNavigateToConversationWithRetry(
    String conversationId,
    ChatType convType, {
    int maxRetries = 10,
    Duration retryDelay = const Duration(milliseconds: 300),
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

        final conversationsRepo = ConversationRepository();

        // Handle DM conversations
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
        }
        // Handle group and community_group conversations
        else if (convType == ChatType.group ||
            convType == ChatType.communityGroup) {
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
        } else {
          debugPrint(
            '❌ Unknown conversation type: $convType for conversation $conversationId',
          );
          return;
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
      '❌ Failed to navigate to conversation $conversationId after $maxRetries attempts',
    );
  }

  /// Navigate to DM conversation
  void _navigateToDM(DmModel dm) {
    debugPrint('🚀 Navigating to DM conversation: ${dm.chatId}');

    // Use NavigationHelper's pushRouteWithRetry for more reliable navigation
    NavigationHelper.pushRouteWithRetry(
      InnerChatPage(dm: dm),
      maxRetries: 10,
      retryDelay: const Duration(milliseconds: 300),
    );
  }

  /// Navigate to group conversation
  void _navigateToGroup(GroupModel group) {
    debugPrint('🚀 Navigating to group conversation: ${group.chatId}');

    // Use NavigationHelper's pushRouteWithRetry for more reliable navigation
    NavigationHelper.pushRouteWithRetry(
      InnerGroupChatPage(group: group),
      maxRetries: 10,
      retryDelay: const Duration(milliseconds: 300),
    );
  }

  /// Initialize sharing intent listeners
  void _initializeSharing() {
    // Listen for shared media while the app is running (app was in background)
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

    // Handle shared media when app is cold-started via the share sheet.
    // Store the files and process them once authentication is confirmed,
    // so we never reset() the intent before navigation actually happens.
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        _pendingSharedFiles = value;
        _tryHandlePendingSharedFiles();
      }
    });
  }

  /// Process pending shared files from a cold-start intent.
  /// Safe to call multiple times — exits early if not yet ready.
  void _tryHandlePendingSharedFiles() {
    if (_pendingSharedFiles == null || _pendingSharedFiles!.isEmpty) return;
    if (!_isAuthenticated) return; // Will be retried once auth completes

    final files = _pendingSharedFiles!;
    _pendingSharedFiles = null;

    // addPostFrameCallback fires after the very next render frame (~16ms),
    // guaranteeing MainScreen (and therefore the navigator) is already built.
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleSharedMedia(
        files,
        onNavigated: () {
          ReceiveSharingIntent.instance.reset();
        },
      );
    });
  }

  /// Handle shared media files.
  /// [onNavigated] is called only after the screen is actually pushed.
  void _handleSharedMedia(
    List<SharedMediaFile> files, {
    VoidCallback? onNavigated,
    int retryCount = 0,
  }) {
    if (!_isAuthenticated) return;

    if (NavigationHelper.navigatorKey.currentContext != null) {
      material.Navigator.of(NavigationHelper.navigatorKey.currentContext!).push(
        material.MaterialPageRoute(
          builder: (_) => ShareHandlerScreen(initialFiles: files),
        ),
      );
      onNavigated?.call();
    } else if (retryCount < 10) {
      // Navigator not ready yet — retry with a bounded retry count
      Future.delayed(const Duration(milliseconds: 300), () {
        _handleSharedMedia(
          files,
          onNavigated: onNavigated,
          retryCount: retryCount + 1,
        );
      });
    } else {
      debugPrint("❌ Could not navigate to ShareHandlerScreen after retries");
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
      builder: (context, child) {
        return Stack(
          children: [child ?? const SizedBox.shrink(), const GlobalCallPill()],
        );
      },
      home: _isLoading
          ? _buildLoadingScreen()
          : _isAuthenticated
          ? MainScreen()
          : LoginScreen(),
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
