import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:amigo/db/repositories/conversation_member.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/messageStatus.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/providers/chat_provider.dart';
import 'package:amigo/utils/chat/chat_helpers.utils.dart';
import 'package:amigo/utils/route_transitions.dart';
import 'package:amigo/utils/snowflake.util.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/group_model.dart';
import '../../../models/community_model.dart';
import '../../../models/user_model.dart';
import '../../../api/chats.services.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../services/socket/websocket_message_handler.dart';
import '../../../types/socket.type.dart';
import '../../../services/media_cache_service.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/draft_message_service.dart';
import '../../../providers/draft_provider.dart';
import '../../../widgets/chat/inputcontainer.widget.dart';
import '../../../widgets/chat/media_messages.widget.dart';
import '../../../services/notification_service.dart';
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
  // final GroupsService _groupsService = GroupsService();
  // final UserService _userService = UserService();
  final ChatsServices _chatsServices = ChatsServices();
  final MessageRepository _messagesRepo = MessageRepository();
  final ConversationRepository _conversationRepo = ConversationRepository();
  final UserRepository _userRepo = UserRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final WebSocketService _webSocket = WebSocketService();
  // final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final UserUtils _userUtils = UserUtils();
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();

  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();

  final WebSocketMessageHandler _wsMessageHandler = WebSocketMessageHandler();
  final ImagePicker _imagePicker = ImagePicker();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  List<MessageModel> _messages = [];
  bool _isLoading = false;

  UserModel? _currentUserDetails;

  // Message sync state variables
  bool _isSyncingMessages = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  int _syncedMessageCount = 0;
  int _totalMessageCount = 0;

  List<UserModel> _conversationMembers = [];

  // bool _isLoadingMore = false;
  // bool _hasMoreMessages = true;
  // int _currentPage = 1;
  // String? _errorMessage;
  // int? _currentUserId;
  // bool _isInitialized = false;
  // ConversationMeta? _conversationMeta;
  // bool _isLoadingFromCache = false;
  // bool _hasCheckedCache = false;
  // bool _isCheckingCache = true;
  bool _isTyping = false;
  bool _isSendingMessage = false;
  bool _isAdminOrStaff = false;
  // bool _isOtherTyping = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);
  bool _isDisposed = false;

  // Scroll to bottom button state
  bool _isAtBottom = true;
  // int _unreadCountWhileScrolled = 0;
  // int _previousMessageCount = 0;

  // For optimistic message handling - using filtered streams per conversation
  // StreamSubscription<OnlineStatusPayload>? _onlineStatusSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<ChatMessageAckPayload>? _messageAckSubscription;
  StreamSubscription<MessagePinPayload>? _messagePinSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;
  // int _optimisticMessageId = -1;
  // final Set<int> _optimisticMessageIds = {};
  bool _isTestSending = false;

  Future<void> _startTestSequence(int totalMessages) async {
    if (_isTestSending) return;
    _isTestSending = true;
    final random = Random();
    try {
      for (int i = 1; i <= totalMessages; i++) {
        if (!mounted) break;
        _messageController.text = 'test sequence $i';
        _sendMessage(MessageType.text);
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
  // final Map<int, Map<String, String?>> _userInfoCache = {};

  /// Get user info from cache, metadata, or local DB
  // Map<String, String?> _getUserInfo(int userId) {
  //   // PRIORITY 1: Check in-memory cache (INSTANT - populated during init)
  //   if (_userInfoCache.containsKey(userId)) {
  //     return _userInfoCache[userId]!;
  //   }

  //   // PRIORITY 2: Check conversation metadata members data
  //   if (_conversationMeta != null && _conversationMeta!.members.isNotEmpty) {
  //     final senderName = _conversationMeta!.getSenderName(userId);
  //     final senderProfilePic = _conversationMeta!.getSenderProfilePic(userId);
  //     if (senderName != 'Unknown User') {
  //       // Cache it for next time
  //       _userInfoCache[userId] = {
  //         'name': senderName,
  //         'profile_pic': senderProfilePic,
  //       };
  //       return {'name': senderName, 'profile_pic': senderProfilePic};
  //     }
  //   }

  // // PRIORITY 3: Check local DB asynchronously and update cache
  // // (Runs in background, will update UI when complete)
  // Future.microtask(() async {
  //   // Try group_members table first (for group member info)
  //   final groupMember = await _groupMembersRepo.getMemberByUserId(userId);
  //   if (groupMember != null && mounted) {
  //     _userInfoCache[userId] = {
  //       'name': groupMember.userName,
  //       'profile_pic': groupMember.profilePic,
  //     };
  //     // Trigger rebuild to show updated names
  //     setState(() {});
  //     return;
  //   }

  //   // Fallback to users table (only for current user)
  //   final user = await _userRepo.getUserById(userId);
  //   if (user != null && mounted) {
  //     _userInfoCache[userId] = {
  //       'name': user.name,
  //       'profile_pic': user.profilePic,
  //     };
  //     debugPrint(
  //       '💾 Loaded user $userId (${user.name}) from users DB - updating UI',
  //     );
  //     // Trigger rebuild to show updated names
  //     setState(() {});
  //   } else {
  //     debugPrint('! User $userId not found in local DB');
  //   }
  // });

  // PRIORITY 4: Return temporary fallback (will update when DB lookup completes)
  // debugPrint('! Using fallback for user $userId - will check DB');
  // return {'name': 'Unknown User', 'profile_pic': null};
  // }

  // Message selection and actions
  final Set<int> _selectedMessages = {};
  // bool _isSelectionMode = false;
  MessageModel? _pinnedMessage; // Only one message can be pinned
  final Set<int> _starredMessages = {};

  // Forward message state
  final Set<int> _messagesToForward = {};
  bool _isLoadingConversations = false;

  // Reply message state
  MessageModel? _replyToMessageData;
  // bool _isReplying = false;

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

    debugPrint('-------initializing the group-------');

    // Clear notifications for this conversation when opened
    NotificationService().clearConversationNotifications(
      widget.group.conversationId.toString(),
    );

    // _websocketService.connect(widget.group.conversationId);

    getAllConversationMembers();

    // Initialize typing animation
    _initializeTypingAnimation();

    // Initialize voice recording animations
    _initializeVoiceAnimations();

    // Set up WebSocket message listener
    _setupWebSocketListener();

    // Start initialization immediately
    _initializeChat();

    // Load draft message for this conversation
    _loadDraft();

    // Check admin or staff status
    // _updateIsAdminOrStaff();

    // Listen to text changes for draft saving
    _messageController.addListener(_onMessageTextChanged);
  }

  Future<void> getAllConversationMembers() async {
    final members = await _conversationMemberRepo
        .getMembersWithUserDetailsByConversationId(widget.group.conversationId);
    setState(() {
      _conversationMembers = members;
    });
    debugPrint(
      '-------conversation members: ${_conversationMembers.length}-------',
    );
    debugPrint(
      '-------conversation members: ${widget.group.conversationId}-------',
    );
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

  // Future<void> _updateIsAdminOrStaff() async {
  //   // Load directly from service for immediate access

  //   if (widget.group.role == 'admin') {
  //     setState(() {
  //       _isAdminOrStaff = true;
  //     });
  //   } else {
  //     // Check if user role is 'staff'
  //     try {
  //       final currentUser = await _userRepo.getFirstUser();
  //       if (currentUser != null && currentUser.role == 'staff') {
  //         setState(() {
  //           _isAdminOrStaff = true;
  //         });
  //       }
  //     } catch (e) {
  //       debugPrint('❌ Error checking user role: $e');
  //     }
  //   }
  // }

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
      messages: _messages,
    );

    // Initialize the audio player asynchronously
    _audioPlaybackManager.initialize();
  }

  Future<void> _initializeChat() async {
    // get the current user details
    final currentUser = await _userUtils.getUserDetails();
    if (currentUser != null) {
      setState(() {
        _currentUserDetails = currentUser;
      });
    }

    // Load messages from local storage first
    final messaagesFromLocal = await _messagesRepo.getMessagesByConversation(
      widget.group.conversationId,
      limit: 100,
      offset: 0,
    );

    setState(() {
      _messages = messaagesFromLocal;
      _sortMessagesBySentAt();
      _isLoading = false;
    });

    // Load pinned message ID directly from database (not from widget.group which may be stale)
    final conversation = await _conversationRepo.getConversationById(
      widget.group.conversationId,
    );
    final currentPinnedMessageId = conversation?.pinnedMessageId;

    if (currentPinnedMessageId != null) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        currentPinnedMessageId,
      );
      if (pinnedMessage != null) {
        setState(() {
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
        await _conversationRepo.updatePinnedMessage(
          widget.group.conversationId,
          null,
        );
        setState(() {
          _pinnedMessage = null;
        });
      }
    } else {
      // Ensure _pinnedMessage is null when there's no pinned message
      setState(() {
        _pinnedMessage = null;
      });
    }

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // Send WebSocket messages in background (non-blocking, non-critical)
    final joinConvPayload = JoinLeavePayload(
      convId: widget.group.conversationId,
      convType: ChatType.group,
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
  }

  Future<void> _loadMoreMessages() async {
    // Implement loading more messages from server to local DB
    final moreMessages = await _messagesRepo.getMessagesByConversation(
      widget.group.conversationId,
      limit: 100,
      offset: _messages.length,
    );

    setState(() {
      _messages.addAll(moreMessages);
      _sortMessagesBySentAt();
    });
  }

  /// Sync all messages from server to local DB
  /// This is called when user visits the conversation for the first time
  Future<void> _syncMessagesFromServer() async {
    // Check if sync is needed
    final needSync = await _conversationRepo.getNeedSyncStatus(
      widget.group.conversationId,
    );
    if (needSync == false) {
      if (mounted) {
        setState(() {
          _isSyncingMessages = false;
          _syncProgress = 1.0;
          _syncStatus = 'Sync complete';
        });
      }
      final firstPageResponse = await _chatsServices.getConversationHistory(
        conversationId: widget.group.conversationId,
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

      // Reload messages from local DB after sync
      final syncedMessages = await _messagesRepo.getMessagesByConversation(
        widget.group.conversationId,
        limit: 100,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _messages = syncedMessages;
          _sortMessagesBySentAt();
          _isSyncingMessages = false;
          _syncProgress = 1.0;
          _syncStatus = 'Sync complete';
        });
      }

      // return early since we don't need heavy sync
      return;
    }

    // Start syncing
    if (mounted) {
      setState(() {
        _isSyncingMessages = true;
        _syncProgress = 0.0;
        _syncStatus = 'syncing messages';
        _syncedMessageCount = 0;
        _totalMessageCount = 0;
      });
    }

    try {
      int page = 1;
      const int limit = 200; // Fetch 100 messages per page
      bool hasMorePages = true;
      int totalSynced = 0;

      // First, get the first page to know total count
      final firstPageResponse = await _chatsServices.getConversationHistory(
        conversationId: widget.group.conversationId,
        page: page,
        limit: limit,
      );

      if (firstPageResponse['success'] != true ||
          firstPageResponse['data'] == null) {
        // Failed to fetch, stop syncing
        if (mounted) {
          setState(() {
            _isSyncingMessages = false;
            _syncStatus = 'Sync failed';
          });
        }
        return;
      }

      final firstPageHistory = ConversationHistoryResponse.fromJson(
        firstPageResponse['data'],
      );

      final List<ConversationMemberModel> membersOfConversation =
          firstPageHistory.members
              .map(
                (e) => ConversationMemberModel(
                  conversationId: widget.group.conversationId,
                  userId: e['user_id'],
                  role: e['group_role'],
                  unreadCount: e['unread_count'] ?? 0,
                  joinedAt: e['joined_at'],
                  removedAt: e['removed_at'],
                ),
              )
              .toList();

      await _conversationMemberRepo.insertConversationMembers(
        membersOfConversation,
      );

      await _userRepo.insertUsers(
        firstPageHistory.members
            .map(
              (e) => UserModel(
                id: e['user_id'],
                name: e['name'],
                profilePic: e['profile_pic'],
                phone: e['phone'],
                isOnline: e['is_online'] ?? false,
                role: e['user_role'],
              ),
            )
            .toList(),
      );

      _totalMessageCount = firstPageHistory.totalCount;

      if (_totalMessageCount == 0) {
        // No messages to sync
        if (mounted) {
          setState(() {
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

        if (mounted) {
          setState(() {
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
      while (hasMorePages && mounted && !_isDisposed) {
        final response = await _chatsServices.getConversationHistory(
          conversationId: widget.group.conversationId,
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
        if (mounted) {
          setState(() {
            _syncedMessageCount = totalSynced;
            _syncProgress = totalSynced / _totalMessageCount;
            _syncStatus =
                'Syncing messages... ($totalSynced/$_totalMessageCount)';
          });
        }

        hasMorePages = historyResponse.hasNextPage;
        page++;

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Sync message statuses after all messages are synced
      await _syncMessageStatuses();

      // Reload messages from local DB after sync
      if (mounted && !_isDisposed) {
        final syncedMessages = await _messagesRepo.getMessagesByConversation(
          widget.group.conversationId,
          limit: 100,
          offset: 0,
        );

        setState(() {
          _messages = syncedMessages;
          _sortMessagesBySentAt();
          _isSyncingMessages = false;
          _syncProgress = 1.0;
          _syncStatus = 'Sync complete';
        });

        // Mark sync as completed in conversations repo
        await _conversationRepo.updateNeedSyncStatus(
          widget.group.conversationId,
          false,
        );

        // Clear sync status after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_isDisposed) {
            setState(() {
              _syncStatus = '';
              _syncProgress = 0.0;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error syncing messages: $e');
      if (mounted) {
        setState(() {
          _isSyncingMessages = false;
          _syncStatus = 'Sync failed';
        });
      }
    }
  }

  /// Sync message statuses from server to local DB
  Future<void> _syncMessageStatuses() async {
    try {
      int page = 1;
      const int limit = 1000; // Fetch up to 1000 statuses per page
      bool hasMorePages = true;

      while (hasMorePages && mounted && !_isDisposed) {
        final response = await _chatsServices.getMessageStatuses(
          conversationId: widget.group.conversationId,
          page: page,
          limit: limit,
        );

        if (response['success'] == true) {
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

  // int _  parseToInt(dynamic value) {
  //   if (value == null) return 0;
  //   if (value is int) return value;
  //   if (value is String) return int.tryParse(value) ?? 0;
  //   return 0;
  // }

  /// Load pinned message from storage or conversation metadata
  // /// The above code snippet contains commented-out functions related to loading, validating, and
  /// cleaning up pinned and starred messages in a chat application.
  // Future<void> _loadPinnedMessageFromStorage() async {
  //   final conversationId = widget.group.conversationId;

  //   // First check if group metadata has pinned message
  //   if (widget.group.metadata?.pinnedMessage != null) {
  //     final pinnedMessage = widget.group.metadata!.pinnedMessage!;
  //     if (mounted) {
  //       setState(() {
  //         _pinnedMessage = pinnedMessage;
  //       });
  //       return;
  //     }
  //   }

  //   // Fallback to local storage
  //   final pinnedMessageId =
  //       await MessageStorageHelpers.loadPinnedMessageFromStorage(
  //         conversationId,
  //       );

  //   if (pinnedMessageId != null && mounted) {
  //     setState(() {
  //       _pinnedMessageId = pinnedMessageId;
  //     });
  //   }
  // }

  // /// Load starred messages from storage
  // Future<void> _loadStarredMessagesFromStorage() async {
  //   final conversationId = widget.group.conversationId;
  //   final starredMessages =
  //       await MessageStorageHelpers.loadStarredMessagesFromStorage(
  //         conversationId,
  //       );

  //   if (starredMessages.isNotEmpty && mounted) {
  //     setState(() {
  //       _starredMessages.clear();
  //       _starredMessages.addAll(starredMessages);
  //     });
  //   }
  // }

  // /// Validate pinned message exists in current messages and clean up if not
  // void _validatePinnedMessage() {
  //   // Don't validate if we don't have a full message set yet
  //   // Only validate if we've loaded a significant number of messages
  //   // This prevents clearing pinned messages during initial load or pagination
  //   if (_pinnedMessageId != null && _messages.length > 20) {
  //     final messageExists = _messages.any((msg) => msg.id == _pinnedMessageId);
  //     if (!messageExists && mounted) {
  //       debugPrint(
  //         '⚠️ Pinned message $_pinnedMessageId not found in current group messages, but keeping it (might be paginated)',
  //       );
  //       // Don't clear the pinned message - it might just be in a different page
  //       // Only clear if we explicitly receive an unpin action via WebSocket
  //     }
  //   }
  // }

  // /// Validate starred messages exist in current messages and clean up invalid ones
  // void _validateStarredMessages() {
  //   if (_starredMessages.isNotEmpty && _messages.isNotEmpty) {
  //     final currentMessageIds = _messages.map((msg) => msg.id).toSet();
  //     final invalidStarredMessages = _starredMessages
  //         .where((starredId) => !currentMessageIds.contains(starredId))
  //         .toList();

  //     if (invalidStarredMessages.isNotEmpty && mounted) {
  //       debugPrint(
  //         '⚠️ ${invalidStarredMessages.length} starred messages not found in current group messages, cleaning up',
  //       );

  //       setState(() {
  //         _starredMessages.removeAll(invalidStarredMessages);
  //       });

  //       // Update storage with cleaned up starred messages
  //       _messagesRepo.saveStarredMessages(
  //         conversationId: widget.group.conversationId,
  //         starredMessageIds: _starredMessages,
  //       );
  //     }
  //   }
  // }

  /// Validate reply messages are properly loaded and structured
  // void _validateReplyMessages() {
  //   if (_messages.isEmpty) return;

  //   Future.microtask(() async {
  //     try {
  //       // Count reply messages in current UI
  //       final replyMessagesInUI = _messages
  //           .where(
  //             (msg) =>
  //                 msg.replyToMessage != null || msg.replyToMessageId != null,
  //           )
  //           .toList();

  //       debugPrint(
  //         '🔍 Found ${replyMessagesInUI.length} reply messages in group cache',
  //       );

  //       // Validate each reply message
  //       for (final message in replyMessagesInUI) {
  //         if (message.replyToMessage != null) {
  //           debugPrint(
  //             '✅ Group reply message ${message.id} has complete reply data: "${message.replyToMessage!.body}" by ${message.replyToMessage!.senderName}',
  //           );
  //         } else if (message.replyToMessageId != null) {
  //           // Try to find the referenced message in current messages
  //           MessageModel? referencedMessage;
  //           try {
  //             referencedMessage = _messages.firstWhere(
  //               (msg) => msg.id == message.replyToMessageId,
  //             );
  //           } catch (e) {
  //             referencedMessage = null;
  //           }
  //           if (referencedMessage != null) {
  //             debugPrint(
  //               '🔗 Group reply message ${message.id} references existing message ${message.replyToMessageId}',
  //             );
  //           } else {
  //             debugPrint(
  //               '⚠️ Group reply message ${message.id} references missing message ${message.replyToMessageId}',
  //             );
  //           }
  //         }
  //       }

  //       // Validate storage
  //       await _messagesRepo.validateReplyMessageStorage(
  //         widget.group.conversationId,
  //       );
  //     } catch (e) {
  //       debugPrint('❌ Error validating group reply messages: $e');
  //     }
  //   });
  // }

  /// Cache user info from conversation metadata to local DB
  // Future<void> _cacheUsersFromMetadata() async {
  //   if (_conversationMeta == null || _conversationMeta!.members.isEmpty) return;

  //   try {
  //     for (final member in _conversationMeta!.members) {
  //       final userId = member['user_id'] as int?;
  //       final userName = member['name'] as String?;
  //       final profilePic = member['profile_pic'] as String?;

  //       if (userId != null && userName != null) {
  //         // Cache in memory
  //         _userInfoCache[userId] = {
  //           'name': userName,
  //           'profile_pic': profilePic,
  //         };

  //         // Save to group_members table (not users table) for offline access
  //         final memberInfo = GroupMemberInfo(
  //           userId: userId,
  //           userName: userName,
  //           profilePic: profilePic,
  //           role: 'member', // Default role from metadata
  //           joinedAt: null,
  //         );
  //         await _groupMembersRepo.insertOrUpdateGroupMember(
  //           widget.group.conversationId,
  //           memberInfo,
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Error caching users from metadata: $e');
  //   }
  // }

  /// Show ReadBy modal for a specific message
  Future<void> _showReadByModal(MessageModel message) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReadByModal(
        message: message,
        members: _conversationMembers,
        currentUserId: _currentUserDetails!.id,
      ),
    );
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

    if (distanceFromTop <= 1000) {
      _loadMoreMessages();
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
        currentMessage.sentAt,
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
          ChatHelpers.getMessageDateString(message.sentAt) ==
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
          ChatHelpers.formatDateSeparator(messageWithCurrentDate.sentAt),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Future<void> _loadInitialMessages() async {
  //   final conversationId = widget.group.conversationId;

  //   await loadInitialMessages(
  //     LoadInitialMessagesConfig(
  //       conversationId: conversationId,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       mounted: () => mounted,
  //       setState: setState,
  //       hasCheckedCache: () => _hasCheckedCache,
  //       getMessages: () => _messages,
  //       getConversationMeta: () => _conversationMeta,
  //       getHasMoreMessages: () => _hasMoreMessages,
  //       getCurrentPage: () => _currentPage,
  //       getIsInitialized: () => _isInitialized,
  //       getIsLoading: () => _isLoading,
  //       getErrorMessage: () => _errorMessage,
  //       getIsCheckingCache: () => _isCheckingCache,
  //       getIsLoadingFromCache: () => _isLoadingFromCache,
  //       setHasCheckedCache: (value) => _hasCheckedCache = value,
  //       setMessages: (value) => _messages = value,
  //       setConversationMeta: (value) => _conversationMeta = value,
  //       setHasMoreMessages: (value) => _hasMoreMessages = value,
  //       setCurrentPage: (value) => _currentPage = value,
  //       setIsInitialized: (value) => _isInitialized = value,
  //       setIsLoading: (value) => _isLoading = value,
  //       setErrorMessage: (value) => _errorMessage = value,
  //       setIsCheckingCache: (value) => _isCheckingCache = value,
  //       setIsLoadingFromCache: (value) => _isLoadingFromCache = value,
  //       performSmartSync: _performSmartSync,
  //       validateMessages: (messages) {
  //         _validatePinnedMessage();
  //         _validateStarredMessages();
  //         _validateReplyMessages();
  //       },
  //       populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
  //       cleanCachedMessages: (messages) {
  //         // Filter out old orphaned optimistic messages (messages with negative IDs older than 5 minutes)
  //         final now = DateTime.now();
  //         final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

  //         final cleanedMessages = messages.where((msg) {
  //           // Keep all messages with positive IDs (server-confirmed)
  //           if (msg.id >= 0) return true;

  //           // For optimistic messages (negative IDs), only keep recent ones
  //           try {
  //             final createdAt = DateTime.parse(msg.createdAt);
  //             return createdAt.isAfter(fiveMinutesAgo);
  //           } catch (e) {
  //             // If we can't parse the date, keep the message to be safe
  //             return true;
  //           }
  //         }).toList();

  //         // Remove duplicates by ID (keep the one with positive ID if both exist)
  //         final messageMap = <int, MessageModel>{};
  //         for (final msg in cleanedMessages) {
  //           final existingMsg = messageMap[msg.id.abs()];
  //           // Prefer positive IDs (server-confirmed) over negative IDs (optimistic)
  //           if (existingMsg == null || msg.id > 0) {
  //             messageMap[msg.id.abs()] = msg;
  //           }
  //         }
  //         final deduplicatedMessages = messageMap.values.toList()
  //           ..sort((a, b) => a.id.compareTo(b.id));

  //         return deduplicatedMessages;
  //       },
  //       onAfterLoadFromServer: _cacheUsersFromMetadata,
  //       getErrorMessageText: () => 'Failed to load group messages',
  //       getNoCacheMessage: () =>
  //           'ℹ️ No cached group messages found in local DB',
  //     ),
  //   );
  // }

  // Future<void> _loadMoreMessages() async {
  //   final conversationId = widget.group.conversationId;

  //   await loadMoreMessages(
  //     LoadMoreMessagesConfig(
  //       conversationId: conversationId,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       mounted: () => mounted,
  //       setState: setState,
  //       isLoadingMore: () => _isLoadingMore,
  //       hasMoreMessages: () => _hasMoreMessages,
  //       currentPage: () => _currentPage,
  //       getMessages: () => _messages,
  //       getConversationMeta: () => _conversationMeta,
  //       setIsLoadingMore: (value) => _isLoadingMore = value,
  //       setHasMoreMessages: (value) => _hasMoreMessages = value,
  //       setCurrentPage: (value) => _currentPage = value,
  //       setMessages: (value) => _messages = value,
  //       setConversationMeta: (value) => _conversationMeta = value,
  //       populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
  //       onAfterLoadMore: _cacheUsersFromMetadata,
  //     ),
  //   );
  // }

  /// Set up WebSocket message listener for real-time group messages
  void _setupWebSocketListener() {
    final convId = widget.group.conversationId;

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
    _messageDeleteSubscription = _wsMessageHandler
        .messageDeletesForConversation(convId)
        .listen(
          (payload) => _handleMessageDelete(payload),
          onError: (error) {
            debugPrint('❌ Message delete stream error: $error');
          },
        );
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

      // Check if message already exists (avoid duplicates)
      final existingIndex = _messages.indexWhere(
        (msg) =>
            msg.canonicalId == message.canonicalId ||
            msg.id == message.id ||
            (msg.optimisticId != null &&
                msg.optimisticId == message.optimisticId),
      );

      // Add message to UI immediately with animation
      if (mounted) {
        setState(() {
          if (existingIndex == -1) {
            // New message - check if it should be at the end
            if (_messages.isEmpty) {
              _messages.add(message);
            } else {
              // Compare with last message to see if this is newer
              final lastMessage = _messages.last;
              try {
                final lastTime = DateTime.parse(lastMessage.sentAt);
                final newTime = DateTime.parse(message.sentAt);
                if (newTime.isAfter(lastTime) ||
                    newTime.isAtSameMomentAs(lastTime)) {
                  // New message is newer or same time - add at end (no sort needed)
                  _messages.add(message);
                } else {
                  // Message is older - add and sort
                  _messages.add(message);
                  _sortMessagesBySentAt();
                }
              } catch (e) {
                // If parsing fails, add at end and sort to be safe
                _messages.add(message);
                _sortMessagesBySentAt();
              }
            }
          } else {
            // Message already exists - update it in place
            _messages[existingIndex] = message;
          }
        });

        if (message.id > 0) {
          _animateNewMessage(message.id);
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  void _handleMessageAck(ChatMessageAckPayload payload) async {
    try {
      // Find the message with matching optimisticId or canonicalId
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

      // Update the message with canonicalId, status, and cleared uploading state
      final updatedMessage = currentMessage.copyWith(
        canonicalId: payload.canonicalId,
        status: MessageStatusType
            .delivered, // Update to delivered when acknowledged
        metadata: updatedMetadata,
      );

      // Update in UI and DB
      if (mounted) {
        setState(() {
          _messages[messageIndex] = updatedMessage;
        });
      }

      // Save to DB
      try {
        await _messagesRepo.insertMessage(updatedMessage);
      } catch (e) {
        debugPrint('❌ Error updating message in DB: $e');
      }
    } catch (e) {
      debugPrint('❌ Error processing message_ack: $e');
    }
  }

  void _receiveTyping(TypingPayload payload) {
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

  /// Handle incoming message pin from WebSocket
  void _handleMessagePin(MessagePinPayload payload) async {
    // load pinned message from prefs and then DB
    if (payload.pin) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        payload.messageId,
      );
      setState(() {
        _pinnedMessage = pinnedMessage;
      });
    } else {
      setState(() {
        _pinnedMessage = null;
      });
    }
  }

  /// Handle message delete event from WebSocket
  // void _handleMessageDelete(Map<String, dynamic> message) async {
  //   await handleMessageDelete(
  //     HandleMessageDeleteConfig(
  //       message: message,
  //       mounted: () => mounted,
  //       setState: setState,
  //       messages: _messages,
  //       conversationId: widget.group.conversationId,
  //       messagesRepo: _messagesRepo,
  //     ),
  //   );
  // }

  void _handleMessageDelete(DeleteMessagePayload payload) async {
    // find the message in _messages and set isDeleted to true
    for (final msgId in payload.messageIds) {
      final messageIndex = _messages.indexWhere((msg) => msg.id == msgId);
      if (messageIndex != -1) {
        _messages.removeAt(messageIndex);
      }
    }
    // update UI
    if (mounted) {
      setState(() {});
    }

    // delete messages from local DB
    // await _messagesRepo.deleteMessages(payload.messageIds);
  }

  // /// Send group message with immediate display (optimistic UI)
  // void _sendMessage(
  //   MessageType messageType, {
  //   MediaResponse? mediaResponse,
  // }) async {
  //   final messageText = _messageController.text.trim();
  //   if (messageText.isEmpty) return;

  //   // Store reply message reference
  //   final replyMessage = _replyToMessageData;
  //   final replyMessageId = _replyToMessageData?.id;

  //   // Clear input and reply state immediately for better UX
  //   _messageController.clear();
  //   _cancelReply();

  //   // Clear draft when message is sent
  //   final draftNotifier = ref.read(draftMessagesProvider.notifier);
  //   await draftNotifier.removeDraft(widget.group.conversationId);

  //   // Create optimistic message for immediate display with current UTC time
  //   final nowUTC = DateTime.now().toUtc();
  //   final optimisticMessage = MessageModel(
  //     id: _optimisticMessageId, // Use negative ID for optimistic messages
  //     body: messageText,
  //     type: 'text',
  //     senderId: _currentUserId ?? 0,
  //     conversationId: widget.group.conversationId,
  //     createdAt: nowUTC
  //         .toIso8601String(), // Store as UTC, convert to IST when displaying
  //     deleted: false,
  //     senderName: 'You', // Current user name
  //     senderProfilePic: null,
  //     replyToMessage: replyMessage,
  //     replyToMessageId: replyMessageId,
  //   );

  //   // Track this as an optimistic message
  //   _optimisticMessageIds.add(_optimisticMessageId);

  //   // Add message to UI immediately with animation
  //   if (mounted) {
  //     setState(() {
  //       _messages.add(optimisticMessage);
  //       // Update sticky date separator for new messages
  //       _currentStickyDate = ChatHelpers.getMessageDateString(
  //         optimisticMessage.createdAt,
  //       );
  //       _showStickyDate = true;
  //     });

  //     _animateNewMessage(optimisticMessage.id);
  //     _scrollToBottom();
  //   }

  //   // Store message immediately in cache (optimistic storage)
  //   _storeMessageAsync(optimisticMessage);

  //   final prefs = await SharedPreferences.getInstance();
  //   final currentUserName = prefs.getString('current_user_name');
  //   try {
  //     // Check if this is a reply message
  //     if (replyMessageId != null) {
  //       debugPrint('🔄 Sending group reply message via WebSocket');
  //       // Send reply message via WebSocket
  //       await _websocketService.sendMessage({
  //         'type': 'message_reply',
  //         'data': {
  //           'new_message': messageText,
  //           'optimistic_id': _optimisticMessageId,
  //         },
  //         'conversation_id': widget.group.conversationId,
  //         'message_ids': [
  //           replyMessageId,
  //         ], // Array of message IDs being replied to
  //       });
  //     } else {
  //       // Send regular message
  //       final messageData = {
  //         'type': 'text',
  //         'body': messageText,
  //         'optimistic_id': _optimisticMessageId,
  //       };

  //       await _websocketService.sendMessage({
  //         'type': 'message',
  //         'data': messageData,
  //         'conversation_id': widget.group.conversationId,
  //         'sender_name': currentUserName,
  //       });
  //     }

  //     _optimisticMessageId--;
  //   } catch (e) {
  //     debugPrint('❌ Error sending group message: $e');
  //     _retryMessage(optimisticMessage.id);
  //     // Handle send failure - mark message as failed
  //     // _handleMessageSendFailure(optimisticMessage.id, e.toString());
  //   }
  // }

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
      conversationId: widget.group.conversationId,
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

    if (mounted) {
      setState(() {
        // New message - add at end (newest messages are at end in reverse list)
        _messages.add(newMsg);
        // No need to sort - new message is already at the correct end position
      });

      _animateNewMessage(newMsg.optimisticId!);
      _scrollToBottom();
    }

    final response = await _chatsServices.sendMediaMessage(mediaFile);
    if (response['success'] == true && response['data'] != null) {
      final mediaData = MediaResponse.fromJson(response['data']);
      // return mediaData;

      _sendMessage(
        messageType,
        mediaResponse: mediaData,
        optimisticId: optimisticId,
      );

      debugPrint('Media data: $mediaData, messageType: $messageType');
    } else {
      // Update message to show upload failed state and save to DB
      await _markMessageAsFailed(optimisticId);
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to send media message')),
        // );
      }
    }
  }

  /// Mark a message as failed in both UI and DB
  Future<void> _markMessageAsFailed(int messageId) async {
    if (!mounted) return;

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
    if (mounted) {
      setState(() {
        _messages[index] = updatedMessage;
      });
    }

    // Save to DB with failed status
    await _messagesRepo.insertMessage(updatedMessage);
  }

  /// Resend a failed message
  Future<void> _resendFailedMessage(MessageModel failedMessage) async {
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
    final index = _messages.indexWhere(
      (msg) =>
          msg.id == failedMessage.id ||
          msg.optimisticId == failedMessage.optimisticId,
    );
    if (index != -1 && mounted) {
      setState(() {
        _messages[index] = uploadingMessage;
      });
    }

    // Save uploading state to DB
    await _messagesRepo.insertMessage(uploadingMessage);

    // Resend the message
    try {
      // Use current time for the resent message
      final newSentAt = DateTime.now().toUtc();

      final messagePayload = ChatMessagePayload(
        optimisticId: failedMessage.optimisticId ?? failedMessage.id,
        convId: failedMessage.conversationId,
        senderId: failedMessage.senderId,
        senderName: failedMessage.senderName,
        attachments: failedMessage.attachments,
        convType: ChatType.group,
        msgType: failedMessage.type,
        body: failedMessage.body,
        replyToMessageId: failedMessage.metadata?['reply_to']?['message_id'],
        sentAt: newSentAt,
      );

      final wsmsg = WSMessage(
        type: WSMessageType.messageNew,
        payload: messagePayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      await _webSocket
          .sendMessage(wsmsg)
          .then((_) {
            // Clear uploading state on success
            final successMetadata = Map<String, dynamic>.from(
              uploadingMessage.metadata ?? {},
            );
            successMetadata['is_uploading'] = false;
            successMetadata.remove(
              'upload_failed',
            ); // Explicitly remove upload_failed
            // Update message with new timestamp and clear upload flags
            final successMessage = uploadingMessage.copyWith(
              sentAt: newSentAt.toIso8601String(),
              metadata: successMetadata,
            );
            // Recalculate index to ensure we update the correct message
            final currentIndex = _messages.indexWhere(
              (msg) =>
                  msg.id == failedMessage.id ||
                  msg.optimisticId == failedMessage.optimisticId,
            );
            if (currentIndex != -1 && mounted) {
              setState(() {
                // Update the message with new timestamp
                _messages[currentIndex] = successMessage;
                // Re-sort messages so the resent message appears at the bottom
                _sortMessagesBySentAt();
                // Scroll to bottom to show the resent message
                _scrollToBottom();
              });
            }
            _messagesRepo.insertMessage(successMessage);
          })
          .catchError((e) async {
            debugPrint('Error resending message: $e');
            // Mark as failed again
            await _markMessageAsFailed(failedMessage.id);
          });
    } catch (e) {
      debugPrint('Error resending message: $e');
      // Mark as failed again
      await _markMessageAsFailed(failedMessage.id);
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
    await draftNotifier.removeDraft(widget.group.conversationId);

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
        'is_loading': false,
      };
    }

    final newMsg = MessageModel(
      optimisticId: optimisticMessageId,
      conversationId: widget.group.conversationId,
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
    if (mounted) {
      setState(() {
        // If optimisticId is provided, replace the existing optimistic message
        if (optimisticId != null) {
          final index = _messages.indexWhere(
            (msg) => msg.optimisticId == optimisticId,
          );
          if (index != -1) {
            _messages[index] = newMsg;
            // Only sort if we replaced a message (might have changed position)
            _sortMessagesBySentAt();
          } else {
            // New message - add at end (newest messages are at end in reverse list)
            _messages.add(newMsg);
            // No need to sort - new message is already at the correct end position
          }
        } else {
          // New message - add at end (newest messages are at end in reverse list)
          _messages.add(newMsg);
          // No need to sort - new message is already at the correct end position
        }
      });

      _animateNewMessage(newMsg.optimisticId!);
      _scrollToBottom();
    }

    try {
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

      final messagePayload = ChatMessagePayload(
        optimisticId: optimisticMessageId,
        convId: widget.group.conversationId,
        senderId: _currentUserDetails!.id,
        senderName: _currentUserDetails!.name,
        attachments: mediaResponse,
        convType: ChatType.group,
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

      ref
          .read(chatProvider.notifier)
          .updateLastMessageOnSendingOwnMessage(
            widget.group.conversationId,
            newMsg,
          );

      // store that message in the message status table
      await _messageStatusRepo.insertMessageStatusesWithMultipleUserIds(
        messageId: newMsg.id,
        conversationId: widget.group.conversationId,
        userIds: _conversationMembers.map((member) => member.id).toList(),
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
        if (mounted) {
          setState(() {
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
    setState(() {
      // _unreadCountWhileScrolled = 0;
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
      if (mounted &&
          (!_isAtBottom
          // || _unreadCountWhileScrolled > 0
          )) {
        setState(() {
          _isAtBottom = true;
          // _unreadCountWhileScrolled = 0;
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
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      // Send inactive message when user navigates away from the page
      final typingPayload = TypingPayload(
        convId: widget.group.conversationId,
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
        debugPrint('Error sending typing indicator');
      });
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    }
  }

  void _replyToMessage(MessageModel message) {
    setState(() {
      _replyToMessageData = message;
      // _isReplying = true;
    });
  }

  void _openGroupInfo() async {
    final result = await Navigator.push(
      context,
      // MaterialPageRoute(
      //   builder: (context) => GroupInfoPage(group: widget.group),
      // ),
      SlideRightRoute(page: GroupInfoPage(group: widget.group)),
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
        actions: _selectedMessages.isNotEmpty
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
                if (_pinnedMessage != null)
                  PinnedMessageSection(
                    pinnedMessage: _messages.firstWhere(
                      (message) =>
                          message.canonicalId == _pinnedMessage?.canonicalId ||
                          message.id == _pinnedMessage?.id,
                      orElse: () => _pinnedMessage!,
                    ),
                    currentUserId: _currentUserDetails?.id ?? 0,
                    // isGroupChat: widget.group.type == ChatType.group,
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

  Widget _buildSyncProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
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
    if (_messages.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.black, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ElevatedButton(
            //   onPressed: null,
            //   child: const Text('Refresh'),
            // ),
          ],
        ),
      );
    }

    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (_messages.isEmpty && !_isLoading) {
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
            // ElevatedButton(
            //   onPressed: _loadInitialMessages,
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.white,
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 20,
            //       vertical: 10,
            //     ),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(10),
            //     ),
            //     elevation: 0,
            //   ),
            //   child: const Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
            //       SizedBox(width: 6),
            //       Text(
            //         'Refresh',
            //         style: TextStyle(
            //           color: Colors.black,
            //           fontSize: 12,
            //           fontWeight: FontWeight.normal,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      physics: const ClampingScrollPhysics(),
      cacheExtent: 500, // Cache more items for smoother scrolling
      addAutomaticKeepAlives: true, // Keep message widgets alive
      addRepaintBoundaries: true, // Optimize repainting
      itemBuilder: (context, index) {
        // if (index == 0 && _isLoadingMore) {
        //   return Container(
        //     padding: const EdgeInsets.all(16),
        //     alignment: Alignment.center,
        //     child: SizedBox(
        //       width: 20,
        //       height: 20,
        //       child: CircularProgressIndicator(
        //         strokeWidth: 2,
        //         valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[300]!),
        //       ),
        //     ),
        //   );
        // }

        // Adjust index for loading indicator
        final messageIndex = index;
        final message =
            _messages[_messages.length -
                1 -
                messageIndex]; // Show newest at bottom

        // Debug: Check user ID comparison
        final isMyMessage = message.senderId == _currentUserDetails?.id;

        // Wrap the message with a container that has a key for scrolling
        // This prevents widgets from being rebuilt incorrectly when messages are added
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

  Widget _buildMessageWithActions(MessageModel message, bool isMyMessage) {
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessage?.canonicalId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    return GestureDetector(
      onLongPress: () => _showMessageActions(message, isMyMessage),
      onTap: _selectedMessages.isNotEmpty
          ? () => _toggleMessageSelection(message.canonicalId!)
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
    if (_selectedMessages.isNotEmpty ||
        _swipeStartPosition == null ||
        _isScrolling) {
      return;
    }
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
        onRetryFailedMessage: _resendFailedMessage,
        isGroupChat: true,
        nonMyMessageBackgroundColor: Colors.grey[100]!,
        useIntrinsicWidth: false,
        useStackContainer: false,
        currentUserId: _currentUserDetails!.id,
        onReplyTap: _scrollToMessage,
        messagesRepo: _messagesRepo,
        userRepo: _userRepo,
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
          message.body ?? '',
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
          message.body ?? '',
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
          message.body ?? '',
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
    return ChatHelpers.isMediaMessage(message);
  }

  /// Handle media upload failure
  /// Handle media upload failure - update only metadata to mark as failed
  // void _handleMediaUploadFailure(MessageModel loadingMessage, String error) {
  //   if (!mounted) return;

  //   // Find the message and update only metadata
  //   final index = _messages.indexWhere((msg) => msg.id == loadingMessage.id);
  //   if (index != -1) {
  //     final failedMessage = _messages[index];
  //     final updatedMetadata = Map<String, dynamic>.from(
  //       failedMessage.metadata ?? {},
  //     );
  //     updatedMetadata['is_uploading'] = false;
  //     updatedMetadata['upload_failed'] = true;

  //     setState(() {
  //       // Use copyWith to update only metadata, explicitly preserve attachments
  //       _messages[index] = failedMessage.copyWith(
  //         metadata: updatedMetadata,
  //         attachments:
  //             failedMessage.attachments, // Explicitly preserve attachments
  //       );
  //     });
  //   }
  // }

  Future<void> _showMessageActions(
    MessageModel message,
    bool isMyMessage,
  ) async {
    final isPinned = _pinnedMessage?.canonicalId == message.id;
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
        if (_currentUserDetails != null &&
            _currentUserDetails!.role == 'staff') {
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
        onPin: () => _togglePinMessage(message),
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

  // Widget _buildMessageStatusTicks(MessageModel message) {
  //   // For group chats, show delivery status based on isDelivered
  //   if (message.isDelivered) {
  //     // Double tick - message is delivered
  //     return Icon(Icons.done_all, size: 16, color: Colors.white70);
  //   } else {
  //     // Single tick - message is sent but not delivered
  //     return Icon(Icons.done, size: 16, color: Colors.white70);
  //   }
  // }

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
          checkExistingCache: false,
          debugPrefix: 'group message',
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

  // // Media sending methods
  // void _sendImageMessage(
  //   File imageFile,
  //   String source, {
  //   MessageModel? failedMessage,
  // }) async {
  //   await sendImageMessage(
  //     SendMediaMessageConfig(
  //       mediaFile: imageFile,
  //       conversationId: widget.group.conversationId,
  //       currentUserId: _currentUserId,
  //       optimisticMessageId: _optimisticMessageId,
  //       replyToMessage: _replyToMessageData,
  //       replyToMessageId: _replyToMessageData?.id,
  //       failedMessage: failedMessage,
  //       messageType: 'image',
  //       messages: _messages,
  //       optimisticMessageIds: _optimisticMessageIds,
  //       conversationMeta: _conversationMeta,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       websocketService: _websocketService,
  //       mounted: () => mounted,
  //       setState: setState,
  //       handleMediaUploadFailure: _handleMediaUploadFailure,
  //       animateNewMessage: _animateNewMessage,
  //       scrollToBottom: _scrollToBottom,
  //       cancelReply: _cancelReply,
  //       isReplying: _isReplying,
  //     ),
  //   );

  //   // Only decrement optimistic ID if this was a new message (not a retry)
  //   if (failedMessage == null) {
  //     _optimisticMessageId--;
  //   }
  // }

  // void _sendVideoMessage(
  //   File videoFile,
  //   String source, {
  //   MessageModel? failedMessage,
  // }) async {
  //   await sendVideoMessage(
  //     SendMediaMessageConfig(
  //       mediaFile: videoFile,
  //       conversationId: widget.group.conversationId,
  //       currentUserId: _currentUserId,
  //       optimisticMessageId: _optimisticMessageId,
  //       replyToMessage: _replyToMessageData,
  //       replyToMessageId: _replyToMessageData?.id,
  //       failedMessage: failedMessage,
  //       messageType: 'video',
  //       messages: _messages,
  //       optimisticMessageIds: _optimisticMessageIds,
  //       conversationMeta: _conversationMeta,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       websocketService: _websocketService,
  //       mounted: () => mounted,
  //       setState: setState,
  //       handleMediaUploadFailure: _handleMediaUploadFailure,
  //       animateNewMessage: _animateNewMessage,
  //       scrollToBottom: _scrollToBottom,
  //       cancelReply: _cancelReply,
  //       isReplying: _isReplying,
  //     ),
  //   );

  //   // Only decrement optimistic ID if this was a new message (not a retry)
  //   if (failedMessage == null) {
  //     _optimisticMessageId--;
  //   }
  // }

  // void _sendDocumentMessage(
  //   File documentFile,
  //   String fileName,
  //   String extension, {
  //   MessageModel? failedMessage,
  // }) async {
  //   await sendDocumentMessage(
  //     SendMediaMessageConfig(
  //       mediaFile: documentFile,
  //       conversationId: widget.group.conversationId,
  //       currentUserId: _currentUserId,
  //       optimisticMessageId: _optimisticMessageId,
  //       replyToMessage: _replyToMessageData,
  //       replyToMessageId: _replyToMessageData?.id,
  //       failedMessage: failedMessage,
  //       messageType: 'document',
  //       fileName: fileName,
  //       extension: extension,
  //       messages: _messages,
  //       optimisticMessageIds: _optimisticMessageIds,
  //       conversationMeta: _conversationMeta,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       websocketService: _websocketService,
  //       mounted: () => mounted,
  //       setState: setState,
  //       handleMediaUploadFailure: _handleMediaUploadFailure,
  //       animateNewMessage: _animateNewMessage,
  //       scrollToBottom: _scrollToBottom,
  //       cancelReply: _cancelReply,
  //       isReplying: _isReplying,
  //     ),
  //   );

  //   // Only decrement optimistic ID if this was a new message (not a retry)
  //   if (failedMessage == null) {
  //     _optimisticMessageId--;
  //   }
  // }

  // Message action methods
  void _toggleMessageSelection(int messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
      } else {
        _selectedMessages.add(messageId);
      }
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
    });
  }

  void _enterSelectionMode(int messageId) {
    setState(() {
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
    setState(() {
      _pinnedMessage = wasPinned ? null : message;
    });

    await ChatHelpers.togglePinMessage(
      message: message,
      conversationId: widget.group.conversationId,
      currentPinnedMessageId: pinnedMessageId,
      setPinnedMessageId: (value) {
        // This is called inside togglePinMessage's setState, but we already updated above
        // Keep it for consistency
        _pinnedMessage = value;
      },
      currentUserId: _currentUserDetails?.id,
      setState: setState,
    );

    // Update provider state immediately for UI consistency
    ref
        .read(chatProvider.notifier)
        .updatePinnedMessageInState(
          widget.group.conversationId,
          newPinnedMessageId,
        );
  }

  void _toggleStarMessage(int messageId) async {
    await ChatHelpers.toggleStarMessage(
      messageId: messageId,
      conversationId: widget.group.conversationId,
      starredMessages: _starredMessages,
      currentUserId: _currentUserDetails?.id,
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

      ref
          .read(chatProvider.notifier)
          .handleMessageDelete(
            DeleteMessagePayload(
              messageIds: _selectedMessages.map((id) => id).toList(),
              convId: widget.group.conversationId,
              senderId: _currentUserDetails?.id ?? 0,
            ),
          )
          .catchError((e) {
            debugPrint('❌ Error deleting messages: $e');
          });

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final deleteMessagePayload = DeleteMessagePayload(
        messageIds: _selectedMessages.map((id) => id).toList(),
        convId: widget.group.conversationId,
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
      _exitSelectionMode();
    }
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
        currentConversationId: widget.group.conversationId,
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
    });
  }

  void _forwardMessage(MessageModel message) async {
    setState(() {
      _messagesToForward.clear();
      _messagesToForward.add(message.canonicalId!);
    });
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
            convId: widget.group.conversationId,
            senderId: _currentUserDetails?.id ?? 0,
          ),
        )
        .catchError((e) {
          debugPrint('❌ Error deleting messages: $e');
        });

    final deleteResponse = _isAdminOrStaff
        ? await _chatsServices.deleteMessage([messageId], _isAdminOrStaff)
        : await _chatsServices.deleteMessage([messageId]);

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final deleteMessagePayload = DeleteMessagePayload(
      messageIds: [messageId],
      convId: widget.group.conversationId,
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
      conversationId: widget.group.conversationId,
      selectedMessages: _selectedMessages,
      starredMessages: _starredMessages,
      currentUserId: _currentUserDetails?.id ?? 0,
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
      isReplying: _replyToMessageData != null,
      isSending: _isSendingMessage,
      replyToMessageData: _replyToMessageData,
      currentUserId: _currentUserDetails?.id ?? 0,
      onSendMessage: (messageType) => _sendMessage(messageType),
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
      await _sendMediaMessageToServer(voiceFile, MessageType.audio);

      // Stop recording and close modal after successful send
      await _stopRecording();

      // Close the voice recording modal
      if (mounted && failedMessage == null) {
        Navigator.of(context).pop();
      }

      // await sendRecordedVoice(
      //   SendMediaMessageConfig(
      //     mediaFile: voiceFile,
      //     conversationId: widget.group.conversationId,
      //     currentUserId: _currentUserId,
      //     optimisticMessageId: _optimisticMessageId,
      //     replyToMessage: _replyToMessageData,
      //     replyToMessageId: _replyToMessageData?.id,
      //     failedMessage: failedMessage,
      //     messageType: 'audio',
      //     duration: duration,
      //     messages: _messages,
      //     optimisticMessageIds: _optimisticMessageIds,
      //     conversationMeta: _conversationMeta,
      //     messagesRepo: _messagesRepo,
      //     chatsServices: _chatsServices,
      //     websocketService: _websocketService,
      //     mounted: () => mounted,
      //     setState: setState,
      //     handleMediaUploadFailure: _handleMediaUploadFailure,
      //     animateNewMessage: _animateNewMessage,
      //     scrollToBottom: _scrollToBottom,
      //     cancelReply: _cancelReply,
      //     isReplying: _isReplying,
      //     context: context,
      //     closeModal: failedMessage == null
      //         ? () => Navigator.of(context).pop()
      //         : null,
      //   ),
      // );

      // Only decrement optimistic ID if this was a new message (not a retry)
      // if (failedMessage == null) {
      //   _optimisticMessageId--;
      // }
    } catch (e) {
      _showErrorDialog('Failed to send voice note. Please try again.');
    }
  }

  @override
  void deactivate() {
    // Send inactive message when user navigates away from the page
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final joinConvPayload = JoinLeavePayload(
      convId: widget.group.conversationId,
      convType: ChatType.group,
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
    _isOtherTypingNotifier.dispose();
    _messageAckSubscription?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _messagePinSubscription?.cancel();
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

    // Clear active conversation when leaving the messaging screen
    ref.read(chatProvider.notifier).setActiveConversation(null, null);

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // Send inactive message when user navigates away from the page
    final joinConvPayload = JoinLeavePayload(
      convId: widget.group.conversationId,
      convType: ChatType.group,
      userId: _currentUserDetails?.id ?? 0,
      userName: _currentUserDetails?.name ?? '',
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.conversationLeave,
      payload: joinConvPayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    _webSocket.sendMessage(wsmsg).catchError((e) {
      debugPrint('❌ Error sending conversation:leave in dispose: $e');
    });
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    super.dispose();
  }
}
