import 'dart:async';
import 'package:amigo/db/repositories/conversation_member.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/group_model.dart';
import 'package:amigo/models/community_model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/user.service.dart';
import '../models/user_model.dart';
import '../services/socket/websocket_message_handler.dart';
import '../services/user_status_service.dart';
import '../api/chats.services.dart';

/// State class for DM list
class ChatState {
  final List<DmModel> dmList;
  final List<GroupModel> groupList;
  final List<CommunityModel> communities;
  final List<CommunityGroupModel>? commGroupList;
  final bool isLoading;
  final int? activeConvId;
  final ChatType? activeConvType;
  final Map<int, List<int>> typingConvUsers; // conversationId -> userIds[]
  final Set<int> pinnedChats;
  final Set<int> mutedChats;
  final Set<int> favoriteChats;
  final Set<int> deletedChats;
  final String searchQuery;

  ChatState({
    this.dmList = const [],
    this.groupList = const [],
    this.communities = const [],
    this.commGroupList,
    this.isLoading = false,
    this.activeConvId,
    this.activeConvType,
    Map<int, List<int>>? typingConvUsers,
    Set<int>? pinnedChats,
    Set<int>? mutedChats,
    Set<int>? favoriteChats,
    Set<int>? deletedChats,
    this.searchQuery = '',
  }) : typingConvUsers = typingConvUsers ?? {},
       pinnedChats = pinnedChats ?? {},
       mutedChats = mutedChats ?? {},
       favoriteChats = favoriteChats ?? {},
       deletedChats = deletedChats ?? {};

  ChatState copyWith({
    List<DmModel>? dmList,
    List<GroupModel>? groupList,
    List<CommunityModel>? communities,
    List<CommunityGroupModel>? commGroupList,
    bool? isLoading,
    int? activeConversationId,
    ChatType? activeConvType,
    Map<int, List<int>>? typingConvUsers,
    Set<int>? pinnedChats,
    Set<int>? mutedChats,
    Set<int>? favoriteChats,
    Set<int>? deletedChats,
    String? searchQuery,
    bool clearActiveConversation = false,
    bool clearTypingConvs = false,
  }) {
    return ChatState(
      dmList: dmList ?? this.dmList,
      groupList: groupList ?? this.groupList,
      communities: communities ?? this.communities,
      commGroupList: commGroupList ?? this.commGroupList,
      isLoading: isLoading ?? this.isLoading,
      activeConvId: clearActiveConversation
          ? null
          : (activeConversationId ?? this.activeConvId),
      activeConvType: activeConvType ?? this.activeConvType,
      typingConvUsers: clearTypingConvs
          ? {}
          : (typingConvUsers ?? this.typingConvUsers),
      pinnedChats: pinnedChats ?? this.pinnedChats,
      mutedChats: mutedChats ?? this.mutedChats,
      favoriteChats: favoriteChats ?? this.favoriteChats,
      deletedChats: deletedChats ?? this.deletedChats,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get filtered conversations based on search query
  List<DmModel> get filteredConversations {
    if (searchQuery.isEmpty) {
      return dmList;
    }
    final query = searchQuery.toLowerCase();
    return dmList.where((conversation) {
      final recipientName = conversation.recipientName.toLowerCase();
      final lastMessageBody = conversation.lastMessageBody?.toLowerCase() ?? '';
      final recipientPhone = conversation.recipientPhone.toLowerCase();
      return recipientName.contains(query) ||
          lastMessageBody.contains(query) ||
          recipientPhone.contains(query);
    }).toList();
  }

  /// Get filtered group items (groups + communities) based on search query
  List<dynamic> get filteredGroupItems {
    if (searchQuery.isEmpty) {
      return [...groupList, ...communities];
    }
    final query = searchQuery.toLowerCase();
    final filteredGroups = groupList.where((group) {
      return group.title.toLowerCase().contains(query) ||
          group.members!.any(
            (member) => member.name.toLowerCase().contains(query),
          );
    }).toList();

    final filteredCommunities = communities.where((community) {
      return community.name.toLowerCase().contains(query);
    }).toList();

    return [...filteredGroups, ...filteredCommunities];
  }
}

/// Provider for chat state (DM, Groups, Community Groups)
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);

/// Legacy alias for backward compatibility
final dmListProvider = chatProvider;

class ChatNotifier extends Notifier<ChatState> {
  final UserService _userService = UserService();
  final UserRepository _userRepo = UserRepository();
  final ConversationRepository _conversationsRepo = ConversationRepository();
  final MessageRepository _messageRepo = MessageRepository();
  final ConversationMemberRepository _conversationsMemberRepo =
      ConversationMemberRepository();
  final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final UserStatusService _userStatusService = UserStatusService();
  final ChatsServices _chatsServices = ChatsServices();

