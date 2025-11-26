import 'dart:async';
import 'package:amigo/db/repositories/conversation_member.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/messageStatus.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/group_model.dart';
import 'package:amigo/models/community_model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/chat.types.dart';
import 'package:amigo/types/socket.type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/user.service.dart';
import '../models/user_model.dart';
import '../services/socket/websocket_message_handler.dart';
import '../services/user_status_service.dart';
import '../api/chats.services.dart';
import '../api/groups.services.dart';
import '../utils/user.utils.dart';

/// State class for DM list
class ChatState {
  final List<DmModel> dmList;
  final List<GroupModel> groupList;
  final List<CommunityModel> communities;
  final List<CommunityGroupModel>? commGroupList;
  final bool isLoading;
  final int? activeConvId;
  final ChatType? activeConvType;
  final Map<int, Set<TypingUser>>
  typingConvUsers; // conversationId -> userIds[]
  // final Set<int> pinnedChats;
  // final Set<int> mutedChats;
  // final Set<int> favoriteChats;
  // final Set<int> deletedChats;
  final String searchQuery;

  ChatState({
    this.dmList = const [],
    this.groupList = const [],
    this.communities = const [],
    this.commGroupList,
    this.isLoading = true,
    this.activeConvId,
    this.activeConvType,
    Map<int, Set<TypingUser>>? typingConvUsers,
    // Set<int>? pinnedChats,
    // Set<int>? mutedChats,
    // Set<int>? favoriteChats,
    // Set<int>? deletedChats,
    this.searchQuery = '',
  }) : typingConvUsers = typingConvUsers ?? {};
  // pinnedChats = pinnedChats ?? {},
  // mutedChats = mutedChats ?? {},
  // favoriteChats = favoriteChats ?? {},
  // deletedChats = deletedChats ?? {};

