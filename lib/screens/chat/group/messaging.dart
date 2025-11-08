import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../../models/group_model.dart';
import '../../../models/message_model.dart';
import '../../../models/conversation_model.dart';
import '../../../models/community_model.dart';
import '../../../models/user_model.dart';
import '../../../api/groups.services.dart';
import '../../../api/user.service.dart';
import '../../../api/chats.services.dart';
import '../../../services/message_storage_service.dart';
import '../../../repositories/messages_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../repositories/groups_repository.dart';
import '../../../repositories/group_members_repository.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../services/socket/websocket_message_handler.dart';
import '../../../widgets/loading_dots_animation.dart';
import '../../../services/media_cache_service.dart';
import '../../../utils/chat_helpers.dart';
import '../../../utils/message_storage_helpers.dart';
import '../../../widgets/media_preview_widgets.dart';
import '../../../widgets/chat/message_action_sheet.dart';
import '../../../widgets/chat/date.widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/draft_message_service.dart';
import '../../../providers/draft_provider.dart';
import 'group_info.dart';
import 'dart:io' as io;

class InnerGroupChatPage extends ConsumerStatefulWidget {
  final GroupModel group;
  final bool isCommunityGroup;
  final CommunityGroupMetadata? communityGroupMetadata;

  const InnerGroupChatPage({
    super.key,
    required this.group,
    this.isCommunityGroup = false,
    this.communityGroupMetadata,
  });

  @override
  ConsumerState<InnerGroupChatPage> createState() => _InnerGroupChatPageState();
}