  StreamSubscription<OnlineStatusPayload>? _onlineStatusSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<ChatMessageAckPayload>? _messageAckSubscription;
  StreamSubscription<MessagePinPayload>? _pinSubscription;
  StreamSubscription<NewConversationPayload>? _conversationAddedSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;

  final Map<int, Timer?> _typingTimers = {};

  @override
  ChatState build() {
    // Initialize and load data
    Future.microtask(() async {
      await _loadConvsFromLocal();
      await loadConvsFromServer();
      _setupWebSocketListeners();
    });
    return ChatState();
  }

  /// Load conversations from local DB first
  Future<void> _loadConvsFromLocal() async {
    try {
      final localDMs = await _conversationsRepo.getAllDmsWithRecipientInfo();
      final localGroups = await _conversationsRepo.getGroupListWithoutMembers();
      // final localCommGroups = await _conversationsRepo.getConversationsByType(
      //   ChatType.communityGroup,
      // );

      // Initialize Sets from loaded conversations
      final pinnedChats = <int>{};
      final mutedChats = <int>{};
      final favoriteChats = <int>{};
      final deletedChats = <int>{};

      for (final dm in localDMs) {
        if (dm.isPinned == true) pinnedChats.add(dm.conversationId);
        if (dm.isMuted == true) mutedChats.add(dm.conversationId);
        if (dm.isFavorite == true) favoriteChats.add(dm.conversationId);
        if (dm.isDeleted == true) deletedChats.add(dm.conversationId);
      }

      if (localDMs.isNotEmpty) {
        state = state.copyWith(
          dmList: localDMs,
          isLoading: false,
          pinnedChats: pinnedChats,
          mutedChats: mutedChats,
          favoriteChats: favoriteChats,
          deletedChats: deletedChats,
        );
      }
      if (localGroups.isNotEmpty) {
        state = state.copyWith(groupList: localGroups, isLoading: false);
      }
    } catch (e) {
      debugPrint('❌ Error loading from local DB: $e');
    }
  }

