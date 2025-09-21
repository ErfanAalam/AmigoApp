import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../api/chats.services.dart';
import '../../api/user.service.dart';
import '../../services/message_storage_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/media_preview_widgets.dart';

class InnerChatPage extends StatefulWidget {
  final ConversationModel conversation;

  const InnerChatPage({Key? key, required this.conversation}) : super(key: key);

  @override
  State<InnerChatPage> createState() => _InnerChatPageState();
}

class _InnerChatPageState extends State<InnerChatPage>
    with TickerProviderStateMixin {
  final ChatsServices _chatsServices = ChatsServices();
  final UserService _userService = UserService();
  final MessageStorageService _storageService = MessageStorageService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final WebSocketService _websocketService = WebSocketService();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>();
  List<MessageModel> _messages = [];
  bool _isLoading = false; // Start false, will be set true only if no cache
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentPage = 1;
  String? _errorMessage;
  int? _currentUserId;
  bool _isInitialized = false;
  ConversationMeta? _conversationMeta;
  bool _isLoadingFromCache = false;
  bool _hasCheckedCache = false; // Track if we've checked cache
  bool _isCheckingCache = true; // Show brief cache check state
  bool _isTyping = false;
  bool _isOtherTyping = false;
  // For optimistic message handling
  StreamSubscription<Map<String, dynamic>>? _websocketSubscription;
  StreamSubscription? _audioProgressSubscription;
  Timer? _audioProgressTimer;
  DateTime? _audioStartTime;
  Duration _customPosition = Duration.zero;
  int _optimisticMessageId = -1; // Negative IDs for optimistic messages
  final Set<int> _optimisticMessageIds = {}; // Track optimistic messages

  // User info cache for sender names and profile pics
  final Map<int, Map<String, String?>> _userInfoCache = {};

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

  // Typing animation controllers
  late AnimationController _typingAnimationController;
  late List<Animation<double>> _typingDotAnimations;
  Timer? _typingTimeout;

  // Message animation controllers
  final Map<int, AnimationController> _messageAnimationControllers = {};
  final Map<int, Animation<double>> _messageSlideAnimations = {};
  final Map<int, Animation<double>> _messageFadeAnimations = {};
  final Set<int> _animatedMessages =
      {}; // Track which messages have been animated

  // Swipe animation controllers for reply gesture
  final Map<int, AnimationController> _swipeAnimationControllers = {};
  final Map<int, Animation<double>> _swipeAnimations = {};

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

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

  /// Ultra-fast cache check that runs immediately
  void _quickCacheCheck() async {
    try {
      final conversationId = widget.conversation.conversationId;

      // Quick synchronous check if cache key exists
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('messages_$conversationId')) {
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
          // final newMessagesCount = backendCount - cachedCount;
          final newMessages = backendMessages.skip(cachedCount).toList();

          // Add new messages to cache
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _storageService.addMessagesToCache(
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

            // Show a subtle notification for new messages (optional)
            // if (newMessagesCount > 0) {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(
            //       content: Text(
            //         '$newMessagesCount new message${newMessagesCount > 1 ? 's' : ''}',
            //       ),
            //       duration: const Duration(seconds: 2),
            //       behavior: SnackBarBehavior.floating,
            //       backgroundColor: Colors.green[600],
            //     ),
            //   );
            // }
          }

          // debugPrint(
          //   '🎉 Smart sync completed: Added $newMessagesCount new messages',
          // );
        } else if (backendCount == cachedCount) {
          // Same count - no new messages

          // Just update metadata in case pagination info changed
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _storageService.saveMessages(
            conversationId: conversationId,
            messages: _messages,
            meta: _conversationMeta!,
          );
        } else {
          // Backend has fewer messages (unlikely but handle it)

          // Replace cache with backend data
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _storageService.saveMessages(
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
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in smart sync: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _initializeChat() async {
    // Get user ID first, then load messages
    // This ensures we can properly identify sender vs receiver messages
    await _getCurrentUserId();

    // Initialize user info cache with conversation participant
    _initializeUserCache();

    // Load pinned message from storage
    await _loadPinnedMessageFromStorage();

    // Load starred messages from storage
    await _loadStarredMessagesFromStorage();

    // Try to load from cache immediately for instant display
    await _tryLoadFromCacheFirst();

    // Then load from server if needed
    await _loadInitialMessages();
  }

  /// Quick cache check and load for instant display
  Future<void> _tryLoadFromCacheFirst() async {
    if (_hasCheckedCache) return; // Avoid double-checking

    try {
      final conversationId = widget.conversation.conversationId;

      final cachedData = await _storageService.getCachedMessages(
        conversationId,
      );

      if (cachedData != null && cachedData.messages.isNotEmpty && mounted) {
        setState(() {
          _isCheckingCache = false; // Stop cache checking state
          _isLoadingFromCache = false; // No loading state needed for cache
          _messages =
              cachedData.messages; // Don't reverse - keep chronological order
          _conversationMeta = cachedData.meta;
          _hasMoreMessages = cachedData.meta.hasNextPage;
          _currentPage = cachedData.meta.currentPage;
          _isInitialized = true;
          _isLoading = false;
          _errorMessage = null;
          _hasCheckedCache = true;
        });

        // Validate pinned message and starred messages exist in cached messages
        _validatePinnedMessage();
        _validateStarredMessages();

        // Validate reply message storage
        _validateReplyMessages();
      } else {
        if (mounted) {
          setState(() {
            _isCheckingCache = false;
            _isLoading = true; // Now show loading since no cache
            _hasCheckedCache = true;
          });
        }
      }
    } catch (e) {
      debugPrint('⚡ Error in quick cache check: $e');
      if (mounted) {
        setState(() {
          _isCheckingCache = false;
          _isLoading = true; // Show loading since cache check failed
          _hasCheckedCache = true;
        });
      }
    }
  }

  Future<void> _getCurrentUserId() async {
    try {
      final response = await _userService.getUser();
      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['data'] ?? response['data'];
        _currentUserId = _parseToInt(userData['id']);
      } else {
        _currentUserId = widget.conversation.userId;
      }
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      // Fallback: try to get from conversation if available
      _currentUserId = widget.conversation.userId;
    }

    // Final fallback - if still null, log warning
    if (_currentUserId == null) {
      // WARNING: Could not determine current user ID. All messages will show as from others.
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
      debugPrint(
        '👤 Cached user info for ${widget.conversation.userId}: ${widget.conversation.userName}',
      );
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

  /// Load pinned message from storage
  Future<void> _loadPinnedMessageFromStorage() async {
    try {
      final conversationId = widget.conversation.conversationId;
      final pinnedMessageId = await _storageService.getPinnedMessage(
        conversationId,
      );

      if (pinnedMessageId != null && mounted) {
        setState(() {
          _pinnedMessageId = pinnedMessageId;
        });
        debugPrint('📌 Loaded pinned message $pinnedMessageId from storage');
      }
    } catch (e) {
      debugPrint('❌ Error loading pinned message from storage: $e');
    }
  }

  /// Load starred messages from storage
  Future<void> _loadStarredMessagesFromStorage() async {
    try {
      final conversationId = widget.conversation.conversationId;
      final starredMessages = await _storageService.getStarredMessages(
        conversationId,
      );

      if (starredMessages.isNotEmpty && mounted) {
        setState(() {
          _starredMessages.clear();
          _starredMessages.addAll(starredMessages);
        });
        debugPrint(
          '⭐ Loaded ${starredMessages.length} starred messages from storage',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading starred messages from storage: $e');
    }
  }

  /// Validate pinned message exists in current messages and clean up if not
  void _validatePinnedMessage() {
    if (_pinnedMessageId != null && _messages.isNotEmpty) {
      final messageExists = _messages.any((msg) => msg.id == _pinnedMessageId);
      if (!messageExists && mounted) {
        debugPrint(
          '⚠️ Pinned message $_pinnedMessageId not found in current messages, clearing',
        );
        setState(() {
          _pinnedMessageId = null;
        });
        // Also clear from storage
        _storageService.savePinnedMessage(
          conversationId: widget.conversation.conversationId,
          pinnedMessageId: null,
        );
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
          '⚠️ ${invalidStarredMessages.length} starred messages not found in current messages, cleaning up',
        );

        setState(() {
          _starredMessages.removeAll(invalidStarredMessages);
        });

        // Update storage with cleaned up starred messages
        _storageService.saveStarredMessages(
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
            // Reply message is already available in the message object
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
        await _storageService.validateReplyMessageStorage(
          widget.conversation.conversationId,
        );
      } catch (e) {
        debugPrint('❌ Error validating reply messages: $e');
      }
    });
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

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _websocketSubscription?.cancel();
    _typingAnimationController.dispose();
    _typingTimeout?.cancel();

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

    // Properly close the audio player
    try {
      if (_audioPlayer.isPlaying) {
        _audioPlayer.stopPlayer();
      }
      _audioProgressSubscription?.cancel();
      _stopAudioProgressTimer();
      _audioPlayer.closePlayer();
    } catch (e) {
      print('Warning: Error closing audio player during dispose: $e');
    }

    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreMessages) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final conversationId = widget.conversation.conversationId;
      debugPrint(
        '🔄 Loading initial messages for conversation $conversationId',
      );

      // If we already have messages from cache, do smart sync
      if (_hasCheckedCache && _messages.isNotEmpty) {
        debugPrint('📦 Already have cached messages, doing smart sync...');

        // Always check backend for new messages (but silently)
        await _performSmartSync(conversationId);
        return;
      } else if (!_hasCheckedCache) {
        // This is a fallback if quick cache check didn't work
        debugPrint('📦 Fallback: checking cache in _loadInitialMessages');

        final cachedData = await _storageService.getCachedMessages(
          conversationId,
        );

        if (cachedData != null && cachedData.messages.isNotEmpty) {
          debugPrint('📦 Found cache in fallback check');
          if (mounted) {
            setState(() {
              _isCheckingCache = false;
              _isLoadingFromCache = false; // No loading state for cache
              _messages = cachedData
                  .messages; // Don't reverse - keep chronological order
              _conversationMeta = cachedData.meta;
              _hasMoreMessages = cachedData.meta.hasNextPage;
              _currentPage = cachedData.meta.currentPage;
              _isInitialized = true;
              _isLoading = false;
              _errorMessage = null;
              _hasCheckedCache = true;
            });
          }

          // Check if cache is fresh
          final isStale = await _storageService.isCacheStale(
            conversationId,
            maxAgeMinutes: 5,
          );

          if (!isStale) {
            if (mounted) {
              setState(() {
                _isLoadingFromCache = false;
              });
            }
            debugPrint('📱 Fallback cache is fresh, no server request needed');
            return;
          }
        }
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
        final response = await _chatsServices.getConversationHistory(
          conversationId: conversationId,
          page: 1,
          limit: 20,
        );

        print('🌐 Server response received: ${response}');

        if (!mounted) return; // Prevent setState if widget is disposed

        debugPrint('🌐 Server response received: ${response['success']}');
        if (response['success'] == true && response['data'] != null) {
          final historyResponse = ConversationHistoryResponse.fromJson(
            response['data'],
          );

          // Keep messages in chronological order (oldest first)
          final processedMessages = historyResponse.messages;
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);

          // Save to cache
          await _storageService.saveMessages(
            conversationId: conversationId,
            messages: historyResponse.messages, // Save in chronological order
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

          // Validate pinned message and starred messages exist in loaded messages
          _validatePinnedMessage();
          _validateStarredMessages();

          // Validate reply message storage
          _validateReplyMessages();

          debugPrint(
            '🌐 Loaded ${processedMessages.length} messages from server and cached',
          );
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load messages';
            _isLoading = false;
            _isLoadingFromCache = false;
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading messages from server: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Error: ${e.toString()}';
            _isLoading = false;
            _isLoadingFromCache = false;
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Critical error in _loadInitialMessages: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load messages: ${e.toString()}';
          _isLoading = false;
          _isLoadingFromCache = false;
          _isInitialized =
              true; // Ensure we don't stay in loading state forever
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
      final conversationId = widget.conversation.conversationId;
      final response = await _chatsServices.getConversationHistory(
        conversationId: conversationId,
        page: _currentPage + 1,
        limit: 20,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final historyResponse = ConversationHistoryResponse.fromJson(
          response['data'],
        );
        // Keep chronological order for older messages
        final newMessages = historyResponse.messages;

        // Update conversation metadata
        _conversationMeta = ConversationMeta.fromResponse(historyResponse);

        // Add to cache (insert at beginning for older messages)
        await _storageService.addMessagesToCache(
          conversationId: conversationId,
          newMessages: historyResponse.messages, // Save in chronological order
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

        // Update the AnimatedList to reflect the new item count
        // Since we're inserting at the beginning, we need to update the list
        // The AnimatedList will handle the animation for existing items
        if (_animatedListKey.currentState != null) {
          // For pagination, we don't need to animate individual insertions
          // Just rebuild the list with the new count
          _animatedListKey.currentState!.setState(() {});
        }

        debugPrint('📄 Loaded ${newMessages.length} more messages and cached');
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

  /// Set up WebSocket message listener for real-time messages
  void _setupWebSocketListener() {
    _websocketSubscription = _websocketService.messageStream.listen(
      (message) {
        _handleIncomingWebSocketMessage(message);
      },
      onError: (error) {
        debugPrint('❌ WebSocket message stream error: $error');
      },
    );
  }

  /// Handle incoming WebSocket messages
  void _handleIncomingWebSocketMessage(Map<String, dynamic> message) {
    try {
      debugPrint('📨 Received WebSocket message: $message');

      // Check if this is a message for our conversation
      final messageConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];

      if (messageConversationId != widget.conversation.conversationId) {
        return; // Not for this conversation
      }

      // Handle different message types
      final messageType = message['type'];
      if (messageType == 'message') {
        _handleIncomingMessage(message);
      } else if (messageType == 'typing') {
        _reciveTyping(message);
      } else if (messageType == 'message_pin') {
        _handleMessagePin(message);
      } else if (messageType == 'message_star') {
        _handleMessageStar(message);
      } else if (messageType == 'message_reply') {
        _handleMessageReply(message);
      } else if (messageType == 'media') {
        _handleIncomingMediaMessages(message);
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message: $e');
    }
  }

  void _handleMessageReply(Map<String, dynamic> message) {
    print('🔍 Handling message reply: $message');
    // Reply messages are handled through the regular message flow
    // The reply data is embedded in the message data itself
    _handleIncomingMessage(message);
  }

  /// Handle incoming message pin from WebSocket
  void _handleMessagePin(Map<String, dynamic> message) async {
    print('🔍 Handling message pin: $message');
    final data = message['data'] as Map<String, dynamic>? ?? {};
    final messageId = data['message_id'] ?? data['messageId'];
    final action = data['action'] ?? 'pin';
    final conversationId = widget.conversation.conversationId;

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
    await _storageService.savePinnedMessage(
      conversationId: conversationId,
      pinnedMessageId: newPinnedMessageId,
    );

    print('📌 Updated pinned message from WebSocket: $_pinnedMessageId');
  }

  /// Handle incoming message star from WebSocket
  void _handleMessageStar(Map<String, dynamic> message) async {
    print('🔍 Handling message star: $message');
    final data = message['data'] as Map<String, dynamic>? ?? {};
    final messagesIds = message['message_ids'] as List<int>? ?? [];
    final action = data['action'] ?? 'star';
    final conversationId = widget.conversation.conversationId;

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
          await _storageService.starMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
        } else {
          await _storageService.unstarMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
        }
      }
      print(
        '⭐ Updated ${messagesIds.length} starred messages from WebSocket in local storage',
      );
    } catch (e) {
      print('❌ Error updating starred messages from WebSocket in storage: $e');
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

      // print('message with optimistic is: $_shallcachedMessages')

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

      // If this is our own message (sender), update the optimistic message in local storage
      if (_currentUserId != null && senderId == _currentUserId) {
        debugPrint(
          '🔄 Updating own message from optimistic ID to server ID in local storage',
        );
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
        // IMPORTANT: Call insertItem BEFORE adding to the list for AnimatedList
        // _animatedListKey.currentState?.insertItem(
        //   _messages.length, // Insert at the end (current length)
        //   duration: const Duration(
        //     milliseconds: 500,
        //   ), // Longer duration for smoother animation
        // );

        setState(() {
          _messages.add(newMessage);
        });

        _animateNewMessage(newMessage.id);
        _scrollToBottom();
      }

      // Store message asynchronously
      _storeMessageAsync(newMessage);
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  /// Update optimistic message in local storage with server ID (for sender's own messages)
  Future<void> _updateOptimisticMessageInStorage(
    int? optimisticId,
    int? serverId,
    Map<String, dynamic> messageData,
  ) async {
    if (optimisticId == null || serverId == null) return;

    try {
      // Get current cached messages
      final cachedData = await _storageService.getCachedMessages(
        widget.conversation.conversationId,
      );

      if (cachedData == null || cachedData.messages.isEmpty) {
        debugPrint('⚠️ No cached messages found to update');
        return;
      }

      // Find the optimistic message in cached data
      final messageIndex = cachedData.messages.indexWhere(
        (msg) => msg.id == optimisticId,
      );

      if (messageIndex == -1) {
        debugPrint('⚠️ Optimistic message $optimisticId not found in cache');
        return;
      }

      // Create updated message with server ID
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final originalMessage = cachedData.messages[messageIndex];

      final updatedMessage = MessageModel(
        id: serverId, // Use server ID instead of optimistic ID
        body: data['body'] ?? originalMessage.body,
        type: data['type'] ?? originalMessage.type,
        senderId: originalMessage.senderId,
        conversationId: originalMessage.conversationId,
        createdAt: data['created_at'] ?? originalMessage.createdAt,
        editedAt: data['edited_at'] ?? originalMessage.editedAt,
        metadata: data['metadata'] ?? originalMessage.metadata,
        attachments: data['attachments'] ?? originalMessage.attachments,
        deleted: data['deleted'] == true,
        senderName: originalMessage.senderName,
        senderProfilePic: originalMessage.senderProfilePic,
        replyToMessage: originalMessage.replyToMessage,
        replyToMessageId: originalMessage.replyToMessageId,
      );

      // Update the message in the cached messages list
      final updatedMessages = List<MessageModel>.from(cachedData.messages);
      updatedMessages[messageIndex] = updatedMessage;

      // Save updated messages back to storage
      await _storageService.saveMessages(
        conversationId: widget.conversation.conversationId,
        messages: updatedMessages,
        meta: cachedData.meta,
      );

      // Also update the in-memory _messages list
      final uiMessageIndex = _messages.indexWhere(
        (msg) => msg.id == optimisticId,
      );
      if (uiMessageIndex != -1 && mounted) {
        setState(() {
          _messages[uiMessageIndex] = updatedMessage;
        });
      }

      debugPrint(
        '✅ Updated message ID from $optimisticId to $serverId in local storage and UI',
      );
    } catch (e) {
      debugPrint('❌ Error updating optimistic message in storage: $e');
    }
  }

  /// Replace optimistic message with server-confirmed message
  void _replaceOptimisticMessage(
    int messageId,
    Map<String, dynamic> messageData,
  ) {
    try {
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        // Create the confirmed message
        final data = messageData['data'] as Map<String, dynamic>? ?? {};
        final senderId = data['sender_id'] != null
            ? _parseToInt(data['sender_id'])
            : _messages[index].senderId;

        // Get updated sender info from cache/lookup
        final senderInfo = _getUserInfo(senderId);
        final senderName = senderInfo['name'] ?? _messages[index].senderName;
        final senderProfilePic =
            senderInfo['profile_pic'] ?? _messages[index].senderProfilePic;

        final confirmedMessage = MessageModel(
          id: data['id'] ?? data['messageId'] ?? messageId,
          body: data['body'] ?? _messages[index].body,
          type: data['type'] ?? _messages[index].type,
          senderId: senderId,
          conversationId: widget.conversation.conversationId,
          createdAt: data['created_at'] ?? _messages[index].createdAt,
          editedAt: data['edited_at'],
          metadata: data['metadata'],
          attachments: data['attachments'],
          deleted: data['deleted'] == true,
          senderName: senderName,
          senderProfilePic: senderProfilePic,
        );

        if (mounted) {
          setState(() {
            _messages[index] = confirmedMessage;
          });
        }

        // Remove from optimistic tracking
        _optimisticMessageIds.remove(messageId);

        // Store confirmed message
        _storeMessageAsync(confirmedMessage);
      }
    } catch (e) {
      debugPrint('❌ Error replacing optimistic message: $e');
    }
  }

  void _handleTyping(String value) async {
    final wasTyping = _isTyping;
    final isTyping = value.isNotEmpty;

    setState(() {
      _isTyping = isTyping;
    });

    // Only send websocket message if typing state changed
    if (wasTyping != isTyping) {
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

    setState(() {
      _isOtherTyping = isTyping;
    });

    // Control the typing animation
    if (isTyping) {
      _typingAnimationController.repeat(reverse: true);

      // Set a safety timeout to hide typing indicator after 5 seconds
      _typingTimeout = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isOtherTyping = false;
          });
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
      final senderId = _parseToInt(data['sender_id'] ?? data['senderId']);
      final messageId = data['id'] ?? data['messageId'];
      final optimisticId = data['optimistic_id'] ?? data['optimisticId'];

      // Skip if this is our own optimistic message being echoed back
      if (_optimisticMessageIds.contains(optimisticId)) {
        debugPrint('🔄 Replacing optimistic media message with server message');
        _replaceOptimisticMessage(optimisticId, messageData);
        return;
      }

      // If this is our own message (sender), update the optimistic message in local storage
      if (_currentUserId != null && senderId == _currentUserId) {
        debugPrint(
          '🔄 Updating own media message from optimistic ID to server ID in local storage',
        );
        await _updateOptimisticMessageInStorage(
          optimisticId,
          messageId,
          messageData,
        );
        return;
      }

      // Get sender info from cache/lookup
      final senderInfo = _getUserInfo(senderId);
      final senderName = senderInfo['name'] ?? 'Unknown User';
      final senderProfilePic = senderInfo['profile_pic'];

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

      debugPrint(
        '📱 Received incoming media message: $mediaType from $senderName',
      );

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
        });

        _animateNewMessage(newMediaMessage.id);
        _scrollToBottom();
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
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);

    // Decrement for next optimistic message

    // Add message to UI immediately with animation
    if (mounted) {
      // IMPORTANT: Call insertItem BEFORE adding to the list for AnimatedList
      // _animatedListKey.currentState?.insertItem(
      //   _messages.length, // Insert at the end (current length)
      //   duration: const Duration(
      //     milliseconds: 500,
      //   ), // Longer duration for smoother animation
      // );

      setState(() {
        _messages.add(optimisticMessage);
      });

      _animateNewMessage(optimisticMessage.id);
      _scrollToBottom();
    }

    // Store message immediately in cache (optimistic storage)
    _storeMessageAsync(optimisticMessage);

    try {
      // Prepare WebSocket message data
      final messageData = {
        'type': 'text',
        'body': messageText,
        'optimistic_id': _optimisticMessageId,
      };

      // Add reply data if replying to a message
      if (replyMessageId != null) {
        messageData['reply_to_message_id'] = replyMessageId.toString();
      }

      // Send message through WebSocket
      await _websocketService.sendMessage({
        'type': 'message',
        'data': messageData,
        'conversation_id': widget.conversation.conversationId,
      });

      _optimisticMessageId--;

      debugPrint('✅ Message sent successfully via WebSocket');
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
          content: Text('Failed to send message: $error'),
          backgroundColor: Colors.red,
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
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      final message = _messages[index];

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
          await _storageService.addMessageToCache(
            conversationId: widget.conversation.conversationId,
            newMessage: message,
            updatedMeta: _conversationMeta!.copyWith(
              totalCount: _conversationMeta!.totalCount + 1,
            ),
            insertAtBeginning: false, // Add new messages at the end
          );

          // Debug reply message storage
          if (message.replyToMessage != null) {
            debugPrint(
              '💾 Reply message stored: ${message.id} -> ${message.replyToMessage!.id} (${message.replyToMessage!.senderName})',
            );
          } else {
            debugPrint('💾 Regular message stored: ${message.id}');
          }

          // Validate reply message storage periodically
          if (message.replyToMessage != null) {
            await _storageService.validateReplyMessageStorage(
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

  DateTime _convertToIST(String dateTimeString) {
    try {
      // Parse the datetime - handle both UTC and local formats
      DateTime parsedDateTime;
      if (dateTimeString.endsWith('Z')) {
        // Already UTC format
        parsedDateTime = DateTime.parse(dateTimeString).toUtc();
      } else if (dateTimeString.contains('+') || dateTimeString.contains('T')) {
        // ISO format with timezone or T separator
        parsedDateTime = DateTime.parse(dateTimeString).toUtc();
      } else {
        // Assume local format, convert to UTC first
        parsedDateTime = DateTime.parse(dateTimeString).toUtc();
      }

      // Convert to IST (UTC+5:30)
      final istDateTime = parsedDateTime.add(
        const Duration(hours: 5, minutes: 30),
      );

      return istDateTime;
    } catch (e) {
      debugPrint('Error converting to IST: $e for input: $dateTimeString');
      // Return current IST time as fallback
      return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    }
  }

  String _formatMessageTime(String dateTimeString) {
    try {
      final dateTime = _convertToIST(dateTimeString);
      // Always return just time for chat bubble in 12-hour format
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      debugPrint('Error formatting message time: $e');
      return '';
    }
  }

  String _formatDateSeparator(String dateTimeString) {
    try {
      final messageDateTime = _convertToIST(dateTimeString);
      // Get current IST time
      final nowUTC = DateTime.now().toUtc();
      final nowIST = nowUTC.add(const Duration(hours: 5, minutes: 30));

      final today = DateTime(nowIST.year, nowIST.month, nowIST.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate = DateTime(
        messageDateTime.year,
        messageDateTime.month,
        messageDateTime.day,
      );
      if (messageDate == today) {
        return 'Today';
      } else if (messageDate == yesterday) {
        return 'Yesterday';
      } else {
        // Format as "DD MMM YYYY" or "DD MMM" for current year
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final monthName = months[messageDateTime.month - 1];

        if (messageDateTime.year == nowIST.year) {
          return '${messageDateTime.day} $monthName';
        } else {
          return '${messageDateTime.day} $monthName ${messageDateTime.year}';
        }
      }
    } catch (e) {
      debugPrint('Error formatting date separator: $e');
      return 'Unknown Date';
    }
  }

  bool _shouldShowDateSeparator(int index) {
    try {
      // Get the current message (the one we're checking)
      final currentMessage = _messages[_messages.length - 1 - index];

      // For the first message (newest), check if we need a separator
      if (index == 0) {
        // Always show separator for the first (newest) message
        debugPrint(
          'Showing separator for newest message: ${currentMessage.id}',
        );
        return true;
      }

      // Get the previous message in the list (chronologically newer, displayed above)
      final previousMessage = _messages[_messages.length - index];

      // Convert both to IST and get date parts
      final currentDateTime = _convertToIST(currentMessage.createdAt);
      final previousDateTime = _convertToIST(previousMessage.createdAt);

      final currentDate = DateTime(
        currentDateTime.year,
        currentDateTime.month,
        currentDateTime.day,
      );
      final previousDate = DateTime(
        previousDateTime.year,
        previousDateTime.month,
        previousDateTime.day,
      );

      // Show separator if the current message is from a different date than the previous message
      final shouldShow = currentDate != previousDate;
      return shouldShow;
    } catch (e) {
      debugPrint('Error in _shouldShowDateSeparator: $e');
      return false;
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
            : null,
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
                        ? NetworkImage(widget.conversation.userProfilePic!)
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
                            const Text(
                              'Online', // TODO: Implement real online status
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
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
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: _bulkDeleteMessages,
                  tooltip: 'Delete messages',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement call functionality
                    debugPrint('Call pressed');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement video call functionality
                    debugPrint('Video call pressed');
                  },
                ),

                // PopupMenuButton<String>(
                //   icon: const Icon(Icons.more_vert, color: Colors.white),
                //   onSelected: (String value) {
                //     switch (value) {
                //       case 'clear_cache':
                //         _showClearCacheDialog();
                //         break;
                //       case 'cache_stats':
                //         _showCacheStats();
                //         break;
                //       case 'clear_all_cache':
                //         _showClearAllCacheDialog();
                //         break;
                //       case 'debug_user':
                //         _showUserDebugInfo();
                //         break;
                //       case 'smart_sync':
                //         _performSmartSync(widget.conversation.conversationId);
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           const SnackBar(content: Text('Smart sync triggered')),
                //         );
                //         break;
                //       case 'debug_dates':
                //         _debugMessageDates();
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           const SnackBar(
                //             content: Text('Check console for date debug info'),
                //           ),
                //         );
                //         break;
                //     }
                //   },
                //   itemBuilder: (BuildContext context) => [
                //     const PopupMenuItem<String>(
                //       value: 'clear_cache',
                //       child: Row(
                //         children: [
                //           Icon(Icons.clear_all, size: 20),
                //           SizedBox(width: 12),
                //           Text('Clear Cache'),
                //         ],
                //       ),
                //     ),
                //     const PopupMenuItem<String>(
                //       value: 'cache_stats',
                //       child: Row(
                //         children: [
                //           Icon(Icons.info_outline, size: 20),
                //           SizedBox(width: 12),
                //           Text('Cache Info'),
                //         ],
                //       ),
                //     ),
                //     const PopupMenuItem<String>(
                //       value: 'clear_all_cache',
                //       child: Row(
                //         children: [
                //           Icon(Icons.delete_sweep, size: 20),
                //           SizedBox(width: 12),
                //           Text('Clear All Cache'),
                //         ],
                //       ),
                //     ),
                //     const PopupMenuItem<String>(
                //       value: 'debug_user',
                //       child: Row(
                //         children: [
                //           Icon(Icons.bug_report, size: 20),
                //           SizedBox(width: 12),
                //           Text('Debug User ID'),
                //         ],
                //       ),
                //     ),
                //     const PopupMenuItem<String>(
                //       value: 'smart_sync',
                //       child: Row(
                //         children: [
                //           Icon(Icons.sync, size: 20),
                //           SizedBox(width: 12),
                //           Text('Smart Sync'),
                //         ],
                //       ),
                //     ),
                //     const PopupMenuItem<String>(
                //       value: 'debug_dates',
                //       child: Row(
                //         children: [
                //           Icon(Icons.calendar_today, size: 20),
                //           SizedBox(width: 12),
                //           Text('Debug Dates'),
                //         ],
                //       ),
                //     ),
                //   ],
                // ),
              ],
      ),
      body: Column(
        children: [
          // Pinned Message Section
          if (_pinnedMessageId != null) _buildPinnedMessageSection(),

          // Messages List
          Expanded(child: _buildMessagesList()),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageSection() {
    final pinnedMessage = _messages.firstWhere(
      (message) => message.id == _pinnedMessageId,
      orElse: () => throw StateError('Pinned message not found'),
    );

    final isMyMessage =
        _currentUserId != null && pinnedMessage.senderId == _currentUserId;
    final messageTime = _formatMessageTime(pinnedMessage.createdAt);

    return GestureDetector(
      onTap: () => _scrollToMessage(pinnedMessage.id),
      child: Container(
        // margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
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

  Widget _buildMessagesList() {
    // Show cache loader while checking cache (prevent black screen)
    if (_isCheckingCache && _messages.isEmpty) {
      return Container(
        color: Colors.white, // Pure white background
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading messages...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    // Show appropriate loader based on state
    if (_isLoadingFromCache) {
      return _buildCacheLoader();
    }

    // Only show loading if we haven't initialized and don't have messages
    if (_isLoading && !_isInitialized && _messages.isEmpty) {
      return _buildMinimalLoader();
    }

    if (_errorMessage != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialMessages,
              child: const Text('Retry'),
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

    return Container(
      color: Colors.white, // Pure white background
      child: AnimatedList(
        key: _animatedListKey,
        controller: _scrollController,
        reverse: true, // Start from bottom (newest messages)
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        initialItemCount: _messages.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index, animation) {
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

          // Keep pinned message in regular list - it will also be shown in pinned section

          // Debug: Check user ID comparison
          final isMyMessage =
              _currentUserId != null && message.senderId == _currentUserId;

          // Debug logging for first few messages to troubleshoot
          // if (index < 3) {
          //   debugPrint(
          //     '🔍 Message ${message.id}: senderId=${message.senderId}, currentUserId=$_currentUserId, isMyMessage=$isMyMessage',
          //   );
          // }

          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3), // Start slightly below
                  end: Offset.zero, // End at normal position
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack, // More bouncy/natural curve
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: ScaleTransition(
                scale:
                    Tween<double>(
                      begin: 0.8, // Start slightly smaller
                      end: 1.0, // End at normal size
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                child: Column(
                  children: [
                    // Date separator - show the date for the group of messages that starts here
                    if (_shouldShowDateSeparator(messageIndex))
                      _buildDateSeparator(message.createdAt),
                    // Message bubble with long press
                    _buildMessageWithActions(message, isMyMessage),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSeparator(String dateTimeString) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.grey[300])),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              _formatDateSeparator(dateTimeString),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.grey[300])),
        ],
      ),
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
  }

  void _onSwipeUpdate(
    MessageModel message,
    DragUpdateDetails details,
    bool isMyMessage,
  ) {
    // Only allow right swipe (positive delta x) for reply gesture
    if (details.delta.dx > 0 && !_isSelectionMode) {
      final controller = _swipeAnimationControllers[message.id];
      if (controller != null) {
        // Calculate swipe progress (0 to 1)
        final progress = (details.delta.dx / 100).clamp(0.0, 1.0);
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
      // If swipe velocity is sufficient or swipe distance is enough, trigger reply
      if (details.velocity.pixelsPerSecond.dx > 300 || controller.value > 0.3) {
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
    final messageTime = _formatMessageTime(message.createdAt);

    // Check if this message should be animated
    final shouldAnimate = _messageAnimationControllers.containsKey(message.id);
    final slideAnimation = _messageSlideAnimations[message.id];
    final fadeAnimation = _messageFadeAnimations[message.id];

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
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  left: isMyMessage ? 40 : 8,
                  right: isMyMessage ? 8 : 40,
                ),
                child: Stack(
                  children: [
                    // Check if this is a media message (image/video)
                    _isMediaMessage(message)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isMyMessage
                                  ? Colors.teal[600]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(
                                  isMyMessage ? 20 : 4,
                                ),
                                bottomRight: Radius.circular(
                                  isMyMessage ? 4 : 20,
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
                                // Reply message preview (if this is a reply)
                                if (message.replyToMessage != null)
                                  _buildReplyPreview(
                                    message.replyToMessage!,
                                    isMyMessage,
                                  ),

                                // Message content (text, image, or video)
                                _buildMessageContent(message, isMyMessage),
                                const SizedBox(height: 6),
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    if (isMyMessage) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                    // Pin indicator
                    // if (isPinned)
                    //   Positioned(
                    //     top: -4,
                    //     right: isMyMessage ? 8 : null,
                    //     left: isMyMessage ? null : 8,
                    //     child: Container(
                    //       padding: const EdgeInsets.all(4),
                    //       decoration: BoxDecoration(
                    //         color: Colors.orange[400],
                    //         shape: BoxShape.circle,
                    //         boxShadow: [
                    //           BoxShadow(
                    //             color: Colors.black.withOpacity(0.1),
                    //             blurRadius: 4,
                    //             offset: const Offset(0, 2),
                    //           ),
                    //         ],
                    //       ),
                    //       child: const Icon(
                    //         Icons.push_pin,
                    //         size: 12,
                    //         color: Colors.white,
                    //       ),
                    //     ),
                    //   ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMyMessage ? Colors.white.withOpacity(0.15) : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMyMessage ? Colors.white : Colors.teal,
            width: 3,
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
          Text(
            replyMessage.body.length > 50
                ? '${replyMessage.body.substring(0, 50)}...'
                : replyMessage.body,
            style: TextStyle(
              color: isMyMessage
                  ? Colors.white.withOpacity(0.8)
                  : Colors.grey[600],
              fontSize: 13,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
          ),
        );
    }
  }

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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          // borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isMyMessage
                ? const Color(0xFF008080)
                : const Color(0xFF008080),
            width: 6,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _openImagePreview(imageUrl, message.body),
                  child: Hero(
                    tag: imageUrl,
                    child: Image.network(
                      imageUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.teal,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 30,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Failed to load',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isMyMessage) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 14, color: Colors.white),
                    ],
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
              borderRadius: BorderRadius.circular(12),
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
                          _formatFileSize(fileSize),
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
                borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(20),
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
                            // const Spacer(),
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
                              _formatMessageTime(message.createdAt),
                              style: TextStyle(
                                color: isMyMessage
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 12,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMyMessage
                ? const Color(0xFF008080)
                : const Color(0xFF008080),
            width: 6,
          ),
          borderRadius: BorderRadius.circular(12),
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
                  child: Container(
                    width: 220,
                    height: 220,
                    color: Colors.black87,
                    child: Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 50,
                        color: Colors.white,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isMyMessage) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 14, color: Colors.white),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalLoader() {
    return Container(
      color: Colors.white, // Pure white background
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[400]!),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheLoader() {
    return Container(
      color: Colors.white, // Pure white background
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading ...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Much faster! ⚡',
            style: TextStyle(color: Colors.green[600], fontSize: 14),
          ),
        ],
      ),
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

  void _exitSelectionMode() {
    setState(() {
      _selectedMessages.clear();
      _isSelectionMode = false;
    });
  }

  void _showMessageActions(MessageModel message, bool isMyMessage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMessageActionSheet(message, isMyMessage),
    );
  }

  Widget _buildMessageActionSheet(MessageModel message, bool isMyMessage) {
    final isPinned = _pinnedMessageId == message.id;
    final isStarred = _starredMessages.contains(message.id);

    return Container(
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
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Message preview
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.message, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message.body.length > 50
                        ? '${message.body.substring(0, 50)}...'
                        : message.body,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildActionButton(
                  icon: Icons.reply,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(context);
                    _replyToMessage(message);
                  },
                ),
                _buildActionButton(
                  icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  label: isPinned ? 'Unpin' : 'Pin',
                  onTap: () {
                    Navigator.pop(context);
                    _togglePinMessage(message.id);
                  },
                ),
                _buildActionButton(
                  icon: isStarred ? Icons.star : Icons.star_border,
                  label: isStarred ? 'Unstar' : 'Star',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleStarMessage(message.id);
                  },
                ),
                _buildActionButton(
                  icon: Icons.forward,
                  label: 'Forward',
                  onTap: () {
                    Navigator.pop(context);
                    _forwardMessage(message);
                  },
                ),
                _buildActionButton(
                  icon: Icons.select_all,
                  label: 'Select',
                  onTap: () {
                    Navigator.pop(context);
                    _enterSelectionMode(message.id);
                  },
                ),
                if (isMyMessage)
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(message.id);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.grey[700], size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    debugPrint('📸 Opening camera...');

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress to reduce file size
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        debugPrint('📸 Camera image captured: ${image.path}');
        debugPrint('📸 Image name: ${image.name}');
        debugPrint('📸 Image size: ${await image.length()} bytes');

        // Print image details
        final File imageFile = File(image.path);
        if (await imageFile.exists()) {
          debugPrint('📸 Image file exists at: ${imageFile.path}');
          debugPrint('📸 Image file size: ${await imageFile.length()} bytes');
        }

        // TODO: Implement send image functionality
        _sendImageMessage(imageFile, 'camera');
      } else {
        debugPrint('📸 Camera capture cancelled by user');
      }
    } catch (e) {
      debugPrint('❌ Error capturing image from camera: $e');
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
      debugPrint('🖼️ Opening gallery...');

      // Use file picker to allow both images and videos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.first;
        final File mediaFile = File(file.path!);
        final String extension = file.extension?.toLowerCase() ?? '';

        // Check if it's a video file
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
          debugPrint('🎥 Gallery video selected: ${file.path}');
          debugPrint('🎥 Video name: ${file.name}');
          debugPrint('🎥 Video size: ${file.size} bytes');
          debugPrint('🎥 Video extension: ${file.extension}');

          if (await mediaFile.exists()) {
            debugPrint('🎥 Video file exists at: ${mediaFile.path}');
            debugPrint('🎥 Video file size: ${await mediaFile.length()} bytes');
          }

          _sendVideoMessage(mediaFile, 'gallery');
        } else {
          debugPrint('🖼️ Gallery image selected: ${file.path}');
          debugPrint('🖼️ Image name: ${file.name}');
          debugPrint('🖼️ Image size: ${file.size} bytes');
          debugPrint('🖼️ Image extension: ${file.extension}');

          if (await mediaFile.exists()) {
            debugPrint('🖼️ Image file exists at: ${mediaFile.path}');
            debugPrint(
              '🖼️ Image file size: ${await mediaFile.length()} bytes',
            );
          }

          _sendImageMessage(mediaFile, 'gallery');
        }
      } else {
        debugPrint('🖼️ Gallery selection cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error selecting from gallery: $e');
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
    debugPrint('📄 Opening document picker...');

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowCompression: true,
        withData: false, // Don't load file data into memory for large files
        withReadStream: true, // Use stream for large files
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.first;
        final File documentFile = File(file.path!);

        debugPrint('📄 Document selected: ${file.path}');
        debugPrint('📄 Document name: ${file.name}');
        debugPrint('📄 Document size: ${file.size} bytes');
        debugPrint('📄 Document extension: ${file.extension}');

        if (await documentFile.exists()) {
          debugPrint('📄 Document file exists at: ${documentFile.path}');
          debugPrint(
            '📄 Document file size: ${await documentFile.length()} bytes',
          );
        }

        // Check file size (limit to 50MB)
        if (file.size > 50 * 1024 * 1024) {
          _showErrorDialog('File too large. Maximum size is 50MB');
          return;
        }

        _sendDocumentMessage(documentFile, file.name, file.extension ?? '');
      } else {
        debugPrint('📄 Document selection cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error selecting document: $e');
      if (e.toString().contains('permission')) {
        _showErrorDialog(
          'Storage permission is required to access documents. Please grant permission in your device settings.',
        );
      } else {
        _showErrorDialog('Failed to select document');
      }
    }
  }

  // Helper methods for file attachments

  bool _isMediaMessage(MessageModel message) {
    if (message.attachments != null) {
      final attachmentData = message.attachments as Map<String, dynamic>;
      final category = attachmentData['category'] as String?;
      return category?.toLowerCase() == 'images' ||
          category?.toLowerCase() == 'videos' ||
          category?.toLowerCase() == 'docs' ||
          category?.toLowerCase() == 'audios';
    }
    return message.type == 'image' ||
        message.type == 'video' ||
        message.type == 'attachment' ||
        message.type == 'docs' ||
        message.type == 'audios';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
        currentConversationId: widget.conversation.conversationId,
      ),
    );
  }

  Future<void> _loadAvailableConversations() async {
    setState(() {
      _isLoadingConversations = true;
    });

    try {
      final response = await _userService.GetChatList('all');
      debugPrint('🔍 Forward modal - Raw API response: $response');

      if (response['success'] == true && response['data'] != null) {
        final dynamic responseData = response['data'];
        debugPrint(
          '🔍 Forward modal - Response data type: ${responseData.runtimeType}',
        );
        debugPrint('🔍 Forward modal - Response data: $responseData');
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

          debugPrint(
            '🔍 Forward modal - Processing ${conversationsList.length} conversations',
          );

          for (int i = 0; i < conversationsList.length; i++) {
            final json = conversationsList[i];
            try {
              final conversation = ConversationModel.fromJson(
                json as Map<String, dynamic>,
              );
              debugPrint(
                '✅ Forward modal - Successfully parsed conversation: ${conversation.displayName} (Type: ${conversation.type}, ID: ${conversation.conversationId})',
              );

              // Exclude current conversation
              if (conversation.conversationId !=
                  widget.conversation.conversationId) {
                conversations.add(conversation);
              } else {
                debugPrint(
                  '🚫 Forward modal - Excluding current conversation: ${conversation.conversationId}',
                );
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing conversation $i: $e');
              debugPrint('📄 Raw conversation data: $json');
              // Skip this conversation and continue with others
              continue;
            }
          }

          setState(() {
            _availableConversations = conversations;
          });

          debugPrint(
            '✅ Forward modal - Successfully loaded ${conversations.length} conversations for forwarding',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations for forward: $e');
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
          'source_conversation_id': widget.conversation.conversationId,
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

      debugPrint('✅ Messages forwarded successfully');
    } catch (e) {
      debugPrint('❌ Error forwarding messages: $e');
      if (mounted) {
        _showErrorDialog('Failed to forward messages. Please try again.');
      }
    }
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
          _audioStartTime = null;
        }
      } catch (e) {
        print('❌ Error in custom progress tracking: $e');
      }
    });
  }

  void _stopAudioProgressTimer() {
    _audioProgressTimer?.cancel();
    _audioProgressTimer = null;
    _audioStartTime = null;
    _customPosition = Duration.zero;
  }

  void _sendVoiceNote() async {
    print('📤 Sending voice note');

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

  void _sendImageMessage(File imageFile, String source) async {
    try {
      final response = await _chatsServices.sendMediaMessage(imageFile);

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];

        // Create a new message model for the image
        final imageMessage = MessageModel(
          id: _optimisticMessageId--, // Use negative ID for optimistic message
          conversationId: widget.conversation.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You', // Current user name
          body: '', // Empty body for image message
          type: 'image',
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData, // Store the media data as attachment
          replyToMessageId: _isReplying ? _replyToMessageData?.id : null,
          replyToMessage: _isReplying && _replyToMessageData != null
              ? MessageModel(
                  id: _replyToMessageData!.id,
                  body: _replyToMessageData!.body,
                  senderName: _replyToMessageData!.senderName,
                  type: _replyToMessageData!.type,
                  senderId: _replyToMessageData!.senderId,
                  conversationId: widget.conversation.conversationId,
                  createdAt: _replyToMessageData!.createdAt,
                  deleted: false,
                )
              : null,
        );

        // Add optimistic message ID to track it
        _optimisticMessageIds.add(imageMessage.id);

        // Add message to local list immediately
        setState(() {
          _messages.add(imageMessage);
          // Clear reply state if replying
          if (_isReplying) {
            _isReplying = false;
            _replyToMessageData = null;
          }
        });

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

        await _storageService.addMessageToCache(
          conversationId: widget.conversation.conversationId,
          newMessage: imageMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false, // Add at end (newest)
        );

        // Scroll to bottom to show new message
        _scrollToBottom();

        debugPrint('💾 Image message stored locally and displayed');

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.conversation.conversationId,
            'reply_to_message_id': _isReplying ? _replyToMessageData?.id : null,
          },
          'conversation_id': widget.conversation.conversationId,
        });

        debugPrint('📡 Image message sent to websocket for real-time delivery');
      } else {
        debugPrint(
          '❌ Failed to upload image: ${response['message'] ?? 'Unknown error'}',
        );
        // Show error to user
        _showErrorDialog(
          'Failed to send image: ${response['message'] ?? 'Upload failed'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending image message: $e');
      _showErrorDialog('Failed to send image. Please try again.');
    }
  }

  void _sendVideoMessage(File videoFile, String source) async {
    debugPrint('📤 Sending video message from $source');
    debugPrint('📤 Video path: ${videoFile.path}');
    debugPrint('📤 Video exists: ${videoFile.existsSync()}');

    try {
      debugPrint('📤 Uploading video to server...');

      final response = await _chatsServices.sendMediaMessage(videoFile);

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];
        debugPrint('✅ Video uploaded successfully: ${mediaData['url']}');

        // Create a new message model for the video
        final videoMessage = MessageModel(
          id: _optimisticMessageId--, // Use negative ID for optimistic message
          conversationId: widget.conversation.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You', // Current user name
          body: '', // Empty body for video message
          type: 'video',
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData, // Store the media data as attachment
          replyToMessageId: _isReplying ? _replyToMessageData?.id : null,
          replyToMessage: _isReplying && _replyToMessageData != null
              ? MessageModel(
                  id: _replyToMessageData!.id,
                  body: _replyToMessageData!.body,
                  senderName: _replyToMessageData!.senderName,
                  type: _replyToMessageData!.type,
                  senderId: _replyToMessageData!.senderId,
                  conversationId: widget.conversation.conversationId,
                  createdAt: _replyToMessageData!.createdAt,
                  deleted: false,
                )
              : null,
        );

        // Add optimistic message ID to track it
        _optimisticMessageIds.add(videoMessage.id);

        // Add message to local list immediately
        setState(() {
          _messages.add(videoMessage);
          // Clear reply state if replying
          if (_isReplying) {
            _isReplying = false;
            _replyToMessageData = null;
          }
        });

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

        await _storageService.addMessageToCache(
          conversationId: widget.conversation.conversationId,
          newMessage: videoMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false, // Add at end (newest)
        );

        // Scroll to bottom to show new message
        _scrollToBottom();

        debugPrint('💾 Video message stored locally and displayed');

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.conversation.conversationId,
            'message_type': 'video',
            'reply_to_message_id': _isReplying ? _replyToMessageData?.id : null,
          },
          'conversation_id': widget.conversation.conversationId,
        });

        debugPrint('📡 Video message sent to websocket for real-time delivery');
      } else {
        debugPrint(
          '❌ Failed to upload video: ${response['message'] ?? 'Unknown error'}',
        );
        _showErrorDialog(
          'Failed to send video: ${response['message'] ?? 'Upload failed'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending video message: $e');
      _showErrorDialog('Failed to send video. Please try again.');
    }
  }

  void _sendDocumentMessage(
    File documentFile,
    String fileName,
    String extension,
  ) async {
    try {
      final response = await _chatsServices.sendMediaMessage(documentFile);

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];
        debugPrint('✅ Document uploaded successfully: ${mediaData['url']}');

        // Create a new message model for the document
        final documentMessage = MessageModel(
          id: _optimisticMessageId--, // Use negative ID for optimistic message
          conversationId: widget.conversation.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You', // Current user name
          body: '', // Empty body for document message
          type: 'document',
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData, // Store the media data as attachment
          replyToMessageId: _isReplying ? _replyToMessageData?.id : null,
          replyToMessage: _isReplying && _replyToMessageData != null
              ? MessageModel(
                  id: _replyToMessageData!.id,
                  body: _replyToMessageData!.body,
                  senderName: _replyToMessageData!.senderName,
                  type: _replyToMessageData!.type,
                  senderId: _replyToMessageData!.senderId,
                  conversationId: widget.conversation.conversationId,
                  createdAt: _replyToMessageData!.createdAt,
                  deleted: false,
                )
              : null,
        );

        // Add optimistic message ID to track it
        _optimisticMessageIds.add(documentMessage.id);

        // Add message to local list immediately
        setState(() {
          _messages.add(documentMessage);
          // Clear reply state if replying
          if (_isReplying) {
            _isReplying = false;
            _replyToMessageData = null;
          }
        });

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

        await _storageService.addMessageToCache(
          conversationId: widget.conversation.conversationId,
          newMessage: documentMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false, // Add at end (newest)
        );

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.conversation.conversationId,
            'message_type': 'document',
            'reply_to_message_id': _isReplying ? _replyToMessageData?.id : null,
          },
          'conversation_id': widget.conversation.conversationId,
        });

        // Scroll to bottom to show new message
        _scrollToBottom();

        debugPrint('💾 Document message stored locally and displayed');
        debugPrint(
          '📡 Document message sent to websocket for real-time delivery',
        );
      } else {
        debugPrint(
          '❌ Failed to upload document: ${response['message'] ?? 'Unknown error'}',
        );
        _showErrorDialog(
          'Failed to send document: ${response['message'] ?? 'Upload failed'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending document message: $e');
      _showErrorDialog('Failed to send document. Please try again.');
    }
  }

  void _enterSelectionMode(int messageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessages.add(messageId);
    });
  }

  void _togglePinMessage(int messageId) async {
    final conversationId = widget.conversation.conversationId;
    final wasPinned = messageId == _pinnedMessageId;

    setState(() {
      if (wasPinned) {
        _pinnedMessageId = null;
      } else {
        _pinnedMessageId = messageId;
      }
    });

    // Save to local storage
    await _storageService.savePinnedMessage(
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
    final conversationId = widget.conversation.conversationId;
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
      await _storageService.toggleStarMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
      debugPrint(
        '⭐ ${isCurrentlyStarred ? 'Unstarred' : 'Starred'} message $messageId in local storage',
      );
    } catch (e) {
      debugPrint('❌ Error saving star state to storage: $e');
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

  void _replyToMessage(MessageModel message) {
    setState(() {
      _replyToMessageData = message;
      _isReplying = true;
    });
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageData = null;
      _isReplying = false;
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
    final response = await _chatsServices.deleteMessage([messageId]);

    if (response['success'] == true) {
      debugPrint('✅ Message deleted successfully');

      // Remove from local state
      setState(() {
        _messages.removeWhere((message) => message.id == messageId);
      });

      // Remove from local storage cache
      await _storageService.removeMessageFromCache(
        conversationId: widget.conversation.conversationId,
        messageIds: [messageId],
      );
    } else {
      debugPrint(
        '❌ Failed to delete message: ${response['message'] ?? 'Unknown error'}',
      );
    }
  }

  void _bulkStarMessages() async {
    final conversationId = widget.conversation.conversationId;
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
          await _storageService.unstarMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
        } else {
          await _storageService.starMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
        }
      }
      debugPrint(
        '⭐ Bulk ${action}red ${messagesToStar.length} messages in local storage',
      );
    } catch (e) {
      debugPrint('❌ Error bulk ${action}ring messages in storage: $e');
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
    );

    if (response['success'] == true) {
      setState(() {
        _messages.removeWhere(
          (message) => _selectedMessages.contains(message.id),
        );
      });
      await _storageService.removeMessageFromCache(
        conversationId: widget.conversation.conversationId,
        messageIds: _selectedMessages.map((id) => id).toList(),
      );
    } else {
      debugPrint(
        '❌ Failed to delete messages: ${response['message'] ?? 'Unknown error'}',
      );
    }
    _exitSelectionMode();
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        // Typing indicator
        if (_isOtherTyping) _buildTypingIndicator(),

        // Reply container
        if (_isReplying && _replyToMessageData != null) _buildReplyContainer(),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                onPressed: () {
                  _showAttachmentModal();
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  onChanged: (value) {
                    _handleTyping(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _isTyping ? _sendMessage : _sendVoiceNote,
                backgroundColor: Colors.teal,
                mini: true,
                child: _isTyping
                    ? const Icon(Icons.send, color: Colors.white)
                    : const Icon(Icons.mic, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
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
                      'Replying to ${isRepliedMessageMine ? 'yourself' : replyMessage.senderName}',
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  replyMessage.body.length > 60
                      ? '${replyMessage.body.substring(0, 60)}...'
                      : replyMessage.body,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
            backgroundImage: widget.conversation.userProfilePic != null
                ? NetworkImage(widget.conversation.userProfilePic!)
                : null,
            child: widget.conversation.userProfilePic == null
                ? Text(
                    widget.conversation.userName.isNotEmpty
                        ? widget.conversation.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  )
                : null,
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

  /// Debug method to test reply message storage and retrieval

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

  // Media preview methods
  void _openImagePreview(String imageUrl, String? caption) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImagePreviewScreen(
          imageUrls: [imageUrl],
          initialIndex: 0,
          captions: caption != null && caption.isNotEmpty ? [caption] : null,
        ),
      ),
    );
  }

  void _openVideoPreview(String videoUrl, String? caption, String? fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPreviewScreen(
          videoUrl: videoUrl,
          caption: caption,
          fileName: fileName,
        ),
      ),
    );
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
      print('❌ Error checking microphone permission: $e');
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
          '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      print('📁 Recording path: $recordingPath');
      print('📁 Temp directory exists: ${await tempDir.exists()}');

      // Start recording with AAC MP4 format (most widely supported)
      print('🎙️ Starting recorder...');
      await _recorder.startRecorder(
        toFile: recordingPath,
        codec: Codec.aacMP4,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1, // Mono recording for smaller file size
      );

      print('✅ Recorder started successfully');

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

          // Check if we're actually recording audio
          print('⏱️ Recording duration: ${_recordingDuration.inSeconds}s');
        }
      });

      print('🎤 Started recording voice note at: $recordingPath');
    } catch (e) {
      print('❌ Error starting voice recording: $e');
      _showErrorDialog('Failed to start recording. Please try again.');
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) {
        print('⚠️ Not currently recording, cannot stop');
        return;
      }

      // Check minimum recording duration (at least 1 second)
      if (_recordingDuration.inSeconds < 1) {
        print('⚠️ Recording too short (${_recordingDuration.inSeconds}s)');
        _showErrorDialog(
          'Recording is too short. Please record for at least 1 second.',
        );
        return;
      }

      print(
        '🛑 Stopping recording after ${_recordingDuration.inSeconds} seconds...',
      );

      // Add a small delay to ensure audio is captured
      await Future.delayed(const Duration(milliseconds: 100));

      final recordingPath = await _recorder.stopRecorder();
      _recordingTimer?.cancel();
      _zigzagAnimationController.stop();

      print('✅ Recording stopped successfully');
      print('📁 Final recording path: $recordingPath');

      // Wait a moment for file to be written completely
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify the file was created and has content
      if (recordingPath != null) {
        final file = File(recordingPath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        print('📄 Recording file exists: $exists');
        print('📏 Recording file size: $size bytes');

        // For M4A files, minimum size should be much larger than 44 bytes
        if (!exists || size < 1000) {
          print('❌ Recording file is empty or too small (${size} bytes)');
          _showErrorDialog(
            'Recording failed - no audio was captured. Please check microphone permissions and try again.',
          );
          return;
        }
      } else {
        print('❌ Recording path is null');
        _showErrorDialog(
          'Recording failed - no file path returned. Please try again.',
        );
        return;
      }

      setState(() {
        _isRecording = false;
        _recordingPath = recordingPath;
      });

      print('🎤 Stopped recording voice note. Path: $recordingPath');
    } catch (e) {
      print('❌ Error stopping voice recording: $e');
      print('❌ Stack trace: ${e.toString()}');
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
      print('🗑️ Cancelled voice recording - Timer reset to 0:00');
    } catch (e) {
      print('❌ Error cancelling voice recording: $e');
    }
  }

  Future<void> _sendRecordedVoice() async {
    try {
      print('📤 Starting voice note send process...');

      // Stop the recording timer immediately
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (_recordingPath == null) {
        print('❌ No recording path found');
        _showErrorDialog('No recording found. Please try again.');
        return;
      }

      if (_recorder.isRecording) {
        final path = await _recorder.stopRecorder();
        _recordingPath = path; // overwrite with final file
      }

      setState(() {
        _recordingPath = _recordingPath;
      });

      final voiceFile = File(_recordingPath!);
      if (!await voiceFile.exists()) {
        print('❌ Recording file does not exist at path: ${_recordingPath!}');
        _showErrorDialog('Recording file not found. Please try again.');
        return;
      }

      final fileSize = await voiceFile.length();
      if (fileSize == 0) {
        print('❌ Recording file is empty');
        _showErrorDialog('Recording is empty. Please try recording again.');
        return;
      }

      Navigator.of(context).pop();
      print('📤 Sending voice note: ${voiceFile.path}');
      print('📤 Voice note file size: ${await voiceFile.length()} bytes');
      print('📤 Voice note file extension: ${voiceFile.path.split('.').last}');

      final response = await _chatsServices.sendMediaMessage(voiceFile);
      print('📤 Voice note response: $response');

      if (response['success'] == true && response['data'] != null) {
        final mediaData = response['data'];
        print('✅ Voice note uploaded successfully: ${mediaData['url']}');

        // Create a new message model for the voice note
        final voiceMessage = MessageModel(
          id: _optimisticMessageId--,
          conversationId: widget.conversation.conversationId,
          senderId: _currentUserId ?? 0,
          senderName: 'You',
          body: '',
          type: 'audio',
          createdAt: DateTime.now().toIso8601String(),
          deleted: false,
          attachments: mediaData,
          replyToMessageId: _isReplying ? _replyToMessageData?.id : null,
          replyToMessage: _isReplying && _replyToMessageData != null
              ? MessageModel(
                  id: _replyToMessageData!.id,
                  body: _replyToMessageData!.body,
                  senderName: _replyToMessageData!.senderName,
                  type: _replyToMessageData!.type,
                  senderId: _replyToMessageData!.senderId,
                  conversationId: widget.conversation.conversationId,
                  createdAt: _replyToMessageData!.createdAt,
                  deleted: false,
                )
              : null,
        );

        // Add optimistic message ID to track it
        _optimisticMessageIds.add(voiceMessage.id);

        // Add message to local list immediately
        setState(() {
          _messages.add(voiceMessage);
          if (_isReplying) {
            _isReplying = false;
            _replyToMessageData = null;
          }
        });

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

        await _storageService.addMessageToCache(
          conversationId: widget.conversation.conversationId,
          newMessage: voiceMessage,
          updatedMeta: updatedMeta,
          insertAtBeginning: false,
        );

        // Send to websocket for real-time messaging
        await _websocketService.sendMessage({
          'type': 'media',
          'data': {
            ...response['data'],
            'conversation_id': widget.conversation.conversationId,
            'message_type': 'audio',
            'reply_to_message_id': _isReplying ? _replyToMessageData?.id : null,
          },
          'conversation_id': widget.conversation.conversationId,
        });

        _scrollToBottom();
        print('💾 Voice message stored locally and displayed');
      } else {
        print(
          '❌ Failed to upload voice note: ${response['message'] ?? 'Unknown error'}',
        );
        _showErrorDialog(
          'Failed to send voice note: ${response['message'] ?? 'Upload failed'}',
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
    } catch (e) {
      print('❌ Error sending voice note: $e');
      _showErrorDialog('Failed to send voice note. Please try again.');
    }
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

        // Start new playback
        print('🎬 Starting audio player with URL: $audioUrl');
        await _audioPlayer.startPlayer(
          fromURI: audioUrl,
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
            'Audio player was not ready. Please try playing again.',
          );
        } catch (initError) {
          print('❌ Failed to initialize audio player: $initError');
          _showErrorDialog(
            'Failed to initialize audio player. Please restart the app.',
          );
        }
      } else {
        _showErrorDialog('Failed to play audio. Please try again.');
      }
    }
  }

  void _estimateAudioDuration(String audioKey, int? fileSize) {
    // Skip if we already have duration
    if (_audioDurations[audioKey] != null &&
        _audioDurations[audioKey]!.inMilliseconds > 0) {
      return;
    }

    if (fileSize != null && fileSize > 0) {
      // Rough estimation: M4A files are typically 1MB per minute at 128kbps
      // This is just a rough estimate for display purposes
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }
}

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
                                : Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isRecording ? Icons.stop : Icons.send,
                            color: widget.isRecording
                                ? Colors.red
                                : Colors.green,
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
