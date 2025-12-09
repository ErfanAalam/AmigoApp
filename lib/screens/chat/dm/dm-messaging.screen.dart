import 'dart:async';
import 'dart:io';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/utils/snowflake.util.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../api/chat.api-client.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/draft-message.service.dart';
import '../../../services/media-cache.service.dart';
import '../../../services/notification.service.dart';
import '../../../services/socket/websocket.service.dart';
import '../../../services/socket/ws-message.handler.dart';
import '../../../services/user-status.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/attachment.action-sheet.dart';
import '../../../ui/chat/date.widgets.dart';
import '../../../ui/chat/forward-message.widget.dart';
import '../../../ui/snackbar.dart';
import '../../../ui/chat/input-container.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/message.action-sheet.dart';
import '../../../ui/chat/message.widget.dart';
import '../../../ui/chat/pinned-message.widget.dart';
import '../../../ui/chat/scroll-to-bottom.button.dart';
import '../../../ui/chat/voice-recording.widget.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/chat/attachments.utils.dart';
import '../../../utils/chat/audio-playback.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../utils/chat/forward-message.utils.dart';
import '../../../utils/chat/preview-media.utils.dart';

class InnerChatPage extends ConsumerStatefulWidget {
  final DmModel dm;
  const InnerChatPage({super.key, required this.dm});

  @override
  ConsumerState<InnerChatPage> createState() => _InnerChatPageState();
}

