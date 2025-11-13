import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/conversation_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../api/chats.services.dart';
import '../../../api/user.service.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../services/message_storage_service.dart';
import '../../../repositories/messages_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../services/socket/websocket_message_handler.dart';
import '../../../utils/chat/chat_helpers.dart';
import '../../../utils/chat/sync_messages.utils.dart';
import '../../../utils/message_storage_helpers.dart';
import '../../../utils/animations.utils.dart';
import '../../../widgets/chat/message_action_sheet.dart';
import '../../../widgets/chat/date.widgets.dart';
import '../../../widgets/loading_dots_animation.dart';
import '../../../widgets/chat/scroll_to_bottom_button.dart';
import '../../../widgets/chat/attachment_action_sheet.dart';
import '../../../widgets/chat/messagewidget.dart';
import '../../../widgets/chat/forward_message_widget.dart';
import '../../../widgets/chat/voice_recording_widget.dart';
import '../../../widgets/chat/pinned_message.widget.dart';
import '../../../utils/chat/forward_message.utils.dart';
import '../../../utils/chat/attachments.utils.dart';
import '../../../utils/chat/preview_media.utils.dart';
import '../../../utils/chat/audio_playback.utils.dart';
import '../../../utils/chat/sendMediaMessage.utils.dart';
import '../../../utils/chat/chatActions.utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/user_status_service.dart';
import '../../../services/media_cache_service.dart';
import '../../../services/draft_message_service.dart';
import '../../../providers/draft_provider.dart';
import '../../../widgets/chat/inputcontainer.widget.dart';
import '../../../widgets/chat/media_messages.widget.dart';

class InnerChatPage extends ConsumerStatefulWidget {
  final ConversationModel conversation;

  const InnerChatPage({super.key, required this.conversation});

  @override
  ConsumerState<InnerChatPage> createState() => _InnerChatPageState();
}

