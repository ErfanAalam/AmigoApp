import 'dart:async';
import 'dart:math';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
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
import '../../../models/conversations.model.dart';
import '../../../models/group.model.dart';
import '../../../models/user.model.dart';
import '../../../providers/call.provider.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../utils/message-recommendations.store.dart';
import '../../../services/fcm/fcm-init.service.dart';
import '../../../services/media-cache.service.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../services/socket/ws-message.handler.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/group-readby.modal.dart';
import '../../../ui/chat/input-container.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/message.action-sheet.dart';
import '../../../ui/chat/message-recommendations.widget.dart';
import '../../../ui/chat/sender-profile.sheet.dart';
import '../../../ui/snackbar.dart';
import '../dm/dm-messaging.screen.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/chat/audio-playback.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../ui/blurred-popup.widget.dart';
import '../../../ui/chat/add-member.sheet.dart';
import '../../../ui/chat/group-actions.dart';
import '../../../utils/route-transitions.util.dart';
import '../chat-details.screen.dart';
import '../dm/dm-media-links-docs.screen.dart';
import '../shared/chat-actions.mixin.dart';
import '../shared/chat-attachment.mixin.dart';
import '../shared/chat-bubble.mixin.dart';
import '../shared/chat-scroll.mixin.dart';
import '../shared/chat-search.mixin.dart';
import '../shared/chat-delete.mixin.dart';
import '../shared/chat-media-preview.mixin.dart';
import '../shared/chat-send.mixin.dart';
import '../shared/chat-shell.mixin.dart';
import '../shared/chat-status-ticks.mixin.dart';
import '../shared/chat-swipe-reply.mixin.dart';
import '../shared/chat-sync.mixin.dart';
import '../shared/chat-voice-recording.mixin.dart';
import '../shared/chat-websocket.mixin.dart';
import '../shared/media-message-config.builder.dart' as shared_media;

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
        ChatSyncMixin<InnerGroupChatPage>,
        ChatStatusTicksMixin<InnerGroupChatPage>,
        ChatMediaPreviewMixin<InnerGroupChatPage>,
        ChatDeleteMixin<InnerGroupChatPage>,
        ChatShellMixin<InnerGroupChatPage> {
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
  // showForwardModal is provided by ChatMediaPreviewMixin.

  @override
  String? get mediaDebugPrefix => 'group message';
  @override
  bool get mediaCheckExistingCache => false;
  @override
  String? get forwardDebugPrefix => 'group';

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
  bool get useIntrinsicWidth => false;
  @override
  bool get useStackContainer => false;
  // buildMessageStatusTicks now provided by ChatStatusTicksMixin.
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
  void Function(MessageModel message)? get onSenderNameTap =>
      _openSenderProfile;
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

  @override
  void onFirstMessagesEmitted() {
    // Position initial scroll: to the first unread if any, else to bottom.
    // Defer one frame so the list is laid out and scrollToIndex can resolve.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) scrollToFirstUnreadOrBottom();
    });
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

  List<String> _messageRecommendations = List<String>.from(
    kDefaultMessageRecommendations,
  );

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

    // Capture unread snapshot BEFORE initializeChat clears it — drives the
    // unread-separator pill and the scroll-to-first-unread initial position.
    unreadAtOpen = widget.group.unreadCount;

    // Critical-path: cheap listeners + the message stream subscription that
    // drives first paint. Anything that does I/O, sets up animation
    // controllers, or touches the audio session is deferred to post-frame.
    _scrollController.addListener(onScroll);
    _messageController.addListener(onMessageTextChanged);
    searchController.addListener(onSearchTextChanged);
    _messageFocusNode.addListener(onInputFocusChange);

    setupWebSocketListener();
    initializeChat();

    MessageRecommendationsStore.load().then((recs) {
      if (!mounted) return;
      setState(() => _messageRecommendations = recs);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService().clearConversationNotifications(
        widget.group.chatId.toString(),
      );
      // Member list isn't needed for first paint — it's used for @mentions
      // and member name resolution in long-press menus. Lazy-load it.
      getAllConversationMembers();
      _initializeTypingAnimation();
      initializeVoiceRecording();
      _initializeAudioPlayback();
      startSendAutoRetry();
      loadDraft();
    });
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
        final audioData = nextAudioMessage.attachments;
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
    return buildChatScaffold(
      appBarTitle: _buildAppBarTitle(themeColor),
      nonSelectionActions: [_buildGroupOverflowMenu()],
      selectionModeActions: buildSelectionModeActions(
        onBulkDelete: _isAdminOrStaff ? _bulkDeleteMessages : null,
      ),
      messageInput: _buildMessageInput(),
    );
  }

  Widget _buildAppBarTitle(themeColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailsScreen(group: widget.group),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: themeColor.primary.withAlpha(20),
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
                      color: Colors.black,
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

  void _openGroupInfo() async {
    final result = await Navigator.push(
      context,
      SlideRightRoute(page: ChatDetailsScreen(group: widget.group)),
    );
    // Bubble up "deleted"/"left" so the messaging screen pops itself
    // and the chat list refreshes.
    if (result is Map &&
        (result['action'] == 'deleted' || result['action'] == 'left')) {
      if (mounted) {
        Navigator.pop(context, result);
      }
    }
  }

  /// True for users who can manage the group (admin role on the group, or
  /// app-wide staff). Mirrors the gate used by the chat-details screen so
  /// "Add Members" / "Delete and leave group" appear in both places for the
  /// same set of users.
  bool get _canManageGroup =>
      widget.group.role == 'admin' || _currentUserDetails?.role == 'staff';

  void _openMediaLinksDocs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DmMediaLinksDocsScreen(group: widget.group),
      ),
    );
  }

  Future<void> _openAddMembersSheet() async {
    final existing = _conversationMembers.map((u) => u.id).toSet();
    final selected = await showAddMemberSheet(
      context: context,
      existingMemberIds: existing,
      themeColor: ref.read(themeColorProvider),
    );
    if (selected != null && selected.isNotEmpty) {
      final ok = await addMembersToGroup(
        conversationId: widget.group.chatId,
        userIds: selected,
      );
      if (ok && mounted) {
        // Refresh the in-memory member list so future menu opens see the
        // new members and don't suggest re-adding them.
        await getAllConversationMembers();
      }
    }
  }

  Future<void> _confirmDeleteAndLeaveGroup() async {
    final ok = await confirmAndDeleteGroup(
      context: context,
      ref: ref,
      conversationId: widget.group.chatId,
      groupTitle: widget.group.title,
    );
    if (ok && mounted) {
      // Pop back to the group list with the same payload chat-details uses
      // so the list refreshes consistently.
      Navigator.pop(context, {'action': 'deleted'});
    }
  }

  Widget _buildGroupOverflowMenu() {
    return BlurredPopupButton<String>(
      icon: Icons.more_vert,
      iconColor: Colors.black,
      tooltip: 'More',
      menuMaxWidth: 220,
      itemsBuilder: () => [
        const BlurredPopupAction(
          value: 'info',
          label: 'Group info',
          icon: Icons.info_outline_rounded,
        ),
        if (_canManageGroup)
          const BlurredPopupAction(
            value: 'add',
            label: 'Add members',
            icon: Icons.person_add_alt_1_rounded,
          ),
        const BlurredPopupAction(
          value: 'media',
          label: 'Media, Links & Docs',
          icon: Icons.photo_library_outlined,
        ),
        const BlurredPopupAction(
          value: 'mute',
          label: 'Mute',
          icon: Icons.notifications_off_outlined,
        ),
        if (_canManageGroup) ...[
          const BlurredPopupSeparator(),
          const BlurredPopupAction(
            value: 'delete',
            label: 'Delete and leave group',
            icon: Icons.delete_outline_rounded,
            style: BlurredPopupActionStyle.destructive,
          ),
        ],
      ],
      onSelected: (v) {
        switch (v) {
          case 'info':
            _openGroupInfo();
            break;
          case 'add':
            _openAddMembersSheet();
            break;
          case 'media':
            _openMediaLinksDocs();
            break;
          case 'mute':
            // Placeholder — menu entry is shown but the toggle isn't wired
            // up yet (intentional, matches DM screen).
            break;
          case 'delete':
            _confirmDeleteAndLeaveGroup();
            break;
        }
      },
    );
  }

  Future<void> _bulkDeleteMessages() async {
    final selectedIds = selectedMessages.toList();
    await deleteMessages(selectedIds, isAdminOrStaff: _isAdminOrStaff);
    exitSelectionMode();
  }

  Future<void> _showMessageActions(
    MessageModel message,
    bool isMyMessage,
  ) async {
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = starredMessages.contains(message.id);

    bool isAdmin = false;
    if (widget.group.role == 'admin') {
      isAdmin = true;
      _safeSetState(() {
        _isAdminOrStaff = true;
      });
    } else {
      try {
        if (_currentUserDetails != null &&
            _currentUserDetails!.role == 'staff') {
          isAdmin = true;
          _safeSetState(() {
            _isAdminOrStaff = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error checking user role: $e');
      }
    }

    if (!mounted) return;

    final myReactions = <String>[];
    if (_currentUserDetails != null) {
      final msgReactions = reactionsByMessage[message.id] ?? {};
      for (final entry in msgReactions.entries) {
        final users = (entry.value as List?) ?? [];
        if (users.any(
          (u) => u['user_id']?.toString() == _currentUserDetails!.id,
        )) {
          myReactions.add(entry.key);
        }
      }
    }

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
        onReply: () => replyToMessage(message),
        onPin: () => togglePinMessage(message),
        onStar: () => toggleStarMessage(message.id),
        onForward: () => forwardMessage(message),
        onSelect: () => enterSelectionMode(message.id),
        onReadBy: (message.senderId == _currentUserDetails?.id)
            ? () => _showReadByModal(message)
            : null,
        onDelete: isAdmin || _isAdminOrStaff
            ? () => deleteMessages([message.id], isAdminOrStaff: true)
            : null,
        onReact: (emoji) => reactToMessage(message, emoji),
        myReactions: myReactions,
      ),
    );
  }

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

  MediaMessageConfig _buildMediaMessageConfig(
    MessageModel message,
    bool isMyMessage,
  ) {
    return shared_media.buildMediaMessageConfig(
      message: message,
      isMyMessage: isMyMessage,
      isStarred: starredMessages.contains(message.id),
      mounted: () => mounted,
      onSetState: () => _safeSetState(() {}),
      showErrorDialog: showErrorDialog,
      buildMessageStatusTicks: buildMessageStatusTicks,
      onImagePreview: openImagePreviewForUrl,
      onVideoPreview: openVideoPreviewForUrl,
      onDocumentPreview: openDocumentPreviewForUrl,
      sendMediaMessageToServer: sendMediaMessageToServer,
      videoThumbnailCache: _videoThumbnailCache,
      videoThumbnailFutures: _videoThumbnailFutures,
      audioPlaybackManager: _audioPlaybackManager,
      mediaCacheService: _mediaCacheService,
      onResendFailedMessage: resendFailedMessage,
      onDeleteFailedMessage: (messageId) async {
        if (mounted) {
          _safeSetState(() {
            _messages.removeWhere((m) => m.id == messageId);
          });
        }
        await _messagesRepo.permanentlyDeleteMessage(messageId);
      },
      cacheCheckExisting: false,
      cacheDebugPrefix: 'group message',
    );
  }

  Widget _buildMessageInput() {
    if (_isRemovedFromGroup) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: Colors.grey[100],
        child: const Text(
          "You're no longer a member of this group",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: replyToMessageData != null,
      isSending: isSendingMessage,
      replyToMessageData: replyToMessageData,
      currentUserId: _currentUserDetails?.id ?? '',
      onSendMessage: sendMessage,
      // Legacy modal flow — left wired so it can be re-enabled by
      // unsetting the inline-recording callbacks below.
      onSendVoiceNote: sendVoiceNote,
      // ── New inline (WhatsApp-style) recording flow ─────────────────
      onStartInlineRecording: startInlineRecording,
      onStopInlineRecording: stopInlineRecording,
      onCancelInlineRecording: cancelInlineRecording,
      onSendInlineRecording: sendInlineRecording,
      onDiscardInlineRecording: discardInlineRecording,
      inlineRecordingTimerStream: inlineRecordingTimerStream,
      onPickGallery: handleGalleryAttachment,
      onPickCamera: handleCameraAttachment,
      onPickDocument: handleDocumentAttachment,
      onPickContact: handleContactAttachment,
      onTyping: handleTyping,
      onCancelReply: cancelReply,
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!mounted) return;
        _safeSetState(() {
          isInputFocused = isFocused;
        });
      },
      isCommunityGroup: widget.isCommunityGroup,
      communityGroupMetadata: widget.communityGroupMetadata,
      recommendations: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _messageController,
        builder: (context, value, child) {
          return MessageRecommendations(
            recommendations: _messageRecommendations,
            onRecommendationTap: onRecommendationTap,
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return ChatHelpers.buildTypingIndicator(
      typingDotAnimations: _typingDotAnimations,
      isGroupChat: true,
    );
  }

  // ── Sender profile sheet ────────────────────────────────────────────────

  /// Opens the WhatsApp-style profile sheet when the sender-name label above
  /// an other-user bubble is tapped. Resolves the user from local DB so the
  /// avatar / display name reflect the latest contact rename.
  Future<void> _openSenderProfile(MessageModel message) async {
    final senderId = message.senderId;
    if (senderId == null || senderId.isEmpty) return;
    if (senderId == _currentUserDetails?.id) return;

    final user = await _userRepo.getUserById(senderId);
    if (!mounted) return;

    final displayName =
        user?.displayName ?? (message.senderName ?? 'Unknown User');
    final profilePic = user?.profilePic ?? message.senderProfilePic;

    SenderProfileSheet.show(
      context: context,
      profilePic: profilePic,
      displayName: displayName,
      showCallActions: _currentUserDetails?.callAccess ?? true,
      onMessage: () {
        Navigator.pop(context);
        _openDmWithMember(
          userId: senderId,
          fallbackName: displayName,
          fallbackPic: profilePic,
        );
      },
      onAudioCall: () {
        Navigator.pop(context);
        _initiateCallWithMember(
          userId: senderId,
          userName: displayName,
          userProfilePic: profilePic,
          video: false,
        );
      },
      onVideoCall: () {
        Navigator.pop(context);
        _initiateCallWithMember(
          userId: senderId,
          userName: displayName,
          userProfilePic: profilePic,
          video: true,
        );
      },
    );
  }

  /// Open (or create) a DM with a group member. Mirrors the flow used by
  /// the contacts screen and `chat-details.screen.dart`'s `_messageMember`.
  Future<void> _openDmWithMember({
    required String userId,
    required String fallbackName,
    required String? fallbackPic,
  }) async {
    UserModel? user = await _userRepo.getUserById(userId);
    user ??= UserModel(
      id: userId,
      name: fallbackName,
      phone: '',
      profilePic: fallbackPic,
    );

    try {
      final result = await apiService.chat.createChat(userId);
      if (!result.isSuccess || result.data == null) {
        if (mounted) Snack.error('Failed to start chat: ${result.message}');
        return;
      }

      await _userRepo.insertUser(user);

      final data = result.data as Map<String, dynamic>;
      final convId = data['id']?.toString() ?? '';

      if (data['existing'] == true) {
        final dm = await _conversationRepo.getDmByConversationId(convId);
        if (!mounted) return;
        if (dm == null) {
          Snack.show(
            'Cannot start conversation. The chat may be deleted. Try restoring the chat.',
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InnerChatPage(dm: dm)),
        );
        return;
      }

      final dm = DmModel(
        chatId: convId,
        recipientId: user.id,
        recipientName: user.displayName,
        recipientPhone: user.phone,
        recipientProfilePic: user.profilePic,
        unreadCount: 0,
        isRecipientOnline: user.isOnline,
        createdAt: data['created_at']?.toString() ?? '',
      );

      final conversation = ConversationModel(
        id: convId,
        type: 'dm',
        unreadCount: 0,
        createrId: data['creater_id']?.toString(),
        createdAt: data['created_at']?.toString(),
      );

      await _conversationRepo.insertConversations([conversation]);
      await _conversationMemberRepo.insertConversationMembers([
        ConversationMemberModel(
          chatId: convId,
          userId: user.id,
          role: 'member',
          joinedAt: data['created_at']?.toString(),
        ),
      ]);
      await ref.read(chatProvider.notifier).addNewDm(dm);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InnerChatPage(dm: dm)),
      );
    } catch (e) {
      if (mounted) Snack.error('Failed to start chat: $e');
    }
  }

  /// Place an audio / video call directly from the sender profile sheet.
  Future<void> _initiateCallWithMember({
    required String userId,
    required String userName,
    required String? userProfilePic,
    required bool video,
  }) async {
    try {
      await ref
          .read(callServiceProvider.notifier)
          .initiateCall(userId, userName, userProfilePic, video: video);
    } catch (e) {
      if (mounted) {
        Snack.error(
          'Failed to start call: Please check your internet connection',
        );
      }
    }
  }
}
