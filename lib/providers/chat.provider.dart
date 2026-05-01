import 'dart:async';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/db/sqlite.db.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/chat.types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../db/repositories/conversation-member.repo.dart';
import '../db/repositories/message-status.repo.dart';
import '../models/community.model.dart';
import '../models/group.model.dart';
import '../models/user.model.dart';
import '../services/message/message_gc.service.dart';
import '../services/message/status-ack.service.dart';
import '../services/socket/ws-message.handler.dart';
import '../services/socket/transport.manager.dart';
import '../services/user-info-cache.service.dart';
import '../services/user-status.service.dart';
import '../types/socket.types.dart';
import '../utils/user.utils.dart';

/// Overall transport/connectivity status exposed to the UI.
enum TransportStatus { connected, polling, disconnected }

/// State class for DM list
class ChatState {
  final List<DmModel> dmList;
  final List<GroupModel> groupList;
  final List<CommunityModel> communities;
  final List<CommunityGroupModel>? commGroupList;
  final bool isLoading;
  final String? activeConvId;
  final ChatType? activeConvType;
  final Map<String, Set<TypingUser>> typingConvUsers; // convId -> userIds[]
  final Map<String, int>? mediaUploadProgress; // messageId -> upload progress %
  final String searchQuery;
  final TransportStatus transportStatus;
  final DateTime? lastSyncedAt;

  ChatState({
    this.dmList = const [],
    this.groupList = const [],
    this.communities = const [],
    this.commGroupList,
    this.isLoading = true,
    this.activeConvId,
    this.activeConvType,
    this.typingConvUsers = const {},
    this.mediaUploadProgress,
    this.searchQuery = '',
    this.transportStatus = TransportStatus.disconnected,
    this.lastSyncedAt,
  });

  ChatState copyWith({
    List<DmModel>? dmList,
    List<GroupModel>? groupList,
    List<CommunityModel>? communities,
    List<CommunityGroupModel>? commGroupList,
    bool? isLoading,
    String? activeConvId,
    ChatType? activeConvType,
    Map<String, Set<TypingUser>>? typingConvUsers,
    Map<String, int>? mediaUploadProgress,
    String? searchQuery,
    TransportStatus? transportStatus,
    DateTime? lastSyncedAt,
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
      mediaUploadProgress: mediaUploadProgress ?? this.mediaUploadProgress,
      searchQuery: searchQuery ?? this.searchQuery,
      transportStatus: transportStatus ?? this.transportStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
      final lastMessageBody = conversation.lastMsgBody?.toLowerCase() ?? '';
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

  int get unreadDmCount {
    // Dedupe by chatId — the in-memory dmList can briefly contain duplicates
    // when WS replay (`conversation:new`) races the initial load. The list
    // sorter scrubs them on the next state update; this guard makes the badge
    // correct in the meantime.
    final seen = <String>{};
    return dmList
        .where((dm) => (dm.unreadCount ?? 0) > 0 && seen.add(dm.chatId))
        .length;
  }

  int get unreadGroupCount {
    final seen = <String>{};
    return groupList
        .where((group) => group.unreadCount > 0 && seen.add(group.chatId))
        .length;
  }

  bool isUserOnline(String recipientId, String convId) {
    for (final dm in dmList) {
      if (dm.chatId == convId && dm.recipientId == recipientId) {
        return dm.isRecipientOnline;
      }
    }
    return false;
  }
}

/// Provider for chat state (DM, Groups, Community Groups)
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);

class ChatNotifier extends Notifier<ChatState> {
  final apiService = ApiService();
  final UserRepository _userRepo = UserRepository();
  final ConversationRepository _conversationsRepo = ConversationRepository();
  final MessageRepository _messageRepo = MessageRepository();
  final ConversationMemberRepository _conversationsMemberRepo =
      ConversationMemberRepository();
  final WebSocketMessageHandler _messageHandler = WebSocketMessageHandler();
  final UserStatusService _userStatusService = UserStatusService();
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();
  final TransportManager _transportManager = TransportManager();

  StreamSubscription<ConnectionStatusPayload>? _onlineStatusSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<MessageSentAckPayload>? _messageSentAckSubscription;
  StreamSubscription<MessageStatusAckPayload>? _messageStatusAckSubscription;
  StreamSubscription<MessagePinPayload>? _pinSubscription;
  StreamSubscription<NewConversationPayload>? _conversationAddedSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;
  StreamSubscription<MessageReactPayload>? _messageReactSubscription;
  StreamSubscription<ConvJoinPayload>? _joinConvSubscription;
  StreamSubscription<ConversationActionPayload>?
  _conversationActionSubscription;

  final Map<String, Timer?> _typingTimers = {};
  bool _listenersSetup = false;
  bool _isDisposed = false;