class _InnerChatPageState extends ConsumerState<InnerChatPage>
    with TickerProviderStateMixin {
  final ChatsServices _chatsServices = ChatsServices();
  final UserService _userService = UserService();
  final MessagesRepository _messagesRepo = MessagesRepository();
  final UserRepository _userRepo = UserRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final WebSocketService _websocketService = WebSocketService();
  final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final ImagePicker _imagePicker = ImagePicker();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  final ConversationsRepository _conversationsRepo = ConversationsRepository();

  List<MessageModel> _messages = [];
  bool _isLoading = false; // Start false, will be set true only if no cache
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentPage = 1;
  String? _errorMessage;
  int? _currentUserId;
  bool _isInitialized = false;
  bool _hasCallAccess = false;
  ConversationMeta? _conversationMeta;
  bool _isLoadingFromCache = false;
  bool _hasCheckedCache = false; // Track if we've checked cache
  bool _isCheckingCache = true; // Show brief cache check state
  bool _isTyping = false;
  bool isloadingMediamessage = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);
  Map<int, int?> userLastReadMessageIds = {}; // userId -> lastReadMessageId

  // Scroll to bottom button state
  bool _isAtBottom = true;
  int _unreadCountWhileScrolled = 0;
  double _lastScrollPosition = 0.0;
  int _previousMessageCount = 0;

  // For optimistic message handling - using filtered streams per conversation
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _mediaSubscription;
  StreamSubscription<Map<String, dynamic>>? _deliveryReceiptSubscription;
  StreamSubscription<Map<String, dynamic>>? _readReceiptSubscription;
  StreamSubscription<Map<String, dynamic>>? _messagePinSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageStarSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageReplySubscription;
  StreamSubscription<Map<String, dynamic>>? _onlineStatusSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeleteSubscription;
  int _optimisticMessageId = -1; // Negative IDs for optimistic messages
  final Set<int> _optimisticMessageIds = {}; // Track optimistic messages
  bool _isDisposed = false; // Track if the page is being disposed

  // User info cache for sender names and profile pics
  final Map<int, Map<String, String?>> _userInfoCache = {};

  // Track if other users are active in the conversation
  final Map<int, bool> _activeUsers = {};
  List<int> _onlineUsers = [];

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

  // GlobalKey map for message widgets to enable precise scrolling
  final Map<int, GlobalKey> _messageKeys = {};

  // Sticky date separator state - using ValueNotifier to avoid setState during scroll
  final ValueNotifier<String?> _currentStickyDate = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<bool> _showStickyDate = ValueNotifier<bool>(false);

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
  final Set<int> _animatedMessages =
      {}; // Track which messages have been animated

  // Swipe animation controllers for reply gesture
  final Map<int, AnimationController> _swipeAnimationControllers = {};
  final Map<int, Animation<double>> _swipeAnimations = {};

  // Swipe gesture tracking variables
  Offset? _swipeStartPosition;
  double _swipeTotalDistance = 0.0;
  bool _isSwipeGesture = false;
  bool _isScrolling = false;
  static const double _minSwipeDistance =
      30.0; // Minimum distance to consider as swipe
  static const double _maxVerticalDeviation =
      40.0; // Max vertical movement allowed for horizontal swipe
  static const double _minSwipeVelocity =
      800.0; // Minimum velocity for swipe completion
  static const double _swipeThreshold =
      0.4; // Threshold for swipe completion (0.0 to 1.0)

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

    // Initialize typing animation
    _initializeTypingAnimation();

    _websocketService.connect(widget.conversation.conversationId);

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

    // Listen to text changes for draft saving
    _messageController.addListener(_onMessageTextChanged);
  }

  /// Load draft message when opening conversation
  Future<void> _loadDraft() async {
    // Load directly from service for immediate access
    final draftService = DraftMessageService();
    final draft = await draftService.getDraft(
      widget.conversation.conversationId,
    );
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      // Also update the provider state
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.conversation.conversationId, draft);
    }
  }

  /// Handle message text changes with debouncing for draft saving
  void _onMessageTextChanged() {
    // Cancel existing timer
    _draftSaveTimer?.cancel();

    // Create new timer to save draft after 500ms of no typing
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_isDisposed) {
        final draftNotifier = ref.read(draftMessagesProvider.notifier);
        final text = _messageController.text;
        draftNotifier.saveDraft(widget.conversation.conversationId, text);
      }
    });
  }

  void _initializeTypingAnimation() {
    final result = initializeTypingDotAnimation(this);
    _typingAnimationController = result.controller;
    _typingDotAnimations = result.dotAnimations;
  }

  /// Ultra-fast cache check that runs immediately
  void _quickCacheCheck() async {
    try {
      final conversationId = widget.conversation.conversationId;

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
      debugPrint('🚀 Quick cache check error: $e');
    }
  }

  /// Smart sync: Compare cached message count with backend and add only new messages
  /// NOTE: This should ONLY be called when:
  /// 1. User opens the conversation (to check for missed messages)
  /// 2. User pulls to refresh
  /// 3. App resumes from background (to sync missed messages)
  ///
  /// DO NOT call this after sending messages - the WebSocket echo is sufficient!
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

        // Process read status from members data
        final membersData =
            response['data']['data']['members'] as List<dynamic>? ?? [];
        // final backendMessagesWithReadStatus = _processReadStatusFromMembers(
        //   historyResponse.messages,
        //   membersData,
        // );

        final backendMessagesWithReadStatus = historyResponse.messages;

        final backendCount = backendMessagesWithReadStatus.length;

        if (backendCount > cachedCount) {
          // Backend has more messages - add only the new ones
          // final newMessagesCount = backendCount - cachedCount;
          final newMessages = backendMessagesWithReadStatus
              .skip(cachedCount)
              .toList();

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
              // Update userLastReadMessageIds from members data
              userLastReadMessageIds.addEntries(
                membersData.map((member) {
                  final userId = member['user_id'] as int;
                  final lastReadMessageId =
                      member['last_read_message_id'] as int;
                  return MapEntry(userId, lastReadMessageId);
                }),
              );

              _messages =
                  backendMessagesWithReadStatus; // Show all messages including new ones
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

          // Update userLastReadMessageIds even if no new messages
          if (mounted) {
            setState(() {
              userLastReadMessageIds.addEntries(
                membersData.map((member) {
                  final userId = member['user_id'] as int;
                  final lastReadMessageId =
                      member['last_read_message_id'] as int;
                  return MapEntry(userId, lastReadMessageId);
                }),
              );
            });
          }
        } else {
          // Replace cache with backend data
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _messagesRepo.saveMessages(
            conversationId: conversationId,
            messages: backendMessagesWithReadStatus,
            meta: _conversationMeta!,
          );

          if (mounted) {
            setState(() {
              // Update userLastReadMessageIds from members data
              userLastReadMessageIds.addEntries(
                membersData.map((member) {
                  final userId = member['user_id'] as int;
                  final lastReadMessageId =
                      member['last_read_message_id'] as int;
                  return MapEntry(userId, lastReadMessageId);
                }),
              );

              _messages = backendMessagesWithReadStatus;
              _conversationMeta = ConversationMeta.fromResponse(
                historyResponse,
              );
              _hasMoreMessages = historyResponse.hasNextPage;
            });
            _populateReplyMessageSenderNames();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in smart sync: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _initializeChat() async {
    // CRITICAL: Get user ID FIRST (must know who "I" am before displaying messages)
    await _getCurrentUserId();

    // Fetch call access (needed for UI button)
    await _fetchUserCallAccess();

    // Initialize user info cache
    _initializeUserCache();

    // NOW load and display messages (user ID is known, display will be correct)
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
            'conversation_id': widget.conversation.conversationId,
          })
          .catchError((e) {
            debugPrint('❌ Error sending active_in_conversation: $e');
          });
    });
  }

  /// Fetch user call access status - prioritize local DB for instant display
  Future<void> _fetchUserCallAccess() async {
    try {
      // PRIORITY 1: Check local DB first (INSTANT - 5ms)
      if (_currentUserId != null) {
        final localUser = await _userRepo.getUserById(_currentUserId!);
        if (localUser != null) {
          _hasCallAccess = localUser.callAccess;

          // Update UI immediately with cached value
          if (mounted) {
            setState(() {});
          }

          // PRIORITY 2: Update from server in background (silent sync)
          _syncCallAccessFromServer(localUser);
          return;
        }
      }
      await _syncCallAccessFromServer(null);
    } catch (e) {
      debugPrint('❌ Error fetching user call access: $e');
      _hasCallAccess = false; // Default to no access
    }
  }

  /// Sync call access from server and update local DB if changed
  Future<void> _syncCallAccessFromServer(dynamic existingUser) async {
    try {
      final response = await _userService.getUser().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          return {'success': false, 'message': 'Timeout'};
        },
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        final serverCallAccess = userData['call_access'] == true;

        // Check if value changed from local DB
        final hasChanged =
            existingUser != null && existingUser.callAccess != serverCallAccess;

        if (hasChanged || existingUser == null) {
          _hasCallAccess = serverCallAccess;

          // Update local DB with new value
          if (_currentUserId != null) {
            final userModel = UserModel(
              id: _currentUserId!,
              name: userData['name'] ?? '',
              phone: userData['phone'] ?? '',
              role: userData['role'] ?? '',
              profilePic: userData['profile_pic'],
              callAccess: serverCallAccess,
            );
            await _userRepo.insertOrUpdateUser(userModel);
          }

          // Update UI if value changed
          if (mounted && hasChanged) {
            setState(() {});
          }
        } else {
          debugPrint('✓ Call access unchanged from server');
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing call access from server: $e');
      // Keep existing value, don't update
    }
  }

  /// Quick cache check and load for instant display
  Future<void> _tryLoadFromCacheFirst() async {
    final conversationId = widget.conversation.conversationId;

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
        getErrorLogMessage: () => 'Error in quick cache check',
      ),
    );
  }

  Future<void> _getCurrentUserId() async {
    try {
      // FAST PATH: Try to get from local DB first (instant, offline-friendly)
      final conversationId = widget.conversation.conversationId;
      final cachedMessages = await _messagesRepo.getMessagesByConversation(
        conversationId,
        limit: 20, // Check more messages to ensure we find one from us
      );

      // Find a message that's from us (senderId != conversation.userId)
      if (cachedMessages.isNotEmpty) {
        // In a DM, one user is conversation.userId (the other person)
        // The other user is us (current user)
        final otherUserId = widget.conversation.userId;

        for (final msg in cachedMessages) {
          if (msg.senderId != otherUserId) {
            _currentUserId = msg.senderId;
            return; // Found it! Return immediately
          }
        }

        // If all messages are from the other person, we haven't sent any yet
        // In that case, we need to fetch from API
      }

      // SLOW PATH: Try API with timeout (only if no cache found us)
      final response = await _userService.getUser().timeout(
        Duration(seconds: 2), // Reduced to 2 seconds
        onTimeout: () {
          return {'success': false, 'message': 'Timeout'};
        },
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        _currentUserId = _parseToInt(userData['id']);
      } else {
        debugPrint('⚠️ Could not get current user ID from API');
        // Will be determined when user sends first message
      }
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      // Continue without user ID - will be inferred when user sends a message
    }
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Initialize user info cache with known conversation participant
  void _initializeUserCache() {
    // Cache the other participant's info from conversation
    if (widget.conversation.userId != _currentUserId) {
      _userInfoCache[widget.conversation.userId] = {
        'name': widget.conversation.userName,
        'profile_pic': widget.conversation.userProfilePic,
      };
    }

    // Cache current user info
    if (_currentUserId != null) {
      _userInfoCache[_currentUserId!] = {
        'name': 'You',
        'profile_pic':
            null, // We don't have current user's profile pic readily available
      };
    }
  }

  /// Load pinned message from storage or conversation metadata
  Future<void> _loadPinnedMessageFromStorage() async {
    final conversationId = widget.conversation.conversationId;

    // First check if conversation metadata has pinned message
    if (widget.conversation.metadata?.pinnedMessage != null) {
      final pinnedMessageId =
          widget.conversation.metadata!.pinnedMessage!.messageId;
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
    final conversationId = widget.conversation.conversationId;
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
        setState(() {
          _starredMessages.removeAll(invalidStarredMessages);
        });

        // Update storage with cleaned up starred messages
        _messagesRepo.saveStarredMessages(
          conversationId: widget.conversation.conversationId,
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

        // Validate each reply message
        for (final message in replyMessagesInUI) {
          if (message.replyToMessage != null) {
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
                '🔗 Reply message ${message.id} references existing message ${message.replyToMessageId}',
              );
            } else {
              debugPrint(
                '⚠️ Reply message ${message.id} references missing message ${message.replyToMessageId}',
              );
            }
          }
        }

        // Validate storage
        await _messagesRepo.validateReplyMessageStorage(
          widget.conversation.conversationId,
        );
      } catch (e) {
        debugPrint('❌ Error validating reply messages: $e');
      }
    });
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
        final senderInfo = _getUserInfo(senderId);
        final senderName = senderInfo['name'] ?? 'Unknown User';
        final senderProfilePic = senderInfo['profile_pic'];

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
      } else {
        updatedMessages.add(message);
      }
    }

    if (hasUpdates && mounted) {
      // Track new messages if scrolled up
      if (!_isAtBottom && updatedMessages.length > _previousMessageCount) {
        final newMessageCount = updatedMessages.length - _previousMessageCount;
        setState(() {
          _unreadCountWhileScrolled += newMessageCount;
        });
      }
      _previousMessageCount = updatedMessages.length;

      setState(() {
        _messages = updatedMessages;
      });
    }
  }

  /// Get user info (name and profile pic) by user ID
  Map<String, String?> _getUserInfo(int userId) {
    // Check cache first
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }

    // If not in cache, check if it's the conversation participant
    if (userId == widget.conversation.userId) {
      final userInfo = {
        'name': widget.conversation.userName,
        'profile_pic': widget.conversation.userProfilePic,
      };
      _userInfoCache[userId] = userInfo;
      return userInfo;
    }

    // If it's the current user
    if (userId == _currentUserId) {
      final userInfo = {'name': 'You', 'profile_pic': null};
      _userInfoCache[userId] = userInfo;
      return userInfo;
    }

    // Fallback for unknown users
    debugPrint('⚠️ Unknown user ID: $userId, using fallback');
    final fallbackInfo = {'name': 'User $userId', 'profile_pic': null};
    _userInfoCache[userId] = fallbackInfo;
    return fallbackInfo;
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

      // Only update if the date has changed - using ValueNotifier to avoid setState
      if (_currentStickyDate.value != currentDateString) {
        _currentStickyDate.value = currentDateString;
        _showStickyDate.value = true;
      }
    }
  }

  @override
  void deactivate() {
    // Send inactive message when user navigates away from the page
    _websocketService
        .sendMessage({
          'type': 'inactive_in_conversation',
          'conversation_id': widget.conversation.conversationId,
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
    if (_isDisposed) return; // Prevent multiple dispose calls
    _isDisposed = true;

    _scrollController.dispose();
    _messageController.dispose();
    _isOtherTypingNotifier.dispose();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _mediaSubscription?.cancel();
    _deliveryReceiptSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _messagePinSubscription?.cancel();
    _messageStarSubscription?.cancel();
    _messageReplySubscription?.cancel();
    _onlineStatusSubscription?.cancel();
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
        widget.conversation.conversationId,
        _messageController.text,
      );
    }

    // Remove listener
    _messageController.removeListener(_onMessageTextChanged);
    _currentStickyDate.dispose();
    _showStickyDate.dispose();

    _conversationsRepo.updateUnreadCount(widget.conversation.conversationId, 0);
    // Send inactive message when actually disposing (leaving the page)
    _websocketService
        .sendMessage({
          'type': 'inactive_in_conversation',
          'conversation_id': widget.conversation.conversationId,
        })
        .catchError((e) {
          debugPrint('❌ Error sending inactive_in_conversation: $e');
        });

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

    // Clear message keys to prevent memory leaks
    _messageKeys.clear();

    super.dispose();
  }

  void _onScroll() {
    // Ensure we have a valid scroll position and the widget is still mounted
    if (!mounted || !_scrollController.hasClients) return;

    // Set scrolling flag to disable swipe gestures during scroll
    _isScrolling = true;

    // Reset scrolling flag after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _isScrolling = false;
      }
    });

    // Debounce sticky date separator updates to reduce frequency (increased to 100ms)
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
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

    if (distanceFromTop <= 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    final conversationId = widget.conversation.conversationId;

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
        onAfterLoadFromCache: (messages) {
          ChatHelpers.debugMessageDates(messages);
        },
        processMembersData: (response) {
          final membersData =
              response['data']['data']['members'] as List<dynamic>? ?? [];
          userLastReadMessageIds.addEntries(
            membersData.map((member) {
              final userId = member['user_id'] as int;
              final lastReadMessageId = member['last_read_message_id'] as int;
              return MapEntry(userId, lastReadMessageId);
            }),
          );
        },
        getErrorMessageText: () => 'Failed to load messages',
        getNoCacheMessage: () => 'ℹ️ No cached messages found in local DB',
      ),
    );
  }

  Future<void> _loadMoreMessages() async {
    final conversationId = widget.conversation.conversationId;

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
        processMembersData: (response) {
          final membersData =
              response['data']['data']['members'] as List<dynamic>? ?? [];
          userLastReadMessageIds.addEntries(
            membersData.map((member) {
              final userId = member['user_id'] as int;
              final lastReadMessageId = member['last_read_message_id'] as int;
              return MapEntry(userId, lastReadMessageId);
            }),
          );
        },
        onProcessingError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to process older messages. Please try again.',
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red[600],
            ),
          );
        },
        onLoadError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load older messages. Please try again.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red[600],
            ),
          );
        },
      ),
    );
  }

  /// Set up WebSocket message listener for real-time messages
  void _setupWebSocketListener() {
    final conversationId = widget.conversation.conversationId;

    // Listen to messages filtered for this conversation
    _messageSubscription = _messageHandler
        .messagesForConversation(conversationId)
        .listen(
          (message) {
            _handleIncomingMessage(message);
          },
          onError: (error) {
            debugPrint('❌ Message stream error: $error');
          },
        );

    // Listen to typing events for this conversation
    _typingSubscription = _messageHandler
        .typingForConversation(conversationId)
        .listen(
          (message) => _reciveTyping(message),
          onError: (error) {
            debugPrint('❌ Typing stream error: $error');
          },
        );

    // Listen to media messages for this conversation
    _mediaSubscription = _messageHandler
        .mediaForConversation(conversationId)
        .listen(
          (message) => _handleIncomingMediaMessages(message),
          onError: (error) {
            debugPrint('❌ Media stream error: $error');
          },
        );

    // Listen to delivery receipts for this conversation
    _deliveryReceiptSubscription = _messageHandler
        .deliveryReceiptsForConversation(conversationId)
        .listen(
          (message) => _handleMessageDeliveryReceipt(message),
          onError: (error) {
            debugPrint('❌ Delivery receipt stream error: $error');
          },
        );

    // Listen to read receipts for this conversation
    _readReceiptSubscription = _messageHandler
        .readReceiptsForConversation(conversationId)
        .listen(
          (message) => _handleReadReceipt(message),
          onError: (error) {
            debugPrint('❌ Read receipt stream error: $error');
          },
        );

    // Listen to message pins for this conversation
    _messagePinSubscription = _messageHandler
        .messagePinsForConversation(conversationId)
        .listen(
          (message) => _handleMessagePin(message),
          onError: (error) {
            debugPrint('❌ Message pin stream error: $error');
          },
        );

    // Listen to message stars for this conversation
    _messageStarSubscription = _messageHandler
        .messageStarsForConversation(conversationId)
        .listen(
          (message) => _handleMessageStar(message),
          onError: (error) {
            debugPrint('❌ Message star stream error: $error');
          },
        );

    // Listen to message replies for this conversation
    _messageReplySubscription = _messageHandler
        .messageRepliesForConversation(conversationId)
        .listen(
          (message) => _handleMessageReply(message),
          onError: (error) {
            debugPrint('❌ Message reply stream error: $error');
          },
        );

    // Listen to message delete events for this conversation
    _messageDeleteSubscription = _messageHandler
        .messageDeletesForConversation(conversationId)
        .listen(
          (message) => _handleMessageDelete(message),
          onError: (error) {
            debugPrint('❌ Message delete stream error: $error');
          },
        );

    // Listen to online status for this conversation
    _onlineStatusSubscription = _messageHandler
        .onlineStatusForConversation(conversationId)
        .listen(
          (message) => _handleOnlineStatus(message),
          onError: (error) {
            debugPrint('❌ Online status stream error: $error');
          },
        );
  }

  void _handleMessageReply(Map<String, dynamic> message) async {
    try {
      debugPrint('📨 Received message_reply: $message');

      final data = message['data'] as Map<String, dynamic>? ?? {};
      final messageBody = data['new_message'] as String? ?? '';
      final newMessageId = data['new_message_id'];
      final userId = data['user_id'];
      final conversationId = message['conversation_id'];
      final messageIds = message['message_ids'] as List<dynamic>? ?? [];
      final timestamp = message['timestamp'] as String?;
      final optimisticId = data['optimistic_id'];

      // Skip if this is not for our conversation
      if (conversationId != widget.conversation.conversationId) {
        return;
      }

      // Check if this is our own optimistic message being confirmed
      if (_optimisticMessageIds.contains(optimisticId)) {
        debugPrint('🔄 Replacing optimistic reply message with server message');
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

      // Get sender info
      final senderInfo = _getUserInfo(userId);
      final senderName = senderInfo['name'] ?? 'Unknown User';
      final senderProfilePic = senderInfo['profile_pic'];

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
            '⚠️ Original message not found in local messages: $originalMessageId',
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
          // Sort messages by ID to maintain proper order
          // _messages.sort((a, b) => a.id.toString().compareTo(b.id.toString()));
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
      debugPrint('❌ Error processing message_reply: $e');
    }
  }

  /// Handle incoming message pin from WebSocket
  void _handleMessagePin(Map<String, dynamic> message) async {
    await handleMessagePin(
      HandleMessagePinConfig(
        message: message,
        conversationId: widget.conversation.conversationId,
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
        conversationId: widget.conversation.conversationId,
        messagesRepo: _messagesRepo,
      ),
    );
  }

  /// Build message status ticks (single/double) based on delivery and read status
  Widget _buildMessageStatusTicks(MessageModel message) {
    bool hasActiveUsers = _onlineUsers
        .where((userId) => userId != _currentUserId)
        .isNotEmpty;
    // Get the last read message id of the other user (not the current user)
    int userReadMsgId = -1;
    if (userLastReadMessageIds.isNotEmpty) {
      try {
        // Find the first user id that is not the current user
        final otherUserId = userLastReadMessageIds.keys.firstWhere(
          (id) => id != _currentUserId,
        );
        userReadMsgId = userLastReadMessageIds[otherUserId] ?? -1;
      } catch (e) {
        // If no other user found or any error occurs, keep userReadMsgId as -1
        userReadMsgId = -1;
      }
    }

    // if ((message.id <= userReadMsgId || hasActiveUsers) && message.id > 0) {
    if (((message.id <= userReadMsgId || hasActiveUsers) && message.id > 0) &&
        userReadMsgId > 0) {
      // Message is already marked as read - always show blue tick
      return Icon(Icons.done_all, size: 16, color: Colors.blue);
    } else if (hasActiveUsers) {
      // User is active - show blue tick for delivered messages
      if (message.isDelivered) {
        // Double blue tick - user is active and message is delivered
        return Icon(Icons.done_all, size: 16, color: Colors.blue);
      } else {
        // Single grey tick - message is sent but not delivered
        return Icon(Icons.done, size: 16, color: Colors.white70);
      }
    } else {
      // No users active - show grey tick for delivered messages
      if (message.isDelivered) {
        // Double grey tick - message is delivered but no users active
        return Icon(Icons.done_all, size: 16, color: Colors.white70);
      } else {
        // Single grey tick - message is sent but not delivered
        return Icon(Icons.done, size: 16, color: Colors.white70);
      }
    }
  }

  /// Handle message delivery receipt from WebSocket
  void _handleMessageDeliveryReceipt(Map<String, dynamic> messageData) async {
    try {
      debugPrint('📨 Received message_delivery_receipt: $messageData');

      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final messageId = data['message_id'];
      final optimisticId = data['optimistic_id'];
      final deliveredCount = data['delivered_count'] ?? 0;
      final readCount = data['read_count'] ?? 0;
      final readBy = data['read_by'] as List<dynamic>? ?? [];

      if (messageId == null && optimisticId == null) return;

      // Find the message in our list and update its status
      // Check both message_id and optimistic_id
      int messageIndex = -1;

      if (messageId != null) {
        messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
      }

      // If not found by message_id, try optimistic_id
      if (messageIndex == -1 && optimisticId != null) {
        messageIndex = _messages.indexWhere((msg) {
          // Check if optimistic_id in metadata matches
          final msgOptimisticId = msg.metadata?['optimistic_id'];
          if (msgOptimisticId != null) {
            return msgOptimisticId.toString() == optimisticId.toString();
          }
          // Also check if message id matches optimistic_id (for cases where optimistic_id is the same as message_id)
          return msg.id.toString() == optimisticId.toString();
        });
      }
      if (messageIndex != -1) {
        final currentMessage = _messages[messageIndex];
        final actualMessageId = currentMessage.id;

        // Update delivery and read status
        final isDelivered = deliveredCount > 0;

        // Message is read ONLY if:
        // 1. read_count > 0 (server says it's read), OR
        // 2. read_by array contains any user IDs (real read receipts from server)
        final isRead = readCount > 0 || readBy.isNotEmpty;

        if (mounted) {
          setState(() {
            // Update the current message
            _messages[messageIndex] = currentMessage.copyWith(
              isDelivered: isDelivered,
              isRead: isRead,
            );

            // Update all other messages that the current user sent to also have read receipts
            for (int i = 0; i < _messages.length; i++) {
              if (i != messageIndex &&
                  _messages[i].senderId == _currentUserId) {
                final originalMessage = _messages[i];
                _messages[i] = originalMessage.copyWith(
                  isDelivered: isDelivered || originalMessage.isDelivered,
                  // isRead: isRead || originalMessage.isRead,
                );
              }
            }

            // Update userLastReadMessageIds for all users using readBy and unreadBy
            if (readBy.isNotEmpty) {
              for (final userId in readBy) {
                if (userId != null && messageId != null) {
                  userLastReadMessageIds[userId] = messageId;
                }
              }
            }
          });
        }

        // Update in storage for all messages that the current user sent (batch update)
        if (_currentUserId != null && isDelivered) {
          await _messagesRepo.updateAllMessagesStatus(
            conversationId: widget.conversation.conversationId,
            senderId: _currentUserId!,
            isDelivered: isDelivered,
          );
        }
      } else {
        debugPrint(
          '⚠️ Message not found for delivery receipt - messageId: $messageId, optimisticId: $optimisticId',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling delivery receipt: $e');
    }
  }

  /// Handle read receipt from WebSocket (for active/inactive conversation status)
  void _handleReadReceipt(Map<String, dynamic> messageData) async {
    try {
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final userId = data['user_id'];
      final readAll = data['read_all'] ?? false;
      final userActive = data['user_active'] ?? false;
      final lastReadMessageId = data['message_id'];
      // Skip if this is our own read receipt
      if (_currentUserId != null && userId == _currentUserId) {
        return;
      }

      // Update the active user state
      _activeUsers[userId] = userActive;
      if (mounted) {
        setState(() {
          // Update userLastReadMessageIds when we receive a read receipt
          if (lastReadMessageId != null && userId != null) {
            userLastReadMessageIds[userId] = lastReadMessageId;
          }

          // If user became active, mark delivered messages as read
          if (userActive && readAll) {
            for (int i = 0; i < _messages.length; i++) {
              final message = _messages[i];

              // Only update messages sent by the current user
              if (message.senderId == _currentUserId && message.isDelivered
              // && !message.isRead
              ) {
                _messages[i] = message.copyWith(isRead: true);
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling read receipt: $e');
    }
  }

  void _handleOnlineStatus(Map<String, dynamic> messageData) async {
    try {
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final onlineInConversation = data['online_in_conversation'];

      // add to active users map if not present and update if present
      for (final userId in onlineInConversation) {
        _activeUsers[userId] = true;
      }

      if (mounted) {
        setState(() {
          _onlineUsers = (onlineInConversation as List)
              .map((e) => _parseToInt(e))
              .toList();

          // Update userReadMsgId for online users to the last message
          // This ensures that when a user comes online, they're considered to have seen all current messages
          if (_messages.isNotEmpty) {
            final lastMessageId = _messages.last.id;
            for (final userId in _onlineUsers) {
              // Only update for other users, not the current user
              if (userId != _currentUserId) {
                userLastReadMessageIds[userId] = lastMessageId;
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling online status: $e');
    }
  }

  /// Handle incoming message from WebSocket
  void _handleIncomingMessage(Map<String, dynamic> messageData) async {
    try {
      // Extract message data from WebSocket payload
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final messageBody = data['body'] as String? ?? '';
      final senderId = _parseToInt(data['sender_id'] ?? data['senderId']);
      final messageId = data['id'] ?? data['messageId'];

      final optimisticId = data['optimistic_id'] ?? data['optimisticId'];

      // Get sender info from cache/lookup
      final senderInfo = _getUserInfo(senderId);
      final senderName = senderInfo['name'] ?? 'Unknown User';
      final senderProfilePic = senderInfo['profile_pic'];

      // Skip if this is our own optimistic message being echoed back
      if (_optimisticMessageIds.contains(optimisticId)) {
        debugPrint('🔄 Replacing optimistic message with server message');
        _replaceOptimisticMessage(optimisticId, messageData);
        return;
      }

      _websocketService.sendMessage({
        'type': 'read_receipt',
        'message_ids': [messageId],
        'conversation_id': widget.conversation.conversationId,
      });

      // If this is our own message (sender), update the optimistic message in local storage
      if (_currentUserId != null && senderId == _currentUserId) {
        await _updateOptimisticMessageInStorage(
          optimisticId,
          messageId,
          messageData,
        );
        return;
      }

      // Handle reply message data
      MessageModel? replyToMessage;
      int? replyToMessageId;

      // Check for reply data in metadata first (server format)
      final metadata = data['metadata'] as Map<String, dynamic>?;
      if (metadata != null && metadata['reply_to'] != null) {
        final replyToData = metadata['reply_to'] as Map<String, dynamic>;
        replyToMessageId = _parseToInt(replyToData['message_id']);

        // Create reply message from metadata
        replyToMessage = MessageModel(
          id: replyToMessageId,
          body: replyToData['body'] ?? '',
          type: 'text',
          senderId: _parseToInt(replyToData['sender_id']),
          conversationId: widget.conversation.conversationId,
          createdAt: replyToData['created_at'] ?? '',
          deleted: false,
          senderName:
              _getUserInfo(_parseToInt(replyToData['sender_id']))['name'] ??
              'Unknown User',
          senderProfilePic: _getUserInfo(
            _parseToInt(replyToData['sender_id']),
          )['profile_pic'],
        );
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
            '⚠️ Reply message not found in local messages: $replyToMessageId',
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
        conversationId: widget.conversation.conversationId,
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
        });
        // Update sticky date separator for new messages - using ValueNotifier
        _currentStickyDate.value = ChatHelpers.getMessageDateString(
          newMessage.createdAt,
        );
        _showStickyDate.value = true;

        _animateNewMessage(newMessage.id);
        if (!_isAtBottom) {
          _trackNewMessage();
        }
        // _scrollToBottom();
      }

      // Store message asynchronously
      _storeMessageAsync(newMessage);
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  /// Update optimistic message ID when server confirms it
  ///
  /// OPTIMIZED APPROACH (Like Telegram/WhatsApp):
  /// 1. User sends message → creates with temp ID (e.g., -1)
  /// 2. Server processes and echoes back with real ID + optimistic_id
  /// 3. We simply update the ID field (no need to rebuild entire message)
  /// 4. This eliminates unnecessary DB calls (delete + re-insert → simple update)
  ///
  /// Previously: Delete message → Insert new message (2 DB operations)
  /// Now: Just update ID field (1 DB operation, much faster)
  Future<void> _updateOptimisticMessageInStorage(
    int? optimisticId,
    int? serverId,
    Map<String, dynamic> messageData,
  ) async {
    if (optimisticId == null || serverId == null) return;

    try {
      // Find the optimistic message in UI
      final uiMessageIndex = _messages.indexWhere(
        (msg) => msg.id == optimisticId,
      );

      if (uiMessageIndex == -1) {
        debugPrint('⚠️ Optimistic message $optimisticId not found in UI');
        return;
      }

      final currentMessage = _messages[uiMessageIndex];

      // Simply update the ID - create new message with same data but new ID
      final updatedMessage = MessageModel(
        id: serverId, // New server ID
        body: currentMessage.body,
        type: currentMessage.type,
        senderId: currentMessage.senderId,
        conversationId: currentMessage.conversationId,
        createdAt: currentMessage.createdAt,
        editedAt: currentMessage.editedAt,
        metadata: currentMessage.metadata,
        attachments: currentMessage.attachments,
        deleted: currentMessage.deleted,
        senderName: currentMessage.senderName,
        senderProfilePic: currentMessage.senderProfilePic,
        replyToMessage: currentMessage.replyToMessage,
        replyToMessageId: currentMessage.replyToMessageId,
        isDelivered: currentMessage.isDelivered,
        localMediaPath: currentMessage.localMediaPath,
      );

      if (mounted) {
        setState(() {
          _messages[uiMessageIndex] = updatedMessage;
        });

        debugPrint(
          '✅ Updated message ID from $optimisticId to $serverId in UI',
        );
      }

      // Update in local storage asynchronously (non-blocking)
      _messagesRepo.updateMessageId(optimisticId, serverId).catchError((e) {
        debugPrint('❌ Error updating message ID in storage: $e');
      });
    } catch (e) {
      debugPrint('❌ Error updating optimistic message: $e');
    }
  }

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
          if (optimisticMessage.type == 'video_loading') {
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
                  conversationId: widget.conversation.conversationId,
                  newMessage: confirmedMessage,
                  updatedMeta: _conversationMeta!,
                  insertAtBeginning: false,
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
            '✅ Replaced optimistic dm reply message with server-confirmed message',
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
        'conversation_id': widget.conversation.conversationId,
      });
    }
  }

  void _reciveTyping(Map<String, dynamic> message) {
    final isTyping = message['data']['is_typing'] as bool;

    // Cancel any existing timeout
    _typingTimeout?.cancel();

    // Update the ValueNotifier directly without setState
    _isOtherTypingNotifier.value = isTyping;

    // Control the typing animation
    if (isTyping) {
      _typingAnimationController.repeat(reverse: true);

      // Set a safety timeout to hide typing indicator after 2 seconds
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

  // handle incoming media messages

  /// Handle incoming media messages from WebSocket
  void _handleIncomingMediaMessages(Map<String, dynamic> messageData) async {
    try {
      // Extract message data from WebSocket payload
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final senderId = _parseToInt(data['user_id'] ?? data['user_id']);
      final messageId =
          data['id'] ?? data['messageId'] ?? data['media_message_id'];
      final optimisticId = data['optimistic_id'] ?? data['optimisticId'];

      final senderInfo = _getUserInfo(senderId);
      final senderName = senderInfo['name'] ?? 'Unknown User';
      final senderProfilePic = senderInfo['profile_pic'];

      // Skip if this is our own optimistic message being echoed back
      if (_optimisticMessageIds.contains(optimisticId)) {
        debugPrint('🔄 Replacing optimistic media message with server message');
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

      _websocketService.sendMessage({
        'type': 'read_receipt',
        'message_ids': [messageId],
        'conversation_id': widget.conversation.conversationId,
      });

      // Get sender info from cache/lookup

      // Handle reply message data for media messages
      MessageModel? replyToMessage;
      int? replyToMessageId;
      if (data['reply_to_message'] != null) {
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
            '⚠️ Reply message not found in local messages: $replyToMessageId',
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
            conversationId: widget.conversation.conversationId,
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
            conversationId: widget.conversation.conversationId,
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
            conversationId: widget.conversation.conversationId,
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
            conversationId: widget.conversation.conversationId,
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
            conversationId: widget.conversation.conversationId,
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
        });

        _animateNewMessage(newMediaMessage.id);
        if (!_isAtBottom) {
          _trackNewMessage();
        }
      }

      // Store message asynchronously in local storage
      _storeMessageAsync(newMediaMessage);

      debugPrint('💾 Incoming $mediaType message stored locally and displayed');
    } catch (e) {
      debugPrint('❌ Error processing incoming media message: $e');
    }
  }

  /// Send message with immediate display (optimistic UI)
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
    await draftNotifier.removeDraft(widget.conversation.conversationId);

    // Create optimistic message for immediate display with current UTC time
    final nowUTC = DateTime.now().toUtc();
    final optimisticMessage = MessageModel(
      id: _optimisticMessageId, // Use negative ID for optimistic messages
      body: messageText,
      type: 'text',
      senderId: _currentUserId ?? 0,
      conversationId: widget.conversation.conversationId,
      createdAt: nowUTC
          .toIso8601String(), // Store as UTC, convert to IST when displaying
      deleted: false,
      senderName: 'You', // Current user name
      senderProfilePic: null,
      replyToMessage: replyMessage,
      replyToMessageId: replyMessageId,
      metadata: {
        'optimistic_id': _optimisticMessageId,
      }, // Store optimistic_id in metadata
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);
    // Add message to UI immediately with animation
    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
      });

      _animateNewMessage(optimisticMessage.id);
      _scrollToBottom();
    }

    // Store message immediately in cache (optimistic storage)
    _storeMessageAsync(optimisticMessage);

    try {
      // Check if this is a reply message
      if (replyMessageId != null) {
        // Send reply message via WebSocket
        await _websocketService.sendMessage({
          'type': 'message_reply',
          'data': {
            'new_message': messageText,
            'optimistic_id': _optimisticMessageId,
          },
          'conversation_id': widget.conversation.conversationId,
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
          'conversation_id': widget.conversation.conversationId,
        });
      }
      _optimisticMessageId--;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');

      // Handle send failure - mark message as failed
      _handleMessageSendFailure(optimisticMessage.id, e.toString());
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
          content: Text('Failed to send message, please check your internet!'),
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

  /// Retry sending a failed message
  void _retryMessage(int messageId) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      final message = _messages[index];

      if (!_websocketService.isConnected) {
        _websocketService.connect();
      }
      // Re-send the message
      _websocketService
          .sendMessage({
            'type': 'message',
            'data': {'type': message.type, 'body': message.body},
            'conversation_id': widget.conversation.conversationId,
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
            conversationId: widget.conversation.conversationId,
            newMessage: message,
            updatedMeta: _conversationMeta!.copyWith(
              totalCount: _conversationMeta!.totalCount + 1,
            ),
            insertAtBeginning: false, // Add new messages at the end
          );

          // Validate reply message storage periodically
          if (message.replyToMessage != null) {
            await _messagesRepo.validateReplyMessageStorage(
              widget.conversation.conversationId,
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Error storing message asynchronously: $e');
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

    _lastScrollPosition = scrollPosition;
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

  /// Scroll to a specific message
  Future<void> _scrollToMessage(int messageId, {int retryCount = 0}) async {
    // Prevent infinite loops
    const maxRetries = 3;
    if (retryCount >= maxRetries) {
      debugPrint('❌ Max retry attempts reached for message $messageId');
      return;
    }
    // Check if the message exists in the current loaded messages
    final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);

    if (messageIndex == -1) {
      // Message not loaded yet - we need to load more messages
      // Keep loading until we find the message or run out of messages
      bool messageFound = false;
      int attempts = 0;
      const maxAttempts = 20; // Prevent infinite loops

      while (!messageFound && _hasMoreMessages && attempts < maxAttempts) {
        // Load more messages
        await _loadMoreMessages();

        // Check if we found the message
        messageFound = _messages.any((msg) => msg.id == messageId);
        attempts++;

        // Small delay to allow UI to update
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!messageFound) {
        // Show a user-friendly message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message not found'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Update messageIndex after loading
      final updatedIndex = _messages.indexWhere((msg) => msg.id == messageId);
      if (updatedIndex == -1) return;
    }

    // Now the message should be in our list
    if (!mounted) return;

    // Ensure we have a key for this message
    if (!_messageKeys.containsKey(messageId)) {
      _messageKeys[messageId] = GlobalKey();
    }

    // PHASE 1: Scroll approximately to the message area so it gets built
    final updatedMessageIndex = _messages.indexWhere(
      (msg) => msg.id == messageId,
    );
    if (updatedMessageIndex != -1 && _scrollController.hasClients) {
      // Calculate approximate position (reverse list)
      final approximatePosition =
          (_messages.length - 1 - updatedMessageIndex) * 100.0;

      // Only scroll if the message is not near the current viewport
      final currentPosition = _scrollController.position.pixels;
      final viewportHeight = _scrollController.position.viewportDimension;

      // If message is likely off-screen, scroll approximately to it first
      if ((approximatePosition - currentPosition).abs() > viewportHeight / 2) {
        try {
          await _scrollController.animateTo(
            approximatePosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );

          // Wait for widgets to build
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('⚠️ Error in approximate scroll: $e');
        }
      }
    }

    // PHASE 2: Use GlobalKey for precise scrolling
    final messageKey = _messageKeys[messageId];
    if (messageKey?.currentContext != null) {
      try {
        // Use Scrollable.ensureVisible for precise scrolling
        await Scrollable.ensureVisible(
          messageKey!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.5, // Center the message in the viewport
        );

        // Highlight the message after scrolling
        if (mounted) {
          setState(() {
            _highlightedMessageId = messageId;
          });

          // Cancel any existing timer
          _highlightTimer?.cancel();

          // Remove highlight after 2 seconds
          _highlightTimer = Timer(const Duration(milliseconds: 2000), () {
            if (mounted) {
              setState(() {
                _highlightedMessageId = null;
              });
            }
          });
        }
      } catch (e) {
        debugPrint('❌ Error in precise scroll: $e');
      }
    } else {
      // Only retry if we haven't exceeded max retries
      if (retryCount < maxRetries - 1 && mounted) {
        // Force a rebuild and wait a bit longer
        setState(() {});

        // Try again after a longer delay
        await Future.delayed(const Duration(milliseconds: 300));
        _scrollToMessage(messageId, retryCount: retryCount + 1);
      } else {
        // Still highlight the message even if we can't scroll precisely
        if (mounted) {
          setState(() {
            _highlightedMessageId = messageId;
          });

          _highlightTimer?.cancel();
          _highlightTimer = Timer(const Duration(milliseconds: 2000), () {
            if (mounted) {
              setState(() {
                _highlightedMessageId = null;
              });
            }
          });
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      //  resizeToAvoidBottomInset: false,
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
                    backgroundColor: Colors.white,
                    backgroundImage: widget.conversation.userProfilePic != null
                        ? CachedNetworkImageProvider(
                            widget.conversation.userProfilePic!,
                          )
                        : null,
                    child: widget.conversation.userProfilePic == null
                        ? Text(
                            widget.conversation.userName.isNotEmpty
                                ? widget.conversation.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            StreamBuilder<Map<int, bool>>(
                              stream: UserStatusService().statusStream,
                              initialData: UserStatusService().onlineStatus,
                              builder: (context, snapshot) {
                                final isOnline =
                                    snapshot.data?[widget
                                        .conversation
                                        .userId] ??
                                    false;
                                return Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    color: isOnline
                                        ? Colors.greenAccent[100]
                                        : Colors.red[100],
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                            if (_isLoadingFromCache) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Cache ⚡',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: _isSelectionMode
            ? [
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
              ]
            : [
                // Only show call button if user has call access
                if (_hasCallAccess)
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.white),
                    onPressed: () => _initiateCall(context),
                  ),
              ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
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
                    conversationUserId: widget.conversation.userId,
                    isGroupChat: false,
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
                backgroundColor: Colors.grey[100],
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

    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (_messages.isEmpty &&
        _isInitialized &&
        !_isLoading &&
        !_isLoadingFromCache) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics:
          const ClampingScrollPhysics(), // Better performance than bouncing
      cacheExtent: 100, // Reduce cache extent to save memory
      addAutomaticKeepAlives: false, // Don't keep all items alive
      addRepaintBoundaries:
          true, // Add repaint boundaries for better performance
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      // (_isLoadingMore ? 1 : 0) +
      // (!_hasMoreMessages && _messages.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top when loading older messages
        if (index == 0 && _isLoadingMore) {
          return Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.teal[400]!,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading older messages...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate the actual message index, accounting for indicators
        int messageIndex = index;

        // Subtract 1 if there's a "no more messages" indicator at index 0
        if (!_hasMoreMessages && _messages.isNotEmpty && !_isLoadingMore) {
          messageIndex = index - 1;
        }

        // Subtract 1 if there's a loading indicator at index 0
        if (_isLoadingMore) {
          messageIndex = index - 1;
        }

        // Bounds check to prevent index out of bounds errors
        if (messageIndex < 0 || messageIndex >= _messages.length) {
          // Removed expensive debug prints during scroll - causes lag
          return const SizedBox.shrink(); // Return empty widget for invalid indices
        }

        final message =
            _messages[_messages.length -
                1 -
                messageIndex]; // Show newest at bottom

        // Determine if message is from current user
        // If _currentUserId is known, use it
        // If not, infer: in a DM, any message NOT from conversation.userId is from us
        final isMyMessage = _currentUserId != null
            ? message.senderId == _currentUserId
            : message.senderId != widget.conversation.userId;

        // Ensure we have a GlobalKey for this message for precise scrolling
        if (!_messageKeys.containsKey(message.id)) {
          _messageKeys[message.id] = GlobalKey();
        }

        // Wrap the message with a container that has a key for scrolling
        return Container(
          key: _messageKeys[message.id],
          child: Column(
            children: [
              // Date separator - show the date for the group of messages that starts here
              if (ChatHelpers.shouldShowDateSeparator(_messages, messageIndex))
                DateSeparator(dateTimeString: message.createdAt),
              // Message bubble with long press
              _buildMessageWithActions(message, isMyMessage),
            ],
          ),
        );
      },
    );
  }

  /// Build sticky date separator that appears at the top when scrolling
  Widget _buildStickyDateSeparator() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showStickyDate,
      builder: (context, showDate, child) {
        if (!showDate) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<String?>(
          valueListenable: _currentStickyDate,
          builder: (context, currentDate, child) {
            if (currentDate == null) {
              return const SizedBox.shrink();
            }

            // Find a message with the current date to get the formatted date string
            final messageWithCurrentDate = _messages.firstWhere(
              (message) =>
                  ChatHelpers.getMessageDateString(message.createdAt) ==
                  currentDate,
              orElse: () => _messages.first,
            );

            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                // show a loading indicator when  _isLoadingMore is true else day
                child: Text(
                  _isLoadingMore
                      ? "Loading more chats..."
                      : ChatHelpers.formatDateSeparator(
                          messageWithCurrentDate.createdAt,
                        ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageWithActions(MessageModel message, bool isMyMessage) {
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessageId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Wrap in RepaintBoundary to isolate repaints and improve scroll performance
    return RepaintBoundary(
      key: ValueKey(message.id), // Add key for better widget identification
      child: GestureDetector(
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
          verticalDistance < _maxVerticalDeviation) {
        _isSwipeGesture = true;
      } else if (verticalDistance > _maxVerticalDeviation) {
        // Too much vertical movement, this is likely a scroll, not a swipe
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
        buildMessageStatusTicks: _buildMessageStatusTicks,
        isGroupChat: false,
        nonMyMessageBackgroundColor: Colors.white,
        useIntrinsicWidth: true,
        useStackContainer: true,
        currentUserId: _currentUserId,
        conversationUserId: widget.conversation.userId,
        onReplyTap: _scrollToMessage,
      ),
    );
  }
  // Helper methods for file attachments

  bool _isMediaMessage(MessageModel message) {
    return isMediaMessage(message);
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

  Widget _buildImageMessage(MessageModel message, bool isMyMessage) {
    return buildImageMessage(_buildMediaMessageConfig(message, isMyMessage));
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

  Widget _buildDocumentMessage(MessageModel message, bool isMyMessage) {
    return buildDocumentMessage(_buildMediaMessageConfig(message, isMyMessage));
  }

  Widget _buildAudioMessage(MessageModel message, bool isMyMessage) {
    return buildAudioMessage(_buildMediaMessageConfig(message, isMyMessage));
  }

  Widget _buildVideoMessage(MessageModel message, bool isMyMessage) {
    return buildVideoMessage(_buildMediaMessageConfig(message, isMyMessage));
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

  void _exitSelectionMode() {
    setState(() {
      _selectedMessages.clear();
      _isSelectionMode = false;
    });
  }

  void _showMessageActions(MessageModel message, bool isMyMessage) {
    final isPinned = _pinnedMessageId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageActionSheet(
        message: message,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        showReadBy: false,
        onReply: () => _replyToMessage(message),
        onPin: () => _togglePinMessage(message.id),
        onStar: () => _toggleStarMessage(message.id),
        onForward: () => _forwardMessage(message),
        onSelect: () => _enterSelectionMode(message.id),
        onDelete: isMyMessage ? () => _deleteMessage(message.id) : null,
      ),
    );
  }

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
        currentConversationId: widget.conversation.conversationId,
      ),
    );
  }

  Future<void> _loadAvailableConversations() async {
    await loadAvailableConversations(
      LoadAvailableConversationsConfig(
        userService: _userService,
        currentConversationId: widget.conversation.conversationId,
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
        sourceConversationId: widget.conversation.conversationId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          setState(() {
            _messagesToForward.clear();
          });
        },
        showErrorDialog: _showErrorDialog,
      ),
    );
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
      filePrefix: 'voice_note_',
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

  void _sendImageMessage(
    File imageFile,
    String source, {
    MessageModel? failedMessage,
  }) async {
    await sendImageMessage(
      SendMediaMessageConfig(
        mediaFile: imageFile,
        conversationId: widget.conversation.conversationId,
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
        conversationId: widget.conversation.conversationId,
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
        conversationId: widget.conversation.conversationId,
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
      conversationId: widget.conversation.conversationId,
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
      conversationId: widget.conversation.conversationId,
      starredMessages: _starredMessages,
      currentUserId: _currentUserId,
      messagesRepo: _messagesRepo,
      websocketService: _websocketService,
      setState: setState,
    );
  }

  void _replyToMessage(MessageModel message) async {
    setState(() {
      _replyToMessageData = message;
      _isReplying = true;
    });
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
      conversationId: widget.conversation.conversationId,
      messages: _messages,
      chatsServices: _chatsServices,
      messagesRepo: _messagesRepo,
      setState: setState,
    );
  }

  void _bulkStarMessages() async {
    await ChatHelpers.bulkStarMessages(
      conversationId: widget.conversation.conversationId,
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
      conversation: widget.conversation,
    );
  }

  Widget _buildTypingIndicator() {
    return ChatHelpers.buildTypingIndicator(
      typingDotAnimations: _typingDotAnimations,
      isGroupChat: false,
      userProfilePic: widget.conversation.userProfilePic,
      userName: widget.conversation.userName,
    );
  }

  /// Debug method to test reply message storage and retrieval

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
                recordingTextPrefix: 'Still Recording',
                sendButtonColor: Colors.green,
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
          conversationId: widget.conversation.conversationId,
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

  /// Initiate audio call
  Future<void> _initiateCall(BuildContext context) async {
    await ChatHelpers.initiateCall(
      context: context,
      websocketService: _websocketService,
      userId: widget.conversation.userId,
      userName: widget.conversation.userName,
      userProfilePic: widget.conversation.userProfilePic,
    );
  }
}