  /// Load conversations from server
  Future<void> loadConvsFromServer({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    final response = await _userService.getChatList('dm');
    if (response['success']) {
      final List<dynamic> conversationsList = response['data'];

      if (conversationsList.isNotEmpty) {
        final dmList = await _convertToDmListTypeAsync(conversationsList);
        final convList = await _convertToConversationsTypeAsync(
          conversationsList,
        );

        // Store conversations in local DB
        await _conversationsRepo.insertConversations(convList);

        // Store conversation members in local DB
        final convMembers = dmList
            .map(
              (dm) => ConversationMemberModel(
                conversationId: dm.conversationId,
                userId: dm.recipientId,
                role: 'member',
                unreadCount: dm.unreadCount ?? 0,
                joinedAt: dm.createdAt,
              ),
            )
            .toList();
        await _conversationsMemberRepo.insertConversationMembers(convMembers);

        // Store user (recipient) in local DB
        final users = dmList
            .map(
              (dm) => UserModel(
                id: dm.recipientId,
                name: dm.recipientName,
                phone: dm.recipientPhone,
                profilePic: dm.recipientProfilePic,
                isOnline: dm.isRecipientOnline,
              ),
            )
            .toList();
        await _userRepo.insertUsers(users);

        // Load pin/mute/favorite status from local DB (these are local-only, not from server)
        // Query all DM conversations from DB to get their local pin/mute/favorite status
        final localConvs = await _conversationsRepo.getConversationsByType(
          ChatType.dm,
        );
        final convStatusMap = <int, ConversationModel>{};
        for (final conv in localConvs) {
          convStatusMap[conv.id] = conv;
        }

        // Merge with existing Sets to preserve group status
        final currentPinnedChats = Set<int>.from(state.pinnedChats);
        final currentMutedChats = Set<int>.from(state.mutedChats);
        final currentFavoriteChats = Set<int>.from(state.favoriteChats);
        final currentDeletedChats = Set<int>.from(state.deletedChats);

        // Populate Sets from local DB status for DMs
        for (final dm in dmList) {
          final conv = convStatusMap[dm.conversationId];
          if (conv != null) {
            if (conv.isPinned == true) {
              currentPinnedChats.add(dm.conversationId);
            } else {
              currentPinnedChats.remove(dm.conversationId);
            }
            if (conv.isMuted == true) {
              currentMutedChats.add(dm.conversationId);
            } else {
              currentMutedChats.remove(dm.conversationId);
            }
            if (conv.isFavorite == true) {
              currentFavoriteChats.add(dm.conversationId);
            } else {
              currentFavoriteChats.remove(dm.conversationId);
            }
            if (conv.isDeleted == true) {
              currentDeletedChats.add(dm.conversationId);
            } else {
              currentDeletedChats.remove(dm.conversationId);
            }
          } else {
            // If conversation not found in DB, ensure it's not in Sets
            currentPinnedChats.remove(dm.conversationId);
            currentMutedChats.remove(dm.conversationId);
            currentFavoriteChats.remove(dm.conversationId);
            currentDeletedChats.remove(dm.conversationId);
          }
        }

        // Update Provider state
        state = state.copyWith(
          dmList: dmList,
          isLoading: false,
          pinnedChats: currentPinnedChats,
          mutedChats: currentMutedChats,
          favoriteChats: currentFavoriteChats,
          deletedChats: currentDeletedChats,
        );
      } else {
        state = state.copyWith(dmList: [], isLoading: false);
      }
    }

    // Load groups
    final groupResponse = await _userService.getChatList('group');
    if (groupResponse['success']) {
      final List<dynamic> groupsList = groupResponse['data'] is List
          ? groupResponse['data']
          : [];

      List<GroupModel> groups = [];
      List<ConversationModel> convs = [];

      for (final group in groupsList) {
        try {
          if (group is Map<String, dynamic>) {
            final groupModel = GroupModel.fromJson(group);
            groups.add(groupModel);

            final convModel = ConversationModel(
              id: groupModel.conversationId,
              type: "group",
              title: groupModel.title,
              createrId: group['createrId'] ?? 0,
              unreadCount: groupModel.unreadCount,
              lastMessageId: groupModel.lastMessageId,
              pinnedMessageId: groupModel.pinnedMessageId,
              isDeleted: false,
              isPinned: false,
              isFavorite: false,
              isMuted: false,
              createdAt: groupModel.joinedAt,
            );
            convs.add(convModel);
          }
        } catch (e) {
          debugPrint('❌ Error processing group conversation: $e');
        }
      }

      // Store group conversations in local DB
      await _conversationsRepo.insertConversations(convs);

      // Load pin/mute/favorite status from local DB for groups (these are local-only, not from server)
      final localGroupConvs = await _conversationsRepo.getConversationsByType(
        ChatType.group,
      );
      final groupConvStatusMap = <int, ConversationModel>{};
      for (final conv in localGroupConvs) {
        groupConvStatusMap[conv.id] = conv;
      }

      // Update pinned/muted/favorite Sets with group status
      final currentPinnedChats = Set<int>.from(state.pinnedChats);
      final currentMutedChats = Set<int>.from(state.mutedChats);
      final currentFavoriteChats = Set<int>.from(state.favoriteChats);
      final currentDeletedChats = Set<int>.from(state.deletedChats);

      for (final group in groups) {
        final conv = groupConvStatusMap[group.conversationId];
        if (conv != null) {
          if (conv.isPinned == true) {
            currentPinnedChats.add(group.conversationId);
          } else {
            currentPinnedChats.remove(group.conversationId);
          }
          if (conv.isMuted == true) {
            currentMutedChats.add(group.conversationId);
          } else {
            currentMutedChats.remove(group.conversationId);
          }
          if (conv.isFavorite == true) {
            currentFavoriteChats.add(group.conversationId);
          } else {
            currentFavoriteChats.remove(group.conversationId);
          }
          if (conv.isDeleted == true) {
            currentDeletedChats.add(group.conversationId);
          } else {
            currentDeletedChats.remove(group.conversationId);
          }
        } else {
          // If conversation not found in DB, ensure it's not in Sets
          currentPinnedChats.remove(group.conversationId);
          currentMutedChats.remove(group.conversationId);
          currentFavoriteChats.remove(group.conversationId);
          currentDeletedChats.remove(group.conversationId);
        }
      }

      // Storing group members and metadata can be added here if needed
      // Sort groups
      final sortedGroups = await _filterAndSortGroupConversations(groups);
      state = state.copyWith(
        groupList: sortedGroups,
        isLoading: false,
        pinnedChats: currentPinnedChats,
        mutedChats: currentMutedChats,
        favoriteChats: currentFavoriteChats,
        deletedChats: currentDeletedChats,
      );
    } else {
      state = state.copyWith(dmList: [], isLoading: false);
    }
  }

  /// Process conversations asynchronously
  Future<List<DmModel>> _convertToDmListTypeAsync(
    List<dynamic> conversationsList,
  ) async {
    const chunkSize = 10;
    List<DmModel> processedConversations = [];

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
                final recipientName = json['userName'];

                if (conversationId == null ||
                    recipientName == null ||
                    recipientName.toString().isEmpty) {
                  return null;
                }

                // mapping backend response to DmListModel
                // Note: isPinned, isMuted, isFavorite are local-only and not from server
                return DmModel(
                  conversationId: json['conversationId'],
                  recipientId: json['userId'],
                  recipientName: json['userName'],
                  recipientPhone: json['userPhone'],
                  recipientProfilePic: json['userProfilePic'],
                  pinnedMessageId: json['pinnedMessageId'],
                  lastMessageId: json['lastMessageId'],
                  lastMessageType: json['lastMessageType'],
                  lastMessageBody: json['lastMessageBody'],
                  lastMessageAt: json['lastMessageAt'],
                  unreadCount: json['unreadCount'],
                  isRecipientOnline: json['onlineStatus'],
                  createdAt: json['createdAt'],
                );
              }
              return null;
            } catch (e) {
              debugPrint('❌ Error processing conversation: $e');
              return null;
            }
          })
          .where((conversation) => conversation != null)
          .cast<DmModel>()
          .toList();

      processedConversations.addAll(chunkProcessed);

      if (i + chunkSize < conversationsList.length) {
        await Future.delayed(Duration.zero);
      }
    }

    // _setInitialOnlineStatus(processedConversations);

    return processedConversations;
  }

  Future<List<ConversationModel>> _convertToConversationsTypeAsync(
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
                final convId = json['conversationId'];

                if (convId == null) {
                  return null;
                }

                // mapping backend response to DmListModel
                return ConversationModel(
                  id: convId,
                  type: json['type'],
                  title: json['title'],
                  createrId: json['createrId'],
                  unreadCount: json['unreadCount'],
                  lastMessageId: json['lastMessageId'],
                  pinnedMessageId: json['pinnedMessageId'],
                  isDeleted: json['isDeleted'],
                  isPinned: json['isPinned'],
                  isFavorite: json['isFavorite'],
                  isMuted: json['isMuted'],
                  createdAt: json['createdAt'],
                );
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

    // _setInitialOnlineStatus(processedConversations);

    return processedConversations;
  }

  /// Filter and sort conversations
  Future<List<DmModel>> _filterAndSortConversations(
    List<DmModel> conversations,
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
        return DateTime.parse(
          b.createdAt,
        ).compareTo(DateTime.parse(a.createdAt));
      }
    });

    return filteredConversations;
  }

  /// Filter and sort group conversations
  Future<List<GroupModel>> _filterAndSortGroupConversations(
    List<GroupModel> groups,
  ) async {
    final filteredGroups = groups
        .where((group) => !state.deletedChats.contains(group.conversationId))
        .toList();

    filteredGroups.sort((a, b) {
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

    return filteredGroups;
  }

  /// Set active conversation
  void setActiveConversation(int? conversationId, ChatType? convType) {
    state = state.copyWith(
      activeConversationId: conversationId,
      activeConvType: convType,
    );
    if (conversationId != null) {
      clearUnreadCount(conversationId, convType);
    }
  }

  /// Clear unread count for a conversation
  void clearUnreadCount(int convId, ChatType? convType) async {
    if (convType == ChatType.dm) {
      final convIndex = state.dmList.indexWhere(
        (conv) => conv.conversationId == convId,
      );

      if (convIndex != -1) {
        final dm = state.dmList[convIndex];
        if ((dm.unreadCount ?? 0) > 0) {
          final updatedDm = dm.copyWith(unreadCount: 0);
          final updatedDmList = List<DmModel>.from(state.dmList);
          updatedDmList[convIndex] = updatedDm;

          state = state.copyWith(dmList: updatedDmList);
          await _conversationsRepo.updateUnreadCount(convId, 0);
        }
      }
    } else if (convType == ChatType.group) {
      final convIndex = state.groupList.indexWhere(
        (group) => group.conversationId == convId,
      );

      if (convIndex != -1) {
        final group = state.groupList[convIndex];
        if (group.unreadCount > 0) {
          final updatedGroup = GroupModel(
            conversationId: group.conversationId,
            title: group.title,
            members: group.members,
            metadata: group.metadata,
            lastMessageAt: group.lastMessageAt,
            role: group.role ?? 'member',
            unreadCount: 0,
            joinedAt: group.joinedAt,
          );
          final updatedGroupList = List<GroupModel>.from(state.groupList);
          updatedGroupList[convIndex] = updatedGroup;

          state = state.copyWith(groupList: updatedGroupList);
          await _conversationsRepo.updateUnreadCount(convId, 0);
        }
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
    int conversationId,
    ChatType convType,
  ) async {
    try {
      switch (action) {
        case 'pin':
          await _conversationsRepo.togglePin(conversationId, true);
          state = state.copyWith(
            pinnedChats: {...state.pinnedChats, conversationId},
          );
          break;
        case 'unpin':
          await _conversationsRepo.togglePin(conversationId, false);
          final newPinned = Set<int>.from(state.pinnedChats);
          newPinned.remove(conversationId);
          state = state.copyWith(pinnedChats: newPinned);
          break;
        case 'mute':
          await _conversationsRepo.toggleMute(conversationId, true);
          state = state.copyWith(
            mutedChats: {...state.mutedChats, conversationId},
          );
          break;
        case 'unmute':
          await _conversationsRepo.toggleMute(conversationId, false);
          final newMuted = Set<int>.from(state.mutedChats);
          newMuted.remove(conversationId);
          state = state.copyWith(mutedChats: newMuted);
          break;
        case 'favorite':
          await _conversationsRepo.toggleFavorite(conversationId, true);
          state = state.copyWith(
            favoriteChats: {...state.favoriteChats, conversationId},
          );
          break;
        case 'unfavorite':
          await _conversationsRepo.toggleFavorite(conversationId, false);
          final newFavorite = Set<int>.from(state.favoriteChats);
          newFavorite.remove(conversationId);
          state = state.copyWith(favoriteChats: newFavorite);
          break;
        case 'delete':
          if (convType == ChatType.dm) {
            final response = await _chatsServices.deleteDm(conversationId);
            if (response['success']) {
              final newDeleted = Set<int>.from(state.deletedChats);
              newDeleted.add(conversationId);
              final updatedConversations = state.dmList
                  .where((conv) => conv.conversationId != conversationId)
                  .toList();
              final newPinned = Set<int>.from(state.pinnedChats);
              newPinned.remove(conversationId);
              final newMuted = Set<int>.from(state.mutedChats);
              newMuted.remove(conversationId);
              final newFavorite = Set<int>.from(state.favoriteChats);
              newFavorite.remove(conversationId);

              state = state.copyWith(
                dmList: updatedConversations,
                deletedChats: newDeleted,
                pinnedChats: newPinned,
                mutedChats: newMuted,
                favoriteChats: newFavorite,
              );
              await _conversationsRepo.deleteConversation(conversationId);
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling chat action: $e');
    }
  }

  /// Set up WebSocket listeners
  void _setupWebSocketListeners() {
    _conversationAddedSubscription = _messageHandler.conversationAddedStream
        .listen(
          _handleConversationAdded,
          onError: (error) {
            debugPrint('❌ Conversation added stream error: $error');
          },
        );

    _typingSubscription = _messageHandler.typingStream.listen(
      _handleTypingMessage,
      onError: (error) {
        debugPrint('❌ Typing stream error: $error');
      },
    );

    _messageSubscription = _messageHandler.messageNewStream.listen(
      _handleNewMessage,
      onError: (error) {
        debugPrint('❌ Message stream error: $error');
      },
    );

    _messageAckSubscription = _messageHandler.messageAckStream.listen(
      _handleAckMessage,
      onError: (error) {
        debugPrint('❌ Message Ack stream error: $error');
      },
    );

    _pinSubscription = _messageHandler.messagePinStream.listen(
      _handlePinMessage,
      onError: (error) {
        debugPrint('❌ Pin stream error: $error');
      },
    );

    _messageDeleteSubscription = _messageHandler.messageDeleteStream.listen(
      _handleMessageDelete,
      onError: (error) {
        debugPrint('❌ Message delete stream error: $error');
      },
    );

    // Handle online status updates through the onlineStatusStream from messageHandler
    _onlineStatusSubscription = _messageHandler.onlineStatusStream.listen(
      _handleOnlineStatus,
      onError: (error) {
        debugPrint('❌ User status stream error: $error');
      },
    );
  }

  /// Handle typing message
  void _handleTypingMessage(TypingPayload message) {
    try {
      final conversationId = message.convId;

      if (message.isTyping) {
        final typingUsers = Map<int, List<int>>.from(state.typingConvUsers);
        final userIds = typingUsers[conversationId] ?? [];
        if (!userIds.contains(message.senderId)) {
          typingUsers[conversationId] = [...userIds, message.senderId];
        }

        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = Timer(const Duration(seconds: 2), () {
          final newTypingUsers = Map<int, List<int>>.from(
            state.typingConvUsers,
          );
          final updatedUserIds = newTypingUsers[conversationId] ?? [];
          updatedUserIds.remove(message.senderId);
          if (updatedUserIds.isEmpty) {
            newTypingUsers.remove(conversationId);
          } else {
            newTypingUsers[conversationId] = updatedUserIds;
          }
          state = state.copyWith(typingConvUsers: newTypingUsers);
          _typingTimers[conversationId] = null;
        });

        state = state.copyWith(typingConvUsers: typingUsers);
      } else {
        final newTypingUsers = Map<int, List<int>>.from(state.typingConvUsers);
        final userIds = newTypingUsers[conversationId] ?? [];
        userIds.remove(message.senderId);
        if (userIds.isEmpty) {
          newTypingUsers.remove(conversationId);
        } else {
          newTypingUsers[conversationId] = userIds;
        }
        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = null;

        state = state.copyWith(typingConvUsers: newTypingUsers);
      }
    } catch (e) {
      debugPrint('❌ Error handling typing message: $e');
    }
  }

  /// Handle new message
  Future<void> _handleNewMessage(ChatMessagePayload payload) async {
    try {
      final convId = payload.convId;
      final convType = payload.convType;

      // Insert message into local DB
      await _messageRepo.insertMessage(
        MessageModel(
          optimisticId: payload.optimisticId,
          canonicalId: payload.canonicalId,
          conversationId: payload.convId,
          senderId: payload.senderId,
          type: payload.msgType,
          body: payload.body,
          status: MessageStatusType.delivered,
          attachments: payload.attachments,
          metadata: payload.metadata,
          isStarred: false,
          isReplied: payload.replyToMessageId != null,
          isForwarded: false,
          isDeleted: false,
          sentAt: payload.sentAt.toIso8601String(),
        ),
      );

      int newDmUnreadCount = 0, newGrpUnreadCount = 0;

      // Handle DM messages
      if (convType == ChatType.dm) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.conversationId == convId,
        );

        if (convIndex == -1) return;

        final dm = state.dmList[convIndex];

        newDmUnreadCount = state.activeConvId == convId
            ? 0
            : (dm.unreadCount ?? 0) + 1;

        final updatedConversation = dm.copyWith(
          lastMessageId: payload.canonicalId,
          lastMessageType: payload.msgType.value,
          lastMessageBody: payload.body,
          lastMessageAt: payload.sentAt.toIso8601String(),
          unreadCount: newDmUnreadCount,
        );

        final updatedConversations = List<DmModel>.from(state.dmList);
        updatedConversations[convIndex] = updatedConversation;

        // Sort conversations
        final sortedConversations = await _filterAndSortConversations(
          updatedConversations,
        );

        state = state.copyWith(dmList: sortedConversations);
      }
      // Handle group messages
      else if (convType == ChatType.group) {
        final convIndex = state.groupList.indexWhere(
          (group) => group.conversationId == convId,
        );

        if (convIndex == -1) return;

        final group = state.groupList[convIndex];

        // Update group's last message
        newGrpUnreadCount = state.activeConvId == convId
            ? 0
            : group.unreadCount + 1;

        final updatedGroup = group.copyWith(
          lastMessageId: payload.canonicalId,
          lastMessageType: payload.msgType.value,
          lastMessageBody: payload.body,
          lastMessageAt: payload.sentAt.toIso8601String(),
          unreadCount: newGrpUnreadCount,
        );

        final updatedGroups = List<GroupModel>.from(state.groupList);
        updatedGroups[convIndex] = updatedGroup;

        // Sort groups
        final sortedGroups = await _filterAndSortGroupConversations(
          updatedGroups,
        );

        state = state.copyWith(groupList: sortedGroups);
      }

      // Update unreadCount and lastmessageID in DB
      await _conversationsRepo.updateUnreadCount(
        convId,
        convType == ChatType.dm ? newDmUnreadCount : newGrpUnreadCount,
      );

      if (payload.canonicalId != null) {
        await _conversationsRepo.updateLastMessage(
          convId,
          payload.canonicalId!,
        );
      } else {
        debugPrint(
          '❌ canonicalId is null, skipping last message update in DB for: \n opt message id: ${payload.optimisticId}, msg body : ${payload.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling new message: $e');
    }
  }

  /// Handle ack message
  Future<void> _handleAckMessage(ChatMessageAckPayload payload) async {
    try {
      // Update message status in local DB
      await _messageRepo.updateMessageId(
        payload.optimisticId,
        payload.canonicalId,
      );

      // Use msgStatus from payload if available, otherwise default to delivered
      final status = payload.msgStatus ?? MessageStatusType.delivered;
      await _messageRepo.updateMessageStatus(payload.canonicalId, status);
    } catch (e) {
      debugPrint('❌ Error handling ack message: $e');
    }
  }

  /// Handle reply message (now handled via messageNewStream with replyToMessageId)

  /// Handle reply message
  Future<void> _handlePinMessage(MessagePinPayload payload) async {
    try {
      final convId = payload.convId;
      final pinnedMessageId = payload.messageId;

      if (payload.isPinned) {
        // Update in local DB
        await _conversationsRepo.updatePinnedMessage(convId, pinnedMessageId);

        // Update in Provider state
        final dmIndex = state.dmList.indexWhere(
          (dm) => dm.conversationId == convId,
        );
        if (dmIndex != -1) {
          final dm = state.dmList[dmIndex];
          final updatedDm = dm.copyWith(pinnedMessageId: pinnedMessageId);
          final updatedDmList = List<DmModel>.from(state.dmList);
          updatedDmList[dmIndex] = updatedDm;
          state = state.copyWith(dmList: updatedDmList);
        }
      } else {
        // Unpin message in local DB
        await _conversationsRepo.updatePinnedMessage(convId, null);

        // Update in Provider state
        final dmIndex = state.dmList.indexWhere(
          (dm) => dm.conversationId == convId,
        );
        if (dmIndex != -1) {
          final dm = state.dmList[dmIndex];
          final updatedDm = dm.copyWith(pinnedMessageId: null);
          final updatedDmList = List<DmModel>.from(state.dmList);
          updatedDmList[dmIndex] = updatedDm;
          state = state.copyWith(dmList: updatedDmList);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling pin message: $e');
    }
  }

  /// Handle conversation added
  Future<void> _handleConversationAdded(NewConversationPayload message) async {
    try {
      final convId = message.convId;

      // Check if conversation is DM
      if (message.convType.value == 'dm') {
        // Check if conversation already exists
        final existingIndex = state.dmList.indexWhere(
          (conv) => conv.conversationId == convId,
        );
        if (existingIndex != -1) return;

        final newDM = DmModel(
          conversationId: convId,
          recipientId: message.createrId,
          recipientName: message.createrName,
          recipientPhone: message.createrPhone,
          isRecipientOnline: true,
          unreadCount: 0,
          isDeleted: false,
          isPinned: false,
          isFavorite: false,
          isMuted: false,
          createdAt: message.joinedAt.toIso8601String(),
        );

        final newConv = ConversationModel(
          id: convId,
          type: 'dm',
          createrId: message.createrId,
          unreadCount: 0,
          pinnedMessageId: null,
          isDeleted: false,
          isPinned: false,
          isFavorite: false,
          isMuted: false,
          createdAt: message.joinedAt.toIso8601String(),
        );

        // Store in local DB
        await _conversationsRepo.insertConversations([newConv]);

        final convMember = ConversationMemberModel(
          conversationId: newDM.conversationId,
          userId: newDM.recipientId,
          role: 'member',
          unreadCount: newDM.unreadCount ?? 0,
          joinedAt: newDM.createdAt,
        );
        await _conversationsMemberRepo.insertConversationMembers([convMember]);

        // Store user (recipient) in local DB
        final user = UserModel(
          id: newDM.recipientId,
          name: newDM.recipientName,
          phone: newDM.recipientPhone,
          profilePic: newDM.recipientProfilePic,
          isOnline: newDM.isRecipientOnline,
        );
        await _userRepo.insertUser(user);

        // Update dmList Provider state
        state = state.copyWith(dmList: [...state.dmList, newDM]);
      }

      if (message.convType.value == 'group') {
        final existingIndex = state.groupList.indexWhere(
          (conv) => conv.conversationId == convId,
        );
        if (existingIndex != -1) return;

        final newGroup = GroupModel(
          conversationId: convId,
          title: message.title ?? 'New Group',
          unreadCount: 0,
          isPinned: false,
          isFavorite: false,
          isMuted: false,
          joinedAt: message.joinedAt.toIso8601String(),
        );

        final newConv = ConversationModel(
          id: convId,
          type: 'group',
          createrId: message.createrId,
          unreadCount: 0,
          pinnedMessageId: null,
          isDeleted: false,
          isPinned: false,
          isFavorite: false,
          isMuted: false,
          createdAt: message.joinedAt.toIso8601String(),
        );

        // Store in local DB
        await _conversationsRepo.insertConversations([newConv]);

        // Update groupList Provider state
        final updatedGroups = [...state.groupList, newGroup];
        final sortedGroups = await _filterAndSortGroupConversations(
          updatedGroups,
        );
        state = state.copyWith(groupList: sortedGroups);
      }
    } catch (e) {
      debugPrint('❌ Error handling conversation added: $e');
    }
  }

  /// Handle online status update
  Future<void> _handleOnlineStatus(OnlineStatusPayload payload) async {
    try {
      final userId = payload.senderId;
      final isOnline = payload.status == 'online';

      // Update user online status in database
      await _userRepo.updateUserOnlineStatus(userId, isOnline);

      // Update UserStatusService
      _userStatusService.setUserOnlineStatus(userId, isOnline: isOnline);

      // Find and update all DMs where recipientId matches the userId
      bool hasChanges = false;
      final updatedDmList = state.dmList.map((dm) {
        if (dm.recipientId == userId && dm.isRecipientOnline != isOnline) {
          hasChanges = true;
          return dm.copyWith(isRecipientOnline: isOnline);
        }
        return dm;
      }).toList();

      // Only update state if there were actual changes
      if (hasChanges) {
        state = state.copyWith(dmList: updatedDmList);
      }
    } catch (e) {
      debugPrint('❌ Error handling online status: $e');
    }
  }

  /// Handle message delete
  Future<void> _handleMessageDelete(DeleteMessagePayload payload) async {
    try {
      final conversationId = payload.convId;
      final deletedMessageIds = payload.messageIds;

      if (deletedMessageIds.isEmpty) return;

      // remove messages from local DB
      await _messageRepo.permanentlyDeleteMessages(deletedMessageIds);

      final convFromDB = await _conversationsRepo.getConversationById(
        conversationId,
      );

      ChatType convType;

      if (convFromDB == null) {
        return;
      } else if (convFromDB.type == 'group') {
        convType = ChatType.group;
      } else if (convFromDB.type == 'community_group') {
        convType = ChatType.communityGroup;
      } else {
        convType = ChatType.dm;
      }

      if (convType == ChatType.dm) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.conversationId == conversationId,
        );
        if (convIndex == -1) return;
        final conversation = state.dmList[convIndex];

        final lastMessage = await _messageRepo.getLastMessage(conversationId);
        final updatedConversation = conversation.copyWith(
          lastMessageId: lastMessage?.id,
          lastMessageType: lastMessage?.type.value,
          lastMessageBody: lastMessage?.body,
          lastMessageAt: lastMessage?.sentAt,
        );

        final updatedConversations = List<DmModel>.from(state.dmList);
        updatedConversations[convIndex] = updatedConversation;

        state = state.copyWith(dmList: updatedConversations);
      }
      // Update for group conversations can be added here in future
      else if (convType == ChatType.group) {
        final convIndex = state.groupList.indexWhere(
          (conv) => conv.conversationId == conversationId,
        );
        if (convIndex == -1) return;
        final conversation = state.groupList[convIndex];

        final lastMessage = await _messageRepo.getLastMessage(conversationId);
        final updatedConversation = conversation.copyWith(
          lastMessageId: lastMessage?.id,
          lastMessageType: lastMessage?.type.value,
          lastMessageBody: lastMessage?.body,
          lastMessageAt: lastMessage?.sentAt,
        );

        final updatedConversations = List<GroupModel>.from(state.groupList);
        updatedConversations[convIndex] = updatedConversation;

        state = state.copyWith(groupList: updatedConversations);
      }
    } catch (e) {
      debugPrint('❌ Error handling message delete: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _typingSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageAckSubscription?.cancel();
    _pinSubscription?.cancel();
    _conversationAddedSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _onlineStatusSubscription?.cancel();

    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
  }
}