class _InnerChatPageState extends ConsumerState<InnerChatPage>
    with TickerProviderStateMixin {
  final ChatsServices _chatsServices = ChatsServices();
  // final UserService _userService = UserService();
  final ConversationRepository _conversationsRepo = ConversationRepository();
  final MessageRepository _messagesRepo = MessageRepository();
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();
  final UserRepository _userRepo = UserRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final WebSocketService _webSocket = WebSocketService();
  final WebSocketMessageHandler _wsMessageHandler = WebSocketMessageHandler();
  final ImagePicker _imagePicker = ImagePicker();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  final UserUtils _userUtils = UserUtils();

  // stream subscriptions
  StreamSubscription<ConnectionStatus>? _onlineStatusSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<ChatMessageAckPayload>? _messageAckSubscription;
  StreamSubscription<MessagePinPayload>? _messagePinSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;
  StreamSubscription<JoinLeavePayload>? _joinConvSubscription;

  // State variables
  bool _isLoading = false;
  List<MessageModel> _messages = [];
  List<MessageModel> _failedMessages = [];
  MessageModel? _pinnedMessage;
  UserModel? _currentUserDetails;

  // Message sync state variables
  bool _isSyncingMessages = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  int _syncedMessageCount = 0;
  int _totalMessageCount = 0;

  // Typing animation controllers
  late AnimationController _typingAnimationController;
  late List<Animation<double>> _typingDotAnimations;

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

  // Draft save debounce timer
  Timer? _draftSaveTimer;

  // bool _isLoadingMore = false;
  // bool _hasMoreMessages = true;
  // int _currentPage = 1;
  // String? _errorMessage;
  // bool _isInitialized = false;
  // bool _hasCallAccess = false;
  // ConversationMeta? _conversationMeta;
  // bool _isLoadingFromCache = false;
  // bool _hasCheckedCache = false; // Track if we've checked cache
  // bool _isCheckingCache = true; // Show brief cache check state
  bool _isTyping = false;
  bool _isSendingMessage = false;
  // bool isloadingMediamessage = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);
  // Map<int, int?> userLastReadMessageIds = {}; // userId -> lastReadMessageId

  // Scroll to bottom button state
  bool _isAtBottom = true;
  // int _unreadCountWhileScrolled = 0;
  double _lastScrollPosition = 0.0;
  // int _previousMessageCount = 0;

  // int _optimisticMessageId = -1; // Negative IDs for optimistic messages
  // final Set<int> _optimisticMessageIds = {}; // Track optimistic messages
  bool _isDisposed = false; // Track if the page is being disposed

  bool get _canSetState => mounted && !_isDisposed;

  void _safeSetState(VoidCallback fn) {
    if (_canSetState) {
      setState(fn);
    }
  }

  // User info cache for sender names and profile pics
  // final Map<int, Map<String, String?>> _userInfoCache = {};

  // Track if other users are active in the conversation
  // final Map<int, bool> _activeUsers = {};
  // List<int> _onlineUsers = [];

  // Message selection and actions
  final Set<int> _selectedMessages = {};
  // int? _pinnedMessageId; // Only one message can be pinned
  final Set<int> _starredMessages = {};

  // Forward message state
  final Set<int> _messagesToForward = {};
  final bool _isLoadingConversations = false;

  // Reply message state
  MessageModel? _replyToMessageData;

  // Highlighted message state (for scroll-to effect)
  int? _highlightedMessageId;
  Timer? _highlightTimer;

  // Sticky date separator state - using ValueNotifier to avoid setState during scroll
  final ValueNotifier<String?> _currentStickyDate = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<bool> _showStickyDate = ValueNotifier<bool>(false);

  Timer? _typingTimeout;

  // Scroll debounce timer
  Timer? _scrollDebounceTimer;

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
  static const double _minSwipeDistance =
      30.0; // Minimum distance to consider as swipe
  static const double _maxVerticalDeviation =
      40.0; // Max vertical movement allowed for horizontal swipe
  static const double _minSwipeVelocity =
      800.0; // Minimum velocity for swipe completion
  static const double _swipeThreshold =
      0.4; // Threshold for swipe completion (0.0 to 1.0)

  //
  // // Video thumbnail cache
  final Map<String, String?> _videoThumbnailCache = {};
  final Map<String, Future<String?>> _videoThumbnailFutures = {};

  @override
  void initState() {
    super.initState();

    // Clear notifications for this conversation when opened
    NotificationService().clearConversationNotifications(
      widget.dm.conversationId.toString(),
    );

    // Initialize typing animation
    _initializeTypingAnimation();

    // Initialize voice recording animations
    _initializeVoiceAnimations();

    // Load draft message for this conversation
    _loadDraft();

    // Set up WebSocket message listener
    _setupWebSocketListener();

    // Start initialization immediately
    _initializeChat();

    _scrollController.addListener(_onScroll);

    // Listen to text changes for draft saving
    _messageController.addListener(_onMessageTextChanged);
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
      setState: () => _safeSetState(() {}),
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
      setState: () => _safeSetState(() {}),
      showErrorDialog: _showErrorDialog,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      messages: _messages,
    );

    // Initialize the audio player asynchronously
    _audioPlaybackManager.initialize();
  }

  /// Load draft message when opening conversation
  Future<void> _loadDraft() async {
    // Load directly from service for immediate access
    final draftService = DraftMessageService();
    final draft = await draftService.getDraft(widget.dm.conversationId);
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      // Also update the provider state
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.dm.conversationId, draft);
    }
  }

  /// Set up WebSocket message listener for real-time messages
  void _setupWebSocketListener() {
    final convId = widget.dm.conversationId;

    // Listen to messages filtered for this conversation
    _messageSubscription = _wsMessageHandler
        .messagesForConversation(convId)
        .listen(
          (payload) {
            _handleMessageNew(payload);
          },
          onError: (error) {
            debugPrint('❌ Message stream error: $error');
          },
        );

    // Listen to ack messages filtered for this conversation
    _messageAckSubscription = _wsMessageHandler
        .messagesAckForConversation(convId)
        .listen(
          (payload) {
            _handleMessageAck(payload);
          },
          onError: (error) {
            debugPrint('❌ Message stream error: $error');
          },
        );

    // Listen to typing events for this conversation
    _typingSubscription = _wsMessageHandler
        .typingForConversation(convId)
        .listen(
          (payload) => _receiveTyping(payload),
          onError: (error) {
            debugPrint('❌ Typing stream error: $error');
          },
        );

    // Listen to message pins for this conversation
    _messagePinSubscription = _wsMessageHandler
        .messagePinsForConversation(convId)
        .listen(
          (payload) => _handleMessagePin(payload),
          onError: (error) {
            debugPrint('❌ Message pin stream error: $error');
          },
        );

    // Listen to message delete events for this conversation
    // _messageDeleteSubscription = _wsMessageHandler
    //     .messageDeletesForConversation(convId)
    //     .listen(
    //       (payload) => _handleMessageDelete(payload),
    //       onError: (error) {
    //         debugPrint('❌ Message delete stream error: $error');
    //       },
    //     );
    _joinConvSubscription = _wsMessageHandler
        .joinConversation(convId)
        .listen(
          _handleConversationJoin,
          onError: (error) {
            debugPrint('❌ Conversation join/leave stream error: $error');
          },
        );
  }

  Future<void> _initializeChat() async {
    // get the current user details
    final currentUser = await _userUtils.getUserDetails();
    if (currentUser != null) {
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _currentUserDetails = currentUser;
      });
    }

    ref
        .read(chatProvider.notifier)
        .setActiveConversation(widget.dm.conversationId, ChatType.dm);

    // Clear unread count when entering conversation (important for notification navigation)
    await _conversationsRepo.updateUnreadCount(widget.dm.conversationId, 0);
    // Also clear via provider to update UI state
    ref
        .read(chatProvider.notifier)
        .clearUnreadCount(widget.dm.conversationId, ChatType.dm);

    final messagesFromLocal = await _messagesRepo.getMessagesByConversation(
      widget.dm.conversationId,
      limit: 100,
      offset: 0,
    );

    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _messages = messagesFromLocal;
      _sortMessagesBySentAt();
      _isLoading = false;
    });

    // Load pinned message ID directly from database (not from widget.dm which may be stale)
    final conversation = await _conversationsRepo.getConversationById(
      widget.dm.conversationId,
    );
    final currentPinnedMessageId = conversation?.pinnedMessageId;

    if (currentPinnedMessageId != null) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        currentPinnedMessageId,
      );
      if (!_canSetState) {
        return;
      }

      if (pinnedMessage != null) {
        _safeSetState(() {
          _pinnedMessage = pinnedMessage;
          // Ensure pinned message is in _messages list if not already present
          final isInMessages = _messages.any(
            (msg) =>
                msg.canonicalId == pinnedMessage.canonicalId ||
                msg.id == pinnedMessage.id,
          );
          if (!isInMessages) {
            _messages.add(pinnedMessage);
            _sortMessagesBySentAt();
          }
        });
      } else {
        // Pinned message ID exists but message not found - clear it from DB
        await _conversationsRepo.updatePinnedMessage(
          widget.dm.conversationId,
          null,
        );
        _safeSetState(() {
          _pinnedMessage = null;
        });
      }
    } else {
      // Ensure _pinnedMessage is null when there's no pinned message
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _pinnedMessage = null;
      });
    }

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // Send WebSocket messages in background (non-blocking, non-critical)
    final joinConvPayload = JoinLeavePayload(
      convId: widget.dm.conversationId,
      convType: ChatType.dm,
      userId: _currentUserDetails?.id ?? 0,
      userName: _currentUserDetails?.name ?? '',
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.conversationJoin,
      payload: joinConvPayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    await _webSocket.sendMessage(wsmsg);
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    // start silent message sync (from server to local DB)
    await _syncMessagesFromServer();

    // resend any failed messages
    final failedMessages = messagesFromLocal
        .where(
          (msg) =>
              msg.metadata != null &&
              msg.metadata!['upload_failed'] == true &&
              msg.senderId == _currentUserDetails?.id,
        )
        .toList();
    if (failedMessages.isNotEmpty) {
      // Update UI to show loading state for all failed messages before resending
      if (_canSetState) {
        _safeSetState(() {
          for (final failedMessage in failedMessages) {
            final msgIndex = _messages.indexWhere(
              (msg) =>
                  msg.id == failedMessage.id ||
                  msg.optimisticId == failedMessage.optimisticId,
            );
            if (msgIndex != -1) {
              final uploadingMetadata = Map<String, dynamic>.from(
                failedMessage.metadata ?? {},
              );
              uploadingMetadata.remove('upload_failed');
              uploadingMetadata['is_uploading'] = true;
              _messages[msgIndex] = failedMessage.copyWith(
                status: MessageStatusType.sent,
                metadata: uploadingMetadata,
              );
            }
          }
        });
      }

      // Now resend each failed message
      for (final failedMessage in failedMessages) {
        await _resendFailedMessage(failedMessage);
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    // Implement loading more messages from server to local DB
    final moreMessages = await _messagesRepo.getMessagesByConversation(
      widget.dm.conversationId,
      limit: 100,
      offset: _messages.length,
    );

    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _messages.addAll(moreMessages);
      _sortMessagesBySentAt();
    });
  }

  /// Sync all messages from server to local DB
  /// This is called when user visits the conversation for the first time
  Future<void> _syncMessagesFromServer() async {
    // Check if sync is needed
    final needSync = await _conversationsRepo.getNeedSyncStatus(
      widget.dm.conversationId,
    );

    // ===========================================================================
    // ===========================================================================
    // TEMPORARY NEED SYNC LOGIC CHANGE
    // ===========================================================================
    // ===========================================================================

    if (needSync == false) {
      if (_canSetState) {
        _safeSetState(() {
          _isSyncingMessages = false;
          _syncProgress = 1.0;
          _syncStatus = 'Sync complete';
        });
      }
      final firstPageResponse = await _chatsServices.getConversationHistory(
        conversationId: widget.dm.conversationId,
        page: 1,
        limit: 100,
      );

      final firstPageHistory = ConversationHistoryResponse.fromJson(
        firstPageResponse['data'],
      );

      // Process first page
      if (firstPageHistory.messages.isNotEmpty) {
        await _messagesRepo.insertMessages(firstPageHistory.messages);
      }

      // Sync message statuses
      await _syncMessageStatuses();

      // hasMorePages = firstPageHistory.hasNextPage;
      // page++;

      // Reload messages from local DB after sync
      if (!_canSetState) {
        return;
      }
      final syncedMessages = await _messagesRepo.getMessagesByConversation(
        widget.dm.conversationId,
        limit: 100,
        offset: 0,
      );

      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _messages = syncedMessages;
        _sortMessagesBySentAt();
        _isSyncingMessages = false;
        _syncProgress = 1.0;
        _syncStatus = 'Sync complete';
      });

      // return early since we don't need heavy sync
      return;
    }

    // Start syncing
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _isSyncingMessages = true;
      _syncProgress = 0.0;
      _syncStatus = 'syncing messages';
      _syncedMessageCount = 0;
      _totalMessageCount = 0;
    });

    try {
      int page = 1;
      const int limit = 200; // Fetch 100 messages per page
      bool hasMorePages = true;
      int totalSynced = 0;

      // First, get the first page to know total count
      final firstPageResponse = await _chatsServices.getConversationHistory(
        conversationId: widget.dm.conversationId,
        page: page,
        limit: limit,
      );

      if (firstPageResponse['success'] != true ||
          firstPageResponse['data'] == null) {
        // Failed to fetch, stop syncing
        if (_canSetState) {
          _safeSetState(() {
            _isSyncingMessages = false;
            _syncStatus = 'Sync failed';
          });
        }
        return;
      }

      final firstPageHistory = ConversationHistoryResponse.fromJson(
        firstPageResponse['data'],
      );
      _totalMessageCount = firstPageHistory.totalCount;

      if (_totalMessageCount == 0) {
        // No messages to sync
        if (_canSetState) {
          _safeSetState(() {
            _isSyncingMessages = false;
            _syncStatus = '';
          });
        }
        return;
      }

      // Process first page
      if (firstPageHistory.messages.isNotEmpty) {
        await _messagesRepo.insertMessages(firstPageHistory.messages);
        totalSynced += firstPageHistory.messages.length;

        if (_canSetState) {
          _safeSetState(() {
            _syncedMessageCount = totalSynced;
            _syncProgress = totalSynced / _totalMessageCount;
            _syncStatus =
                'Syncing messages... ($totalSynced/$_totalMessageCount)';
          });
        }
      }

      hasMorePages = firstPageHistory.hasNextPage;
      page++;

      // Continue fetching remaining pages
      while (hasMorePages && _canSetState) {
        final response = await _chatsServices.getConversationHistory(
          conversationId: widget.dm.conversationId,
          page: page,
          limit: limit,
        );

        if (response['success'] != true || response['data'] == null) {
          break; // Stop on error
        }

        final historyResponse = ConversationHistoryResponse.fromJson(
          response['data'],
        );

        if (historyResponse.messages.isEmpty) {
          break; // No more messages
        }

        // Insert messages into local DB
        await _messagesRepo.insertMessages(historyResponse.messages);
        totalSynced += historyResponse.messages.length;

        // Update progress
        if (_canSetState) {
          _safeSetState(() {
            _syncedMessageCount = totalSynced;
            _syncProgress = totalSynced / _totalMessageCount;
            _syncStatus =
                'Syncing messages... ($totalSynced/$_totalMessageCount)';
          });
        }

        hasMorePages = historyResponse.hasNextPage;
        page++;

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Sync message statuses after all messages are synced
      await _syncMessageStatuses();

      // Reload messages from local DB after sync
      if (!_canSetState) {
        return;
      }
      final syncedMessages = await _messagesRepo.getMessagesByConversation(
        widget.dm.conversationId,
        limit: 100,
        offset: 0,
      );

      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _messages = syncedMessages;
        _sortMessagesBySentAt();
        _isSyncingMessages = false;
        _syncProgress = 1.0;
        _syncStatus = 'Sync complete';
      });

      // Mark sync as completed in conversations repo
      await _conversationsRepo.updateNeedSyncStatus(
        widget.dm.conversationId,
        false,
      );

      // Clear sync status after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        _safeSetState(() {
          _syncStatus = '';
          _syncProgress = 0.0;
        });
      });
    } catch (e) {
      debugPrint('❌ Error syncing messages: $e');
      _safeSetState(() {
        _isSyncingMessages = false;
        _syncStatus = 'Sync failed';
      });
    }
  }

  /// Sync message statuses from server to local DB
  Future<void> _syncMessageStatuses() async {
    try {
      int page = 1;
      const int limit = 1000; // Fetch up to 1000 statuses per page
      bool hasMorePages = true;

      while (hasMorePages && _canSetState) {
        final response = await _chatsServices.getMessageStatuses(
          conversationId: widget.dm.conversationId,
          page: page,
          limit: limit,
        );

        if (response['success'] != true || response['data'] == null) {
          break; // Stop on error
        }

        final statusesData = response['data'];
        final List<dynamic> statuses = statusesData['statuses'] ?? [];

        if (statuses.isEmpty) {
          break; // No more statuses
        }

        // Convert to format expected by repository
        final List<Map<String, dynamic>> statusesToInsert = statuses.map((
          status,
        ) {
          return {
            'id': status['id'],
            'conversationId': status['conv_id'],
            'messageId': status['message_id'],
            'userId': status['user_id'],
            'deliveredAt': status['delivered_at'],
            'readAt': status['read_at'],
          };
        }).toList();

        // Insert statuses into local DB
        await _messageStatusRepo.insertMessageStatuses(statusesToInsert);

        // Check if there are more pages
        final pagination = statusesData['pagination'];
        hasMorePages = pagination?['hasNextPage'] ?? false;
        page++;

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('❌ Error syncing message statuses: $e');
      // Don't fail the entire sync if status sync fails
    }
  }

  /// Sort messages by sentAt timestamp to maintain consistent order
  /// This prevents messages from flipping when setState is called
  void _sortMessagesBySentAt() {
    _messages.sort((a, b) {
      try {
        final aTime = DateTime.parse(a.sentAt);
        final bTime = DateTime.parse(b.sentAt);
        return aTime.compareTo(bTime);
      } catch (e) {
        // If parsing fails, fall back to string comparison
        return a.sentAt.compareTo(b.sentAt);
      }
    });
  }

  /// Handle message text changes with debouncing for draft saving
  void _onMessageTextChanged() {
    // Cancel existing timer
    _draftSaveTimer?.cancel();

    // Create new timer to save draft after 500ms of no typing
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_canSetState) {
        final draftNotifier = ref.read(draftMessagesProvider.notifier);
        final text = _messageController.text;
        draftNotifier.saveDraft(widget.dm.conversationId, text);
      }
    });
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
        currentMessage.sentAt,
      );

      // Only update if the date has changed - using ValueNotifier to avoid setState
      if (_currentStickyDate.value != currentDateString) {
        _currentStickyDate.value = currentDateString;
        _showStickyDate.value = true;
      }
    }
  }

  void _onScroll() async {
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
      await _loadMoreMessages();
    }
  }

  /// Handle message delete event from WebSocket
  // void _handleMessageDelete(DeleteMessagePayload payload) async {
  //   await handleMessageDelete(
  //     HandleMessageDeleteConfig(
  //       message: payload,
  //       mounted: () => mounted,
  //       setState: setState,
  //       messages: _messages,
  //       conversationId: widget.dm.id,
  //       messagesRepo: _messagesRepo,
  //     ),
  //   );
  // }

  /// Build message status ticks (single/double) based on delivery and read status
  Widget _buildMessageStatusTicks(MessageModel message) {
    if (((message.status == MessageStatusType.read) && message.id > 0)) {
      // Message is already marked as read - always show blue tick
      return Icon(Icons.done_all, size: 16, color: Colors.blue);
    } else if (message.status == MessageStatusType.delivered) {
      // User is active - show blue tick for delivered messages
      return Icon(Icons.done_all, size: 16, color: Colors.grey[600]);
    } else {
      return Icon(Icons.done, size: 16, color: Colors.grey[600]);
    }
  }

  /// Handle incoming message from WebSocket
  void _handleMessageNew(ChatMessagePayload payload) async {
    try {
      UserModel? senderDetails;
      if (payload.senderName == null) {
        senderDetails = await _userRepo.getUserById(payload.senderId);
      }

      // create message model from payload
      final message = MessageModel(
        canonicalId: payload.canonicalId,
        conversationId: payload.convId,
        senderId: payload.senderId,
        attachments: payload.attachments,
        body: payload.body,
        metadata: payload.metadata,
        senderName: payload.senderName ?? senderDetails?.name ?? '',
        senderProfilePic: senderDetails?.profilePic ?? '',
        isReplied: payload.replyToMessageId != null,
        type: payload.msgType,
        status: MessageStatusType.read,
        sentAt: payload.sentAt.toIso8601String(),
      );

      // If this is a message from the current user, check if we have an optimistic message
      // that matches by optimisticId and update it instead of adding a duplicate
      if (payload.senderId == _currentUserDetails?.id &&
          payload.optimisticId != null) {
        final existingIndex = _messages.indexWhere(
          (msg) =>
              msg.optimisticId == payload.optimisticId ||
              (msg.id == payload.optimisticId &&
                  msg.senderId == payload.senderId),
        );

        if (existingIndex != -1) {
          // Update existing message with server response
          if (!_canSetState) {
            return;
          }
          _safeSetState(() {
            // Clear uploading state and update with server message
            final updatedMetadata = Map<String, dynamic>.from(
              message.metadata ?? {},
            );
            updatedMetadata['is_uploading'] = false;
            updatedMetadata.remove('upload_failed');

            final updatedMessage = message.copyWith(
              optimisticId: _messages[existingIndex].optimisticId,
              metadata: updatedMetadata,
            );
            _messages[existingIndex] = updatedMessage;
            _sortMessagesBySentAt();
          });

          // Save to DB
          await _messagesRepo.insertMessage(message);
          return;
        }
      }

      // Add message to UI immediately with animation
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _messages.add(message);
        _sortMessagesBySentAt();
      });

      if (message.id > 0) {
        _animateNewMessage(message.id);
      }
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  void _handleMessageAck(ChatMessageAckPayload payload) async {
    try {
      // Find the message with matching optimisticId
      final messageIndex = _messages.indexWhere(
        (msg) =>
            msg.optimisticId == payload.optimisticId ||
            msg.id == payload.optimisticId ||
            msg.canonicalId == payload.canonicalId,
      );

      if (messageIndex == -1) {
        debugPrint(
          '⚠️ Message with optimisticId ${payload.optimisticId} not found in _messages',
        );
        return;
      }

      final currentMessage = _messages[messageIndex];

      // Clear uploading state and update status
      final updatedMetadata = Map<String, dynamic>.from(
        currentMessage.metadata ?? {},
      );
      updatedMetadata['is_uploading'] = false;
      updatedMetadata.remove('upload_failed');

      // updating message status
      final recipientId = widget.dm.recipientId;

      MessageStatusType status = MessageStatusType.delivered;
      if (payload.readBy != null && payload.readBy!.isNotEmpty) {
        if (payload.readBy!.contains(recipientId)) {
          status = MessageStatusType.read;
        }
      } else if (payload.deliveredTo != null &&
          payload.deliveredTo!.isNotEmpty) {
        if (payload.deliveredTo!.contains(recipientId)) {
          status = MessageStatusType.delivered;
        }
      } else {
        status = MessageStatusType.sent;
      }

      // Update the message with canonicalId, status, and cleared uploading state
      final updatedMessage = currentMessage.copyWith(
        canonicalId: payload.canonicalId,
        status: status, // Update to delivered when acknowledged
        metadata: updatedMetadata,
      );

      // Update the message in-place with canonicalId and status (no setState to avoid UI update)
      // The canonicalId will take precedence in the id getter
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          canonicalId: payload.canonicalId,
          status: status, // Update to delivered when acknowledged
          metadata: updatedMetadata,
        );
      });

      // Save to DB
      try {
        await _messagesRepo.insertMessage(updatedMessage);
      } catch (e) {
        debugPrint('❌ Error updating message in DB: $e');
      }

      // Determine status based on readBy and deliveredTo arrays
      // Only update status if this is a message sent by the current user
      // MessageStatusType? newStatus;
      // if (message.senderId == _currentUserDetails?.id) {
      //   if (payload.readBy != null && payload.readBy!.contains(recipientId)) {
      //     newStatus = MessageStatusType.read;
      //   } else if (payload.deliveredTo != null &&
      //       payload.deliveredTo!.contains(recipientId)) {
      //     newStatus = MessageStatusType.delivered;
      //   } else {
      //     newStatus = MessageStatusType.sent;
      //   }
      // }
    } catch (e) {
      debugPrint('❌ Error processing message_ack: $e');
    }
  }

  void _receiveTyping(TypingPayload payload) {
    if (_isDisposed) {
      return;
    }

    final isTyping = payload.isTyping;

    // Cancel any existing timeout
    _typingTimeout?.cancel();

    // Update the ValueNotifier directly without setState
    _isOtherTypingNotifier.value = isTyping;

    // Control the typing animation
    if (isTyping) {
      _typingAnimationController.repeat(reverse: true);

      // Set a safety timeout to hide typing indicator after 2 seconds
      _typingTimeout = Timer(const Duration(seconds: 2), () {
        if (_isDisposed) {
          return;
        }
        _isOtherTypingNotifier.value = false;
        _typingAnimationController.stop();
        _typingAnimationController.reset();
      });
    } else {
      // Immediately stop typing indicator
      _typingAnimationController.stop();
      _typingAnimationController.reset();
    }
  }

  void _handleTyping(String value) async {
    // final wasTyping = _isTyping;
    final isTyping = value.isNotEmpty;

    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _isTyping = isTyping;
    });

    if (isTyping) {
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      // Send inactive message when user navigates away from the page
      final typingPayload = TypingPayload(
        convId: widget.dm.conversationId,
        isTyping: true,
        senderId: _currentUserDetails!.id,
        senderName: _currentUserDetails!.name,
        senderPfp: _currentUserDetails!.profilePic,
      ).toJson();

      final wsmsg = WSMessage(
        type: WSMessageType.conversationTyping,
        payload: typingPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      await _webSocket.sendMessage(wsmsg).catchError((e) {
        debugPrint('Error sending conversation:leave in deactivate');
      });
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    }
  }

  /// Handle incoming message pin from WebSocket
  void _handleMessagePin(MessagePinPayload payload) async {
    // load pinned message from prefs and then DB
    if (payload.pin) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        payload.messageId,
      );
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _pinnedMessage = pinnedMessage;
      });
    } else {
      if (_canSetState) {
        _safeSetState(() {
          _pinnedMessage = null;
        });
      }
    }
  }

  void _handleConversationJoin(JoinLeavePayload payload) async {
    // find all the messages with message status not read (send or delivered)
    for (final message in _messages) {
      if (message.status != MessageStatusType.read &&
          message.senderId == _currentUserDetails?.id) {
        final messageIndex = _messages.indexWhere(
          (msg) => msg.id == message.id,
        );

        if (messageIndex == -1) {
          debugPrint(
            '⚠️ Message with id ${payload.convId} not found in _messages',
          );
          continue;
        }

        // update the message status to read
        if (!_canSetState) {
          return;
        }
        _safeSetState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatusType.read,
          );
        });
      }
    }
  }

  /// Send message with immediate display (optimistic UI)
  void _sendMessage(
    MessageType messageType, {
    MediaResponse? mediaResponse,
    int? optimisticId,
  }) async {
    if (mounted) {
      setState(() {
        _isSendingMessage = true;
      });
    }
    String messageText = '';
    if (messageType == MessageType.text) {
      messageText = _messageController.text.trim();
      if (messageText.isEmpty) return;
    }

    final optimisticMessageId = optimisticId ?? Snowflake.generateNegative();

    // Clear draft when message is sent
    final draftNotifier = ref.read(draftMessagesProvider.notifier);
    await draftNotifier.removeDraft(widget.dm.conversationId);

    // Create optimistic message for immediate display with current UTC time
    final nowUTC = DateTime.now().toUtc();

    // Structure metadata properly for reply messages
    Map<String, dynamic>? replyMetadata;
    if (_replyToMessageData != null) {
      replyMetadata = {
        'reply_to': {
          'message_id': _replyToMessageData!.id,
          'sender_id': _replyToMessageData!.senderId,
          'sender_name': _replyToMessageData!.senderName,
        },
      };
    }

    final newMsg = MessageModel(
      optimisticId: optimisticMessageId,
      conversationId: widget.dm.conversationId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      metadata: replyMetadata,
      attachments: mediaResponse?.toJson(),
      type: messageType,
      body: messageText,
      isReplied: _replyToMessageData != null,
      status: MessageStatusType.sent,
      sentAt: nowUTC.toIso8601String(),
    );

    // storing the message into the local database
    await _messagesRepo.insertMessage(newMsg);

    // Clear input and reply state immediately for better UX
    _messageController.clear();

    // Add message to UI immediately with animation
    if (_canSetState) {
      _safeSetState(() {
        // If optimisticId is provided, replace the existing optimistic message
        if (optimisticId != null) {
          final index = _messages.indexWhere(
            (msg) => msg.optimisticId == optimisticId,
          );
          if (index != -1) {
            _messages[index] = newMsg;
          } else {
            _messages.add(newMsg);
          }
        } else {
          _messages.add(newMsg);
        }
        _sortMessagesBySentAt();
      });

      _animateNewMessage(newMsg.optimisticId!);
      _scrollToBottom();
    }

    try {
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

      final messagePayload = ChatMessagePayload(
        optimisticId: optimisticMessageId,
        convId: widget.dm.conversationId,
        senderId: _currentUserDetails!.id,
        senderName: _currentUserDetails!.name,
        attachments: mediaResponse,
        convType: ChatType.dm,
        msgType: messageType,
        body: messageText,
        replyToMessageId: _replyToMessageData?.id,
        sentAt: nowUTC,
      );

      final wsmsg = WSMessage(
        type: WSMessageType.messageNew,
        payload: messagePayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      await _webSocket.sendMessage(wsmsg).catchError((e) async {
        debugPrint('Error sending message: $e');
        // Mark message as failed in DB and UI
        await _markMessageAsFailed(newMsg.id);
      });

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

      // updating the last message on sending own message
      ref
          .read(chatProvider.notifier)
          .updateLastMessageOnSendingOwnMessage(
            widget.dm.conversationId,
            newMsg,
          );

      // store that message in the message status table
      await _messageStatusRepo.insertMessageStatusesWithMultipleUserIds(
        messageId: newMsg.id,
        conversationId: widget.dm.conversationId,
        userIds: [widget.dm.recipientId],
      );

      _cancelReply();
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Mark message as failed in DB and UI
      await _markMessageAsFailed(newMsg.id);
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  /// Scroll to bottom of message list
  void _scrollToBottom() {
    ChatHelpers.scrollToBottom(
      scrollController: _scrollController,
      onScrollComplete: () {
        if (_canSetState) {
          _safeSetState(() {
            // _unreadCountWhileScrolled = 0;
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
    // setState(() {
    //   _unreadCountWhileScrolled = 0;
    // });
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
      if (_canSetState && (!_isAtBottom)) {
        _safeSetState(() {
          _isAtBottom = true;
        });
      }
    } else if (scrolledUp || scrollPosition > 100) {
      // User scrolled up - show button
      if (_canSetState && _isAtBottom) {
        _safeSetState(() {
          _isAtBottom = false;
        });
      }
    }

    _lastScrollPosition = scrollPosition;
  }

  /// Track new messages when added while scrolled up
  // void _trackNewMessage() {
  //   if (!_isAtBottom && mounted) {
  //     setState(() {
  //       _unreadCountWhileScrolled++;
  //     });
  //   }
  //   _previousMessageCount = _messages.length;
  // }

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

      while (!messageFound && attempts < maxAttempts) {
        // Load more messages
        // await _loadMoreMessages();

        // Check if we found the message
        messageFound = _messages.any((msg) => msg.id == messageId);
        attempts++;

        // Small delay to allow UI to update
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!messageFound) {
        // Show a user-friendly message
        if (mounted) {
          Snack.warning('Message not found');
        }
        return;
      }

      // Update messageIndex after loading
      final updatedIndex = _messages.indexWhere((msg) => msg.id == messageId);
      if (updatedIndex == -1) return;
    }

    // Now the message should be in our list
    if (!_canSetState) return;

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

    // PHASE 2: Use message ID to find and highlight the message
    // After approximate scroll, highlight the message
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _highlightedMessageId = messageId;
    });

    // Cancel any existing timer
    _highlightTimer?.cancel();

    // Remove highlight after 2 seconds
    _highlightTimer = Timer(const Duration(milliseconds: 2000), () {
      _safeSetState(() {
        _highlightedMessageId = null;
      });
    });

    // If we couldn't find the message initially, retry
    if (updatedMessageIndex == -1 && retryCount < maxRetries - 1) {
      // Force a rebuild and wait a bit longer
      _safeSetState(() {});

      // Try again after a longer delay
      await Future.delayed(const Duration(milliseconds: 300));
      _scrollToMessage(messageId, retryCount: retryCount + 1);
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
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      //  resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: _selectedMessages.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: _selectedMessages.isNotEmpty
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
                    backgroundImage: widget.dm.recipientProfilePic != null
                        ? CachedNetworkImageProvider(
                            widget.dm.recipientProfilePic!,
                          )
                        : null,
                    child: widget.dm.recipientProfilePic == null
                        ? Text(
                            widget.dm.recipientName.isNotEmpty
                                ? widget.dm.recipientName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: themeColor.primary,
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
                          widget.dm.recipientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            StreamBuilder<Map<int, bool>>(
                              stream: UserStatusService().userStatusStream,
                              initialData: UserStatusService().onlineStatus,
                              builder: (context, snapshot) {
                                final isOnline = ref
                                    .read(chatProvider)
                                    .isUserOnline(
                                      widget.dm.recipientId,
                                      widget.dm.conversationId,
                                    );
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        actions: _selectedMessages.isNotEmpty
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
                if (_currentUserDetails?.callAccess == true)
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
                if (_pinnedMessage != null)
                  PinnedMessageSection(
                    pinnedMessage: _messages.firstWhere(
                      (message) =>
                          message.canonicalId == _pinnedMessage?.canonicalId ||
                          message.id == _pinnedMessage?.id,
                      orElse: () => _pinnedMessage!,
                    ),
                    currentUserId: _currentUserDetails?.id,
                    onTap: () => _scrollToMessage(
                      _pinnedMessage?.canonicalId ?? _pinnedMessage?.id ?? 0,
                    ),
                    onUnpin: () => _togglePinMessage(_pinnedMessage!),
                  ),

                // Messages List
                Expanded(child: _buildMessagesList()),

                // Message Input
                _buildMessageInput(),
              ],
            ),
            // Sync Progress Bar - Floating at the top
            if (_isSyncingMessages)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildSyncProgressBar(),
              ),
            // Sticky Date Separator - Overlay on top
            Positioned(
              top: _isSyncingMessages ? 60 : 10,
              left: 0,
              right: 0,
              child: _buildStickyDateSeparator(),
            ),
            // Scroll to Bottom Button - positioned at right bottom
            Positioned(
              right: 16,
              bottom: _replyToMessageData != null
                  ? 150.0
                  : 80.0, // Position above message input
              child: ScrollToBottomButton(
                scrollController: _scrollController,
                onTap: _handleScrollToBottomTap,
                isAtBottom: _isAtBottom,
                // unreadCount: _unreadCountWhileScrolled > 0
                //     ? _unreadCountWhileScrolled
                //     : null,
                bottomPadding:
                    0.0, // Not used anymore, positioning handled by parent
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build floating sync progress bar widget
  Widget _buildSyncProgressBar() {
    final themeColor = ref.watch(themeColorProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeColor.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  value: _syncProgress > 0 ? _syncProgress : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _syncStatus.isNotEmpty
                          ? _syncStatus
                          : 'Syncing messages...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_totalMessageCount > 0) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _syncProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (_messages.isEmpty && !_isLoading) {
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
      itemCount: _messages.length,
      physics:
          const ClampingScrollPhysics(), // Better performance than bouncing
      cacheExtent: 500, // Reduce cache extent to save memory
      addAutomaticKeepAlives: false, // Don't keep all items alive
      addRepaintBoundaries:
          true, // Add repaint boundaries for better performance
      // itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      // (_isLoadingMore ? 1 : 0) +
      // (!_hasMoreMessages && _messages.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top when loading older messages
        // if (index == 0 && _isLoadingMore) {
        //   return Container(
        //     padding: const EdgeInsets.all(16),
        //     margin: const EdgeInsets.symmetric(vertical: 8),
        //     decoration: BoxDecoration(
        //       color: Colors.grey[50],
        //       borderRadius: BorderRadius.circular(12),
        //       border: Border.all(color: Colors.grey[200]!),
        //     ),
        //     child: Row(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         SizedBox(
        //           width: 20,
        //           height: 20,
        //           child: CircularProgressIndicator(
        //             strokeWidth: 2,
        //             valueColor: AlwaysStoppedAnimation<Color>(
        //               Colors.teal[400]!,
        //             ),
        //           ),
        //         ),
        //         const SizedBox(width: 12),
        //         Text(
        //           'Loading older messages...',
        //           style: TextStyle(
        //             color: Colors.grey[600],
        //             fontSize: 14,
        //             fontWeight: FontWeight.w500,
        //           ),
        //         ),
        //       ],
        //     ),
        //   );
        // }

        // Calculate the actual message index, accounting for indicators
        int messageIndex = index;
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
        final isMyMessage = message.senderId == _currentUserDetails?.id;

        // Wrap the message with a container that has a key for scrolling
        return Container(
          key: ValueKey(message.id),
          child: Column(
            children: [
              // Date separator - show the date for the group of messages that starts here
              if (ChatHelpers.shouldShowDateSeparator(_messages, messageIndex))
                DateSeparator(dateTimeString: message.sentAt),
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
                  ChatHelpers.getMessageDateString(message.sentAt) ==
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
                  ChatHelpers.formatDateSeparator(
                    messageWithCurrentDate.sentAt,
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
    final themeColor = ref.watch(themeColorProvider);
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessage?.canonicalId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Wrap in RepaintBoundary to isolate repaints and improve scroll performance
    return RepaintBoundary(
      key: ValueKey(message.id), // Add key for better widget identification
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message, isMyMessage),
        onTap: _selectedMessages.isNotEmpty
            ? () => _toggleMessageSelection(message.id)
            : null,
        onPanStart: (details) => _onSwipeStart(message, details),
        onPanUpdate: (details) => _onSwipeUpdate(message, details, isMyMessage),
        onPanEnd: (details) => _onSwipeEnd(message, details, isMyMessage),
        child: Container(
          color: isSelected
              ? themeColor.primary.withOpacity(0.1)
              : Colors.transparent,
          child: Stack(
            children: [
              _buildSwipeableMessageBubble(
                message,
                isMyMessage,
                isPinned,
                isStarred,
              ),
              if (_selectedMessages.isNotEmpty)
                Positioned(
                  left: isMyMessage ? 8 : null,
                  right: isMyMessage ? null : 8,
                  top: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? themeColor.primary : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? themeColor.primary
                            : Colors.grey[400]!,
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
    if (_selectedMessages.isNotEmpty ||
        _swipeStartPosition == null ||
        _isScrolling)
      return;

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
    final themeColor = ref.watch(themeColorProvider);
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
                          color: themeColor.primary.withOpacity(0.8),
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
    final messageTime = ChatHelpers.formatMessageTime(message.sentAt);

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
        onRetryFailedMessage: _resendFailedMessage,
        isGroupChat: false,
        nonMyMessageBackgroundColor: Colors.white,
        useIntrinsicWidth: true,
        useStackContainer: true,
        currentUserId: _currentUserDetails?.id,
        conversationUserId: widget.dm.recipientId,
        onReplyTap: _scrollToMessage,
        messagesRepo: _messagesRepo,
        userRepo: _userRepo,
      ),
    );
  }
  // Helper methods for file attachments

  bool _isMediaMessage(MessageModel message) {
    return ChatHelpers.isMediaMessage(message);
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
    switch (message.type.value.toLowerCase()) {
      case 'image':
        return _buildImageMessage(message, isMyMessage);
      case 'video':
        return _buildVideoMessage(message, isMyMessage);
      case 'audio':
        return _buildAudioMessage(message, isMyMessage);
      case 'document':
        return _buildDocumentMessage(message, isMyMessage);
      case 'reply':
        // Reply messages show the reply UI with quoted message
        return Text(
          message.body!,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
      case 'forwarded':
        // Forwarded messages show forwarded indicator
        return Text(
          message.body!,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
      // Backward compatibility for old types
      case 'docs':
        return _buildDocumentMessage(message, isMyMessage);
      case 'attachment':
        // Server sends attachments with type="attachment" (backward compatibility)
        return _buildImageMessage(message, isMyMessage);
      case 'text':
      default:
        return Text(
          message.body!,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
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
      setState: () => _safeSetState(() {}),
      showErrorDialog: _showErrorDialog,
      buildMessageStatusTicks: _buildMessageStatusTicks,
      onImagePreview: (url, caption) => _openImagePreview(url, caption),
      onRetryImage: (file, source, {MessageModel? failedMessage}) {
        if (failedMessage != null) {
          _resendFailedMessage(failedMessage);
        } else {
          _sendMediaMessageToServer(file, MessageType.image);
        }
      },
      onCacheImage: (url, id) {
        ChatHelpers.cacheMediaForMessage(
          url: url,
          messageId: id,
          mediaCacheService: _mediaCacheService,
        );
      },
      onVideoPreview: (url, caption, fileName) =>
          _openVideoPreview(url, caption, fileName),
      onRetryVideo: (file, source, {MessageModel? failedMessage}) {
        if (failedMessage != null) {
          _resendFailedMessage(failedMessage);
        } else {
          _sendMediaMessageToServer(file, MessageType.video);
        }
      },
      videoThumbnailCache: _videoThumbnailCache,
      videoThumbnailFutures: _videoThumbnailFutures,
      onDocumentPreview: (url, fileName, caption, fileSize) =>
          _openDocumentPreview(url, fileName, caption, fileSize),
      onRetryDocument:
          (file, fileName, extension, {MessageModel? failedMessage}) {
            if (failedMessage != null) {
              _resendFailedMessage(failedMessage);
            } else {
              _sendMediaMessageToServer(file, MessageType.document);
            }
          },
      audioPlaybackManager: _audioPlaybackManager,
      onRetryAudio: ({MessageModel? failedMessage}) {
        if (failedMessage != null) {
          _resendFailedMessage(failedMessage);
        } else {
          _sendMediaMessageToServer(
            File(failedMessage?.attachments?['url'] ?? ''),
            MessageType.audio,
          );
        }
      },
    );
  }

  Widget _buildDocumentMessage(MessageModel message, bool isMyMessage) {
    return buildDocumentMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildAudioMessage(MessageModel message, bool isMyMessage) {
    return buildAudioMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildVideoMessage(MessageModel message, bool isMyMessage) {
    return buildVideoMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildImageMessage(MessageModel message, bool isMyMessage) {
    return buildImageMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  // Message action methods
  void _toggleMessageSelection(int messageId) {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
      } else {
        _selectedMessages.add(messageId);
      }
    });
  }

  void _exitSelectionMode() {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _selectedMessages.clear();
    });
  }

  void _showMessageActions(MessageModel message, bool isMyMessage) {
    final isPinned = _pinnedMessage?.canonicalId == message.canonicalId;
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
        onPin: () => _togglePinMessage(message),
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
        _sendMediaMessageToServer(imageFile, MessageType.image);
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
        _sendMediaMessageToServer(imageFile, MessageType.image);
      },
      onVideoSelected: (videoFile, source) {
        _sendMediaMessageToServer(videoFile, MessageType.video);
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
        _sendMediaMessageToServer(documentFile, MessageType.document);
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
    final dmList = await ConversationRepository().getAllDmsWithRecipientInfo();
    final groupList = await ConversationRepository()
        .getGroupListWithoutMembers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => ForwardMessageModal(
        messagesToForward: _messagesToForward,
        dmList: dmList,
        groupList: groupList,
        isLoading: _isLoadingConversations,
        onForward: _handleForwardToConversations,
        currentConversationId: widget.dm.conversationId,
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
        currentUserId: _currentUserDetails?.id ?? 0,
        sourceConversationId: widget.dm.conversationId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          if (_canSetState) {
            _safeSetState(() {
              _messagesToForward.clear();
            });
          }
        },
        showErrorDialog: _showErrorDialog,
      ),
    );
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

  Future<void> _sendMediaMessageToServer(
    File mediaFile,
    MessageType messageType,
  ) async {
    final optimisticId = Snowflake.generateNegative();
    final nowUTC = DateTime.now().toUtc();

    // Structure metadata properly for reply messages and upload status
    Map<String, dynamic> metadata = {
      'is_uploading': true, // UI widgets check for this to show loading state
    };
    if (_replyToMessageData != null) {
      metadata['reply_to'] = {
        'message_id': _replyToMessageData!.id,
        'sender_id': _replyToMessageData!.senderId,
        'sender_name': _replyToMessageData!.senderName,
      };
    }

    // Build attachments with local_path for UI to display during upload
    final fileName = mediaFile.path.split('/').last;
    final attachments = {
      'file_name': fileName,
      'local_path': mediaFile.path, // Required for UI to display local file
    };

    final newMsg = MessageModel(
      optimisticId: optimisticId,
      conversationId: widget.dm.conversationId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      metadata: metadata,
      attachments: attachments,
      type: messageType,
      body: '',
      isReplied: _replyToMessageData != null,
      status: MessageStatusType.sent,
      sentAt: nowUTC.toIso8601String(),
    );

    if (_canSetState) {
      _safeSetState(() {
        _messages.add(newMsg);
        _sortMessagesBySentAt();
      });

      _animateNewMessage(newMsg.optimisticId!);
      _scrollToBottom();
    }

    final response = await _chatsServices.sendMediaMessage(mediaFile);
    if (response['success'] == true && response['data'] != null) {
      final mediaData = MediaResponse.fromJson(response['data']);

      _sendMessage(
        messageType,
        mediaResponse: mediaData,
        optimisticId: optimisticId,
      );

      debugPrint('Media data: $mediaData, messageType: $messageType');
    } else {
      // Update message to show upload failed state and save to DB
      await _markMessageAsFailed(optimisticId);
      if (_canSetState) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to send media message')),
        // );
      }
    }
  }

  /// Mark a message as failed in both UI and DB
  Future<void> _markMessageAsFailed(int messageId) async {
    if (!_canSetState) return;

    final index = _messages.indexWhere(
      (msg) => msg.id == messageId || msg.optimisticId == messageId,
    );

    if (index == -1) return;

    final failedMsg = _messages[index];
    final updatedMetadata = Map<String, dynamic>.from(failedMsg.metadata ?? {});
    updatedMetadata['is_uploading'] = false;
    updatedMetadata['upload_failed'] = true;

    final updatedMessage = failedMsg.copyWith(
      status: MessageStatusType.failed,
      metadata: updatedMetadata,
    );

    // Update in UI
    _safeSetState(() {
      _messages[index] = updatedMessage;
    });

    // Save to DB with failed status
    await _messagesRepo.insertMessage(updatedMessage);
  }

  /// Resend a failed message
  Future<void> _resendFailedMessage(MessageModel failedMessage) async {
    // Find the message index in the UI
    final index = _messages.indexWhere(
      (msg) =>
          msg.id == failedMessage.id ||
          msg.optimisticId == failedMessage.optimisticId,
    );

    // Set uploading state immediately for visual feedback
    final uploadingMetadata = Map<String, dynamic>.from(
      failedMessage.metadata ?? {},
    );
    uploadingMetadata.remove('upload_failed');
    uploadingMetadata['is_uploading'] = true;

    final uploadingMessage = failedMessage.copyWith(
      status: MessageStatusType.sent,
      metadata: uploadingMetadata,
    );

    // Update in UI immediately to show uploading state
    if (index != -1 && _canSetState) {
      _safeSetState(() {
        _messages[index] = uploadingMessage;
      });
    }

    // Save uploading state to DB
    await _messagesRepo.insertMessage(uploadingMessage);

    // Handle media messages differently - need to upload first
    if (failedMessage.type != MessageType.text) {
      try {
        // Get the local file path from either localMediaPath or attachments
        String? localPath = failedMessage.localMediaPath;
        if (localPath == null || localPath.isEmpty) {
          localPath = failedMessage.attachments?['local_path'] as String?;
        }

        if (localPath == null || localPath.isEmpty) {
          debugPrint('Error: No local path found for failed media message');
          await _markMessageAsFailed(
            failedMessage.optimisticId ?? failedMessage.id,
          );
          return;
        }

        final mediaFile = File(localPath);
        if (!mediaFile.existsSync()) {
          debugPrint('Error: Media file not found at path: $localPath');
          await _markMessageAsFailed(
            failedMessage.optimisticId ?? failedMessage.id,
          );
          return;
        }

        // Upload the media to server first
        final response = await _chatsServices.sendMediaMessage(mediaFile);

        if (response['success'] == true && response['data'] != null) {
          final mediaData = MediaResponse.fromJson(response['data']);

          // Update message with the new attachments (server URLs)
          final updatedMessage = uploadingMessage.copyWith(
            attachments: mediaData.toJson(),
          );

          // Update in UI
          if (index != -1 && _canSetState) {
            _safeSetState(() {
              _messages[index] = updatedMessage;
            });
          }

          // Save to DB
          await _messagesRepo.insertMessage(updatedMessage);

          // Now send the message with proper MediaResponse
          final messagePayload = ChatMessagePayload(
            optimisticId: failedMessage.optimisticId ?? failedMessage.id,
            convId: failedMessage.conversationId,
            senderId: failedMessage.senderId,
            senderName: failedMessage.senderName,
            attachments: mediaData,
            convType: ChatType.dm,
            msgType: failedMessage.type,
            body: failedMessage.body,
            replyToMessageId:
                failedMessage.metadata?['reply_to']?['message_id'],
            sentAt: DateTime.parse(failedMessage.sentAt),
          );

          final wsmsg = WSMessage(
            type: WSMessageType.messageNew,
            payload: messagePayload,
            wsTimestamp: DateTime.now(),
          ).toJson();

          await _webSocket
              .sendMessage(wsmsg)
              .then((_) {
                // Keep the message in the list with loading state
                // The server will send back the message via WebSocket and we'll update it
                // Save success state to DB (server will send back the actual message)
                final successMetadata = Map<String, dynamic>.from(
                  updatedMessage.metadata ?? {},
                );
                successMetadata['is_uploading'] =
                    true; // Keep loading until server responds
                final successMessage = updatedMessage.copyWith(
                  metadata: successMetadata,
                );
                _messagesRepo.insertMessage(successMessage);
              })
              .catchError((e) async {
                debugPrint('Error resending media message: $e');
                // Mark as failed again
                await _markMessageAsFailed(
                  failedMessage.optimisticId ?? failedMessage.id,
                );
              });
        } else {
          debugPrint('Error: Failed to upload media for resend');
          await _markMessageAsFailed(
            failedMessage.optimisticId ?? failedMessage.id,
          );
        }
      } catch (e) {
        debugPrint('Error resending media message: $e');
        // Mark as failed again
        await _markMessageAsFailed(
          failedMessage.optimisticId ?? failedMessage.id,
        );
      }
      return;
    }

    // Handle text messages
    try {
      final messagePayload = ChatMessagePayload(
        optimisticId: failedMessage.optimisticId ?? failedMessage.id,
        convId: failedMessage.conversationId,
        senderId: failedMessage.senderId,
        senderName: failedMessage.senderName,
        attachments: failedMessage.attachments,
        convType: ChatType.dm,
        msgType: failedMessage.type,
        body: failedMessage.body,
        replyToMessageId: failedMessage.metadata?['reply_to']?['message_id'],
        sentAt: DateTime.parse(failedMessage.sentAt),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.messageNew,
        payload: messagePayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      await _webSocket
          .sendMessage(wsmsg)
          .then((_) {
            // Keep the message in the list with loading state
            // The server will send back the message via WebSocket and we'll update it
            // Save success state to DB (server will send back the actual message)
            final successMetadata = Map<String, dynamic>.from(
              uploadingMessage.metadata ?? {},
            );
            successMetadata['is_uploading'] =
                true; // Keep loading until server responds
            final successMessage = uploadingMessage.copyWith(
              metadata: successMetadata,
            );
            _messagesRepo.insertMessage(successMessage);
          })
          .catchError((e) async {
            debugPrint('Error resending message: $e');
            // Mark as failed again
            await _markMessageAsFailed(
              failedMessage.optimisticId ?? failedMessage.id,
            );
          });
    } catch (e) {
      debugPrint('Error resending message: $e');
      // Mark as failed again
      await _markMessageAsFailed(
        failedMessage.optimisticId ?? failedMessage.id,
      );
    }
  }

  void _enterSelectionMode(int messageId) {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _selectedMessages.add(messageId);
    });
  }

  void _togglePinMessage(MessageModel message) async {
    // Check if this message is currently pinned by comparing IDs
    final messageId = message.canonicalId ?? message.id;
    final pinnedMessageId = _pinnedMessage?.canonicalId ?? _pinnedMessage?.id;
    final wasPinned = messageId == pinnedMessageId && _pinnedMessage != null;
    final newPinnedMessageId = wasPinned ? null : message.canonicalId;

    // Clear or set pinned message immediately for instant UI feedback
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _pinnedMessage = wasPinned ? null : message;
    });

    await ChatHelpers.togglePinMessage(
      message: message,
      conversationId: widget.dm.conversationId,
      currentPinnedMessageId: pinnedMessageId,
      setPinnedMessageId: (value) {
        // This is called inside togglePinMessage's setState, but we already updated above
        // Keep it for consistency
        if (_canSetState) {
          _pinnedMessage = value;
        }
      },
      currentUserId: _currentUserDetails?.id,
      setState: _safeSetState,
    );

    // Update provider state immediately for UI consistency
    ref
        .read(chatProvider.notifier)
        .updatePinnedMessageInState(
          widget.dm.conversationId,
          newPinnedMessageId,
        );
  }

  void _toggleStarMessage(int messageId) async {
    await ChatHelpers.toggleStarMessage(
      messageId: messageId,
      conversationId: widget.dm.conversationId,
      starredMessages: _starredMessages,
      currentUserId: _currentUserDetails?.id,
      setState: _safeSetState,
    );
  }

  void _replyToMessage(MessageModel message) async {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _replyToMessageData = message;
    });
  }

  void _cancelReply() {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _replyToMessageData = null;
    });
  }

  Future<void> _forwardMessage(MessageModel message) async {
    if (_canSetState) {
      _safeSetState(() {
        _messagesToForward.clear();
        _messagesToForward.add(message.id);
      });
    }
    await _showForwardModal();
  }

  void _deleteMessage(int messageId) async {
    setState(() {
      _messages.removeWhere((message) => message.id == messageId);
    });

    ref
        .read(chatProvider.notifier)
        .handleMessageDelete(
          DeleteMessagePayload(
            messageIds: [messageId],
            convId: widget.dm.conversationId,
            senderId: _currentUserDetails?.id ?? 0,
          ),
        )
        .catchError((e) {
          debugPrint('❌ Error deleting messages: $e');
        });

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final deleteMessagePayload = DeleteMessagePayload(
      messageIds: [messageId],
      convId: widget.dm.conversationId,
      senderId: _currentUserDetails?.id ?? 0,
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.messageDelete,
      payload: deleteMessagePayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    _webSocket.sendMessage(wsmsg).catchError((e) {
      debugPrint('❌ Error sending message delete: $e');
    });
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  }

  void _bulkStarMessages() async {
    await ChatHelpers.bulkStarMessages(
      conversationId: widget.dm.conversationId,
      selectedMessages: _selectedMessages,
      starredMessages: _starredMessages,
      currentUserId: _currentUserDetails?.id,
      setState: _safeSetState,
      exitSelectionMode: _exitSelectionMode,
    );
  }

  void _bulkForwardMessages() async {
    await ChatHelpers.bulkForwardMessages(
      selectedMessages: _selectedMessages,
      messagesToForward: _messagesToForward,
      setState: _safeSetState,
      exitSelectionMode: _exitSelectionMode,
      showForwardModal: _showForwardModal,
    );
  }

  Widget _buildMessageInput() {
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: _replyToMessageData != null,
      isSending: _isSendingMessage,
      replyToMessageData: _replyToMessageData,
      currentUserId: _currentUserDetails?.id,
      onSendMessage: (messageType) => _sendMessage(messageType),
      onSendVoiceNote: _sendVoiceNote,
      onAttachmentTap: _showAttachmentModal,
      onTyping: _handleTyping,
      onCancelReply: _cancelReply,
      dm: widget.dm,
    );
  }

  Widget _buildTypingIndicator() {
    return ChatHelpers.buildTypingIndicator(
      typingDotAnimations: _typingDotAnimations,
      isGroupChat: false,
      userProfilePic: widget.dm.recipientProfilePic,
      userName: widget.dm.recipientName,
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
        if (index != -1 && _canSetState) {
          _safeSetState(() {
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

      // Stop recording first
      await _stopRecording();

      // Close the voice recording modal immediately (don't wait for upload)
      if (mounted && failedMessage == null) {
        Navigator.of(context).pop();
      }

      // Send the message (upload continues in background)
      await _sendMediaMessageToServer(voiceFile, MessageType.audio);
    } catch (e) {
      _showErrorDialog('Failed to send voice note. Please try again.');
    }
  }

  /// Initiate audio call
  Future<void> _initiateCall(BuildContext context) async {
    await ChatHelpers.initiateCall(
      context: context,
      websocketService: _webSocket,
      userId: widget.dm.recipientId,
      userName: widget.dm.recipientName,
      userProfilePic: widget.dm.recipientProfilePic,
    );
  }

  @override
  void deactivate() {
    // Send inactive message when user navigates away from the page
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final joinConvPayload = JoinLeavePayload(
      convId: widget.dm.conversationId,
      convType: ChatType.dm,
      userId: _currentUserDetails?.id ?? 0,
      userName: _currentUserDetails?.name ?? '',
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.conversationLeave,
      payload: joinConvPayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    _webSocket.sendMessage(wsmsg).catchError((e) {
      debugPrint('❌ Error sending conversation:leave in deactivate: $e');
    });
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    super.deactivate();
  }

  @override
  void dispose() {
    if (_isDisposed) return; // Prevent multiple dispose calls
    _isDisposed = true;

    _scrollController.dispose();
    _messageController.dispose();
    _messageSubscription?.cancel();
    _messageAckSubscription?.cancel();
    _typingSubscription?.cancel();
    _messagePinSubscription?.cancel();
    // _messageReplySubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _joinConvSubscription?.cancel();
    _typingAnimationController.dispose();
    _typingTimeout?.cancel();
    _scrollDebounceTimer?.cancel();
    // _highlightTimer?.cancel();
    _draftSaveTimer?.cancel();

    // Save draft before disposing
    if (_messageController.text.isNotEmpty) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(
        widget.dm.conversationId,
        _messageController.text,
      );
    }

    // Remove listener
    _messageController.removeListener(_onMessageTextChanged);
    // _currentStickyDate.dispose();
    // _showStickyDate.dispose();

    // Clear active conversation when leaving the messaging screen
    ref.read(chatProvider.notifier).setActiveConversation(null, null);

    // Clear unread count in local DB
    _conversationsRepo.updateUnreadCount(widget.dm.conversationId, 0);

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // Send inactive message when user navigates away from the page
    final joinConvPayload = JoinLeavePayload(
      convId: widget.dm.conversationId,
      convType: ChatType.dm,
      userId: _currentUserDetails?.id ?? 0,
      userName: _currentUserDetails?.name ?? '',
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.conversationLeave,
      payload: joinConvPayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    _webSocket.sendMessage(wsmsg).catchError((e) {
      debugPrint('❌ Error sending conversation:leave in deactivate: $e');
    });
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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

    super.dispose();
  }
}
