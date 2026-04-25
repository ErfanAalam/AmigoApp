import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/utils/id.utils.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../db/repositories/missed-ws-messages.repo.dart';
import '../../../models/community.model.dart';
import '../../../models/group.model.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../config/app-colors.config.dart';
import '../../../services/draft-message.service.dart';
import '../../../services/fcm/fcm-init.service.dart';
import '../../../services/media-cache.service.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../services/socket/transport.service.dart';
import '../../../services/socket/ws-message.handler.dart';
import '../../../services/user-info-cache.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/attachment.action-sheet.dart';
import '../../../ui/chat/date.widgets.dart';
import '../../../ui/chat/forward-message.widget.dart';
import '../../../ui/chat/group-readby.modal.dart';
import '../../../ui/chat/input-container.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/media-grid.widget.dart';
import '../../../ui/chat/emoji-reaction.widget.dart';
import '../../../ui/chat/message.action-sheet.dart';
import '../../../ui/chat/message.widget.dart';
import '../../../ui/chat/pinned-message.widget.dart';
import '../../../ui/chat/chat-pills.widget.dart';
import '../../../ui/chat/scroll-to-bottom.button.dart';
import '../../../ui/chat/voice-recording.widget.dart';
import '../../../ui/chat/message-recommendations.widget.dart';
import '../../../ui/chat/contact-selection.widget.dart';
import '../../../ui/chat/contact-message.widget.dart';
import '../../../models/contact.model.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/chat/attachments.utils.dart';
import '../../../utils/chat/audio-playback.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../utils/chat/forward-message.utils.dart';
import '../../../utils/chat/preview-media.utils.dart';
import '../../../ui/snackbar.dart';
import '../../../utils/route-transitions.util.dart';
import 'group-info.screen.dart';
import '../chat-details.screen.dart';
import '../image-editor.screen.dart';

part 'group-messaging.ws.part.dart';
part 'group-messaging.sync.part.dart';
part 'group-messaging.scroll.part.dart';
part 'group-messaging.search.part.dart';
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

