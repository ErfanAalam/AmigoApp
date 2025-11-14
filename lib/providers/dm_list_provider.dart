import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation_model.dart';
import '../api/user.service.dart';
import '../db/repositories/conversations_repository.dart';
import '../services/socket/websocket_message_handler.dart';
import '../services/last_message_storage_service.dart';
import '../services/chat_preferences_service.dart';
import '../services/user_status_service.dart';
import '../api/chats.services.dart';

/// State class for DM list
class DmListState {
  final List<ConversationModel> conversations;
  final bool isLoading;
  final int? activeConversationId;
  final Map<int, bool> typingUsers; // conversationId -> isTyping
  final Map<int, String> typingUserNames; // conversationId -> userName
  final Set<int> pinnedChats;
  final Set<int> mutedChats;
  final Set<int> favoriteChats;
  final Set<int> deletedChats;
  final String searchQuery;

  DmListState({
    this.conversations = const [],
    this.isLoading = false,
    this.activeConversationId,
    Map<int, bool>? typingUsers,
    Map<int, String>? typingUserNames,
    Set<int>? pinnedChats,
    Set<int>? mutedChats,
    Set<int>? favoriteChats,
    Set<int>? deletedChats,
    this.searchQuery = '',
  }) : typingUsers = typingUsers ?? {},
       typingUserNames = typingUserNames ?? {},
       pinnedChats = pinnedChats ?? {},
       mutedChats = mutedChats ?? {},
       favoriteChats = favoriteChats ?? {},
       deletedChats = deletedChats ?? {};

  DmListState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    int? activeConversationId,
    Map<int, bool>? typingUsers,
    Map<int, String>? typingUserNames,
    Set<int>? pinnedChats,
    Set<int>? mutedChats,
    Set<int>? favoriteChats,
    Set<int>? deletedChats,
    String? searchQuery,
    bool clearActiveConversation = false,
    bool clearTypingUsers = false,
  }) {
    return DmListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      activeConversationId: clearActiveConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      typingUsers: clearTypingUsers ? {} : (typingUsers ?? this.typingUsers),
      typingUserNames: typingUserNames ?? this.typingUserNames,
      pinnedChats: pinnedChats ?? this.pinnedChats,
      mutedChats: mutedChats ?? this.mutedChats,
      favoriteChats: favoriteChats ?? this.favoriteChats,
      deletedChats: deletedChats ?? this.deletedChats,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get filtered conversations based on search query
  List<ConversationModel> get filteredConversations {
    if (searchQuery.isEmpty) {
      return conversations;
    }
    final query = searchQuery.toLowerCase();
    return conversations.where((conversation) {
      final userName = conversation.userName.toLowerCase();
      final lastMessageBody =
          conversation.metadata?.lastMessage.body.toLowerCase() ?? '';
      return userName.contains(query) || lastMessageBody.contains(query);
    }).toList();
  }
}

/// Provider for DM list state
final dmListProvider = NotifierProvider<DmListNotifier, DmListState>(
  () => DmListNotifier(),
);

class DmListNotifier extends Notifier<DmListState> {
  final UserService _userService = UserService();
  final ConversationsRepository _conversationsRepo = ConversationsRepository();
  final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final LastMessageStorageService _lastMessageStorage =
      LastMessageStorageService.instance;
  final ChatPreferencesService _chatPreferencesService =
      ChatPreferencesService();
  final UserStatusService _userStatusService = UserStatusService();
  final ChatsServices _chatsServices = ChatsServices();

  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _mediaSubscription;
  StreamSubscription<Map<String, dynamic>>? _replySubscription;
  StreamSubscription<Map<String, dynamic>>? _conversationAddedSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeleteSubscription;
  StreamSubscription<Map<int, bool>>? _userStatusSubscription;

  final Map<int, Timer?> _typingTimers = {};

  @override
  DmListState build() {
    // Initialize and load data
    Future.microtask(() async {
      await _loadChatPreferences();
      await _loadFromLocal();
      await loadConversations();
      _setupWebSocketListeners();
    });
    return DmListState();
  }

