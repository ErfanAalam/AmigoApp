import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../api/groups.services.dart';
import '../../api/user.service.dart';
import '../../services/message_storage_service.dart';
import '../../services/websocket_service.dart';

class InnerGroupChatPage extends StatefulWidget {
  final GroupModel group;

  const InnerGroupChatPage({Key? key, required this.group}) : super(key: key);

  @override
  State<InnerGroupChatPage> createState() => _InnerGroupChatPageState();
}

class _InnerGroupChatPageState extends State<InnerGroupChatPage> {
  final GroupsService _groupsService = GroupsService();
  final UserService _userService = UserService();
  final MessageStorageService _storageService = MessageStorageService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final WebSocketService _websocketService = WebSocketService();
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

  // For optimistic message handling
  StreamSubscription<Map<String, dynamic>>? _websocketSubscription;
  int _optimisticMessageId = -1;
  final Set<int> _optimisticMessageIds = {};

  // User info cache for sender names and profile pics
  final Map<int, Map<String, String?>> _userInfoCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Set up WebSocket message listener
    _setupWebSocketListener();

    // Start initialization immediately
    _initializeChat();

    // Also try a super quick cache check for even faster display
    _quickCacheCheck();
  }

  /// Ultra-fast cache check that runs immediately
  void _quickCacheCheck() async {
    try {
      final conversationId = widget.group.conversationId;

      // Quick synchronous check if cache key exists
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('messages_$conversationId')) {
        debugPrint('🚀 Group cache exists, will load shortly...');
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
      debugPrint(
        '🔄 Starting group smart sync for conversation $conversationId',
      );

      // Get current cached message count
      final cachedCount = _messages.length;
      debugPrint('📊 Current cached group messages: $cachedCount');

      // Fetch latest data from backend (silently)
      final response = await _groupsService.getGroupConversationHistory(
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
        debugPrint('📊 Backend group messages: $backendCount');

        if (backendCount > cachedCount) {
          // Backend has more messages - add only the new ones
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
          }
        } else if (backendCount == cachedCount) {
          // Same count - no new messages
          debugPrint('✅ Group smart sync: No new messages found');

          // Just update metadata in case pagination info changed
          _conversationMeta = ConversationMeta.fromResponse(historyResponse);
          await _storageService.saveMessages(
            conversationId: conversationId,
            messages: _messages,
            meta: _conversationMeta!,
          );
        } else {
          // Backend has fewer messages (unlikely but handle it)
          debugPrint(
            '⚠️ Backend has fewer group messages than cache, using backend data',
          );

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
      } else {
        debugPrint('❌ Group smart sync failed: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error in group smart sync: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _initializeChat() async {
    // Get user ID first, then load messages
    await _getCurrentUserId();

    // Initialize user info cache with group members
    _initializeUserCache();

    // Try to load from cache immediately for instant display
    await _tryLoadFromCacheFirst();

    // Then load from server if needed
    await _loadInitialMessages();
  }

  /// Quick cache check and load for instant display
  Future<void> _tryLoadFromCacheFirst() async {
    if (_hasCheckedCache) return; // Avoid double-checking

    try {
      final conversationId = widget.group.conversationId;
      debugPrint('⚡ Quick group cache check for instant display...');

      final cachedData = await _storageService.getCachedMessages(
        conversationId,
      );

      if (cachedData != null && cachedData.messages.isNotEmpty && mounted) {
        debugPrint('⚡ Found group cache, displaying immediately!');
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
      } else {
        debugPrint('⚡ No group cache found, will load from server');
        if (mounted) {
          setState(() {
            _isCheckingCache = false;
            _isLoading = true; // Now show loading since no cache
            _hasCheckedCache = true;
          });
        }
      }
    } catch (e) {
      debugPrint('⚡ Error in quick group cache check: $e');
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
        debugPrint('✅ Got current user ID from service: $_currentUserId');
      } else {
        debugPrint('❌ Failed to get user from service, trying fallback...');
        // For groups, we can't use a single user ID as fallback
        _currentUserId = null;
      }
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      _currentUserId = null;
    }

    // Final fallback - if still null, log warning
    if (_currentUserId == null) {
      debugPrint(
        '⚠️ WARNING: Could not determine current user ID for group. All messages will show as from others.',
      );
    } else {
      debugPrint('👤 Final current user ID for group: $_currentUserId');
    }
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Initialize user info cache with known group members
  void _initializeUserCache() {
    // Cache all group members' info
    for (final member in widget.group.members) {
      _userInfoCache[member.userId] = {
        'name': member.name,
        'profile_pic': member.profilePic,
      };
      debugPrint(
        '👤 Cached group member info for ${member.userId}: ${member.name}',
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

  /// Get user info (name and profile pic) by user ID
  Map<String, String?> _getUserInfo(int userId) {
    // Check cache first
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }

    // Check if it's a group member
    for (final member in widget.group.members) {
      if (member.userId == userId) {
        final userInfo = {
          'name': member.name,
          'profile_pic': member.profilePic,
        };
        _userInfoCache[userId] = userInfo;
        return userInfo;
      }
    }

    // If it's the current user
    if (userId == _currentUserId) {
      final userInfo = {'name': 'You', 'profile_pic': null};
      _userInfoCache[userId] = userInfo;
      return userInfo;
    }

    // Fallback for unknown users
    debugPrint('⚠️ Unknown group member ID: $userId, using fallback');
    final fallbackInfo = {'name': 'User $userId', 'profile_pic': null};
    _userInfoCache[userId] = fallbackInfo;
    return fallbackInfo;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _websocketSubscription?.cancel();
    super.dispose();
  }

  /// Clear cache for this group conversation (useful for debugging or when data is corrupted)
  Future<void> _clearConversationCache() async {
    await _storageService.clearConversationCache(widget.group.conversationId);
    if (mounted) {
      // Reload messages after clearing cache
      setState(() {
        _messages.clear();
        _isInitialized = false;
        _currentPage = 1;
        _hasMoreMessages = true;
      });
      await _loadInitialMessages();
    }
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
      final conversationId = widget.group.conversationId;
      debugPrint(
        '🔄 Loading initial group messages for conversation $conversationId',
      );

      // If we already have messages from cache, do smart sync
      if (_hasCheckedCache && _messages.isNotEmpty) {
        debugPrint(
          '📦 Already have cached group messages, doing smart sync...',
        );

        // Always check backend for new messages (but silently)
        await _performSmartSync(conversationId);
        return;
      } else if (!_hasCheckedCache) {
        // This is a fallback if quick cache check didn't work
        debugPrint('📦 Fallback: checking group cache in _loadInitialMessages');

        final cachedData = await _storageService.getCachedMessages(
          conversationId,
        );

        if (cachedData != null && cachedData.messages.isNotEmpty) {
          debugPrint('📦 Found group cache in fallback check');
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
            debugPrint(
              '📱 Fallback group cache is fresh, no server request needed',
            );
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
        final response = await _groupsService.getGroupConversationHistory(
          conversationId: conversationId,
          page: 1,
          limit: 20,
        );

        if (!mounted) return; // Prevent setState if widget is disposed

        debugPrint('🌐 Group server response received: ${response['success']}');
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

          debugPrint(
            '🌐 Loaded ${processedMessages.length} group messages from server and cached',
          );
        } else {
          setState(() {
            _errorMessage =
                response['message'] ?? 'Failed to load group messages';
            _isLoading = false;
            _isLoadingFromCache = false;
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading group messages from server: $e');
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
      debugPrint('❌ Critical error in group _loadInitialMessages: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load group messages: ${e.toString()}';
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
      final conversationId = widget.group.conversationId;
      final response = await _groupsService.getGroupConversationHistory(
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

        debugPrint(
          '📄 Loaded ${newMessages.length} more group messages and cached',
        );
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

  /// Set up WebSocket message listener for real-time group messages
  void _setupWebSocketListener() {
    _websocketSubscription = _websocketService.messageStream.listen(
      (message) {
        _handleIncomingWebSocketMessage(message);
      },
      onError: (error) {
        debugPrint('❌ Group WebSocket message stream error: $error');
      },
    );
  }

  /// Handle incoming WebSocket messages for group
  void _handleIncomingWebSocketMessage(Map<String, dynamic> message) {
    try {
      debugPrint('📨 Received group WebSocket message: $message');

      // Check if this is a message for our group conversation
      final messageConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];

      if (messageConversationId != widget.group.conversationId) {
        return; // Not for this group conversation
      }

      // Handle different message types
      final messageType = message['type'];
      if (messageType == 'message') {
        _handleIncomingMessage(message);
      }
    } catch (e) {
      debugPrint('❌ Error handling group WebSocket message: $e');
    }
  }

  /// Handle incoming message from WebSocket
  void _handleIncomingMessage(Map<String, dynamic> messageData) {
    try {
      // Extract message data from WebSocket payload
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final messageBody = data['body'] as String? ?? '';
      final senderId = _parseToInt(data['sender_id'] ?? data['senderId']);
      final messageId = data['id'] ?? data['messageId'];

      // Get sender info from cache/lookup
      final senderInfo = _getUserInfo(senderId);
      final senderName = senderInfo['name'] ?? 'Unknown User';
      final senderProfilePic = senderInfo['profile_pic'];

      debugPrint('👤 Group message from user $senderId: $senderName');

      // Skip if this is our own optimistic message being echoed back
      if (_optimisticMessageIds.contains(messageId)) {
        debugPrint('🔄 Replacing optimistic group message with server message');
        _replaceOptimisticMessage(messageId, messageData);
        return;
      }

      // Create MessageModel from WebSocket data
      final newMessage = MessageModel(
        id: messageId ?? DateTime.now().millisecondsSinceEpoch,
        body: messageBody,
        type: data['type'] ?? 'text',
        senderId: senderId,
        conversationId: widget.group.conversationId,
        createdAt: data['created_at'] ?? DateTime.now().toIso8601String(),
        editedAt: data['edited_at'],
        metadata: data['metadata'],
        attachments: data['attachments'],
        deleted: data['deleted'] == true,
        senderName: senderName,
        senderProfilePic: senderProfilePic,
      );

      // Add message to UI immediately
      if (mounted) {
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();
      }

      // Store message asynchronously
      _storeMessageAsync(newMessage);
    } catch (e) {
      debugPrint('❌ Error processing incoming group message: $e');
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
          id: messageId,
          body: data['body'] ?? _messages[index].body,
          type: data['type'] ?? _messages[index].type,
          senderId: senderId,
          conversationId: widget.group.conversationId,
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
      debugPrint('❌ Error replacing optimistic group message: $e');
    }
  }

  /// Send group message with immediate display (optimistic UI)
  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Clear input immediately for better UX
    _messageController.clear();

    // Create optimistic message for immediate display
    final optimisticMessage = MessageModel(
      id: _optimisticMessageId, // Use negative ID for optimistic messages
      body: messageText,
      type: 'text',
      senderId: _currentUserId ?? 0,
      conversationId: widget.group.conversationId,
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      senderName: 'You', // Current user name
      senderProfilePic: null,
    );

    // Track this as an optimistic message
    _optimisticMessageIds.add(_optimisticMessageId);
    _optimisticMessageId--; // Decrement for next optimistic message

    // Add message to UI immediately
    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
      });
      _scrollToBottom();
    }

    // Store message immediately in cache (optimistic storage)
    _storeMessageAsync(optimisticMessage);

    try {
      // Send message through WebSocket
      await _websocketService.sendMessage({
        'type': 'message',
        'data': {
          'type': 'text',
          'body': messageText,
          'optimistic_id':
              optimisticMessage.id, // Include optimistic ID for deduplication
        },
        'conversation_id': widget.group.conversationId,
      });

      debugPrint('✅ Group message sent successfully via WebSocket');
    } catch (e) {
      debugPrint('❌ Error sending group message: $e');

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
          content: Text('Failed to send group message: $error'),
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
          await _storageService.addMessageToCache(
            conversationId: widget.group.conversationId,
            newMessage: message,
            updatedMeta: _conversationMeta!.copyWith(
              totalCount: _conversationMeta!.totalCount + 1,
            ),
            insertAtBeginning: false, // Add new messages at the end
          );
          debugPrint('💾 Group message stored asynchronously: ${message.id}');
        }
      } catch (e) {
        debugPrint('❌ Error storing group message asynchronously: $e');
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

  String _formatMessageTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (messageDate == today) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green[100],
              child: Icon(Icons.group, color: Colors.green, size: 20),
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
                  Text(
                    '${widget.group.memberCount} members',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {
              // TODO: Implement group call functionality
              debugPrint('Group call pressed');
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              // TODO: Implement group video call functionality
              debugPrint('Group video call pressed');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String value) {
              switch (value) {
                case 'group_info':
                  // TODO: Show group info page
                  debugPrint('Group info pressed');
                  break;
                case 'add_member':
                  // TODO: Add member functionality
                  debugPrint('Add member pressed');
                  break;
                case 'leave_group':
                  // TODO: Leave group functionality
                  debugPrint('Leave group pressed');
                  break;
                case 'clear_cache':
                  _clearConversationCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group cache cleared')),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'group_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Group Info'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'add_member',
                child: Row(
                  children: [
                    Icon(Icons.person_add, size: 20),
                    SizedBox(width: 12),
                    Text('Add Member'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'leave_group',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 20),
                    SizedBox(width: 12),
                    Text('Leave Group'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Cache'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(child: _buildMessagesList()),

          // Message Input
          _buildMessageInput(),
        ],
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
              'Loading group messages...',
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
              'Start the group conversation!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white, // Pure white background
      child: ListView.builder(
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[300]!),
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

          return _buildMessageBubble(message, isMyMessage);
        },
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMyMessage) {

    print(message);
    // Pre-calculate values for better performance
    final messageTime = _formatMessageTime(message.createdAt);
    final senderInitial = message.senderName.isNotEmpty
        ? message.senderName[0].toUpperCase()
        : '?';
    final profilePic = isMyMessage ? null : message.senderProfilePic;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: isMyMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMyMessage) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green[100],
                backgroundImage: profilePic != null
                    ? NetworkImage(profilePic)
                    : null,
                child: profilePic == null
                    ? Text(
                        senderInitial,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMyMessage ? Colors.green[600] : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
                    bottomRight: Radius.circular(isMyMessage ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMyMessage && message.senderName.isNotEmpty) ...[
                      Text(
                        message.senderName,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message.body,
                      style: TextStyle(
                        color: isMyMessage ? Colors.white : Colors.black87,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          messageTime,
                          style: TextStyle(
                            color: isMyMessage
                                ? Colors.white70
                                : Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        if (isMyMessage) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: Colors.white70),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (isMyMessage) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green[100],
                child: const Icon(Icons.person, color: Colors.green, size: 16),
              ),
            ],
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading group messages...',
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: () {
              // TODO: Implement file attachment for group
              debugPrint('Attach file to group pressed');
            },
          ),
          IconButton(
            icon: Icon(Icons.keyboard_voice, color: Colors.grey[600]),
            onPressed: () {
              // TODO: Implement voice message for group
              debugPrint('Send voice message to group');
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
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: Colors.green,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