class _InnerGroupChatPageState extends ConsumerState<InnerGroupChatPage>
    with TickerProviderStateMixin {
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
  Map<String, Map<String, dynamic>> _reactionsByMessage = {};
  Map<String, MessageStatusType> _deliveryStatusByMessage = {};
  StreamSubscription<Map<String, MessageStatusType>>?
  _deliveryStatusSubscription;
  bool _isLoading = false;

  UserModel? _currentUserDetails;

  // Message sync state variables
  bool _isSyncingMessages = false;
  bool _hasMoreOnServer =
      true; // whether server has more pages beyond what's in local DB
  bool _isLoadingMore = false; // guard against concurrent load-more calls

  // Automatic resend state variable - initialized to true to disable manual resend until initialization completes
  bool _isResendingFailedMessages = true;
  final Map<String, bool> _resendingFailedMessages = {};

  List<UserModel> _conversationMembers = [];

  bool _isTyping = false;
  bool _isSendingMessage = false;
  String? _lastSentReadMsgId;
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

  // Scroll to bottom button state
  bool _isAtBottom = true;
  // int _unreadCountWhileScrolled = 0;
  // int _previousMessageCount = 0;

  // For optimistic message handling - using filtered streams per conversation
  StreamSubscription<List<MessageModel>>? _messagesStreamSub;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _reactionsSubscription;
  // StreamSubscription<OnlineStatusPayload>? _onlineStatusSubscription;
  StreamSubscription<TransportConnectionState>?
  _transportConnectionSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<MessageSentAckPayload>? _messageAckSubscription;
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

  // Message selection and actions
  final Set<String> _selectedMessages = {};
  // bool _isSelectionMode = false;
  MessageModel? _pinnedMessage; // Only one message can be pinned
  final Set<String> _starredMessages = {};

  // Forward message state
  final Set<String> _messagesToForward = {};
  bool _isLoadingConversations = false;

  // Reply message state
  MessageModel? _replyToMessageData;

  // Pending contact metadata for contact messages
  Map<String, dynamic>? _pendingContactMetadata;
  // bool _isReplying = false;

  // Highlighted message state (for scroll-to effect)
  String? _highlightedMessageId; // Current match being viewed
  Set<String> _highlightedMessageIds = {}; // All matching messages
  Timer? _highlightTimer;

  // Scroll-to-reply loading state
  bool _isLoadingTargetMessage = false;

  // ── Jump mode ─────────────────────────────────────────────────────────────
  List<MessageModel> _jumpMessages = [];
  bool _isInJumpMode = false;
  bool _jumpHasOlderMessages = true;
  bool _jumpHasNewerMessages = true;
  bool _isLoadingJumpOlder = false;
  bool _isLoadingJumpNewer = false;
  bool _isScrollingToJumpTarget =
      false; // Guard: true while scrollToIndex animates
  static const int _jumpWindowSize = 300;

  List<MessageModel> get _displayMessages =>
      _isInJumpMode ? _jumpMessages : _messages;

  // GlobalKeys for message widgets to enable accurate scrolling
  final Map<String, GlobalKey> _messageKeys = {};

  // Sticky date separator state
  String? _currentStickyDate;
  bool _showStickyDate = false;

  // Typing animation controllers
  late AnimationController _typingAnimationController;
  late List<Animation<double>> _typingDotAnimations;
  Timer? _typingTimeout;
  DateTime? _lastTypingMessageSent; // Track when last typing message was sent

  // Scroll debounce timer
  Timer? _scrollDebounceTimer;

  // Draft save debounce timer
  Timer? _draftSaveTimer;

  // Search state
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchMatches = []; // List of message IDs that match search
  int _currentMatchIndex = -1; // Current match index in _searchMatches
  Timer? _searchDebounceTimer;

  // Message recommendations state
  bool _isInputFocused = false;
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

  // Message animation controllers
  final Map<String, AnimationController> _messageAnimationControllers = {};
  final Map<String, Animation<double>> _messageSlideAnimations = {};
  final Map<String, Animation<double>> _messageFadeAnimations = {};
  final Set<String> _animatedMessages = {};

  // Swipe animation controllers for reply gesture
  final Map<String, AnimationController> _swipeAnimationControllers = {};
  final Map<String, Animation<double>> _swipeAnimations = {};

  // Swipe gesture tracking variables
  Offset? _swipeStartPosition;
  double _swipeTotalDistance = 0.0;
  bool _isSwipeGesture = false;
  bool _isScrolling = false;
  double _lastScrollPosition = 0.0;
  // Minimum travel (px²) before classifying gesture direction — keeps classification stable
  static const double _minSwipeDistanceSq = 16.0; // 4px
  // Max vertical-to-horizontal ratio allowed — keeps swipe strictly left-to-right (~10°)
  static const double _maxSwipeAngleRatio = 0.18;
  static const double _minSwipeVelocity =
      500.0; // Minimum velocity for swipe completion
  static const double _swipeThreshold =
      0.35; // Threshold for swipe completion (0.0 to 1.0)

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

    // Clear notifications for this conversation when opened
    NotificationService().clearConversationNotifications(
      widget.group.chatId.toString(),
    );

    // _websocketService.connect(widget.group.chatId);

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

    // Listen to search text changes
    _searchController.addListener(_onSearchTextChanged);

    // Listen to focus changes
    _messageFocusNode.addListener(_onInputFocusChange);
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
      onAudioFinished: _handleAudioFinished,
    );

    // Initialize the audio player asynchronously
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
        leading: _selectedMessages.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSearchMode
            ? _buildSearchBar(themeColor)
            : _selectedMessages.isNotEmpty
            ? Text(
                '${_selectedMessages.length} selected',
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
        actions: _selectedMessages.isNotEmpty
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
                    onTap: () => _scrollToMessage(_pinnedMessage?.id ?? ''),
                    onUnpin: () => _togglePinMessage(_pinnedMessage!),
                  ),

                // Messages List
                Expanded(child: _buildMessagesList()),

                // Message Input (includes typing indicator, recommendations, and input field)
                _buildMessageInput(),
              ],
            ),

            // Loading-target-message pill
            if (_isLoadingTargetMessage)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: _buildLoadingTargetPill(),
              ),
            // Sync indicator pill - above date separator
            if (_isSyncingMessages && !_isLoadingTargetMessage)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: _buildSyncProgressBar(),
              ),
            // Sticky Date Separator - shifts down when sync pill is visible
            Positioned(
              top:
                  (_isSyncingMessages ||
                      _isLoadingTargetMessage ||
                      _isInJumpMode)
                  ? 54
                  : 10,
              left: 0,
              right: 0,
              child: _buildStickyDateSeparator(),
            ),
            // Scroll to Bottom Button - positioned at right bottom
            Positioned(
              right: 16,
              bottom: _replyToMessageData != null
                  ? 150.0
                  : 110.0, // Position above message input
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
            // "Return to Latest" — visible only in jump mode
            if (_isInJumpMode)
              Positioned(
                top: (_isSyncingMessages || _isLoadingTargetMessage) ? 54 : 10,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _exitJumpMode,
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
    _jumpMessages = [];
    _isInJumpMode = false;

    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    _isOtherTypingNotifier.dispose();
    _searchDebounceTimer?.cancel();
    _messagesStreamSub?.cancel();
    _reactionsSubscription?.cancel();
    _deliveryStatusSubscription?.cancel();
    _transportConnectionSubscription?.cancel();
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

    // Clear message keys
    _messageKeys.clear();

    // Save draft before disposing
    if (_messageController.text.isNotEmpty) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.group.chatId, _messageController.text);
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

    // conversationLeave was removed; the server infers leave from
    // the absence of heartbeat / next join.

    super.dispose();
  }
}