class _InnerGroupChatPageState extends ConsumerState<InnerGroupChatPage>
    with TickerProviderStateMixin {
  final GroupsService _groupsService = GroupsService();
  final UserService _userService = UserService();
  final ChatsServices _chatsServices = ChatsServices();
  final MessagesRepository _messagesRepo = MessagesRepository();
  final UserRepository _userRepo = UserRepository();
  final GroupMembersRepository _groupMembersRepo = GroupMembersRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final WebSocketService _websocketService = WebSocketService();
  final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final ImagePicker _imagePicker = ImagePicker();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentPage = 1;
  String? _errorMessage;
  int? _currentUserId;
  bool _isInitialized = false;
  ConversationMeta? _conversationMeta;
  bool _isLoadingFromCache = false;
  bool _hasCheckedCache = false;
  bool _isCheckingCache = true;
  bool _isTyping = false;
  bool _isAdminOrStaff = false;
  // bool _isOtherTyping = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);

  // For optimistic message handling - using filtered streams per conversation
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _mediaSubscription;
  StreamSubscription<Map<String, dynamic>>? _messagePinSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageStarSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageReplySubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeleteSubscription;
  StreamSubscription? _audioProgressSubscription;
  Timer? _audioProgressTimer;
  DateTime? _audioStartTime;
  Duration _customPosition = Duration.zero;
  int _optimisticMessageId = -1;
  final Set<int> _optimisticMessageIds = {};
  bool _isTestSending = false;

  Future<void> _startTestSequence(int totalMessages) async {
    if (_isTestSending) return;
    _isTestSending = true;
    final random = Random();
    try {
      for (int i = 1; i <= totalMessages; i++) {
        if (!mounted) break;
        _messageController.text = 'test sequence $i';
        _sendMessage();
        // Human-like delay between 300ms to 1200ms
        final delayMs = 400;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    } finally {
      _isTestSending = false;
    }
  }

  Widget _buildTestFab(int count, Color color) {
    return FloatingActionButton(
      heroTag: 'test-seq-$count',
      mini: true,
      backgroundColor: color,
      onPressed: () => _startTestSequence(count),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // User info cache for sender names and profile pics
  final Map<int, Map<String, String?>> _userInfoCache = {};

  /// Get user info from cache, metadata, or local DB
  Map<String, String?> _getUserInfo(int userId) {
    // PRIORITY 1: Check in-memory cache (INSTANT - populated during init)
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }

    // PRIORITY 2: Check conversation metadata members data
    if (_conversationMeta != null && _conversationMeta!.members.isNotEmpty) {
      final senderName = _conversationMeta!.getSenderName(userId);
      final senderProfilePic = _conversationMeta!.getSenderProfilePic(userId);
      if (senderName != 'Unknown User') {
        // Cache it for next time
        _userInfoCache[userId] = {
          'name': senderName,
          'profile_pic': senderProfilePic,
        };
        return {'name': senderName, 'profile_pic': senderProfilePic};
      }
    }

    // PRIORITY 3: Check local DB asynchronously and update cache
    // (Runs in background, will update UI when complete)
    Future.microtask(() async {
      // Try group_members table first (for group member info)
      final groupMember = await _groupMembersRepo.getMemberByUserId(userId);
      if (groupMember != null && mounted) {
        _userInfoCache[userId] = {
          'name': groupMember.userName,
          'profile_pic': groupMember.profilePic,
        };
        debugPrint(
          '💾 Loaded user $userId (${groupMember.userName}) from group_members DB - updating UI',
        );
        // Trigger rebuild to show updated names
        setState(() {});
        return;
      }

      // Fallback to users table (only for current user)
      final user = await _userRepo.getUserById(userId);
      if (user != null && mounted) {
        _userInfoCache[userId] = {
          'name': user.name,
          'profile_pic': user.profilePic,
        };
        debugPrint(
          '💾 Loaded user $userId (${user.name}) from users DB - updating UI',
        );
        // Trigger rebuild to show updated names
        setState(() {});
      } else {
        debugPrint('! User $userId not found in local DB');
      }
    });

    // PRIORITY 4: Return temporary fallback (will update when DB lookup completes)
    debugPrint('! Using fallback for user $userId - will check DB');
    return {'name': 'Unknown User', 'profile_pic': null};
  }

  // Message selection and actions
  final Set<int> _selectedMessages = {};
  bool _isSelectionMode = false;
  int? _pinnedMessageId; // Only one message can be pinned
  final Set<int> _starredMessages = {};

  // Forward message state
  final Set<int> _messagesToForward = {};
  List<ConversationModel> _availableConversations = [];
  bool _isLoadingConversations = false;

  // Reply message state
  MessageModel? _replyToMessageData;
  bool _isReplying = false;

  // Highlighted message state (for scroll-to effect)
  int? _highlightedMessageId;
  Timer? _highlightTimer;

  // Sticky date separator state
  String? _currentStickyDate;
  bool _showStickyDate = false;

  // Typing animation controllers
  late AnimationController _typingAnimationController;
  late List<Animation<double>> _typingDotAnimations;
  Timer? _typingTimeout;

  // Scroll debounce timer
  Timer? _scrollDebounceTimer;

  // Draft save debounce timer
  Timer? _draftSaveTimer;

  // Message animation controllers
  final Map<int, AnimationController> _messageAnimationControllers = {};
  final Map<int, Animation<double>> _messageSlideAnimations = {};
  final Map<int, Animation<double>> _messageFadeAnimations = {};
  final Set<int> _animatedMessages = {};

  // Swipe animation controllers for reply gesture
  final Map<int, AnimationController> _swipeAnimationControllers = {};
  final Map<int, Animation<double>> _swipeAnimations = {};

  // Swipe gesture tracking variables
  Offset? _swipeStartPosition;
  double _swipeTotalDistance = 0.0;
  bool _isSwipeGesture = false;
  bool _isScrolling = false;
  double _lastScrollPosition = 0.0;
  static const double _minSwipeDistance =
      50.0; // Minimum distance to consider as swipe
  static const double _maxVerticalDeviation =
      30.0; // Max vertical movement allowed for horizontal swipe
  static const double _minSwipeVelocity =
      1000.0; // Minimum velocity for swipe completion
  static const double _swipeThreshold =
      0.5; // Threshold for swipe completion (0.0 to 1.0)

  // Voice recording related variables
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _audioPlayer;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  late AnimationController _voiceModalAnimationController;
  late AnimationController _zigzagAnimationController;
  late Animation<double> _voiceModalAnimation;
  late Animation<double> _zigzagAnimation;
  final StreamController<Duration> _timerStreamController =
      StreamController<Duration>.broadcast();

  // Audio playback related variables
  final Map<String, bool> _playingAudios = {};
  final Map<String, Duration> _audioDurations = {};
  final Map<String, Duration> _audioPositions = {};
  String? _currentPlayingAudioKey;

  // Audio animation controllers
  final Map<String, AnimationController> _audioAnimationControllers = {};
  final Map<String, Animation<double>> _audioAnimations = {};

  // Video thumbnail cache
  final Map<String, String?> _videoThumbnailCache = {};
  final Map<String, Future<String?>> _videoThumbnailFutures = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _websocketService.connect(widget.group.conversationId);

    // Initialize typing animation
    _initializeTypingAnimation();

    // Initialize voice recording animations
    _initializeVoiceAnimations();

    // Set up WebSocket message listener
    _setupWebSocketListener();

    // Start initialization immediately
    _initializeChat();

    // Also try a super quick cache check for even faster display
    _quickCacheCheck();

    // Load draft message for this conversation
    _loadDraft();

    // Check admin or staff status
    _updateIsAdminOrStaff();

    // Listen to text changes for draft saving
    _messageController.addListener(_onMessageTextChanged);
  }

  /// Load draft message when opening conversation
  Future<void> _loadDraft() async {
    // Load directly from service for immediate access
    final draftService = DraftMessageService();
    final draft = await draftService.getDraft(widget.group.conversationId);
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      // Also update the provider state
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.group.conversationId, draft);
    }
  }

  Future<void> _updateIsAdminOrStaff() async {
    // Load directly from service for immediate access

    if (widget.group.role == 'admin') {
      setState(() {
        _isAdminOrStaff = true;
      });
    } else {
      // Check if user role is 'staff'
      try {
        final currentUser = await _userRepo.getFirstUser();
        if (currentUser != null && currentUser.role == 'staff') {
          setState(() {
            _isAdminOrStaff = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error checking user role: $e');
      }
    }
  }

  /// Handle message text changes with debouncing for draft saving
  void _onMessageTextChanged() {
    // Cancel existing timer
    _draftSaveTimer?.cancel();

    // Create new timer to save draft after 500ms of no typing
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final draftNotifier = ref.read(draftMessagesProvider.notifier);
        final text = _messageController.text;
        draftNotifier.saveDraft(widget.group.conversationId, text);
      }
    });
  }

  void _initializeTypingAnimation() {
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Create simple staggered animations for each dot with safe intervals
    _typingDotAnimations = [
      // Dot 0: 0.0 to 0.5
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _typingAnimationController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        ),
      ),
      // Dot 1: 0.2 to 0.7
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _typingAnimationController,
          curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
        ),
      ),
      // Dot 2: 0.4 to 0.9
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _typingAnimationController,
          curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
        ),
      ),
    ];
  }

  void _initializeVoiceAnimations() {
    _recorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();

    // Initialize the audio player asynchronously
    _initializeAudioPlayer();

    _voiceModalAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _zigzagAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _voiceModalAnimation = CurvedAnimation(
      parent: _voiceModalAnimationController,
      curve: Curves.easeOutBack,
    );

    _zigzagAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _zigzagAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      // Ensure player is closed first
      if (!_audioPlayer.isStopped) {
        await _audioPlayer.closePlayer();
      }

      await _audioPlayer.openPlayer();

      // Cancel existing subscription if any
      await _audioProgressSubscription?.cancel();

      // Set up onProgress listener as primary method
      _audioProgressSubscription = _audioPlayer.onProgress!.listen(
        (event) {
          if (mounted && _currentPlayingAudioKey != null) {
            final audioKey = _currentPlayingAudioKey!;
            if (_playingAudios[audioKey] ?? false) {
              setState(() {
                _audioDurations[audioKey] = event.duration;
                _audioPositions[audioKey] = event.position;
              });
              print(
                '🎵 OnProgress Stream: ${event.position.inSeconds}s / ${event.duration.inSeconds}s for $audioKey',
              );
            }
          }
        },
        onError: (error) {
          print('❌ Audio progress stream error: $error');
        },
      );

      print('🔊 Audio player initialized successfully');
    } catch (e) {
      print('❌ Error initializing audio player: $e');
    }
  }

  /// Ultra-fast cache check that runs immediately
  void _quickCacheCheck() async {
    try {
      final conversationId = widget.group.conversationId;

      // Quick check if we have cached messages in DB
      final count = await _messagesRepo.getMessageCount(conversationId);
      if (count > 0) {
        debugPrint(
          '🚀 Group cache exists ($count messages), will load shortly...',
        );
        // Don't load here, just indicate cache is available
        if (mounted) {
          setState(() {
            _isCheckingCache = true; // Show cache loader
          });
        }
      }
    } catch (e) {
      debugPrint('🚀 Quick group cache check error: $e');
    }
  }

  /// Smart sync: Compare cached message count with backend and add only new messages
  Future<void> _performSmartSync(int conversationId) async {
    try {
      // Get current cached message count
      final cachedCount = _messages.length;

      // Fetch latest data from backend (silently)
      final response = await _groupsService.getGroupConversationHistory(
        conversationId: conversationId,
        page: 1,
        limit: 50, // Get more messages to check for new ones
      );

      if (response['success'] == true && response['data'] != null) {
        final historyResponse = ConversationHistoryResponse.fromJson(
          response['data'],
        );

        final backendMessages = historyResponse.messages;
        final backendCount = backendMessages.length;

        if (backendCount > cachedCount) {
          // Backend has more messages - add only the new ones
          final newMessages = backendMessages.skip(cachedCount).toList();
          debugPrint('➕ Added ${newMessages.length} new group messages');

          // Add new messages to cache
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _messagesRepo.addMessagesToCache(
            conversationId: conversationId,
            newMessages: newMessages,
            updatedMeta: _conversationMeta!,
            insertAtBeginning: false, // Add new messages at the end
          );

          // Update UI with all messages (cached + new) - no loading state
          if (mounted) {
            setState(() {
              _messages =
                  backendMessages; // Show all messages including new ones
              _conversationMeta = ConversationMeta.fromResponse(
                historyResponse,
              );
              _hasMoreMessages = historyResponse.hasNextPage;
            });
            _populateReplyMessageSenderNames();
          }
        } else if (backendCount == cachedCount) {
          // Just update metadata in case pagination info changed
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _messagesRepo.saveMessages(
            conversationId: conversationId,
            messages: _messages,
            meta: _conversationMeta!,
          );
        } else {
          // Replace cache with backend data
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _messagesRepo.saveMessages(
            conversationId: conversationId,
            messages: backendMessages,
            meta: _conversationMeta!,
          );

          if (mounted) {
            setState(() {
              _messages = backendMessages;
              _conversationMeta = ConversationMeta.fromResponse(
                historyResponse,
              );
              _hasMoreMessages = historyResponse.hasNextPage;
            });
            _populateReplyMessageSenderNames();
          }
        }

        // Cache user info from metadata for offline access
        await _cacheUsersFromMetadata();
      }
    } catch (e) {
      debugPrint('❌ Error in group smart sync: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _initializeChat() async {
    // CRITICAL: Get user ID FIRST (must know who "I" am before displaying messages)
    await _getCurrentUserId();

    // CRITICAL: Initialize and AWAIT user info cache with group members
    // This MUST complete BEFORE displaying messages so names show correctly
    await _initializeUserCache();

    // NOW load and display messages (user ID and user names are known)
    // This also loads _conversationMeta which contains pinned message info
    await _tryLoadFromCacheFirst();

    // Load pinned and starred messages from local DB (fast)
    // Must be called AFTER _tryLoadFromCacheFirst to access _conversationMeta
    await _loadPinnedMessageFromStorage();
    await _loadStarredMessagesFromStorage();

    // Load from server (in background if we have cache)
    await _loadInitialMessages();

    // Send WebSocket messages in background (non-blocking, non-critical)
    Future.delayed(Duration.zero, () {
      _websocketService
          .sendMessage({
            'type': 'active_in_conversation',
            'conversation_id': widget.group.conversationId,
          })
          .catchError((e) {
            debugPrint('❌ Error sending active_in_conversation for group: $e');
          });
    });
  }

  /// Quick cache check and load for instant display
  Future<void> _tryLoadFromCacheFirst() async {
    if (_hasCheckedCache) return; // Avoid double-checking

    try {
      final conversationId = widget.group.conversationId;

      final cachedData = await _messagesRepo.getCachedMessages(conversationId);

      if (cachedData != null && cachedData.messages.isNotEmpty && mounted) {
        // Filter out old orphaned optimistic messages (messages with negative IDs older than 5 minutes)
        final now = DateTime.now();
        final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

        final cleanedMessages = cachedData.messages.where((msg) {
          // Keep all messages with positive IDs (server-confirmed)
          if (msg.id >= 0) return true;

          // For optimistic messages (negative IDs), only keep recent ones
          try {
            final createdAt = DateTime.parse(msg.createdAt);
            return createdAt.isAfter(fiveMinutesAgo);
          } catch (e) {
            // If we can't parse the date, keep the message to be safe
            return true;
          }
        }).toList();

        // Remove duplicates by ID (keep the one with positive ID if both exist)
        final messageMap = <int, MessageModel>{};
        for (final msg in cleanedMessages) {
          final existingMsg = messageMap[msg.id.abs()];
          // Prefer positive IDs (server-confirmed) over negative IDs (optimistic)
          if (existingMsg == null || msg.id > 0) {
            messageMap[msg.id.abs()] = msg;
          }
        }
        final deduplicatedMessages = messageMap.values.toList()
          ..sort((a, b) => a.id.compareTo(b.id));

        setState(() {
          _isCheckingCache = false;
          _isLoadingFromCache = false;
          _messages = deduplicatedMessages;
          _conversationMeta = cachedData.meta;
          _hasMoreMessages = cachedData.meta.hasNextPage;
          _currentPage = cachedData.meta.currentPage;
          _isInitialized = true;
          _isLoading = false;
          _errorMessage = null;
          _hasCheckedCache = true;
        });

        // Validate messages
        _validatePinnedMessage();
        _validateStarredMessages();
        _validateReplyMessages();
        _populateReplyMessageSenderNames();

        debugPrint(
          '✅ Loaded ${deduplicatedMessages.length} group messages from local DB (cleaned ${cachedData.messages.length - deduplicatedMessages.length} duplicates)',
        );
      } else {
        if (mounted) {
          setState(() {
            _isCheckingCache = false;
            _isLoading = false; // Don't show loading yet
            _hasCheckedCache = true;
          });
        }
      }
    } catch (e) {
      debugPrint('⚡ Error in quick group cache check: $e');
      if (mounted) {
        setState(() {
          _isCheckingCache = false;
          _isLoading = false;
          _hasCheckedCache = true;
        });
      }
    }
  }

  Future<void> _getCurrentUserId() async {
    try {
      // FAST PATH: Try to get from local DB first (instant)
      final conversationId = widget.group.conversationId;
      // final cachedMessages = await _messagesRepo.getMessagesByConversation(
      //   conversationId,
      //   limit: 20,
      // );

      // For groups, find messages we sent by checking local DB
      final cachedUser = await _userRepo.getFirstUser();
      if (cachedUser != null) {
        // Assume the first user we find in local cache is us
        _currentUserId = cachedUser.id;
        // Cache admin/staff status
        _isAdminOrStaff =
            widget.group.role == 'admin' || cachedUser.role == 'staff';
        return;
      }

      // SLOW PATH: Fetch from API (only if not found in cache)
      final response = await _userService.getUser().timeout(
        Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⏰ getUser() timed out after 2 seconds');
          return {'success': false, 'message': 'Timeout'};
        },
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        _currentUserId = _parseToInt(userData['id']);

        // Save to local DB for next time
        final userModel = UserModel(
          id: _currentUserId!,
          name: userData['name'] ?? '',
          phone: userData['phone'] ?? '',
          role: userData['role'] ?? '',
          profilePic: userData['profile_pic'],
          callAccess: userData['call_access'] == true,
        );
        await _userRepo.insertOrUpdateUser(userModel);
        // Cache admin/staff status
        _isAdminOrStaff =
            widget.group.role == 'admin' || userModel.role == 'staff';
      } else {
        debugPrint('⚠️ Could not get current user ID from API');
      }
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
    }

    if (_currentUserId == null) {
      debugPrint('⚠️ WARNING: Could not determine current user ID for group');
    }

    // Initialize admin/staff status if not already set

    // Try to get user role from cache
    try {
      final cachedUser = await _userRepo.getFirstUser();
      if (cachedUser != null) {
        setState(() {
          _isAdminOrStaff =
              widget.group.role == 'admin' || cachedUser.role == 'staff';
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking admin/staff status: $e');
    }
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Initialize user info cache with known group members and save to DB
  /// MUST be awaited to ensure names are available before displaying messages
  Future<void> _initializeUserCache() async {
    debugPrint('👥 Loading group members for caching...');

    // STEP 1: Load latest group info from local DB (might have more up-to-date member list)
    GroupModel? cachedGroup;
    try {
      final groupsRepo = GroupsRepository();
      cachedGroup = await groupsRepo.getGroupById(widget.group.conversationId);
      if (cachedGroup != null && cachedGroup.members.isNotEmpty) {
        debugPrint(
          '📦 Using ${cachedGroup.members.length} members from local DB',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Could not load group from local DB: $e');
    }

    // Use cached group members if available, otherwise use widget.group.members
    final membersToCache = cachedGroup?.members ?? widget.group.members;

    debugPrint('👥 Caching ${membersToCache.length} group members...');

    // STEP 2: Cache all members to BOTH memory AND local DB
    for (final member in membersToCache) {
      // 1. Cache in memory FIRST (synchronous, instant lookup)
      _userInfoCache[member.userId] = {
        'name': member.name,
        'profile_pic': member.profilePic,
      };

      // 2. Save to group_members table (not users table) for offline access
      try {
        final memberInfo = GroupMemberInfo(
          userId: member.userId,
          userName: member.name,
          profilePic: member.profilePic,
          role: member.role,
          joinedAt: member.joinedAt,
        );
        await _groupMembersRepo.insertOrUpdateGroupMember(
          widget.group.conversationId,
          memberInfo,
        );
      } catch (e) {
        debugPrint('❌ Error caching member ${member.userId} to DB: $e');
      }
    }

    // STEP 3: Cache current user info in memory
    if (_currentUserId != null) {
      _userInfoCache[_currentUserId!] = {'name': 'You', 'profile_pic': null};
    }

    debugPrint(
      '✅ Cached ${membersToCache.length} group members to local DB and memory',
    );
    debugPrint('✅ _userInfoCache now has ${_userInfoCache.length} users');
  }

  /// Load pinned message from storage or conversation metadata
  Future<void> _loadPinnedMessageFromStorage() async {
    final conversationId = widget.group.conversationId;

    // First check if group metadata has pinned message
    if (widget.group.metadata?.pinnedMessage != null) {
      final pinnedMessageId = widget.group.metadata!.pinnedMessage!.messageId;
      if (mounted) {
        setState(() {
          _pinnedMessageId = pinnedMessageId;
        });
        return;
      }
    }

    // Fallback to local storage
    final pinnedMessageId =
        await MessageStorageHelpers.loadPinnedMessageFromStorage(
          conversationId,
        );

    if (pinnedMessageId != null && mounted) {
      setState(() {
        _pinnedMessageId = pinnedMessageId;
      });
    }
  }

  /// Load starred messages from storage
  Future<void> _loadStarredMessagesFromStorage() async {
    final conversationId = widget.group.conversationId;
    final starredMessages =
        await MessageStorageHelpers.loadStarredMessagesFromStorage(
          conversationId,
        );

    if (starredMessages.isNotEmpty && mounted) {
      setState(() {
        _starredMessages.clear();
        _starredMessages.addAll(starredMessages);
      });
    }
  }

  /// Validate pinned message exists in current messages and clean up if not
  void _validatePinnedMessage() {
    // Don't validate if we don't have a full message set yet
    // Only validate if we've loaded a significant number of messages
    // This prevents clearing pinned messages during initial load or pagination
    if (_pinnedMessageId != null && _messages.length > 20) {
      final messageExists = _messages.any((msg) => msg.id == _pinnedMessageId);
      if (!messageExists && mounted) {
        debugPrint(
          '⚠️ Pinned message $_pinnedMessageId not found in current group messages, but keeping it (might be paginated)',
        );
        // Don't clear the pinned message - it might just be in a different page
        // Only clear if we explicitly receive an unpin action via WebSocket
      }
    }
  }

  /// Validate starred messages exist in current messages and clean up invalid ones
  void _validateStarredMessages() {
    if (_starredMessages.isNotEmpty && _messages.isNotEmpty) {
      final currentMessageIds = _messages.map((msg) => msg.id).toSet();
      final invalidStarredMessages = _starredMessages
          .where((starredId) => !currentMessageIds.contains(starredId))
          .toList();

      if (invalidStarredMessages.isNotEmpty && mounted) {
        debugPrint(
          '⚠️ ${invalidStarredMessages.length} starred messages not found in current group messages, cleaning up',
        );

        setState(() {
          _starredMessages.removeAll(invalidStarredMessages);
        });

        // Update storage with cleaned up starred messages
        _messagesRepo.saveStarredMessages(
          conversationId: widget.group.conversationId,
          starredMessageIds: _starredMessages,
        );
      }
    }
  }

  /// Validate reply messages are properly loaded and structured
  void _validateReplyMessages() {
    if (_messages.isEmpty) return;

    Future.microtask(() async {
      try {
        // Count reply messages in current UI
        final replyMessagesInUI = _messages
            .where(
              (msg) =>
                  msg.replyToMessage != null || msg.replyToMessageId != null,
            )
            .toList();

        debugPrint(
          '🔍 Found ${replyMessagesInUI.length} reply messages in group cache',
        );

        // Validate each reply message
        for (final message in replyMessagesInUI) {
          if (message.replyToMessage != null) {
            debugPrint(
              '✅ Group reply message ${message.id} has complete reply data: "${message.replyToMessage!.body}" by ${message.replyToMessage!.senderName}',
            );
          } else if (message.replyToMessageId != null) {
            // Try to find the referenced message in current messages
            MessageModel? referencedMessage;
            try {
              referencedMessage = _messages.firstWhere(
                (msg) => msg.id == message.replyToMessageId,
              );
            } catch (e) {
              referencedMessage = null;
            }
            if (referencedMessage != null) {
              debugPrint(
                '🔗 Group reply message ${message.id} references existing message ${message.replyToMessageId}',
              );
            } else {
              debugPrint(
                '⚠️ Group reply message ${message.id} references missing message ${message.replyToMessageId}',
              );
            }
          }
        }

        // Validate storage
        await _messagesRepo.validateReplyMessageStorage(
          widget.group.conversationId,
        );
      } catch (e) {
        debugPrint('❌ Error validating group reply messages: $e');
      }
    });
  }

  /// Cache user info from conversation metadata to local DB
  Future<void> _cacheUsersFromMetadata() async {
    if (_conversationMeta == null || _conversationMeta!.members.isEmpty) return;

    try {
      for (final member in _conversationMeta!.members) {
        final userId = member['user_id'] as int?;
        final userName = member['name'] as String?;
        final profilePic = member['profile_pic'] as String?;

        if (userId != null && userName != null) {
          // Cache in memory
          _userInfoCache[userId] = {
            'name': userName,
            'profile_pic': profilePic,
          };

          // Save to group_members table (not users table) for offline access
          final memberInfo = GroupMemberInfo(
            userId: userId,
            userName: userName,
            profilePic: profilePic,
            role: 'member', // Default role from metadata
            joinedAt: null,
          );
          await _groupMembersRepo.insertOrUpdateGroupMember(
            widget.group.conversationId,
            memberInfo,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error caching users from metadata: $e');
    }
  }

  /// Populate sender names for reply messages loaded from cache
  void _populateReplyMessageSenderNames() {
    if (_messages.isEmpty) return;

    bool hasUpdates = false;
    final updatedMessages = <MessageModel>[];

    for (final message in _messages) {
      if (message.replyToMessage != null &&
          message.replyToMessage!.senderName.isEmpty) {
        // Reply message exists but sender name is empty, populate it
        final senderId = message.replyToMessage!.senderId;
        String senderName;
        String? senderProfilePic;

        // First try to find the original message in the messages array
        try {
          final originalMessage = _messages.firstWhere(
            (msg) => msg.id == message.replyToMessage!.id,
          );
          senderName = originalMessage.senderName;
          senderProfilePic = originalMessage.senderProfilePic;
          debugPrint(
            '✅ Found original message in array for cached reply: $senderName',
          );
        } catch (e) {
          // If not found, use cache/DB
          final senderInfo = _getUserInfo(senderId);
          senderName = senderInfo['name'] ?? 'Unknown User';
          senderProfilePic = senderInfo['profile_pic'];
          debugPrint(
            '⚠️ Original message not in array, using cache for cached reply: $senderName',
          );
        }

        final updatedReplyMessage = MessageModel(
          id: message.replyToMessage!.id,
          body: message.replyToMessage!.body,
          type: message.replyToMessage!.type,
          senderId: message.replyToMessage!.senderId,
          conversationId: message.replyToMessage!.conversationId,
          createdAt: message.replyToMessage!.createdAt,
          editedAt: message.replyToMessage!.editedAt,
          metadata: message.replyToMessage!.metadata,
          attachments: message.replyToMessage!.attachments,
          deleted: message.replyToMessage!.deleted,
          senderName: senderName,
          senderProfilePic: senderProfilePic,
          replyToMessage: message.replyToMessage!.replyToMessage,
          replyToMessageId: message.replyToMessage!.replyToMessageId,
        );

        final updatedMessage = MessageModel(
          id: message.id,
          body: message.body,
          type: message.type,
          senderId: message.senderId,
          conversationId: message.conversationId,
          createdAt: message.createdAt,
          editedAt: message.editedAt,
          metadata: message.metadata,
          attachments: message.attachments,
          deleted: message.deleted,
          senderName: message.senderName,
          senderProfilePic: message.senderProfilePic,
          replyToMessage: updatedReplyMessage,
          replyToMessageId: message.replyToMessageId,
        );

        updatedMessages.add(updatedMessage);
        hasUpdates = true;

        debugPrint(
          '🔧 Updated group reply message sender name for message ${message.id}',
        );
      } else {
        updatedMessages.add(message);
      }
    }

    if (hasUpdates && mounted) {
      setState(() {
        _messages = updatedMessages;
      });
      debugPrint(
        '✅ Updated ${updatedMessages.where((m) => m.replyToMessage != null).length} group reply messages with sender names',
      );
    }
  }

  /// Show ReadBy modal for a specific message
  void _showReadByModal(MessageModel message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReadByModal(
        message: message,
        members: _conversationMeta?.members ?? [],
        currentUserId: _currentUserId,
      ),
    );
  }

  @override
  void deactivate() {
    // Send inactive message when user navigates away from the page
    _websocketService
        .sendMessage({
          'type': 'inactive_in_conversation',
          'conversation_id': widget.group.conversationId,
        })
        .catchError((e) {
          debugPrint(
            '❌ Error sending inactive_in_conversation in deactivate: $e',
          );
        });
    super.deactivate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _isOtherTypingNotifier.dispose();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _mediaSubscription?.cancel();
    _messagePinSubscription?.cancel();
    _messageStarSubscription?.cancel();
    _messageReplySubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _typingAnimationController.dispose();
    _typingTimeout?.cancel();
    _scrollDebounceTimer?.cancel();
    _highlightTimer?.cancel();
    _draftSaveTimer?.cancel();

    // Save draft before disposing
    if (_messageController.text.isNotEmpty) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(
        widget.group.conversationId,
        _messageController.text,
      );
    }

    // Remove listener
    _messageController.removeListener(_onMessageTextChanged);

    // Dispose message animation controllers
    for (final controller in _messageAnimationControllers.values) {
      controller.dispose();
    }
    _messageAnimationControllers.clear();
    _messageSlideAnimations.clear();
    _messageFadeAnimations.clear();
    _animatedMessages.clear();

    // Dispose swipe animation controllers
    for (final controller in _swipeAnimationControllers.values) {
      controller.dispose();
    }
    _swipeAnimationControllers.clear();
    _swipeAnimations.clear();

    // Dispose audio animation controllers
    for (final controller in _audioAnimationControllers.values) {
      controller.dispose();
    }
    _audioAnimationControllers.clear();
    _audioAnimations.clear();

    // Dispose voice recording controllers
    _voiceModalAnimationController.dispose();
    _zigzagAnimationController.dispose();
    _recordingTimer?.cancel();
    _timerStreamController.close();
    _recorder.closeRecorder();

    _websocketService
        .sendMessage({
          'type': 'inactive_in_conversation',
          'conversation_id': widget.group.conversationId,
        })
        .catchError((e) {
          debugPrint('❌ Error sending inactive_in_conversation: $e');
        });

    // Properly close the audio player
    try {
      if (_audioPlayer.isPlaying) {
        _audioPlayer.stopPlayer();
      }
      _audioProgressSubscription?.cancel();
      _stopAudioProgressTimer();
      _audioPlayer.closePlayer();
    } catch (e) {
      debugPrint('Warning: Error closing audio player during dispose: $e');
    }

    super.dispose();
  }

  void _onScroll() {
    // Ensure we have a valid scroll position and the widget is still mounted
    if (!mounted || !_scrollController.hasClients) return;

    final currentScrollPosition = _scrollController.position.pixels;
    final scrollDelta = (currentScrollPosition - _lastScrollPosition).abs();

    // Only set scrolling flag if there's significant movement (more than 5 pixels)
    if (scrollDelta > 5.0) {
      _isScrolling = true;
      _lastScrollPosition = currentScrollPosition;

      // Reset scrolling flag after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _isScrolling = false;
        }
      });
    }

    // Debounce sticky date separator updates to reduce frequency
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted && _scrollController.hasClients) {
        _updateStickyDateSeparator();
      }
    });

    // With reverse: true, when scrolling to see older messages (scrolling "up" in the UI),
    // we're actually scrolling towards maxScrollExtent
    // Load older messages when we're near the top of the scroll (close to maxScrollExtent)
    final scrollPosition = _scrollController.position.pixels;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final distanceFromTop = maxScrollExtent - scrollPosition;

    if (distanceFromTop <= 200) {
      if (!_isLoadingMore && _hasMoreMessages && _isInitialized) {
        debugPrint(
          '🔄 Triggering load more group messages - Distance from top: $distanceFromTop',
        );
        _loadMoreMessages();
      }
    }
  }

  /// Update sticky date separator based on current scroll position
  void _updateStickyDateSeparator() {
    if (_messages.isEmpty || !_scrollController.hasClients) return;

    // Calculate which message is currently visible at the top
    final scrollOffset = _scrollController.offset;
    final itemHeight = 100.0; // Approximate height per message
    final visibleIndex = (scrollOffset / itemHeight).floor();

    // Find the message that should show the sticky date
    final messageIndex = _messages.length - 1 - visibleIndex;
    if (messageIndex >= 0 && messageIndex < _messages.length) {
      final currentMessage = _messages[messageIndex];
      final currentDateString = ChatHelpers.getMessageDateString(
        currentMessage.createdAt,
      );

      // Only update if the date has changed
      if (_currentStickyDate != currentDateString) {
        setState(() {
          _currentStickyDate = currentDateString;
          _showStickyDate = true;
        });
      }
    }
  }

  /// Build sticky date separator that appears at the top when scrolling
  Widget _buildStickyDateSeparator() {
    if (!_showStickyDate || _currentStickyDate == null) {
      return const SizedBox.shrink();
    }

    // Find a message with the current date to get the formatted date string
    final messageWithCurrentDate = _messages.firstWhere(
      (message) =>
          ChatHelpers.getMessageDateString(message.createdAt) ==
          _currentStickyDate,
      orElse: () => _messages.first,
    );

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          ChatHelpers.formatDateSeparator(messageWithCurrentDate.createdAt),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _loadInitialMessages() async {
    try {
      final conversationId = widget.group.conversationId;

      // ALWAYS load from local DB first for instant display
      if (!_hasCheckedCache) {
        final cachedData = await _messagesRepo.getCachedMessages(
          conversationId,
        );

        if (cachedData != null && cachedData.messages.isNotEmpty) {
          // Filter out old orphaned optimistic messages (messages with negative IDs older than 5 minutes)
          final now = DateTime.now();
          final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

          final cleanedMessages = cachedData.messages.where((msg) {
            // Keep all messages with positive IDs (server-confirmed)
            if (msg.id >= 0) return true;

            // For optimistic messages (negative IDs), only keep recent ones
            try {
              final createdAt = DateTime.parse(msg.createdAt);
              return createdAt.isAfter(fiveMinutesAgo);
            } catch (e) {
              // If we can't parse the date, keep the message to be safe
              return true;
            }
          }).toList();

          // Remove duplicates by ID (keep the one with positive ID if both exist)
          final messageMap = <int, MessageModel>{};
          for (final msg in cleanedMessages) {
            final existingMsg = messageMap[msg.id.abs()];
            // Prefer positive IDs (server-confirmed) over negative IDs (optimistic)
            if (existingMsg == null || msg.id > 0) {
              messageMap[msg.id.abs()] = msg;
            }
          }
          final deduplicatedMessages = messageMap.values.toList()
            ..sort((a, b) => a.id.compareTo(b.id));

          if (mounted) {
            setState(() {
              _isCheckingCache = false;
              _isLoadingFromCache = false;
              _messages = deduplicatedMessages;
              _conversationMeta = cachedData.meta;
              _hasMoreMessages = cachedData.meta.hasNextPage;
              _currentPage = cachedData.meta.currentPage;
              _isInitialized = true;
              _isLoading = false;
              _errorMessage = null;
              _hasCheckedCache = true;
            });

            // Validate messages
            _validatePinnedMessage();
            _validateStarredMessages();
            _validateReplyMessages();
            _populateReplyMessageSenderNames();
          }
        } else {
          debugPrint('ℹ️ No cached group messages found in local DB');
          _hasCheckedCache = true;
        }
      }

      // If we already have messages from cache, do smart sync silently
      if (_messages.isNotEmpty) {
        debugPrint('📡 Silently syncing group with server in background...');
        await _performSmartSync(conversationId);
        return;
      }

      // Show loading only if we don't have cached messages
      if (_messages.isEmpty && mounted) {
        setState(() {
          _isCheckingCache = false;
          _isLoading = true;
          _isLoadingFromCache = false;
          _errorMessage = null;
        });
      }

      try {
        final response = await _groupsService.getGroupConversationHistory(
          conversationId: conversationId,
          page: 1,
          limit: 20,
        );

        if (!mounted) return;

        if (response['success'] == true && response['data'] != null) {
          final historyResponse = ConversationHistoryResponse.fromJson(
            response['data'],
          );

          final processedMessages = historyResponse.messages;
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);

          // Save to local DB
          await _messagesRepo.saveMessages(
            conversationId: conversationId,
            messages: processedMessages,
            meta: _conversationMeta!,
          );

          setState(() {
            _messages = processedMessages;
            _hasMoreMessages = historyResponse.hasNextPage;
            _currentPage = 1;
            _isLoading = false;
            _isLoadingFromCache = false;
            _isInitialized = true;
          });

          _validatePinnedMessage();
          _validateStarredMessages();
          _validateReplyMessages();
          _populateReplyMessageSenderNames();

          // Cache user info from metadata for offline access
          await _cacheUsersFromMetadata();
        } else {
          setState(() {
            _errorMessage =
                response['message'] ?? 'Failed to load group messages';
            _isLoading = false;
            _isLoadingFromCache = false;
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading group messages from server: $e');

        // On network error, if we have cached data, keep showing it
        if (mounted) {
          if (_messages.isNotEmpty) {
            setState(() {
              _isLoading = false;
              _isLoadingFromCache = false;
              _isInitialized = true;
              _errorMessage = null; // Don't show error if we have cache
            });
          } else {
            setState(() {
              _errorMessage = 'No internet connection';
              _isLoading = false;
              _isLoadingFromCache = false;
              _isInitialized = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Critical error in group _loadInitialMessages: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load group messages: ${e.toString()}';
          _isLoading = false;
          _isLoadingFromCache = false;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || !mounted) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final conversationId = widget.group.conversationId;
      final response = await _groupsService.getGroupConversationHistory(
        conversationId: conversationId,
        page: _currentPage + 1,
        limit: 20,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final historyResponse = ConversationHistoryResponse.fromJson(
          response['data'],
        );
        final newMessages = historyResponse.messages;

        // Update conversation metadata
        _conversationMeta = ConversationMeta.fromResponse(historyResponse);

        // Add to cache (insert at beginning for older messages)
        await _messagesRepo.addMessagesToCache(
          conversationId: conversationId,
          newMessages: newMessages,
          updatedMeta: _conversationMeta!,
          insertAtBeginning: true,
        );

        setState(() {
          // Insert older messages at the beginning (chronologically)
          _messages.insertAll(0, newMessages);
          _hasMoreMessages = historyResponse.hasNextPage;
          _currentPage++;
          _isLoadingMore = false;
        });

        _populateReplyMessageSenderNames();

        // Cache user info from metadata for offline access
        await _cacheUsersFromMetadata();
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Set up WebSocket message listener for real-time group messages
  void _setupWebSocketListener() {
    final conversationId = widget.group.conversationId;

    // Listen to messages filtered for this conversation
    _messageSubscription = _messageHandler
        .messagesForConversation(conversationId)
        .listen(
          (message) => _handleIncomingMessage(message),
          onError: (error) {
            debugPrint('❌ Group message stream error: $error');
          },
        );

    // Listen to typing events for this conversation
    _typingSubscription = _messageHandler
        .typingForConversation(conversationId)
        .listen(
          (message) => _reciveTyping(message),
          onError: (error) {
            debugPrint('❌ Group typing stream error: $error');
          },
        );

    // Listen to media messages for this conversation
    _mediaSubscription = _messageHandler
        .mediaForConversation(conversationId)
        .listen(
          (message) => _handleIncomingMediaMessages(message),
          onError: (error) {
            debugPrint('❌ Group media stream error: $error');
          },
        );

    // Listen to message pins for this conversation
    _messagePinSubscription = _messageHandler
        .messagePinsForConversation(conversationId)
        .listen(
          (message) => _handleMessagePin(message),
          onError: (error) {
            debugPrint('❌ Group message pin stream error: $error');
          },
        );

    // Listen to message stars for this conversation
    _messageStarSubscription = _messageHandler
        .messageStarsForConversation(conversationId)
        .listen(
          (message) => _handleMessageStar(message),
          onError: (error) {
            debugPrint('❌ Group message star stream error: $error');
          },
        );

    // Listen to message replies for this conversation
    _messageReplySubscription = _messageHandler
        .messageRepliesForConversation(conversationId)
        .listen(
          (message) => _handleMessageReply(message),
          onError: (error) {
            debugPrint('❌ Group message reply stream error: $error');
          },
        );

    // Listen to message delete events for this conversation
    _messageDeleteSubscription = _messageHandler
        .messageDeletesForConversation(conversationId)
        .listen(
          (message) => _handleMessageDelete(message),
          onError: (error) {
            debugPrint('❌ Group message delete stream error: $error');
          },
        );
  }

  /// Handle incoming message from WebSocket
  void _handleIncomingMessage(Map<String, dynamic> messageData) async {
    try {
      // Extract message data from WebSocket payload
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final messageBody = data['body'] as String? ?? '';
      final senderId = _parseToInt(data['sender_id']);
      final senderName = data['sender_name'];
      final messageId = data['id'];

      final optimisticId = data['optimistic_id'] ?? data['optimisticId'];

      // Skip if this is our own optimistic message being echoed back
      if (_optimisticMessageIds.contains(optimisticId)) {
        debugPrint('🔄 Replacing optimistic group message with server message');
        _replaceOptimisticMessage(optimisticId, messageData);
        return;
      }

      // If this is our own message (sender), update the optimistic message in local storage
      if (_currentUserId != null && senderId == _currentUserId) {
        await _updateOptimisticMessageInStorage(
          optimisticId,
          messageId,
          messageData,
        );
        return;
      }

      // Check for duplicate message before processing
      if (messageId != null && _messages.any((msg) => msg.id == messageId)) {
        debugPrint('⚠️ Duplicate message detected (ID: $messageId), skipping');
        return;
      }

      // Use sender name directly from socket message
      String? senderProfilePic;

      // Try to get profile pic from cache if available
      final senderInfo = _getUserInfo(senderId);
      senderProfilePic = senderInfo['profile_pic'];

      // Handle reply message data
      MessageModel? replyToMessage;
      int? replyToMessageId;

      // Check for reply data in metadata first (server format)
      final metadata = data['metadata'] as Map<String, dynamic>?;
      if (metadata != null && metadata['reply_to'] != null) {
        final replyToData = metadata['reply_to'] as Map<String, dynamic>;
        replyToMessageId = _parseToInt(replyToData['message_id']);

        // Try to find the original message in local messages first
        try {
          replyToMessage = _messages.firstWhere(
            (msg) => msg.id == replyToMessageId,
          );
          debugPrint('✅ Found original message in local array for reply');
        } catch (e) {
          // Message not in local array, create from metadata
          final repliedToSenderId = _parseToInt(replyToData['sender_id']);

          // Get the sender name for the replied-to message
          final replySenderName = replyToData['sender_name'] as String?;
          String finalReplySenderName;
          String? replySenderProfilePic;

          if (replySenderName != null && replySenderName.isNotEmpty) {
            // Use sender name from metadata
            finalReplySenderName = replySenderName;
          } else {
            // Fallback to user info cache/DB
            final senderInfo = _getUserInfo(repliedToSenderId);
            finalReplySenderName = senderInfo['name'] ?? 'Unknown User';
          }

          replySenderProfilePic = _getUserInfo(
            repliedToSenderId,
          )['profile_pic'];

          // Create reply message from metadata
          replyToMessage = MessageModel(
            id: replyToMessageId,
            body: replyToData['body'] ?? '',
            type: 'text',
            senderId: repliedToSenderId,
            conversationId: widget.group.conversationId,
            createdAt: replyToData['created_at'] ?? '',
            deleted: false,
            senderName: finalReplySenderName,
            senderProfilePic: replySenderProfilePic,
          );
        }
      } else if (data['reply_to_message'] != null) {
        replyToMessage = MessageModel.fromJson(
          data['reply_to_message'] as Map<String, dynamic>,
        );
      } else if (data['reply_to_message_id'] != null) {
        replyToMessageId = _parseToInt(data['reply_to_message_id']);
        // Find the replied message in our local messages
        try {
          replyToMessage = _messages.firstWhere(
            (msg) => msg.id == replyToMessageId,
          );
        } catch (e) {
          debugPrint(
            '⚠️ Reply message not found in local group messages: $replyToMessageId',
          );
        }
      }

      // Create MessageModel from WebSocket data
      final nowUTC = DateTime.now().toUtc();
      final newMessage = MessageModel(
        id: messageId ?? DateTime.now().millisecondsSinceEpoch,
        body: messageBody,
        type: data['type'] ?? 'text',
        senderId: senderId,
        conversationId: widget.group.conversationId,
        createdAt:
            data['created_at'] ?? nowUTC.toIso8601String(), // Store as UTC
        editedAt: data['edited_at'],
        metadata: data['metadata'],
        attachments: data['attachments'],
        deleted: data['deleted'] == true,
        senderName: senderName,
        senderProfilePic: senderProfilePic,
        replyToMessage: replyToMessage,
        replyToMessageId: replyToMessageId,
      );

      // Add message to UI immediately with animation
      if (mounted) {
        setState(() {
          _messages.add(newMessage);
          // _messages.sort((a, b) => a.id.toString().compareTo(b.id.toString()));
          // Update sticky date separator for new messages
          _currentStickyDate = ChatHelpers.getMessageDateString(
            newMessage.createdAt,
          );
          _showStickyDate = true;
        });

        // _animateNewMessage(newMessage.id);
        // _scrollToBottom();
      }

      // Store message asynchronously
      _storeMessageAsync(newMessage);
    } catch (e) {
      debugPrint('❌ Error processing incoming group message: $e');
    }
  }

  /// Update optimistic message in local storage with server ID (for sender's own messages)
  Future<void> _updateOptimisticMessageInStorage(
    int? optimisticId,
    int? serverId,
    Map<String, dynamic> messageData,
  ) async {
    final updatedMessage =
        await MessageStorageHelpers.updateOptimisticMessageInStorage(
          widget.group.conversationId,
          optimisticId,
          serverId,
          messageData,
        );

    if (updatedMessage != null && optimisticId != null && mounted) {
      // Update the in-memory _messages list
      final uiMessageIndex = _messages.indexWhere(
        (msg) => msg.id == optimisticId,
      );
      if (uiMessageIndex != -1) {
        setState(() {
          _messages[uiMessageIndex] = updatedMessage;
        });
        debugPrint(
          '✅ Updated group message ID from $optimisticId to ${updatedMessage.id} in UI',
        );
      }
    }
  }

  /// Replace optimistic message with server-confirmed message
  void _replaceOptimisticMessage(
    int optimisticId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      final index = _messages.indexWhere((msg) => msg.id == optimisticId);
      if (index != -1) {
        final data = messageData['data'] as Map<String, dynamic>? ?? {};
        final messageType = messageData['type'];

        // Handle media messages
        if (messageType == 'media') {
          final optimisticMessage = _messages[index];
          final mediaType = data['message_type'] ?? data['type'] ?? 'image';
          final mediaData = data['media'] as Map<String, dynamic>? ?? data;
          final serverId = data['id'] ?? data['messageId'];

          // Determine the actual message type based on loading type or media type
          String actualType;
          if (optimisticMessage.type == 'image_loading') {
            actualType = 'image';
          } else if (optimisticMessage.type == 'video_loading') {
            actualType = 'video';
          } else if (optimisticMessage.type == 'document_loading') {
            actualType = 'document';
          } else if (optimisticMessage.type == 'audio_loading') {
            actualType =
                'audios'; // Use 'audios' to match the UI rendering logic
          } else {
            // Use the media type from server
            actualType = mediaType.toLowerCase();
            // Audio messages use 'audios' type
            if (actualType == 'audio' || actualType == 'voice') {
              actualType = 'audios';
            }
          }

          // Create confirmed media message preserving all optimistic data
          final confirmedMessage = MessageModel(
            id: serverId ?? optimisticMessage.id,
            body: optimisticMessage.body,
            type: actualType,
            senderId: optimisticMessage.senderId,
            conversationId: optimisticMessage.conversationId,
            createdAt: data['created_at'] ?? optimisticMessage.createdAt,
            editedAt: data['edited_at'],
            metadata: data['metadata'] ?? optimisticMessage.metadata,
            attachments: mediaData,
            deleted: data['deleted'] == true,
            senderName: optimisticMessage.senderName,
            senderProfilePic: optimisticMessage.senderProfilePic,
            replyToMessage: optimisticMessage.replyToMessage,
            replyToMessageId: optimisticMessage.replyToMessageId,
          );

          if (mounted) {
            setState(() {
              _messages[index] = confirmedMessage;
            });
          }

          // Delete old optimistic message and add confirmed message to database
          Future.microtask(() async {
            try {
              // Delete the old optimistic message from database
              await _messagesRepo.deleteMessage(optimisticMessage.id);

              // Store confirmed message with server ID
              if (_conversationMeta != null) {
                await _messagesRepo.addMessageToCache(
                  conversationId: widget.group.conversationId,
                  newMessage: confirmedMessage,
                  updatedMeta: _conversationMeta!,
                  insertAtBeginning: false,
                );
                debugPrint(
                  '💾 Stored confirmed media message ${confirmedMessage.id} to DB',
                );
              }
            } catch (e) {
              debugPrint(
                '❌ Error replacing optimistic media message in DB: $e',
              );
            }
          });
        } else if (messageType == 'message_reply') {
          // Handle reply messages differently
          final newMessageId = data['new_message_id'];
          final messageBody = data['new_message'] ?? _messages[index].body;
          final timestamp =
              messageData['timestamp'] ?? _messages[index].createdAt;

          // Preserve the reply relationship from the optimistic message
          final optimisticMessage = _messages[index];

          // Create confirmed reply message
          final confirmedMessage = MessageModel(
            id: newMessageId ?? DateTime.now().millisecondsSinceEpoch,
            body: messageBody,
            type: 'text',
            senderId: optimisticMessage.senderId,
            conversationId: optimisticMessage.conversationId,
            createdAt: timestamp,
            deleted: false,
            senderName: optimisticMessage.senderName,
            senderProfilePic: optimisticMessage.senderProfilePic,
            replyToMessage:
                optimisticMessage.replyToMessage, // Preserve reply relationship
            replyToMessageId: optimisticMessage.replyToMessageId,
          );

          if (mounted) {
            setState(() {
              _messages[index] = confirmedMessage;
            });
          }

          await _messagesRepo.updateOptimisticMessage(
            optimisticMessage.conversationId,
            optimisticId,
            newMessageId,
            messageData,
          );

          // Store confirmed message with reply data
          _storeMessageAsync(confirmedMessage);

          debugPrint(
            '✅ Replaced optimistic group reply message with server-confirmed message',
          );
        } else {
          // Handle regular text messages
          final senderId = data['sender_id'] != null
              ? _parseToInt(data['sender_id'])
              : _messages[index].senderId;
          final senderInfo = _getUserInfo(senderId);

          // Create the confirmed message using utility
          final confirmedMessage = MessageStorageHelpers.createConfirmedMessage(
            optimisticId,
            messageData,
            _messages[index],
            senderInfo,
          );

          if (mounted) {
            setState(() {
              _messages[index] = confirmedMessage;
            });
          }

          // Store confirmed message
          _storeMessageAsync(confirmedMessage);
        }

        // Remove from optimistic tracking
        _optimisticMessageIds.remove(optimisticId);
      }
    } catch (e) {
      debugPrint('❌ Error replacing optimistic group message: $e');
    }
  }

  void _handleMessageReply(Map<String, dynamic> message) async {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final messageBody = data['new_message'] as String? ?? '';
      final newMessageId = data['new_message_id'];
      final userId = data['user_id'];
      final conversationId = message['conversation_id'];
      final messageIds = message['message_ids'] as List<dynamic>? ?? [];
      final timestamp = message['timestamp'] as String?;
      final optimisticId = data['optimistic_id'];
      final senderName = data['sender_name'] as String? ?? 'Unknown User';

      // Skip if this is not for our group conversation
      if (conversationId != widget.group.conversationId) {
        return;
      }

      // Check if this is our own optimistic message being confirmed
      if (_optimisticMessageIds.contains(optimisticId)) {
        _replaceOptimisticMessage(optimisticId, message);
        return;
      }

      // If this is our own message (sender), update the optimistic message in local storage
      if (_currentUserId != null && userId == _currentUserId) {
        await _updateOptimisticMessageInStorage(
          optimisticId,
          newMessageId,
          message,
        );
        return;
      }

      // Check for duplicate message before processing
      if (newMessageId != null &&
          _messages.any((msg) => msg.id == newMessageId)) {
        debugPrint(
          '⚠️ Duplicate reply message detected (ID: $newMessageId), skipping',
        );
        return;
      }

      // Try to get profile pic from cache if available
      String? senderProfilePic;
      final cachedInfo = _getUserInfo(userId);
      senderProfilePic = cachedInfo['profile_pic'];

      // Find the original message being replied to
      MessageModel? replyToMessage;
      int? replyToMessageId;

      if (messageIds.isNotEmpty) {
        final originalMessageId = _parseToInt(messageIds.first);
        replyToMessageId = originalMessageId;

        // Try to find the original message in our local messages
        try {
          replyToMessage = _messages.firstWhere(
            (msg) => msg.id == originalMessageId,
          );
        } catch (e) {
          debugPrint(
            '⚠️ Original message not found in local group messages: $originalMessageId',
          );
          // Create a placeholder if we don't have the original message
          replyToMessage = null;
        }
      }

      // Create the reply message
      final replyMessage = MessageModel(
        id: newMessageId ?? DateTime.now().millisecondsSinceEpoch,
        body: messageBody,
        type: 'text',
        senderId: userId ?? 0,
        conversationId: conversationId,
        createdAt: timestamp ?? DateTime.now().toUtc().toIso8601String(),
        deleted: false,
        senderName: senderName,
        senderProfilePic: senderProfilePic,
        replyToMessage: replyToMessage,
        replyToMessageId: replyToMessageId,
      );

      // Add message to UI immediately with animation
      if (mounted) {
        setState(() {
          _messages.add(replyMessage);
          // Update sticky date separator for new messages
          _currentStickyDate = ChatHelpers.getMessageDateString(
            replyMessage.createdAt,
          );
          _showStickyDate = true;
        });

        _animateNewMessage(replyMessage.id);
        _scrollToBottom();
      }

      // Store message asynchronously in local storage
      _storeMessageAsync(replyMessage);
    } catch (e) {
      debugPrint('❌ Error processing group message_reply: $e');
    }
  }

  /// Handle incoming media messages from WebSocket
  void _handleIncomingMediaMessages(Map<String, dynamic> messageData) async {
    try {
      // Extract message data from WebSocket payload
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final senderId = _parseToInt(
        data['sender_id'] ?? data['senderId'] ?? data['user_id'],
      );
      final messageId =
          data['id'] ?? data['messageId'] ?? data['media_message_id'];
      final optimisticId = data['optimistic_id'] ?? data['optimisticId'];

      // Skip if this is our own optimistic message being echoed back
      if (_optimisticMessageIds.contains(optimisticId)) {
        _replaceOptimisticMessage(optimisticId, messageData);
        return;
      }

      // If this is our own message (sender), update the optimistic message in local storage
      if (_currentUserId != null && senderId == _currentUserId) {
        await _updateOptimisticMessageInStorage(
          optimisticId,
          messageId,
          messageData,
        );
        return;
      }

      // Check for duplicate message before processing
      if (messageId != null && _messages.any((msg) => msg.id == messageId)) {
        debugPrint(
          '⚠️ Duplicate media message detected (ID: $messageId), skipping',
        );
        return;
      }

      // Extract sender_name directly from socket message
      final senderName = data['sender_name'] ?? 'Unknown User';

      // Try to get profile pic from cache if available
      String? senderProfilePic;
      final senderInfo = _getUserInfo(senderId);
      senderProfilePic = senderInfo['profile_pic'];

      // Handle reply message data for media messages
      MessageModel? replyToMessage;
      int? replyToMessageId;

      // Check for reply data in metadata first (server format)
      final metadata = data['metadata'] as Map<String, dynamic>?;
      if (metadata != null && metadata['reply_to'] != null) {
        final replyToData = metadata['reply_to'] as Map<String, dynamic>;
        replyToMessageId = _parseToInt(replyToData['message_id']);

        // Try to find the original message in local messages first
        try {
          replyToMessage = _messages.firstWhere(
            (msg) => msg.id == replyToMessageId,
          );
          debugPrint('✅ Found original message in local array for media reply');
        } catch (e) {
          // Message not in local array, create from metadata
          final repliedToSenderId = _parseToInt(replyToData['sender_id']);

          // Get the sender name for the replied-to message
          final replySenderName = replyToData['sender_name'] as String?;
          String finalReplySenderName;
          String? replySenderProfilePic;

          if (replySenderName != null && replySenderName.isNotEmpty) {
            // Use sender name from metadata
            finalReplySenderName = replySenderName;
          } else {
            // Fallback to user info cache/DB
            final senderInfo = _getUserInfo(repliedToSenderId);
            finalReplySenderName = senderInfo['name'] ?? 'Unknown User';
          }

          replySenderProfilePic = _getUserInfo(
            repliedToSenderId,
          )['profile_pic'];

          // Create reply message from metadata
          replyToMessage = MessageModel(
            id: replyToMessageId,
            body: replyToData['body'] ?? '',
            type: 'text',
            senderId: repliedToSenderId,
            conversationId: widget.group.conversationId,
            createdAt: replyToData['created_at'] ?? '',
            deleted: false,
            senderName: finalReplySenderName,
            senderProfilePic: replySenderProfilePic,
          );
        }
      } else if (data['reply_to_message'] != null) {
        replyToMessage = MessageModel.fromJson(
          data['reply_to_message'] as Map<String, dynamic>,
        );
      } else if (data['reply_to_message_id'] != null) {
        replyToMessageId = _parseToInt(data['reply_to_message_id']);
        // Find the replied message in our local messages
        try {
          replyToMessage = _messages.firstWhere(
            (msg) => msg.id == replyToMessageId,
          );
        } catch (e) {
          debugPrint(
            '⚠️ Reply message not found in local group messages: $replyToMessageId',
          );
        }
      }

      // Determine media type from the message data
      final mediaType = data['message_type'] ?? data['type'] ?? 'image';
      final mediaData = data['media'] as Map<String, dynamic>? ?? data;

      // Create MessageModel based on media type
      final nowUTC = DateTime.now().toUtc();
      MessageModel newMediaMessage;

      switch (mediaType.toLowerCase()) {
        case 'image':
          newMediaMessage = MessageModel(
            id: messageId ?? DateTime.now().millisecondsSinceEpoch,
            body: '', // Empty body for media messages
            type: 'image',
            senderId: senderId,
            conversationId: widget.group.conversationId,
            createdAt: data['created_at'] ?? nowUTC.toIso8601String(),
            editedAt: data['edited_at'],
            metadata: data['metadata'],
            attachments: mediaData,
            deleted: data['deleted'] == true,
            senderName: senderName,
            senderProfilePic: senderProfilePic,
            replyToMessage: replyToMessage,
            replyToMessageId: replyToMessageId,
          );
          break;

        case 'video':
          newMediaMessage = MessageModel(
            id: messageId ?? DateTime.now().millisecondsSinceEpoch,
            body: '', // Empty body for media messages
            type: 'video',
            senderId: senderId,
            conversationId: widget.group.conversationId,
            createdAt: data['created_at'] ?? nowUTC.toIso8601String(),
            editedAt: data['edited_at'],
            metadata: data['metadata'],
            attachments: mediaData,
            deleted: data['deleted'] == true,
            senderName: senderName,
            senderProfilePic: senderProfilePic,
            replyToMessage: replyToMessage,
            replyToMessageId: replyToMessageId,
          );
          break;

        case 'document':
        case 'docs':
          newMediaMessage = MessageModel(
            id: messageId ?? DateTime.now().millisecondsSinceEpoch,
            body: '', // Empty body for media messages
            type: 'document',
            senderId: senderId,
            conversationId: widget.group.conversationId,
            createdAt: data['created_at'] ?? nowUTC.toIso8601String(),
            editedAt: data['edited_at'],
            metadata: data['metadata'],
            attachments: mediaData,
            deleted: data['deleted'] == true,
            senderName: senderName,
            senderProfilePic: senderProfilePic,
            replyToMessage: replyToMessage,
            replyToMessageId: replyToMessageId,
          );
          break;

        case 'audio':
        case 'audios':
        case 'voice':
          newMediaMessage = MessageModel(
            id: messageId ?? DateTime.now().millisecondsSinceEpoch,
            body: '', // Empty body for media messages
            type: 'audios', // Use 'audios' to match the UI rendering logic
            senderId: senderId,
            conversationId: widget.group.conversationId,
            createdAt: data['created_at'] ?? nowUTC.toIso8601String(),
            editedAt: data['edited_at'],
            metadata: data['metadata'],
            attachments: mediaData,
            deleted: data['deleted'] == true,
            senderName: senderName,
            senderProfilePic: senderProfilePic,
            replyToMessage: replyToMessage,
            replyToMessageId: replyToMessageId,
          );
          break;

        default:
          debugPrint('⚠️ Unknown media type received: $mediaType');
          newMediaMessage = MessageModel(
            id: messageId ?? DateTime.now().millisecondsSinceEpoch,
            body: '', // Empty body for media messages
            type: 'attachment', // Fallback type
            senderId: senderId,
            conversationId: widget.group.conversationId,
            createdAt: data['created_at'] ?? nowUTC.toIso8601String(),
            editedAt: data['edited_at'],
            metadata: data['metadata'],
            attachments: mediaData,
            deleted: data['deleted'] == true,
            senderName: senderName,
            senderProfilePic: senderProfilePic,
            replyToMessage: replyToMessage,
            replyToMessageId: replyToMessageId,
          );
      }

      // Add message to UI immediately with animation
      if (mounted) {
        setState(() {
          _messages.add(newMediaMessage);
          // _messages.sort((a, b) => a.id.toString().compareTo(b.id.toString()));
          // Update sticky date separator for new messages
          _currentStickyDate = ChatHelpers.getMessageDateString(
            newMediaMessage.createdAt,
          );
          _showStickyDate = true;
        });

        // _animateNewMessage(newMediaMessage.id);
        // _scrollToBottom();
      }

      // Store message asynchronously in local storage
      _storeMessageAsync(newMediaMessage);

      debugPrint(
        '💾 Incoming group $mediaType message stored locally and displayed',
      );
    } catch (e) {
      debugPrint('❌ Error processing incoming group media message: $e');
    }
  }

  /// Handle incoming message pin from WebSocket
  void _handleMessagePin(Map<String, dynamic> message) async {
    final data = message['data'] as Map<String, dynamic>? ?? {};
    // Get message ID from message_ids array
    final messageIds = message['message_ids'] as List<dynamic>? ?? [];
    final messageId = messageIds.isNotEmpty ? messageIds[0] as int? : null;
    final action = data['action'] ?? 'pin';
    final conversationId = widget.group.conversationId;

    int? newPinnedMessageId;
    if (action == 'pin') {
      newPinnedMessageId = messageId;
    } else {
      newPinnedMessageId = null;
    }

    setState(() {
      _pinnedMessageId = newPinnedMessageId;
    });

    // Save to local storage
    await _messagesRepo.savePinnedMessage(
      conversationId: conversationId,
      pinnedMessageId: newPinnedMessageId,
    );
  }

  /// Handle incoming message star from WebSocket
  void _handleMessageStar(Map<String, dynamic> message) async {
    final data = message['data'] as Map<String, dynamic>? ?? {};
    final messagesIds = message['message_ids'] as List<int>? ?? [];
    final action = data['action'] ?? 'star';

    setState(() {
      if (action == 'star') {
        _starredMessages.addAll(messagesIds);
      } else {
        _starredMessages.removeAll(messagesIds);
      }
    });

    // Save to local storage
    try {
      for (final messageId in messagesIds) {
        if (action == 'star') {
          await _messagesRepo.starMessage(messageId);
        } else {
          await _messagesRepo.unstarMessage(messageId);
        }
      }
    } catch (e) {
      debugPrint(
        '❌ Error updating starred messages from WebSocket in group storage: $e',
      );
    }
  }

  /// Handle message delete event from WebSocket
  void _handleMessageDelete(Map<String, dynamic> message) async {
    try {
      final messageIds = message['message_ids'] as List<dynamic>? ?? [];
      if (messageIds.isEmpty) return;

      final deletedMessageIds = messageIds.map((id) => id as int).toList();

      debugPrint(
        '🗑️ Received message_delete event for messages: $deletedMessageIds',
      );

      // Remove from UI
      if (mounted) {
        setState(() {
          _messages.removeWhere((msg) => deletedMessageIds.contains(msg.id));
        });
      }

      // Remove from local storage cache
      await _messagesRepo.removeMessageFromCache(
        conversationId: widget.group.conversationId,
        messageIds: deletedMessageIds,
      );

      debugPrint('✅ Removed deleted messages from UI and cache');
    } catch (e) {
      debugPrint('❌ Error handling message delete event: $e');
    }
  }

  /// Send group message with immediate display (optimistic UI)
  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Store reply message reference
    final replyMessage = _replyToMessageData;
    final replyMessageId = _replyToMessageData?.id;

    // Clear input and reply state immediately for better UX
    _messageController.clear();
    _cancelReply();

    // Clear draft when message is sent
    final draftNotifier = ref.read(draftMessagesProvider.notifier);
    await draftNotifier.removeDraft(widget.group.conversationId);

    // Create optimistic message for immediate display with current UTC time
    final nowUTC = DateTime.now().toUtc();
    final optimisticMessage = MessageModel(
      id: _optimisticMessageId, // Use negative ID for optimistic messages
      body: messageText,
      type: 'text',
      senderId: _currentUserId ?? 0,
      conversationId: widget.group.conversationId,
      createdAt: nowUTC
          .toIso8601String(), // Store as UTC, convert to IST when displaying
      deleted: false,
      senderName: 'You', // Current user name
      senderProfilePic: null,
      replyToMessage: replyMessage,
      replyToMessageId: replyMessageId,
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);

    // Add message to UI immediately with animation
    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
        // Update sticky date separator for new messages
        _currentStickyDate = ChatHelpers.getMessageDateString(
          optimisticMessage.createdAt,
        );
        _showStickyDate = true;
      });

      _animateNewMessage(optimisticMessage.id);
      _scrollToBottom();
    }

    // Store message immediately in cache (optimistic storage)
    _storeMessageAsync(optimisticMessage);

    final prefs = await SharedPreferences.getInstance();
    final currentUserName = prefs.getString('current_user_name');
    try {
      // Check if this is a reply message
      if (replyMessageId != null) {
        debugPrint('🔄 Sending group reply message via WebSocket');
        // Send reply message via WebSocket
        await _websocketService.sendMessage({
          'type': 'message_reply',
          'data': {
            'new_message': messageText,
            'optimistic_id': _optimisticMessageId,
          },
          'conversation_id': widget.group.conversationId,
          'message_ids': [
            replyMessageId,
          ], // Array of message IDs being replied to
        });
      } else {
        // Send regular message
        final messageData = {
          'type': 'text',
          'body': messageText,
          'optimistic_id': _optimisticMessageId,
        };

        await _websocketService.sendMessage({
          'type': 'message',
          'data': messageData,
          'conversation_id': widget.group.conversationId,
          'sender_name': currentUserName,
        });
      }

      _optimisticMessageId--;
    } catch (e) {
      debugPrint('❌ Error sending group message: $e');
      _retryMessage(optimisticMessage.id);
      // Handle send failure - mark message as failed
      // _handleMessageSendFailure(optimisticMessage.id, e.toString());
    }
  }

  /// Handle message send failure
  void _handleMessageSendFailure(int messageId, String error) {
    if (!mounted) return;

    // Find and update the failed message
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      // You could add a "failed" status to MessageModel or show an error indicator
      // For now, we'll show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send group message: Please check your internet!',
          ),
          backgroundColor: Colors.teal,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _retryMessage(messageId),
          ),
        ),
      );
    }
  }

  /// Retry sending a failed message
  void _retryMessage(int messageId) {
    if (!_websocketService.isConnected) {
      _websocketService.connect();
    }

    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      final message = _messages[index];

      // Re-send the message
      _websocketService
          .sendMessage({
            'type': 'message',
            'data': {
              'type': message.type,
              'body': message.body,
              'optimistic_id': messageId,
            },
            'conversation_id': widget.group.conversationId,
          })
          .catchError((error) {
            _handleMessageSendFailure(messageId, error.toString());
          });
    }
  }

  /// Store message asynchronously without blocking UI
  void _storeMessageAsync(MessageModel message) {
    // Run storage operation in background
    Future.microtask(() async {
      try {
        if (_conversationMeta != null) {
          await _messagesRepo.addMessageToCache(
            conversationId: widget.group.conversationId,
            newMessage: message,
            updatedMeta: _conversationMeta!.copyWith(
              totalCount: _conversationMeta!.totalCount + 1,
            ),
            insertAtBeginning: false, // Add new messages at the end
          );
          debugPrint('💾 Group message stored asynchronously: ${message.id}');

          // Trigger background media caching for media messages
          if (message.type == 'image' ||
              message.type == 'video' ||
              message.type == 'audio') {
            String? mediaUrl;
            if (message.attachments != null) {
              if (message.type == 'image') {
                mediaUrl =
                    (message.attachments!['image_url'] ??
                            message.attachments!['url'])
                        as String?;
              } else if (message.type == 'video') {
                mediaUrl =
                    (message.attachments!['video_url'] ??
                            message.attachments!['url'])
                        as String?;
              } else if (message.type == 'audio') {
                mediaUrl =
                    (message.attachments!['audio_url'] ??
                            message.attachments!['url'])
                        as String?;
              }

              if (mediaUrl != null && mediaUrl.isNotEmpty) {
                _cacheMediaForMessage(mediaUrl, message.id);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error storing group message asynchronously: $e');
      }
    });
  }

  /// Cache media file for a message in background
  Future<void> _cacheMediaForMessage(String url, int messageId) async {
    try {
      // Download and cache
      final localPath = await _mediaCacheService.downloadAndCacheMedia(url);
      if (localPath != null) {
        // Update database with local path
        await _messagesRepo.updateLocalMediaPath(messageId, localPath);
        debugPrint('✅ Cached media for group message $messageId');
      }
    } catch (e) {
      debugPrint('❌ Error caching media for group message: $e');
    }
  }

  /// Get media file path (local or remote)
  Future<String> _getMediaPath(String url, String? localPath) async {
    // Check if local file exists
    if (localPath != null && io.File(localPath).existsSync()) {
      return localPath;
    }

    // Try to get from cache service
    final cachedPath = await _mediaCacheService.getCachedFilePath(url);
    if (cachedPath != null) {
      return cachedPath;
    }

    // Return remote URL as fallback
    return url;
  }

  /// Build image widget that uses cached local file if available
  Widget _buildCachedImage(String imageUrl, String? localPath, int messageId) {
    // If we have a local path and the file exists, use it
    if (localPath != null && io.File(localPath).existsSync()) {
      return Image.file(
        io.File(localPath),
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If local file fails, fall back to network
          return _buildNetworkImage(imageUrl, messageId);
        },
      );
    }

    // Otherwise load from network and cache
    return _buildNetworkImage(imageUrl, messageId);
  }

  /// Build network image widget with caching
  Widget _buildNetworkImage(String imageUrl, int messageId) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 200,
        height: 200,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 200,
        height: 200,
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 30, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              'Failed to load',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
      ),
      // Cache the image and save path to database
      imageBuilder: (context, imageProvider) {
        // Try to cache the media file
        _cacheMediaForMessage(imageUrl, messageId);
        return Image(
          image: imageProvider,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        );
      },
    );
  }

  /// Scroll to bottom of message list
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // Since we're using reverse: true, 0 is the bottom
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Create and start animation for a new message
  void _animateNewMessage(int messageId) {
    if (_animatedMessages.contains(messageId)) return; // Already animated

    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    final slideAnimation = Tween<double>(
      begin: 50.0, // Start 50 pixels below
      end: 0.0, // End at normal position
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    final fadeAnimation =
        Tween<double>(
          begin: 0.0, // Start transparent
          end: 1.0, // End fully visible
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );

    _messageAnimationControllers[messageId] = controller;
    _messageSlideAnimations[messageId] = slideAnimation;
    _messageFadeAnimations[messageId] = fadeAnimation;
    _animatedMessages.add(messageId);

    // Start the animation
    controller.forward().then((_) {
      // Clean up after animation completes
      Future.delayed(const Duration(seconds: 5), () {
        if (_messageAnimationControllers.containsKey(messageId)) {
          _messageAnimationControllers[messageId]?.dispose();
          _messageAnimationControllers.remove(messageId);
          _messageSlideAnimations.remove(messageId);
          _messageFadeAnimations.remove(messageId);
        }
      });
    });
  }

  void _handleTyping(String value) async {
    // final wasTyping = _isTyping;
    final isTyping = value.isNotEmpty;

    setState(() {
      _isTyping = isTyping;
    });

    // Only send websocket message if typing state changed
    if (isTyping) {
      await _websocketService.sendMessage({
        'type': 'typing',
        'data': {'user_id': _currentUserId, 'is_typing': isTyping},
        'conversation_id': widget.group.conversationId,
      });
    }
  }

  void _reciveTyping(Map<String, dynamic> message) {
    final isTyping = message['data']['is_typing'] as bool;
    // final senderName = message['data']['sender_name'];
    // Cancel any existing timeout
    _typingTimeout?.cancel();

    _isOtherTypingNotifier.value = isTyping;

    // Control the typing animation
    if (isTyping) {
      _typingAnimationController.repeat(reverse: true);

      // Set a safety timeout to hide typing indicator after 5 seconds
      _typingTimeout = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _isOtherTypingNotifier.value = false;
          _typingAnimationController.stop();
          _typingAnimationController.reset();
        }
      });
    } else {
      // Immediately stop typing indicator
      _typingAnimationController.stop();
      _typingAnimationController.reset();
    }
  }

  void _replyToMessage(MessageModel message) {
    setState(() {
      _replyToMessageData = message;
      _isReplying = true;
    });

    // Focus on the text field for user to type their reply
    // The actual message will be sent when user presses send button
  }

  void _copyMessage(MessageModel message) async {
    if (message.body.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: message.body));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageData = null;
      _isReplying = false;
    });
  }

  void _startAudioProgressTimer(String audioKey) {
    _audioProgressTimer?.cancel();

    // Get current position for resume functionality
    final currentPosition = _audioPositions[audioKey] ?? Duration.zero;

    // Adjust start time to account for current position (for resume)
    _audioStartTime = DateTime.now().subtract(currentPosition);
    _customPosition = currentPosition;

    _audioProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!mounted ||
          _currentPlayingAudioKey != audioKey ||
          !(_playingAudios[audioKey] ?? false)) {
        timer.cancel();
        _audioStartTime = null;
        return;
      }

      try {
        if (_audioPlayer.isPlaying && _audioStartTime != null) {
          // Calculate custom position based on elapsed time
          final elapsed = DateTime.now().difference(_audioStartTime!);
          _customPosition = elapsed;

          // Get duration from getProgress (this part works)
          final progress = await _audioPlayer.getProgress();
          final duration = progress['duration'] ?? Duration.zero;

          if (mounted && duration.inMilliseconds > 0) {
            // Don't let position exceed duration
            final clampedPosition = Duration(
              milliseconds: _customPosition.inMilliseconds.clamp(
                0,
                duration.inMilliseconds,
              ),
            );

            setState(() {
              _audioDurations[audioKey] = duration;
              _audioPositions[audioKey] = clampedPosition;
            });

            // Only log every second to reduce console spam
            if (clampedPosition.inSeconds % 1 == 0 &&
                clampedPosition.inMilliseconds % 1000 < 200) {
              print(
                '🎵 Progress: ${clampedPosition.inSeconds}s / ${duration.inSeconds}s',
              );
            }

            // Check if we've reached the end
            if (clampedPosition.inMilliseconds >=
                duration.inMilliseconds - 100) {
              print('🏁 Audio should be finishing soon...');
            }
          }
        } else {
          print('⚠️ Player not playing - stopping timer');
          timer.cancel();
        }
      } catch (e) {
        print('❌ Error in audio progress timer: $e');
        timer.cancel();
      }
    });
  }

  void _stopAudioProgressTimer() {
    _audioProgressTimer?.cancel();
    _audioProgressTimer = null;
  }

  void _openGroupInfo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoPage(group: widget.group),
      ),
    );

    // Check if the group was deleted
    if (result is Map && result['action'] == 'deleted') {
      // Group was deleted, navigate back to groups page with the same result
      if (mounted) {
        Navigator.pop(context, {'action': 'deleted'});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelectionMode
            ? Text(
                '${_selectedMessages.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.teal[100],
                    child: Text(
                      widget.group.title.isNotEmpty
                          ? widget.group.title[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        // if (_isOtherTypingNotifier.value) ...[
                        //   Text(
                        //     'Typing...',
                        //     style: TextStyle(
                        //       color: Colors.white70,
                        //       fontSize: 12,
                        //     ),
                        //   ),
                        // ],
                      ],
                    ),
                  ),
                ],
              ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: _isSelectionMode
            ? _buildSelectionModeActions()
            : [
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: _openGroupInfo,
                  tooltip: 'Group info',
                ),
              ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/chat_bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.white.withAlpha(100)),
            ),
            Column(
              children: [
                // Pinned Message Section
                if (_pinnedMessageId != null) _buildPinnedMessageSection(),

                // Messages List
                Expanded(child: _buildMessagesList()),

                // Message Input
                _buildMessageInput(),
              ],
            ),
            // Sticky Date Separator - Overlay on top
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: _buildStickyDateSeparator(),
            ),
          ],
        ),
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      // floatingActionButton: Row(
      //   mainAxisSize: MainAxisSize.min,
      //   crossAxisAlignment: CrossAxisAlignment.end,
      //   children: [
      //     _buildTestFab(20, Colors.blue),
      //     const SizedBox(height: 8),
      //     _buildTestFab(50, Colors.orange),
      //     const SizedBox(height: 8),
      //     _buildTestFab(200, Colors.red),
      //   ],
      // ),
    );
  }

  Widget _buildMessagesList() {
    // Show cache loader while checking cache (prevent black screen)
    if (_isCheckingCache && _messages.isEmpty) {
      return Center(child: LoadingDotsAnimation(color: Colors.blue[400]));
    }

    // Show appropriate loader based on state
    if (_isLoadingFromCache) {
      return Center(child: LoadingDotsAnimation(color: Colors.orange[400]));
    }

    // Only show loading if we haven't initialized and don't have messages
    if (_isLoading && !_isInitialized && _messages.isEmpty) {
      return Center(child: LoadingDotsAnimation(color: Colors.blue[400]));
    }

    if (_errorMessage != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Connection lost please refresh',
              style: TextStyle(color: Colors.black, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialMessages,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (_messages.isEmpty &&
        _isInitialized &&
        !_isLoading &&
        !_isLoadingFromCache) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_rounded, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 6),
            Text(
              "No message yet",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialMessages,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      cacheExtent: 500, // Cache more items for smoother scrolling
      addAutomaticKeepAlives: true, // Keep message widgets alive
      addRepaintBoundaries: true, // Optimize repainting
      itemBuilder: (context, index) {
        if (index == 0 && _isLoadingMore) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[300]!),
              ),
            ),
          );
        }

        // Adjust index for loading indicator
        final messageIndex = _isLoadingMore ? index - 1 : index;
        final message =
            _messages[_messages.length -
                1 -
                messageIndex]; // Show newest at bottom

        // Debug: Check user ID comparison
        final isMyMessage =
            _currentUserId != null && message.senderId == _currentUserId;

        return Column(
          children: [
            // Date separator - show the date for the group of messages that starts here
            if (ChatHelpers.shouldShowDateSeparator(_messages, messageIndex))
              DateSeparator(dateTimeString: message.createdAt),
            // Message bubble with long press
            _buildMessageWithActions(message, isMyMessage),
          ],
        );
      },
    );
  }

  Widget _buildMessageWithActions(MessageModel message, bool isMyMessage) {
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessageId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    return GestureDetector(
      onLongPress: () => _showMessageActions(message, isMyMessage),
      onTap: _isSelectionMode
          ? () => _toggleMessageSelection(message.id)
          : null,
      onPanStart: (details) => _onSwipeStart(message, details),
      onPanUpdate: (details) => _onSwipeUpdate(message, details, isMyMessage),
      onPanEnd: (details) => _onSwipeEnd(message, details, isMyMessage),
      child: Container(
        color: isSelected ? Colors.teal.withOpacity(0.1) : Colors.transparent,
        child: Stack(
          children: [
            _buildSwipeableMessageBubble(
              message,
              isMyMessage,
              isPinned,
              isStarred,
            ),
            if (_isSelectionMode)
              Positioned(
                left: isMyMessage ? 8 : null,
                right: isMyMessage ? null : 8,
                top: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.teal : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.teal : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Swipe gesture handling methods
  void _onSwipeStart(MessageModel message, DragStartDetails details) {
    // Initialize swipe animation controller if not exists
    if (!_swipeAnimationControllers.containsKey(message.id)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
      _swipeAnimationControllers[message.id] = controller;
      _swipeAnimations[message.id] = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }

    // Reset swipe tracking variables
    _swipeStartPosition = details.globalPosition;
    _swipeTotalDistance = 0.0;
    _isSwipeGesture = false;
  }

  void _onSwipeUpdate(
    MessageModel message,
    DragUpdateDetails details,
    bool isMyMessage,
  ) {
    if (_isSelectionMode || _swipeStartPosition == null || _isScrolling) return;

    // Calculate total distance moved from start position
    final currentPosition = details.globalPosition;
    final horizontalDistance = currentPosition.dx - _swipeStartPosition!.dx;
    final verticalDistance = (currentPosition.dy - _swipeStartPosition!.dy)
        .abs();

    _swipeTotalDistance = horizontalDistance.abs();

    // Determine if this is a horizontal swipe gesture
    if (!_isSwipeGesture) {
      // Check if we have enough horizontal movement and not too much vertical movement
      if (_swipeTotalDistance > _minSwipeDistance &&
          verticalDistance < _maxVerticalDeviation &&
          horizontalDistance > 0) {
        _isSwipeGesture = true;
      } else if (verticalDistance > _maxVerticalDeviation ||
          horizontalDistance < 0) {
        // Too much vertical movement or left swipe, this is likely a scroll, not a swipe
        _isScrolling = true;
        return;
      }
    }

    // Only proceed if this is confirmed as a horizontal swipe
    if (_isSwipeGesture && horizontalDistance > 0) {
      final controller = _swipeAnimationControllers[message.id];
      if (controller != null) {
        // Calculate swipe progress (0 to 1) based on total distance
        final progress = (_swipeTotalDistance / 100).clamp(0.0, 1.0);
        controller.value = progress;
      }
    }
  }

  void _onSwipeEnd(
    MessageModel message,
    DragEndDetails details,
    bool isMyMessage,
  ) {
    final controller = _swipeAnimationControllers[message.id];
    if (controller != null) {
      // Only trigger reply if this was confirmed as a horizontal swipe gesture
      if (_isSwipeGesture &&
          (details.velocity.pixelsPerSecond.dx > _minSwipeVelocity ||
              controller.value > _swipeThreshold)) {
        // Animate to complete position then trigger reply
        controller.forward().then((_) {
          _replyToMessage(message);
          // Reset animation
          controller.reverse();
        });
      } else {
        // Animate back to original position
        controller.reverse();
      }
    }

    // Reset swipe tracking variables
    _swipeStartPosition = null;
    _swipeTotalDistance = 0.0;
    _isSwipeGesture = false;
    _isScrolling = false;
  }

  Widget _buildSwipeableMessageBubble(
    MessageModel message,
    bool isMyMessage,
    bool isPinned,
    bool isStarred,
  ) {
    final swipeAnimation = _swipeAnimations[message.id];

    if (swipeAnimation != null) {
      return AnimatedBuilder(
        animation: swipeAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Reply icon background
              if (swipeAnimation.value > 0.1)
                Positioned(
                  left: isMyMessage ? 16 : null,
                  right: isMyMessage ? null : 16,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: swipeAnimation.value,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.reply,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              // Message bubble with transform
              Transform.translate(
                offset: Offset(swipeAnimation.value * 50, 0),
                child: _buildMessageBubble(
                  message,
                  isMyMessage,
                  isPinned,
                  isStarred,
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildMessageBubble(message, isMyMessage, isPinned, isStarred);
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMyMessage,
    bool isPinned,
    bool isStarred,
  ) {
    // Pre-calculate values for better performance
    final messageTime = ChatHelpers.formatMessageTime(message.createdAt);

    // Check if this message should be animated
    final shouldAnimate = _messageAnimationControllers.containsKey(message.id);
    final slideAnimation = _messageSlideAnimations[message.id];
    final fadeAnimation = _messageFadeAnimations[message.id];

    // Check if this message is currently highlighted
    final isHighlighted = _highlightedMessageId == message.id;

    Widget messageContent = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMyMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  left: isMyMessage ? 40 : 8,
                  right: isMyMessage ? 8 : 40,
                ),
                padding: isHighlighted
                    ? const EdgeInsets.all(10)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.blue.withAlpha(100)
                      : Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isMyMessage ? 24 : 0),
                    bottomRight: Radius.circular(isMyMessage ? 0 : 24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMyMessage
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Check if this is a media message (image/video)
                    _isMediaMessage(message)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMyMessage) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 8,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    message.senderName.isNotEmpty
                                        ? message.senderName
                                        : 'Unknown User',
                                    style: TextStyle(
                                      color: Colors.teal[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              // Reply message preview (if this is a reply)
                              if (message.replyToMessage != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMyMessage
                                        ? Colors.teal[600]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(0),
                                      topRight: const Radius.circular(0),
                                      bottomLeft: const Radius.circular(4),
                                      bottomRight: const Radius.circular(4),
                                    ),
                                  ),
                                  child: _buildReplyPreview(
                                    message.replyToMessage!,
                                    isMyMessage,
                                  ),
                                ),
                              // Media content without outer padding
                              _buildMessageContent(message, isMyMessage),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.only(
                              top: 5,
                              bottom: 2,
                              left: 10,
                              right: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMyMessage
                                  ? Colors.teal[600]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: Radius.circular(
                                  isMyMessage ? 14 : 0,
                                ),
                                bottomRight: Radius.circular(
                                  isMyMessage ? 0 : 14,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMyMessage) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      message.senderName.isNotEmpty
                                          ? message.senderName
                                          : 'Unknown User',
                                      style: TextStyle(
                                        color: Colors.teal[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                // Reply message preview (if this is a reply)
                                if (message.replyToMessage != null)
                                  _buildReplyPreview(
                                    message.replyToMessage!,
                                    isMyMessage,
                                  ),

                                // Message content (text, image, or video)
                                _buildMessageContent(message, isMyMessage),
                                const SizedBox(height: 1),
                                // Time and status row
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isStarred) ...[
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: isMyMessage
                                            ? Colors.amber[600]
                                            : Colors.amber[600],
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      messageTime,
                                      style: TextStyle(
                                        color: isMyMessage
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    // if (isMyMessage) ...[
                                    //   const SizedBox(width: 4),
                                    //   Icon(
                                    //     Icons.done_all,
                                    //     size: 16,
                                    //     color: Colors.white70,
                                    //   ),
                                    // ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Apply animation if available
    if (shouldAnimate && slideAnimation != null && fadeAnimation != null) {
      return AnimatedBuilder(
        animation: _messageAnimationControllers[message.id]!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: Opacity(opacity: fadeAnimation.value, child: messageContent),
          );
        },
      );
    }

    return messageContent;
  }

  Widget _buildReplyPreview(MessageModel replyMessage, bool isMyMessage) {
    final isRepliedMessageMine =
        _currentUserId != null && replyMessage.senderId == _currentUserId;

    return GestureDetector(
      onTap: () => _scrollToMessage(replyMessage.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMyMessage ? Colors.white.withAlpha(15) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMyMessage ? Colors.white : Colors.teal,
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRepliedMessageMine ? 'You' : replyMessage.senderName,
              style: TextStyle(
                color: isMyMessage ? Colors.white : Colors.teal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            if (replyMessage.body.isNotEmpty) ...[
              Text(
                replyMessage.body.length > 50
                    ? '${replyMessage.body.substring(0, 50)}...'
                    : replyMessage.body,
                style: TextStyle(
                  color: isMyMessage ? Colors.white : Colors.grey[600],
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                '📎 media',
                style: TextStyle(
                  color: isMyMessage
                      ? Colors.white.withAlpha(80)
                      : Colors.grey[600],
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMyMessage) {
    // Handle loading states first
    switch (message.type) {
      case 'image_loading':
        return _buildImageLoadingMessage(message, isMyMessage);
      case 'video_loading':
        return _buildVideoLoadingMessage(message, isMyMessage);
      case 'document_loading':
        return _buildDocumentLoadingMessage(message, isMyMessage);
      case 'audio_loading':
        return _buildAudioLoadingMessage(message, isMyMessage);
    }

    // Handle attachments based on category
    if (message.attachments != null) {
      final attachmentData = message.attachments as Map<String, dynamic>;
      final category = attachmentData['category'] as String?;

      switch (category?.toLowerCase()) {
        case 'images':
          return _buildImageMessage(message, isMyMessage);
        case 'videos':
          return _buildVideoMessage(message, isMyMessage);
        case 'docs':
          return _buildDocumentMessage(message, isMyMessage);
        case 'audios':
          return _buildAudioMessage(message, isMyMessage);
        default:
          // Fallback to type-based handling for backward compatibility
          break;
      }
    }

    // Fallback to original type-based handling
    switch (message.type) {
      case 'image':
        return _buildImageMessage(message, isMyMessage);
      case 'video':
        return _buildVideoMessage(message, isMyMessage);
      case 'docs':
        return _buildDocumentMessage(message, isMyMessage);
      case 'attachment':
        // Server sends attachments with type="attachment"
        return _buildImageMessage(message, isMyMessage);
      case 'text':
      default:
        return Text(
          message.body,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  bool _isMediaMessage(MessageModel message) {
    // if (message.attachments != null) {
    //   final attachmentData = message.attachments as Map<String, dynamic>;
    //   final category = attachmentData['category'] as String?;
    //   return category?.toLowerCase() == 'images' ||
    //       category?.toLowerCase() == 'videos' ||
    //       category?.toLowerCase() == 'docs' ||
    //       category?.toLowerCase() == 'audios';
    // }
    return message.type == 'image' ||
        message.type == 'video' ||
        message.type == 'attachment' ||
        message.type == 'docs' ||
        message.type == 'audio' ||
        message.type == 'audios' ||
        message.type == 'media' ||
        message.type == 'image_loading' ||
        message.type == 'video_loading' ||
        message.type == 'document_loading' ||
        message.type == 'audio_loading';
  }

  /// Handle media upload failure
  void _handleMediaUploadFailure(int messageId, String error) {
    if (!mounted) return;

    // Find and remove the failed loading message
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      setState(() {
        _messages.removeAt(index);
      });

      // Remove from optimistic tracking
      _optimisticMessageIds.remove(messageId);

      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.teal[200],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showMessageActions(
    MessageModel message,
    bool isMyMessage,
  ) async {
    final isPinned = _pinnedMessageId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Check if the current user is group admin or user role = staff
    bool isAdmin = false;

    // Check if user is group admin
    if (widget.group.role == 'admin') {
      isAdmin = true;
      setState(() {
        _isAdminOrStaff = true;
      });
    } else {
      // Check if user role is 'staff'
      try {
        final currentUser = await _userRepo.getFirstUser();
        if (currentUser != null && currentUser.role == 'staff') {
          isAdmin = true;
          setState(() {
            _isAdminOrStaff = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error checking user role: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageActionSheet(
        message: message,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        isAdmin: isAdmin,
        showReadBy: true,
        onReply: () => _replyToMessage(message),
        onCopy: () => _copyMessage(message),
        onPin: () => _togglePinMessage(message.id),
        onStar: () => _toggleStarMessage(message.id),
        onForward: () => _forwardMessage(message),
        onSelect: () => _enterSelectionMode(message.id),
        onReadBy: () => _showReadByModal(message),
        onDelete: isAdmin || _isAdminOrStaff
            ? () => _deleteMessage(message.id)
            : null,
      ),
    );
  }

  /// Build video thumbnail widget with caching to prevent rebuilds
  Widget _buildVideoThumbnail(String videoUrl) {
    // Check if we already have the thumbnail cached
    if (_videoThumbnailCache.containsKey(videoUrl)) {
      final thumbnailPath = _videoThumbnailCache[videoUrl];
      if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
        return Image.file(
          File(thumbnailPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: Colors.black87);
          },
        );
      } else {
        // Cached but path is null or file doesn't exist
        return Container(color: Colors.black87);
      }
    }

    // Thumbnail not yet generated - trigger generation and show loading
    // Use a post-frame callback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_videoThumbnailCache.containsKey(videoUrl) &&
          !_videoThumbnailFutures.containsKey(videoUrl)) {
        _generateVideoThumbnail(videoUrl).then((_) {
          if (mounted) {
            setState(() {}); // Rebuild to show the thumbnail
          }
        });
      }
    });

    // Show loading state
    return Container(
      color: Colors.black87,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Future<String?> _generateVideoThumbnail(String videoUrl) async {
    // Check if thumbnail is already cached
    if (_videoThumbnailCache.containsKey(videoUrl)) {
      return _videoThumbnailCache[videoUrl];
    }

    // Check if thumbnail is currently being generated
    if (_videoThumbnailFutures.containsKey(videoUrl)) {
      return await _videoThumbnailFutures[videoUrl];
    }

    // Generate new thumbnail
    final future = _performThumbnailGeneration(videoUrl);
    _videoThumbnailFutures[videoUrl] = future;

    try {
      final thumbnailPath = await future;
      _videoThumbnailCache[videoUrl] = thumbnailPath;
      _videoThumbnailFutures.remove(videoUrl);
      return thumbnailPath;
    } catch (e) {
      _videoThumbnailFutures.remove(videoUrl);
      _videoThumbnailCache[videoUrl] = null;
      return null;
    }
  }

  Future<String?> _performThumbnailGeneration(String videoUrl) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 220,
        quality: 75,
      );
      debugPrint('✅ Generated video thumbnail: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('❌ Error generating video thumbnail: $e');
      return null;
    }
  }

  Widget _buildMessageInput() {
    // Check if this is a community group and if sending is allowed
    final isCommunityGroupActive = _isCommunityGroupActive();
    final shouldDisableSending =
        widget.isCommunityGroup && !isCommunityGroupActive;

    return Column(
      children: [
        // Time restriction notice for community groups
        if (widget.isCommunityGroup && !isCommunityGroupActive)
          _buildTimeRestrictionNotice(),

        // Typing indicator
        ValueListenableBuilder<bool>(
          valueListenable: _isOtherTypingNotifier,
          builder: (context, isOtherTyping, child) {
            return isOtherTyping
                ? _buildTypingIndicator()
                : const SizedBox.shrink();
          },
        ),

        // Reply container
        if (_isReplying && _replyToMessageData != null) _buildReplyContainer(),

        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: shouldDisableSending
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                onPressed: shouldDisableSending
                    ? null
                    : () {
                        _showAttachmentModal();
                      },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !shouldDisableSending,
                  decoration: InputDecoration(
                    hintText: shouldDisableSending
                        ? 'Messaging is disabled outside active hours'
                        : 'Message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: shouldDisableSending
                        ? Colors.grey[200]
                        : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 6,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: shouldDisableSending
                      ? null
                      : (value) {
                          _handleTyping(value);
                        },
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: shouldDisableSending
                    ? null
                    : (_messageController.text.isNotEmpty
                          ? _sendMessage
                          : _sendVoiceNote),
                backgroundColor: shouldDisableSending
                    ? Colors.grey[400]
                    : Colors.teal,
                mini: true,
                child: _messageController.text.isNotEmpty
                    ? Icon(
                        Icons.send,
                        color: shouldDisableSending
                            ? Colors.grey[600]
                            : Colors.white,
                      )
                    : Icon(
                        Icons.mic,
                        color: shouldDisableSending
                            ? Colors.grey[600]
                            : Colors.white,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to check if community group is active
  bool _isCommunityGroupActive() {
    if (!widget.isCommunityGroup || widget.communityGroupMetadata == null) {
      return true; // Regular groups are always active
    }

    final metadata = widget.communityGroupMetadata!;
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);

    // Check if today is an active day
    // if (!metadata.activeDays.contains(currentDay)) {
    //   return false;
    // }

    // Check if current time is within any active time slot
    for (final timeSlot in metadata.activeTimeSlots) {
      if (_isTimeInRange(currentTime, timeSlot.startTime, timeSlot.endTime)) {
        return true;
      }
    }

    return false;
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Same day range
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  Widget _buildTimeRestrictionNotice() {
    final metadata = widget.communityGroupMetadata;
    if (metadata == null || metadata.activeTimeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeTimeSlotsText = metadata.activeTimeSlots
        .map((slot) => slot.displayTime)
        .join(', ');

    final activeDaysText = _getActiveDaysText(metadata.activeDays);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messaging restricted',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Active: $activeTimeSlotsText',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getActiveDaysText(List<int> activeDays) {
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (activeDays.length == 7) {
      return 'Every day';
    } else if (activeDays.length == 5 &&
        activeDays.contains(1) &&
        activeDays.contains(2) &&
        activeDays.contains(3) &&
        activeDays.contains(4) &&
        activeDays.contains(5)) {
      return 'Weekdays';
    } else if (activeDays.length == 2 &&
        activeDays.contains(0) &&
        activeDays.contains(6)) {
      return 'Weekends';
    } else {
      return activeDays.map((day) => dayNames[day]).join(', ');
    }
  }

  Widget _buildReplyContainer() {
    final replyMessage = _replyToMessageData!;
    final isRepliedMessageMine =
        _currentUserId != null && replyMessage.senderId == _currentUserId;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Reply indicator line
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      isRepliedMessageMine ? 'You' : replyMessage.senderName,
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (replyMessage.body.isNotEmpty) ...[
                  Text(
                    replyMessage.body.length > 50
                        ? '${replyMessage.body.substring(0, 50)}...'
                        : replyMessage.body,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    '📎 media',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Cancel reply button
          IconButton(
            onPressed: _cancelReply,
            icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.group, color: Colors.teal, size: 12),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_buildTypingAnimation()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingAnimation() {
    return SizedBox(
      width: 24,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_buildTypingDot(0), _buildTypingDot(1), _buildTypingDot(2)],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingDotAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _typingDotAnimations[index].value * -4),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  // Media handling methods from inner_chat_page.dart
  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAttachmentModal(),
    );
  }

  Widget _buildAttachmentModal() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: Colors.grey[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Attach File',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          // Attachment options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.pop(context);
                    _handleCameraAttachment();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.perm_media,
                  label: 'Media',
                  color: const Color(0xFF2196F3),
                  onTap: () {
                    Navigator.pop(context);
                    _handleGalleryAttachment();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.description,
                  label: 'Document',
                  color: const Color(0xFFFF9800),
                  onTap: () {
                    Navigator.pop(context);
                    _handleDocumentAttachment();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTapDown: (_) {
              // Add subtle haptic feedback if available
            },
            onTap: () {
              // Add a small scale animation on tap
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.15),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleCameraAttachment() async {
    // Check and request camera permission
    PermissionStatus cameraStatus = await Permission.camera.status;

    // If permission is not granted, request it
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }

    if (!cameraStatus.isGranted) {
      if (cameraStatus.isPermanentlyDenied) {
        _showPermissionDeniedDialog('Camera');
      } else {
        _showErrorDialog('Camera permission is required to take photos.');
      }
      return;
    }

    debugPrint('📸 Opening camera for group...');

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        debugPrint('📸 Group camera image captured: ${image.path}');
        final File imageFile = File(image.path);
        if (await imageFile.exists()) {
          _sendImageMessage(imageFile, 'camera');
        }
      } else {
        debugPrint('📸 Group camera capture cancelled by user');
      }
    } catch (e) {
      debugPrint('❌ Error capturing image from camera for group: $e');
      if (e.toString().contains('permission')) {
        _showErrorDialog(
          'Camera permission is required to take photos. Please grant permission in your device settings.',
        );
      } else {
        _showErrorDialog('Failed to capture image from camera');
      }
    }
  }

  void _handleGalleryAttachment() async {
    try {
      debugPrint('🖼️ Opening gallery for group...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.first;
        final File mediaFile = File(file.path!);
        final String extension = file.extension?.toLowerCase() ?? '';

        final bool isVideo = [
          'mp4',
          'mov',
          'avi',
          'mkv',
          '3gp',
          'webm',
          'flv',
          'wmv',
        ].contains(extension);

        if (isVideo) {
          debugPrint('🎥 Group gallery video selected: ${file.path}');
          _sendVideoMessage(mediaFile, 'gallery');
        } else {
          debugPrint('🖼️ Group gallery image selected: ${file.path}');
          _sendImageMessage(mediaFile, 'gallery');
        }
      } else {
        debugPrint('🖼️ Group gallery selection cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error selecting from gallery for group: $e');
      if (e.toString().contains('permission')) {
        _showErrorDialog(
          'Gallery permission is required to select media. Please grant permission in your device settings.',
        );
      } else {
        _showErrorDialog('Failed to select from gallery');
      }
    }
  }

  void _handleDocumentAttachment() async {
    debugPrint('📄 Opening document picker for group...');

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowCompression: true,
        withData: false,
        withReadStream: true,
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.first;
        final File documentFile = File(file.path!);

        debugPrint('📄 Group document selected: ${file.path}');

        // Check file size (limit to 50MB)
        if (file.size > 50 * 1024 * 1024) {
          _showErrorDialog('File too large. Maximum size is 50MB');
          return;
        }

        _sendDocumentMessage(documentFile, file.name, file.extension ?? '');
      } else {
        debugPrint('📄 Group document selection cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error selecting document for group: $e');
      if (e.toString().contains('permission')) {
        _showErrorDialog(
          'Storage permission is required to access documents. Please grant permission in your device settings.',
        );
      } else {
        _showErrorDialog('Failed to select document');
      }
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text('Permission Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$permissionType permission has been permanently denied.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const Text(
                'To use this feature, please:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text('1. Go to App Settings'),
              const Text('2. Find Permissions'),
              Text('3. Enable $permissionType permission'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _sendVoiceNote() async {
    print('📤 Sending group voice note');

    // Check microphone permission first
    PermissionStatus micStatus = await Permission.microphone.status;

    if (micStatus.isGranted) {
      // Permission already granted, show modal directly
      _showVoiceRecordingModal();
    } else {
      // Permission not granted, show permission dialog
      await _checkAndRequestMicrophonePermission();

      // Check again after permission dialog
      final newStatus = await Permission.microphone.status;
      if (newStatus.isGranted) {
        _showVoiceRecordingModal();
      }
    }
  }

  Future<void> _checkAndRequestMicrophonePermission() async {
    try {
      PermissionStatus micStatus = await Permission.microphone.status;

      if (micStatus.isGranted) {
        return; // Permission already granted
      }

      if (micStatus.isDenied) {
        // First time asking for permission
        micStatus = await Permission.microphone.request();

        if (micStatus.isGranted) {
          return; // Permission granted
        } else if (micStatus.isDenied) {
          _showMicrophonePermissionDialog();
          return;
        }
      }

      if (micStatus.isPermanentlyDenied) {
        _showMicrophonePermissionDeniedDialog();
        return;
      }

      // If we reach here, permission is not granted
      _showMicrophonePermissionDialog();
    } catch (e) {
      print('❌ Error checking microphone permission for group: $e');
      _showErrorDialog(
        'Failed to check microphone permission. Please try again.',
      );
    }
  }

  void _showMicrophonePermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.mic, color: Colors.blue[600], size: 28),
              const SizedBox(width: 12),
              const Text('Microphone Access'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This app needs microphone access to record voice notes.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text('Please grant microphone permission to continue.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final status = await Permission.microphone.request();
                if (status.isGranted) {
                  _startRecording();
                } else if (status.isPermanentlyDenied) {
                  _showMicrophonePermissionDeniedDialog();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  void _showMicrophonePermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text('Permission Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Microphone permission has been permanently denied.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text('To record voice notes, please:'),
              SizedBox(height: 8),
              Text('1. Go to App Settings'),
              Text('2. Find Permissions'),
              Text('3. Enable Microphone permission'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showVoiceRecordingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              child: _VoiceRecordingModal(
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onCancelRecording: _cancelRecording,
                onSendRecording: _sendRecordedVoice,
                isRecording: _isRecording,
                recordingDuration: _recordingDuration,
                zigzagAnimation: _zigzagAnimation,
                voiceModalAnimation: _voiceModalAnimation,
                timerStream: _timerStreamController.stream,
              ),
            ),
          );
        },
      ),
    );
  }

  // Add all missing media rendering methods
  Widget _buildImageMessage(MessageModel message, bool isMyMessage) {
    if (message.attachments == null) {
      return Text(
        'Image not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final imageData = message.attachments as Map<String, dynamic>;
    final imageUrl = imageData['url'] as String?;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Text(
        'Image not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return ClipRRect(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMyMessage
                ? const Color(0xFF008080)
                : const Color(0xFF008080),
            width: 4,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
            bottomRight: Radius.circular(isMyMessage ? 0 : 14),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft: Radius.circular(isMyMessage ? 10 : 0),
                    bottomRight: Radius.circular(isMyMessage ? 0 : 10),
                  ),
                  child: GestureDetector(
                    onTap: () => _openImagePreview(imageUrl, message.body),
                    child: Hero(
                      tag: imageUrl,
                      child: _buildCachedImage(
                        imageUrl,
                        message.localMediaPath,
                        message.id,
                      ),
                    ),
                  ),
                ),
                if (message.body.isNotEmpty)
                  Container(
                    width: 200,
                    padding: const EdgeInsets.only(
                      bottom: 20.0,
                      left: 8.0,
                      right: 8.0,
                      top: 4.0,
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
            // Timestamp overlay positioned at bottom right
            Positioned(
              bottom: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ChatHelpers.formatMessageTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // if (isMyMessage) ...[
                    //   const SizedBox(width: 4),
                    //   _buildMessageStatusTicks(message),
                    // ],
                  ],
                ),
              ),
            ),
            if (_starredMessages.contains(message.id))
              Positioned(
                bottom: 4,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // const SizedBox(width: 4),
                      Icon(Icons.star, size: 14, color: Colors.yellow),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMessage(MessageModel message, bool isMyMessage) {
    if (message.attachments == null) {
      return Text(
        'Video not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final videoData = message.attachments as Map<String, dynamic>;
    final videoUrl = videoData['url'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      return Text(
        'Video not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return ClipRRect(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMyMessage
                ? const Color(0xFF008080)
                : const Color(0xFF008080),
            width: 4,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
            bottomRight: Radius.circular(isMyMessage ? 0 : 14),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _openVideoPreview(
                    videoUrl,
                    message.body,
                    videoData['file_name'] as String?,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(10),
                      topRight: const Radius.circular(10),
                      bottomLeft: Radius.circular(isMyMessage ? 10 : 0),
                      bottomRight: Radius.circular(isMyMessage ? 0 : 10),
                    ),
                    child: Container(
                      width: 220,
                      height: 220,
                      color: Colors.black87,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Video thumbnail - use cached version
                          _buildVideoThumbnail(videoUrl),
                          // Play button overlay
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.play_circle_filled,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (message.body.isNotEmpty)
                  Container(
                    width: 200,
                    padding: const EdgeInsets.only(
                      bottom: 20.0,
                      left: 8.0,
                      right: 8.0,
                      top: 4.0,
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
            // Timestamp overlay positioned at bottom right
            Positioned(
              bottom: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(60),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ChatHelpers.formatMessageTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // if (isMyMessage) ...[
                    //   const SizedBox(width: 4),
                    //   _buildMessageStatusTicks(message),
                    // ],
                  ],
                ),
              ),
            ),
            if (_starredMessages.contains(message.id))
              Positioned(
                bottom: 4,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // const SizedBox(width: 4),
                      Icon(Icons.star, size: 14, color: Colors.yellow),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentMessage(MessageModel message, bool isMyMessage) {
    if (message.attachments == null) {
      return Text(
        'Document not available',
        style: TextStyle(
          color: isMyMessage ? Colors.teal : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final documentData = message.attachments as Map<String, dynamic>;
    final documentUrl = documentData['url'] as String?;
    final fileName = documentData['file_name'] as String?;
    final fileSize = documentData['file_size'] as int?;
    final mimeType = documentData['mime_type'] as String?;

    if (documentUrl == null || documentUrl.isEmpty) {
      return Text(
        'Document not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    IconData docIcon = Icons.description;
    if (mimeType != null) {
      if (mimeType.contains('pdf')) {
        docIcon = Icons.picture_as_pdf;
      } else if (mimeType.contains('word') || mimeType.contains('doc')) {
        docIcon = Icons.description;
      } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
        docIcon = Icons.table_chart;
      } else if (mimeType.contains('powerpoint') ||
          mimeType.contains('presentation')) {
        docIcon = Icons.slideshow;
      } else if (mimeType.contains('zip') || mimeType.contains('rar')) {
        docIcon = Icons.archive;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openDocumentPreview(
            documentUrl,
            fileName,
            message.body,
            fileSize,
          ),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMyMessage ? Colors.teal : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
                bottomRight: Radius.circular(isMyMessage ? 0 : 14),
              ),
              border: Border.all(
                color: isMyMessage ? Colors.teal : Colors.grey[300]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMyMessage
                        ? Colors.teal.withAlpha(25)
                        : Colors.teal.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    docIcon,
                    size: 24,
                    color: isMyMessage ? Colors.white : Colors.teal[700],
                  ),
                ),
                if (_starredMessages.contains(message.id))
                  Positioned(
                    bottom: 4,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(60),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // const SizedBox(width: 4),
                          Icon(Icons.star, size: 14, color: Colors.yellow),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (fileName != null && fileName.isNotEmpty)
                            ? fileName
                            : 'Document',
                        style: TextStyle(
                          color: isMyMessage ? Colors.white : Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (fileSize != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          ChatHelpers.formatFileSize(fileSize),
                          style: TextStyle(
                            color: isMyMessage
                                ? Colors.white
                                : Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.visibility,
                  size: 22,
                  color: isMyMessage ? Colors.white : Colors.teal[600],
                ),
              ],
            ),
          ),
        ),
        if (message.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.body,
            style: TextStyle(
              color: isMyMessage ? Colors.white : Colors.black87,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioMessage(MessageModel message, bool isMyMessage) {
    if (message.attachments == null) {
      return Text(
        'Audio not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final audioData = message.attachments as Map<String, dynamic>;
    final audioUrl = audioData['url'] as String?;
    final fileSize = audioData['file_size'] as int?;

    if (audioUrl == null || audioUrl.isEmpty) {
      return Text(
        'Audio not available',
        style: TextStyle(
          color: isMyMessage ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final audioKey = '${message.id}_$audioUrl';
    final isPlaying = _playingAudios[audioKey] ?? false;
    final duration = _audioDurations[audioKey] ?? Duration.zero;
    final position = _audioPositions[audioKey] ?? Duration.zero;

    // Get animation for this audio
    _getAudioAnimationController(audioKey); // Ensure controller exists
    final animation = _audioAnimations[audioKey]!;

    // If we don't have duration yet, schedule it to be estimated after build
    if (duration == Duration.zero && !isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _estimateAudioDuration(audioKey, fileSize);
      });
    }

    // Calculate progress for the progress bar
    double progressValue = 0.0;
    if (duration.inMilliseconds > 0) {
      progressValue = position.inMilliseconds / duration.inMilliseconds;
      progressValue = progressValue.clamp(0.0, 1.0);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMyMessage ? Colors.teal : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
                  bottomRight: Radius.circular(isMyMessage ? 0 : 14),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleAudioPlayback(audioKey, audioUrl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? (isMyMessage
                                  ? Colors.white.withAlpha(40)
                                  : Colors.blue.withAlpha(30))
                            : (isMyMessage
                                  ? Colors.white.withAlpha(20)
                                  : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: isPlaying
                            ? [
                                BoxShadow(
                                  color:
                                      (isMyMessage ? Colors.white : Colors.blue)
                                          .withAlpha(30),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Transform.scale(
                        scale: isPlaying ? animation.value : 1.0,
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 20,
                          color: isPlaying
                              ? (isMyMessage ? Colors.white : Colors.blue[700])
                              : (isMyMessage ? Colors.white : Colors.grey[700]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isPlaying)
                              _buildAnimatedWaveform(isMyMessage, animation)
                            else
                              Icon(
                                Icons.audiotrack,
                                size: 16,
                                color: isMyMessage
                                    ? Colors.white70
                                    : Colors.grey[600],
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: isMyMessage
                                      ? Colors.white30
                                      : Colors.grey[300],
                                ),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMyMessage ? Colors.white : Colors.blue,
                                  ),
                                  minHeight: 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            if (_starredMessages.contains(message.id))
                              Icon(Icons.star, size: 14, color: Colors.yellow),
                            Text(
                              _formatDuration(isPlaying ? position : duration),
                              style: TextStyle(
                                color: isMyMessage
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              ChatHelpers.formatMessageTime(message.createdAt),
                              style: TextStyle(
                                color: isMyMessage
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),

                            // Show delivery/read status ticks for own messages
                            // if (isMyMessage) ...[
                            //   const SizedBox(width: 4),
                            //   _buildMessageStatusTicks(message),
                            // ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (message.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.body,
                style: TextStyle(
                  color: isMyMessage ? Colors.white : Colors.black87,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAnimatedWaveform(bool isMyMessage, Animation<double> animation) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final delay = index * 0.2;
            final animValue = (animation.value + delay) % 1.0;
            final height = 4 + (animValue * 8);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2,
              height: height,
              decoration: BoxDecoration(
                color: isMyMessage ? Colors.white70 : Colors.blue[600],
                borderRadius: BorderRadius.circular(1),
              ),
            );
          },
        );
      }),
    );
  }

  // Media preview methods
  void _openImagePreview(String imageUrl, String? caption) async {
    try {
      // Find the message to get localMediaPath
      final message = _messages.firstWhere(
        (msg) =>
            msg.attachments != null &&
            (msg.attachments as Map<String, dynamic>)['url'] == imageUrl,
        orElse: () => _messages.first,
      );

      debugPrint('🖼️ Opening image preview for message ${message.id}');
      debugPrint('🖼️ Image URL: $imageUrl');
      debugPrint('🖼️ Local path from message: ${message.localMediaPath}');

      // Get local path or download if needed
      String? localPath = message.localMediaPath;

      // Check if local file exists
      if (localPath != null && io.File(localPath).existsSync()) {
        debugPrint('✅ Local image file exists: $localPath');
      } else {
        debugPrint('⏬ Local file not found, checking cache...');

        // Try to get from cache first
        localPath = await _mediaCacheService.getCachedFilePath(imageUrl);

        if (localPath == null) {
          debugPrint('📥 Image not in cache, will download in background');
          // Start caching in background (don't wait for it)
          _cacheMediaForMessage(imageUrl, message.id);
        } else {
          debugPrint('✅ Image found in cache: $localPath');
          // Update database with local path if not already set
          if (message.localMediaPath == null) {
            await _messagesRepo.updateLocalMediaPath(message.id, localPath);
          }
        }
      }

      if (!mounted) return;

      debugPrint('🖼️ Opening image viewer with localPath: $localPath');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImagePreviewScreen(
            imageUrls: [imageUrl],
            initialIndex: 0,
            captions: caption != null && caption.isNotEmpty ? [caption] : null,
            localPaths: localPath != null ? [localPath] : null,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening image preview: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openVideoPreview(
    String videoUrl,
    String? caption,
    String? fileName,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      // Find the message to get localMediaPath and cache if needed
      final message = _messages.firstWhere(
        (msg) =>
            msg.attachments != null &&
            (msg.attachments as Map<String, dynamic>)['url'] == videoUrl,
        orElse: () => _messages.first,
      );

      debugPrint('🎬 Opening video preview for message ${message.id}');
      debugPrint('🎬 Video URL: $videoUrl');
      debugPrint('🎬 Local path from message: ${message.localMediaPath}');

      // Get local path or download if needed
      String? localPath = message.localMediaPath;

      // Check if local file exists
      if (localPath != null && io.File(localPath).existsSync()) {
        debugPrint('✅ Local video file exists: $localPath');
      } else {
        debugPrint('⏬ Local file not found, checking cache or downloading...');

        // Try to get from cache first
        localPath = await _mediaCacheService.getCachedFilePath(videoUrl);

        if (localPath == null) {
          debugPrint('📥 Downloading video to cache...');
          // Download and wait for completion
          localPath = await _mediaCacheService.downloadAndCacheMedia(videoUrl);

          if (localPath != null) {
            debugPrint('✅ Video downloaded successfully: $localPath');
            // Update database with local path
            await _messagesRepo.updateLocalMediaPath(message.id, localPath);

            // Update the message in memory
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1 && mounted) {
              setState(() {
                _messages[index] = message.copyWith(localMediaPath: localPath);
              });
            }
          } else {
            debugPrint('⚠️ Video download failed, will use network URL');
          }
        } else {
          debugPrint('✅ Video found in cache: $localPath');
        }
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      debugPrint('🎬 Opening video player with localPath: $localPath');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPreviewScreen(
            videoUrl: videoUrl,
            caption: caption,
            fileName: fileName,
            localPath: localPath,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening video preview: $e');

      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openDocumentPreview(
    String documentUrl,
    String? fileName,
    String? caption,
    int? fileSize,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentPreviewScreen(
          documentUrl: documentUrl,
          fileName: fileName,
          caption: caption,
          fileSize: fileSize,
        ),
      ),
    );
  }

  // Audio helper methods
  void _estimateAudioDuration(String audioKey, int? fileSize) {
    // Skip if we already have duration
    if (_audioDurations[audioKey] != null &&
        _audioDurations[audioKey]!.inMilliseconds > 0) {
      return;
    }

    if (fileSize != null && fileSize > 0) {
      // Rough estimation: M4A files are typically 1MB per minute at 128kbps
      final estimatedSeconds = (fileSize / (128 * 1024 / 8))
          .round(); // bytes per second at 128kbps
      final estimatedDuration = Duration(
        seconds: estimatedSeconds.clamp(1, 3600),
      ); // min 1s, max 1 hour

      setState(() {
        _audioDurations[audioKey] = estimatedDuration;
      });

      print(
        '📏 Estimated duration for $audioKey: ${estimatedDuration.inSeconds}s (${fileSize} bytes)',
      );
    }
  }

  AnimationController _getAudioAnimationController(String audioKey) {
    if (!_audioAnimationControllers.containsKey(audioKey)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 0.5,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      _audioAnimationControllers[audioKey] = controller;
      _audioAnimations[audioKey] = animation;
    }
    return _audioAnimationControllers[audioKey]!;
  }

  Future<void> _toggleAudioPlayback(String audioKey, String audioUrl) async {
    try {
      // Ensure audio player is initialized
      if (_audioPlayer.isStopped) {
        print('🔧 Audio player not initialized, initializing now...');
        await _initializeAudioPlayer();
      }

      final isCurrentlyPlaying = _playingAudios[audioKey] ?? false;

      if (isCurrentlyPlaying) {
        // Stop playback
        await _audioPlayer.stopPlayer();

        // Stop animation
        final controller = _audioAnimationControllers[audioKey];
        controller?.stop();

        // Stop progress timer and save current position
        _stopAudioProgressTimer();

        setState(() {
          _playingAudios[audioKey] = false;
          _currentPlayingAudioKey = null;
          // Keep the current position when paused
        });
        print('🔇 Stopped audio playback for: $audioKey');
      } else {
        // Stop any currently playing audio
        _stopAudioProgressTimer();
        for (final key in _playingAudios.keys) {
          _playingAudios[key] = false;
        }

        // Only reset position if this is a fresh start (not resume)
        final currentPosition = _audioPositions[audioKey] ?? Duration.zero;
        final currentDuration = _audioDurations[audioKey] ?? Duration.zero;

        // If we're at the end, start from beginning; otherwise resume from current position
        if (currentPosition.inMilliseconds >=
            currentDuration.inMilliseconds - 100) {
          setState(() {
            _audioPositions[audioKey] = Duration.zero;
          });
        }
        // If resuming, we'll adjust the start time to account for current position

        setState(() {
          _playingAudios[audioKey] = true;
          _currentPlayingAudioKey = audioKey;
        });

        // Start animation
        final controller = _getAudioAnimationController(audioKey);
        controller.repeat(reverse: true);

        // Get local cached path or use remote URL
        // Extract message ID from audioKey (format: messageId_url)
        final messageId = int.tryParse(audioKey.split('_').first);
        String playbackUrl = audioUrl;

        if (messageId != null) {
          final message = _messages.firstWhere(
            (msg) => msg.id == messageId,
            orElse: () => _messages.first,
          );

          // Try to use local cached file
          playbackUrl = await _getMediaPath(audioUrl, message.localMediaPath);

          // If using remote URL and not cached yet, cache it in background
          if (playbackUrl == audioUrl && message.localMediaPath == null) {
            _cacheMediaForMessage(audioUrl, messageId);
          }
        }

        // Start new playback
        print('🎬 Starting audio player with: $playbackUrl');
        await _audioPlayer.startPlayer(
          fromURI: playbackUrl,
          whenFinished: () {
            if (mounted) {
              print('🏁 Audio finished callback triggered');
              // Stop animation
              final controller = _audioAnimationControllers[audioKey];
              controller?.stop();

              // Stop progress timer
              _stopAudioProgressTimer();

              setState(() {
                _playingAudios[audioKey] = false;
                // Keep position at duration when finished so we show total duration
                final duration = _audioDurations[audioKey] ?? Duration.zero;
                _audioPositions[audioKey] = duration;
                _currentPlayingAudioKey = null;
              });
              print('🔇 Audio playback finished for: $audioKey');
            }
          },
        );

        // Verify player is actually playing
        await Future.delayed(const Duration(milliseconds: 100));
        print(
          '🎵 Player state after start: isPlaying=${_audioPlayer.isPlaying}, isStopped=${_audioPlayer.isStopped}',
        );

        // Start progress timer as fallback
        _startAudioProgressTimer(audioKey);

        print('🔊 Started audio playback for: $audioKey');
      }
    } catch (e) {
      print('❌ Error toggling audio playback: $e');
      if (e.toString().contains('has not been initialized')) {
        print('❌ Audio player not initialized, trying to initialize...');
        try {
          await _audioPlayer.openPlayer();
          print('✅ Audio player initialized successfully, try playing again');
          _showErrorDialog(
            'Audio player initialized. Please try playing the audio again.',
          );
        } catch (initError) {
          print('❌ Failed to initialize audio player: $initError');
          _showErrorDialog('Failed to initialize audio player: $initError');
        }
      } else {
        _showErrorDialog('Failed to play audio. Please try again.');
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  // Media sending methods
  void _sendImageMessage(File imageFile, String source) async {
    // Store reply message reference
    final replyMessage = _replyToMessageData;
    final replyMessageId = _replyToMessageData?.id;

    // Clear reply state immediately for better UX
    if (_isReplying) {
      _cancelReply();
    }

    // Create loading message for immediate display
    final loadingMessage = MessageModel(
      id: _optimisticMessageId, // Use negative ID for optimistic message
      conversationId: widget.group.conversationId,
      senderId: _currentUserId ?? 0,
      senderName: 'You', // Current user name
      body: '', // Empty body for image message
      type: 'image_loading', // Special type for loading state
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {
        'local_path': imageFile.path,
      }, // Store local path for preview
      replyToMessageId: replyMessageId,
      replyToMessage: replyMessage,
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);

    // Add loading message to UI immediately
    if (mounted) {
      setState(() {
        _messages.add(loadingMessage);
      });
      _animateNewMessage(loadingMessage.id);
      _scrollToBottom();
    }

    try {
      final response = await _chatsServices.sendMediaMessage(imageFile);

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];

        // Update the loading message with actual data
        final imageMessage = MessageModel(
          id: loadingMessage.id, // Keep same ID
          conversationId: widget.group.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You', // Current user name
          body: '', // Empty body for image message
          type: 'image', // Change to actual image type
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData, // Store the media data as attachment
          replyToMessageId: replyMessageId,
          replyToMessage: replyMessage,
        );

        // Update message in local list
        if (mounted) {
          final index = _messages.indexWhere(
            (msg) => msg.id == loadingMessage.id,
          );
          if (index != -1) {
            setState(() {
              _messages[index] = imageMessage;
            });
          }
        }

        // Store in local storage
        final updatedMeta =
            _conversationMeta?.copyWith() ??
            ConversationMeta(
              totalCount: _messages.length,
              currentPage: 1,
              totalPages: 1,
              hasNextPage: false,
              hasPreviousPage: false,
            );

        await _messagesRepo.addMessageToCache(
          conversationId: widget.group.conversationId,
          newMessage: imageMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false, // Add at end (newest)
        );

        debugPrint('💾 Group image message stored locally and displayed');

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.group.conversationId,
            'optimistic_id': loadingMessage.id,
            'reply_to_message_id': replyMessageId,
          },
          'conversation_id': widget.group.conversationId,
        });

        debugPrint(
          '📡 Group image message sent to websocket for real-time delivery',
        );
      } else {
        // Handle upload failure - replace loading message with error
        _handleMediaUploadFailure(
          loadingMessage.id,
          'Failed to upload image: ${response['message'] ?? 'Upload failed'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending group image message: $e');
      _handleMediaUploadFailure(
        loadingMessage.id,
        'Failed to send image. Please try again.',
      );
    }

    _optimisticMessageId--;
  }

  void _sendVideoMessage(File videoFile, String source) async {
    debugPrint('📤 Sending group video message from $source');

    // Store reply message reference
    final replyMessage = _replyToMessageData;
    final replyMessageId = _replyToMessageData?.id;

    // Clear reply state immediately for better UX
    if (_isReplying) {
      _cancelReply();
    }

    // Create loading message for immediate display
    final loadingMessage = MessageModel(
      id: _optimisticMessageId, // Use negative ID for optimistic message
      conversationId: widget.group.conversationId,
      senderId: _currentUserId ?? 0,
      senderName: 'You', // Current user name
      body: '', // Empty body for video message
      type: 'video_loading', // Special type for loading state
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {
        'local_path': videoFile.path,
      }, // Store local path for preview
      replyToMessageId: replyMessageId,
      replyToMessage: replyMessage,
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);

    // Add loading message to UI immediately
    if (mounted) {
      setState(() {
        _messages.add(loadingMessage);
      });
      _animateNewMessage(loadingMessage.id);
      _scrollToBottom();
    }

    try {
      final response = await _chatsServices.sendMediaMessage(videoFile);

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];
        debugPrint('✅ Group video uploaded successfully: ${mediaData['url']}');

        // Update the loading message with actual data
        final videoMessage = MessageModel(
          id: loadingMessage.id, // Keep same ID
          conversationId: widget.group.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You', // Current user name
          body: '', // Empty body for video message
          type: 'video', // Change to actual video type
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData, // Store the media data as attachment
          replyToMessageId: replyMessageId,
          replyToMessage: replyMessage,
        );

        // Update message in local list
        if (mounted) {
          final index = _messages.indexWhere(
            (msg) => msg.id == loadingMessage.id,
          );
          if (index != -1) {
            setState(() {
              _messages[index] = videoMessage;
            });
          }
        }

        // Store in local storage
        final updatedMeta =
            _conversationMeta?.copyWith() ??
            ConversationMeta(
              totalCount: _messages.length,
              currentPage: 1,
              totalPages: 1,
              hasNextPage: false,
              hasPreviousPage: false,
            );

        await _messagesRepo.addMessageToCache(
          conversationId: widget.group.conversationId,
          newMessage: videoMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false, // Add at end (newest)
        );

        debugPrint('💾 Group video message stored locally and displayed');

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.group.conversationId,
            'message_type': 'video',
            'optimistic_id': loadingMessage.id,
            'reply_to_message_id': replyMessageId,
          },
          'conversation_id': widget.group.conversationId,
        });

        debugPrint(
          '📡 Group video message sent to websocket for real-time delivery',
        );
      } else {
        // Handle upload failure - replace loading message with error
        _handleMediaUploadFailure(
          loadingMessage.id,
          'Failed to upload video: ${response['message'] ?? 'Upload failed'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending group video message: $e');
      _handleMediaUploadFailure(
        loadingMessage.id,
        'Failed to send video. Please try again.',
      );
    }

    _optimisticMessageId--;
  }

  void _sendDocumentMessage(
    File documentFile,
    String fileName,
    String extension,
  ) async {
    // Store reply message reference
    final replyMessage = _replyToMessageData;
    final replyMessageId = _replyToMessageData?.id;

    // Clear reply state immediately for better UX
    if (_isReplying) {
      _cancelReply();
    }

    // Create loading message for immediate display
    final loadingMessage = MessageModel(
      id: _optimisticMessageId, // Use negative ID for optimistic message
      conversationId: widget.group.conversationId,
      senderId: _currentUserId ?? 0,
      senderName: 'You', // Current user name
      body: '', // Empty body for document message
      type: 'document_loading', // Special type for loading state
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {
        'local_path': documentFile.path,
        'file_name': fileName,
        'file_extension': extension,
      }, // Store local info for preview
      replyToMessageId: replyMessageId,
      replyToMessage: replyMessage,
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);

    // Add loading message to UI immediately
    if (mounted) {
      setState(() {
        _messages.add(loadingMessage);
      });
      _animateNewMessage(loadingMessage.id);
      _scrollToBottom();
    }

    try {
      final response = await _chatsServices.sendMediaMessage(documentFile);

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];
        debugPrint(
          '✅ Group document uploaded successfully: ${mediaData['url']}',
        );

        // Update the loading message with actual data
        final documentMessage = MessageModel(
          id: loadingMessage.id, // Keep same ID
          conversationId: widget.group.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You', // Current user name
          body: '', // Empty body for document message
          type: 'document', // Change to actual document type
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData, // Store the media data as attachment
          replyToMessageId: replyMessageId,
          replyToMessage: replyMessage,
        );

        // Update message in local list
        if (mounted) {
          final index = _messages.indexWhere(
            (msg) => msg.id == loadingMessage.id,
          );
          if (index != -1) {
            setState(() {
              _messages[index] = documentMessage;
            });
          }
        }

        // Store in local storage
        final updatedMeta =
            _conversationMeta?.copyWith() ??
            ConversationMeta(
              totalCount: _messages.length,
              currentPage: 1,
              totalPages: 1,
              hasNextPage: false,
              hasPreviousPage: false,
            );

        await _messagesRepo.addMessageToCache(
          conversationId: widget.group.conversationId,
          newMessage: documentMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false, // Add at end (newest)
        );

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.group.conversationId,
            'message_type': 'document',
            'optimistic_id': loadingMessage.id,
            'reply_to_message_id': replyMessageId,
          },
          'conversation_id': widget.group.conversationId,
        });

        // Scroll to bottom to show new message
        _scrollToBottom();

        debugPrint('💾 Group document message stored locally and displayed');
        debugPrint(
          '📡 Group document message sent to websocket for real-time delivery',
        );
      } else {
        // Handle upload failure - replace loading message with error
        _handleMediaUploadFailure(
          loadingMessage.id,
          'Failed to upload document: ${response['message'] ?? 'Upload failed'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending group document message: $e');
      _handleMediaUploadFailure(
        loadingMessage.id,
        'Failed to send document. Please try again.',
      );
    }

    _optimisticMessageId--;
  }

  // Voice recording methods
  Future<void> _startRecording() async {
    try {
      // Check microphone permission first
      await _checkAndRequestMicrophonePermission();

      // Double check permission status
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        return; // Permission dialog already handled in _checkAndRequestMicrophonePermission
      }

      // Initialize recorder if not already done
      if (_recorder.isStopped) {
        await _recorder.openRecorder();
      }

      // Get temporary directory for recording
      final Directory tempDir = await getTemporaryDirectory();
      final String recordingPath =
          '${tempDir.path}/group_voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      print('📁 Group recording path: $recordingPath');

      // Start recording with AAC MP4 format (most widely supported)
      print('🎙️ Starting group recorder...');
      await _recorder.startRecorder(
        toFile: recordingPath,
        codec: Codec.aacMP4,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1, // Mono recording for smaller file size
      );

      print('✅ Group recorder started successfully');

      setState(() {
        _isRecording = true;
        _recordingPath = recordingPath;
        _recordingDuration = Duration.zero;
      });

      // Initialize timer stream
      _timerStreamController.add(_recordingDuration);

      // Start animation
      _voiceModalAnimationController.forward();
      _zigzagAnimationController.repeat();

      // Start timer for recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _recordingDuration = Duration(seconds: timer.tick);
          setState(() {});
          // Emit timer update to stream for modal
          _timerStreamController.add(_recordingDuration);

          debugPrint(
            '⏱️ Group recording duration: ${_recordingDuration.inSeconds}s',
          );
        }
      });

      debugPrint('🎤 Started recording group voice note at: $recordingPath');
    } catch (e) {
      debugPrint('❌ Error starting group voice recording: $e');
      _showErrorDialog('Failed to start recording. Please try again.');
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) {
        print('⚠️ Not currently recording group voice, cannot stop');
        return;
      }

      // Check minimum recording duration (at least 1 second)
      if (_recordingDuration.inSeconds < 1) {
        print(
          '⚠️ Group recording too short (${_recordingDuration.inSeconds}s)',
        );
        _showErrorDialog(
          'Recording is too short. Please record for at least 1 second.',
        );
        return;
      }

      print(
        '🛑 Stopping group recording after ${_recordingDuration.inSeconds} seconds...',
      );

      // Add a small delay to ensure audio is captured
      await Future.delayed(const Duration(milliseconds: 100));

      final recordingPath = await _recorder.stopRecorder();
      _recordingTimer?.cancel();
      _zigzagAnimationController.stop();

      print('✅ Group recording stopped successfully');
      print('📁 Final group recording path: $recordingPath');

      // Wait a moment for file to be written completely
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify the file was created and has content
      if (recordingPath != null) {
        final file = File(recordingPath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        print('📄 Group recording file exists: $exists');
        print('📏 Group recording file size: $size bytes');

        // For M4A files, minimum size should be much larger than 44 bytes
        if (!exists || size < 1000) {
          print('❌ Group recording file is empty or too small (${size} bytes)');
          _showErrorDialog(
            'Recording failed - no audio was captured. Please check microphone permissions and try again.',
          );
          return;
        }
      } else {
        print('❌ Group recording path is null');
        _showErrorDialog(
          'Recording failed - no file path returned. Please try again.',
        );
        return;
      }

      setState(() {
        _isRecording = false;
        _recordingPath = recordingPath;
      });

      debugPrint('🎤 Stopped recording group voice note. Path: $recordingPath');
    } catch (e) {
      debugPrint('❌ Error stopping group voice recording: $e');
      _showErrorDialog('Failed to stop recording. Please try again. Error: $e');
    }
  }

  void _cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
        _zigzagAnimationController.stop();
      }

      // Cancel and reset timer
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _voiceModalAnimationController.reverse();

      // Delete the recording file if it exists
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Reset all recording state including timer
      _recordingDuration = Duration.zero; // Reset timer to 0:00
      _timerStreamController.add(_recordingDuration); // Emit reset to stream

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
        });
      }

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('❌ Error cancelling group voice recording: $e');
    }
  }

  Future<void> _sendRecordedVoice() async {
    try {
      // Stop the recording timer immediately
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (_recordingPath == null) {
        _showErrorDialog('No recording found. Please try again.');
        return;
      }

      if (_recorder.isRecording) {
        final path = await _recorder.stopRecorder();
        _recordingPath = path; // overwrite with final file
        setState(() {
          _isRecording = false;
        });
      }

      setState(() {
        _recordingPath = _recordingPath;
      });

      final voiceFile = File(_recordingPath!);
      if (!await voiceFile.exists()) {
        _showErrorDialog('Recording file not found. Please try again.');
        return;
      }

      final fileSize = await voiceFile.length();
      if (fileSize == 0) {
        _showErrorDialog('Recording is empty. Please try recording again.');
        return;
      }

      // Store reply message reference before closing modal
      final replyMessage = _replyToMessageData;
      final replyMessageId = _replyToMessageData?.id;

      // Clear reply state immediately for better UX
      if (_isReplying) {
        _cancelReply();
      }

      Navigator.of(context).pop();

      // Create loading message for immediate display
      final loadingMessage = MessageModel(
        id: _optimisticMessageId, // Use negative ID for optimistic message
        conversationId: widget.group.conversationId,
        senderId: _currentUserId ?? 0,
        senderName: 'You',
        body: '',
        type: 'audio_loading', // Special type for loading state
        createdAt: DateTime.now().toIso8601String(),
        deleted: false,
        attachments: {
          'local_path': voiceFile.path,
          'duration': _recordingDuration.inSeconds,
        }, // Store local info for preview
        replyToMessageId: replyMessageId,
        replyToMessage: replyMessage,
      );

      // Track this as an optimistic message
      _optimisticMessageIds.add(_optimisticMessageId);

      // Add loading message to UI immediately
      if (mounted) {
        setState(() {
          _messages.add(loadingMessage);
        });
        _animateNewMessage(loadingMessage.id);
        _scrollToBottom();
      }

      try {
        final response = await _chatsServices.sendMediaMessage(voiceFile);

        if (response['success'] == true && response['data'] != null) {
          final mediaData = response['data'];

          // Update the loading message with actual data
          final voiceMessage = MessageModel(
            id: loadingMessage.id, // Keep same ID
            conversationId: widget.group.conversationId,
            senderId: _currentUserId ?? 0,
            senderName: 'You',
            body: '',
            type: 'audios', // Use 'audios' to match the UI rendering logic
            createdAt: DateTime.now().toIso8601String(),
            deleted: false,
            attachments: mediaData,
            replyToMessageId: replyMessageId,
            replyToMessage: replyMessage,
          );

          // Update message in local list
          if (mounted) {
            final index = _messages.indexWhere(
              (msg) => msg.id == loadingMessage.id,
            );
            if (index != -1) {
              setState(() {
                _messages[index] = voiceMessage;
              });
            }
          }

          // Store in local storage
          final updatedMeta =
              _conversationMeta?.copyWith() ??
              ConversationMeta(
                totalCount: _messages.length,
                currentPage: 1,
                totalPages: 1,
                hasNextPage: false,
                hasPreviousPage: false,
              );

          await _messagesRepo.addMessageToCache(
            conversationId: widget.group.conversationId,
            newMessage: voiceMessage,
            updatedMeta: updatedMeta,
            insertAtBeginning: false,
          );

          // Send to websocket for real-time messaging
          await _websocketService.sendMessage({
            'type': 'media',
            'data': {
              ...response['data'],
              'conversation_id': widget.group.conversationId,
              'message_type': 'audio',
              'optimistic_id': loadingMessage.id,
              'reply_to_message_id': replyMessageId,
            },
            'conversation_id': widget.group.conversationId,
          });

          print('💾 Group voice message stored locally and displayed');
        } else {
          // Handle upload failure - replace loading message with error
          _handleMediaUploadFailure(
            loadingMessage.id,
            'Failed to upload voice note: ${response['message'] ?? 'Upload failed'}',
          );
        }
      } catch (e) {
        print('❌ Error uploading group voice note: $e');
        _handleMediaUploadFailure(
          loadingMessage.id,
          'Failed to send voice note. Please try again.',
        );
      }

      // Clean up
      setState(() {
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });

      // Delete the temporary file
      if (await voiceFile.exists()) {
        await voiceFile.delete();
      }

      _optimisticMessageId--;
    } catch (e) {
      print('❌ Error sending group voice note: $e');
      _showErrorDialog('Failed to send voice note. Please try again.');
    }
  }

  // Loading message builders for group chat
  Widget _buildImageLoadingMessage(MessageModel message, bool isMyMessage) {
    final attachmentData = message.attachments as Map<String, dynamic>;
    final localPath = attachmentData['local_path'] as String?;

    return ClipRRect(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMyMessage
                ? const Color(0xFF008080)
                : const Color(0xFF008080),
            width: 4,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
            bottomRight: Radius.circular(isMyMessage ? 0 : 14),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: message.body.isNotEmpty
                        ? Radius.zero
                        : Radius.circular(10),
                    bottomRight: message.body.isNotEmpty
                        ? Radius.zero
                        : Radius.circular(10),
                  ),
                  child: localPath != null
                      ? Image.file(
                          File(localPath),
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
                if (message.body.isNotEmpty)
                  Container(
                    width: 200,
                    padding: const EdgeInsets.only(
                      bottom: 20.0,
                      left: 8.0,
                      right: 8.0,
                      top: 4.0,
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
            // Loading overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft: Radius.circular(isMyMessage ? 10 : 0),
                    bottomRight: Radius.circular(isMyMessage ? 0 : 10),
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLoadingMessage(MessageModel message, bool isMyMessage) {
    final attachmentData = message.attachments as Map<String, dynamic>;
    final localPath = attachmentData['local_path'] as String?;
    return ClipRRect(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMyMessage
                ? const Color(0xFF008080)
                : const Color(0xFF008080),
            width: 4,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
            bottomRight: Radius.circular(isMyMessage ? 0 : 14),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft: Radius.circular(isMyMessage ? 10 : 0),
                    bottomRight: Radius.circular(isMyMessage ? 0 : 10),
                  ),
                  child: localPath != null
                      ? Container(
                          width: 200,
                          height: 200,
                          child: _buildVideoThumbnail(localPath),
                        )
                      : Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.videocam,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
                if (message.body.isNotEmpty)
                  Container(
                    width: 200,
                    padding: const EdgeInsets.only(
                      bottom: 20.0,
                      left: 8.0,
                      right: 8.0,
                      top: 4.0,
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
            // Loading overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft: Radius.circular(isMyMessage ? 10 : 0),
                    bottomRight: Radius.circular(isMyMessage ? 0 : 10),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading video...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentLoadingMessage(MessageModel message, bool isMyMessage) {
    final attachmentData = message.attachments as Map<String, dynamic>;
    final fileName = attachmentData['file_name'] as String? ?? 'Document';
    final extension = attachmentData['file_extension'] as String? ?? '';

    IconData docIcon = Icons.description;
    if (extension.isNotEmpty) {
      if (extension.contains('pdf')) {
        docIcon = Icons.picture_as_pdf;
      } else if (extension.contains('doc')) {
        docIcon = Icons.description;
      } else if (extension.contains('xls')) {
        docIcon = Icons.table_chart;
      } else if (extension.contains('ppt')) {
        docIcon = Icons.slideshow;
      } else if (extension.contains('zip') || extension.contains('rar')) {
        docIcon = Icons.archive;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMyMessage ? Colors.teal : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
              bottomRight: Radius.circular(isMyMessage ? 0 : 14),
            ),
            border: Border.all(
              color: isMyMessage ? Colors.teal : Colors.grey[300]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMyMessage
                      ? Colors.teal.withAlpha(25)
                      : Colors.teal.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  docIcon,
                  size: 24,
                  color: isMyMessage ? Colors.white : Colors.teal[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        color: isMyMessage ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Uploading...',
                      style: TextStyle(
                        color: isMyMessage ? Colors.white70 : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMyMessage ? Colors.white : Colors.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioLoadingMessage(MessageModel message, bool isMyMessage) {
    final attachmentData = message.attachments as Map<String, dynamic>;
    final duration = attachmentData['duration'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMyMessage ? Colors.teal : Colors.grey[100],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMyMessage ? 14 : 0),
              bottomRight: Radius.circular(isMyMessage ? 0 : 14),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMyMessage
                      ? Colors.white.withAlpha(20)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.mic,
                  size: 20,
                  color: isMyMessage ? Colors.white : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.audiotrack,
                          size: 16,
                          color: isMyMessage
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: isMyMessage
                                  ? Colors.white30
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(Duration(seconds: duration)),
                          style: TextStyle(
                            color: isMyMessage
                                ? Colors.white70
                                : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isMyMessage ? Colors.white70 : Colors.teal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            color: isMyMessage
                                ? Colors.white70
                                : Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Message action methods
  void _toggleMessageSelection(int messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
        if (_selectedMessages.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessages.add(messageId);
      }
    });
  }

  /// Check if current user is group admin or has staff role
  Future<bool> _isUserAdminOrStaff() async {
    // Check if user is group admin
    if (widget.group.role == 'admin') {
      return true;
    }

    // Check if user role is 'staff'
    try {
      final currentUser = await _userRepo.getFirstUser();
      if (currentUser != null && currentUser.role == 'staff') {
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error checking user role: $e');
    }

    return false;
  }

  /// Check if all selected messages belong to the current user
  bool _areAllSelectedMessagesMine() {
    if (_currentUserId == null || _selectedMessages.isEmpty) {
      return false;
    }

    return _selectedMessages.every((messageId) {
      final message = _messages.firstWhere(
        (msg) => msg.id == messageId,
        orElse: () => MessageModel(
          id: 0,
          body: '',
          type: 'text',
          senderId: 0,
          conversationId: widget.group.conversationId,
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          senderName: '',
        ),
      );
      return message.senderId == _currentUserId;
    });
  }

  /// Build selection mode actions with conditional delete button
  List<Widget> _buildSelectionModeActions() {
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.star_border, color: Colors.white),
        onPressed: _bulkStarMessages,
        tooltip: 'Star messages',
      ),
      IconButton(
        icon: const Icon(Icons.forward, color: Colors.white),
        onPressed: _bulkForwardMessages,
        tooltip: 'Forward messages',
      ),
    ];

    // Show delete button if:
    // 1. User is admin/staff, OR
    // 2. All selected messages belong to the current user

    if (_isAdminOrStaff) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: _bulkDeleteMessages,
          tooltip: 'Delete messages',
        ),
      );
    }

    return actions;
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedMessages.clear();
      _isSelectionMode = false;
    });
  }

  void _enterSelectionMode(int messageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessages.add(messageId);
    });
  }

  void _togglePinMessage(int messageId) async {
    final conversationId = widget.group.conversationId;
    final wasPinned = messageId == _pinnedMessageId;

    setState(() {
      if (wasPinned) {
        _pinnedMessageId = null;
      } else {
        _pinnedMessageId = messageId;
      }
    });

    // Save to local storage
    await _messagesRepo.savePinnedMessage(
      conversationId: conversationId,
      pinnedMessageId: _pinnedMessageId,
    );

    // Send WebSocket message to other users
    await _websocketService.sendMessage({
      'type': 'message_pin',
      'data': {
        'user_id': _currentUserId,
        'action': wasPinned ? 'unpin' : 'pin',
      },
      'conversation_id': conversationId,
      'message_ids': [messageId],
    });
  }

  void _toggleStarMessage(int messageId) async {
    final conversationId = widget.group.conversationId;
    final isCurrentlyStarred = _starredMessages.contains(messageId);

    // Update UI immediately
    setState(() {
      if (isCurrentlyStarred) {
        _starredMessages.remove(messageId);
      } else {
        _starredMessages.add(messageId);
      }
    });

    // Save to local storage
    try {
      await _messagesRepo.toggleStarMessage(messageId);
      debugPrint(
        '⭐ ${isCurrentlyStarred ? 'Unstarred' : 'Starred'} group message $messageId in local storage',
      );
    } catch (e) {
      debugPrint('❌ Error saving star state to group storage: $e');
      // Revert UI state on storage error
      setState(() {
        if (isCurrentlyStarred) {
          _starredMessages.add(messageId);
        } else {
          _starredMessages.remove(messageId);
        }
      });
    }

    // Send WebSocket message to other users
    await _websocketService.sendMessage({
      'type': 'message_star',
      'data': {
        'user_id': _currentUserId,
        'message_id': messageId,
        'action': _starredMessages.contains(messageId) ? 'star' : 'unstar',
      },
      'conversation_id': conversationId,
      'message_ids': [messageId],
    });
  }

  void _forwardMessage(MessageModel message) async {
    setState(() {
      _messagesToForward.clear();
      _messagesToForward.add(message.id);
    });

    await _showForwardModal();
  }

  void _deleteMessage(int messageId) async {
    // bool isAdminOrStaff = false;
    //
    // if (widget.group.role == 'admin') {
    //   isAdminOrStaff = true;
    // } else {
    //   // Check if user role is 'staff'
    //   try {
    //     final currentUser = await _userRepo.getFirstUser();
    //     if (currentUser != null && currentUser.role == 'staff') {
    //       isAdminOrStaff = true;
    //     }
    //   } catch (e) {
    //     debugPrint('❌ Error checking user role: $e');
    //   }
    // }

    final response = await _chatsServices.deleteMessage([
      messageId,
    ], _isAdminOrStaff);

    if (response['success'] == true) {
      debugPrint('✅ Group message deleted successfully');

      // Remove from local state
      setState(() {
        _messages.removeWhere((message) => message.id == messageId);
      });

      // Remove from local storage cache
      await _messagesRepo.removeMessageFromCache(
        conversationId: widget.group.conversationId,
        messageIds: [messageId],
      );
    } else {
      debugPrint(
        '❌ Failed to delete group message: ${response['message'] ?? 'Unknown error'}',
      );
    }
  }

  void _bulkStarMessages() async {
    final conversationId = widget.group.conversationId;
    final messagesToStar = _selectedMessages.toList();
    final areAllStarred = messagesToStar.every(
      (id) => _starredMessages.contains(id),
    );

    // Determine action - if all are starred, unstar them; otherwise star them
    final action = areAllStarred ? 'unstar' : 'star';

    // Update UI immediately
    setState(() {
      if (areAllStarred) {
        _starredMessages.removeAll(messagesToStar);
      } else {
        _starredMessages.addAll(messagesToStar);
      }
    });
    _exitSelectionMode();

    // Save each message to local storage
    try {
      for (final messageId in messagesToStar) {
        if (areAllStarred) {
          await _messagesRepo.unstarMessage(messageId);
        } else {
          await _messagesRepo.starMessage(messageId);
        }
      }
      debugPrint(
        '⭐ Bulk ${action}red ${messagesToStar.length} group messages in local storage',
      );
    } catch (e) {
      debugPrint('❌ Error bulk ${action}ring group messages in storage: $e');
      // Revert UI state on storage error
      setState(() {
        if (areAllStarred) {
          _starredMessages.addAll(messagesToStar);
        } else {
          _starredMessages.removeAll(messagesToStar);
        }
      });
    }

    // Send WebSocket message
    await _websocketService.sendMessage({
      'type': 'message_star',
      'data': {
        'user_id': _currentUserId,
        'message_ids': messagesToStar,
        'action': action,
      },
      'conversation_id': conversationId,
      'message_ids': messagesToStar,
    });
  }

  void _bulkForwardMessages() async {
    setState(() {
      _messagesToForward.clear();
      _messagesToForward.addAll(_selectedMessages);
    });

    _exitSelectionMode();
    await _showForwardModal();
  }

  void _bulkDeleteMessages() async {
    final response = await _chatsServices.deleteMessage(
      _selectedMessages.map((id) => id).toList(),
      _isAdminOrStaff,
    );

    if (response['success'] == true) {
      setState(() {
        _messages.removeWhere(
          (message) => _selectedMessages.contains(message.id),
        );
      });
      await _messagesRepo.removeMessageFromCache(
        conversationId: widget.group.conversationId,
        messageIds: _selectedMessages.map((id) => id).toList(),
      );
    } else {
      debugPrint(
        '❌ Failed to delete group messages: ${response['message'] ?? 'Unknown error'}',
      );
    }
    _exitSelectionMode();
  }

  /// Scroll to a specific message
  void _scrollToMessage(int messageId) {
    // Find the index of the message in the list
    final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex != -1 && _scrollController.hasClients) {
      // Calculate the scroll position (since we're using reverse: true)
      final targetPosition =
          (_messages.length - 1 - messageIndex) *
          100.0; // Approximate height per message

      _scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // Highlight the message after scrolling
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = messageId;
          });

          // Cancel any existing timer
          _highlightTimer?.cancel();

          // Remove highlight after 1 second
          _highlightTimer = Timer(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _highlightedMessageId = null;
              });
            }
          });
        }
      });
    }
  }

  Widget _buildPinnedMessageSection() {
    final pinnedMessage = _messages.firstWhere(
      (message) => message.id == _pinnedMessageId,
      // orElse: () => throw StateError('Pinned message not found'),
    );

    final isMyMessage =
        _currentUserId != null && pinnedMessage.senderId == _currentUserId;
    final messageTime = ChatHelpers.formatMessageTime(pinnedMessage.createdAt);

    return GestureDetector(
      onTap: () => _scrollToMessage(pinnedMessage.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          // borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pin icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.push_pin, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name and time
                  Row(
                    children: [
                      Text(
                        isMyMessage ? 'You' : pinnedMessage.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        messageTime,
                        style: TextStyle(color: Colors.blue[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Message text
                  Text(
                    pinnedMessage.body,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unpin button
            IconButton(
              onPressed: () => _togglePinMessage(pinnedMessage.id),
              icon: Icon(Icons.close, size: 18, color: Colors.blue[600]),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForwardModal() async {
    await _loadAvailableConversations();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => _ForwardMessageModal(
        messagesToForward: _messagesToForward,
        availableConversations: _availableConversations,
        isLoading: _isLoadingConversations,
        onForward: _handleForwardToConversations,
        currentConversationId: widget.group.conversationId,
      ),
    );
  }

  Future<void> _loadAvailableConversations() async {
    setState(() {
      _isLoadingConversations = true;
    });

    try {
      final response = await _userService.GetChatList('all');
      debugPrint('🔍 Group forward modal - Raw API response: $response');

      if (response['success'] == true && response['data'] != null) {
        final dynamic responseData = response['data'];
        List<dynamic> conversationsList = [];

        if (responseData is List) {
          conversationsList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            conversationsList = responseData['data'] as List<dynamic>;
          } else {
            for (var key in responseData.keys) {
              if (responseData[key] is List) {
                conversationsList = responseData[key] as List<dynamic>;
                break;
              }
            }
          }
        }

        if (conversationsList.isNotEmpty) {
          final conversations = <ConversationModel>[];

          for (int i = 0; i < conversationsList.length; i++) {
            final json = conversationsList[i];
            try {
              final conversation = ConversationModel.fromJson(
                json as Map<String, dynamic>,
              );

              // Exclude current conversation
              if (conversation.conversationId != widget.group.conversationId) {
                conversations.add(conversation);
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing conversation $i: $e');
              continue;
            }
          }

          setState(() {
            _availableConversations = conversations;
          });

          debugPrint(
            '✅ Group forward modal - Successfully loaded ${conversations.length} conversations for forwarding',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations for group forward: $e');
      if (mounted) {
        _showErrorDialog('Failed to load conversations. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
        });
      }
    }
  }

  Future<void> _handleForwardToConversations(
    List<int> selectedConversationIds,
  ) async {
    if (_messagesToForward.isEmpty || selectedConversationIds.isEmpty) {
      return;
    }

    try {
      // Send WebSocket message for forwarding
      await _websocketService.sendMessage({
        'type': 'message_forward',
        'data': {
          'user_id': _currentUserId,
          'source_conversation_id': widget.group.conversationId,
          'target_conversation_ids': selectedConversationIds,
        },
        'message_ids': _messagesToForward.toList(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Forwarded ${_messagesToForward.length} message${_messagesToForward.length > 1 ? 's' : ''} to ${selectedConversationIds.length} chat${selectedConversationIds.length > 1 ? 's' : ''}',
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Clear forward state
      setState(() {
        _messagesToForward.clear();
      });

      debugPrint('✅ Group messages forwarded successfully');
    } catch (e) {
      debugPrint('❌ Error forwarding group messages: $e');
      if (mounted) {
        _showErrorDialog('Failed to forward messages. Please try again.');
      }
    }
  }
}

// Forward Message Modal - copied from inner_chat_page.dart
class _ForwardMessageModal extends StatefulWidget {
  final Set<int> messagesToForward;
  final List<ConversationModel> availableConversations;
  final bool isLoading;
  final Function(List<int>) onForward;
  final int currentConversationId;

  const _ForwardMessageModal({
    required this.messagesToForward,
    required this.availableConversations,
    required this.isLoading,
    required this.onForward,
    required this.currentConversationId,
  });

  @override
  State<_ForwardMessageModal> createState() => _ForwardMessageModalState();
}

class _ForwardMessageModalState extends State<_ForwardMessageModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedConversations = {};
  List<ConversationModel> _filteredConversations = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Initialize filtered conversations
    _filteredConversations = widget.availableConversations;

    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterConversations(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConversations = widget.availableConversations;
      } else {
        _filteredConversations = widget.availableConversations
            .where(
              (conv) =>
                  conv.displayName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _toggleConversationSelection(int conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  Future<void> _handleForward() async {
    if (_selectedConversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one chat to forward to'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Close modal with animation
    await _slideController.reverse();
    await _fadeController.reverse();

    if (mounted) {
      Navigator.of(context).pop();
      widget.onForward(_selectedConversations.toList());
    }
  }

  Future<void> _handleCancel() async {
    await _slideController.reverse();
    await _fadeController.reverse();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  Widget _buildConversationAvatar(ConversationModel conversation) {
    if (conversation.isGroup) {
      // Group conversation - show group icon
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.orange[100],
        child: Icon(Icons.group, color: Colors.orange[700], size: 28),
      );
    } else {
      // DM conversation - show user avatar or initials
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.teal[100],
        backgroundImage: conversation.displayAvatar != null
            ? NetworkImage(conversation.displayAvatar!)
            : null,
        child: conversation.displayAvatar == null
            ? Text(
                _getInitials(conversation.displayName),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: SlideTransition(
          position: _slideAnimation,
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.forward, color: Colors.teal, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Forward Message${widget.messagesToForward.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${widget.messagesToForward.length} message${widget.messagesToForward.length > 1 ? 's' : ''} selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _handleCancel,
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search chats...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[500],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onChanged: _filterConversations,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Selected count
                    if (_selectedConversations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '${_selectedConversations.length} selected',
                                style: TextStyle(
                                  color: Colors.teal[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Conversations list
                    Expanded(
                      child: widget.isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: Colors.teal),
                                  SizedBox(height: 16),
                                  Text('Loading chats...'),
                                ],
                              ),
                            )
                          : _filteredConversations.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No chats available'
                                        : 'No chats found for "$_searchQuery"',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _filteredConversations.length,
                              itemBuilder: (context, index) {
                                final conversation =
                                    _filteredConversations[index];
                                final isSelected = _selectedConversations
                                    .contains(conversation.conversationId);

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.teal.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.teal.withOpacity(0.3)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _toggleConversationSelection(
                                      conversation.conversationId,
                                    ),
                                    leading: _buildConversationAvatar(
                                      conversation,
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversation.displayName,
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              fontSize: 16,
                                              color: isSelected
                                                  ? Colors.teal[700]
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (conversation.isGroup)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.orange[300]!,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              'GROUP',
                                              style: TextStyle(
                                                color: Colors.orange[700],
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle:
                                        conversation
                                                .metadata
                                                ?.lastMessage
                                                .body !=
                                            null
                                        ? Text(
                                            conversation
                                                .metadata!
                                                .lastMessage
                                                .body,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? Colors.teal
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.teal
                                              : Colors.grey[400]!,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Forward button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedConversations.isEmpty
                                  ? null
                                  : _handleForward,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedConversations.isEmpty
                                        ? 'Select chats to forward'
                                        : 'Forward to ${_selectedConversations.length} chat${_selectedConversations.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Voice Recording Modal - copied from inner_chat_page.dart
class _VoiceRecordingModal extends StatefulWidget {
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;
  final bool isRecording;
  final Duration recordingDuration;
  final Animation<double> zigzagAnimation;
  final Animation<double> voiceModalAnimation;
  final Stream<Duration> timerStream;

  const _VoiceRecordingModal({
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
    required this.isRecording,
    required this.recordingDuration,
    required this.zigzagAnimation,
    required this.voiceModalAnimation,
    required this.timerStream,
  });

  @override
  State<_VoiceRecordingModal> createState() => _VoiceRecordingModalState();
}

class _VoiceRecordingModalState extends State<_VoiceRecordingModal> {
  @override
  void initState() {
    super.initState();
    // Auto-start recording when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStartRecording();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.voiceModalAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.voiceModalAnimation.value,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  // Microphone icon with pulse animation
                  AnimatedBuilder(
                    animation: widget.zigzagAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: widget.isRecording
                              ? Colors.red
                              : Colors.grey[300],
                          shape: BoxShape.circle,
                          boxShadow: widget.isRecording
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(
                                      0.3 * widget.zigzagAnimation.value,
                                    ),
                                    blurRadius:
                                        20 * widget.zigzagAnimation.value,
                                    spreadRadius:
                                        5 * widget.zigzagAnimation.value,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.mic,
                          color: widget.isRecording
                              ? Colors.white
                              : Colors.grey[600],
                          size: 20,
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 15),

                  // Recording info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (widget.isRecording) ...[
                              AnimatedBuilder(
                                animation: widget.zigzagAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(
                                        widget.zigzagAnimation.value,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            StreamBuilder<Duration>(
                              stream: widget.timerStream,
                              initialData: widget.recordingDuration,
                              builder: (context, snapshot) {
                                final currentDuration =
                                    snapshot.data ?? Duration.zero;
                                return Text(
                                  widget.isRecording
                                      ? 'Recording ${_formatDuration(currentDuration)}'
                                      : _formatDuration(currentDuration),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isRecording
                                        ? Colors.red
                                        : Colors.teal,
                                    letterSpacing: 0.5,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Control buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete button
                      GestureDetector(
                        onTap: widget.onCancelRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Send/Stop button
                      GestureDetector(
                        onTap: widget.isRecording
                            ? widget.onStopRecording
                            : widget.onSendRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.isRecording
                                ? Colors.red.withOpacity(0.1)
                                : Colors.teal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isRecording ? Icons.stop : Icons.send,
                            color: widget.isRecording
                                ? Colors.red
                                : Colors.teal,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ReadBy Modal Widget with smooth animations and good UI/UX
class ReadByModal extends StatefulWidget {
  final MessageModel message;
  final List<Map<String, dynamic>> members;
  final int? currentUserId;

  const ReadByModal({
    super.key,
    required this.message,
    required this.members,
    this.currentUserId,
  });

  @override
  State<ReadByModal> createState() => _ReadByModalState();
}

class _ReadByModalState extends State<ReadByModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize animations
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Get members who have read the message
  List<Map<String, dynamic>> _getReadMembers() {
    final readMembers = <Map<String, dynamic>>[];

    for (final member in widget.members) {
      final lastReadMessageId = member['last_read_message_id'];
      final userId = member['user_id'];

      // Skip current user
      if (userId == widget.currentUserId) continue;

      // Check if member has read this message or a later one
      if (lastReadMessageId != null) {
        final lastReadId = lastReadMessageId is int
            ? lastReadMessageId
            : int.tryParse(lastReadMessageId.toString());

        if (lastReadId != null && lastReadId >= widget.message.id) {
          readMembers.add(member);
        }
      }
    }

    return readMembers;
  }

  /// Get members who haven't read the message
  List<Map<String, dynamic>> _getUnreadMembers() {
    final unreadMembers = <Map<String, dynamic>>[];

    for (final member in widget.members) {
      final lastReadMessageId = member['last_read_message_id'];
      final userId = member['user_id'];

      // Skip current user
      if (userId == widget.currentUserId) continue;

      // Check if member hasn't read this message
      if (lastReadMessageId == null) {
        unreadMembers.add(member);
      } else {
        final lastReadId = lastReadMessageId is int
            ? lastReadMessageId
            : int.tryParse(lastReadMessageId.toString());

        if (lastReadId == null || lastReadId < widget.message.id) {
          unreadMembers.add(member);
        }
      }
    }

    return unreadMembers;
  }

  void _closeModal() async {
    await _fadeController.reverse();
    await _slideController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readMembers = _getReadMembers();
    final unreadMembers = _getUnreadMembers();

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
          child: GestureDetector(
            onTap: _closeModal,
            child: Container(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on modal content
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.mark_chat_read_rounded,
                                      color: Colors.teal[600],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Read By',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          '${readMembers.length} of ${widget.members.length - 1} members',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _closeModal,
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),

                              // Message preview
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.teal[400],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        widget.message.body.isNotEmpty
                                            ? widget.message.body
                                            : _getMessageTypeText(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Read members section
                        if (readMembers.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Read by ${readMembers.length}',
                            true,
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: readMembers.length,
                              itemBuilder: (context, index) {
                                return _buildMemberTile(
                                  readMembers[index],
                                  true,
                                  index,
                                );
                              },
                            ),
                          ),
                        ],

                        // Unread members section
                        if (unreadMembers.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Not read by ${unreadMembers.length}',
                            false,
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: unreadMembers.length,
                              itemBuilder: (context, index) {
                                return _buildMemberTile(
                                  unreadMembers[index],
                                  false,
                                  index + readMembers.length,
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isRead) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: isRead ? Colors.green[400] : Colors.orange[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isRead ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    Map<String, dynamic> member,
    bool hasRead,
    int index,
  ) {
    final name = member['name']?.toString() ?? 'Unknown User';
    final profilePic = member['profile_pic']?.toString();
    final lastReadMessageId = member['last_read_message_id'];

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasRead ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasRead ? Colors.green[200]! : Colors.orange[200]!,
                ),
              ),
              child: Row(
                children: [
                  // Profile picture or initials
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasRead ? Colors.green[100] : Colors.orange[100],
                      shape: BoxShape.circle,
                    ),
                    child: profilePic != null && profilePic.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profilePic,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildInitials(name);
                              },
                            ),
                          )
                        : _buildInitials(name),
                  ),

                  const SizedBox(width: 12),

                  // Name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (hasRead && lastReadMessageId != null)
                          Text(
                            'Read at message #$lastReadMessageId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Text(
                            'Not read yet',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasRead ? Colors.green[400] : Colors.orange[400],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasRead ? Icons.check : Icons.schedule,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .map((word) => word.isNotEmpty ? word[0] : '')
              .take(2)
              .join('')
              .toUpperCase()
        : 'U';

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  String _getMessageTypeText() {
    switch (widget.message.type) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎥 Video';
      case 'document':
        return '📄 Document';
      case 'audios':
        return '🎵 Voice Message';
      default:
        return 'Message';
    }
  }
}
