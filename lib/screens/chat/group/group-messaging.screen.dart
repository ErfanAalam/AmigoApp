import 'dart:async';
import 'dart:math';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../models/community.model.dart';
import '../../../models/group.model.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/draft-message.service.dart';
import '../../../services/fcm/fcm-init.service.dart';
import '../../../services/media-cache.service.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../services/socket/ws-message.handler.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/forward-message.widget.dart';
import '../../../ui/chat/group-readby.modal.dart';
import '../../../ui/chat/input-container.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/message.action-sheet.dart';
import '../../../ui/chat/pinned-message.widget.dart';
import '../../../ui/chat/chat-pills.widget.dart';
import '../../../ui/chat/scroll-to-bottom.button.dart';
import '../../../ui/chat/message-recommendations.widget.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/chat/audio-playback.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../utils/chat/forward-message.utils.dart';
import '../../../utils/chat/preview-media.utils.dart';
import '../../../utils/route-transitions.util.dart';
import 'group-info.screen.dart';
import '../chat-details.screen.dart';
import '../shared/chat-actions.mixin.dart';
import '../shared/chat-attachment.mixin.dart';
import '../shared/chat-bubble.mixin.dart';
import '../shared/chat-scroll.mixin.dart';
import '../shared/chat-search.mixin.dart';
import '../shared/chat-send.mixin.dart';
import '../shared/chat-swipe-reply.mixin.dart';
import '../shared/chat-sync.mixin.dart';
import '../shared/chat-voice-recording.mixin.dart';
import '../shared/chat-websocket.mixin.dart';
import '../shared/media-message-config.builder.dart' as shared_media;

part 'group-messaging.ws.part.dart';
part 'group-messaging.sync.part.dart';
part 'group-messaging.send.part.dart';
part 'group-messaging.actions.part.dart';
part 'group-messaging.ui.part.dart';

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

// Star feature is dropped on the backend. Keep all star UI reachable behind
// a compile-time flag so it can be restored without restructuring the screen.
const bool _starEnabled = false;

