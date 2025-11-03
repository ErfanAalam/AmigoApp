import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/conversation_model.dart';
import '../../../api/user.service.dart';
import '../../../services/websocket_service.dart';
import '../../../services/user_status_service.dart';
import '../../../services/websocket_message_handler.dart';
import '../../../services/chat_preferences_service.dart';
import '../../../services/last_message_storage_service.dart';
import '../../../widgets/chat_action_menu.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../api/chats.services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/chat/searchable_list_widget.dart';
import '../../../providers/draft_provider.dart';
import 'messaging.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => ChatsPageState();
}

class ChatsPageState extends ConsumerState<ChatsPage>
    with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final ChatPreferencesService _chatPreferencesService =
      ChatPreferencesService();
  final ConversationsRepository _conversationsRepo = ConversationsRepository();
  final LastMessageStorageService _lastMessageStorage =
      LastMessageStorageService.instance;
  final ChatsServices _chatsServices = ChatsServices();
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
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _mediaSubscription;
  StreamSubscription<Map<String, dynamic>>? _replySubscription;
  StreamSubscription<Map<int, bool>>? _userStatusSubscription;
  StreamSubscription<Map<String, dynamic>>? _conversationAddedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversationsFromLocal();
    _loadConversations();
    _setupWebSocketListener();
    _setupUserStatusListener();
    _loadChatPreferences();
    _setupConversationAddedListener();

    // Setup search functionality
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadConversationsFromLocal() async {
    try {
      final localConversations = await _conversationsRepo.getAllConversations();
      if (localConversations.isNotEmpty && mounted) {
        // Load last messages from storage and update conversations
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages(
              localConversations,
            );

        setState(() {
          _conversations = updatedConversations;
          _isLoaded = true;
          _filterConversations();
        });
      }
    } catch (e) {
      debugPrint('Error loading conversations from local: $e');
    }
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
        // Add null safety checks
        final userName = conversation.userName;
        final lastMessageBody = conversation.metadata?.lastMessage.body ?? '';

        return userName.toLowerCase().contains(_searchQuery) ||
            lastMessageBody.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  /// Clear search query
  void _clearSearch() {
    _searchController.clear();
  }

  /// Update conversations with stored last messages
  Future<List<ConversationModel>> _updateConversationsWithStoredLastMessages(
    List<ConversationModel> conversations,
  ) async {
    try {
      final storedLastMessages = await _lastMessageStorage.getAllLastMessages();
      final updatedConversations = <ConversationModel>[];

      for (final conversation in conversations) {
        final storedMessage = storedLastMessages[conversation.conversationId];

        if (storedMessage != null) {
          // Create LastMessage from stored data
          final lastMessage = LastMessage(
            id: storedMessage['id'] ?? 0,
            body: storedMessage['body'] ?? '',
            type: storedMessage['type'] ?? 'text',
            senderId: storedMessage['sender_id'] ?? 0,
            createdAt:
                storedMessage['created_at'] ?? DateTime.now().toIso8601String(),
            conversationId: conversation.conversationId,
          );

          // Create updated metadata with stored last message
          final updatedMetadata = ConversationMetadata(
            lastMessage: lastMessage,
            pinnedMessage: conversation.metadata?.pinnedMessage,
          );

          // Create updated conversation
          final updatedConversation = conversation.copyWith(
            metadata: updatedMetadata,
            lastMessageAt: lastMessage.createdAt,
          );

          updatedConversations.add(updatedConversation);
        } else {
          // No stored last message, use original conversation
          updatedConversations.add(conversation);
        }
      }

      return updatedConversations;
    } catch (e) {
      debugPrint(
        '❌ Error updating conversations with stored last messages: $e',
      );
      return conversations; // Return original conversations on error
    }
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
            final response = await _chatsServices.deleteDm(
              conversation.conversationId,
            );

            if (response['success']) {
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
                // Delete from local DB
                _conversationsRepo.deleteConversation(
                  conversation.conversationId,
                );
              });
              _showSnackBar('Chat deleted', Colors.teal);
            }
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
    try {
      final response = await _userService.GetChatList('dm');
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

          // Store the server's last messages to local storage for offline use
          for (final conversation in filteredConversations) {
            if (conversation.metadata?.lastMessage != null) {
              final lastMsg = conversation.metadata!.lastMessage;
              await _lastMessageStorage
                  .storeLastMessage(conversation.conversationId, {
                    'id': lastMsg.id,
                    'body': lastMsg.body,
                    'type': lastMsg.type,
                    'sender_id': lastMsg.senderId,
                    'created_at': lastMsg.createdAt,
                    'conversation_id': conversation.conversationId,
                  });
            }
          }

          // Persist to local DB
          await _conversationsRepo.insertOrUpdateConversations(
            filteredConversations,
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
        // Server returned error, try to load from local DB
        debugPrint('⚠️ Server fetch failed, loading from local DB');
        final localConversations = await _conversationsRepo
            .getAllConversations();
        // Update with stored last messages when using local data
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages(
              localConversations,
            );
        if (mounted) {
          setState(() {
            _conversations = updatedConversations;
            _isLoaded = true;
            _filterConversations();
          });
        }
        return updatedConversations;
      }
    } catch (e) {
      debugPrint(
        '❌ Error loading conversations from server \n 📦 Loading from local DB as fallback',
      );
      try {
        final localConversations = await _conversationsRepo
            .getAllConversations();
        // Update with stored last messages when using local data
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages(
              localConversations,
            );
        if (mounted) {
          setState(() {
            _conversations = updatedConversations;
            _isLoaded = true;
            _filterConversations();
          });
        }
        return updatedConversations;
      } catch (localError) {
        debugPrint('❌ Error loading from local DB: $localError');
        if (mounted) {
          setState(() {
            _conversations = [];
            _isLoaded = true;
            _filterConversations();
          });
        }
        return [];
      }
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
    // print(
    //   "--------------------------------------------------------------------------------",
    // );
    // for (var conv in filteredConversations) {
    //   print(
    //     "Conversation ID: ${conv.conversationId}, User: ${conv.userName}, Last Message At: ${conv.lastMessageAt}, Pinned: ${_pinnedChats.contains(conv.conversationId)}",
    //   );
    // }
    // print(
    //   "--------------------------------------------------------------------------------",
    // );

    // Sort conversations: pinned first, then by last message time
    filteredConversations.sort((a, b) {
      final aPinned = _pinnedChats.contains(a.conversationId);
      final bPinned = _pinnedChats.contains(b.conversationId);

      // If one is pinned and the other is not, pinned comes first
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // Both pinned or both not pinned, sort by last message time
      // Prioritize conversations with messages over those without
      final aHasMessage =
          a.lastMessageAt != null && a.lastMessageAt!.isNotEmpty;
      final bHasMessage =
          b.lastMessageAt != null && b.lastMessageAt!.isNotEmpty;

      // If one has messages and the other doesn't, prioritize the one with messages
      if (aHasMessage && !bHasMessage) return -1;
      if (!aHasMessage && bHasMessage) return 1;

      // Both have messages or both don't have messages
      if (aHasMessage && bHasMessage) {
        // Both have messages, sort by lastMessageAt (most recent first)
        return DateTime.parse(
          b.lastMessageAt!,
        ).compareTo(DateTime.parse(a.lastMessageAt!));
      } else {
        // Neither has messages, sort by joinedAt (most recent first)
        return DateTime.parse(b.joinedAt).compareTo(DateTime.parse(a.joinedAt));
      }
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
          .map((json) {
            try {
              // Add validation before creating ConversationModel
              if (json is Map<String, dynamic>) {
                final conversationId = json['conversationId'];
                final userName = json['userName'];

                // Skip invalid conversations
                if (conversationId == null ||
                    userName == null ||
                    userName.toString().isEmpty) {
                  return null;
                }

                return ConversationModel.fromJson(json);
              }
              return null;
            } catch (e) {
              debugPrint('❌ Error processing conversation: $e, data: $json');
              return null;
            }
          })
          .where((conversation) => conversation != null)
          .cast<ConversationModel>()
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
        _userStatusService.setUserOnlineStatus(
          conversation.userId,
          isOnline: conversation.isOnline!,
        );
      }
    }
  }

  void _refreshConversations() {
    setState(() {
      _isLoaded = false; // Reset to show loading state
      _conversations.clear(); // Clear current conversations
      _filteredConversations.clear(); // Clear filtered conversations
    });
    _loadConversations();
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
          // Persist to local DB
          _conversationsRepo.updateUnreadCount(conversationId, 0);
        });
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
    _activeConversationId = conversationId;
    if (conversationId != null) {
      _clearUnreadCount(conversationId);
    }
  }

  /// Set up conversation added listener
  void _setupConversationAddedListener() {
    _conversationAddedSubscription = _messageHandler.conversationAddedStream
        .listen(
          (message) {
            _handleConversationAdded(message);
          },
          onError: (error) {
            debugPrint(
              '❌ Conversation added stream error in ChatsPage: $error',
            );
          },
        );
  }

  /// Handle conversation added message
  Future<void> _handleConversationAdded(Map<String, dynamic> message) async {
    try {
      final conversationId = message['conversation_id'] as int?;
      final data = message['data'] as Map<String, dynamic>?;

      if (conversationId == null || data == null) {
        debugPrint(
          '⚠️ Invalid conversation_added message: missing conversation_id or data',
        );
        return;
      }

      // Only handle DMs in the DM list screen
      final conversationType = data['type'] as String?;
      if (conversationType != 'dm') {
        return; // Ignore groups, they'll be handled in group_list.dart
      }

      // Check if conversation already exists in the list
      final existingIndex = _conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      if (existingIndex != -1) {
        debugPrint(
          'ℹ️ Conversation $conversationId already exists in list, skipping',
        );
        return;
      }

      // Convert the data to ConversationModel
      try {
        final conversation = ConversationModel.fromJson(data);

        // Update with stored last message if available
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages([conversation]);

        if (updatedConversations.isNotEmpty && mounted) {
          setState(() {
            // Add the new conversation to the list
            _conversations.add(updatedConversations[0]);

            // Sort conversations: pinned first, then by last message time
            _conversations.sort((a, b) {
              final aPinned = _pinnedChats.contains(a.conversationId);
              final bPinned = _pinnedChats.contains(b.conversationId);

              if (aPinned && !bPinned) return -1;
              if (!aPinned && bPinned) return 1;

              // Prioritize conversations with messages over those without
              final aHasMessage =
                  a.lastMessageAt != null && a.lastMessageAt!.isNotEmpty;
              final bHasMessage =
                  b.lastMessageAt != null && b.lastMessageAt!.isNotEmpty;

              // If one has messages and the other doesn't, prioritize the one with messages
              if (aHasMessage && !bHasMessage) return -1;
              if (!aHasMessage && bHasMessage) return 1;

              // Both have messages or both don't have messages
              if (aHasMessage && bHasMessage) {
                // Both have messages, sort by lastMessageAt (most recent first)
                return DateTime.parse(
                  b.lastMessageAt!,
                ).compareTo(DateTime.parse(a.lastMessageAt!));
              } else {
                // Neither has messages, sort by joinedAt (most recent first)
                return DateTime.parse(
                  b.joinedAt,
                ).compareTo(DateTime.parse(a.joinedAt));
              }
            });

            // Persist to local DB
            _conversationsRepo.insertOrUpdateConversation(
              updatedConversations[0],
            );

            // Update filtered conversations
            _filterConversations();
          });

          debugPrint('✅ Added new DM conversation $conversationId to list');
        }
      } catch (e) {
        debugPrint('❌ Error converting conversation data: $e');
      }
    } catch (e) {
      debugPrint('❌ Error handling conversation_added message: $e');
    }
  }

  /// Set up WebSocket message listener using centralized handler
  void _setupWebSocketListener() {
    // Listen to typing events for all conversations
    _typingSubscription = _messageHandler.typingStream.listen(
      (message) {
        _handleTypingMessage(message);
      },
      onError: (error) {
        debugPrint('❌ Typing stream error in ChatsPage: $error');
      },
    );

    // Listen to new messages for all conversations
    _messageSubscription = _messageHandler.messageStream.listen(
      (message) {
        _handleNewMessage(message);
      },
      onError: (error) {
        debugPrint('❌ Message stream error in ChatsPage: $error');
      },
    );

    // Listen to new replied messages for all conversations
    _replySubscription = _messageHandler.messageReplyStream.listen(
      (message) {
        _handleNewMessage(message);
      },
      onError: (error) {
        debugPrint('❌ Reply stream error in ChatsPage: $error');
      },
    );

    // Listen to media messages for all conversations
    _mediaSubscription = _messageHandler.mediaStream.listen(
      (message) {
        _handleNewMessage(message);
      },
      onError: (error) {
        debugPrint('❌ Media stream error in ChatsPage: $error');
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
          });
        }
      },
      onError: (error) {
        debugPrint('❌ User status stream error in ChatsPage: $error');
      },
    );
  }

  // Note: User online/offline messages are now handled centrally by WebSocketMessageHandler
  // and routed to UserStatusService, which we listen to via _setupUserStatusListener()

  /// /// Handle message delivery receipt to update last message and unread count
  /// Future<void> _handleMessageDeliveryReceipt(
  ///   Map<String, dynamic> message,
  /// ) async {
  ///   try {
  ///     final data = message['data'] as Map<String, dynamic>? ?? {};
  ///     final conversationId = message['conversation_id'] as int?;
  ///     final messageData = data['message'] as Map<String, dynamic>? ?? {};
  ///
  ///     if (conversationId == null) {
  ///       debugPrint('⚠️ Invalid delivery receipt: missing conversation_id');
  ///       return;
  ///     }
  ///
  ///     // Find the conversation to update
  ///     final conversationIndex = _conversations.indexWhere(
  ///       (conv) => conv.conversationId == conversationId,
  ///     );
  ///
  ///     if (conversationIndex == -1) {
  ///       debugPrint(
  ///         '⚠️ Conversation not found for delivery receipt: $conversationId',
  ///       );
  ///       return;
  ///     }
  ///
  ///     if (mounted && _isLoaded) {
  ///       final conversation = _conversations[conversationIndex];
  ///       // Update the last message if provided
  ///       ConversationMetadata? updatedMetadata = conversation.metadata;
  ///       if (messageData.isNotEmpty) {
  ///         // Extract message details with proper handling for media messages
  ///         String messageBody = messageData['body'] ?? '';
  ///         String messageTypeValue = messageData['type'] ?? 'text';
  ///         int senderId = messageData['sender_id'] ?? 0;
  ///         int messageId = messageData['id'] ?? 0;
  ///         String createdAt =
  ///             messageData['created_at'] ?? DateTime.now().toIso8601String();
  ///
  ///         // If body is empty and it's a media message, extract from nested data
  ///         if (messageBody.isEmpty && messageData['data'] != null) {
  ///           final nestedData = messageData['data'] as Map<String, dynamic>;
  ///           messageBody =
  ///               nestedData['message_type'] ?? nestedData['file_name'] ?? '';
  ///           messageTypeValue = nestedData['message_type'] ?? messageTypeValue;
  ///           senderId = nestedData['user_id'] ?? senderId;
  ///           messageId = nestedData['media_message_id'] ?? messageId;
  ///           createdAt = nestedData['created_at'] ?? createdAt;
  ///         }
  ///
  ///         final lastMessage = LastMessage(
  ///           id: messageId,
  ///           body: messageBody,
  ///           type: messageTypeValue,
  ///           senderId: senderId,
  ///           createdAt: createdAt,
  ///           conversationId: conversationId,
  ///         );
  ///
  ///         // Store the last message in local storage
  ///         await _lastMessageStorage.storeLastMessage(conversationId, {
  ///           'id': messageId,
  ///           'body': messageBody,
  ///           'type': messageTypeValue,
  ///           'sender_id': senderId,
  ///           'created_at': createdAt,
  ///           'conversation_id': conversationId,
  ///         });
  ///
  ///         // Preserve pinnedMessage from existing metadata
  ///         updatedMetadata = ConversationMetadata(
  ///           lastMessage: lastMessage,
  ///           pinnedMessage: conversation.metadata?.pinnedMessage,
  ///         );
  ///       }
  ///
  ///       setState(() {
  ///         // Update unread count (only increment if not the active conversation)
  ///         final providedUnreadCount = data['unread_count'] as int?;
  ///         final newUnreadCount =
  ///             providedUnreadCount ??
  ///             (_activeConversationId == conversationId
  ///                 ? conversation
  ///                       .unreadCount // Don't increment if user is viewing this chat
  ///                 : conversation.unreadCount +
  ///                       1); // Increment if user is not viewing this chat
  ///
  ///         // Create updated conversation
  ///         final updatedConversation = conversation.copyWith(
  ///           metadata: updatedMetadata,
  ///           unreadCount: newUnreadCount,
  ///           lastMessageAt:
  ///               messageData['created_at'] ?? DateTime.now().toIso8601String(),
  ///         );
  ///
  ///         // Replace the conversation in the list
  ///         _conversations[conversationIndex] = updatedConversation;
  ///
  ///         // Persist to local DB
  ///         _conversationsRepo.insertOrUpdateConversation(updatedConversation);
  ///
  ///         // Sort conversations: pinned first, then by last message time
  ///         _conversations.sort((a, b) {
  ///           final aPinned = _pinnedChats.contains(a.conversationId);
  ///           final bPinned = _pinnedChats.contains(b.conversationId);
  ///
  ///           // If one is pinned and the other is not, pinned comes first
  ///           if (aPinned && !bPinned) return -1;
  ///           if (!aPinned && bPinned) return 1;
  ///
  ///           // Both pinned or both not pinned, sort by last message time
  ///           final aTime = a.lastMessageAt ?? a.joinedAt;
  ///           final bTime = b.lastMessageAt ?? b.joinedAt;
  ///           return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
  ///         });
  ///
  ///         // Update filtered conversations to immediately show the updated list
  ///         _filterConversations();
  ///       });
  ///     } else {
  ///       debugPrint(
  ///         '⚠️ Cannot update UI: mounted=$mounted, _isLoaded=$_isLoaded',
  ///       );
  ///     }
  ///   } catch (e) {
  ///     debugPrint('❌ Error handling message delivery receipt: $e');
  ///   }
  /// }

  /// Handle new message to update last message and unread count
  Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    try {
      final conversationId = message['conversation_id'] as int?;
      final messageType = message['type'] as String?;
      final data = message['data'] as Map<String, dynamic>? ?? {};

      if (conversationId == null) {
        debugPrint('⚠️ Invalid new message: missing conversation_id');
        return;
      }

      // Find the conversation to update
      final conversationIndex = _conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      if (conversationIndex == -1) {
        debugPrint(
          '⚠️ Conversation not found for new message: $conversationId',
        );
        return;
      }

      if (mounted && _isLoaded) {
        final conversation = _conversations[conversationIndex];

        // Extract message details with proper handling for media messages
        String messageBody = data['body'] ?? '';
        String messageTypeValue = data['type'] ?? messageType ?? 'text';
        int senderId = data['sender_id'] ?? 0;
        int messageId = data['id'] ?? 0;
        String createdAt =
            data['created_at'] ??
            message['timestamp'] ??
            DateTime.now().toIso8601String();

        // If body is empty and it's a media message, extract from nested data
        if (messageBody.isEmpty && data['data'] != null) {
          final nestedData = data['data'] as Map<String, dynamic>;
          messageBody =
              nestedData['message_type'] ?? nestedData['file_name'] ?? '';
          messageTypeValue =
              nestedData['message_type'] ?? messageType ?? 'media';
          senderId = nestedData['user_id'] ?? senderId;
          messageId =
              nestedData['media_message_id'] ??
              data['media_message_id'] ??
              messageId;
          createdAt = nestedData['created_at'] ?? createdAt;
        }

        // Create new last message from the message data
        final lastMessage = LastMessage(
          id: messageId,
          body: messageBody,
          type: messageBody.isEmpty ? 'attachment' : messageTypeValue,
          senderId: senderId,
          createdAt: createdAt,
          conversationId: conversationId,
          attachmentData: data['attachments'],
        );

        // Store the last message in local storage
        await _lastMessageStorage.storeLastMessage(conversationId, {
          'id': messageId,
          'body': messageBody,
          'type': messageTypeValue,
          'sender_id': senderId,
          'created_at': createdAt,
          'conversation_id': conversationId,
          'attachments': data['attachments'],
        });

        // Preserve pinnedMessage from existing metadata
        final updatedMetadata = ConversationMetadata(
          lastMessage: lastMessage,
          pinnedMessage: conversation.metadata?.pinnedMessage,
        );

        setState(() {
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

          // Persist to local DB
          _conversationsRepo.insertOrUpdateConversation(updatedConversation);

          // Sort conversations: pinned first, then by last message time
          _conversations.sort((a, b) {
            final aPinned = _pinnedChats.contains(a.conversationId);
            final bPinned = _pinnedChats.contains(b.conversationId);

            // If one is pinned and the other is not, pinned comes first
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;

            // Prioritize conversations with messages over those without
            final aHasMessage =
                a.lastMessageAt != null && a.lastMessageAt!.isNotEmpty;
            final bHasMessage =
                b.lastMessageAt != null && b.lastMessageAt!.isNotEmpty;

            // If one has messages and the other doesn't, prioritize the one with messages
            if (aHasMessage && !bHasMessage) return -1;
            if (!aHasMessage && bHasMessage) return 1;

            // Both have messages or both don't have messages
            if (aHasMessage && bHasMessage) {
              // Both have messages, sort by lastMessageAt (most recent first)
              return DateTime.parse(
                b.lastMessageAt!,
              ).compareTo(DateTime.parse(a.lastMessageAt!));
            } else {
              // Neither has messages, sort by joinedAt (most recent first)
              return DateTime.parse(
                b.joinedAt,
              ).compareTo(DateTime.parse(a.joinedAt));
            }
          });

          // Update filtered conversations to immediately show the updated list
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
      try {
        final conversation = _conversations.firstWhere(
          (conv) => conv.conversationId == conversationId,
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
      } catch (error) {
        debugPrint(
          '⚠️ Error finding conversation for typing indicator: $error',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling typing message: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingSubscription?.cancel();
    _messageSubscription?.cancel();
    _replySubscription?.cancel();
    _mediaSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _conversationAddedSubscription?.cancel();
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
      _activeConversationId = null;
    }
  }

  /// Called when the page becomes visible (when user navigates to Chats tab)
  void onPageVisible() {
    // Silently refresh conversations without showing loading state
    _loadConversationsSilently();
  }

  /// Silently load conversations without affecting the UI state
  Future<void> _loadConversationsSilently() async {
    try {
      // debugPrint('🔄 Silently loading conversations...');
      final response = await _userService.GetChatList('dm');

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
          // Process data in background
          final conversations = await _processConversationsAsync(
            conversationsList,
          );
          // Filter out deleted conversations and sort
          final filteredConversations = await _filterAndSortConversations(
            conversations,
          );

          // Store the server's last messages to local storage for offline use
          for (final conversation in filteredConversations) {
            if (conversation.metadata?.lastMessage != null) {
              final lastMsg = conversation.metadata!.lastMessage;
              await _lastMessageStorage
                  .storeLastMessage(conversation.conversationId, {
                    'id': lastMsg.id,
                    'body': lastMsg.body,
                    'type': lastMsg.type,
                    'sender_id': lastMsg.senderId,
                    'created_at': lastMsg.createdAt,
                    'conversation_id': conversation.conversationId,
                    'attachments': lastMsg.attachmentData,
                  });
            }
          }

          // Persist to local DB
          await _conversationsRepo.insertOrUpdateConversations(
            filteredConversations,
          );

          // Update the state silently (only if mounted and not already showing loading)
          if (mounted && _isLoaded) {
            setState(() {
              _conversations = filteredConversations;
              _filterConversations(); // Update filtered conversations
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error silently loading conversations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.teal,
          leadingWidth: 60,
          leading: Container(
            margin: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amigo chats',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => _loadConversations(),
              ),
            ),
          ],
        ),
      ),

      body: SearchableListLayout(
        searchBar: SearchableListBar(
          controller: _searchController,
          hintText: 'Search chats...',
          onChanged: (value) => _onSearchChanged(),
          onClear: _clearSearch,
        ),
        content: _buildChatsContent(),
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
    // Show loading skeleton while loading
    if (!_isLoaded) {
      return _buildSkeletonLoader();
    }

    // Determine which conversations to show
    final conversationsToShow = _searchQuery.isNotEmpty
        ? _filteredConversations
        : _conversations;

    // Show empty state if no conversations
    if (conversationsToShow.isEmpty) {
      return _searchQuery.isNotEmpty
          ? _buildSearchEmptyState()
          : _buildEmptyState();
    }

    // Show the conversations list
    return _buildChatsList(conversationsToShow);
  }

  Widget _buildChatsList(List<ConversationModel> conversations) {
    // Add safety check for empty conversations
    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshConversations(),
      child: ListView.builder(
        itemCount: conversations.length,
        itemExtent: 80,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          // Add bounds checking
          if (index >= conversations.length) {
            return Container(); // Return empty container if index is out of bounds
          }

          final conversation = conversations[index];

          // Add null safety check for conversation
          if (conversation.userName.isEmpty) {
            return Container(); // Skip invalid conversations
          }

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
            conversationId: conversation.conversationId,
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

class ChatListItem extends ConsumerWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isTyping;
  final String? typingUserName;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;
  final int conversationId;

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
    required this.conversationId,
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
    if (name.isEmpty || name.trim().isEmpty) {
      return '?';
    }

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      // Check if both words have at least one character
      if (words[0].isNotEmpty && words[1].isNotEmpty) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words[0].isNotEmpty) {
        return words[0][0].toUpperCase();
      }
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  String _formatLastMessageText(
    String lastMessageBody,
    String? messageType, [
    Map<String, dynamic>? attachmentData,
  ]) {
    // If body is not empty and not a media type identifier, return it
    if (lastMessageBody.isNotEmpty &&
        ![
          'image',
          'images',
          'video',
          'videos',
          'audio',
          'audios',
          'voice',
          'file',
          'document',
          'location',
          'contact',
          'media',
        ].contains(lastMessageBody.toLowerCase())) {
      return lastMessageBody;
    }

    // Handle media messages based on type or body
    final type = (messageType ?? lastMessageBody).toLowerCase();
    switch (type) {
      case 'attachment':
        if (attachmentData != null && attachmentData.containsKey('category')) {
          final attachmentType = attachmentData['category'].toLowerCase();
          switch (attachmentType) {
            case 'image':
            case 'images':
              return '📷 Photo';
            case 'video':
            case 'videos':
              return '📹 Video';
            case 'audio':
            case 'audios':
            case 'voice':
              return '🎵 Audio';
            case 'file':
            case 'document':
              return '📎 File';
          }
        }
        return '📎 Attachment';
      case 'location':
        return '📍 Location';
      case 'contact':
        return '👤 Contact';
      case 'media':
        return '📎 Media';
      case 'text':
        return lastMessageBody;
      default:
        return lastMessageBody.isNotEmpty ? lastMessageBody : 'New message';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check for draft message
    final drafts = ref.watch(draftMessagesProvider);
    final draft = drafts[conversationId];

    final hasUnreadMessages = conversation.unreadCount > 0 && !isMuted;

    // Use draft if available, otherwise use last message
    String lastMessageBody;
    String? lastMessageType;
    Map<String, dynamic>? attachmentData;

    if (draft != null && draft.isNotEmpty) {
      // Show draft as last message
      lastMessageBody = draft;
      lastMessageType = 'text';
      attachmentData = null;
    } else {
      lastMessageBody =
          conversation.metadata?.lastMessage.body ?? 'No messages yet';
      lastMessageType = conversation.metadata?.lastMessage.type;
      attachmentData = conversation.metadata?.lastMessage.attachmentData;
    }

    final lastMessageText = _formatLastMessageText(
      lastMessageBody,
      lastMessageType,
      attachmentData,
    );
    final timeText = conversation.metadata?.lastMessage.createdAt != null
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
                      : FontWeight.bold,
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
                draft != null && draft.isNotEmpty
                    ? 'Draft: $lastMessageText'
                    : lastMessageText,
                style: TextStyle(
                  color: draft != null && draft.isNotEmpty
                      ? Colors.orange[600]
                      : (isMuted ? Colors.grey[400] : Colors.grey[600]),
                  fontSize: 14,
                  fontStyle: draft != null && draft.isNotEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: _buildUnreadCounts(timeText, hasUnreadMessages),
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
              ? CachedNetworkImageProvider(conversation.userProfilePic!)
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
          'Typing',
          style: TextStyle(
            color: Colors.teal[600],
            fontSize: 14,
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

  Widget _buildUnreadCounts(String timeText, bool hasUnreadMessages) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(timeText, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        if (hasUnreadMessages) ...[
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