  @override
  ChatState build() {
    // Initialize web socket listeners
    if (!_listenersSetup) {
      _setupWebSocketListeners();
      _listenersSetup = true;
    }

    // Start the optimistic message cleanup timer
    // _messageRepo.startCleanupTimer();

    // Set current user for StatusAckService
    Future.microtask(() async {
      final user = await UserUtils().getUserDetails();
      if (user != null) {
        StatusAckService.instance.setCurrentUserId(user.id);
        debugPrint('[ChatProvider] StatusAckService userId set: ${user.id}');
      }
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

      if (localDMs.isNotEmpty) {
        final sortedDms = await filterAndSortConversations(localDMs);
        state = state.copyWith(dmList: sortedDms, isLoading: false);
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

  /// Called when the app comes back to the foreground.
  /// Re-attempts WS connection and pulls any messages missed while in background.
  Future<void> syncOnResume() async {
    debugPrint('[CHAT-PROVIDER] App resumed — syncing missed messages');
    state = state.copyWith(lastSyncedAt: DateTime.now());

    // Attempt WS reconnect; poll immediately for gap-fill regardless
    if (!_transportManager.isConnected) {
      _transportManager.reconnect();
    }
    // pollNow triggers an immediate poll to pull missed messages
    _transportManager.pollNow();

    // Run GC to reconcile any stalled outbound messages
    Future.microtask(() => MessageGarbageCollector.instance.runGC());

    // Also refresh conversation list from server
    // await loadConvsFromServer(silent: true);
  }

  /// Called when the app goes to background.
  void onAppBackground() {
    debugPrint('[CHAT-PROVIDER] App backgrounded');
    state = state.copyWith(transportStatus: TransportStatus.disconnected);
  }

  /// Load conversations from server
  Future<void> loadConvsFromServer({bool silent = true}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    // Load groups
    try {
      debugPrint('🔄 Loading DMs from server...');
      final response = await apiService.user.getChatList('dm');
      if (response.isSuccess) {
        final List<dynamic> conversationsList = response.data as List<dynamic>;

        if (conversationsList.isNotEmpty) {
          // Fetch all existing IDs from DB first
          final existingConvIds = await _conversationsRepo
              .getAllConversationIds(type: ChatType.dm);
          final existingConvIdsSet = existingConvIds.toSet();
          // debugPrint('Existing conversation IDs: ${existingConvIdsSet.length}');

          // Get all existing conversation members (conversationId, userId pairs)
          final existingMembers = await _conversationsMemberRepo
              .getAllConversationMembers();
          final existingMemberPairs = existingMembers
              .map((m) => '${m.chatId}_${m.userId}')
              .toSet();
          // debugPrint('Existing member pairs: ${existingMemberPairs.length}');

          // Get all existing user IDs
          final existingUsers = await _userRepo.getAllUsers();
          final existingUserIds = existingUsers.map((u) => u.id).toSet();
          // debugPrint('Existing user IDs: ${existingUserIds.length}');

          final dmList = await _convertToDmListTypeAsync(conversationsList);
          final convList = await _convertToConversationsTypeAsync(
            conversationsList,
          );

          final serverConvIds = convList.map((c) => c.id).toSet();
          final deletedDmIds = existingConvIdsSet
              .where((id) => !serverConvIds.contains(id))
              .toList();
          final newConvs = convList
              .where((conv) => !existingConvIdsSet.contains(conv.id))
              .toList();

          final convMembers = dmList
              .map(
                (dm) => ConversationMemberModel(
                  chatId: dm.chatId,
                  userId: dm.recipientId,
                  role: 'member',
                  joinedAt: dm.createdAt,
                ),
              )
              .toList();
          final newMembers = convMembers
              .where(
                (member) => !existingMemberPairs.contains(
                  '${member.chatId}_${member.userId}',
                ),
              )
              .toList();

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
          final newUsers = users
              .where((user) => !existingUserIds.contains(user.id))
              .toList();

          // Enrich DMs with local user display names (includes username from contacts)
          final enrichedDmList = await UserUtils().enrichDmsWithDisplayNames(
            dmList,
          );

          // Single Drift transaction → one watch emit, no partial loads.
          // Order: users + members first (referenced by DM enrichment), then
          // conversations, then deletes, then unread reconcile.
          try {
            await SqliteDatabase.instance.database.transaction(() async {
              if (newUsers.isNotEmpty) {
                await _userRepo.insertUsersOnly(newUsers);
              }
              if (newMembers.isNotEmpty) {
                await _conversationsMemberRepo.insertConversationMembersOnly(
                  newMembers,
                );
              }
              for (final id in deletedDmIds) {
                await _conversationsRepo.deleteConversation(id);
              }
              if (newConvs.isNotEmpty) {
                await _conversationsRepo.insertConversations(newConvs);
              }
              for (final dm in enrichedDmList) {
                await _conversationsRepo.updateUnreadCount(
                  dm.chatId,
                  dm.unreadCount ?? 0,
                );
              }
            });
            if (deletedDmIds.isNotEmpty) {
              debugPrint(
                '🗑️ Removed ${deletedDmIds.length} deleted DMs from local DB',
              );
            }
          } catch (e) {
            debugPrint('❌ Error reconciling DM conversations to DB: $e');
          }

          // Update Provider state
          final sortedDms = await filterAndSortConversations(enrichedDmList);
          debugPrint('✅ Processed ${sortedDms.length} DMs');
          state = state.copyWith(dmList: sortedDms, isLoading: false);
          debugPrint('✅ DMs state updated successfully');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading DMs from server: $e');
      state = state.copyWith(isLoading: false);
    }

    // Load groups
    try {
      debugPrint('🔄 Loading groups from server...');
      final groupResponse = await apiService.user.getChatList('group');

      if (groupResponse.isSuccess) {
        final List<dynamic> groupsList = groupResponse.data as List<dynamic>;

        List<GroupModel> groups = [];
        List<ConversationModel> convs = [];
        final List<MessageModel> groupLastMessagesToInsert = [];

        for (final group in groupsList) {
          try {
            if (group is Map<String, dynamic>) {
              final groupModel = GroupModel.fromJson(
                GroupModel.normalizeApiResponse(group),
              );
              // Redis-enriched last message for groups
              final lastMsg = group['lastMessage'] is Map<String, dynamic>
                  ? group['lastMessage'] as Map<String, dynamic>
                  : null;

              if (lastMsg != null && lastMsg['id'] != null) {
                groupLastMessagesToInsert.add(MessageModel(
                  id: lastMsg['id'].toString(),
                  chatId: groupModel.chatId,
                  senderId: lastMsg['sender_id']?.toString() ?? '',
                  type: MessageType.fromString(lastMsg['type']?.toString()) ?? MessageType.text,
                  body: lastMsg['body']?.toString() ?? '',
                  sentAt: lastMsg['sent_at']?.toString() ?? DateTime.now().toIso8601String(),
                ));
              }

              final enrichedGroup = groupModel.copyWith(
                lastMsgId: lastMsg?['id']?.toString() ?? groupModel.lastMsgId,
                lastMsgBody: lastMsg?['body']?.toString() ?? groupModel.lastMsgBody,
                lastMsgType: lastMsg?['type']?.toString() ?? groupModel.lastMsgType,
                lastMsgAt: lastMsg?['sent_at']?.toString() ?? groupModel.lastMsgAt,
              );
              groups.add(enrichedGroup);

              final convModel = ConversationModel(
                id: enrichedGroup.chatId,
                type: "group",
                title: enrichedGroup.title,
                createrId: group['createrId']?.toString(),
                unreadCount: enrichedGroup.unreadCount,
                lastMsgId: enrichedGroup.lastMsgId,
                pinnedMsgId: enrichedGroup.pinnedMsgId,
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

        // Fetch existing group conversation IDs from DB
        final existingGroupConvIds = await _conversationsRepo
            .getAllConversationIds(type: ChatType.group);
        final existingGroupConvIdsSet = existingGroupConvIds.toSet();

        final serverGroupConvIds = convs.map((c) => c.id).toSet();
        final deletedGroupIds = existingGroupConvIdsSet
            .where((id) => !serverGroupConvIds.contains(id))
            .toList();
        final newGroupConvs = convs
            .where((conv) => !existingGroupConvIdsSet.contains(conv.id))
            .toList();

        // Run reconcile (delete-gone + insert-messages + insert-chats +
        // unread-update) inside a single Drift transaction so the watch
        // streams emit ONCE with consistent state. Critical: messages
        // first, then chats — the chats row references lastMsgId, and
        // watchGroupConversations joins on it. Without this ordering the
        // first emit shows empty last-message bodies until a follow-up
        // emit lands with the messages.
        try {
          await SqliteDatabase.instance.database.transaction(() async {
            if (groupLastMessagesToInsert.isNotEmpty) {
              await _messageRepo.insertMessages(groupLastMessagesToInsert);
            }
            for (final id in deletedGroupIds) {
              await _conversationsRepo.deleteConversation(id);
            }
            if (newGroupConvs.isNotEmpty) {
              await _conversationsRepo.insertConversations(newGroupConvs);
            }
            for (final group in groups) {
              await _conversationsRepo.updateUnreadCount(
                group.chatId,
                group.unreadCount,
              );
            }
          });
          if (deletedGroupIds.isNotEmpty) {
            debugPrint(
              '🗑️ Removed ${deletedGroupIds.length} deleted groups from local DB',
            );
          }
        } catch (e) {
          debugPrint('❌ Error reconciling group conversations to DB: $e');
        }

        // Load pin/mute/favorite status from local DB for groups (these are local-only, not from server)
        final localGroupConvs = await _conversationsRepo.getConversationsByType(
          ChatType.group,
        );
        final groupConvStatusMap = <String, ConversationModel>{};
        for (final conv in localGroupConvs) {
          groupConvStatusMap[conv.id] = conv;
        }

        // Update groups with local status (pinned, muted, favorite)
        groups = groups.map((group) {
          final conv = groupConvStatusMap[group.chatId];
          if (conv != null) {
            return group.copyWith(
              isPinned: conv.isPinned,
              isMuted: conv.isMuted,
              isFavorite: conv.isFavorite,
            );
          }
          return group;
        }).toList();

        // Sort groups
        final sortedGroups = await filterAndSortGroupConversations(groups);
        debugPrint('✅ Processed ${groups.length} groups');
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
        debugPrint('❌ Failed to load groups: ${groupResponse.message}');
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('❌ Error loading groups from server: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void removeGroupFromState(String conversationId) {
    final updatedGroupList = state.groupList
        .where((group) => group.chatId != conversationId)
        .toList();
    state = state.copyWith(groupList: updatedGroupList);
  }

  /// Process conversations asynchronously
  Future<List<DmModel>> _convertToDmListTypeAsync(
    List<dynamic> conversationsList,
  ) async {
    const chunkSize = 10;
    List<DmModel> processedConversations = [];
    // Collect last-message inserts and await them before returning so the
    // watchDmConversations stream (which joins messages on lastMsgId) has
    // the rows when it next emits — otherwise the body flashes empty.
    final List<MessageModel> lastMessagesToInsert = [];

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

                // Redis-enriched last message data
                final lastMsg = json['lastMessage'] is Map<String, dynamic>
                    ? json['lastMessage'] as Map<String, dynamic>
                    : null;

                if (lastMsg != null && lastMsg['id'] != null) {
                  final convId = json['conversationId']?.toString() ?? '';
                  lastMessagesToInsert.add(MessageModel(
                    id: lastMsg['id'].toString(),
                    chatId: convId,
                    senderId: lastMsg['sender_id']?.toString() ?? '',
                    type: MessageType.fromString(lastMsg['type']?.toString()) ?? MessageType.text,
                    body: lastMsg['body']?.toString() ?? '',
                    sentAt: lastMsg['sent_at']?.toString() ?? DateTime.now().toIso8601String(),
                  ));
                }

                return DmModel(
                  chatId: json['conversationId']?.toString() ?? '',
                  recipientId: json['userId']?.toString() ?? '',
                  recipientName: json['userName']?.toString() ?? '',
                  recipientPhone: json['userPhone']?.toString() ?? '',
                  recipientProfilePic: json['userProfilePic']?.toString(),
                  pinnedMsgId: json['pinnedMsgId']?.toString(),
                  lastMsgId: lastMsg?['id']?.toString() ?? json['lastMsgId']?.toString(),
                  lastMsgType: lastMsg?['type']?.toString(),
                  lastMsgBody: lastMsg?['body']?.toString(),
                  lastMsgAt: lastMsg?['sent_at']?.toString() ?? json['lastMsgAt']?.toString(),
                  unreadCount: json['unreadCount'] is int ? json['unreadCount'] : 0,
                  isRecipientOnline: false,
                  createdAt: json['joinedAt']?.toString() ?? '',
                );
              }
              return null;
            } catch (e) {
              debugPrint('❌ Error processing convertToDmListTypeAsync: $e');
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

    // Await all last-message inserts so the Drift reactive stream has them
    // when it emits on the subsequent chat insert.
    if (lastMessagesToInsert.isNotEmpty) {
      try {
        await _messageRepo.insertMessages(lastMessagesToInsert);
      } catch (e) {
        debugPrint('❌ Error inserting DM last messages batch: $e');
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

                final lastMsg = json['lastMessage'] is Map<String, dynamic>
                    ? json['lastMessage'] as Map<String, dynamic>
                    : null;
                final lastMsgId = lastMsg?['id']?.toString() ?? json['lastMsgId']?.toString();

                return ConversationModel(
                  id: convId.toString(),
                  type: json['type']?.toString() ?? 'dm',
                  title: json['title']?.toString(),
                  createrId: json['createrId']?.toString(),
                  unreadCount: json['unreadCount'] is int ? json['unreadCount'] : 0,
                  lastMsgId: lastMsgId,
                  lastMsgAt: lastMsg?['sent_at']?.toString() ?? json['lastMsgAt']?.toString(),
                  pinnedMsgId: json['pinnedMsgId']?.toString(),
                  deletedAt: json['deletedAt']?.toString(),
                  isPinned: json['isPinned'] == true,
                  isFavorite: json['isFavorite'] == true,
                  isMuted: json['isMuted'] == true,
                  createdAt: json['joinedAt']?.toString(),
                );
              }
              return null;
            } catch (e) {
              debugPrint(
                '❌ Error processing convertToConversationsTypeAsync: $e',
              );
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
    // Dedupe by chatId — race conditions in _handleConversationAdded /
    // addNewGroup can append the same conv twice. Last write wins so newer
    // unread counts / last-message data take precedence.
    final byId = <String, DmModel>{};
    for (final c in conversations) {
      byId[c.chatId] = c;
    }
    final filteredConversations = byId.values
        .where((conv) => conv.deletedAt == null)
        .toList();

    filteredConversations.sort((a, b) {
      final aPinned = a.isPinned;
      final bPinned = b.isPinned;

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aHasMessage = a.lastMsgAt != null && a.lastMsgAt!.isNotEmpty;
      final bHasMessage = b.lastMsgAt != null && b.lastMsgAt!.isNotEmpty;

      // Chats with messages should come before chats without messages
      if (aHasMessage && !bHasMessage) return -1;
      if (!aHasMessage && bHasMessage) return 1;

      // Both have messages: sort by lastMessageAt (newest first)
      if (aHasMessage && bHasMessage) {
        return DateTime.parse(
          b.lastMsgAt!,
        ).compareTo(DateTime.parse(a.lastMsgAt!));
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
    // Dedupe by chatId — see filterAndSortConversations for the rationale.
    final byId = <String, GroupModel>{};
    for (final g in groups) {
      byId[g.chatId] = g;
    }
    final filteredGroups = byId.values.toList();

    filteredGroups.sort((a, b) {
      final aPinned = a.isPinned;
      final bPinned = b.isPinned;

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aHasMessage = a.lastMsgAt != null && a.lastMsgAt!.isNotEmpty;
      final bHasMessage = b.lastMsgAt != null && b.lastMsgAt!.isNotEmpty;

      if (aHasMessage && !bHasMessage) return -1;
      if (!aHasMessage && bHasMessage) return 1;

      if (aHasMessage && bHasMessage) {
        return DateTime.parse(
          b.lastMsgAt!,
        ).compareTo(DateTime.parse(a.lastMsgAt!));
      }

      return DateTime.parse(b.joinedAt).compareTo(DateTime.parse(a.joinedAt));
    });

    return filteredGroups;
  }

  void toggleDeleteChat(String conversationId, ChatType convType) async {
    if (convType == ChatType.dm) {
      final convIndex = state.dmList.indexWhere(
        (conv) => conv.chatId == conversationId,
      );
      if (convIndex == -1) return;

      final conv = state.dmList[convIndex];

      final updatedConv = conv.copyWith(
        deletedAt: conv.deletedAt == null
            ? DateTime.now().toIso8601String()
            : null,
      );
      // print(
      //   "--------------------------------------------------------------------------------",
      // );
      // print("updatedConv -> ${updatedConv.toJson()}");
      // print(
      //   "--------------------------------------------------------------------------------",
      // );
      final updatedDmList = List<DmModel>.from(state.dmList);
      updatedDmList[convIndex] = updatedConv;

      // Sort conversations
      final sortedConversations = await filterAndSortConversations(
        updatedDmList,
      );

      state = state.copyWith(dmList: sortedConversations);
    }
    // else if (convType == ChatType.group) {
    //   final convIndex = state.groupList.indexWhere(
    //     (group) => group.conversationId == conversationId,
    //   );
    //   if (convIndex == -1) return;
    //   final group = state.groupList[convIndex];
    //   final updatedGroup =
    //       group.copyWith(isDeleted: !(group.isDeleted ?? false));
    //   final updatedGroupList = List<GroupModel>.from(state.groupList);
    //   updatedGroupList[convIndex] = updatedGroup;
    //
    //   state = state.copyWith(groupList: updatedGroupList);
    //   await _conversationsRepo.toggleDeleteConversation(
    //     conversationId,
    //     convType,
    //     updatedGroup.isDeleted ?? false,
    //   );
    // }
  }

  /// Set active conversation
  void setActiveConversation(String? conversationId, ChatType? convType) {
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
  void clearUnreadCount(String convId, ChatType? convType) async {
    if (convType == ChatType.dm) {
      final convIndex = state.dmList.indexWhere(
        (conv) => conv.chatId == convId,
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
        (group) => group.chatId == convId,
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
        (g) => g.chatId == group.chatId,
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
        (d) => d.chatId == dm.chatId,
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
    String conversationId,
    ChatType convType,
  ) async {
    try {
      if (convType == ChatType.dm) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.chatId == conversationId,
        );
        if (convIndex == -1) return;
        final conv = state.dmList[convIndex];

        DmModel? updatedConversation;

        switch (action) {
          case 'pin':
            await _conversationsRepo.togglePin(conversationId, true);

            updatedConversation = conv.copyWith(isPinned: !conv.isPinned);
            break;
          case 'unpin':
            await _conversationsRepo.togglePin(conversationId, false);
            updatedConversation = conv.copyWith(isPinned: !conv.isPinned);
            break;
          case 'mute':
            await _conversationsRepo.toggleMute(conversationId, true);

            updatedConversation = conv.copyWith(isMuted: !conv.isMuted);
            break;
          case 'unmute':
            await _conversationsRepo.toggleMute(conversationId, false);

            updatedConversation = conv.copyWith(isMuted: !conv.isMuted);
            break;
          case 'favorite':
            await _conversationsRepo.toggleFavorite(conversationId, true);

            updatedConversation = conv.copyWith(isFavorite: !conv.isFavorite);
            break;
          case 'unfavorite':
            await _conversationsRepo.toggleFavorite(conversationId, false);

            updatedConversation = conv.copyWith(isFavorite: !conv.isFavorite);
            break;
          case 'delete':
            final response = await apiService.chat.deleteDm(conversationId);
            if (response.isSuccess) {
              // Soft-delete locally (sets chats.deletedAt) so the DM stays
              // restorable from Profile → Chat Management. The dm-list
              // stream filters deletedAt-not-null rows out of the active
              // list, and toggleDeleteChat keeps state.dmList in sync.
              await _conversationsRepo.softDeleteConversation(conversationId);
              toggleDeleteChat(conversationId, ChatType.dm);
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
          (group) => group.chatId == conversationId,
        );
        if (convIndex == -1) return;
        final group = state.groupList[convIndex];

        GroupModel? updatedGroup;

        switch (action) {
          case 'pin':
            await _conversationsRepo.togglePin(conversationId, true);

            updatedGroup = group.copyWith(isPinned: !group.isPinned);
            break;
          case 'unpin':
            await _conversationsRepo.togglePin(conversationId, false);
            updatedGroup = group.copyWith(isPinned: !group.isPinned);
            break;
          case 'mute':
            await _conversationsRepo.toggleMute(conversationId, true);

            updatedGroup = group.copyWith(isMuted: !group.isMuted);
            break;
          case 'unmute':
            await _conversationsRepo.toggleMute(conversationId, false);

            updatedGroup = group.copyWith(isMuted: !group.isMuted);
            break;
          case 'favorite':
            await _conversationsRepo.toggleFavorite(conversationId, true);

            updatedGroup = group.copyWith(isFavorite: !group.isFavorite);
            break;
          case 'unfavorite':
            await _conversationsRepo.toggleFavorite(conversationId, false);

            updatedGroup = group.copyWith(isFavorite: !group.isFavorite);
            break;
          case 'delete':
            final response = await apiService.group.deleteGroup(conversationId);
            if (response.isSuccess) {
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

    _conversationActionSubscription = _messageHandler.conversationActionStream
        .listen(
          _handleConversationAction,
          onError: (error) {
            debugPrint('❌ Conversation action stream error: $error');
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

    _messageSentAckSubscription = _messageHandler.messageSentAckStream.listen(
      _handleSentAck,
      onError: (error) {
        debugPrint('❌ Message Sent Ack stream error: $error');
      },
    );

    _messageStatusAckSubscription = _messageHandler.messageStatusAckStream.listen(
      _handleStatusAck,
      onError: (error) {
        debugPrint('❌ Message Status Ack stream error: $error');
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

    _messageReactSubscription = _messageHandler.messageReactStream.listen(
      _handleMessageReact,
      onError: (error) {
        debugPrint('❌ Message react stream error: $error');
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
  void _handleTypingMessage(TypingPayload message) async {
    try {
      final conversationId = message.convId;

      // Every typing event means "is typing" — cancel existing timer and reset
      _typingTimers[conversationId]?.cancel();

      // Look up sender info from cache
      final user = await UserInfoCache.instance.getUser(message.senderId);

      // Get the currently typing users
      final typingUsers = Map<String, Set<TypingUser>>.from(
        state.typingConvUsers,
      );

      // Create a new typing user
      final newtu = TypingUser(
        userId: message.senderId,
        userName: user?.name ?? '',
        userPfp: user?.profilePic,
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

      // Set timer to remove user after 3 seconds of inactivity
      _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
        final updatedTypingUsers = Map<String, Set<TypingUser>>.from(
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
    } catch (e) {
      debugPrint('❌ Error handling typing message: $e');
    }
  }

  Future<void> _handleNewMessage(ChatMessagePayload payload) async {
    debugPrint('✅ recieved new message at chat provider');
    try {
      final convId = payload.convId;

      // Ack delivery (and read if this chat is active) via StatusAckService.
      // Skip system messages — they are client-only (synthetic) and don't exist
      // in the backend messages table, so status acks for them fail FK checks.
      final currentUser = await UserUtils().getUserDetails();
      if (currentUser != null) {
        StatusAckService.instance.setCurrentUserId(currentUser.id);
      }
      if (currentUser != null &&
          payload.senderId != currentUser.id &&
          payload.msgType != MessageType.system) {
        StatusAckService.instance.ackMessage(
          convId,
          payload.id,
          isRead: convId == state.activeConvId,
        );
      }

      // Resolve convType from DB since it's no longer on the payload
      final convTypeStr = await _conversationsRepo.getConversationTypeById(convId);
      final convType = ChatType.fromString(convTypeStr) ?? ChatType.dm;

      // Idempotency guard: if this message id is already in local DB, this is a
      // replay (WS reconnect after FCM delivered it, or a re-join flush).
      // Skipping the unread-count increment here prevents double-counting on
      // app restarts when the server re-delivers unacked messages.
      final isReplay = await _messageRepo.getMessageById(payload.id) != null;

      // Insert message into local DB (upsert — safe on replay)
      await _messageRepo.insertMessage(
        MessageModel(
          id: payload.id,
          chatId: payload.convId,
          senderId: payload.senderId,
          type: payload.msgType,
          body: payload.body,
          attachments: payload.attachments,
          repliedTo: payload.repliedTo,
          repliedToMessage: payload.repliedToMessage,
          sentAt: payload.sentAt.toIso8601String(),
        ),
      );

      if (isReplay) {
        debugPrint('[ChatProvider] Skipping unread increment for replayed message ${payload.id}');
        return;
      }

      int newDmUnreadCount = 0, newGrpUnreadCount = 0;

      // Handle DM messages
      if (convType == ChatType.dm) {
        final convIndex = state.dmList.indexWhere(
          (conv) => conv.chatId == convId,
        );

        if (convIndex == -1) return;

        final dm = state.dmList[convIndex];

        newDmUnreadCount = state.activeConvId == convId
            ? 0
            : payload.senderId == currentUser?.id
            ? dm.unreadCount ?? 0
            : (dm.unreadCount ?? 0) + 1;

        final updatedConversation = dm.copyWith(
          lastMsgId: payload.id,
          lastMsgType: payload.msgType.value,
          lastMsgBody: payload.body,
          lastMsgAt: payload.sentAt.toIso8601String(),
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
          (group) => group.chatId == convId,
        );

        if (convIndex == -1) return;

        final group = state.groupList[convIndex];

        // Update group's last message
        newGrpUnreadCount = state.activeConvId == convId
            ? 0
            : payload.senderId == currentUser?.id
            ? group.unreadCount
            : (group.unreadCount) + 1;

        final updatedGroup = group.copyWith(
          lastMsgId: payload.id,
          lastMsgType: payload.msgType.value,
          lastMsgBody: payload.body,
          lastMsgAt: payload.sentAt.toIso8601String(),
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

      // if (payload.canonicalId != null) {
      await _conversationsRepo.updateLastMessage(convId, payload.id);
      // } else {
      //   debugPrint(
      //     '❌ canonicalId is null, skipping last message update in DB for: \n opt message id: ${payload.optimisticId}, msg body : ${payload.body}',
      //   );
      // }
    } catch (e) {
      debugPrint('❌ Error handling new message: $e');
    }
  }

  /// Handle sent ack (server confirms our message was persisted)
  Future<void> _handleSentAck(MessageSentAckPayload payload) async {
    debugPrint('✅ received sent ack at chat provider');
    try {
      if (payload.isSent) {
        // Mark as sent (clear failed flag)
        await _messageRepo.updateMessageFields(payload.msgId, isFailed: false);

        // Keep the conversation last-message pointer in sync
        await _conversationsRepo.updateLastMessageId(
          payload.convId,
          payload.newId ?? payload.msgId,
        );
      } else {
        // Message failed to send on server
        await _messageRepo.updateMessageFields(payload.msgId, isFailed: true);
      }
    } catch (e) {
      debugPrint('❌ Error handling sent ack: $e');
    }
  }

  /// Handle status ack (delivery/read receipts from other users)
  Future<void> _handleStatusAck(MessageStatusAckPayload payload) async {
    debugPrint('✅ received status ack at chat provider');
    try {
      final recipientId = payload.recipientId;
      final atStr = payload.at.toIso8601String();

      for (final ack in payload.acks) {
        for (final msgId in ack.msgIds) {
          if (ack.status.contains('read')) {
            // Read implies delivered
            await _messageStatusRepo.updateDeliveredAtForUser(
              messageId: msgId,
              userId: recipientId,
              chatId: ack.chatId,
              deliveredAt: atStr,
            );
            await _messageStatusRepo.updateReadAtForUser(
              messageId: msgId,
              userId: recipientId,
              chatId: ack.chatId,
              readAt: atStr,
            );
          } else if (ack.status.contains('delivered')) {
            await _messageStatusRepo.updateDeliveredAtForUser(
              messageId: msgId,
              userId: recipientId,
              chatId: ack.chatId,
              deliveredAt: atStr,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling status ack: $e');
    }
  }

  // updateLast messge on sending own message from messaging page
  void updateLastMessageOnSendingOwnMessage(
    String conversationId,
    MessageModel lastMessage,
  ) async {
    try {
      final messageId = lastMessage.id;

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
          (conv) => conv.chatId == conversationId,
        );
        if (convIndex != -1) {
          final dm = state.dmList[convIndex];
          final updatedDm = dm.copyWith(
            lastMsgId: messageId,
            lastMsgType: lastMessage.type.value,
            lastMsgBody: lastMessage.body,
            lastMsgAt: lastMessage.sentAt,
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
          (group) => group.chatId == conversationId,
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
            chatId: conversationId,
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
              createdBy: group.metadata?.createdBy ?? '',
            );
          }

          final updatedGroup = group.copyWith(
            lastMsgId: messageId,
            lastMsgType: lastMessage.type.value,
            lastMsgBody: lastMessage.body ?? '',
            lastMsgAt: lastMessage.sentAt,
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
    String conversationId,
    String? pinnedMessageId,
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
          (conv) => conv.chatId == conversationId,
        );
        if (convIndex != -1) {
          final dm = state.dmList[convIndex];
          final updatedDm = dm.copyWith(pinnedMsgId: pinnedMessageId);
          final updatedDmList = List<DmModel>.from(state.dmList);
          updatedDmList[convIndex] = updatedDm;
          state = state.copyWith(dmList: updatedDmList);
        }
      } else if (convType == ChatType.group.value) {
        final convIndex = state.groupList.indexWhere(
          (group) => group.chatId == conversationId,
        );
        if (convIndex != -1) {
          final group = state.groupList[convIndex];
          final updatedGroup = group.copyWith(pinnedMsgId: pinnedMessageId);
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
      final dmIndex = state.dmList.indexWhere((dm) => dm.chatId == convId);
      if (dmIndex != -1) {
        final dm = state.dmList[dmIndex];
        final updatedDm = dm.copyWith(pinnedMsgId: pinnedMessageId);
        final updatedDmList = List<DmModel>.from(state.dmList);
        updatedDmList[dmIndex] = updatedDm;
        state = state.copyWith(dmList: updatedDmList);
        return;
      }

      // Check Group list if not found in DM list
      final groupIndex = state.groupList.indexWhere(
        (group) => group.chatId == convId,
      );
      if (groupIndex != -1) {
        final group = state.groupList[groupIndex];
        final updatedGroup = group.copyWith(pinnedMsgId: pinnedMessageId);
        final updatedGroupList = List<GroupModel>.from(state.groupList);
        updatedGroupList[groupIndex] = updatedGroup;
        state = state.copyWith(groupList: updatedGroupList);
      }
    } catch (e) {
      debugPrint('❌ Error handling pin message: $e');
    }
  }

  /// Handle incoming emoji reaction from WebSocket
  Future<void> _handleMessageReact(MessageReactPayload payload) async {
    try {
      await _messageStatusRepo.upsertReaction(
        messageId: payload.messageId,
        userId: payload.senderId,
        chatId: payload.convId,
        emoji: payload.action == 'add' ? payload.emoji : null,
      );
    } catch (e) {
      debugPrint('❌ Error handling message react: $e');
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
          (conv) => conv.chatId == convId,
        );
        if (existingIndex != -1) return;

        // Try to get user from local DB to use displayName (includes username)
        final displayName =
            await UserUtils().getDisplayNameForUserId(message.createrId) ??
            message.createrName;

        final newDM = DmModel(
          chatId: convId,
          recipientId: message.createrId,
          recipientName: displayName,
          recipientPhone: message.createrPhone,
          isRecipientOnline: true,
          unreadCount: 0,
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
          pinnedMsgId: null,
          isPinned: false,
          isFavorite: false,
          isMuted: false,
          createdAt: message.joinedAt.toIso8601String(),
        );

        // Store in local DB
        await _conversationsRepo.insertConversations([newConv]);

        final convMember = ConversationMemberModel(
          chatId: newDM.chatId,
          userId: newDM.recipientId,
          role: 'member',
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
          (conv) => conv.chatId == convId,
        );
        if (existingIndex != -1) return;

        final newGroup = GroupModel(
          chatId: convId,
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
          pinnedMsgId: null,
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
                  chatId: newGroup.chatId,
                  userId: member.userId,
                  role: member.role.value,
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
  Future<void> _handleOnlineStatus(ConnectionStatusPayload payload) async {
    try {
      final userId = payload.senderId;
      // Backend now emits 'online' | 'offline' | 'stale'
      final isOnline = payload.status == 'online';
      debugPrint('[OnlineStatus] user=$userId status=${payload.status} isOnline=$isOnline');

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

      // mark as delivered all undelivered messages from this user in message_status table
      await _messageStatusRepo.markAllAsDeliveredForUser(
        userId: userId,
        deliveredAt: DateTime.now().toIso8601String(),
      );
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

      // Get current user ID to check which messages were unread
      final currentUser = await UserUtils().getUserDetails();
      if (currentUser == null) return;
      final currentUserId = currentUser.id;

      // Get messages before deletion to check if they were unread
      final messagesToDelete = await _messageRepo.getMessagesByIds(
        deletedMessageIds,
      );

      // Count unread messages (messages not sent by current user and not read by current user)
      int unreadCountToDecrement = 0;
      for (final message in messagesToDelete) {
        // Only count messages sent by others (not by current user)
        if (message.senderId != currentUserId) {
          // Check if message was unread
          final isRead = await _messageStatusRepo.isReadByUser(
            message.id,
            currentUserId,
          );
          if (!isRead) {
            unreadCountToDecrement++;
          }
        }
      }

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
          (conv) => conv.chatId == conversationId,
        );
        if (convIndex == -1) return;
        final conversation = state.dmList[convIndex];

        final lastMessage = await _messageRepo.getLastMessage(conversationId);

        // Decrement unread count if unread messages were deleted
        final currentUnreadCount = conversation.unreadCount ?? 0;
        final newUnreadCount = currentUnreadCount > unreadCountToDecrement
            ? currentUnreadCount - unreadCountToDecrement
            : 0;

        final updatedConversation = conversation.copyWith(
          lastMsgId: lastMessage?.id,
          lastMsgType: lastMessage?.type.value,
          lastMsgBody: lastMessage?.body,
          lastMsgAt: lastMessage?.sentAt,
          unreadCount: newUnreadCount,
        );

        final updatedConversations = List<DmModel>.from(state.dmList);
        updatedConversations[convIndex] = updatedConversation;

        state = state.copyWith(dmList: updatedConversations);

        // Update unread count in database
        await _conversationsRepo.updateUnreadCount(
          conversationId,
          newUnreadCount,
        );
      }
      // Update for group conversations can be added here in future
      else if (convType == ChatType.group) {
        final convIndex = state.groupList.indexWhere(
          (conv) => conv.chatId == conversationId,
        );
        if (convIndex == -1) return;
        final conversation = state.groupList[convIndex];

        final lastMessage = await _messageRepo.getLastMessage(conversationId);

        // Decrement unread count if unread messages were deleted
        final currentUnreadCount = conversation.unreadCount;
        final newUnreadCount = currentUnreadCount > unreadCountToDecrement
            ? currentUnreadCount - unreadCountToDecrement
            : 0;

        final updatedConversation = conversation.copyWith(
          lastMsgId: lastMessage?.id,
          lastMsgType: lastMessage?.type.value,
          lastMsgBody: lastMessage?.body,
          lastMsgAt: lastMessage?.sentAt,
          unreadCount: newUnreadCount,
        );

        final updatedConversations = List<GroupModel>.from(state.groupList);
        updatedConversations[convIndex] = updatedConversation;

        state = state.copyWith(groupList: updatedConversations);

        // Update unread count in database
        await _conversationsRepo.updateUnreadCount(
          conversationId,
          newUnreadCount,
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling message delete: $e');
    }
  }

  /// Handle conversation join/leave events
  Future<void> _handleConversationJoin(ConvJoinPayload payload) async {
    debugPrint('[ConvJoin] user=${payload.userId} conv=${payload.convId} lastRead=${payload.lastReadMsgId}');
    try {
      await _messageStatusRepo.markAllAsReadByConversationAndUser(
        chatId: payload.convId,
        userId: payload.userId,
      );
    } catch (e) {
      debugPrint('❌ Error handling conversation join/leave event: $e');
    }
  }

  /// Handle conversation member/admin actions (add/remove/promote/demote)
  Future<void> _handleConversationAction(
    ConversationActionPayload payload,
  ) async {
    try {
      switch (payload.action) {
        case ConversationActionType.memberAdded:
          final members = payload.members
              .map(
                (member) => ConversationMemberModel(
                  chatId: payload.convId,
                  userId: member.userId,
                  role: member.role.value,
                  joinedAt: member.joinedAt.toIso8601String(),
                ),
              )
              .toList();
          await _conversationsMemberRepo.insertConversationMembers(members);

          // Also upsert user info for each new member so message bubbles
          // can resolve sender names instead of showing "Unknown User".
          final userModels = payload.members
              .map(
                (m) => UserModel(
                  id: m.userId,
                  name: m.userName,
                  phone: '',
                  profilePic: m.userPfp,
                  isOnline: false,
                ),
              )
              .toList();
          await _userRepo.insertOrUpdateUsers(userModels);
          // Prime the in-memory cache too
          for (final u in userModels) {
            UserInfoCache.instance.setUser(u);
          }
          break;
        case ConversationActionType.memberRemoved:
          for (final member in payload.members) {
            await _conversationsMemberRepo.deleteMemberByConversationAndUserId(
              payload.convId,
              member.userId,
            );
          }
          // If the current user is among the removed, mark the group as
          // "you are no longer a member" by setting deletedAt on the chat row.
          // The group messaging screen checks this to disable input.
          final currentUser = await UserUtils().getUserDetails();
          if (currentUser != null &&
              payload.members.any((m) => m.userId == currentUser.id)) {
            await _conversationsRepo.softDeleteConversation(payload.convId);
          }
          break;
        case ConversationActionType.memberPromoted:
        case ConversationActionType.memberDemoted:
          final roleValue =
              payload.action == ConversationActionType.memberPromoted
              ? ChatRoleType.admin.value
              : ChatRoleType.member.value;
          for (final member in payload.members) {
            await _conversationsMemberRepo.updateMemberRole(
              payload.convId,
              member.userId,
              roleValue,
            );
          }
          break;
        case ConversationActionType.chatDelete:
          // Admin hard-deleted the chat. Wipe local state and bail out before
          // the system-message insert below — there's no chat row left for
          // it to belong to. If the user is currently inside this chat,
          // setActiveConvId(null) so the screen's existing removed-from-group
          // empty-state path takes over on next build.
          await _conversationsMemberRepo.deleteMembersByConversationId(
            payload.convId,
          );
          await _conversationsRepo.deleteConversation(payload.convId);
          final updatedGroupList = state.groupList
              .where((g) => g.chatId != payload.convId)
              .toList();
          final updatedDmList = state.dmList
              .where((d) => d.chatId != payload.convId)
              .toList();
          final clearedActive =
              state.activeConvId == payload.convId ? null : state.activeConvId;
          state = state.copyWith(
            groupList: updatedGroupList,
            dmList: updatedDmList,
            activeConvId: clearedActive,
          );
          return;
      }

      // Look up actor info from cache
      final actor = payload.actorId != null
          ? await UserInfoCache.instance.getUser(payload.actorId!)
          : null;

      final systemMessage = MessageModel(
        id: payload.eventId,
        chatId: payload.convId,
        senderId: payload.actorId,
        senderName: actor?.name,
        senderProfilePic: actor?.profilePic,
        type: MessageType.system,
        body: payload.message,
        attachments: null,
        sentAt: payload.actionAt.toIso8601String(),
      );

      await _messageRepo.insertMessage(systemMessage);

      final convIndex = state.groupList.indexWhere(
        (group) => group.chatId == payload.convId,
      );

      if (convIndex != -1) {
        final group = state.groupList[convIndex];
        final newUnread = state.activeConvId == payload.convId
            ? 0
            : group.unreadCount + 1;

        final updatedGroup = group.copyWith(
          lastMsgId: payload.eventId,
          lastMsgType: MessageType.system.value,
          lastMsgBody: payload.message,
          lastMsgAt: payload.actionAt.toIso8601String(),
          unreadCount: newUnread,
        );

        final updatedGroups = List<GroupModel>.from(state.groupList);
        updatedGroups[convIndex] = updatedGroup;

        final sortedGroups = await filterAndSortGroupConversations(
          updatedGroups,
        );

        state = state.copyWith(groupList: sortedGroups);

        await _conversationsRepo.updateUnreadCount(payload.convId, newUnread);

        await _conversationsRepo.updateLastMessage(
          payload.convId,
          payload.eventId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling conversation action: $e');
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
      mediaUploadProgress: {},
    );
  }

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return; // Prevent multiple dispose calls
    _isDisposed = true;

    // Stop the cleanup timer
    // _messageRepo.stopCleanupTimer();

    _typingSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageSentAckSubscription?.cancel();
    _messageStatusAckSubscription?.cancel();
    _pinSubscription?.cancel();
    _joinConvSubscription?.cancel();
    _conversationAddedSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _messageReactSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _conversationActionSubscription?.cancel();

    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
  }
}