  /// Load conversations from local DB first
  Future<void> _loadFromLocal() async {
    try {
      final localConversations = await _conversationsRepo.getAllConversations();
      if (localConversations.isNotEmpty) {
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages(
              localConversations,
            );
        state = state.copyWith(
          conversations: updatedConversations,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading from local DB: $e');
    }
  }

  /// Load chat preferences from local storage
  Future<void> _loadChatPreferences() async {
    try {
      final pinnedChats = await _chatPreferencesService.getPinnedChats();
      final mutedChats = await _chatPreferencesService.getMutedChats();
      final favoriteChats = await _chatPreferencesService.getFavoriteChats();
      final deletedChats = await _chatPreferencesService.getDeletedChats();

      state = state.copyWith(
        pinnedChats: pinnedChats.toSet(),
        mutedChats: mutedChats.toSet(),
        favoriteChats: favoriteChats.toSet(),
        deletedChats: deletedChats
            .map((chat) => chat['conversation_id'] as int)
            .toSet(),
      );
    } catch (e) {
      debugPrint('❌ Error loading chat preferences: $e');
    }
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
          final lastMessage = LastMessage(
            id: storedMessage['id'] ?? 0,
            body: storedMessage['body'] ?? '',
            type: storedMessage['type'] ?? 'text',
            senderId: storedMessage['sender_id'] ?? 0,
            createdAt:
                storedMessage['created_at'] ?? DateTime.now().toIso8601String(),
            conversationId: conversation.conversationId,
          );

          final updatedMetadata = ConversationMetadata(
            lastMessage: lastMessage,
            pinnedMessage: conversation.metadata?.pinnedMessage,
          );

          final updatedConversation = conversation.copyWith(
            metadata: updatedMetadata,
            lastMessageAt: lastMessage.createdAt,
          );

          updatedConversations.add(updatedConversation);
        } else {
          updatedConversations.add(conversation);
        }
      }

      return updatedConversations;
    } catch (e) {
      debugPrint(
        '❌ Error updating conversations with stored last messages: $e',
      );
      return conversations;
    }
  }

  /// Load conversations from server
  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

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
          final conversations = await _processConversationsAsync(
            conversationsList,
          );
          final filteredConversations = await _filterAndSortConversations(
            conversations,
          );

          // Store last messages
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

          await _conversationsRepo.insertOrUpdateConversations(
            filteredConversations,
          );

          state = state.copyWith(
            conversations: filteredConversations,
            isLoading: false,
          );
        } else {
          state = state.copyWith(conversations: [], isLoading: false);
        }
      } else {
        // Fallback to local
        final localConversations = await _conversationsRepo
            .getAllConversations();
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages(
              localConversations,
            );
        state = state.copyWith(
          conversations: updatedConversations,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      try {
        final localConversations = await _conversationsRepo
            .getAllConversations();
        final updatedConversations =
            await _updateConversationsWithStoredLastMessages(
              localConversations,
            );
        state = state.copyWith(
          conversations: updatedConversations,
          isLoading: false,
        );
      } catch (localError) {
        debugPrint('❌ Error loading from local DB: $localError');
        state = state.copyWith(conversations: [], isLoading: false);
      }
    }
  }

  /// Process conversations asynchronously
  Future<List<ConversationModel>> _processConversationsAsync(
    List<dynamic> conversationsList,
  ) async {
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
              if (json is Map<String, dynamic>) {
                final conversationId = json['conversationId'];
                final userName = json['userName'];

                if (conversationId == null ||
                    userName == null ||
                    userName.toString().isEmpty) {
                  return null;
                }

                return ConversationModel.fromJson(json);
              }
              return null;
            } catch (e) {
              debugPrint('❌ Error processing conversation: $e');
              return null;
            }
          })
          .where((conversation) => conversation != null)
          .cast<ConversationModel>()
          .toList();

      processedConversations.addAll(chunkProcessed);

      if (i + chunkSize < conversationsList.length) {
        await Future.delayed(Duration.zero);
      }
    }

    _setInitialOnlineStatus(processedConversations);

    return processedConversations;
  }

  /// Set initial online status
  void _setInitialOnlineStatus(List<ConversationModel> conversations) {
    for (final conversation in conversations) {
      if (conversation.isDM && conversation.isOnline != null) {
        _userStatusService.setUserOnlineStatus(
          conversation.userId,
          isOnline: conversation.isOnline!,
        );
      }
    }
  }

  /// Filter and sort conversations
  Future<List<ConversationModel>> _filterAndSortConversations(
    List<ConversationModel> conversations,
  ) async {
    final filteredConversations = conversations
        .where((conv) => !state.deletedChats.contains(conv.conversationId))
        .toList();

    filteredConversations.sort((a, b) {
      final aPinned = state.pinnedChats.contains(a.conversationId);
      final bPinned = state.pinnedChats.contains(b.conversationId);

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aHasMessage =
          a.lastMessageAt != null && a.lastMessageAt!.isNotEmpty;
      final bHasMessage =
          b.lastMessageAt != null && b.lastMessageAt!.isNotEmpty;

      if (aHasMessage && !bHasMessage) return -1;
      if (!aHasMessage && bHasMessage) return 1;

      if (aHasMessage && bHasMessage) {
        return DateTime.parse(
          b.lastMessageAt!,
        ).compareTo(DateTime.parse(a.lastMessageAt!));
      } else {
        return DateTime.parse(b.joinedAt).compareTo(DateTime.parse(a.joinedAt));
      }
    });

    return filteredConversations;
  }

  /// Set active conversation
  void setActiveConversation(int? conversationId) {
    state = state.copyWith(activeConversationId: conversationId);
    if (conversationId != null) {
      clearUnreadCount(conversationId);
    }
  }

  /// Clear unread count for a conversation
  void clearUnreadCount(int conversationId) {
    final conversationIndex = state.conversations.indexWhere(
      (conv) => conv.conversationId == conversationId,
    );

    if (conversationIndex != -1) {
      final conversation = state.conversations[conversationIndex];
      if (conversation.unreadCount > 0) {
        final updatedConversation = conversation.copyWith(unreadCount: 0);
        final updatedConversations = List<ConversationModel>.from(
          state.conversations,
        );
        updatedConversations[conversationIndex] = updatedConversation;

        state = state.copyWith(conversations: updatedConversations);
        _conversationsRepo.updateUnreadCount(conversationId, 0);
      }
    }
  }

  /// Update search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  /// Handle chat action (pin, mute, favorite, delete)
  Future<void> handleChatAction(
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
            state = state.copyWith(
              pinnedChats: {...state.pinnedChats, conversation.conversationId},
            );
          }
          break;
        case 'unpin':
          await _chatPreferencesService.unpinChat(conversation.conversationId);
          final newPinned = Set<int>.from(state.pinnedChats);
          newPinned.remove(conversation.conversationId);
          state = state.copyWith(pinnedChats: newPinned);
          break;
        case 'mute':
          await _chatPreferencesService.muteChat(conversation.conversationId);
          state = state.copyWith(
            mutedChats: {...state.mutedChats, conversation.conversationId},
          );
          break;
        case 'unmute':
          await _chatPreferencesService.unmuteChat(conversation.conversationId);
          final newMuted = Set<int>.from(state.mutedChats);
          newMuted.remove(conversation.conversationId);
          state = state.copyWith(mutedChats: newMuted);
          break;
        case 'favorite':
          await _chatPreferencesService.favoriteChat(
            conversation.conversationId,
          );
          state = state.copyWith(
            favoriteChats: {
              ...state.favoriteChats,
              conversation.conversationId,
            },
          );
          break;
        case 'unfavorite':
          await _chatPreferencesService.unfavoriteChat(
            conversation.conversationId,
          );
          final newFavorite = Set<int>.from(state.favoriteChats);
          newFavorite.remove(conversation.conversationId);
          state = state.copyWith(favoriteChats: newFavorite);
          break;
        case 'delete':
          final response = await _chatsServices.deleteDm(
            conversation.conversationId,
          );
          if (response['success']) {
            await _chatPreferencesService.deleteChat(
              conversation.conversationId,
              conversation.toJson(),
            );
            final newDeleted = Set<int>.from(state.deletedChats);
            newDeleted.add(conversation.conversationId);
            final updatedConversations = state.conversations
                .where(
                  (conv) => conv.conversationId != conversation.conversationId,
                )
                .toList();
            final newPinned = Set<int>.from(state.pinnedChats);
            newPinned.remove(conversation.conversationId);
            final newMuted = Set<int>.from(state.mutedChats);
            newMuted.remove(conversation.conversationId);
            final newFavorite = Set<int>.from(state.favoriteChats);
            newFavorite.remove(conversation.conversationId);

            state = state.copyWith(
              conversations: updatedConversations,
              deletedChats: newDeleted,
              pinnedChats: newPinned,
              mutedChats: newMuted,
              favoriteChats: newFavorite,
            );
            _conversationsRepo.deleteConversation(conversation.conversationId);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling chat action: $e');
    }
  }

  /// Set up WebSocket listeners
  void _setupWebSocketListeners() {
    _typingSubscription = _messageHandler.typingStream.listen(
      _handleTypingMessage,
      onError: (error) {
        debugPrint('❌ Typing stream error: $error');
      },
    );

    _messageSubscription = _messageHandler.messageStream.listen(
      _handleNewMessage,
      onError: (error) {
        debugPrint('❌ Message stream error: $error');
      },
    );

    _replySubscription = _messageHandler.messageReplyStream.listen(
      _handleNewMessage,
      onError: (error) {
        debugPrint('❌ Reply stream error: $error');
      },
    );

    _mediaSubscription = _messageHandler.mediaStream.listen(
      _handleNewMessage,
      onError: (error) {
        debugPrint('❌ Media stream error: $error');
      },
    );

    _conversationAddedSubscription = _messageHandler.conversationAddedStream
        .listen(
          _handleConversationAdded,
          onError: (error) {
            debugPrint('❌ Conversation added stream error: $error');
          },
        );

    _messageDeleteSubscription = _messageHandler.messageDeleteStream.listen(
      _handleMessageDelete,
      onError: (error) {
        debugPrint('❌ Message delete stream error: $error');
      },
    );

    _userStatusSubscription = _userStatusService.statusStream.listen(
      (_) {
        // Trigger rebuild when user status changes
        state = state.copyWith();
      },
      onError: (error) {
        debugPrint('❌ User status stream error: $error');
      },
    );
  }

  /// Handle typing message
  void _handleTypingMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final conversationId = message['conversation_id'] as int?;
      final isTyping = data['is_typing'] as bool? ?? false;
      final userId = data['user_id'] as int?;

      if (conversationId == null || userId == null) return;

      final conversation = state.conversations.firstWhere(
        (conv) => conv.conversationId == conversationId,
        orElse: () => ConversationModel(
          conversationId: 0,
          type: 'dm',
          unreadCount: 0,
          joinedAt: DateTime.now().toIso8601String(),
          userId: 0,
          userName: '',
        ),
      );

      if (conversation.conversationId == 0) return;

      if (isTyping) {
        final typingUsers = Map<int, bool>.from(state.typingUsers);
        final typingUserNames = Map<int, String>.from(state.typingUserNames);
        typingUsers[conversationId] = true;
        typingUserNames[conversationId] = conversation.userName;

        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = Timer(const Duration(seconds: 2), () {
          final newTypingUsers = Map<int, bool>.from(state.typingUsers);
          final newTypingUserNames = Map<int, String>.from(
            state.typingUserNames,
          );
          newTypingUsers[conversationId] = false;
          newTypingUserNames.remove(conversationId);
          state = state.copyWith(
            typingUsers: newTypingUsers,
            typingUserNames: newTypingUserNames,
          );
          _typingTimers[conversationId] = null;
        });

        state = state.copyWith(
          typingUsers: typingUsers,
          typingUserNames: typingUserNames,
        );
      } else {
        final newTypingUsers = Map<int, bool>.from(state.typingUsers);
        final newTypingUserNames = Map<int, String>.from(state.typingUserNames);
        newTypingUsers[conversationId] = false;
        newTypingUserNames.remove(conversationId);
        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = null;

        state = state.copyWith(
          typingUsers: newTypingUsers,
          typingUserNames: newTypingUserNames,
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling typing message: $e');
    }
  }

  /// Handle new message
  Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    try {
      final conversationId = message['conversation_id'] as int?;
      final messageType = message['type'] as String?;
      final data = message['data'] as Map<String, dynamic>? ?? {};

      if (conversationId == null) return;

      final conversationIndex = state.conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      if (conversationIndex == -1) return;

      final conversation = state.conversations[conversationIndex];

      String messageBody = data['body'] ?? '';
      String messageTypeValue = data['type'] ?? messageType ?? 'text';
      int senderId = data['sender_id'] ?? 0;
      int messageId = data['id'] ?? 0;
      String createdAt =
          data['created_at'] ??
          message['timestamp'] ??
          DateTime.now().toIso8601String();

      if (messageBody.isEmpty && data['data'] != null) {
        final nestedData = data['data'] as Map<String, dynamic>;
        messageBody =
            nestedData['message_type'] ?? nestedData['file_name'] ?? '';
        messageTypeValue = nestedData['message_type'] ?? messageType ?? 'media';
        senderId = nestedData['user_id'] ?? senderId;
        messageId =
            nestedData['media_message_id'] ??
            data['media_message_id'] ??
            messageId;
        createdAt = nestedData['created_at'] ?? createdAt;
      }

      final lastMessage = LastMessage(
        id: messageId,
        body: messageBody,
        type: messageBody.isEmpty ? 'attachment' : messageTypeValue,
        senderId: senderId,
        createdAt: createdAt,
        conversationId: conversationId,
        attachmentData: data['attachments'],
      );

      await _lastMessageStorage.storeLastMessage(conversationId, {
        'id': messageId,
        'body': messageBody,
        'type': messageTypeValue,
        'sender_id': senderId,
        'created_at': createdAt,
        'conversation_id': conversationId,
        'attachments': data['attachments'],
      });

      final updatedMetadata = ConversationMetadata(
        lastMessage: lastMessage,
        pinnedMessage: conversation.metadata?.pinnedMessage,
      );

      final newUnreadCount = state.activeConversationId == conversationId
          ? conversation.unreadCount
          : conversation.unreadCount + 1;

      final updatedConversation = conversation.copyWith(
        metadata: updatedMetadata,
        unreadCount: newUnreadCount,
        lastMessageAt: lastMessage.createdAt,
      );

      final updatedConversations = List<ConversationModel>.from(
        state.conversations,
      );
      updatedConversations[conversationIndex] = updatedConversation;

      await _conversationsRepo.insertOrUpdateConversation(updatedConversation);

      // Sort conversations
      final sortedConversations = await _filterAndSortConversations(
        updatedConversations,
      );

      state = state.copyWith(conversations: sortedConversations);
    } catch (e) {
      debugPrint('❌ Error handling new message: $e');
    }
  }

  /// Handle conversation added
  Future<void> _handleConversationAdded(Map<String, dynamic> message) async {
    try {
      final conversationId = message['conversation_id'] as int?;
      final data = message['data'] as Map<String, dynamic>?;

      if (conversationId == null || data == null) return;

      final conversationType = data['type'] as String?;
      if (conversationType != 'dm') return;

      final existingIndex = state.conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      if (existingIndex != -1) return;

      final conversation = ConversationModel.fromJson(data);
      final updatedConversations =
          await _updateConversationsWithStoredLastMessages([conversation]);

      if (updatedConversations.isNotEmpty) {
        final newConversations = [
          ...state.conversations,
          updatedConversations[0],
        ];
        final sortedConversations = await _filterAndSortConversations(
          newConversations,
        );

        await _conversationsRepo.insertOrUpdateConversation(
          updatedConversations[0],
        );

        state = state.copyWith(conversations: sortedConversations);
      }
    } catch (e) {
      debugPrint('❌ Error handling conversation added: $e');
    }
  }

  /// Handle message delete
  Future<void> _handleMessageDelete(Map<String, dynamic> message) async {
    try {
      final conversationId = message['conversation_id'] as int?;
      final messageIds = message['message_ids'] as List<dynamic>? ?? [];

      if (conversationId == null || messageIds.isEmpty) return;

      final deletedMessageIds = messageIds.map((id) => id as int).toList();

      final conversationIndex = state.conversations.indexWhere(
        (conv) => conv.conversationId == conversationId,
      );

      if (conversationIndex == -1) return;

      final conversation = state.conversations[conversationIndex];
      final lastMessage = conversation.metadata?.lastMessage;

      if (lastMessage != null && deletedMessageIds.contains(lastMessage.id)) {
        try {
          final historyResponse = await _chatsServices.getConversationHistory(
            conversationId: conversationId,
            page: 1,
            limit: 1,
          );

          if (historyResponse['success'] == true) {
            final messages =
                historyResponse['data']['messages'] as List<dynamic>? ?? [];

            final updatedConversations = List<ConversationModel>.from(
              state.conversations,
            );

            if (messages.isNotEmpty) {
              final newLastMessageData = messages[0] as Map<String, dynamic>;
              final newLastMessage = LastMessage(
                id: newLastMessageData['id'] ?? 0,
                body: newLastMessageData['body'] ?? '',
                type: newLastMessageData['type'] ?? 'text',
                senderId: newLastMessageData['sender_id'] ?? 0,
                createdAt:
                    newLastMessageData['created_at'] ??
                    DateTime.now().toIso8601String(),
                conversationId: conversationId,
              );

              final updatedMetadata = ConversationMetadata(
                lastMessage: newLastMessage,
                pinnedMessage: conversation.metadata?.pinnedMessage,
              );

              final updatedConversation = conversation.copyWith(
                metadata: updatedMetadata,
                lastMessageAt: newLastMessage.createdAt,
              );

              await _lastMessageStorage.storeLastMessage(conversationId, {
                'id': newLastMessage.id,
                'body': newLastMessage.body,
                'type': newLastMessage.type,
                'sender_id': newLastMessage.senderId,
                'created_at': newLastMessage.createdAt,
                'conversation_id': conversationId,
              });

              await _conversationsRepo.insertOrUpdateConversation(
                updatedConversation,
              );

              updatedConversations[conversationIndex] = updatedConversation;
            } else {
              final updatedConversation = conversation.copyWith(
                metadata: null,
                lastMessageAt: null,
              );

              await _lastMessageStorage.storeLastMessage(conversationId, {
                'id': 0,
                'body': '',
                'type': 'text',
                'sender_id': 0,
                'created_at': DateTime.now().toIso8601String(),
                'conversation_id': conversationId,
              });

              await _conversationsRepo.insertOrUpdateConversation(
                updatedConversation,
              );

              updatedConversations[conversationIndex] = updatedConversation;
            }

            state = state.copyWith(conversations: updatedConversations);
          }
        } catch (e) {
          debugPrint('❌ Error fetching new last message after delete: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling message delete: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _typingSubscription?.cancel();
    _messageSubscription?.cancel();
    _replySubscription?.cancel();
    _mediaSubscription?.cancel();
    _conversationAddedSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _userStatusSubscription?.cancel();

    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
  }
}