class _InnerGroupChatPageState extends ConsumerState<InnerGroupChatPage>
    with
        TickerProviderStateMixin,
        ChatSearchMixin<InnerGroupChatPage>,
        ChatSwipeReplyMixin<InnerGroupChatPage>,
        ChatAttachmentMixin<InnerGroupChatPage>,
        ChatActionsMixin<InnerGroupChatPage>,
        ChatVoiceRecordingMixin<InnerGroupChatPage>,
        ChatScrollMixin<InnerGroupChatPage>,
        ChatBubbleMixin<InnerGroupChatPage>,
        ChatSendMixin<InnerGroupChatPage>,
        ChatWebSocketMixin<InnerGroupChatPage>,
        ChatSyncMixin<InnerGroupChatPage> {
  // final GroupsService _groupsService = GroupsService();
  // final UserService _userService = UserService();
  final apiService = ApiService();
  final MessageRepository _messagesRepo = MessageRepository();
  final ConversationRepository _conversationRepo = ConversationRepository();
  final UserRepository _userRepo = UserRepository();
  final AutoScrollController _scrollController = AutoScrollController(
    suggestedRowHeight: 100,
  );
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final TransportManager _transportManager = TransportManager();
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

  // Drift watch-streams (messages, reactions, delivery statuses) +
  // sync flags (isSyncingMessages, hasMoreOnServer, isLoadingMore)
  // live on ChatSyncMixin.

  // Automatic resend state variable - initialized to true to disable manual resend until initialization completes
  bool _isResendingFailedMessages = true;
  // resendingFailedMessages map lives on ChatSendMixin.

  List<UserModel> _conversationMembers = [];

  bool _isTyping = false;
  // isSendingMessage lives on ChatSendMixin.
  // lastSentReadMsgId lives on ChatWebSocketMixin.
  bool _isRemovedFromGroup = false;
  bool _isAdminOrStaff = false;
  // bool _isOtherTyping = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);
  bool _isDisposed = false;

  bool get _canSetState => mounted && !_isDisposed;

  void _safeSetState(VoidCallback fn) {
    if (_canSetState) {
      setState(fn);
    }
  }

  // ChatSearchMixin requirements
  @override
  bool get canSetState => _canSetState;
  @override
  void safeSetState(VoidCallback fn) => _safeSetState(fn);
  @override
  List<MessageModel> get messages => _messages;
  @override
  set messages(List<MessageModel> value) => _messages = value;
  @override
  TextEditingController get messageController => _messageController;
  @override
  FocusNode get messageFocusNode => _messageFocusNode;
  // scrollToMessage is provided concretely by ChatScrollMixin.
  // sendMessage is provided concretely by ChatSendMixin.

  // ChatSwipeReplyMixin requirements
  @override
  Set<String> get selectedMessageIds => selectedMessages;
  @override
  void onSwipeReply(MessageModel message) => replyToMessage(message);

  // ChatAttachmentMixin requirements
  @override
  ImagePicker get imagePicker => _imagePicker;
  // sendMediaMessageToServer concrete is provided by ChatSendMixin; the
  // sibling-mixin abstracts (ChatAttachment, ChatBubble, ChatVoiceRecording)
  // are satisfied by that concrete.

  // ChatActionsMixin requirements
  @override
  String get conversationId => widget.group.chatId;
  @override
  String? get currentUserId => _currentUserDetails?.id;
  @override
  String? get currentUserName => _currentUserDetails?.name;
  @override
  String? get currentUserProfilePic => _currentUserDetails?.profilePic;
  @override
  MessageStatusRepository get messageStatusRepo => _messageStatusRepo;
  @override
  ApiService get chatApiService => apiService;
  @override
  MessageModel? get pinnedMessage => _pinnedMessage;
  @override
  void setPinnedMessage(MessageModel? message) => _pinnedMessage = message;
  // reactionsByMessage now lives on ChatSyncMixin (shared with delivery-status
  // streams).
  @override
  Future<void> showForwardModal() => _showForwardModal();

  // ChatVoiceRecordingMixin requirements
  @override
  String get voiceFilePrefix => 'group_voice_note_';

  // ChatScrollMixin requirements
  @override
  AutoScrollController get scrollController => _scrollController;
  // loadMoreMessages now lives on ChatSyncMixin.
  @override
  String get scrollDebugPrefix => '[Group]';
  @override
  int get loadMoreDistanceFromTop => 1000;

  // ChatBubbleMixin requirements
  @override
  bool get isGroupChat => true;
  @override
  Color get nonMyMessageBackgroundColor => Colors.grey[100]!;
  @override
  bool get useIntrinsicWidth => false;
  @override
  bool get useStackContainer => false;
  @override
  Widget buildMessageStatusTicks(MessageModel message) =>
      _buildMessageStatusTicks(message);
  @override
  void showMessageActions(MessageModel message, bool isMyMessage) =>
      _showMessageActions(message, isMyMessage);
  @override
  MediaMessageConfig buildMediaMessageConfig(
    MessageModel message,
    bool isMyMessage,
  ) => _buildMediaMessageConfig(message, isMyMessage);
  @override
  MessageRepository get messagesRepo => _messagesRepo;
  @override
  UserRepository get userRepo => _userRepo;
  @override
  Future<void> Function(String) get onResendFailedMessage =>
      resendFailedMessage;
  @override
  MediaCacheService get mediaCacheService => _mediaCacheService;
  @override
  Map<String, String?> get videoThumbnailCache => _videoThumbnailCache;
  @override
  Map<String, Future<String?>> get videoThumbnailFutures =>
      _videoThumbnailFutures;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;
  // isLoadingMore now lives on ChatSyncMixin.

  // ChatSendMixin requirements
  // sortMessagesBySentAt is provided by ChatSyncMixin.
  @override
  TransportManager get transportManager => _transportManager;
  @override
  List<String> get statusAckRecipientIds => _conversationMembers
      .where((member) => member.id != _currentUserDetails?.id)
      .map((member) => member.id)
      .toList();
  @override
  String? get sendMessageBlockedReason =>
      _isRemovedFromGroup ? 'user removed from group' : null;

  // ChatSyncMixin requirements
  @override
  ConversationRepository get conversationsRepo => _conversationRepo;
  @override
  ConversationMemberRepository get conversationMemberRepo =>
      _conversationMemberRepo;
  @override
  UserUtils get userUtils => _userUtils;
  @override
  String? get serverLatestMsgId => widget.group.lastMsgId;
  @override
  ChatType get conversationType => ChatType.group;
  @override
  void setCurrentUserDetails(UserModel? user) => _currentUserDetails = user;

  // ChatSyncMixin hooks — group-specific concerns. The DM defaults are no-ops.
  @override
  Future<void> onBeforeChatInit() async {
    _checkRemovedState();
  }

  @override
  void onMessagesStreamUpdate() {
    // memberRemoved WS events trigger the chat provider to soft-delete the
    // chat row; re-check after each batch so the input bar locks itself.
    _checkRemovedState();
  }

  // ChatWebSocketMixin requirements
  @override
  WebSocketMessageHandler get wsMessageHandler => _wsMessageHandler;
  @override
  ValueNotifier<bool> get isOtherTypingNotifier => _isOtherTypingNotifier;
  @override
  AnimationController get typingAnimationController =>
      _typingAnimationController;

  // Group strips down the media-preview ticks to a simple sent/failed glyph
  // — the preview doesn't surface the per-member read counts that the bubble
  // ticks show in the messages list.
  @override
  Widget mediaPreviewStatusTicks(MessageModel message) {
    if (message.isFailed) {
      return const Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
    return const Icon(Icons.done_all, size: 16, color: Colors.white70);
  }

  // isAtBottom, lastScrollPosition live on ChatScrollMixin.
  // int _unreadCountWhileScrolled = 0;
  // int _previousMessageCount = 0;

  // Drift watch-streams live on ChatSyncMixin. WebSocket subscriptions
  // (message/sent-ack/typing/pin/delete + transport reconnect) live on
  // ChatWebSocketMixin.
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
        sendMessage(MessageType.text);
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

  // selectedMessages, starredMessages, messagesToForward, replyToMessageData,
  // and isLoadingConversations live on ChatActionsMixin.
  MessageModel? _pinnedMessage; // Only one message can be pinned

  // pendingContactMetadata lives on ChatAttachmentMixin.
  // bool _isReplying = false;

  // Highlight timer, isLoadingTargetMessage, jump-mode state, displayMessages
  // getter, message-animation maps, draft / sticky-date debounce timers,
  // and isAtBottom / lastScrollPosition all live on ChatScrollMixin.

  // GlobalKeys for message widgets to enable accurate scrolling
  final Map<String, GlobalKey> _messageKeys = {};

  // Sticky-date state lives on ChatScrollMixin (currentStickyDate, showStickyDate).

  // Typing animation controllers
  late AnimationController _typingAnimationController;
  late List<Animation<double>> _typingDotAnimations;
  // typingTimeout and lastTypingMessageSent live on ChatWebSocketMixin.

  // Search state lives on ChatSearchMixin (isSearchMode, searchController,
  // searchMatches, currentMatchIndex, searchDebounceTimer, isInputFocused,
  // highlightedMessageId, highlightedMessageIds).

  final List<String> _messageRecommendations = [
    'Hi',
    'Hello',
    'Done',
    'Bye',
    'Ok',
    'Thanks',
    'Sure',
    'Yes',
    'No',
    'Maybe',
  ];

  // Swipe animation controllers, gesture state, and constants live on
  // ChatSwipeReplyMixin (swipeAnimationControllers, swipeAnimations,
  // swipeStartPosition, isSwipeGesture, isScrolling).

  // Voice recording state lives on ChatVoiceRecordingMixin.
  late AudioPlaybackManager _audioPlaybackManager;

  // Video thumbnail cache
  final Map<String, String?> _videoThumbnailCache = {};
  final Map<String, Future<String?>> _videoThumbnailFutures = {};

  Future<void> getAllConversationMembers() async {
    final members = await _conversationMemberRepo
        .getMembersWithUserDetailsByConversationId(widget.group.chatId);
    _safeSetState(() {
      _conversationMembers = members;
    });
  }

  /// Whether the current user has been removed from this group.
  /// `_handleConversationAction` in chat.provider sets `deletedAt` on the
  /// chat row when the current user appears in the removed-members list.
  Future<void> _checkRemovedState() async {
    final conv = await _conversationRepo.getConversationById(
      widget.group.chatId,
    );
    final removed = conv?.deletedAt != null;
    if (mounted && _isRemovedFromGroup != removed) {
      _safeSetState(() => _isRemovedFromGroup = removed);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(onScroll);

    // Clear notifications for this conversation when opened
    NotificationService().clearConversationNotifications(
      widget.group.chatId.toString(),
    );

    // _websocketService.connect(widget.group.chatId);

    getAllConversationMembers();

    // Initialize typing animation
    _initializeTypingAnimation();

    // Initialize voice recording animations + manager (mixin-owned)
    initializeVoiceRecording();
    _initializeAudioPlayback();

    // Periodically retry failed messages while the screen is open (handles
    // the "transport stable, but a media upload failed" case that
    // MessageGarbageCollector can't because it can't re-upload files).
    startSendAutoRetry();

    // Set up WebSocket message listener
    setupWebSocketListener();

    // Start initialization immediately
    initializeChat();

    // Load draft message for this conversation
    loadDraft();

    // Check admin or staff status
    // _updateIsAdminOrStaff();

    // Listen to text changes for draft saving
    _messageController.addListener(onMessageTextChanged);

    // Listen to search text changes
    searchController.addListener(onSearchTextChanged);

    // Listen to focus changes
    _messageFocusNode.addListener(onInputFocusChange);
  }

  void _initializeTypingAnimation() {
    final result = initializeTypingDotAnimation(this);
    _typingAnimationController = result.controller;
    _typingDotAnimations = result.dotAnimations;
  }

  void _initializeAudioPlayback() {
    _audioPlaybackManager = AudioPlaybackManager(
      vsync: this,
      mounted: () => mounted,
      setState: () => setState(() {}),
      showErrorDialog: showErrorDialog,
      mediaCacheService: _mediaCacheService,
      messages: _messages,
      onAudioFinished: _handleAudioFinished,
    );
    _audioPlaybackManager.initialize();
  }

  /// Handle audio finished - auto-play next consecutive audio message
  void _handleAudioFinished(String finishedAudioKey) {
    try {
      // Extract message ID from audioKey (format: messageId_url)
      final messageId = finishedAudioKey.split('_').first;

      if (messageId.isEmpty) return;

      // Find the current message index
      final currentIndex = _messages.indexWhere((msg) => msg.id == messageId);

      if (currentIndex == -1) return;

      // Find the next audio message (check messages after current one)
      // Messages are sorted by sentAt, so we check forward in the list
      MessageModel? nextAudioMessage;
      for (int i = currentIndex + 1; i < _messages.length; i++) {
        final message = _messages[i];
        // Check if it's an audio message
        if (message.type == MessageType.audio ||
            (message.attachments != null &&
                (message.attachments as Map<String, dynamic>)['category']
                        ?.toString()
                        .toLowerCase() ==
                    'audios')) {
          nextAudioMessage = message;
          break;
        }
      }

      // If found, auto-play the next audio message
      if (nextAudioMessage != null) {
        final audioData = nextAudioMessage.attachments as Map<String, dynamic>?;
        final audioUrl = audioData?['url'] as String?;

        if (audioUrl != null && audioUrl.isNotEmpty) {
          // Play a notification tone to indicate next audio is starting
          try {
            FlutterRingtonePlayer().playNotification(asAlarm: false);
          } catch (e) {
            debugPrint('⚠️ Could not play notification tone: $e');
            // Fallback to system sound
            try {
              SystemSound.play(SystemSoundType.alert);
            } catch (e2) {
              debugPrint('⚠️ Could not play system sound: $e2');
            }
          }

          // Small delay before playing next audio for better UX
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              final nextAudioKey = '${nextAudioMessage!.id}_$audioUrl';
              _audioPlaybackManager.togglePlayback(
                nextAudioKey,
                audioUrl,
                onError: (error) {
                  debugPrint('❌ Error auto-playing next audio: $error');
                },
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling audio finished: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      appBar: AppBar(
        leading: selectedMessages.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: exitSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: isSearchMode
            ? buildSearchBar(themeColor)
            : selectedMessages.isNotEmpty
            ? Text(
                '${selectedMessages.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ChatDetailsScreen(group: widget.group),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.group.title.isNotEmpty
                            ? widget.group.title[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: themeColor.primary,
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
              ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        actions: selectedMessages.isNotEmpty
            ? _buildSelectionModeActions()
            : [
                // Search button
                // IconButton(
                //   icon: const Icon(Icons.search, color: Colors.white),
                //   onPressed: _toggleSearchMode,
                //   tooltip: 'Search messages',
                // ),
                IconButton(
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                  ),
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
                if (_pinnedMessage != null && _pinnedMessage!.id.isNotEmpty)
                  PinnedMessageSection(
                    pinnedMessage: _messages.firstWhere(
                      (message) => message.id == _pinnedMessage?.id,
                      orElse: () => _pinnedMessage!,
                    ),
                    currentUserId: _currentUserDetails?.id ?? '',
                    // isGroupChat: widget.group.type == ChatType.group,
                    onTap: () => scrollToMessage(_pinnedMessage?.id ?? ''),
                    onUnpin: () => togglePinMessage(_pinnedMessage!),
                  ),

                // Messages List
                Expanded(child: buildMessagesList()),

                // Message Input (includes typing indicator, recommendations, and input field)
                _buildMessageInput(),
              ],
            ),

            // Loading-target-message pill
            if (isLoadingTargetMessage)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: _buildLoadingTargetPill(),
              ),
            // Sync indicator pill - above date separator
            if (isSyncingMessages && !isLoadingTargetMessage)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: _buildSyncProgressBar(),
              ),
            // Sticky Date Separator - shifts down when sync pill is visible
            Positioned(
              top:
                  (isSyncingMessages ||
                      isLoadingTargetMessage ||
                      isInJumpMode)
                  ? 54
                  : 10,
              left: 0,
              right: 0,
              child: buildStickyDateSeparator(),
            ),
            // Scroll to Bottom Button - positioned at right bottom
            Positioned(
              right: 16,
              bottom: replyToMessageData != null
                  ? 150.0
                  : 110.0, // Position above message input
              child: ScrollToBottomButton(
                scrollController: _scrollController,
                onTap: handleScrollToBottomTap,
                isAtBottom: isAtBottom,
                // unreadCount: _unreadCountWhileScrolled > 0
                //     ? _unreadCountWhileScrolled
                //     : null,
                bottomPadding:
                    0.0, // Not used anymore, positioning handled by parent
              ),
            ),
            // "Return to Latest" — visible only in jump mode
            if (isInJumpMode)
              Positioned(
                top: (isSyncingMessages || isLoadingTargetMessage) ? 54 : 10,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: exitJumpMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Return to latest',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void deactivate() {
    // Deactivate is called when user navigates away from the page.
    // conversationLeave was removed; the server now infers leave from
    // the absence of heartbeat / next join.
    super.deactivate();
  }

  @override
  void dispose() {
    if (_isDisposed) return; // Prevent multiple dispose calls
    _isDisposed = true;
    jumpMessages = [];
    isInJumpMode = false;

    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    disposeSearch();
    _isOtherTypingNotifier.dispose();
    _typingAnimationController.dispose();
    // Drift watch-streams (messages / reactions / delivery statuses).
    disposeSync();
    // WS subscriptions + typing timeout (mixin-owned).
    disposeWebSocketListener();

    // Clear message keys
    _messageKeys.clear();

    // Save draft before disposing
    if (_messageController.text.isNotEmpty) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.group.chatId, _messageController.text);
    }

    // Remove listener
    _messageController.removeListener(onMessageTextChanged);

    // Scroll-mixin-owned timers + message-animation controllers.
    disposeScroll();

    disposeSwipeReply();

    // Dispose audio playback manager
    _audioPlaybackManager.dispose();

    // Dispose voice recording (mixin-owned)
    disposeVoiceRecording();

    // Stop the periodic failed-message retry timer.
    stopSendAutoRetry();

    // Clear active conversation when leaving the messaging screen
    ref.read(chatProvider.notifier).setActiveConversation(null, null);

    // conversationLeave was removed; the server infers leave from
    // the absence of heartbeat / next join.

    super.dispose();
  }
}