  ChatState copyWith({
    List<DmModel>? dmList,
    List<GroupModel>? groupList,
    List<CommunityModel>? communities,
    List<CommunityGroupModel>? commGroupList,
    bool? isLoading,
    int? activeConvId,
    ChatType? activeConvType,
    Map<int, Set<TypingUser>>? typingConvUsers,
    // Set<int>? pinnedChats,
    // Set<int>? mutedChats,
    // Set<int>? favoriteChats,
    // Set<int>? deletedChats,
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
          : (activeConvId ?? this.activeConvId),
      activeConvType: clearActiveConversation
          ? null
          : (activeConvType ?? this.activeConvType),
      typingConvUsers: clearTypingConvs
          ? {}
          : (typingConvUsers ?? this.typingConvUsers),
      // pinnedChats: pinnedChats ?? this.pinnedChats,
      // mutedChats: mutedChats ?? this.mutedChats,
      // favoriteChats: favoriteChats ?? this.favoriteChats,
      // deletedChats: deletedChats ?? this.deletedChats,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get filtered conversations based on search query
  List<DmModel> get filteredDmList {
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
      return group.title.toLowerCase().contains(query);
      // group.members!.any(
      //   (member) => member.name.toLowerCase().contains(query),
      // );
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
  final GroupsService _groupsService = GroupsService();

  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();

  StreamSubscription<ConnectionStatus>? _onlineStatusSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<ChatMessageAckPayload>? _messageAckSubscription;
  StreamSubscription<MessagePinPayload>? _pinSubscription;
  StreamSubscription<NewConversationPayload>? _conversationAddedSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;
  StreamSubscription<JoinLeavePayload>? _joinConvSubscription;

  final Map<int, Timer?> _typingTimers = {};
  bool _listenersSetup = false;
  bool _isDisposed = false;

  @override
  ChatState build() {
    // Initialize web socket listeners
    if (!_listenersSetup) {
      _setupWebSocketListeners();
      _listenersSetup = true;
    }

    // Load conversations from local DB and then from server
    Future.microtask(() async {
      await loadConvsFromLocal();
      await loadConvsFromServer();
    });

    return ChatState();
  }

  /// Load conversations from local DB first
  Future<void> loadConvsFromLocal() async {
    state = state.copyWith(isLoading: true);
    try {
      final localDMs = await _conversationsRepo.getAllDmsWithRecipientInfo();
      final localGroups = await _conversationsRepo.getGroupListWithoutMembers();
      // final localCommGroups = await _conversationsRepo.getConversationsByType(
      //   ChatType.communityGroup,
      // );

      // Initialize Sets from loaded conversations
      // final pinnedChats = <int>{};
      // final mutedChats = <int>{};
      // final favoriteChats = <int>{};
      // final deletedChats = <int>{};
      //
      // for (final dm in localDMs) {
      //   if (dm.isPinned == true) pinnedChats.add(dm.conversationId);
      //   if (dm.isMuted == true) mutedChats.add(dm.conversationId);
      //   if (dm.isFavorite == true) favoriteChats.add(dm.conversationId);
      //   if (dm.isDeleted == true) deletedChats.add(dm.conversationId);
      // }

      if (localDMs.isNotEmpty) {
        final sortedDms = await filterAndSortConversations(localDMs);
        state = state.copyWith(
          dmList: sortedDms,
          isLoading: false,
          // pinnedChats: pinnedChats,
          // mutedChats: mutedChats,
          // favoriteChats: favoriteChats,
          // deletedChats: deletedChats,
        );
      }

      if (localGroups.isNotEmpty) {
        final sortedGroups = await filterAndSortGroupConversations(localGroups);
        state = state.copyWith(groupList: sortedGroups, isLoading: false);
      }
    } catch (e) {
      debugPrint('❌ Error loading from local DB: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load conversations from server
  Future<void> loadConvsFromServer({bool silent = true}) async {
    print(
      "--------------------------------------------------------------------------------",
    );
    print("loadConvsFromServer called");
    print(
      "--------------------------------------------------------------------------------",
    );
    debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 1');
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    final response = await _userService.getChatList('dm');
    if (response['success']) {
      debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 2');
      final List<dynamic> conversationsList = response['data'];

      if (conversationsList.isNotEmpty) {
        // Fetch all existing IDs from DB first
        final existingConvIds = await _conversationsRepo.getAllConversationIds(
          type: ChatType.dm,
        );
        final existingConvIdsSet = existingConvIds.toSet();
        debugPrint('Existing conversation IDs: ${existingConvIdsSet.length}');

        // Get all existing conversation members (conversationId, userId pairs)
        final existingMembers = await _conversationsMemberRepo
            .getAllConversationMembers();
        final existingMemberPairs = existingMembers
            .map((m) => '${m.conversationId}_${m.userId}')
            .toSet();
        debugPrint('Existing member pairs: ${existingMemberPairs.length}');

        // Get all existing user IDs
        final existingUsers = await _userRepo.getAllUsers();
        final existingUserIds = existingUsers.map((u) => u.id).toSet();
        debugPrint('Existing user IDs: ${existingUserIds.length}');

        final dmList = await _convertToDmListTypeAsync(conversationsList);
        final convList = await _convertToConversationsTypeAsync(
          conversationsList,
        );
        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 3');

        // Filter conversations to only include new ones
        final newConvs = convList
            .where((conv) => !existingConvIdsSet.contains(conv.id))
            .toList();
        debugPrint(
          'New conversations to insert: ${newConvs.length} out of ${convList.length}',
        );

        // Store only new conversations in local DB
        try {
          if (newConvs.isNotEmpty) {
            await _conversationsRepo.insertConversations(newConvs);
          }
        } catch (e) {
          debugPrint('❌ Error inserting DM conversations to DB: $e');
          // Continue even if DB insert fails
        }

        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 4');
        // Store conversation members in local DB - filter to only new ones
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

        // Filter to only new member pairs
        final newMembers = convMembers
            .where(
              (member) => !existingMemberPairs.contains(
                '${member.conversationId}_${member.userId}',
              ),
            )
            .toList();
        debugPrint(
          'New members to insert: ${newMembers.length} out of ${convMembers.length}',
        );

        try {
          if (newMembers.isNotEmpty) {
            await _conversationsMemberRepo.insertConversationMembersOnly(
              newMembers,
            );
          }
        } catch (e) {
          debugPrint('❌ Error inserting conversation members to DB: $e');
          // Continue even if DB insert fails
        }
        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 5');

        // Store user (recipient) in local DB - filter to only new ones
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

        // Filter to only new users
        final newUsers = users
            .where((user) => !existingUserIds.contains(user.id))
            .toList();
        debugPrint(
          'New users to insert: ${newUsers.length} out of ${users.length}',
        );

        try {
          if (newUsers.isNotEmpty) {
            await _userRepo.insertUsersOnly(newUsers);
          }
        } catch (e) {
          debugPrint('❌ Error inserting users to DB: $e');
          // Continue even if DB insert fails
        }

        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 6');
        // Load pin/mute/favorite status from local DB (these are local-only, not from server)
        // Query all DM conversations from DB to get their local pin/mute/favorite status
        final localConvs = await _conversationsRepo.getConversationsByType(
          ChatType.dm,
        );
        final convStatusMap = <int, ConversationModel>{};
        for (final conv in localConvs) {
          convStatusMap[conv.id] = conv;
        }

        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 7');

        // Merge with existing Sets to preserve group status
        // final currentPinnedChats = Set<int>.from(state.pinnedChats);
        // final currentMutedChats = Set<int>.from(state.mutedChats);
        // final currentFavoriteChats = Set<int>.from(state.favoriteChats);
        // final currentDeletedChats = Set<int>.from(state.deletedChats);

        // Populate Sets from local DB status for DMs
        // for (final dm in dmList) {
        //   final conv = convStatusMap[dm.conversationId];
        //   if (conv != null) {
        //     if (conv.isPinned == true) {
        //       currentPinnedChats.add(dm.conversationId);
        //     } else {
        //       currentPinnedChats.remove(dm.conversationId);
        //     }
        //     if (conv.isMuted == true) {
        //       currentMutedChats.add(dm.conversationId);
        //     } else {
        //       currentMutedChats.remove(dm.conversationId);
        //     }
        //     if (conv.isFavorite == true) {
        //       currentFavoriteChats.add(dm.conversationId);
        //     } else {
        //       currentFavoriteChats.remove(dm.conversationId);
        //     }
        //     if (conv.isDeleted == true) {
        //       currentDeletedChats.add(dm.conversationId);
        //     } else {
        //       currentDeletedChats.remove(dm.conversationId);
        //     }
        //   } else {
        //     // If conversation not found in DB, ensure it's not in Sets
        //     currentPinnedChats.remove(dm.conversationId);
        //     currentMutedChats.remove(dm.conversationId);
        //     currentFavoriteChats.remove(dm.conversationId);
        //     currentDeletedChats.remove(dm.conversationId);
        //   }
        // }

        // Update Provider state
        final sortedDms = await filterAndSortConversations(dmList);
        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 8');
        state = state.copyWith(
          dmList: sortedDms,
          isLoading: false,
          // pinnedChats: currentPinnedChats,
          // mutedChats: currentMutedChats,
          // favoriteChats: currentFavoriteChats,
          // deletedChats: currentDeletedChats,
        );
      }
      debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 9');
      // else {
      //   state = state.copyWith(dmList: [], isLoading: false);
      // }
    }

    // Load groups
    try {
      debugPrint('🔄 Loading groups from server...');
      final groupResponse = await _userService.getChatList('group');
      debugPrint('📦 Group response success: ${groupResponse['success']}');
      debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 10');

      if (groupResponse['success']) {
        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 11');
        final List<dynamic> groupsList = groupResponse['data'] is List
            ? groupResponse['data']
            : [];

        debugPrint('📊 Groups list length: ${groupsList.length}');

        List<GroupModel> groups = [];
        List<ConversationModel> convs = [];

        for (final group in groupsList) {
          try {
            if (group is Map<String, dynamic>) {
              final groupModel = GroupModel.fromJson(group);
              debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 12');
              groups.add(groupModel);

              if (groupModel.lastMessageId != null) {
                final metadataLastMsg = groupModel.metadata?.lastMessage!;
                // ------------------------------------------------------------------------------------
                // TODO: temporary type casting going on in here
                // ------------------------------------------------------------------------------------
                final msg = MessageModel(
                  conversationId: metadataLastMsg?.conversationId ?? 0,
                  canonicalId: metadataLastMsg?.id,
                  senderId: metadataLastMsg?.senderId ?? 0,
                  senderName: metadataLastMsg?.senderName,
                  type:
                      MessageType.fromString(metadataLastMsg?.type) ??
                      MessageType.text,
                  body: metadataLastMsg?.body ?? '',
                  attachments: metadataLastMsg?.attachmentData,
                  status: MessageStatusType.sent, // temp default value
                  sentAt:
                      metadataLastMsg?.createdAt ??
                      groupModel.joinedAt, // temp fall back
                );
                _messageRepo
                    .insertMessage(msg)
                    .catchError(
                      (e) => debugPrint('❌ Error inserting last message: $e'),
                    );
              }
              debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 13');

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

              debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 14');
            }
          } catch (e) {
            debugPrint('❌ Error processing group conversation: $e');
          }
        }

        // Fetch existing group conversation IDs from DB
        final existingGroupConvIds = await _conversationsRepo
            .getAllConversationIds(type: ChatType.group);
        final existingGroupConvIdsSet = existingGroupConvIds.toSet();
        debugPrint(
          'Existing group conversation IDs: ${existingGroupConvIdsSet.length}',
        );

        // Filter group conversations to only include new ones
        final newGroupConvs = convs
            .where((conv) => !existingGroupConvIdsSet.contains(conv.id))
            .toList();
        debugPrint(
          'New group conversations to insert: ${newGroupConvs.length} out of ${convs.length}',
        );

        // Store only new group conversations in local DB
        try {
          if (newGroupConvs.isNotEmpty) {
            await _conversationsRepo.insertConversations(newGroupConvs);
          }
        } catch (e) {
          debugPrint('❌ Error inserting group conversations to DB: $e');
          // Continue even if DB insert fails - we can still show groups from server
        }
        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 15');

        // Load pin/mute/favorite status from local DB for groups (these are local-only, not from server)
        final localGroupConvs = await _conversationsRepo.getConversationsByType(
          ChatType.group,
        );
        final groupConvStatusMap = <int, ConversationModel>{};
        for (final conv in localGroupConvs) {
          groupConvStatusMap[conv.id] = conv;
        }
        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 15');

        // Update groups with local status (pinned, muted, favorite)
        groups = groups.map((group) {
          final conv = groupConvStatusMap[group.conversationId];
          if (conv != null) {
            return group.copyWith(
              isPinned: conv.isPinned,
              isMuted: conv.isMuted,
              isFavorite: conv.isFavorite,
            );
          }
          return group;
        }).toList();

        debugPrint('>>>>>>>>>>>>>......>>>>>>>>>> checkpoint 16');
        // Update pinned/muted/favorite Sets with group status
        // final currentPinnedChats = Set<int>.from(state.pinnedChats);
        // final currentMutedChats = Set<int>.from(state.mutedChats);
        // final currentFavoriteChats = Set<int>.from(state.favoriteChats);
        // final currentDeletedChats = Set<int>.from(state.deletedChats);

        // for (final group in groups) {
        //   final conv = groupConvStatusMap[group.conversationId];
        //   if (conv != null) {
        //     if (conv.isPinned == true) {
        //       currentPinnedChats.add(group.conversationId);
        //     } else {
        //       currentPinnedChats.remove(group.conversationId);
        //     }
        //     if (conv.isMuted == true) {
        //       currentMutedChats.add(group.conversationId);
        //     } else {
        //       currentMutedChats.remove(group.conversationId);
        //     }
        //     if (conv.isFavorite == true) {
        //       currentFavoriteChats.add(group.conversationId);
        //     } else {
        //       currentFavoriteChats.remove(group.conversationId);
        //     }
        //     if (conv.isDeleted == true) {
        //       currentDeletedChats.add(group.conversationId);
        //     } else {
        //       currentDeletedChats.remove(group.conversationId);
        //     }
        //   } else {
        //     // If conversation not found in DB, ensure it's not in Sets
        //     currentPinnedChats.remove(group.conversationId);
        //     currentMutedChats.remove(group.conversationId);
        //     currentFavoriteChats.remove(group.conversationId);
        //     currentDeletedChats.remove(group.conversationId);
        //   }
        // }

        // Storing group members and metadata can be added here if needed
        // Sort groups
        debugPrint('✅ Processed ${groups.length} groups, sorting...');
        final sortedGroups = await filterAndSortGroupConversations(groups);
        debugPrint('✅ Sorted ${sortedGroups.length} groups, updating state...');
        state = state.copyWith(
          groupList: sortedGroups,
          isLoading: false,
          // pinnedChats: currentPinnedChats,
          // mutedChats: currentMutedChats,
          // favoriteChats: currentFavoriteChats,
          // deletedChats: currentDeletedChats,
        );
        debugPrint('✅ Groups state updated successfully');
      } else {
        // If group response failed, ensure loading state is cleared
        debugPrint(
          '❌ Failed to load groups: ${groupResponse['message'] ?? 'Unknown error'}',
        );
        state = state.copyWith(isLoading: false);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading groups from server: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      state = state.copyWith(isLoading: false);
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

                if (json['lastMessageId'] != null) {
                  final metadataLastMsg = json['metadata']['last_message'];
                  final msg = MessageModel.fromJson(metadataLastMsg);
                  _messageRepo
                      .insertMessage(msg)
                      .catchError(
                        (e) => debugPrint('❌ Error inserting last message: $e'),
                      );
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
                  createdAt: json['joinedAt'],
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

                if (json['lastMessageId'] != null) {
                  final metadataLastMsg = json['metadata']['last_message'];
                  final msg = MessageModel.fromJson(metadataLastMsg);
                  _messageRepo
                      .insertMessage(msg)
                      .catchError(
                        (e) => debugPrint('❌ Error inserting last message: $e'),
                      );
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
                  createdAt: json['joinedAt'],
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
  Future<List<DmModel>> filterAndSortConversations(
    List<DmModel> conversations,
  ) async {
    final filteredConversations = conversations
        .where((conv) => !(conv.isDeleted ?? false))
        .toList();

    filteredConversations.sort((a, b) {
      final aPinned = a.isPinned ?? false;
      final bPinned = b.isPinned ?? false;

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aHasMessage =
          a.lastMessageAt != null && a.lastMessageAt!.isNotEmpty;
      final bHasMessage =
          b.lastMessageAt != null && b.lastMessageAt!.isNotEmpty;

      // Chats with messages should come before chats without messages
      if (aHasMessage && !bHasMessage) return -1;
      if (!aHasMessage && bHasMessage) return 1;

      // Both have messages: sort by lastMessageAt (newest first)
      if (aHasMessage && bHasMessage) {
        return DateTime.parse(
          b.lastMessageAt!,
        ).compareTo(DateTime.parse(a.lastMessageAt!));
      }

      // Neither has messages: sort by createdAt (newest first)
      return DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt));
    });

    return filteredConversations;
  }

  /// Filter and sort group conversations
  Future<List<GroupModel>> filterAndSortGroupConversations(
    List<GroupModel> groups,
  ) async {
    final filteredGroups = groups;
    // .where((group) => !state.deletedChats.contains(group.conversationId))
    // .toList();

    filteredGroups.sort((a, b) {
      final aPinned = a.isPinned ?? false;
      final bPinned = b.isPinned ?? false;

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
      }

      return DateTime.parse(b.joinedAt).compareTo(DateTime.parse(a.joinedAt));
    });

    return filteredGroups;
  }

  /// Set active conversation
  void setActiveConversation(int? conversationId, ChatType? convType) {
    final shouldClear = conversationId == null;
    state = state.copyWith(
      activeConvId: conversationId,
      activeConvType: shouldClear ? null : convType,
      clearActiveConversation: shouldClear,
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
          final updatedGroup = group.copyWith(unreadCount: 0);
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

  /// Add a new group to the state (used when creating a group)
  Future<void> addNewGroup(GroupModel group) async {
    try {
      // Check if group already exists
      final existingIndex = state.groupList.indexWhere(
        (g) => g.conversationId == group.conversationId,
      );
      if (existingIndex != -1) {
        // Group already exists, update it instead
        final updatedGroups = List<GroupModel>.from(state.groupList);
        updatedGroups[existingIndex] = group;
        final sortedGroups = await filterAndSortGroupConversations(
          updatedGroups,
        );
        state = state.copyWith(groupList: sortedGroups);
        return;
      }

      // Add new group to the list
      final updatedGroups = [...state.groupList, group];
      final sortedGroups = await filterAndSortGroupConversations(updatedGroups);
      state = state.copyWith(groupList: sortedGroups);
    } catch (e) {
      debugPrint('❌ Error adding new group to state: $e');
    }
  }

  /// Add a new DM to the state (used when creating a DM conversation)
  Future<void> addNewDm(DmModel dm) async {
    try {
      // Check if DM already exists
      final existingIndex = state.dmList.indexWhere(
        (d) => d.conversationId == dm.conversationId,
      );
      if (existingIndex != -1) {
        // DM already exists, update it instead
        final updatedDms = List<DmModel>.from(state.dmList);
        updatedDms[existingIndex] = dm;
        final sortedDms = await filterAndSortConversations(updatedDms);
        state = state.copyWith(dmList: sortedDms);
        return;
      }

      // Add new DM to the list
      final updatedDms = [...state.dmList, dm];
      final sortedDms = await filterAndSortConversations(updatedDms);
      state = state.copyWith(dmList: sortedDms);
    } catch (e) {
      debugPrint('❌ Error adding new DM to state: $e');
    }
  }

  /// Handle chat action (pin, mute, favorite, delete)
  Future<void> handleChatAction(
    String action,
    int conversationId,
    ChatType convType,
  ) async {
    try {
      if (convType == ChatType.dm) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.conversationId == conversationId,
        );
        if (convIndex == -1) return;
        final conv = state.dmList[convIndex];

        DmModel? updatedConversation;

        switch (action) {
          case 'pin':
            await _conversationsRepo.togglePin(conversationId, true);

            updatedConversation = conv.copyWith(
              isPinned: conv.isPinned != null ? !conv.isPinned! : true,
            );

            // state = state.copyWith(
            //   pinnedChats: {...state.pinnedChats, conversationId},
            // );
            break;
          case 'unpin':
            await _conversationsRepo.togglePin(conversationId, false);
            updatedConversation = conv.copyWith(
              isPinned: conv.isPinned != null ? !conv.isPinned! : true,
            );

            // final newPinned = Set<int>.from(state.pinnedChats);
            // newPinned.remove(conversationId);
            // state = state.copyWith(pinnedChats: newPinned);
            break;
          case 'mute':
            await _conversationsRepo.toggleMute(conversationId, true);

            updatedConversation = conv.copyWith(
              isMuted: conv.isMuted != null ? !conv.isMuted! : true,
            );
            // state = state.copyWith(
            //   mutedChats: {...state.mutedChats, conversationId},
            // );
            break;
          case 'unmute':
            await _conversationsRepo.toggleMute(conversationId, false);

            updatedConversation = conv.copyWith(
              isMuted: conv.isMuted != null ? !conv.isMuted! : true,
            );

            // final newMuted = Set<int>.from(state.mutedChats);
            // newMuted.remove(conversationId);
            // state = state.copyWith(mutedChats: newMuted);
            break;
          case 'favorite':
            await _conversationsRepo.toggleFavorite(conversationId, true);

            updatedConversation = conv.copyWith(
              isFavorite: conv.isFavorite != null ? !conv.isFavorite! : true,
            );
            // state = state.copyWith(
            //   favoriteChats: {...state.favoriteChats, conversationId},
            // );
            break;
          case 'unfavorite':
            await _conversationsRepo.toggleFavorite(conversationId, false);

            updatedConversation = conv.copyWith(
              isFavorite: conv.isFavorite != null ? !conv.isFavorite! : true,
            );
            // final newFavorite = Set<int>.from(state.favoriteChats);
            // newFavorite.remove(conversationId);
            // state = state.copyWith(favoriteChats: newFavorite);
            break;
          case 'delete':
            final response = await _chatsServices.deleteDm(conversationId);
            if (response['success']) {
              // final newDeleted = Set<int>.from(state.deletedChats);
              // newDeleted.add(conversationId);
              // final updatedConversations = state.dmList
              //     .where((conv) => conv.conversationId != conversationId)
              //     .toList();
              // final newPinned = Set<int>.from(state.pinnedChats);
              // newPinned.remove(conversationId);
              // final newMuted = Set<int>.from(state.mutedChats);
              // newMuted.remove(conversationId);
              // final newFavorite = Set<int>.from(state.favoriteChats);
              // newFavorite.remove(conversationId);
              //
              // state = state.copyWith(
              //   dmList: updatedConversations,
              //   deletedChats: newDeleted,
              //   pinnedChats: newPinned,
              //   mutedChats: newMuted,
              //   favoriteChats: newFavorite,
              // );
              await _conversationsRepo.deleteConversation(conversationId);
            }
            break;
        }
        // update the provider with the approapriate action update
        if (updatedConversation != null) {
          final updatedConversations = List<DmModel>.from(state.dmList);
          updatedConversations[convIndex] = updatedConversation;

          // Sort conversations
          final sortedConversations = await filterAndSortConversations(
            updatedConversations,
          );

          state = state.copyWith(dmList: sortedConversations);
        }
      } else if (convType == ChatType.group) {
        final convIndex = state.groupList.indexWhere(
          (group) => group.conversationId == conversationId,
        );
        if (convIndex == -1) return;
        final group = state.groupList[convIndex];

        GroupModel? updatedGroup;

        switch (action) {
          case 'pin':
            await _conversationsRepo.togglePin(conversationId, true);

            updatedGroup = group.copyWith(
              isPinned: group.isPinned != null ? !group.isPinned! : true,
            );
            break;
          case 'unpin':
            await _conversationsRepo.togglePin(conversationId, false);
            updatedGroup = group.copyWith(
              isPinned: group.isPinned != null ? !group.isPinned! : true,
            );
            break;
          case 'mute':
            await _conversationsRepo.toggleMute(conversationId, true);

            updatedGroup = group.copyWith(
              isMuted: group.isMuted != null ? !group.isMuted! : true,
            );
            break;
          case 'unmute':
            await _conversationsRepo.toggleMute(conversationId, false);

            updatedGroup = group.copyWith(
              isMuted: group.isMuted != null ? !group.isMuted! : true,
            );
            break;
          case 'favorite':
            await _conversationsRepo.toggleFavorite(conversationId, true);

            updatedGroup = group.copyWith(
              isFavorite: group.isFavorite != null ? !group.isFavorite! : true,
            );
            break;
          case 'unfavorite':
            await _conversationsRepo.toggleFavorite(conversationId, false);

            updatedGroup = group.copyWith(
              isFavorite: group.isFavorite != null ? !group.isFavorite! : true,
            );
            break;
          case 'delete':
            final response = await _groupsService.deleteGroup(conversationId);
            if (response['success']) {
              await _conversationsRepo.deleteConversation(conversationId);
            }
            break;
        }
        // update the provider with the approapriate action update
        if (updatedGroup != null) {
          final updatedGroups = List<GroupModel>.from(state.groupList);
          updatedGroups[convIndex] = updatedGroup;

          // Sort groups
          final sortedGroups = await filterAndSortGroupConversations(
            updatedGroups,
          );

          state = state.copyWith(groupList: sortedGroups);
        }
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
      handleMessageDelete,
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

    _joinConvSubscription = _messageHandler.joinConversationStream.listen(
      _handleConversationJoin,
      onError: (error) {
        debugPrint('❌ Conversation join/leave stream error: $error');
      },
    );
  }

  /// Handle typing message
  void _handleTypingMessage(TypingPayload message) {
    try {
      final conversationId = message.convId;

      if (message.isTyping) {
        // Cancel existing timer for this conversation
        _typingTimers[conversationId]?.cancel();

        // Get the currently typing users
        final typingUsers = Map<int, Set<TypingUser>>.from(
          state.typingConvUsers,
        );

        // Create a new typing user
        final newtu = TypingUser(
          userId: message.senderId,
          userName: message.senderName,
          userPfp: message.senderPfp,
          convId: message.convId,
        );

        // Add it to the typing map
        if (typingUsers.containsKey(conversationId)) {
          // Remove existing entry for this user if present (to avoid duplicates)
          typingUsers[conversationId]!.removeWhere(
            (u) => u.userId == message.senderId,
          );
          typingUsers[conversationId]!.add(newtu);
        } else {
          typingUsers[conversationId] = {newtu};
        }

        // Immediately update state to show typing indicator
        state = state.copyWith(typingConvUsers: typingUsers);

        // Set timer to remove user after 2 seconds of inactivity
        _typingTimers[conversationId] = Timer(const Duration(seconds: 2), () {
          final updatedTypingUsers = Map<int, Set<TypingUser>>.from(
            state.typingConvUsers,
          );

          if (updatedTypingUsers.containsKey(conversationId)) {
            updatedTypingUsers[conversationId]!.removeWhere(
              (u) => u.userId == message.senderId,
            );

            // Remove the conversation entry if no one is typing
            if (updatedTypingUsers[conversationId]!.isEmpty) {
              updatedTypingUsers.remove(conversationId);
            }
          }

          state = state.copyWith(typingConvUsers: updatedTypingUsers);
          _typingTimers[conversationId] = null;
        });
      } else {
        // User stopped typing - remove immediately
        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = null;

        final typingUsers = Map<int, Set<TypingUser>>.from(
          state.typingConvUsers,
        );

        if (typingUsers.containsKey(conversationId)) {
          typingUsers[conversationId]!.removeWhere(
            (u) => u.userId == message.senderId,
          );

          // Remove the conversation entry if no one is typing
          if (typingUsers[conversationId]!.isEmpty) {
            typingUsers.remove(conversationId);
          }

          state = state.copyWith(typingConvUsers: typingUsers);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling typing message: $e');
    }
  }

  /// Handle new message
  Future<void> _handleNewMessage(ChatMessagePayload payload) async {
    debugPrint('✅ recieved new message at chat provider');
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
        final sortedConversations = await filterAndSortConversations(
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
        final sortedGroups = await filterAndSortGroupConversations(
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
    print('payload: $payload');
    try {
      // Update message status in local DB
      await _messageRepo.updateMessageId(
        payload.optimisticId,
        payload.canonicalId,
      );

      // Determine status from delivered_to and read_by arrays
      // Default to delivered if arrays are not available
      MessageStatusType status = MessageStatusType.delivered;
      final currentUser = await UserUtils().getUserDetails();
      if (currentUser != null) {
        final currentUserId = currentUser.id;
        if (payload.readBy != null && payload.readBy!.contains(currentUserId)) {
          status = MessageStatusType.read;
        } else if (payload.deliveredTo != null &&
            payload.deliveredTo!.contains(currentUserId)) {
          status = MessageStatusType.delivered;
        } else {
          status = MessageStatusType.sent;
        }
      }
      await _messageRepo.updateMessageStatus(payload.canonicalId, status);

      await _conversationsRepo.updateLastMessageId(
        payload.convId,
        payload.canonicalId,
      );

      await _messageStatusRepo.updateMessageId(
        payload.optimisticId,
        payload.canonicalId,
      );

      // update the sended message in the status table with deliveredAt timestamp
      await _messageStatusRepo.updateDeliveredAt(
        messageId: payload.canonicalId,
        deliveredAt: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('❌ Error handling ack message: $e');
    }
  }

  // updateLast messge on sending own message from messaging page
  void updateLastMessageOnSendingOwnMessage(
    int conversationId,
    MessageModel lastMessage,
  ) async {
    try {
      // Ensure we have a valid message ID (use optimistic ID if canonical is not available yet)
      final messageId = lastMessage.canonicalId ?? lastMessage.optimisticId;

      if (messageId == null) {
        return;
      }

      // Update database with the message ID
      await _conversationsRepo.updateLastMessage(conversationId, messageId);

      final convType = await _conversationsRepo.getConversationTypeById(
        conversationId,
      );

      if (convType == null) {
        return;
      }

      if (convType == ChatType.dm.value) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.conversationId == conversationId,
        );
        if (convIndex != -1) {
          final dm = state.dmList[convIndex];
          final updatedDm = dm.copyWith(
            lastMessageId: messageId,
            lastMessageType: lastMessage.type.value,
            lastMessageBody: lastMessage.body,
            lastMessageAt: lastMessage.sentAt,
          );
          final updatedDmList = List<DmModel>.from(state.dmList);
          updatedDmList[convIndex] = updatedDm;

          // Sort conversations after updating last message
          final sortedConversations = await filterAndSortConversations(
            updatedDmList,
          );

          // Update state - wrap in try-catch to handle defunct widget errors gracefully
          try {
            state = state.copyWith(dmList: sortedConversations);
          } catch (e) {
            // Still update state even if there's an error - the state should be correct
            state = state.copyWith(dmList: sortedConversations);
          }
        } else {
          debugPrint('❌ DM conversation not found in list: $conversationId');
        }
      } else if (convType == ChatType.group.value) {
        final convIndex = state.groupList.indexWhere(
          (group) => group.conversationId == conversationId,
        );
        if (convIndex != -1) {
          final group = state.groupList[convIndex];

          // Update metadata.lastMessage as well (UI reads from this)
          GroupMetadata? updatedMetadata;
          final updatedLastMessage = GroupLastMessage(
            id: messageId,
            body: lastMessage.body ?? '',
            type: lastMessage.type.value,
            senderId: lastMessage.senderId,
            senderName: lastMessage.senderName ?? 'You',
            createdAt: lastMessage.sentAt,
            conversationId: conversationId,
            attachmentData: lastMessage.attachments,
          );

          if (group.metadata != null) {
            // Preserve existing metadata values
            updatedMetadata = group.metadata!.copyWith(
              lastMessage: updatedLastMessage,
            );
          } else {
            // Create new metadata if it doesn't exist
            updatedMetadata = GroupMetadata(
              lastMessage: updatedLastMessage,
              totalMessages: 0,
              createdBy: 0,
            );
          }

          final updatedGroup = group.copyWith(
            lastMessageId: messageId,
            lastMessageType: lastMessage.type.value,
            lastMessageBody: lastMessage.body ?? '',
            lastMessageAt: lastMessage.sentAt,
            metadata: updatedMetadata,
          );

          final updatedGroups = List<GroupModel>.from(state.groupList);
          updatedGroups[convIndex] = updatedGroup;

          // Sort groups after updating last message
          final sortedGroups = await filterAndSortGroupConversations(
            updatedGroups,
          );

          // Update state - wrap in try-catch to handle defunct widget errors gracefully
          try {
            state = state.copyWith(groupList: sortedGroups);
          } catch (e) {
            // Still update state even if there's an error - the state should be correct
            state = state.copyWith(groupList: sortedGroups);
          }
        } else {
          debugPrint('❌ Group conversation not found in list: $conversationId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating last message on sending own message: $e');
    }
  }

  /// Update pinned message in provider state when pinning/unpinning locally
  void updatePinnedMessageInState(
    int conversationId,
    int? pinnedMessageId,
  ) async {
    try {
      // Update database
      await _conversationsRepo.updatePinnedMessage(
        conversationId,
        pinnedMessageId,
      );

      final convType = await _conversationsRepo.getConversationTypeById(
        conversationId,
      );

      if (convType == null) {
        return;
      }

      if (convType == ChatType.dm.value) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.conversationId == conversationId,
        );
        if (convIndex != -1) {
          final dm = state.dmList[convIndex];
          final updatedDm = dm.copyWith(pinnedMessageId: pinnedMessageId);
          final updatedDmList = List<DmModel>.from(state.dmList);
          updatedDmList[convIndex] = updatedDm;
          state = state.copyWith(dmList: updatedDmList);
        }
      } else if (convType == ChatType.group.value) {
        final convIndex = state.groupList.indexWhere(
          (group) => group.conversationId == conversationId,
        );
        if (convIndex != -1) {
          final group = state.groupList[convIndex];
          final updatedGroup = group.copyWith(pinnedMessageId: pinnedMessageId);
          final updatedGroupList = List<GroupModel>.from(state.groupList);
          updatedGroupList[convIndex] = updatedGroup;
          state = state.copyWith(groupList: updatedGroupList);
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating pinned message in state: $e');
    }
  }

  /// Handle reply message (now handled via messageNewStream with replyToMessageId)

  /// Handle reply message
  Future<void> _handlePinMessage(MessagePinPayload payload) async {
    try {
      final convId = payload.convId;
      final pinnedMessageId = payload.pin ? payload.messageId : null;

      // Update in local DB
      await _conversationsRepo.updatePinnedMessage(convId, pinnedMessageId);

      // Update in Provider state - Check DM list first
      final dmIndex = state.dmList.indexWhere(
        (dm) => dm.conversationId == convId,
      );
      if (dmIndex != -1) {
        final dm = state.dmList[dmIndex];
        final updatedDm = dm.copyWith(pinnedMessageId: pinnedMessageId);
        final updatedDmList = List<DmModel>.from(state.dmList);
        updatedDmList[dmIndex] = updatedDm;
        state = state.copyWith(dmList: updatedDmList);
        return;
      }

      // Check Group list if not found in DM list
      final groupIndex = state.groupList.indexWhere(
        (group) => group.conversationId == convId,
      );
      if (groupIndex != -1) {
        final group = state.groupList[groupIndex];
        final updatedGroup = group.copyWith(pinnedMessageId: pinnedMessageId);
        final updatedGroupList = List<GroupModel>.from(state.groupList);
        updatedGroupList[groupIndex] = updatedGroup;
        state = state.copyWith(groupList: updatedGroupList);
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
          title: message.title,
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

        // Store conversation members in local DB
        if (message.members != null && message.members!.isNotEmpty) {
          final convMembers = message.members!
              .map(
                (member) => ConversationMemberModel(
                  conversationId: newGroup.conversationId,
                  userId: member.userId,
                  role: member.role.value,
                  unreadCount: 0,
                  joinedAt: member.joinedAt.toIso8601String(),
                ),
              )
              .toList();
          await _conversationsMemberRepo.insertConversationMembers(convMembers);
        }

        // Update groupList Provider state
        final updatedGroups = [...state.groupList, newGroup];
        final sortedGroups = await filterAndSortGroupConversations(
          updatedGroups,
        );
        state = state.copyWith(groupList: sortedGroups);
      }
    } catch (e) {
      debugPrint('❌ Error handling conversation added: $e');
    }
  }

  /// Handle online status update
  Future<void> _handleOnlineStatus(ConnectionStatus payload) async {
    try {
      final userId = payload.senderId;
      final isOnline = payload.status == 'foreground';

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
  Future<void> handleMessageDelete(DeleteMessagePayload payload) async {
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

  /// Handle conversation join/leave events
  Future<void> _handleConversationJoin(JoinLeavePayload payload) async {
    try {
      await _messageStatusRepo.markAllAsReadByConversationAndUser(
        conversationId: payload.convId,
        userId: payload.userId,
      );
    } catch (e) {
      debugPrint('❌ Error handling conversation join/leave event: $e');
    }
  }

  /// Clear all state (used during logout)
  void clearAllState() {
    state = state.copyWith(
      dmList: [],
      groupList: [],
      communities: [],
      commGroupList: null,
      isLoading: false,
      clearActiveConversation: true,
      clearTypingConvs: true,
      searchQuery: '',
    );
  }

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return; // Prevent multiple dispose calls
    _isDisposed = true;

    _typingSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageAckSubscription?.cancel();
    _pinSubscription?.cancel();
    _joinConvSubscription?.cancel();
    _conversationAddedSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _joinConvSubscription?.cancel();

    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
  }
}
