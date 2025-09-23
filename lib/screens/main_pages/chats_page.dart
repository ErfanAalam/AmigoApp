import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../api/user.service.dart';
import '../../services/websocket_service.dart';
import '../../services/user_status_service.dart';
import '../../services/chat_preferences_service.dart';
import '../../widgets/chat_action_menu.dart';
import 'inner_chat_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({Key? key}) : super(key: key);

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  final ChatPreferencesService _chatPreferencesService =
      ChatPreferencesService();
  late Future<List<ConversationModel>> _conversationsFuture;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ConversationModel> _filteredConversations = [];

  // Real-time conversation state management
  List<ConversationModel> _conversations = [];
  bool _isLoaded = false;

  // Track which conversation user is currently viewing
  int? _activeConversationId;

  // Chat preferences state
  Set<int> _pinnedChats = {};
  Set<int> _mutedChats = {};
  Set<int> _favoriteChats = {};
  Set<int> _deletedChats = {};

  // Typing state management
  final Map<int, bool> _typingUsers = {}; // conversationId -> isTyping
  final Map<int, Timer?> _typingTimers = {}; // conversationId -> timer
  final Map<int, String> _typingUserNames = {}; // conversationId -> userName
  StreamSubscription<Map<String, dynamic>>? _websocketSubscription;
  StreamSubscription<Map<int, bool>>? _userStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationsFuture = _loadConversations();
    _setupWebSocketListener();
    _setupUserStatusListener();
    _loadChatPreferences();

    // Setup search functionality
    _searchController.addListener(_onSearchChanged);
  }

  /// Handle search text changes
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _filterConversations();
      });
    }
  }

  /// Filter conversations based on search query
  void _filterConversations() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = List.from(_conversations);
    } else {
      _filteredConversations = _conversations.where((conversation) {
        return conversation.userName.toLowerCase().contains(_searchQuery) ||
            (conversation.metadata?.lastMessage.body ?? '')
                .toLowerCase()
                .contains(_searchQuery);
      }).toList();
    }
  }

  /// Clear search query
  void _clearSearch() {
    _searchController.clear();
  }

  /// Load chat preferences from local storage
  Future<void> _loadChatPreferences() async {
    try {
      final pinnedChats = await _chatPreferencesService.getPinnedChats();
      final mutedChats = await _chatPreferencesService.getMutedChats();
      final favoriteChats = await _chatPreferencesService.getFavoriteChats();
      final deletedChats = await _chatPreferencesService.getDeletedChats();

      if (mounted) {
        setState(() {
          _pinnedChats = pinnedChats.toSet();
          _mutedChats = mutedChats.toSet();
          _favoriteChats = favoriteChats.toSet();
          _deletedChats = deletedChats
              .map((chat) => chat['conversation_id'] as int)
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading chat preferences: $e');
    }
  }

  /// Handle chat action (pin, mute, favorite, delete)
  Future<void> _handleChatAction(
    String action,
    ConversationModel conversation,
  ) async {
    try {
      switch (action) {
        case 'pin':
          final success = await _chatPreferencesService.pinChat(
            conversation.conversationId,
          );
          if (success) {
            setState(() {
              _pinnedChats.add(conversation.conversationId);
            });
            _showSnackBar('Chat pinned to top', Colors.orange);
          } else {
            final pinnedCount = await _chatPreferencesService
                .getPinnedChatsCount();
            if (pinnedCount >= ChatPreferencesService.maxPinnedChats) {
              _showSnackBar(
                'Maximum ${ChatPreferencesService.maxPinnedChats} chats can be pinned',
                Colors.red,
              );
            }
          }
          break;
        case 'unpin':
          await _chatPreferencesService.unpinChat(conversation.conversationId);
          setState(() {
            _pinnedChats.remove(conversation.conversationId);
          });
          _showSnackBar('Chat unpinned', Colors.grey);
          break;
        case 'mute':
          await _chatPreferencesService.muteChat(conversation.conversationId);
          setState(() {
            _mutedChats.add(conversation.conversationId);
          });
          _showSnackBar('Chat muted', Colors.blue);
          break;
        case 'unmute':
          await _chatPreferencesService.unmuteChat(conversation.conversationId);
          setState(() {
            _mutedChats.remove(conversation.conversationId);
          });
          _showSnackBar('Chat unmuted', Colors.blue);
          break;
        case 'favorite':
          await _chatPreferencesService.favoriteChat(
            conversation.conversationId,
          );
          setState(() {
            _favoriteChats.add(conversation.conversationId);
          });
          _showSnackBar('Added to favorites', Colors.pink);
          break;
        case 'unfavorite':
          await _chatPreferencesService.unfavoriteChat(
            conversation.conversationId,
          );
          setState(() {
            _favoriteChats.remove(conversation.conversationId);
          });
          _showSnackBar('Removed from favorites', Colors.grey);
          break;
        case 'delete':
          final shouldDelete = await _showDeleteConfirmation(
            conversation.userName,
          );
          if (shouldDelete == true) {
            await _chatPreferencesService.deleteChat(
              conversation.conversationId,
              conversation.toJson(),
            );
            setState(() {
              _deletedChats.add(conversation.conversationId);
              _conversations.removeWhere(
                (conv) => conv.conversationId == conversation.conversationId,
              );
              _pinnedChats.remove(conversation.conversationId);
              _mutedChats.remove(conversation.conversationId);
              _favoriteChats.remove(conversation.conversationId);
            });
            _showSnackBar('Chat deleted', Colors.red);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling chat action: $e');
      _showSnackBar('Action failed', Colors.red);
    }
  }

  /// Show delete confirmation dialog
  Future<bool?> _showDeleteConfirmation(String userName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete the chat with $userName? You can restore it from your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('DELETE'),
          ),
        ],
      ),
    );
  }

  /// Show chat actions bottom sheet
  Future<void> _showChatActions(ConversationModel conversation) async {
    final action = await ChatActionBottomSheet.show(
      context: context,
      conversation: conversation,
      isPinned: _pinnedChats.contains(conversation.conversationId),
      isMuted: _mutedChats.contains(conversation.conversationId),
      isFavorite: _favoriteChats.contains(conversation.conversationId),
    );

    if (action != null) {
      await _handleChatAction(action, conversation);
    }
  }

  /// Show snackbar with message
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<List<ConversationModel>> _loadConversations() async {
    print('Loading conversations');
    try {
      final response = await _userService.GetChatList('dm');
      print(
        "------------------------------------------------------------\n response -> $response \n----------------------------------------------------------------",
      );
      if (response['success']) {
        final dynamic responseData = response['data'];
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
          // Process data in background to avoid blocking UI
          final conversations = await _processConversationsAsync(
            conversationsList,
          );
          // Filter out deleted conversations and sort
          final filteredConversations = await _filterAndSortConversations(
            conversations,
          );

          // Update the state for real-time updates
          if (mounted) {
            setState(() {
              _conversations = filteredConversations;
              _isLoaded = true;
              _filterConversations(); // Update filtered conversations
            });
          }
          return filteredConversations;
        } else {
          // No conversations found - return empty list instead of throwing exception
          debugPrint('ℹ️ No conversations found, returning empty list');
          if (mounted) {
            setState(() {
              _conversations = [];
              _isLoaded = true;
              _filterConversations(); // Update filtered conversations
            });
          }
          return [];
        }
      } else {
        if (mounted) {
          setState(() {
            _conversations = [];
            _isLoaded = true;
            _filterConversations(); // Update filtered conversations
          });
        }
        throw Exception(response['message'] ?? 'Failed to load conversations');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conversations = [];
          _isLoaded = true;
          _filterConversations(); // Update filtered conversations
        });
      }
      throw Exception('Error loading conversations: ${e.toString()}');
    }
  }

  /// Filter out deleted conversations and sort by preferences
  Future<List<ConversationModel>> _filterAndSortConversations(
    List<ConversationModel> conversations,
  ) async {
    // Filter out deleted conversations
    final filteredConversations = conversations
        .where((conv) => !_deletedChats.contains(conv.conversationId))
        .toList();

    // Sort conversations: pinned first, then by last message time
    filteredConversations.sort((a, b) {
      final aPinned = _pinnedChats.contains(a.conversationId);
      final bPinned = _pinnedChats.contains(b.conversationId);

      // If one is pinned and the other is not, pinned comes first
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // Both pinned or both not pinned, sort by last message time
      final aTime = a.lastMessageAt ?? a.joinedAt;
      final bTime = b.lastMessageAt ?? b.joinedAt;
      return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
    });

    return filteredConversations;
  }

  Future<List<ConversationModel>> _processConversationsAsync(
    List<dynamic> conversationsList,
  ) async {
    // Process data in chunks to prevent UI blocking
    const chunkSize = 10;
    List<ConversationModel> processedConversations = [];

    for (int i = 0; i < conversationsList.length; i += chunkSize) {
      final end = (i + chunkSize < conversationsList.length)
          ? i + chunkSize
          : conversationsList.length;
      final chunk = conversationsList.sublist(i, end);

      final chunkProcessed = chunk
          .map(
            (json) => ConversationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      processedConversations.addAll(chunkProcessed);

      // Allow other operations to run
      if (i + chunkSize < conversationsList.length) {
        await Future.delayed(Duration.zero);
      }
    }

    // Set initial online status for all users from the response
    _setInitialOnlineStatus(processedConversations);

    return processedConversations;
  }

  /// Set initial online status from the API response
  void _setInitialOnlineStatus(List<ConversationModel> conversations) {
    for (final conversation in conversations) {
      // Only set status for DM conversations and if onlineStatus is not null
      if (conversation.isDM && conversation.isOnline != null) {
        _userStatusService.setUserOnline(
          conversation.userId, 
          isOnline: conversation.isOnline!
        );
        debugPrint(
          '📡 Set initial online status for user ${conversation.userId}: ${conversation.isOnline}'
        );
      }
    }
  }

  void _refreshConversations() {
    setState(() {
      _conversationsFuture = _loadConversations();
      _isLoaded = false; // Reset to show loading state
      _conversations.clear(); // Clear current conversations
      _filteredConversations.clear(); // Clear filtered conversations
    });
    // Reload chat preferences as well
    _loadChatPreferences();
  }

  /// Clear unread count for a specific conversation
  void _clearUnreadCount(int conversationId) {
    if (!mounted) return;

    final conversationIndex = _conversations.indexWhere(
      (conv) => conv.conversationId == conversationId,
    );

    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      if (conversation.unreadCount > 0) {
        setState(() {
          final updatedConversation = conversation.copyWith(unreadCount: 0);
          _conversations[conversationIndex] = updatedConversation;
        });
        debugPrint(
          '✅ Cleared unread count for conversation $conversationId (was ${conversation.unreadCount})',
        );
      } else {
        debugPrint(
          'ℹ️ Conversation $conversationId already has 0 unread count',
        );
      }
    } else {
      debugPrint(
        '⚠️ Conversation $conversationId not found when trying to clear unread count',
      );
    }
  }

  /// Set the currently active conversation (when user enters inner chat)
  void _setActiveConversation(int? conversationId) {
    debugPrint(
      '📍 Setting active conversation from $_activeConversationId to: $conversationId',
    );
    _activeConversationId = conversationId;
    if (conversationId != null) {
      _clearUnreadCount(conversationId);
    }
  }

  /// Set up WebSocket message listener for typing events
  void _setupWebSocketListener() {
    _websocketSubscription = _websocketService.messageStream.listen(
      (message) {
        _handleIncomingWebSocketMessage(message);
      },
      onError: (error) {
        debugPrint('❌ WebSocket message stream error in ChatsPage: $error');
      },
    );
  }

  /// Set up user status listener to update conversations when status changes
  void _setupUserStatusListener() {
    _userStatusSubscription = _userStatusService.statusStream.listen(
      (statusMap) {
        if (mounted) {
          setState(() {
            // Trigger a rebuild to update online status indicators
            debugPrint('📨 User status updated: $statusMap');
          });
        }
      },
      onError: (error) {
        debugPrint('❌ User status stream error in ChatsPage: $error');
      },
    );
  }

  /// Handle incoming WebSocket messages for typing events
  void _handleIncomingWebSocketMessage(Map<String, dynamic> message) {
    try {
      debugPrint('📨 ChatsPage received WebSocket message: $message');

      // Handle different message types
      final messageType = message['type'];
      if (messageType == 'typing') {
        _handleTypingMessage(message);
      } else if (messageType == 'user_online') {
        _handleUserOnlineMessage(message);
      } else if (messageType == 'user_offline') {
        _handleUserOfflineMessage(message);
      } else if (messageType == 'message_delivery_receipt') {
        _handleMessageDeliveryReceipt(message);
      } else if (messageType == 'message' || messageType == 'media') {
        _handleNewMessage(message);
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message in ChatsPage: $e');
    }
  }

  void _handleUserOnlineMessage(Map<String, dynamic> message) {
    debugPrint('📨 ChatsPage handling user_online message: $message');
    _userStatusService.handleUserOnlineMessage(message);
  }

  void _handleUserOfflineMessage(Map<String, dynamic> message) {
    debugPrint('📨 ChatsPage handling user_offline message: $message');
    _userStatusService.handleUserOfflineMessage(message);
  }

  /// Handle message delivery receipt to update last message and unread count
  void _handleMessageDeliveryReceipt(Map<String, dynamic> message) {
    try {
      debugPrint('📨 ChatsPage handling message_delivery_receipt: $message');

      final data = message['data'] as Map<String, dynamic>? ?? {};
      final conversationId = message['conversation_id'] as int?;
      final messageData = data['message'] as Map<String, dynamic>? ?? {};

      if (conversationId == null) {
        debugPrint('⚠️ Invalid delivery receipt: missing conversation_id');
        return;
      }

      // Find the conversation to update
      final conversationIndex = _conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      if (conversationIndex == -1) {
        debugPrint(
          '⚠️ Conversation not found for delivery receipt: $conversationId',
        );
        return;
      }

      if (mounted && _isLoaded) {
        setState(() {
          final conversation = _conversations[conversationIndex];
          // Update the last message if provided
          ConversationMetadata? updatedMetadata = conversation.metadata;
          if (messageData.isNotEmpty) {
            final lastMessage = LastMessage(
              id: messageData['id'] ?? 0,
              body:
                  messageData['body'] ??
                  messageData['data']['message_type'] ??
                  '',
              type: messageData['type'] ?? 'text',
              senderId: messageData['sender_id'] ?? 0,
              createdAt:
                  messageData['created_at'] ?? DateTime.now().toIso8601String(),
              conversationId: conversationId,
            );
            updatedMetadata = ConversationMetadata(lastMessage: lastMessage);
          }

          // Update unread count (only increment if not the active conversation)
          final providedUnreadCount = data['unread_count'] as int?;
          final newUnreadCount =
              providedUnreadCount ??
              (_activeConversationId == conversationId
                  ? conversation
                        .unreadCount // Don't increment if user is viewing this chat
                  : conversation.unreadCount +
                        1); // Increment if user is not viewing this chat

          // Create updated conversation
          final updatedConversation = conversation.copyWith(
            metadata: updatedMetadata,
            unreadCount: newUnreadCount,
            lastMessageAt:
                messageData['created_at'] ?? DateTime.now().toIso8601String(),
          );

          // Replace the conversation in the list
          _conversations[conversationIndex] = updatedConversation;

          // Sort conversations: pinned first, then by last message time
          _conversations.sort((a, b) {
            final aPinned = _pinnedChats.contains(a.conversationId);
            final bPinned = _pinnedChats.contains(b.conversationId);

            // If one is pinned and the other is not, pinned comes first
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;

            // Both pinned or both not pinned, sort by last message time
            final aTime = a.lastMessageAt ?? a.joinedAt;
            final bTime = b.lastMessageAt ?? b.joinedAt;
            return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
          });

          // Update filtered conversations
          _filterConversations();
        });
      } else {
        debugPrint(
          '⚠️ Cannot update UI: mounted=$mounted, _isLoaded=$_isLoaded',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling message delivery receipt: $e');
    }
  }

  /// Handle new message to update last message and unread count
  void _handleNewMessage(Map<String, dynamic> message) {
    try {
      debugPrint('📨 ChatsPage handling new message: $message');

      final conversationId = message['conversation_id'] as int?;
      final data = message['data'] as Map<String, dynamic>? ?? {};

      if (conversationId == null) {
        debugPrint('⚠️ Invalid new message: missing conversation_id');
        return;
      }

      // Find the conversation to update
      final conversationIndex = _conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      print(
        '------------------------------------------------------------------',
      );
      print('messageData: $data');
      print(
        '------------------------------------------------------------------',
      );
      print(
        '------------------------------------------------------------------',
      );

      if (conversationIndex == -1) {
        debugPrint(
          '⚠️ Conversation not found for new message: $conversationId',
        );
        return;
      }

      // {type: media, data: {user_id: 7300437892, url: https://amigo-chat-app.s3.ap-south-1.amazonaws.com/audios/7300437892/1758627144111_voice_note_1758627136762.m4a, key: audios/7300437892/1758627144111_voice_note_1758627136762.m4a, category: audios, file_name: voice_note_1758627136762.m4a, file_size: 96156, mime_type: audio/x-m4a, conversation_id: 3904105585, message_type: audio, reply_to_message_id: null, optimistic_id: -1, media_message_id: 531}, conversation_id: 3904105585, timestamp: 2025-09-23T11:32:25.419Z}

      // {id: 532, optimistic_id: -2, conversation_id: 3904105585, sender_id: 7300437892, type: text, body: hrhfh, created_at: 2025-09-23T11:35:26.561Z}

      if (mounted && _isLoaded) {
        setState(() {
          final conversation = _conversations[conversationIndex];

          // Create new last message from the message data
          final lastMessage = LastMessage(
            id: data['id'] ?? data['user_id'] ?? 0,
            body:
                data['body'] ??
                data['data']['message_type'] ??
                data['data']['file_name'] ??
                '',
            type: data['type'] ?? data['data']['message_type'] ?? 'text',
            senderId: data['sender_id'] ?? data['data']['user_id'] ?? 0,
            createdAt:
                data['created_at'] ??
                data['data']['created_at'] ??
                DateTime.now().toIso8601String(),
            conversationId: conversationId,
          );

          final updatedMetadata = ConversationMetadata(
            lastMessage: lastMessage,
          );

          // Only increment unread count if this is not the currently active conversation
          final newUnreadCount = _activeConversationId == conversationId
              ? conversation
                    .unreadCount // Don't increment if user is viewing this chat
              : conversation.unreadCount +
                    1; // Increment if user is not viewing this chat

          // Create updated conversation
          final updatedConversation = conversation.copyWith(
            metadata: updatedMetadata,
            unreadCount: newUnreadCount,
            lastMessageAt: lastMessage.createdAt,
          );

          // Replace the conversation in the list
          _conversations[conversationIndex] = updatedConversation;

          // Sort conversations: pinned first, then by last message time
          _conversations.sort((a, b) {
            final aPinned = _pinnedChats.contains(a.conversationId);
            final bPinned = _pinnedChats.contains(b.conversationId);

            // If one is pinned and the other is not, pinned comes first
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;

            // Both pinned or both not pinned, sort by last message time
            final aTime = a.lastMessageAt ?? a.joinedAt;
            final bTime = b.lastMessageAt ?? b.joinedAt;
            return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
          });

          // Update filtered conversations
          _filterConversations();
        });
      } else {
        debugPrint(
          '⚠️ Cannot update UI for new message: mounted=$mounted, _isLoaded=$_isLoaded',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling new message: $e');
    }
  }

  /// Handle typing message from WebSocket
  void _handleTypingMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final conversationId = message['conversation_id'] as int?;
      final isTyping = data['is_typing'] as bool? ?? false;
      final userId = data['user_id'] as int?;

      if (conversationId == null || userId == null) {
        debugPrint(
          '⚠️ Invalid typing message: missing conversationId or userId',
        );
        return;
      }

      // Find the conversation to get user name
      _conversationsFuture
          .then((conversations) {
            final conversation = conversations.firstWhere(
              (conv) => conv.conversationId == conversationId,
              orElse: () => throw StateError('Conversation not found'),
            );

            if (mounted) {
              setState(() {
                if (isTyping) {
                  _typingUsers[conversationId] = true;
                  _typingUserNames[conversationId] = conversation.userName;

                  // Cancel existing timer
                  _typingTimers[conversationId]?.cancel();

                  // Set timer to hide typing indicator after 2 seconds
                  _typingTimers[conversationId] = Timer(
                    const Duration(seconds: 2),
                    () {
                      if (mounted) {
                        setState(() {
                          _typingUsers[conversationId] = false;
                          _typingUserNames.remove(conversationId);
                        });
                      }
                      _typingTimers[conversationId] = null;
                    },
                  );
                } else {
                  // Stop typing immediately
                  _typingUsers[conversationId] = false;
                  _typingUserNames.remove(conversationId);
                  _typingTimers[conversationId]?.cancel();
                  _typingTimers[conversationId] = null;
                }
              });
            }
          })
          .catchError((error) {
            debugPrint(
              '⚠️ Error finding conversation for typing indicator: $error',
            );
          });
    } catch (e) {
      debugPrint('❌ Error handling typing message: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _websocketSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _searchController.dispose(); // Dispose search controller
    // Cancel all typing timers
    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
    // Clear active conversation
    _activeConversationId = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes back to foreground, clear active conversation
    // This handles cases where user might have been in a chat and app was backgrounded
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, clearing active conversation state');
      _activeConversationId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40, // Reduce leading width to minimize gap
        leading: Padding(
          padding: EdgeInsets.only(left: 16), // Add some left padding
          child: Icon(Icons.chat, color: Colors.white),
        ),
        titleSpacing: 8,
        title: Text(
          'Amigo Chats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadConversations();
              // TODO: Implement search functionality
            },
          ),
          // IconButton(
          //   icon: Icon(Icons.more_vert, color: Colors.white),
          //   onPressed: () {
          //     // TODO: Implement more options
          //   },
          // ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Chats List
            Expanded(child: _buildChatsContent()),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // TODO: Implement new chat functionality
      //   },
      //   backgroundColor: Colors.teal,
      //   child: Icon(Icons.chat, color: Colors.white),
      // ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Avatar skeleton
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Time skeleton
          Container(
            width: 50,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshConversations,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to begin',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No chats found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with a different term',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsContent() {
    debugPrint(
      '🏗️ Building chats content: _isLoaded=$_isLoaded, conversations count=${_conversations.length}, search query: "$_searchQuery"',
    );

    // If we have loaded conversations and they're available, show them directly
    if (_isLoaded && _conversations.isNotEmpty) {
      final conversationsToShow = _searchQuery.isNotEmpty
          ? _filteredConversations
          : _conversations;
      debugPrint(
        '🏗️ Using real-time conversations (${conversationsToShow.length} items, filtered: ${_searchQuery.isNotEmpty})',
      );
      return _buildChatsList(conversationsToShow);
    }

    // Otherwise, use FutureBuilder for initial load
    return FutureBuilder<List<ConversationModel>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        debugPrint(
          '🏗️ FutureBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, _isLoaded: $_isLoaded',
        );

        if (snapshot.connectionState == ConnectionState.waiting && !_isLoaded) {
          return _buildSkeletonLoader();
        } else if (snapshot.hasError && !_isLoaded) {
          return _buildErrorState(snapshot.error.toString());
        } else if (snapshot.hasData) {
          // If we have data but haven't loaded real-time state yet, show the snapshot data
          final conversations = _isLoaded ? _conversations : snapshot.data!;
          final conversationsToShow = _searchQuery.isNotEmpty
              ? _filteredConversations
              : conversations;
          debugPrint(
            '🏗️ Using conversations: ${conversationsToShow.length} items (filtered: ${_searchQuery.isNotEmpty})',
          );
          if (conversationsToShow.isEmpty) {
            return _searchQuery.isNotEmpty
                ? _buildSearchEmptyState()
                : _buildEmptyState();
          }
          return _buildChatsList(conversationsToShow);
        } else if (_isLoaded && _conversations.isEmpty) {
          return _searchQuery.isNotEmpty
              ? _buildSearchEmptyState()
              : _buildEmptyState();
        } else {
          return _buildSkeletonLoader();
        }
      },
    );
  }

  Widget _buildChatsList(List<ConversationModel> conversations) {
    return RefreshIndicator(
      onRefresh: () async => _refreshConversations(),
      child: ListView.builder(
        itemCount: conversations.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          final isTyping = _typingUsers[conversation.conversationId] ?? false;
          final typingUserName = _typingUserNames[conversation.conversationId];

          return ChatListItem(
            conversation: conversation,
            isTyping: isTyping,
            typingUserName: typingUserName,
            isOnline: _userStatusService.isUserOnline(conversation.userId),
            isPinned: _pinnedChats.contains(conversation.conversationId),
            isMuted: _mutedChats.contains(conversation.conversationId),
            isFavorite: _favoriteChats.contains(conversation.conversationId),
            onLongPress: () => _showChatActions(conversation),
            onTap: () async {
              // Set this conversation as active and clear unread count
              _setActiveConversation(conversation.conversationId);

              // Navigate to inner chat page
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      InnerChatPage(conversation: conversation),
                ),
              );

              // Clear unread count again when returning from inner chat
              // This ensures the count is cleared even if it was updated while in the chat
              _clearUnreadCount(conversation.conversationId);

              // Send inactive message before clearing active conversation
              try {
                await _websocketService.sendMessage({
                  'type': 'inactive_in_conversation',
                  'conversation_id': conversation.conversationId,
                });
              } catch (e) {
                debugPrint('❌ Error sending inactive_in_conversation: $e');
              }

              // Clear active conversation when returning from inner chat
              _setActiveConversation(null);
            },
          );
        },
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isTyping;
  final String? typingUserName;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;

  const ChatListItem({
    Key? key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.isTyping = false,
    this.typingUserName,
    this.isOnline = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isFavorite = false,
  }) : super(key: key);

  String _formatTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
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

  @override
  Widget build(BuildContext context) {
    final hasUnreadMessages = conversation.unreadCount > 0 && !isMuted;
    final lastMessageText =
        conversation.metadata?.lastMessage.body ?? 'No messages yet';
    final timeText = conversation.metadata != null
        ? _formatTime(conversation.metadata!.lastMessage.createdAt)
        : _formatTime(conversation.joinedAt);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isPinned ? Colors.teal.withOpacity(0.05) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
          left: isPinned
              ? BorderSide(color: Colors.orange, width: 3)
              : BorderSide.none,
        ),
      ),
      child: ListTile(
        leading: _buildAvatar(),
        title: Row(
          children: [
            if (isPinned) ...[
              Icon(Icons.push_pin, size: 16, color: Colors.orange),
              SizedBox(width: 4),
            ],
            if (isMuted) ...[
              Icon(Icons.volume_off, size: 16, color: Colors.grey[600]),
              SizedBox(width: 4),
            ],
            if (isFavorite) ...[
              Icon(Icons.favorite, size: 16, color: Colors.pink),
              SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                conversation.userName,
                style: TextStyle(
                  fontWeight: hasUnreadMessages
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: isTyping
            ? _buildTypingIndicator()
            : Text(
                lastMessageText,
                style: TextStyle(
                  color: isMuted ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: _buildTrailing(timeText, hasUnreadMessages),
        onTap: onTap,
        onLongPress: onLongPress,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.teal[100],
          backgroundImage: conversation.userProfilePic != null
              ? NetworkImage(conversation.userProfilePic!)
              : null,
          child: conversation.userProfilePic == null
              ? Text(
                  _getInitials(conversation.userName),
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        // Online status indicator - only show for DM conversations
        if (conversation.isDM && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        Text(
          'typing',
          style: TextStyle(
            color: Colors.teal[600],
            fontSize: 14,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        _buildTypingAnimation(),
      ],
    );
  }

  Widget _buildTypingAnimation() {
    return SizedBox(
      width: 20,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _TypingDot(delay: 0),
          _TypingDot(delay: 200),
          _TypingDot(delay: 400),
        ],
      ),
    );
  }

  Widget _buildTrailing(String timeText, bool hasUnreadMessages) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(timeText, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        if (hasUnreadMessages && !isTyping) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isMuted ? Colors.grey : Colors.teal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              conversation.unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start animation with delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.teal[600]!.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
