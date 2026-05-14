import 'dart:async';
import 'package:amigo/api/api_service.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/providers/call.provider.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../db/repositories/conversation-member.repo.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../utils/message-recommendations.store.dart';
import '../../../services/fcm/fcm-init.service.dart';
import '../../../services/media-cache.service.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../services/socket/ws-message.handler.dart';
import '../../../services/user-status.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/blurred-dialog.widget.dart';
import '../../../ui/blurred-popup.widget.dart';
import '../../../ui/snackbar.dart';
import '../../../ui/chat/input-container.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/message.action-sheet.dart';
import '../../../ui/chat/message-recommendations.widget.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/chat/audio-playback.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
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
import 'dm-details.screen.dart';
import 'dm-media-links-docs.screen.dart';

class InnerChatPage extends ConsumerStatefulWidget {
  final DmModel dm;
  const InnerChatPage({super.key, required this.dm});

  @override
  ConsumerState<InnerChatPage> createState() => _InnerChatPageState();
}

class _InnerChatPageState extends ConsumerState<InnerChatPage>
    with
        TickerProviderStateMixin,
        ChatSearchMixin<InnerChatPage>,
        ChatSwipeReplyMixin<InnerChatPage>,
        ChatAttachmentMixin<InnerChatPage>,
        ChatActionsMixin<InnerChatPage>,
        ChatVoiceRecordingMixin<InnerChatPage>,
        ChatScrollMixin<InnerChatPage>,
        ChatBubbleMixin<InnerChatPage>,
        ChatSendMixin<InnerChatPage>,
        ChatWebSocketMixin<InnerChatPage>,
        ChatSyncMixin<InnerChatPage>,
        ChatStatusTicksMixin<InnerChatPage>,
        ChatMediaPreviewMixin<InnerChatPage>,
        ChatDeleteMixin<InnerChatPage>,
        ChatShellMixin<InnerChatPage> {
  final apiService = ApiService();
  final ConversationRepository _conversationsRepo = ConversationRepository();
  final MessageRepository _messagesRepo = MessageRepository();
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();
  final UserRepository _userRepo = UserRepository();
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();
  final AutoScrollController _scrollController = AutoScrollController(
    suggestedRowHeight: 100,
  );
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final TransportManager _transportManager = TransportManager();
  final WebSocketMessageHandler _wsMessageHandler = WebSocketMessageHandler();
  final ImagePicker _imagePicker = ImagePicker();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  final UserUtils _userUtils = UserUtils();

  // stream subscriptions
  StreamSubscription<ConnectionStatusPayload>? _onlineStatusSubscription;
  StreamSubscription<ConvJoinPayload>? _joinConvSubscription;
  // Drift watch-streams (messages, reactions, delivery statuses) +
  // sync flags (isSyncingMessages, hasMoreOnServer, isLoadingMore)
  // live on ChatSyncMixin. WebSocket subscriptions live on
  // ChatWebSocketMixin.

  // State variables
  bool _isLoading = false;
  List<MessageModel> _messages = [];
  MessageModel? _pinnedMessage;
  UserModel? _currentUserDetails;

  // Typing animation controllers
  late AnimationController _typingAnimationController;
  late List<Animation<double>> _typingDotAnimations;

  // Voice recording state lives on ChatVoiceRecordingMixin.
  late AudioPlaybackManager _audioPlaybackManager;

  // draftSaveTimer lives on ChatScrollMixin.

  // bool _isTyping = false;
  // isSendingMessage lives on ChatSendMixin.
  // lastSentReadMsgId lives on ChatWebSocketMixin.
  // bool isloadingMediamessage = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);

  // isAtBottom and lastScrollPosition live on ChatScrollMixin.

  bool _isDisposed = false; // Track if the page is being disposed

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
  String get conversationId => widget.dm.chatId;
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

  // ChatVoiceRecordingMixin requirements
  @override
  String get voiceFilePrefix => 'voice_note_';
  @override
  String get voiceRecordingTextPrefix => 'Still Recording';
  @override
  Color get voiceSendButtonColor => Colors.green;

  // ChatScrollMixin requirements
  @override
  AutoScrollController get scrollController => _scrollController;
  // loadMoreMessages now lives on ChatSyncMixin.
  @override
  String get scrollDebugPrefix => '[DM]';

  // ChatBubbleMixin requirements (DM uses the defaults for layout flags;
  // it just needs to opt out of group mode and supply its bubble repos).
  @override
  bool get isGroupChat => false;
  @override
  String? get conversationUserId => widget.dm.recipientId;
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
  List<String> get statusAckRecipientIds => <String>[widget.dm.recipientId];

  // ChatSyncMixin requirements
  @override
  ConversationRepository get conversationsRepo => _conversationsRepo;
  @override
  ConversationMemberRepository get conversationMemberRepo =>
      _conversationMemberRepo;
  @override
  UserUtils get userUtils => _userUtils;
  @override
  String? get serverLatestMsgId => widget.dm.lastMsgId;
  @override
  ChatType get conversationType => ChatType.dm;
  @override
  void setCurrentUserDetails(UserModel? user) => _currentUserDetails = user;

  @override
  void onFirstMessagesEmitted() {
    // Position initial scroll: to first unread if any, else to bottom.
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

  // selectedMessages, starredMessages, messagesToForward, replyToMessageData,
  // and isLoadingConversations live on ChatActionsMixin.

  // resendingFailedMessages map lives on ChatSendMixin.

  // replyToMessageData lives on ChatActionsMixin.

  // pendingContactMetadata lives on ChatAttachmentMixin.

  // Scroll, jump-mode, message-animation, draft-save, sticky-date debounce,
  // and highlight-timer state all live on ChatScrollMixin (highlightTimer,
  // isLoadingTargetMessage, isInJumpMode, jumpMessages, jumpHas*, isLoadingJump*,
  // isScrollingToJumpTarget, displayMessages getter, messageAnimation*,
  // animatedMessages, draftSaveTimer, scrollDebounceTimer).

  // GlobalKeys for message widgets to enable accurate scrolling
  final Map<String, GlobalKey> _messageKeys = {};

  // Search state lives on ChatSearchMixin (isSearchMode, searchController,
  // searchMatches, currentMatchIndex, searchDebounceTimer, isInputFocused,
  // highlightedMessageId, highlightedMessageIds).

  List<String> _messageRecommendations = List<String>.from(
    kDefaultMessageRecommendations,
  );

  // Sticky-date state lives on ChatScrollMixin (currentStickyDate, showStickyDate).

  // typingTimeout and lastTypingMessageSent live on ChatWebSocketMixin.

  // Swipe animation controllers, gesture state, and constants live on
  // ChatSwipeReplyMixin (swipeAnimationControllers, swipeAnimations,
  // swipeStartPosition, isSwipeGesture, isScrolling).

  //
  // // Video thumbnail cache
  final Map<String, String?> _videoThumbnailCache = {};
  final Map<String, Future<String?>> _videoThumbnailFutures = {};

  @override
  void initState() {
    super.initState();

    // Capture unread snapshot BEFORE initializeChat clears it — drives the
    // unread-separator pill and the scroll-to-first-unread initial position.
    unreadAtOpen = widget.dm.unreadCount ?? 0;

    // Critical-path: things the first frame and the message stream depend on.
    // Listener registrations are O(1) and don't trigger work — keep inline.
    _scrollController.addListener(onScroll);
    _messageController.addListener(onMessageTextChanged);
    searchController.addListener(onSearchTextChanged);
    _messageFocusNode.addListener(onInputFocusChange);

    setupWebSocketListener();
    // initializeChat() subscribes the messages-stream listener which flips
    // `isLoading` → false on first emission, so the skeleton can clear.
    initializeChat();

    MessageRecommendationsStore.load().then((recs) {
      if (!mounted) return;
      setState(() => _messageRecommendations = recs);
    });

    // Everything else can wait until after the first frame paints — these
    // touch the audio session, kick off DB reads (drafts), or set up timers
    // / animation controllers that only matter once the UI is interactive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService().clearConversationNotifications(widget.dm.chatId);
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
      setState: () => _safeSetState(() {}),
      showErrorDialog: showErrorDialog,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
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
  double? get appBarTitleSpacing => 0;

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    return buildChatScaffold(
      appBarTitle: _buildAppBarTitle(themeColor),
      nonSelectionActions: [
        if (_currentUserDetails?.callAccess == true) ...[
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.black),
            tooltip: 'Video call',
            onPressed: _confirmAndInitiateVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black),
            tooltip: 'Voice call',
            onPressed: _confirmAndInitiateVoiceCall,
          ),
        ],
        _buildDmOverflowMenu(),
      ],
      selectionModeActions: buildSelectionModeActions(),
      messageInput: _buildMessageInput(),
    );
  }

  /// Trailing 3-dot menu in the DM app bar. Sits to the right of the call
  /// button so the call CTA stays the most prominent action.
  Widget _buildDmOverflowMenu() {
    return BlurredPopupButton<String>(
      icon: Icons.more_vert,
      iconColor: Colors.black,
      tooltip: 'More',
      menuMaxWidth: 200,
      itemsBuilder: () => const [
        BlurredPopupAction(
          value: 'view',
          label: 'View Contact',
          icon: Icons.person_outline_rounded,
        ),
        BlurredPopupAction(
          value: 'media',
          label: 'Media, Links & Docs',
          icon: Icons.photo_library_outlined,
        ),
        BlurredPopupAction(
          value: 'mute',
          label: 'Mute',
          icon: Icons.notifications_off_outlined,
        ),
      ],
      onSelected: (v) {
        switch (v) {
          case 'view':
            _openDmDetails();
            break;
          case 'media':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DmMediaLinksDocsScreen(dm: widget.dm),
              ),
            );
            break;
          case 'mute':
            // Placeholder — wiring deferred until the per-DM mute toggle
            // gets its own UX pass.
            break;
        }
      },
    );
  }

  /// Opens DM details and pops this messaging screen back to the chat list
  /// when the details screen returns `{action: 'deleted'}` — same bubble-up
  /// pattern group-messaging uses for the leave/delete flow.
  Future<void> _openDmDetails() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DmDetailsScreen(dm: widget.dm)),
    );
    if (mounted && result is Map && result['action'] == 'deleted') {
      Navigator.pop(context, result);
    }
  }

  /// Confirms and starts a voice call. Both call types now have their own
  /// AppBar button + dedicated confirmation dialog so users don't have to
  /// tap through the legacy combined picker.
  Future<void> _confirmAndInitiateVoiceCall() async {
    final ok = await showBlurredConfirm(
      context: context,
      title: 'Voice call ${widget.dm.recipientName}?',
      message:
          'Start a voice call with ${widget.dm.recipientName}.',
      confirmLabel: 'Call',
      confirmIcon: Icons.call_rounded,
    );
    if (ok != true || !mounted) return;
    await _initiateCall(
      widget.dm.recipientId,
      widget.dm.recipientName,
      widget.dm.recipientProfilePic,
      video: false,
    );
  }

  /// Confirms and starts a video call. Mirrors the voice flow but kicks
  /// off `_initiateCall` with `video: true`.
  Future<void> _confirmAndInitiateVideoCall() async {
    final ok = await showBlurredConfirm(
      context: context,
      title: 'Video call ${widget.dm.recipientName}?',
      message:
          'Start a video call with ${widget.dm.recipientName}.',
      confirmLabel: 'Call',
      confirmIcon: Icons.videocam_rounded,
    );
    if (ok != true || !mounted) return;
    await _initiateCall(
      widget.dm.recipientId,
      widget.dm.recipientName,
      widget.dm.recipientProfilePic,
      video: true,
    );
  }

  Widget _buildAppBarTitle(themeColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _openDmDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: themeColor.primary.withAlpha(20),
              backgroundImage: widget.dm.recipientProfilePic != null
                  ? CachedNetworkImageProvider(widget.dm.recipientProfilePic!)
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.dm.recipientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  StreamBuilder<Map<String, bool>>(
                    stream: UserStatusService().userStatusStream,
                    initialData: UserStatusService().onlineStatus,
                    builder: (context, snapshot) {
                      final isOnline = ref
                          .read(chatProvider)
                          .isUserOnline(
                            widget.dm.recipientId,
                            widget.dm.chatId,
                          );
                      return Text(
                        isOnline ? 'Online' : 'Offline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Initiate audio call
  Future<void> _initiateCall(
    String userId,
    String userName,
    String? userProfilePic, {
    bool video = false,
  }) async {
    try {
      final callServiceNotifier = ref.read(callServiceProvider.notifier);
      await callServiceNotifier.initiateCall(
        widget.dm.recipientId,
        widget.dm.recipientName,
        widget.dm.recipientProfilePic,
        video: video,
      );

      // Native call screen is launched automatically by call.service.dart
    } catch (e) {
      if (context.mounted) {
        Snack.error(
          'Failed to start call: Please check your internet connection',
        );
      }
    }
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
    _onlineStatusSubscription?.cancel();
    _joinConvSubscription?.cancel();
    _typingAnimationController.dispose();
    // Drift watch-streams (messages / reactions / delivery statuses).
    disposeSync();
    // WS subscriptions + typing timeout (mixin-owned).
    disposeWebSocketListener();

    // Save draft before disposing
    if (_messageController.text.isNotEmpty) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.dm.chatId, _messageController.text);
    }

    // Remove listener
    _messageController.removeListener(onMessageTextChanged);
    // Clear active conversation when leaving the messaging screen
    ref.read(chatProvider.notifier).setActiveConversation(null, null);

    // Clear unread count in local DB
    _conversationsRepo.updateUnreadCount(widget.dm.chatId, 0);

    // conversationLeave was removed; the server infers leave from
    // the absence of heartbeat / next join.

    // Scroll-mixin-owned timers + message-animation controllers.
    disposeScroll();

    disposeSwipeReply();

    // Dispose audio playback manager
    _audioPlaybackManager.dispose();

    // Dispose voice recording (mixin-owned)
    disposeVoiceRecording();

    // Stop the periodic failed-message retry timer.
    stopSendAutoRetry();

    // Dispose search controller and timer (mixin-owned).
    disposeSearch();

    // Clear message keys
    _messageKeys.clear();

    super.dispose();
  }

  void _showMessageActions(MessageModel message, bool isMyMessage) {
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = starredMessages.contains(message.id);

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

    // "Delete for everyone" is only offered for the sender's own messages
    // *and* only within 1 hour of the message being sent. After that it
    // collapses to "Delete for me" so old messages can't be retracted.
    final canDeleteForEveryone =
        isMyMessage && _isWithinDeleteForEveryoneWindow(message.sentAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageActionSheet(
        message: message,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        showReadBy: false,
        onReply: () => replyToMessage(message),
        onPin: () => togglePinMessage(message),
        onStar: () => toggleStarMessage(message.id),
        onForward: () => forwardMessage(message),
        onSelect: () => enterSelectionMode(message.id),
        onDeleteForMe: () => deleteMessagesForMe([message.id]),
        onDeleteForEveryone:
            canDeleteForEveryone ? () => deleteMessages([message.id]) : null,
        onReact: (emoji) => reactToMessage(message, emoji),
        myReactions: myReactions,
      ),
    );
  }

  /// Whether `sentAt` is recent enough that the sender may still retract
  /// the message for all participants. WhatsApp-style 1-hour window.
  bool _isWithinDeleteForEveryoneWindow(String sentAt) {
    final sent = DateTime.tryParse(sentAt);
    if (sent == null) return false;
    final age = DateTime.now().toUtc().difference(sent.toUtc());
    return age <= const Duration(hours: 1);
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
        if (_canSetState) {
          _safeSetState(() {
            _messages.removeWhere((m) => m.id == messageId);
          });
        }
        await _messagesRepo.permanentlyDeleteMessage(messageId);
      },
    );
  }

  Widget _buildMessageInput() {
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: replyToMessageData != null,
      isSending: isSendingMessage,
      replyToMessageData: replyToMessageData,
      currentUserId: _currentUserDetails?.id,
      onSendMessage: sendMessage,
      onSendVoiceNote: sendVoiceNote,
      onPickGallery: handleGalleryAttachment,
      onPickCamera: handleCameraAttachment,
      onPickDocument: handleDocumentAttachment,
      onPickContact: handleContactAttachment,
      onTyping: handleTyping,
      onCancelReply: cancelReply,
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!_canSetState) return;
        _safeSetState(() {
          isInputFocused = isFocused;
        });
      },
      dm: widget.dm,
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
      isGroupChat: false,
      userProfilePic: widget.dm.recipientProfilePic,
      userName: widget.dm.recipientName,
    );
  }
}
