import 'dart:async';
import 'dart:io';
import 'package:amigo/api/api_service.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/providers/call.provider.dart';
import 'package:amigo/utils/id.utils.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../db/repositories/message-status.repo.dart';
import '../../../db/repositories/missed-ws-messages.repo.dart';
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
import '../../../services/user-status.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/attachment.action-sheet.dart';
import '../../../ui/chat/date.widgets.dart';
import '../../../ui/chat/forward-message.widget.dart';
import '../../../ui/snackbar.dart';
import '../../../ui/chat/input-container.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/media-grid.widget.dart';
import '../../../ui/chat/emoji-reaction.widget.dart';
import '../../../ui/chat/message.action-sheet.dart';
import '../../../ui/chat/message.widget.dart';
import '../../../ui/chat/pinned-message.widget.dart';
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
import '../image-editor.screen.dart';
import 'dm-details.screen.dart';

class InnerChatPage extends ConsumerStatefulWidget {
  final DmModel dm;
  const InnerChatPage({super.key, required this.dm});

  @override
  ConsumerState<InnerChatPage> createState() => _InnerChatPageState();
}

// Star feature is dropped on the backend. Keep all star UI reachable behind
// a compile-time flag so it can be restored without restructuring the screen.
const bool _starEnabled = false;

class _InnerChatPageState extends ConsumerState<InnerChatPage>
    with TickerProviderStateMixin {
  final apiService = ApiService();
  final ConversationRepository _conversationsRepo = ConversationRepository();
  final MessageRepository _messagesRepo = MessageRepository();
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();
  final UserRepository _userRepo = UserRepository();
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
  StreamSubscription<List<MessageModel>>? _messagesStreamSub;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _reactionsSubscription;
  StreamSubscription<ConnectionStatusPayload>? _onlineStatusSubscription;
  StreamSubscription<TransportConnectionState>?
  _transportConnectionSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<MessageSentAckPayload>? _messageAckSubscription;
  StreamSubscription<MessagePinPayload>? _messagePinSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;
  StreamSubscription<ConvJoinPayload>? _joinConvSubscription;

  // State variables
  bool _isLoading = false;
  List<MessageModel> _messages = [];
  Map<String, Map<String, dynamic>> _reactionsByMessage = {};
  Map<String, MessageStatusType> _deliveryStatusByMessage = {};
  StreamSubscription<Map<String, MessageStatusType>>?
  _deliveryStatusSubscription;
  // List<MessageModel> _failedMessages = [];
  MessageModel? _pinnedMessage;
  UserModel? _currentUserDetails;

  // Message sync state variables
  bool _isSyncingMessages = false;
  bool _hasMoreOnServer =
      true; // whether server has more pages beyond what's in local DB
  bool _isLoadingMore = false; // guard against concurrent load-more calls

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

  // bool _isTyping = false;
  bool _isSendingMessage = false;
  String? _lastSentReadMsgId;
  // bool isloadingMediamessage = false;
  final ValueNotifier<bool> _isOtherTypingNotifier = ValueNotifier<bool>(false);

  // Scroll to bottom button state
  bool _isAtBottom = true;
  double _lastScrollPosition = 0.0;

  bool _isDisposed = false; // Track if the page is being disposed

  bool get _canSetState => mounted && !_isDisposed;

  void _safeSetState(VoidCallback fn) {
    if (_canSetState) {
      setState(fn);
    }
  }

  // Message selection and actions
  final Set<String> _selectedMessages = {};
  // String? _pinnedMessageId; // Only one message can be pinned
  final Set<String> _starredMessages = {};

  // Forward message state
  final Set<String> _messagesToForward = {};
  final bool _isLoadingConversations = false;

  // Resending failed messages state
  final Map<String, bool> _resendingFailedMessages = {};

  // Reply message state
  MessageModel? _replyToMessageData;

  // Pending contact metadata for contact messages
  Map<String, dynamic>? _pendingContactMetadata;

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

  // Sticky date separator state - using ValueNotifier to avoid setState during scroll
  final ValueNotifier<String?> _currentStickyDate = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<bool> _showStickyDate = ValueNotifier<bool>(false);

  Timer? _typingTimeout;
  DateTime? _lastTypingMessageSent; // Track when last typing message was sent

  // Scroll debounce timer
  Timer? _scrollDebounceTimer;

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
  // Minimum travel (px²) before classifying gesture direction — keeps classification stable
  static const double _minSwipeDistanceSq = 16.0; // 4px
  // Max vertical-to-horizontal ratio allowed — keeps swipe strictly left-to-right (~10°)
  static const double _maxSwipeAngleRatio = 0.18;
  static const double _minSwipeVelocity =
      500.0; // Minimum velocity for swipe completion
  static const double _swipeThreshold =
      0.35; // Threshold for swipe completion (0.0 to 1.0)

  //
  // // Video thumbnail cache
  final Map<String, String?> _videoThumbnailCache = {};
  final Map<String, Future<String?>> _videoThumbnailFutures = {};

  @override
  void initState() {
    super.initState();

    // Clear notifications for this conversation when opened
    NotificationService().clearConversationNotifications(widget.dm.chatId);

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

  /// Load draft message when opening conversation
  Future<void> _loadDraft() async {
    // Load directly from service for immediate access
    final draftService = DraftMessageService();
    final draft = await draftService.getDraft(widget.dm.chatId);
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      // Also update the provider state
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      draftNotifier.saveDraft(widget.dm.chatId, draft);
    }
  }

  /// Set up WebSocket message listener for real-time messages
  void _setupWebSocketListener() {
    final convId = widget.dm.chatId;

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

    // Listen to sent-ack messages filtered for this conversation
    _messageAckSubscription = _wsMessageHandler
        .sentAckForConversation(convId)
        .listen(
          (payload) {
            _handleSentAck(payload);
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
    // joinConversation stream removed — read-receipt state is now sourced
    // from MessageInfoModel streams, so the join callback is a no-op.

    // Listen to transport connection state changes:
    // 1. Re-send conversation:join so server knows we're still active
    // 2. Auto-resend any failed messages
    _transportConnectionSubscription = _transportManager.connectionStateStream
        .listen((state) {
          if (state == TransportConnectionState.connected) {
            debugPrint(
              '[DM] 🎐🎐🎐 Transport reconnected, re-joining conversation and resending failed messages',
            );
            // Re-join conversation so server updates active_in_conv
            _sendConversationJoin();
            _resendAllFailedMessages();
          }
        });
  }

  /// Send conversation:join to server (idempotent — safe to call multiple times).
  /// If offline, stores the event in MissedWsMessages for replay on reconnect.
  Future<void> _sendConversationJoin() async {
    if (_currentUserDetails == null) return;
    final latestMsgId = _messages.isNotEmpty ? _messages.last.id : '';
    if (latestMsgId.isEmpty || latestMsgId == _lastSentReadMsgId) return;
    _lastSentReadMsgId = latestMsgId;
    final joinConvPayload = ConvJoinPayload(
      convId: widget.dm.chatId,
      userId: _currentUserDetails!.id,
      lastReadMsgId: latestMsgId,
    );
    final wsmsg = WSMessage(
      type: WSMessageType.conversationJoin,
      payload: joinConvPayload.toJson(),
      wsTimestamp: DateTime.now(),
    ).toJson();
    if (_transportManager.isConnected) {
      await _transportManager.sendMessage(wsmsg);
    } else {
      MissedWsMessagesRepository().storeEvent(
        'conversation:join',
        joinConvPayload.toJson(),
      );
    }
  }

  /// Returns true only if the pinned message is real and displayable.
  bool _isValidPinnedMessage(MessageModel msg) {
    if (msg.id.isEmpty) return false;
    return (msg.body != null && msg.body!.isNotEmpty) ||
        msg.type != MessageType.text;
  }

  /// Load pinned message from database
  Future<void> _loadPinnedMessage() async {
    final conversation = await _conversationsRepo.getConversationById(
      widget.dm.chatId,
    );
    final currentPinnedMessageId = conversation?.pinnedMsgId;

    if (currentPinnedMessageId != null) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        currentPinnedMessageId,
      );
      if (!_canSetState) return;

      if (pinnedMessage != null && _isValidPinnedMessage(pinnedMessage)) {
        _safeSetState(() {
          _pinnedMessage = pinnedMessage;
          final isInMessages = _messages.any(
            (msg) => msg.id == pinnedMessage.id,
          );
          if (!isInMessages) {
            _messages.add(pinnedMessage);
            _sortMessagesBySentAt();
          }
        });
      } else {
        await _conversationsRepo.updatePinnedMessage(widget.dm.chatId, null);
        _safeSetState(() {
          _pinnedMessage = null;
        });
      }
    } else {
      if (!_canSetState) return;
      _safeSetState(() {
        _pinnedMessage = null;
      });
    }
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
        .setActiveConversation(widget.dm.chatId, ChatType.dm);

    // --- Parallel: independent reads that don't depend on each other ---
    // Start message stream (synchronous subscription setup)
    _messagesStreamSub?.cancel();
    _messagesStreamSub = _messagesRepo
        .watchMessages(widget.dm.chatId)
        .listen(
          (msgs) {
            if (!_canSetState) return;
            _safeSetState(() {
              _messages = msgs;
              _sortMessagesBySentAt();
              _isLoading = false;
            });
          },
          onError: (e) {
            debugPrint('Messages stream error: $e');
          },
        );

    // Start reactions stream (synchronous subscription setup)
    _reactionsSubscription?.cancel();
    _reactionsSubscription = _messageStatusRepo
        .watchReactionsByConversation(widget.dm.chatId)
        .listen(
          (reactions) {
            debugPrint(
              '[Reactions] Stream fired: ${reactions.length} messages with reactions',
            );
            for (final entry in reactions.entries) {
              debugPrint(
                '[Reactions]   msg=${entry.key} emojis=${(entry.value as Map).keys.toList()}',
              );
            }
            if (!_canSetState) return;
            _safeSetState(() => _reactionsByMessage = reactions);
          },
          onError: (e) {
            debugPrint('Reactions stream error: $e');
          },
        );

    // Start delivery/read status stream
    _deliveryStatusSubscription?.cancel();
    _deliveryStatusSubscription = _messageStatusRepo
        .watchDeliveryStatusByConversation(widget.dm.chatId)
        .listen(
          (statuses) {
            if (!_canSetState) return;
            _safeSetState(() => _deliveryStatusByMessage = statuses);
          },
          onError: (e) {
            debugPrint('Delivery status stream error: $e');
          },
        );

    // Run independent async operations in parallel:
    // - clear unread count
    // - load pinned message
    await Future.wait([
      _conversationsRepo.updateUnreadCount(widget.dm.chatId, 0),
      _loadPinnedMessage(),
    ]);

    // Clear via provider to update UI state (synchronous, no await needed)
    ref
        .read(chatProvider.notifier)
        .clearUnreadCount(widget.dm.chatId, ChatType.dm);

    // Fire-and-forget: don't block chat opening for these
    unawaited(
      _sendConversationJoin().catchError(
        (e) => debugPrint('Error joining conversation: $e'),
      ),
    );
    unawaited(
      _syncMessagesFromServer().catchError(
        (e) => debugPrint('Error syncing messages: $e'),
      ),
    );

    // resend any failed messages
    // final failedMessages = messagesFromLocal
    //     .where(
    //       (msg) =>
    //           msg.metadata != null &&
    //           msg.metadata!['upload_failed'] == true &&
    //           msg.senderId == _currentUserDetails?.id,
    //     )
    //     .toList();
    // if (failedMessages.isNotEmpty) {
    //   // Set flag to indicate automatic resend is in progress
    //   if (_canSetState) {
    //     _safeSetState(() {
    //       _isResendingFailedMessages = true;
    //     });
    //   }
    //
    //   // Update UI to show loading state for all failed messages before resending
    //   if (_canSetState) {
    //     _safeSetState(() {
    //       for (final failedMessage in failedMessages) {
    //         final msgIndex = _messages.indexWhere(
    //           (msg) =>
    //               msg.id == failedMessage.id ||
    //               msg.optimisticId == failedMessage.optimisticId,
    //         );
    //         if (msgIndex != -1) {
    //           final uploadingMetadata = Map<String, dynamic>.from(
    //             failedMessage.metadata ?? {},
    //           );
    //           uploadingMetadata.remove('upload_failed');
    //           uploadingMetadata['is_uploading'] = true;
    //           _messages[msgIndex] = failedMessage.copyWith(
    //             status: MessageStatusType.sent,
    //             metadata: uploadingMetadata,
    //           );
    //         }
    //       }
    //     });
    //   }
    //
    //   // Now resend each failed message
    //   for (final failedMessage in failedMessages) {
    //     await _resendFailedMessage(failedMessage);
    //   }
    //
    //   // Wait a bit for WebSocket handlers to process the responses
    //   await Future.delayed(const Duration(milliseconds: 500));
    //
    //   // Reload messages from DB to ensure UI reflects latest state
    //   final updatedMessages = await _messagesRepo.getMessagesByConversation(
    //     widget.dm.chatId,
    //     limit: 100,
    //     offset: 0,
    //   );
    //
    //   // Clear flag after all automatic resends are complete
    //   if (_canSetState) {
    //     _safeSetState(() {
    //       _messages = updatedMessages;
    //       _sortMessagesBySentAt();
    //       _isResendingFailedMessages = false;
    //     });
    //   }
    // } else {
    //   // No failed messages - enable manual resend immediately
    //   if (_canSetState) {
    //     _safeSetState(() {
    //       _isResendingFailedMessages = false;
    //     });
    //   }
    // }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreOnServer) return;

    _safeSetState(() {
      _isLoadingMore = true;
    });

    try {
      // Use cursor-based pagination: fetch messages older than the oldest we have.
      final oldestMsgId = _messages.isNotEmpty ? _messages.first.id : null;
      final result = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        beforeMessageId: oldestMsgId,
        limit: 100,
      );

      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isNotEmpty) {
          await _messagesRepo.insertMessages(history.messages);
          // Drift stream fires automatically — no setState for _messages needed
          _hasMoreOnServer = history.hasMore;
        } else {
          _hasMoreOnServer = false;
        }
      } else {
        _hasMoreOnServer = false;
      }
    } catch (e) {
      debugPrint('[DM] Error loading more messages: $e');
    } finally {
      if (mounted) {
        _safeSetState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Sync messages from server — lightweight gap detection.
  /// First open: bulk fetch up to 300 messages.
  /// Subsequent opens: only fetch if local is behind server's lastMsgId.
  Future<void> _syncMessagesFromServer() async {
    final needSync = await _conversationsRepo.getNeedSyncStatus(
      widget.dm.chatId,
    );

    if (needSync == false) {
      // Subsequent open: gap-check only
      final localLatestId = _messages.isNotEmpty ? _messages.last.id : null;
      final serverLatestId = widget.dm.lastMsgId;

      if (localLatestId == null ||
          localLatestId == serverLatestId ||
          serverLatestId == null) {
        _hasMoreOnServer = true;
        return;
      }

      // Local is behind — fetch only the gap
      debugPrint(
        '[Sync] Gap detected: local=$localLatestId server=$serverLatestId',
      );
      final gapResponse = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        afterMessageId: localLatestId,
        limit: 100,
      );

      if (gapResponse.data != null) {
        final gapHistory = ConversationHistoryResponse.fromJson(
          gapResponse.data as Map<String, dynamic>,
        );
        if (gapHistory.messages.isNotEmpty) {
          await _messagesRepo.insertMessages(gapHistory.messages);
          debugPrint(
            '[Sync] Gap filled: ${gapHistory.messages.length} messages',
          );
        }
      }

      _hasMoreOnServer = true;
      return;
    }

    // First open: fetch up to 3 batches of 100 = 300 messages
    const int firstOpenMaxBatches = 3;
    const int limit = 100;
    int batch = 0;
    bool hasMore = true;
    String? beforeCursor;

    if (_canSetState) {
      _safeSetState(() {
        _isSyncingMessages = true;
      });
    }

    try {
      while (batch < firstOpenMaxBatches &&
          hasMore &&
          mounted &&
          !_isDisposed) {
        final result = await apiService.chat.getConversationHistory(
          conversationId: widget.dm.chatId,
          beforeMessageId: beforeCursor,
          limit: limit,
        );

        if (result.data == null) break;

        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );

        if (history.messages.isEmpty) break;

        await _messagesRepo.insertMessages(history.messages);

        beforeCursor = history.messages.first.id;
        hasMore = history.hasMore;
        batch++;
        await Future.delayed(const Duration(milliseconds: 30));
      }

      _hasMoreOnServer = hasMore;

      if (mounted) {
        _safeSetState(() {
          _isSyncingMessages = false;
        });
      }

      // First open only: sync statuses from server (no local data to overwrite)
      await _syncMessageStatuses();
      await _conversationsRepo.updateNeedSyncStatus(widget.dm.chatId, false);
    } catch (e) {
      debugPrint('❌ Error syncing messages: $e');
      if (mounted) {
        _safeSetState(() {
          _isSyncingMessages = false;
        });
      }
    }
  }

  /// Sync message statuses from server to local DB
  Future<void> _syncMessageStatuses() async {
    print("-----------------------------------------------------------");
    print("_syncMessageStatuses");
    print("-----------------------------------------------------------");
    try {
      int page = 1;
      const int limit = 1000; // Fetch up to 1000 statuses per page
      bool hasMorePages = true;

      while (hasMorePages && _canSetState) {
        final response = (await apiService.chat.getMessageStatuses(
          conversationId: widget.dm.chatId,
          page: page,
          limit: limit,
        )).toMap();

        if (response['success'] != true || response['data'] == null) {
          break; // Stop on error
        }

        final statusesData = response['data'];
        final List<dynamic> statuses = statusesData['statuses'] ?? [];

        if (statuses.isEmpty) {
          break; // No more statuses
        }

        if (statuses.isNotEmpty) {
          debugPrint('[StatusSync] Sample status: ${statuses.first}');
        }

        // Convert to format expected by repository (Drizzle returns camelCase)
        final List<Map<String, dynamic>> statusesToInsert = statuses.map((
          status,
        ) {
          return {
            'id': status['id'],
            'conversationId': status['chatId'] ?? status['chat_id'] ?? status['conv_id'],
            'messageId': status['messageId'] ?? status['message_id'],
            'userId': status['userId'] ?? status['user_id'],
            'deliveredAt': status['deliveredAt'] ?? status['delivered_at'],
            'readAt': status['readAt'] ?? status['read_at'],
            'reaction': status['reaction'],
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
        draftNotifier.saveDraft(widget.dm.chatId, text);
      }
    });
  }

  /// Update sticky date separator based on current scroll position
  void _updateStickyDateSeparator() {
    if (_displayMessages.isEmpty || !_scrollController.hasClients) return;

    // Calculate which message is currently visible at the top
    final scrollOffset = _scrollController.offset;
    final itemHeight = 100.0; // Approximate height per message
    final visibleIndex = (scrollOffset / itemHeight).floor();

    // Find the message that should show the sticky date
    final messageIndex = _displayMessages.length - 1 - visibleIndex;
    if (messageIndex >= 0 && messageIndex < _displayMessages.length) {
      final currentMessage = _displayMessages[messageIndex];
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

    if (_isInJumpMode && !_isScrollingToJumpTarget) {
      if (distanceFromTop <= 1000) _loadJumpOlderMessages();
      if (scrollPosition <= 200) _loadJumpNewerMessages();
    } else if (!_isLoadingTargetMessage) {
      if (distanceFromTop <= 200) await _loadMoreMessages();
    }
  }

  /// Handle message delete event from WebSocket
  void _handleMessageDelete(DeleteMessagePayload payload) async {
    // Find all message indices to remove
    final indicesToRemove = <int>[];
    for (final msgId in payload.messageIds) {
      final messageIndex = _messages.indexWhere((msg) => msg.id == msgId);
      if (messageIndex != -1) {
        indicesToRemove.add(messageIndex);
      }
    }

    // Remove messages in reverse order to avoid index shifting issues
    if (indicesToRemove.isNotEmpty) {
      indicesToRemove.sort((a, b) => b.compareTo(a)); // Sort descending
      if (!_canSetState) return;
      _safeSetState(() {
        for (final index in indicesToRemove) {
          _messages.removeAt(index);
        }
      });
    }
  }

  /// Build message status ticks (single/double) based on delivery and read status.
  /// Status is derived from MessageInfoModel rows aggregated for this chat.
  /// MessageModel itself no longer carries a `status` field.
  Widget _buildMessageStatusTicks(MessageModel message) {
    if (message.isFailed) {
      return Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
    }
    final status = _deriveStatus(message);
    switch (status) {
      case MessageStatusType.read:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.blue);
      case MessageStatusType.delivered:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.grey[500]);
      case MessageStatusType.sent:
        return Icon(Icons.done_rounded, size: 16, color: Colors.grey[500]);
      case MessageStatusType.unsent:
        return Icon(
          Icons.access_time_rounded,
          size: 16,
          color: Colors.grey[500],
        );
      case MessageStatusType.uploading:
        return Icon(
          Icons.cloud_upload_outlined,
          size: 16,
          color: Colors.greenAccent,
        );
      case MessageStatusType.failed:
        return Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
    }
  }

  /// Derive a coarse delivery status from uploading metadata + failure flag.
  /// Richer delivered/read state should be sourced from MessageInfoModel
  /// aggregation later.
  MessageStatusType _deriveStatus(MessageModel message) {
    if (message.isFailed) return MessageStatusType.failed;
    final atts = message.attachments;
    if (atts is Map<String, dynamic>) {
      if (atts['is_uploading'] == true) return MessageStatusType.uploading;
    }
    return _deliveryStatusByMessage[message.id] ?? MessageStatusType.sent;
  }

  /// Handle incoming message from WebSocket
  void _handleMessageNew(ChatMessagePayload payload) async {
    try {
      final senderDetails = await UserInfoCache.instance.getUser(
        payload.senderId,
      );

      // create message model from payload
      final attachments = payload.attachments is Map<String, dynamic>
          ? payload.attachments as Map<String, dynamic>
          : null;
      final message = MessageModel(
        id: payload.id,
        chatId: payload.convId,
        senderId: payload.senderId,
        attachments: attachments,
        body: payload.body,
        senderName: senderDetails?.name ?? '',
        senderProfilePic: senderDetails?.profilePic ?? '',
        repliedTo: payload.repliedTo,
        type: payload.msgType,
        sentAt: payload.sentAt.toIso8601String(),
      );

      // If this is a message from the current user, check if we have an optimistic message
      // that matches by id and update it instead of adding a duplicate
      if (payload.senderId == _currentUserDetails?.id) {
        final existingIndex = _messages.indexWhere(
          (msg) => (msg.id == payload.id && msg.senderId == payload.senderId),
        );

        if (existingIndex != -1) {
          // Update existing message with server response
          if (!_canSetState) {
            return;
          }
          _safeSetState(() {
            final updatedMessage = message.copyWith(
              id: _messages[existingIndex].id,
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

      _animateNewMessage(message.id);
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  void _handleSentAck(MessageSentAckPayload payload) async {
    try {
      // Find the message with matching msgId
      final messageIndex = _messages.indexWhere(
        (msg) => msg.id == payload.msgId,
      );

      if (messageIndex == -1) {
        debugPrint(
          '⚠️ Message with Id ${payload.msgId} not found in _messages',
        );
        return;
      }

      final currentMessage = _messages[messageIndex];

      // Clear uploading state on attachments (if any) — there is no longer a
      // metadata field on MessageModel; upload progress is tracked inside
      // the attachments map instead.
      Map<String, dynamic>? updatedAttachments;
      if (currentMessage.attachments is Map<String, dynamic>) {
        updatedAttachments = Map<String, dynamic>.from(
          currentMessage.attachments!,
        );
        updatedAttachments['is_uploading'] = false;
        updatedAttachments.remove('upload_failed');
      }

      // If the server assigned a new ID, update the message ID
      final effectiveId = payload.newId ?? payload.msgId;

      // Under UUIDv7 the id the client generated is the permanent id — no
      // reconciliation needed. We only clear uploading state here and let
      // the MessageInfoModel rows (delivered/read) drive the tick UI.
      if (!_canSetState) {
        return;
      }

      _safeSetState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          id: effectiveId,
          attachments: updatedAttachments ?? currentMessage.attachments,
          isFailed: !payload.isSent,
        );
      });

      // Save to DB
      try {
        await _messagesRepo.updateMessageFields(
          payload.msgId,
          attachments: updatedAttachments,
        );
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

    // Receiving a TypingPayload means the sender is typing.
    // The typing indicator auto-hides via a safety timeout.

    // Cancel any existing timeout
    _typingTimeout?.cancel();

    // Update the ValueNotifier directly without setState
    _isOtherTypingNotifier.value = true;

    // Control the typing animation
    _typingAnimationController.repeat(reverse: true);

    // Set a safety timeout to hide typing indicator after x seconds
    _typingTimeout = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) {
        return;
      }
      _isOtherTypingNotifier.value = false;
      _typingAnimationController.stop();
      _typingAnimationController.reset();
    });
  }

  void _handleTyping(String value) async {
    // final wasTyping = _isTyping;
    final isTyping = value.isNotEmpty;

    if (!_canSetState) {
      return;
    }
    // _safeSetState(() {
    //   _isTyping = isTyping;
    // });

    if (isTyping) {
      final now = DateTime.now();

      // Send immediately on first keystroke, or if x seconds have passed since last message
      final shouldSend =
          _lastTypingMessageSent == null ||
          now.difference(_lastTypingMessageSent!).inSeconds >= 2;

      if (shouldSend) {
        // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        final typingPayload = TypingPayload(
          convId: widget.dm.chatId,
          senderId: _currentUserDetails!.id,
        ).toJson();

        final wsmsg = WSMessage(
          type: WSMessageType.conversationTyping,
          payload: typingPayload,
          wsTimestamp: now,
        ).toJson();

        await _transportManager.sendMessage(wsmsg).catchError((e) {
          debugPrint('Error sending conversation:typing message');
          return false;
        });

        // Update last sent time
        _lastTypingMessageSent = now;
        // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      }
    } else {
      // Reset timestamp when user stops typing so next typing session sends immediately
      _lastTypingMessageSent = null;
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

  void _handleConversationJoin(ConvJoinPayload payload) async {
    // Read-receipt state is now sourced from MessageInfoModel streams, so this
    // join callback no longer needs to walk _messages and mutate statuses.
    // Intentionally left as no-op.
  }

  /// Send message with immediate display (optimistic UI)
  void _sendMessage(
    MessageType messageType, {
    MediaResponse? mediaResponse,
    String? messageId,
    int? retryCount = 0,
    String? body,
  }) async {
    if (mounted) {
      setState(() {
        _isSendingMessage = true;
      });
    }
    // grab the text from the text input controller or use provided body
    String messageText = '';
    if (messageType == MessageType.text) {
      messageText = body ?? _messageController.text.trim();
      if (messageText.isEmpty) return;
    }

    // Check if this is a resend (body is provided)
    final isResend = body != null;

    // Clear draft when message is grabbed out of the text input for sending
    // Skip if resending (body is provided)
    if (!isResend) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      await draftNotifier.removeDraft(widget.dm.chatId);
    }

    // generate a UUIDv7 message ID (end-to-end, never rewritten)
    final id = messageId ?? newMessageId();

    // Create message for immediate display with current UTC time
    final nowUTC = DateTime.now().toUtc();

    final newMsg = MessageModel(
      id: id,
      chatId: widget.dm.chatId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      repliedTo: _replyToMessageData?.id,
      type: messageType,
      body: messageText,
      attachments: mediaResponse?.toJson(),
      sentAt: nowUTC.toIso8601String(),
    );

    if (messageId == null && mediaResponse == null) {
      // storing the message into the local database
      await _messagesRepo.insertMessage(newMsg);
    } else if (messageId != null && mediaResponse != null) {
      // This is a media message, so we need to update the DB row with media attachments
      final result = await _messagesRepo.updateMessageFields(
        id,
        attachments: mediaResponse.toJson(),
      );
      if (result.isError) {
        debugPrint(
          "Failed to insert media message into local DB errorCode: ${result.errorCode}",
        );
        return;
      }
    }

    // Clear input and reply state immediately for better UX
    // Skip if resending (body is provided)
    if (!isResend) {
      _messageController.clear();
      // Clear pending contact metadata after using it
      _pendingContactMetadata = null;
    }

    // Add message to UI immediately with animation
    if (_canSetState) {
      _safeSetState(() {
        final index = _messages.indexWhere((msg) => msg.id == id);
        if (index != -1) {
          _messages[index] = newMsg;
        } else {
          _messages.add(newMsg);
        }
        _sortMessagesBySentAt();
      });

      _animateNewMessage(newMsg.id);
      // scroll to bottom when a new message is sent
      _handleScrollToBottomTap();
    }

    // >>>>>-- sending to ws (fire-and-forget) -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final messagePayload = ChatMessagePayload(
      id: id,
      convId: widget.dm.chatId,
      senderId: _currentUserDetails!.id,
      attachments: mediaResponse,
      msgType: messageType,
      body: messageText,
      repliedTo: _replyToMessageData?.id,
      sentAt: nowUTC,
    );

    final wsmsg = WSMessage(
      type: WSMessageType.messageNew,
      payload: messagePayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    // updating the last message on sending own message
    ref
        .read(chatProvider.notifier)
        .updateLastMessageOnSendingOwnMessage(widget.dm.chatId, newMsg);

    // remove the reply container if any
    _cancelReply();

    // Fire-and-forget: send via transport without blocking UI.
    // The MessageSentAckPayload handler marks as "sent" on success or "failed" on failure.
    try {
      // Synchronous check: if transport is not connected, mark failed immediately
      if (!_transportManager.isConnected) {
        debugPrint('Transport not connected, marking message as failed');
        _markMessageAsFailed(newMsg.id);
      } else {
        unawaited(
          _transportManager
              .sendMessage(wsmsg)
              .then((sendResult) async {
                if (sendResult == true) {
                  await _messageStatusRepo
                      .insertMessageStatusesWithMultipleUserIds(
                        messageId: newMsg.id,
                        chatId: widget.dm.chatId,
                        userIds: <String>[widget.dm.recipientId],
                      );
                } else {
                  debugPrint('marking message as failed');
                  await _markMessageAsFailed(newMsg.id);
                }
              })
              .catchError((e) {
                debugPrint('Error sending message: $e');
                _markMessageAsFailed(newMsg.id);
              }),
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _markMessageAsFailed(newMsg.id);
    }
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    if (mounted) {
      setState(() {
        _isSendingMessage = false;
      });
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
    _exitJumpMode();
    // _scrollToBottom();
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

  /// Scroll to a specific message (reply-tap or pinned message tap)
  Future<void> _scrollToMessage(String messageId) async {
    if (!mounted || !_scrollController.hasClients) return;

    // Fast path: only if message is within 100 items of the bottom (visible or near-visible).
    // For anything farther, scrollToIndex through hundreds of items is too slow — use jump mode.
    final current = _displayMessages;
    if (current.isNotEmpty) {
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final builderIndex = current.length - 1 - idx;
        if (builderIndex <= 100) {
          await _scrollController.scrollToIndex(
            builderIndex,
            preferPosition: AutoScrollPosition.middle,
            duration: const Duration(milliseconds: 300),
          );
          _highlightMessage(messageId);
          return;
        }
      }
    }

    // Jump mode: server fetches a 100-message window, replaces display list instantly
    await _jumpToMessage(messageId);
  }

  /// Apply a timed highlight effect on the target message row
  void _highlightMessage(String messageId) {
    if (!_canSetState) return;
    _safeSetState(() => _highlightedMessageId = messageId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2000), () {
      _safeSetState(() => _highlightedMessageId = null);
    });
  }

  Future<void> _jumpToMessage(String messageId) async {
    if (!_canSetState) return;
    _safeSetState(() => _isLoadingTargetMessage = true);
    try {
      final result = await apiService.chat.getMessagesAround(
        conversationId: widget.dm.chatId,
        messageId: messageId,
        before: 50,
        after: 50,
      );
      if (!_canSetState) return;
      if (result.data == null) {
        _safeSetState(() => _isLoadingTargetMessage = false);
        if (mounted) Snack.warning('Could not load message');
        return;
      }
      final around = MessagesAroundResponse.fromJson(
        result.data as Map<String, dynamic>,
      );
      _safeSetState(() {
        final sorted = List<MessageModel>.from(around.messages)
          ..sort((a, b) {
            try {
              return DateTime.parse(
                a.sentAt,
              ).compareTo(DateTime.parse(b.sentAt));
            } catch (_) {
              return a.sentAt.compareTo(b.sentAt);
            }
          });
        // Deduplicate by message ID
        final seen = <String>{};
        _jumpMessages = sorted.where((m) => seen.add(m.id)).toList();
        _jumpHasOlderMessages = around.hasOlder;
        _jumpHasNewerMessages = around.hasNewer;
        _isInJumpMode = true;
        _isLoadingTargetMessage = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (!_canSetState || !_scrollController.hasClients) return;

      final idx = _jumpMessages.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      _isScrollingToJumpTarget = true;
      await _scrollController.scrollToIndex(
        _jumpMessages.length - 1 - idx,
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 300),
      );
      _isScrollingToJumpTarget = false;
      _highlightMessage(messageId);
    } catch (e) {
      debugPrint('[DM] _jumpToMessage: $e');
      if (_canSetState) _safeSetState(() => _isLoadingTargetMessage = false);
      if (mounted) Snack.warning('Could not load message');
    }
  }

  Future<void> _loadJumpOlderMessages() async {
    if (_isLoadingJumpOlder || !_jumpHasOlderMessages || !_isInJumpMode) return;
    if (!_canSetState) return;
    _safeSetState(() => _isLoadingJumpOlder = true);
    try {
      final result = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        beforeMessageId: _jumpMessages.first.id,
        limit: 50,
      );
      if (!_canSetState || !_isInJumpMode) return;
      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isNotEmpty) {
          _safeSetState(() {
            final existingIds = _jumpMessages.map((m) => m.id).toSet();
            final newMessages = history.messages
                .where((m) => !existingIds.contains(m.id))
                .toList();
            _jumpMessages = [...newMessages, ..._jumpMessages];
            if (_jumpMessages.length > _jumpWindowSize) {
              final excess = _jumpMessages.length - _jumpWindowSize;
              _jumpMessages = _jumpMessages.sublist(
                0,
                _jumpMessages.length - excess,
              );
              _jumpHasNewerMessages = true;
            }
            _jumpHasOlderMessages = history.hasMore;
          });
        } else {
          _safeSetState(() => _jumpHasOlderMessages = false);
        }
      }
    } catch (e) {
      debugPrint('[DM] _loadJumpOlderMessages: $e');
    } finally {
      if (_canSetState) _safeSetState(() => _isLoadingJumpOlder = false);
    }
  }

  Future<void> _loadJumpNewerMessages() async {
    if (_isLoadingJumpNewer || !_jumpHasNewerMessages || !_isInJumpMode) return;
    if (!_canSetState) return;
    _safeSetState(() => _isLoadingJumpNewer = true);
    try {
      final result = await apiService.chat.getConversationHistory(
        conversationId: widget.dm.chatId,
        afterMessageId: _jumpMessages.last.id,
        limit: 50,
      );
      if (!_canSetState || !_isInJumpMode) return;
      if (result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isEmpty || !history.hasMore) {
          _safeSetState(() => _isLoadingJumpNewer = false);
          _exitJumpMode();
          return;
        }
        _safeSetState(() {
          final existingIds = _jumpMessages.map((m) => m.id).toSet();
          final newMessages = history.messages
              .where((m) => !existingIds.contains(m.id))
              .toList();
          _jumpMessages = [..._jumpMessages, ...newMessages];
          if (_jumpMessages.length > _jumpWindowSize) {
            final excess = _jumpMessages.length - _jumpWindowSize;
            _jumpMessages = _jumpMessages.sublist(excess);
            _jumpHasOlderMessages = true;
          }
          _jumpHasNewerMessages = history.hasMore;
        });
      }
    } catch (e) {
      debugPrint('[DM] _loadJumpNewerMessages: $e');
    } finally {
      if (_canSetState) _safeSetState(() => _isLoadingJumpNewer = false);
    }
  }

  void _exitJumpMode() {
    if (!_canSetState) return;
    _safeSetState(() {
      _isInJumpMode = false;
      _jumpMessages = [];
      _jumpHasOlderMessages = true;
      _jumpHasNewerMessages = true;
      _isLoadingJumpOlder = false;
      _isLoadingJumpNewer = false;
      _highlightedMessageId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canSetState && _scrollController.hasClients) _scrollToBottom();
    });

    // termporary fix to ensure scroll to bottom after jump mode exit
    Timer(const Duration(milliseconds: 800), _scrollToBottom);
  }

  /// Toggle search mode
  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        // Clear search when exiting
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  /// Handle search text changes with debounce
  void _onSearchTextChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  /// Handle input focus changes
  void _onInputFocusChange() {
    if (!_canSetState) return;
    _safeSetState(() {
      _isInputFocused = _messageFocusNode.hasFocus;
    });
  }

  /// Handle recommendation tap - send message directly
  void _onRecommendationTap(String recommendation) {
    if (!_canSetState) return;

    // Set the message text
    _messageController.text = recommendation;

    // Send the message
    _sendMessage(MessageType.text);

    // Keep keyboard open - don't unfocus
  }

  /// Perform search on messages
  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
        _highlightedMessageId = null;
        _highlightedMessageIds.clear();
      });
      return;
    }

    // Search in loaded messages
    final matches = <String>[];
    for (final message in _messages) {
      if (message.isDeleted) continue;

      // Search in message body
      if (message.body != null && message.body!.toLowerCase().contains(query)) {
        matches.add(message.id);
      }
    }

    setState(() {
      _searchMatches = matches;
      _highlightedMessageIds = matches.toSet(); // Highlight all matches
      if (matches.isNotEmpty) {
        _currentMatchIndex = 0;
        _navigateToMatch(0);
      } else {
        _currentMatchIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  /// Navigate to a specific match
  void _navigateToMatch(int index) {
    if (index < 0 || index >= _searchMatches.length) return;

    final messageId = _searchMatches[index];
    setState(() {
      _currentMatchIndex = index;
      _highlightedMessageId = messageId;
    });

    // Scroll to message
    _scrollToMessage(messageId);

    // Note: We don't remove the highlight anymore - all matches stay highlighted
    // Only the current match gets a brighter highlight
  }

  /// Navigate to next match
  void _navigateToNextMatch() {
    if (_searchMatches.isEmpty) return;
    final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    _navigateToMatch(nextIndex);
  }

  /// Navigate to previous match
  void _navigateToPreviousMatch() {
    if (_searchMatches.isEmpty) return;
    final prevIndex = _currentMatchIndex <= 0
        ? _searchMatches.length - 1
        : _currentMatchIndex - 1;
    _navigateToMatch(prevIndex);
  }

  /// Build search bar widget
  Widget _buildSearchBar(ColorTheme themeColor) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, searchValue, child) {
        final hasText = searchValue.text.isNotEmpty;
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search messages...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) {
                    if (_searchMatches.isNotEmpty) {
                      _navigateToNextMatch();
                    }
                  },
                ),
              ),
              if (hasText) ...[
                // Match counter
                if (_searchMatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_currentMatchIndex + 1}/${_searchMatches.length}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Previous match button
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: _searchMatches.isNotEmpty
                        ? themeColor.primary
                        : Colors.grey[400],
                  ),
                  onPressed: _searchMatches.isNotEmpty
                      ? _navigateToPreviousMatch
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                // Next match button
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    size: 20,
                    color: _searchMatches.isNotEmpty
                        ? themeColor.primary
                        : Colors.grey[400],
                  ),
                  onPressed: _searchMatches.isNotEmpty
                      ? _navigateToNextMatch
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
              // Close search button
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: _toggleSearchMode,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  /// Create and start animation for a new message
  void _animateNewMessage(String messageId) {
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
                      builder: (context) => DmDetailsScreen(dm: widget.dm),
                    ),
                  );
                },
                child: Row(
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
                // Search button
                // IconButton(
                //   icon: const Icon(Icons.search, color: Colors.white),
                //   onPressed: _toggleSearchMode,
                //   tooltip: 'Search messages',
                // ),
                // Only show call button if user has call access
                if (_currentUserDetails?.callAccess == true)
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.white),
                    onPressed: () => _initiateCall(
                      widget.dm.recipientId,
                      widget.dm.recipientName,
                      widget.dm.recipientProfilePic,
                    ),
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
                if (_pinnedMessage != null && _pinnedMessage!.id.isNotEmpty)
                  PinnedMessageSection(
                    pinnedMessage: _messages.firstWhere(
                      (message) => message.id == _pinnedMessage?.id,
                      orElse: () => _pinnedMessage!,
                    ),
                    currentUserId: _currentUserDetails?.id,
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

  /// Build floating sync indicator — centered pill styled like the date chip
  Widget _buildSyncProgressBar() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 7),
            Text(
              'Syncing...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pill shown while loading older pages to find a reply target
  Widget _buildLoadingTargetPill() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 7),
            Text(
              'Loading message...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (_displayMessages.isEmpty && !_isLoading && !_isInJumpMode) {
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

    // Find media groups (4+ consecutive media messages)
    final mediaGroups = ChatHelpers.findConsecutiveMediaGroups(
      _displayMessages,
    );
    final Set<int> groupedMessageIndices = {};
    for (final group in mediaGroups) {
      for (int i = group.startIndex; i <= group.endIndex; i++) {
        groupedMessageIndices.add(i);
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount:
          _displayMessages.length + (_isLoadingMore && !_isInJumpMode ? 1 : 0),
      physics:
          const ClampingScrollPhysics(), // Better performance than bouncing
      cacheExtent: 200,
      addAutomaticKeepAlives: false, // Don't keep all items alive
      addRepaintBoundaries:
          true, // Add repaint boundaries for better performance
      itemBuilder: (context, index) {
        // Show load-more spinner at the top (highest index in reversed list)
        if (!_isInJumpMode &&
            _isLoadingMore &&
            index == _displayMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // Calculate the actual message index, accounting for indicators
        int messageIndex = index;
        // Bounds check to prevent index out of bounds errors
        if (messageIndex < 0 || messageIndex >= _displayMessages.length) {
          return const SizedBox.shrink(); // Return empty widget for invalid indices
        }

        final actualIndex = _displayMessages.length - 1 - messageIndex;
        final message = _displayMessages[actualIndex];

        // Check if this message is part of a media group
        final mediaGroup = mediaGroups.firstWhere(
          (group) =>
              actualIndex >= group.startIndex && actualIndex <= group.endIndex,
          orElse: () => MediaGroup(startIndex: -1, endIndex: -1, messages: []),
        );

        // If this is the first message of a media group, render the grid
        if (mediaGroup.startIndex != -1 &&
            actualIndex == mediaGroup.startIndex) {
          return _buildMediaGroup(mediaGroup, actualIndex);
        }

        // If this message is part of a media group but not the first, skip it
        if (groupedMessageIndices.contains(actualIndex) &&
            actualIndex != mediaGroup.startIndex) {
          return const SizedBox.shrink();
        }

        // Determine if message is from current user
        final isMyMessage = message.senderId == _currentUserDetails?.id;

        // Wrap with AutoScrollTag so scrollToIndex can find this item
        return AutoScrollTag(
          key: ValueKey(message.id),
          controller: _scrollController,
          index: index,
          child: Column(
            children: [
              // Date separator - show the date for the group of messages that starts here
              if (ChatHelpers.shouldShowDateSeparator(
                _displayMessages,
                messageIndex,
              ))
                DateSeparator(dateTimeString: message.sentAt),
              // Message bubble with long press
              _buildMessageWithActions(message, isMyMessage),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaGroup(MediaGroup group, int actualIndex) {
    final firstMessage = group.messages.first;
    final isMyMessage = firstMessage.senderId == _currentUserDetails?.id;

    return Container(
      margin: EdgeInsets.only(
        left: isMyMessage ? 50 : 0,
        right: isMyMessage ? 0 : 50,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: isMyMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Date separator if needed
          if (ChatHelpers.shouldShowDateSeparator(
            _displayMessages,
            _displayMessages.length - 1 - actualIndex,
          ))
            DateSeparator(dateTimeString: firstMessage.sentAt),
          // Media grid
          MediaGridWidget(
            mediaMessages: group.messages,
            isMyMessage: isMyMessage,
            onTap: (messages, index) =>
                _openMediaGroupPreview(messages, index, isMyMessage),
            onCacheImage: (url, id) {
              ChatHelpers.cacheMediaForMessage(
                url: url,
                messageId: id.toString(),
                mediaCacheService: _mediaCacheService,
                checkExistingCache: false,
                debugPrefix: 'dm media grid',
              );
            },
            videoThumbnailCache: _videoThumbnailCache,
            videoThumbnailFutures: _videoThumbnailFutures,
            generateVideoThumbnail: (url, _) async {
              return await generateVideoThumbnailWithCache(
                    url,
                    _videoThumbnailCache,
                    _videoThumbnailFutures,
                  ) ??
                  '';
            },
          ),
        ],
      ),
    );
  }

  void _openMediaGroupPreview(
    List<MessageModel> messages,
    int initialIndex,
    bool isMyMessage,
  ) async {
    await openUnifiedMediaPreview(
      context: context,
      messages: messages,
      initialIndex: initialIndex,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
      isMyMessage: isMyMessage,
      buildMessageStatusTicks: _buildMessageStatusTicks,
      onRetryImage: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.image);
        // }
      },
      onRetryVideo: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.video);
        // }
      },
      showErrorDialog: _showErrorDialog,
      starredMessages: _starredMessages,
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
            final messageWithCurrentDate = _displayMessages.firstWhere(
              (message) =>
                  ChatHelpers.getMessageDateString(message.sentAt) ==
                  currentDate,
              orElse: () => _displayMessages.first,
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
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message);
    }

    final themeColor = ref.watch(themeColorProvider);
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessage?.id == message.id;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: isMyMessage
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
            color: isSelected
                ? themeColor.primary.withAlpha(100)
                : (_highlightedMessageIds.contains(message.id)
                      ? (_highlightedMessageId == message.id
                            ? Color.fromARGB(50, 0, 27, 41)
                            : Color.fromARGB(25, 0, 27, 41))
                      : (_highlightedMessageId == message.id
                            ? Color.fromARGB(50, 0, 27, 41)
                            : Colors.transparent)),
          ),
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

  Widget _buildSystemMessage(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.body ?? '',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
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
        _isScrolling) {
      return;
    }

    final currentPosition = details.globalPosition;
    final dx = currentPosition.dx - _swipeStartPosition!.dx;
    final dy = (currentPosition.dy - _swipeStartPosition!.dy).abs();

    // Classify gesture direction as soon as we have a few pixels of movement.
    // Using squared distance avoids sqrt and keeps things fast.
    if (!_isSwipeGesture) {
      final distSq = dx * dx + dy * dy;
      if (distSq < _minSwipeDistanceSq) {
        return; // too little movement to classify
      }

      // Strictly left-to-right: vertical component must be < ~10° off horizontal
      if (dx > 0 && dy < dx * _maxSwipeAngleRatio) {
        _isSwipeGesture = true;
      } else {
        // Any vertical tilt, left swipe, or diagonal → treat as scroll immediately
        _isScrolling = true;
        return;
      }
    }

    // Track finger in real-time with zero lag once classified as a swipe
    if (dx > 0) {
      final controller = _swipeAnimationControllers[message.id];
      if (controller != null) {
        controller.value = (dx / 100).clamp(0.0, 1.0);
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

    // Reactions are surfaced via the Drift stream; MessageModel no longer
    // carries them, so the bubble renders from the stream-backed map.
    final messageWithReactions = message;

    return MessageBubble(
      config: MessageBubbleConfig(
        message: messageWithReactions,
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
        onRetryFailedMessage: (message) {
          if (!_isResendingFailedMessage(message.id)) {
            resendFailedMessage(message.id);
          }
        },
        isResendingMessage: _isResendingFailedMessage(message.id),
        onResendFailedMessage: (String messageId) {
          resendFailedMessage(messageId);
        },
        onDeleteFailedMessage: (String messageId) async {
          // Remove from UI immediately
          if (_canSetState) {
            _safeSetState(() {
              _messages.removeWhere((message) => message.id == messageId);
            });
          }
          // Delete from local DB
          await _messagesRepo.permanentlyDeleteMessage(messageId);
        },
        isGroupChat: false,
        nonMyMessageBackgroundColor: Colors.white,
        useIntrinsicWidth: true,
        useStackContainer: true,
        currentUserId: _currentUserDetails?.id,
        conversationUserId: widget.dm.recipientId,
        onReplyTap: (String id) => _scrollToMessage(id),
        messagesRepo: _messagesRepo,
        userRepo: _userRepo,
        reactions: _reactionsByMessage[message.id] ?? {},
        onReact: (emoji) => _reactToMessage(message, emoji),
        onShowReactionUsers: (reactions) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => AllReactorsSheet(reactions: reactions),
          );
        },
      ),
    );
  }
  // Helper methods for file attachments

  bool _isMediaMessage(MessageModel message) {
    return ChatHelpers.isMediaMessage(message);
  }

  Widget _buildMessageContent(MessageModel message, bool isMyMessage) {
    // Check if this is a contact message
    if (isContactMessage(message)) {
      final contacts = parseContactsFromMessage(message);
      if (contacts.isNotEmpty) {
        return ContactMessageWidget(
          contacts: contacts,
          isMyMessage: isMyMessage,
        );
      }
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
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.image);
        // }
      },
      onCacheImage: (url, id) {
        ChatHelpers.cacheMediaForMessage(
          url: url,
          messageId: id.toString(),
          mediaCacheService: _mediaCacheService,
        );
      },
      onVideoPreview: (url, caption, fileName) =>
          _openVideoPreview(url, caption, fileName),
      onRetryVideo: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.video);
        // }
      },
      videoThumbnailCache: _videoThumbnailCache,
      videoThumbnailFutures: _videoThumbnailFutures,
      onDocumentPreview: (url, fileName, caption, fileSize) =>
          _openDocumentPreview(url, fileName, caption, fileSize),
      onRetryDocument:
          (file, fileName, extension, {MessageModel? failedMessage}) {
            // if (failedMessage != null) {
            //   _resendFailedMessage(failedMessage);
            // } else {
            _sendMediaMessageToServer(file, MessageType.document);
            // }
          },
      audioPlaybackManager: _audioPlaybackManager,
      onRetryAudio: ({MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(
          File(failedMessage?.attachments?['url'] ?? ''),
          MessageType.audio,
        );
        // }
      },
      onResendFailedMessage: (String messageId) {
        resendFailedMessage(messageId);
      },
      onDeleteFailedMessage: (String messageId) async {
        // Remove from UI immediately
        if (_canSetState) {
          _safeSetState(() {
            _messages.removeWhere((message) => message.id == messageId);
          });
        }
        // Delete from local DB
        await _messagesRepo.permanentlyDeleteMessage(messageId);
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
  void _toggleMessageSelection(String messageId) {
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
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Determine which emojis the current user has already reacted with on this message
    final myReactions = <String>[];
    if (_currentUserDetails != null) {
      final msgReactions = _reactionsByMessage[message.id] ?? {};
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
        showReadBy: false,
        onReply: () => _replyToMessage(message),
        onPin: () => _togglePinMessage(message),
        onStar: () => _toggleStarMessage(message.id),
        onForward: () => _forwardMessage(message),
        onSelect: () => _enterSelectionMode(message.id),
        onDeleteForMe: () => _deleteMessageForMe(message.id),
        onDeleteForEveryone: isMyMessage
            ? () => _deleteMessage(message.id, deleteForEveryone: true)
            : null,
        onReact: (emoji) => _reactToMessage(message, emoji),
        myReactions: myReactions,
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
        onContactTap: () => _handleContactAttachment(),
      ),
    );
  }

  void _handleCameraAttachment() async {
    await handleCameraAttachment(
      imagePicker: _imagePicker,
      context: context,
      onImageSelected: (imageFile, source) async {
        // Open image editor before sending
        final editedFile = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(imageFile: imageFile),
          ),
        );

        if (editedFile != null) {
          _sendMediaMessageToServer(editedFile, MessageType.image);
        }
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
      onImageSelected: (imageFile, source) async {
        // Open image editor before sending
        final editedFile = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(imageFile: imageFile),
          ),
        );

        if (editedFile != null) {
          _sendMediaMessageToServer(editedFile, MessageType.image);
        }
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

  void _handleContactAttachment() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactSelectionWidget(
          onContactsSelected: (List<ContactModel> contacts) {
            if (contacts.isEmpty) return;

            // Store contacts in metadata for special rendering
            final contactsMetadata = contacts
                .map(
                  (contact) => {
                    'name': contact.displayName,
                    'displayName': contact.displayName,
                    'firstName': contact.firstName,
                    'lastName': contact.lastName,
                    'phone': contact.phoneNumber,
                    'phoneNumber': contact.phoneNumber,
                  },
                )
                .toList();

            // Also format as text for backward compatibility
            final contactText = contacts
                .map(
                  (contact) => '${contact.displayName}: ${contact.phoneNumber}',
                )
                .join(',\n');

            // Set the formatted text in the message controller
            _messageController.text = contactText;

            // Store metadata before sending
            _pendingContactMetadata = {
              'contacts': contactsMetadata,
              'is_contact_message': true,
            };

            // Send the message
            _sendMessage(MessageType.text);
          },
        ),
      ),
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
        currentConversationId: widget.dm.chatId,
      ),
    );
  }

  Future<void> _handleForwardToConversations(
    List<String> selectedConversationIds,
  ) async {
    await handleForwardToConversations(
      HandleForwardToConversationsConfig(
        messagesToForward: _messagesToForward,
        selectedConversationIds: selectedConversationIds,
        currentUserId: _currentUserDetails?.id ?? '',
        sourceConversationId: widget.dm.chatId,
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
    MessageType messageType, {
    String? existingMessageId,
  }) async {
    final messageId = existingMessageId ?? newMessageId();
    final nowUTC = DateTime.now().toUtc();

    // Build attachments with local_path for UI to display during upload and
    // upload-progress flags (metadata field no longer exists on MessageModel).
    final fileName = mediaFile.path.split('/').last;
    final attachments = <String, dynamic>{
      'file_name': fileName,
      'local_path': mediaFile.path, // Required for UI to display local file
      'is_uploading': true,
      'upload_progress': 0,
    };

    final newMsg = MessageModel(
      id: messageId,
      chatId: widget.dm.chatId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      repliedTo: _replyToMessageData?.id,
      attachments: attachments,
      type: messageType,
      sentAt: nowUTC.toIso8601String(),
    );

    if (_canSetState) {
      // If resending, update existing message; otherwise add new one
      if (existingMessageId != null) {
        final index = _messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          _safeSetState(() {
            _messages[index] = newMsg;
            _sortMessagesBySentAt();
          });
          _animateNewMessage(newMsg.id);
          _handleScrollToBottomTap();
        }
        // Also update in DB
      } else {
        _safeSetState(() {
          _messages.add(newMsg);
          _sortMessagesBySentAt();
        });

        _animateNewMessage(newMsg.id);
        _handleScrollToBottomTap();

        // immediately insert message in the localDB for future reference
        await _messagesRepo.insertMessage(newMsg);
      }
    }

    int? lastProgressUpdate = -1;

    final response = (await apiService.chat.sendMediaMessage(
      mediaFile,
      onSendProgress: (sent, total) {
        // Calculate progress percentage
        final progress = total > 0 ? ((sent / total) * 100).round() : 0;

        // Update immediately if progress changed (remove throttling to see all updates)
        if (progress != lastProgressUpdate && _canSetState) {
          lastProgressUpdate = progress;

          final index = _messages.indexWhere((msg) => msg.id == messageId);

          if (index != -1) {
            final currentMsg = _messages[index];
            final updatedAttachments = Map<String, dynamic>.from(
              (currentMsg.attachments as Map<String, dynamic>?) ?? {},
            );
            updatedAttachments['upload_progress'] = progress;
            updatedAttachments['is_uploading'] = true;

            final updatedMessage = currentMsg.copyWith(
              attachments: updatedAttachments,
            );

            _safeSetState(() {
              _messages[index] = updatedMessage;
            });
          }
        }
      },
    )).toMap();

    if (response['success'] == true && response['data'] != null) {
      final mediaData = MediaResponse.fromJson(response['data']);

      // Clear upload progress before sending message
      if (_canSetState) {
        final index = _messages.indexWhere((msg) => msg.id == messageId);

        if (index != -1) {
          final currentMsg = _messages[index];
          final updatedAttachments = Map<String, dynamic>.from(
            (currentMsg.attachments as Map<String, dynamic>?) ?? {},
          );
          updatedAttachments.remove('is_uploading');
          updatedAttachments.remove('upload_progress');

          final updatedMessage = currentMsg.copyWith(
            attachments: updatedAttachments,
          );

          _safeSetState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      _sendMessage(messageType, mediaResponse: mediaData, messageId: messageId);

      debugPrint('Media data: $mediaData, messageType: $messageType');
    } else {
      // Update message to show upload failed state and save to DB
      await _markMessageAsFailed(messageId);
      if (_canSetState) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to send media message')),
        // );
      }
    }
  }

  /// Mark a message as failed in both UI and DB
  Future<void> _markMessageAsFailed(String messageId) async {
    if (!_canSetState) return;

    final index = _messages.indexWhere((msg) => msg.id == messageId);

    if (index == -1) return;

    final failedMsg = _messages[index];
    // Reflect upload-failed state in the attachments map (there is no longer a
    // metadata field on MessageModel).
    Map<String, dynamic>? updatedAttachments;
    if (failedMsg.attachments is Map<String, dynamic>) {
      updatedAttachments = Map<String, dynamic>.from(failedMsg.attachments!);
      updatedAttachments['is_uploading'] = false;
      updatedAttachments['upload_failed'] = true;
    }

    final updatedMessage = failedMsg.copyWith(
      isFailed: true,
      attachments: updatedAttachments ?? failedMsg.attachments,
    );

    // Update in UI
    _safeSetState(() {
      _messages[index] = updatedMessage;
    });

    // Save to DB with failed status
    await _messagesRepo.updateMessageFields(
      messageId,
      isFailed: true,
      attachments: updatedAttachments,
    );

    // print("🎐 🎐 🎐  set states to failed in UI state and DB");
  }

  /// Check if a specific message is currently being resent
  bool _isResendingFailedMessage(String messageId) {
    return _resendingFailedMessages[messageId] == true;
  }

  /// Resend a failed message
  Future<void> resendFailedMessage(String messageId) async {
    // Skip if already resending this message
    if (_isResendingFailedMessage(messageId)) return;

    try {
      // Mark as resending in the map and update UI
      _safeSetState(() {
        _resendingFailedMessages[messageId] = true;
      });

      // Fetch the message from local DB
      final message = await _messagesRepo.getMessageById(messageId);

      if (message == null) {
        debugPrint('Message not found: $messageId');
        return;
      }

      // Check if message is marked as failed
      if (!message.isFailed) {
        debugPrint('Message is not in failed status');
        return;
      }

      // Preserve reply target if the failed message was a reply
      MessageModel? originalReplyToMessageData = _replyToMessageData;
      final replyToMessageId = message.repliedTo;
      if (replyToMessageId != null) {
        final replyToMessage = await _messagesRepo.getMessageById(
          replyToMessageId,
        );
        if (replyToMessage != null) {
          _replyToMessageData = replyToMessage;
        }
      }

      try {
        // Check if it's a media message (image, video, audio, document)
        final isMediaMessage =
            message.type == MessageType.image ||
            message.type == MessageType.video ||
            message.type == MessageType.audio ||
            message.type == MessageType.document;

        if (isMediaMessage) {
          // Check if attachments contain local_path
          final localPath = message.attachments?['local_path'] as String?;

          if (localPath == null || localPath.isEmpty) {
            debugPrint(
              'No local_path found in attachments for failed media message',
            );
            return;
          }

          // Check if file exists
          final mediaFile = File(localPath);
          if (!mediaFile.existsSync()) {
            debugPrint('Media file not found at path: $localPath');
            return;
          }

          // Resend via _sendMediaMessageToServer with existing messageId
          await _sendMediaMessageToServer(
            mediaFile,
            message.type,
            existingMessageId: messageId,
          );
        } else {
          // For text and other non-media messages, resend directly via _sendMessage
          _sendMessage(message.type, messageId: messageId, body: message.body);
        }
      } finally {
        // Restore original reply message data
        _replyToMessageData = originalReplyToMessageData;
      }
    } catch (e) {
      debugPrint('Error resending failed message: $e');
    } finally {
      // Clear resending state for this message
      if (_canSetState) {
        _safeSetState(() {
          _resendingFailedMessages.remove(messageId);
        });
      } else {
        _resendingFailedMessages.remove(messageId);
      }
    }
  }

  /// Auto-resend all failed messages in this conversation (called on reconnection)
  Future<void> _resendAllFailedMessages() async {
    // Collect failed messages from the in-memory list (already loaded)
    final failedMessages = _messages
        .where(
          (msg) =>
              msg.isFailed &&
              msg.senderId == _currentUserDetails?.id &&
              !_isResendingFailedMessage(msg.id),
        )
        .toList();

    if (failedMessages.isEmpty) return;

    debugPrint(
      '[RESEND] Auto-resending ${failedMessages.length} failed messages',
    );

    // Resend sequentially to avoid overwhelming the server
    for (final msg in failedMessages) {
      if (!mounted) break;
      await resendFailedMessage(msg.id);
    }
  }

  // Future<void> _resendFailedMessage(MessageModel failedMessage) async {
  //   // Find the message index in the UI
  //   final index = _messages.indexWhere(
  //     (msg) =>
  //         msg.id == failedMessage.id ||
  //         msg.optimisticId == failedMessage.optimisticId,
  //   );
  //
  //   // Set uploading state immediately for visual feedback
  //   final uploadingMetadata = Map<String, dynamic>.from(
  //     failedMessage.metadata ?? {},
  //   );
  //   uploadingMetadata.remove('upload_failed');
  //   uploadingMetadata['is_uploading'] = true;
  //   uploadingMetadata['upload_progress'] = 0; // Initialize progress to 0
  //
  //   final uploadingMessage = failedMessage.copyWith(
  //     status: MessageStatusType.sent,
  //     metadata: uploadingMetadata,
  //   );
  //
  //   // Update in UI immediately to show uploading state
  //   if (index != -1 && _canSetState) {
  //     _safeSetState(() {
  //       _messages[index] = uploadingMessage;
  //     });
  //   }
  //
  //   // Save uploading state to DB
  //   await _messagesRepo.insertMessage(uploadingMessage);
  //
  //   // Handle media messages differently - need to upload first
  //   if (failedMessage.type != MessageType.text) {
  //     try {
  //       // Get the local file path from either localMediaPath or attachments
  //       String? localPath = failedMessage.localMediaPath;
  //       if (localPath == null || localPath.isEmpty) {
  //         localPath = failedMessage.attachments?['local_path'] as String?;
  //       }
  //
  //       if (localPath == null || localPath.isEmpty) {
  //         debugPrint('Error: No local path found for failed media message');
  //         await _markMessageAsFailed(
  //           failedMessage.optimisticId ?? failedMessage.id,
  //         );
  //         return;
  //       }
  //
  //       final mediaFile = File(localPath);
  //       if (!mediaFile.existsSync()) {
  //         debugPrint('Error: Media file not found at path: $localPath');
  //         await _markMessageAsFailed(
  //           failedMessage.optimisticId ?? failedMessage.id,
  //         );
  //         return;
  //       }
  //
  //       // Upload the media to server first
  //       int? lastProgressUpdate = -1;
  //
  //       final response = await _chatsServices.sendMediaMessage(
  //         mediaFile,
  //         onSendProgress: (sent, total) {
  //           // Calculate progress percentage
  //           final progress = total > 0 ? ((sent / total) * 100).round() : 0;
  //
  //           // Update immediately if progress changed
  //           if (progress != lastProgressUpdate && index != -1 && _canSetState) {
  //             lastProgressUpdate = progress;
  //
  //             final currentMsg = _messages[index];
  //             final updatedMetadata = Map<String, dynamic>.from(
  //               currentMsg.metadata ?? {},
  //             );
  //             updatedMetadata['upload_progress'] = progress;
  //             updatedMetadata['is_uploading'] = true;
  //
  //             final updatedMessage = currentMsg.copyWith(
  //               metadata: updatedMetadata,
  //             );
  //
  //             _safeSetState(() {
  //               _messages[index] = updatedMessage;
  //             });
  //           }
  //         },
  //       );
  //
  //       if (response['success'] == true && response['data'] != null) {
  //         final mediaData = MediaResponse.fromJson(response['data']);
  //
  //         // Update message with the new attachments (server URLs)
  //         final updatedMessage = uploadingMessage.copyWith(
  //           attachments: mediaData.toJson(),
  //         );
  //
  //         // Update in UI
  //         if (index != -1 && _canSetState) {
  //           _safeSetState(() {
  //             _messages[index] = updatedMessage;
  //           });
  //         }
  //
  //         // Save to DB
  //         await _messagesRepo.insertMessage(updatedMessage);
  //
  //         // Now send the message with proper MediaResponse
  //         final messagePayload = ChatMessagePayload(
  //           optimisticId: failedMessage.optimisticId ?? failedMessage.id,
  //           convId: failedMessage.conversationId,
  //           senderId: failedMessage.senderId,
  //           senderName: failedMessage.senderName,
  //           attachments: mediaData,
  //           convType: ChatType.dm,
  //           msgType: failedMessage.type,
  //           body: failedMessage.body,
  //           replyToMessageId:
  //               failedMessage.metadata?['reply_to']?['message_id'],
  //           sentAt: DateTime.parse(failedMessage.sentAt),
  //         );
  //
  //         final wsmsg = WSMessage(
  //           type: WSMessageType.messageNew,
  //           payload: messagePayload,
  //           wsTimestamp: DateTime.now(),
  //         ).toJson();
  //
  //         await _webSocket
  //             .sendMessage(wsmsg)
  //             .then((_) {
  //               // Keep the message in the list with loading state
  //               // The server will send back the message via WebSocket and we'll update it
  //               // Save success state to DB (server will send back the actual message)
  //               final successMetadata = Map<String, dynamic>.from(
  //                 updatedMessage.metadata ?? {},
  //               );
  //               successMetadata['is_uploading'] =
  //                   true; // Keep loading until server responds
  //               final successMessage = updatedMessage.copyWith(
  //                 metadata: successMetadata,
  //               );
  //               _messagesRepo.insertMessage(successMessage);
  //             })
  //             .catchError((e) async {
  //               debugPrint('Error resending media message: $e');
  //               // Mark as failed again
  //               await _markMessageAsFailed(
  //                 failedMessage.optimisticId ?? failedMessage.id,
  //               );
  //             });
  //       } else {
  //         debugPrint('Error: Failed to upload media for resend');
  //         await _markMessageAsFailed(
  //           failedMessage.optimisticId ?? failedMessage.id,
  //         );
  //       }
  //     } catch (e) {
  //       debugPrint('Error resending media message: $e');
  //       // Mark as failed again
  //       await _markMessageAsFailed(
  //         failedMessage.optimisticId ?? failedMessage.id,
  //       );
  //     }
  //     return;
  //   }
  //
  //   // Handle text messages
  //   try {
  //     final messagePayload = ChatMessagePayload(
  //       optimisticId: failedMessage.optimisticId ?? failedMessage.id,
  //       convId: failedMessage.conversationId,
  //       senderId: failedMessage.senderId,
  //       senderName: failedMessage.senderName,
  //       attachments: failedMessage.attachments,
  //       convType: ChatType.dm,
  //       msgType: failedMessage.type,
  //       body: failedMessage.body,
  //       replyToMessageId: failedMessage.metadata?['reply_to']?['message_id'],
  //       sentAt: DateTime.parse(failedMessage.sentAt),
  //     );
  //
  //     final wsmsg = WSMessage(
  //       type: WSMessageType.messageNew,
  //       payload: messagePayload,
  //       wsTimestamp: DateTime.now(),
  //     ).toJson();
  //
  //     await _webSocket
  //         .sendMessage(wsmsg)
  //         .then((_) {
  //           // Keep the message in the list with loading state
  //           // The server will send back the message via WebSocket and we'll update it
  //           // Save success state to DB (server will send back the actual message)
  //           final successMetadata = Map<String, dynamic>.from(
  //             uploadingMessage.metadata ?? {},
  //           );
  //           successMetadata['is_uploading'] =
  //               true; // Keep loading until server responds
  //           final successMessage = uploadingMessage.copyWith(
  //             metadata: successMetadata,
  //           );
  //           _messagesRepo.insertMessage(successMessage);
  //         })
  //         .catchError((e) async {
  //           debugPrint('Error resending message: $e');
  //           // Mark as failed again
  //           await _markMessageAsFailed(
  //             failedMessage.optimisticId ?? failedMessage.id,
  //           );
  //         });
  //   } catch (e) {
  //     debugPrint('Error resending message: $e');
  //     // Mark as failed again
  //     await _markMessageAsFailed(
  //       failedMessage.optimisticId ?? failedMessage.id,
  //     );
  //   }
  // }

  void _enterSelectionMode(String messageId) {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _selectedMessages.add(messageId);
    });
  }

  void _togglePinMessage(MessageModel message) async {
    // Check if this message is currently pinned by comparing IDs
    final messageId = message.id;
    final pinnedMessageId = _pinnedMessage?.id;
    final wasPinned = messageId == pinnedMessageId && _pinnedMessage != null;
    final newPinnedMessageId = wasPinned ? null : message.id;

    // Clear or set pinned message immediately for instant UI feedback
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _pinnedMessage = wasPinned ? null : message;
    });

    await ChatHelpers.togglePinMessage(
      message: message,
      conversationId: widget.dm.chatId,
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
        .updatePinnedMessageInState(widget.dm.chatId, newPinnedMessageId);
  }

  void _toggleStarMessage(String messageId) async {
    if (_starEnabled) {
      /* star disabled */
    }
  }

  /// React to a message with an emoji (toggle: add if not reacted, remove if already reacted)
  void _reactToMessage(MessageModel message, String emoji) async {
    if (_currentUserDetails == null) return;

    final msgReactions = _reactionsByMessage[message.id] ?? {};
    final emojiUsers =
        (msgReactions[emoji] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final alreadyReacted = emojiUsers.any(
      (u) => u['user_id']?.toString() == _currentUserDetails!.id,
    );
    final action = alreadyReacted ? 'remove' : 'add';

    // Write to local DB immediately so the Drift stream re-emits
    await _messageStatusRepo.upsertReaction(
      messageId: message.id,
      userId: _currentUserDetails!.id,
      chatId: widget.dm.chatId,
      emoji: action == 'add' ? emoji : null,
    );

    // Fire to backend (which will broadcast to other conversation members)
    try {
      await apiService.chat.reactToMessage(
        messageId: message.id,
        conversationId: widget.dm.chatId,
        emoji: emoji,
        action: action,
        senderName: _currentUserDetails!.name,
      );
    } catch (e) {
      debugPrint('❌ Failed to send reaction: $e');
    }
  }

  void _replyToMessage(MessageModel message) async {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _replyToMessageData = message;
    });
    // Keep keyboard open — re-request focus after the layout settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canSetState) _messageFocusNode.requestFocus();
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

  void _deleteMessage(
    String messageId, {
    bool deleteForEveryone = false,
  }) async {
    try {
      if (deleteForEveryone) {
        // Delete for everyone - only own messages
        final message = _messages.firstWhere((m) => m.id == messageId);
        if (message.senderId != _currentUserDetails?.id) {
          Snack.warning('You can only delete your own messages for everyone');
          return;
        }

        // delete from local database
        await _messagesRepo.deleteMessage(messageId);

        // Remove from UI immediately
        if (_canSetState) {
          _safeSetState(() {
            _messages.removeWhere((message) => message.id == messageId);
          });
        }

        // Call API
        final response = (await apiService.chat.deleteMessage([
          messageId,
        ])).toMap();

        if (response['success'] == true) {
          // Update provider
          ref
              .read(chatProvider.notifier)
              .handleMessageDelete(
                DeleteMessagePayload(
                  messageIds: [messageId],
                  convId: widget.dm.chatId,
                  senderId: _currentUserDetails?.id ?? '',
                ),
              )
              .catchError((e) {
                debugPrint('❌ Error deleting messages: $e');
              });

          // Send WebSocket message
          final deleteMessagePayload = DeleteMessagePayload(
            messageIds: [messageId],
            convId: widget.dm.chatId,
            senderId: _currentUserDetails?.id ?? '',
          ).toJson();

          final wsmsg = WSMessage(
            type: WSMessageType.messageDelete,
            payload: deleteMessagePayload,
            wsTimestamp: DateTime.now(),
          ).toJson();

          _transportManager.sendMessage(wsmsg).catchError((e) {
            debugPrint('❌ Error sending message delete: $e');
            return false;
          });
        } else {
          Snack.error(response['message'] ?? 'Failed to delete message');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      Snack.error('Failed to delete message');
    }
  }

  void _deleteMessageForMe(String messageId) async {
    try {
      // Remove from UI immediately
      if (_canSetState) {
        _safeSetState(() {
          _messages.removeWhere((message) => message.id == messageId);
        });
      }

      // Call API
      final response = (await apiService.chat.deleteMessageForMe(
        messageIds: [messageId],
        conversationId: widget.dm.chatId,
      )).toMap();

      if (response['success'] == true) {
        // delete from local database
        await _messagesRepo.deleteMessage(messageId);
      }
    } catch (e) {
      debugPrint('❌ Error deleting message for me: $e');
      // Restore message on error
      if (_canSetState) {
        final messagesFromLocal = await _messagesRepo.getMessagesByConversation(
          widget.dm.chatId,
          limit: 100,
          offset: 0,
        );
        _safeSetState(() {
          _messages = messagesFromLocal;
          _sortMessagesBySentAt();
        });
      }
      Snack.error('Failed to delete message');
    }
  }

  void _bulkStarMessages() async {
    if (_starEnabled) {
      /* star disabled */
    }
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
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!_canSetState) return;
        _safeSetState(() {
          _isInputFocused = isFocused;
        });
      },
      dm: widget.dm,
      recommendations: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _messageController,
        builder: (context, value, child) {
          final text = value.text.trim();
          // Show recommendations if text is empty OR if it matches one of the recommendations
          // if (text.isEmpty || _messageRecommendations.contains(text)) {
          return MessageRecommendations(
            recommendations: _messageRecommendations,
            onRecommendationTap: _onRecommendationTap,
          );
          // }
          // return const SizedBox.shrink();
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

      // if (failedMessage != null) {
      //   // Retry: Get file info from failed message
      //   final attachments = failedMessage.attachments;
      //   final localPath = attachments?['local_path'] as String?;
      //   duration = attachments?['duration'] as int?;
      //
      //   if (localPath == null || !File(localPath).existsSync()) {
      //     _showErrorDialog(
      //       'Original recording not found. Please record again.',
      //     );
      //     return;
      //   }
      //
      //   voiceFile = File(localPath);
      // } else {
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
      // }

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
  Future<void> _initiateCall(
    String userId,
    String userName,
    String? userProfilePic,
  ) async {
    try {
      final callServiceNotifier = ref.read(callServiceProvider.notifier);
      await callServiceNotifier.initiateCall(
        widget.dm.recipientId,
        widget.dm.recipientName,
        widget.dm.recipientProfilePic,
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
    _jumpMessages = [];
    _isInJumpMode = false;

    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _messagesStreamSub?.cancel();
    _reactionsSubscription?.cancel();
    _deliveryStatusSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageAckSubscription?.cancel();
    _typingSubscription?.cancel();
    _messagePinSubscription?.cancel();
    // _messageReplySubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _transportConnectionSubscription?.cancel();
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
      draftNotifier.saveDraft(widget.dm.chatId, _messageController.text);
    }

    // Remove listener
    _messageController.removeListener(_onMessageTextChanged);
    // _currentStickyDate.dispose();
    // _showStickyDate.dispose();

    // Clear active conversation when leaving the messaging screen
    ref.read(chatProvider.notifier).setActiveConversation(null, null);

    // Clear unread count in local DB
    _conversationsRepo.updateUnreadCount(widget.dm.chatId, 0);

    // conversationLeave was removed; the server infers leave from
    // the absence of heartbeat / next join.

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

    // Dispose search controller and timer
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _highlightTimer?.cancel();

    // Clear message keys
    _messageKeys.clear();

    super.dispose();
  }
}
