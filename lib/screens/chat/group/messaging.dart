import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/group_model.dart';
import '../../../models/message_model.dart';
import '../../../models/conversation_model.dart';
import '../../../models/community_model.dart';
import '../../../models/user_model.dart';
import '../../../api/groups.services.dart';
import '../../../api/user.service.dart';
import '../../../api/chats.services.dart';
import '../../../services/message_storage_service.dart';
import '../../../db/repositories/messages_repository.dart';
import '../../../db/repositories/user_repository.dart';
import '../../../db/repositories/groups_repository.dart';
import '../../../db/repositories/group_members_repository.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../services/socket/websocket_message_handler.dart';
import '../../../widgets/loading_dots_animation.dart';
import '../../../services/media_cache_service.dart';
import '../../../utils/chat/chat_helpers.dart';
import '../../../utils/chat/sync_messages.utils.dart';
import '../../../utils/message_storage_helpers.dart';
import '../../../utils/animations.utils.dart';
import '../../../widgets/chat/attachment_action_sheet.dart';
import '../../../utils/chat/attachments.utils.dart';
import '../../../widgets/chat/message_action_sheet.dart';
import '../../../widgets/chat/date.widgets.dart';
import '../../../widgets/chat/scroll_to_bottom_button.dart';
import '../../../widgets/chat/messagewidget.dart';
import '../../../widgets/chat/forward_message_widget.dart';
import '../../../widgets/chat/voice_recording_widget.dart';
import '../../../widgets/chat/pinned_message.widget.dart';
import '../../../utils/chat/group_readby_modal.dart';
import '../../../utils/chat/forward_message.utils.dart';
import '../../../utils/chat/preview_media.utils.dart';
import '../../../utils/chat/audio_playback.utils.dart';
import '../../../utils/chat/sendMediaMessage.utils.dart';
import '../../../utils/chat/chatActions.utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/draft_message_service.dart';
import '../../../providers/draft_provider.dart';
import '../../../widgets/chat/inputcontainer.widget.dart';
import '../../../widgets/chat/media_messages.widget.dart';
import 'group_info.dart';

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

  // Scroll to bottom button state
  bool _isAtBottom = true;
  int _unreadCountWhileScrolled = 0;
  int _previousMessageCount = 0;

  // For optimistic message handling - using filtered streams per conversation
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _mediaSubscription;
  StreamSubscription<Map<String, dynamic>>? _messagePinSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageStarSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageReplySubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeleteSubscription;
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
  late AnimationController _voiceModalAnimationController;
  late AnimationController _zigzagAnimationController;
  late Animation<double> _voiceModalAnimation;
  late Animation<double> _zigzagAnimation;
  final StreamController<Duration> _timerStreamController =
      StreamController<Duration>.broadcast();

  // Audio playback manager
  late AudioPlaybackManager _audioPlaybackManager;

  // Voice recording manager
  late VoiceRecordingManager _voiceRecordingManager;

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
    final result = initializeTypingDotAnimation(this);
    _typingAnimationController = result.controller;
    _typingDotAnimations = result.dotAnimations;
  }

  void _initializeVoiceAnimations() {
    final result = initializeVoiceAnimations(this);
    _voiceModalAnimationController = result.voiceModalController;
    _zigzagAnimationController = result.zigzagController;
    _voiceModalAnimation = result.voiceModalAnimation;
    _zigzagAnimation = result.zigzagAnimation;

    // Initialize voice recording manager
    _voiceRecordingManager = VoiceRecordingManager(
      mounted: () => mounted,
      setState: () => setState(() {}),
      showErrorDialog: _showErrorDialog,
      context: context,
      voiceModalAnimationController: _voiceModalAnimationController,
      zigzagAnimationController: _zigzagAnimationController,
      timerStreamController: _timerStreamController,
      filePrefix: 'group_voice_note_',
    );

    // Initialize audio playback manager
    _audioPlaybackManager = AudioPlaybackManager(
      vsync: this,
      mounted: () => mounted,
      setState: () => setState(() {}),
      showErrorDialog: _showErrorDialog,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      messages: _messages,
    );

    // Initialize the audio player asynchronously
    _audioPlaybackManager.initialize();
  }

  /// Ultra-fast cache check that runs immediately
  void _quickCacheCheck() async {
    try {
      final conversationId = widget.group.conversationId;

      // Quick check if we have cached messages in DB
      final count = await _messagesRepo.getMessageCount(conversationId);
      if (count > 0) {
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
      final response = await _chatsServices.getConversationHistory(
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
    final conversationId = widget.group.conversationId;

    await tryLoadFromCacheFirst(
      TryLoadFromCacheFirstConfig(
        conversationId: conversationId,
        messagesRepo: _messagesRepo,
        mounted: () => mounted,
        setState: setState,
        hasCheckedCache: () => _hasCheckedCache,
        setHasCheckedCache: (value) => _hasCheckedCache = value,
        setMessages: (value) => _messages = value,
        setConversationMeta: (value) => _conversationMeta = value,
        setHasMoreMessages: (value) => _hasMoreMessages = value,
        setCurrentPage: (value) => _currentPage = value,
        setIsInitialized: (value) => _isInitialized = value,
        setIsLoading: (value) => _isLoading = value,
        setErrorMessage: (value) => _errorMessage = value,
        setIsCheckingCache: (value) => _isCheckingCache = value,
        setIsLoadingFromCache: (value) => _isLoadingFromCache = value,
        validateMessages: (messages) {
          _validatePinnedMessage();
          _validateStarredMessages();
          _validateReplyMessages();
        },
        populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
        cleanCachedMessages: (messages) {
          // Filter out old orphaned optimistic messages (messages with negative IDs older than 5 minutes)
          // final now = DateTime.now();
          // final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

          final cleanedMessages = messages.where((msg) {
            // Keep all messages with positive IDs (server-confirmed)
            if (msg.id >= 0) return true;

            // For optimistic messages (negative IDs), only keep recent ones
            try {
              // final createdAt = DateTime.parse(msg.createdAt);
              // return createdAt.isAfter(fiveMinutesAgo);
              return true;
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

          return deduplicatedMessages;
        },
        onAfterLoadFromCache: (processedMessages, originalCount) {},
        getErrorLogMessage: () => 'Error in quick group cache check',
      ),
    );
  }

  Future<void> _getCurrentUserId() async {
    try {
      // FAST PATH: Try to get from local DB first (instant)
      // final conversationId = widget.group.conversationId;
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

    // Dispose audio playback manager
    _audioPlaybackManager.dispose();

    // Dispose voice recording manager
    _voiceRecordingManager.dispose();

    // Dispose voice recording controllers
    _voiceModalAnimationController.dispose();
    _zigzagAnimationController.dispose();
    _timerStreamController.close();

    _websocketService
        .sendMessage({
          'type': 'inactive_in_conversation',
          'conversation_id': widget.group.conversationId,
        })
        .catchError((e) {
          debugPrint('❌ Error sending inactive_in_conversation: $e');
        });

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

    // Update scroll to bottom button state
    _updateScrollToBottomState();

    // With reverse: true, when scrolling to see older messages (scrolling "up" in the UI),
    // we're actually scrolling towards maxScrollExtent
    // Load older messages when we're near the top of the scroll (close to maxScrollExtent)
    final scrollPosition = _scrollController.position.pixels;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final distanceFromTop = maxScrollExtent - scrollPosition;

    if (distanceFromTop <= 100000) {
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
    final conversationId = widget.group.conversationId;

    await loadInitialMessages(
      LoadInitialMessagesConfig(
        conversationId: conversationId,
        messagesRepo: _messagesRepo,
        chatsServices: _chatsServices,
        mounted: () => mounted,
        setState: setState,
        hasCheckedCache: () => _hasCheckedCache,
        getMessages: () => _messages,
        getConversationMeta: () => _conversationMeta,
        getHasMoreMessages: () => _hasMoreMessages,
        getCurrentPage: () => _currentPage,
        getIsInitialized: () => _isInitialized,
        getIsLoading: () => _isLoading,
        getErrorMessage: () => _errorMessage,
        getIsCheckingCache: () => _isCheckingCache,
        getIsLoadingFromCache: () => _isLoadingFromCache,
        setHasCheckedCache: (value) => _hasCheckedCache = value,
        setMessages: (value) => _messages = value,
        setConversationMeta: (value) => _conversationMeta = value,
        setHasMoreMessages: (value) => _hasMoreMessages = value,
        setCurrentPage: (value) => _currentPage = value,
        setIsInitialized: (value) => _isInitialized = value,
        setIsLoading: (value) => _isLoading = value,
        setErrorMessage: (value) => _errorMessage = value,
        setIsCheckingCache: (value) => _isCheckingCache = value,
        setIsLoadingFromCache: (value) => _isLoadingFromCache = value,
        performSmartSync: _performSmartSync,
        validateMessages: (messages) {
          _validatePinnedMessage();
          _validateStarredMessages();
          _validateReplyMessages();
        },
        populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
        cleanCachedMessages: (messages) {
          // Filter out old orphaned optimistic messages (messages with negative IDs older than 5 minutes)
          final now = DateTime.now();
          final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

          final cleanedMessages = messages.where((msg) {
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

          return deduplicatedMessages;
        },
        onAfterLoadFromServer: _cacheUsersFromMetadata,
        getErrorMessageText: () => 'Failed to load group messages',
        getNoCacheMessage: () =>
            'ℹ️ No cached group messages found in local DB',
      ),
    );
  }

  Future<void> _loadMoreMessages() async {
    final conversationId = widget.group.conversationId;

    await loadMoreMessages(
      LoadMoreMessagesConfig(
        conversationId: conversationId,
        messagesRepo: _messagesRepo,
        chatsServices: _chatsServices,
        mounted: () => mounted,
        setState: setState,
        isLoadingMore: () => _isLoadingMore,
        hasMoreMessages: () => _hasMoreMessages,
        currentPage: () => _currentPage,
        getMessages: () => _messages,
        getConversationMeta: () => _conversationMeta,
        setIsLoadingMore: (value) => _isLoadingMore = value,
        setHasMoreMessages: (value) => _hasMoreMessages = value,
        setCurrentPage: (value) => _currentPage = value,
        setMessages: (value) => _messages = value,
        setConversationMeta: (value) => _conversationMeta = value,
        populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
        onAfterLoadMore: _cacheUsersFromMetadata,
      ),
    );
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
        if (!_isAtBottom) {
          _trackNewMessage();
        }
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
        if (_isAtBottom) {
          _scrollToBottom();
        } else {
          _trackNewMessage();
        }
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
        if (!_isAtBottom) {
          _trackNewMessage();
        }
      }

      // Store message asynchronously in local storage
      _storeMessageAsync(newMediaMessage);
    } catch (e) {
      debugPrint('❌ Error processing incoming group media message: $e');
    }
  }

  /// Handle incoming message pin from WebSocket
  void _handleMessagePin(Map<String, dynamic> message) async {
    await handleMessagePin(
      HandleMessagePinConfig(
        message: message,
        conversationId: widget.group.conversationId,
        mounted: () => mounted,
        setState: setState,
        getPinnedMessageId: () => _pinnedMessageId,
        setPinnedMessageId: (value) => _pinnedMessageId = value,
        messagesRepo: _messagesRepo,
      ),
    );
  }

  /// Handle incoming message star from WebSocket
  void _handleMessageStar(Map<String, dynamic> message) async {
    await handleMessageStar(
      HandleMessageStarConfig(
        message: message,
        mounted: () => mounted,
        setState: setState,
        starredMessages: _starredMessages,
        messagesRepo: _messagesRepo,
      ),
    );
  }

  /// Handle message delete event from WebSocket
  void _handleMessageDelete(Map<String, dynamic> message) async {
    await handleMessageDelete(
      HandleMessageDeleteConfig(
        message: message,
        mounted: () => mounted,
        setState: setState,
        messages: _messages,
        conversationId: widget.group.conversationId,
        messagesRepo: _messagesRepo,
      ),
    );
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
                ChatHelpers.cacheMediaForMessage(
                  url: mediaUrl,
                  messageId: message.id,
                  messagesRepo: _messagesRepo,
                  mediaCacheService: _mediaCacheService,
                  checkExistingCache: false,
                  debugPrefix: 'group message',
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error storing group message asynchronously: $e');
      }
    });
  }

  /// Scroll to bottom of message list
  void _scrollToBottom() {
    ChatHelpers.scrollToBottom(
      scrollController: _scrollController,
      onScrollComplete: () {
        if (mounted) {
          setState(() {
            _unreadCountWhileScrolled = 0;
            _isAtBottom = true;
          });
        }
      },
      mounted: mounted,
    );
  }

  /// Handle scroll to bottom button tap
  void _handleScrollToBottomTap() {
    _scrollToBottom();
    // Clear unread count
    setState(() {
      _unreadCountWhileScrolled = 0;
    });
  }

  /// Update scroll to bottom button state
  void _updateScrollToBottomState() {
    if (!_scrollController.hasClients) return;

    final scrollPosition = _scrollController.position.pixels;

    // With reverse: true, 0 is the bottom, maxScrollExtent is the top
    // Check if we're within 100px of the bottom
    final isAtBottomNow = scrollPosition <= 100;

    // Check if user scrolled up significantly
    final scrolledUp = scrollPosition > _lastScrollPosition + 50;

    if (isAtBottomNow) {
      // User is at bottom - clear unread count
      if (mounted && (!_isAtBottom || _unreadCountWhileScrolled > 0)) {
        setState(() {
          _isAtBottom = true;
          _unreadCountWhileScrolled = 0;
        });
      }
    } else if (scrolledUp || scrollPosition > 100) {
      // User scrolled up - show button
      if (mounted && _isAtBottom) {
        setState(() {
          _isAtBottom = false;
        });
      }
    }
  }

  /// Track new messages when added while scrolled up
  void _trackNewMessage() {
    if (!_isAtBottom && mounted) {
      setState(() {
        _unreadCountWhileScrolled++;
      });
    }
    _previousMessageCount = _messages.length;
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
                if (_pinnedMessageId != null)
                  PinnedMessageSection(
                    pinnedMessage: _messages.firstWhere(
                      (message) => message.id == _pinnedMessageId,
                    ),
                    currentUserId: _currentUserId,
                    isGroupChat: true,
                    onTap: () => _scrollToMessage(_pinnedMessageId!),
                    onUnpin: () => _togglePinMessage(_pinnedMessageId!),
                  ),

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
            // Scroll to Bottom Button - positioned at right bottom
            Positioned(
              right: 16,
              bottom: _isReplying
                  ? 150.0
                  : 80.0, // Position above message input
              child: ScrollToBottomButton(
                scrollController: _scrollController,
                onTap: _handleScrollToBottomTap,
                isAtBottom: _isAtBottom,
                unreadCount: _unreadCountWhileScrolled > 0
                    ? _unreadCountWhileScrolled
                    : null,
                bottomPadding:
                    0.0, // Not used anymore, positioning handled by parent
              ),
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

    return MessageBubble(
      config: MessageBubbleConfig(
        message: message,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        isHighlighted: isHighlighted,
        messageTime: messageTime,
        shouldAnimate: shouldAnimate,
        animationController: _messageAnimationControllers[message.id],
        slideAnimation: slideAnimation,
        fadeAnimation: fadeAnimation,
        context: context,
        buildMessageContent: _buildMessageContent,
        isMediaMessage: _isMediaMessage,
        isGroupChat: true,
        nonMyMessageBackgroundColor: Colors.grey[100]!,
        useIntrinsicWidth: false,
        useStackContainer: false,
        currentUserId: _currentUserId,
        onReplyTap: _scrollToMessage,
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMyMessage) {
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
    return isMediaMessage(message);
  }

  /// Handle media upload failure
  /// Handle media upload failure - update only metadata to mark as failed
  void _handleMediaUploadFailure(MessageModel loadingMessage, String error) {
    if (!mounted) return;

    // Find the message and update only metadata
    final index = _messages.indexWhere((msg) => msg.id == loadingMessage.id);
    if (index != -1) {
      final failedMessage = _messages[index];
      final updatedMetadata = Map<String, dynamic>.from(
        failedMessage.metadata ?? {},
      );
      updatedMetadata['is_uploading'] = false;
      updatedMetadata['upload_failed'] = true;

      setState(() {
        // Use copyWith to update only metadata, explicitly preserve attachments
        _messages[index] = failedMessage.copyWith(
          metadata: updatedMetadata,
          attachments:
              failedMessage.attachments, // Explicitly preserve attachments
        );
      });
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

  // Media handling methods from inner_chat_page.dart
  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AttachmentActionSheet(
        onCameraTap: () => _handleCameraAttachment(),
        onGalleryTap: () => _handleGalleryAttachment(),
        onDocumentTap: () => _handleDocumentAttachment(),
      ),
    );
  }

  void _handleCameraAttachment() async {
    await handleCameraAttachment(
      imagePicker: _imagePicker,
      context: context,
      onImageSelected: (imageFile, source) {
        _sendImageMessage(imageFile, source);
      },
      onError: (message) {
        _showErrorDialog(message);
      },
      onPermissionDenied: (permissionType) {
        openAppSettings();
      },
    );
  }

  void _handleGalleryAttachment() async {
    await handleGalleryAttachment(
      context: context,
      onImageSelected: (imageFile, source) {
        _sendImageMessage(imageFile, source);
      },
      onVideoSelected: (videoFile, source) {
        _sendVideoMessage(videoFile, source);
      },
      onError: (message) {
        _showErrorDialog(message);
      },
    );
  }

  void _handleDocumentAttachment() async {
    await handleDocumentAttachment(
      context: context,
      onDocumentSelected: (documentFile, fileName, extension) {
        _sendDocumentMessage(documentFile, fileName, extension);
      },
      onError: (message) {
        _showErrorDialog(message);
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

  Widget _buildMessageStatusTicks(MessageModel message) {
    // For group chats, show delivery status based on isDelivered
    if (message.isDelivered) {
      // Double tick - message is delivered
      return Icon(Icons.done_all, size: 16, color: Colors.white70);
    } else {
      // Single tick - message is sent but not delivered
      return Icon(Icons.done, size: 16, color: Colors.white70);
    }
  }

  MediaMessageConfig _buildMediaMessageConfig(
    MessageModel message,
    bool isMyMessage,
  ) {
    return MediaMessageConfig(
      message: message,
      isMyMessage: isMyMessage,
      isStarred: _starredMessages.contains(message.id),
      mounted: () => mounted,
      setState: () => setState(() {}),
      showErrorDialog: _showErrorDialog,
      buildMessageStatusTicks: _buildMessageStatusTicks,
      onImagePreview: (url, caption) => _openImagePreview(url, caption),
      onRetryImage: (file, source, {MessageModel? failedMessage}) =>
          _sendImageMessage(file, source, failedMessage: failedMessage),
      onCacheImage: (url, id) {
        ChatHelpers.cacheMediaForMessage(
          url: url,
          messageId: id,
          messagesRepo: _messagesRepo,
          mediaCacheService: _mediaCacheService,
          checkExistingCache: false,
          debugPrefix: 'group message',
        );
      },
      onVideoPreview: (url, caption, fileName) =>
          _openVideoPreview(url, caption, fileName),
      onRetryVideo: (file, source, {MessageModel? failedMessage}) =>
          _sendVideoMessage(file, source, failedMessage: failedMessage),
      videoThumbnailCache: _videoThumbnailCache,
      videoThumbnailFutures: _videoThumbnailFutures,
      onDocumentPreview: (url, fileName, caption, fileSize) =>
          _openDocumentPreview(url, fileName, caption, fileSize),
      onRetryDocument:
          (file, fileName, extension, {MessageModel? failedMessage}) =>
              _sendDocumentMessage(
                file,
                fileName,
                extension,
                failedMessage: failedMessage,
              ),
      audioPlaybackManager: _audioPlaybackManager,
      onRetryAudio: ({MessageModel? failedMessage}) =>
          _sendRecordedVoice(failedMessage: failedMessage),
    );
  }

  // Add all missing media rendering methods
  Widget _buildImageMessage(MessageModel message, bool isMyMessage) {
    return buildImageMessage(_buildMediaMessageConfig(message, isMyMessage));
  }

  Widget _buildVideoMessage(MessageModel message, bool isMyMessage) {
    return buildVideoMessage(_buildMediaMessageConfig(message, isMyMessage));
  }

  Widget _buildDocumentMessage(MessageModel message, bool isMyMessage) {
    return buildDocumentMessage(_buildMediaMessageConfig(message, isMyMessage));
  }

  Widget _buildAudioMessage(MessageModel message, bool isMyMessage) {
    return buildAudioMessage(_buildMediaMessageConfig(message, isMyMessage));
  }

  void _sendVoiceNote() async {
    final micStatus = await Permission.microphone.status;
    if (micStatus.isGranted) {
      _showVoiceRecordingModal();
    } else {
      await _checkAndRequestMicrophonePermission();
      final newStatus = await Permission.microphone.status;
      if (newStatus.isGranted) {
        _showVoiceRecordingModal();
      }
    }
  }

  // Media sending methods
  void _sendImageMessage(
    File imageFile,
    String source, {
    MessageModel? failedMessage,
  }) async {
    await sendImageMessage(
      SendMediaMessageConfig(
        mediaFile: imageFile,
        conversationId: widget.group.conversationId,
        currentUserId: _currentUserId,
        optimisticMessageId: _optimisticMessageId,
        replyToMessage: _replyToMessageData,
        replyToMessageId: _replyToMessageData?.id,
        failedMessage: failedMessage,
        messageType: 'image',
        messages: _messages,
        optimisticMessageIds: _optimisticMessageIds,
        conversationMeta: _conversationMeta,
        messagesRepo: _messagesRepo,
        chatsServices: _chatsServices,
        websocketService: _websocketService,
        mounted: () => mounted,
        setState: setState,
        handleMediaUploadFailure: _handleMediaUploadFailure,
        animateNewMessage: _animateNewMessage,
        scrollToBottom: _scrollToBottom,
        cancelReply: _cancelReply,
        isReplying: _isReplying,
      ),
    );

    // Only decrement optimistic ID if this was a new message (not a retry)
    if (failedMessage == null) {
      _optimisticMessageId--;
    }
  }

  void _sendVideoMessage(
    File videoFile,
    String source, {
    MessageModel? failedMessage,
  }) async {
    await sendVideoMessage(
      SendMediaMessageConfig(
        mediaFile: videoFile,
        conversationId: widget.group.conversationId,
        currentUserId: _currentUserId,
        optimisticMessageId: _optimisticMessageId,
        replyToMessage: _replyToMessageData,
        replyToMessageId: _replyToMessageData?.id,
        failedMessage: failedMessage,
        messageType: 'video',
        messages: _messages,
        optimisticMessageIds: _optimisticMessageIds,
        conversationMeta: _conversationMeta,
        messagesRepo: _messagesRepo,
        chatsServices: _chatsServices,
        websocketService: _websocketService,
        mounted: () => mounted,
        setState: setState,
        handleMediaUploadFailure: _handleMediaUploadFailure,
        animateNewMessage: _animateNewMessage,
        scrollToBottom: _scrollToBottom,
        cancelReply: _cancelReply,
        isReplying: _isReplying,
      ),
    );

    // Only decrement optimistic ID if this was a new message (not a retry)
    if (failedMessage == null) {
      _optimisticMessageId--;
    }
  }

  void _sendDocumentMessage(
    File documentFile,
    String fileName,
    String extension, {
    MessageModel? failedMessage,
  }) async {
    await sendDocumentMessage(
      SendMediaMessageConfig(
        mediaFile: documentFile,
        conversationId: widget.group.conversationId,
        currentUserId: _currentUserId,
        optimisticMessageId: _optimisticMessageId,
        replyToMessage: _replyToMessageData,
        replyToMessageId: _replyToMessageData?.id,
        failedMessage: failedMessage,
        messageType: 'document',
        fileName: fileName,
        extension: extension,
        messages: _messages,
        optimisticMessageIds: _optimisticMessageIds,
        conversationMeta: _conversationMeta,
        messagesRepo: _messagesRepo,
        chatsServices: _chatsServices,
        websocketService: _websocketService,
        mounted: () => mounted,
        setState: setState,
        handleMediaUploadFailure: _handleMediaUploadFailure,
        animateNewMessage: _animateNewMessage,
        scrollToBottom: _scrollToBottom,
        cancelReply: _cancelReply,
        isReplying: _isReplying,
      ),
    );

    // Only decrement optimistic ID if this was a new message (not a retry)
    if (failedMessage == null) {
      _optimisticMessageId--;
    }
  }

  // Message action methods
  void _toggleMessageSelection(int messageId) {
    ChatHelpers.toggleMessageSelection(
      messageId: messageId,
      selectedMessages: _selectedMessages,
      setIsSelectionMode: (value) => _isSelectionMode = value,
      setState: setState,
    );
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
    ChatHelpers.enterSelectionMode(
      messageId: messageId,
      selectedMessages: _selectedMessages,
      setIsSelectionMode: (value) => _isSelectionMode = value,
      setState: setState,
    );
  }

  void _togglePinMessage(int messageId) async {
    await ChatHelpers.togglePinMessage(
      messageId: messageId,
      conversationId: widget.group.conversationId,
      getPinnedMessageId: () => _pinnedMessageId,
      setPinnedMessageId: (value) => _pinnedMessageId = value,
      currentUserId: _currentUserId,
      messagesRepo: _messagesRepo,
      websocketService: _websocketService,
      setState: setState,
    );
  }

  void _toggleStarMessage(int messageId) async {
    await ChatHelpers.toggleStarMessage(
      messageId: messageId,
      conversationId: widget.group.conversationId,
      starredMessages: _starredMessages,
      currentUserId: _currentUserId,
      messagesRepo: _messagesRepo,
      websocketService: _websocketService,
      setState: setState,
    );
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

  Future<void> _showForwardModal() async {
    await _loadAvailableConversations();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => ForwardMessageModal(
        messagesToForward: _messagesToForward,
        availableConversations: _availableConversations,
        isLoading: _isLoadingConversations,
        onForward: _handleForwardToConversations,
        currentConversationId: widget.group.conversationId,
      ),
    );
  }

  Future<void> _loadAvailableConversations() async {
    await loadAvailableConversations(
      LoadAvailableConversationsConfig(
        userService: _userService,
        currentConversationId: widget.group.conversationId,
        setIsLoading: (isLoading) {
          setState(() {
            _isLoadingConversations = isLoading;
          });
        },
        setAvailableConversations: (conversations) {
          setState(() {
            _availableConversations = conversations;
          });
        },
        mounted: mounted,
        showErrorDialog: _showErrorDialog,
        debugPrefix: 'group',
      ),
    );
  }

  Future<void> _handleForwardToConversations(
    List<int> selectedConversationIds,
  ) async {
    await handleForwardToConversations(
      HandleForwardToConversationsConfig(
        messagesToForward: _messagesToForward,
        selectedConversationIds: selectedConversationIds,
        websocketService: _websocketService,
        currentUserId: _currentUserId!,
        sourceConversationId: widget.group.conversationId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          setState(() {
            _messagesToForward.clear();
          });
        },
        showErrorDialog: _showErrorDialog,
        debugPrefix: 'group',
      ),
    );
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageData = null;
      _isReplying = false;
    });
  }

  void _forwardMessage(MessageModel message) async {
    await ChatHelpers.forwardMessage(
      messageId: message.id,
      messagesToForward: _messagesToForward,
      setState: setState,
      showForwardModal: _showForwardModal,
    );
  }

  void _deleteMessage(int messageId) async {
    await ChatHelpers.deleteMessage(
      messageId: messageId,
      conversationId: widget.group.conversationId,
      messages: _messages,
      chatsServices: _chatsServices,
      messagesRepo: _messagesRepo,
      setState: setState,
      isAdminOrStaff: _isAdminOrStaff,
    );
  }

  void _bulkStarMessages() async {
    await ChatHelpers.bulkStarMessages(
      conversationId: widget.group.conversationId,
      selectedMessages: _selectedMessages,
      starredMessages: _starredMessages,
      currentUserId: _currentUserId,
      messagesRepo: _messagesRepo,
      websocketService: _websocketService,
      setState: setState,
      exitSelectionMode: _exitSelectionMode,
    );
  }

  void _bulkForwardMessages() async {
    await ChatHelpers.bulkForwardMessages(
      selectedMessages: _selectedMessages,
      messagesToForward: _messagesToForward,
      setState: setState,
      exitSelectionMode: _exitSelectionMode,
      showForwardModal: _showForwardModal,
    );
  }

  Widget _buildMessageInput() {
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: _isReplying,
      replyToMessageData: _replyToMessageData,
      currentUserId: _currentUserId,
      onSendMessage: _sendMessage,
      onSendVoiceNote: _sendVoiceNote,
      onAttachmentTap: _showAttachmentModal,
      onTyping: _handleTyping,
      onCancelReply: _cancelReply,
      isCommunityGroup: widget.isCommunityGroup,
      communityGroupMetadata: widget.communityGroupMetadata,
    );
  }

  Widget _buildTypingIndicator() {
    return ChatHelpers.buildTypingIndicator(
      typingDotAnimations: _typingDotAnimations,
      isGroupChat: true,
    );
  }

  // Media preview methods
  void _openImagePreview(String imageUrl, String? caption) async {
    await openImagePreview(
      context: context,
      imageUrl: imageUrl,
      caption: caption,
      messages: _messages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
      checkExistingCache: false,
      debugPrefix: 'group message',
    );
  }

  void _openVideoPreview(
    String videoUrl,
    String? caption,
    String? fileName,
  ) async {
    await openVideoPreview(
      context: context,
      videoUrl: videoUrl,
      caption: caption,
      fileName: fileName,
      messages: _messages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
      onMessageUpdated: (updatedMessage) {
        final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
        if (index != -1 && mounted) {
          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      },
    );
  }

  void _openDocumentPreview(
    String documentUrl,
    String? fileName,
    String? caption,
    int? fileSize,
  ) {
    openDocumentPreview(
      context: context,
      documentUrl: documentUrl,
      fileName: fileName,
      caption: caption,
      fileSize: fileSize,
    );
  }

  // Voice recording methods
  Future<void> _checkAndRequestMicrophonePermission() async {
    await _voiceRecordingManager.checkAndRequestMicrophonePermission();
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
              child: VoiceRecordingModal(
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onCancelRecording: _cancelRecording,
                onSendRecording: _sendRecordedVoice,
                isRecording: _voiceRecordingManager.isRecording,
                recordingDuration: _voiceRecordingManager.recordingDuration,
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

  Future<void> _startRecording() async {
    await _voiceRecordingManager.startRecording();
  }

  Future<void> _stopRecording() async {
    await _voiceRecordingManager.stopRecording();
  }

  void _cancelRecording() async {
    await _voiceRecordingManager.cancelRecording();
  }

  Future<void> _sendRecordedVoice({MessageModel? failedMessage}) async {
    try {
      File? voiceFile;
      int? duration;

      if (failedMessage != null) {
        // Retry: Get file info from failed message
        final attachments = failedMessage.attachments;
        final localPath = attachments?['local_path'] as String?;
        duration = attachments?['duration'] as int?;

        if (localPath == null || !File(localPath).existsSync()) {
          _showErrorDialog(
            'Original recording not found. Please record again.',
          );
          return;
        }

        voiceFile = File(localPath);
      } else {
        // New send: Stop recording if still recording
        final recordingPath = await _voiceRecordingManager.stopIfRecording();

        if (recordingPath == null) {
          _showErrorDialog('No recording found. Please try again.');
          return;
        }

        voiceFile = File(recordingPath);
        if (!await voiceFile.exists()) {
          _showErrorDialog('Recording file not found. Please try again.');
          return;
        }

        final fileSize = await voiceFile.length();
        if (fileSize == 0) {
          _showErrorDialog('Recording is empty. Please try recording again.');
          return;
        }

        duration = _voiceRecordingManager.recordingDuration.inSeconds;
      }

      await sendRecordedVoice(
        SendMediaMessageConfig(
          mediaFile: voiceFile,
          conversationId: widget.group.conversationId,
          currentUserId: _currentUserId,
          optimisticMessageId: _optimisticMessageId,
          replyToMessage: _replyToMessageData,
          replyToMessageId: _replyToMessageData?.id,
          failedMessage: failedMessage,
          messageType: 'audio',
          duration: duration,
          messages: _messages,
          optimisticMessageIds: _optimisticMessageIds,
          conversationMeta: _conversationMeta,
          messagesRepo: _messagesRepo,
          chatsServices: _chatsServices,
          websocketService: _websocketService,
          mounted: () => mounted,
          setState: setState,
          handleMediaUploadFailure: _handleMediaUploadFailure,
          animateNewMessage: _animateNewMessage,
          scrollToBottom: _scrollToBottom,
          cancelReply: _cancelReply,
          isReplying: _isReplying,
          context: context,
          closeModal: failedMessage == null
              ? () => Navigator.of(context).pop()
              : null,
        ),
      );

      // Only decrement optimistic ID if this was a new message (not a retry)
      if (failedMessage == null) {
        _optimisticMessageId--;
      }
    } catch (e) {
      _showErrorDialog('Failed to send voice note. Please try again.');
    }
  }
}
