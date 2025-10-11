import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/community_model.dart';
import '../../api/user.service.dart';
import '../../repositories/groups_repository.dart';
import '../../repositories/communities_repository.dart';
import '../../services/websocket_service.dart';
import 'inner_group_chat_page.dart';
import 'create_group_page.dart';
import 'community_inner_groups_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({Key? key}) : super(key: key);

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final UserService _userService = UserService();
  final GroupsRepository _groupsRepo = GroupsRepository();
  final CommunitiesRepository _communitiesRepo = CommunitiesRepository();
  final WebSocketService _websocketService = WebSocketService();

  late Future<Map<String, dynamic>> _dataFuture;
  final TextEditingController _searchController = TextEditingController();

  // Real-time state management
  List<GroupModel> _allGroups = [];
  List<CommunityModel> _allCommunities = [];
  List<dynamic> _filteredItems = []; // Can contain both groups and communities
  bool _isLoaded = false;

  // Track which group user is currently viewing
  int? _activeConversationId;

  StreamSubscription<Map<String, dynamic>>? _websocketSubscription;

  @override
  void initState() {
    super.initState();
    _loadFromLocal();
    _dataFuture = _loadGroupsAndCommunities();
    _searchController.addListener(_onSearchChanged);
    _setupWebSocketListener();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _websocketSubscription?.cancel();
    // Clear active conversation
    _activeConversationId = null;
    super.dispose();
  }

  /// Load groups and communities from local DB first
  Future<void> _loadFromLocal() async {
    try {
      debugPrint('📦 Loading from local DB...');
      final localGroups = await _groupsRepo.getAllGroups();
      final localCommunities = await _communitiesRepo.getAllCommunities();

      if (mounted) {
        setState(() {
          _allGroups = localGroups;
          _allCommunities = localCommunities;
          _isLoaded = true;
          _onSearchChanged();
        });

        if (localGroups.isNotEmpty || localCommunities.isNotEmpty) {
          debugPrint(
            '✅ Loaded ${localGroups.length} groups and ${localCommunities.length} communities from local DB',
          );
        } else {
          debugPrint('ℹ️ No cached groups or communities found in local DB');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading from local DB: $e');
      // Even on error, set isLoaded to allow showing empty state
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _allGroups = [];
          _allCommunities = [];
          _filteredItems = [];
        });
      }
    }
  }

  /// Set up WebSocket listener for real-time updates
  void _setupWebSocketListener() {
    _websocketSubscription = _websocketService.messageStream.listen(
      (message) {
        _handleIncomingWebSocketMessage(message);
      },
      onError: (error) {
        debugPrint('❌ WebSocket message stream error in GroupsPage: $error');
      },
    );
  }

  /// Handle incoming WebSocket messages
  void _handleIncomingWebSocketMessage(Map<String, dynamic> message) {
    try {
      debugPrint('📨 GroupsPage received WebSocket message: $message');

      final messageType = message['type'];

      if (messageType == 'message' || messageType == 'media') {
        // Update last message for groups
        _handleNewGroupMessage(message);
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message in GroupsPage: $e');
    }
  }

  /// Clear unread count for a specific group
  void _clearUnreadCount(int conversationId) {
    if (!mounted) return;

    final groupIndex = _allGroups.indexWhere(
      (group) => group.conversationId == conversationId,
    );

    if (groupIndex != -1) {
      final group = _allGroups[groupIndex];
      if (group.unreadCount > 0) {
        setState(() {
          final updatedGroup = GroupModel(
            conversationId: group.conversationId,
            title: group.title,
            type: group.type,
            members: group.members,
            metadata: group.metadata,
            lastMessageAt: group.lastMessageAt,
            role: group.role,
            unreadCount: 0,
            joinedAt: group.joinedAt,
          );
          _allGroups[groupIndex] = updatedGroup;
          // Persist to local DB
          _groupsRepo.insertOrUpdateGroup(updatedGroup);
          // Update filtered items
          _onSearchChanged();
        });
        debugPrint(
          '✅ Cleared unread count for group $conversationId (was ${group.unreadCount})',
        );
      } else {
        debugPrint(
          'ℹ️ Group $conversationId already has 0 unread count',
        );
      }
    } else {
      debugPrint(
        '⚠️ Group $conversationId not found when trying to clear unread count',
      );
    }
  }

  /// Set the currently active group (when user enters inner group chat)
  void _setActiveConversation(int? conversationId) {
    debugPrint(
      '📍 Setting active group from $_activeConversationId to: $conversationId',
    );
    _activeConversationId = conversationId;
    if (conversationId != null) {
      _clearUnreadCount(conversationId);
    }
  }

  /// Handle new message for groups
  void _handleNewGroupMessage(Map<String, dynamic> message) {
    try {
      final conversationId = message['conversation_id'] as int?;
      if (conversationId == null) return;

      final groupIndex = _allGroups.indexWhere(
        (group) => group.conversationId == conversationId,
      );

      if (groupIndex == -1) return;

      final data = message['data'] as Map<String, dynamic>? ?? {};

      if (mounted && _isLoaded) {
        setState(() {
          final group = _allGroups[groupIndex];

          // Create new last message with better media handling
          String messageBody = data['body'] ?? '';
          
          // If body is empty and it's a media message, extract from nested data
          if (messageBody.isEmpty && data['data'] != null) {
            final nestedData = data['data'] as Map<String, dynamic>;
            messageBody = nestedData['message_type'] ?? nestedData['file_name'] ?? '';
          }
          
          final lastMessage = GroupLastMessage(
            id: data['id'] ?? data['media_message_id'] ?? 0,
            body: messageBody,
            type: data['type'] ?? message['type'] ?? 'text',
            senderId: data['sender_id'] ?? data['user_id'] ?? 0,
            senderName: data['sender_name'] ?? '',
            createdAt: data['created_at'] ?? DateTime.now().toIso8601String(),
            conversationId: conversationId,
          );

          final updatedMetadata = GroupMetadata(
            lastMessage: lastMessage,
            totalMessages: (group.metadata?.totalMessages ?? 0) + 1,
            createdAt: group.metadata?.createdAt,
            createdBy: group.metadata?.createdBy ?? 0,
          );

          // Only increment unread count if this is not the currently active group
          final newUnreadCount = _activeConversationId == conversationId
              ? group.unreadCount // Don't increment if user is viewing this group
              : group.unreadCount + 1; // Increment if user is not viewing this group

          // Create updated group
          final updatedGroup = GroupModel(
            conversationId: group.conversationId,
            title: group.title,
            type: group.type,
            members: group.members,
            metadata: updatedMetadata,
            unreadCount: newUnreadCount,
            lastMessageAt: lastMessage.createdAt,
            role: group.role,
            joinedAt: group.joinedAt,
          );

          _allGroups[groupIndex] = updatedGroup;

          // Persist to local DB
          _groupsRepo.insertOrUpdateGroup(updatedGroup);

          // Update filtered items
          _onSearchChanged();
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling new group message: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = [..._allGroups, ..._allCommunities];
      } else {
        final filteredGroups = _allGroups.where((group) {
          return group.title.toLowerCase().contains(query) ||
              group.members.any(
                (member) => member.name.toLowerCase().contains(query),
              );
        }).toList();

        final filteredCommunities = _allCommunities.where((community) {
          return community.name.toLowerCase().contains(query);
        }).toList();

        _filteredItems = [...filteredGroups, ...filteredCommunities];
      }
    });
  }

  Future<Map<String, dynamic>> _loadGroupsAndCommunities() async {
    // First, get current local data
    List<GroupModel> localGroups = [];
    List<CommunityModel> localCommunities = [];

    try {
      localGroups = await _groupsRepo.getAllGroups();
      localCommunities = await _communitiesRepo.getAllCommunities();
      debugPrint(
        '📦 Current local DB has ${localGroups.length} groups and ${localCommunities.length} communities',
      );
    } catch (e) {
      debugPrint('⚠️ Error reading local DB: $e');
    }

    try {
      debugPrint('📥 Loading groups and communities from server...');

      // Load groups
      final groupResponse = await _userService.GetChatList('group');

      // Load communities
      final communityResponse = await _userService.GetCommunityChatList();
      print('Community response: $communityResponse');

      List<GroupModel> groups = [];
      List<CommunityModel> communities = [];
      bool hasServerData = false;

      // Process groups
      if (groupResponse['success']) {
        final dynamic responseData = groupResponse['data'];
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

        // Filter only group conversations and convert to GroupModel
        groups = conversationsList
            .where((json) => json['type'] == 'group')
            .map((json) => _convertToGroupModel(json))
            .toList();

        if (groups.isNotEmpty) {
          hasServerData = true;
          // Only persist if we got data from server
          await _groupsRepo.insertOrUpdateGroups(groups);
          debugPrint('✅ Persisted ${groups.length} groups to local DB');
        } else {
          debugPrint('⚠️ Server returned 0 groups - keeping local cache');
        }
      }

      // Process communities
      if (communityResponse['success'] && communityResponse['data'] != null) {
        final List<dynamic> communityList =
            communityResponse['data'] as List<dynamic>;
        communities = communityList
            .map(
              (json) => CommunityModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        if (communities.isNotEmpty) {
          hasServerData = true;
          // Only persist if we got data from server
          await _communitiesRepo.insertOrUpdateCommunities(communities);
          debugPrint(
            '✅ Persisted ${communities.length} communities to local DB',
          );
        } else {
          debugPrint('⚠️ Server returned 0 communities - keeping local cache');
        }
      }

      // If server returned empty but we have local data, use local data
      if (!hasServerData &&
          (localGroups.isNotEmpty || localCommunities.isNotEmpty)) {
        debugPrint('📦 Server returned no data - using cached data instead');
        groups = localGroups;
        communities = localCommunities;
      }

      if (mounted) {
        setState(() {
          _allGroups = groups.isNotEmpty ? groups : localGroups;
          _allCommunities = communities.isNotEmpty
              ? communities
              : localCommunities;
          _filteredItems = [..._allGroups, ..._allCommunities];
          _isLoaded = true;
        });
      }

      debugPrint(
        '✅ Displaying ${_allGroups.length} groups and ${_allCommunities.length} communities',
      );
      return {'groups': _allGroups, 'communities': _allCommunities};
    } catch (e) {
      debugPrint('❌ Error loading from server: $e');
      debugPrint('📦 Using local DB data as fallback...');

      // Use local data on error
      if (mounted) {
        setState(() {
          _allGroups = localGroups;
          _allCommunities = localCommunities;
          _filteredItems = [...localGroups, ...localCommunities];
          _isLoaded = true;
        });
      }

      debugPrint(
        '📦 Displaying ${localGroups.length} groups and ${localCommunities.length} communities from local DB',
      );
      return {'groups': localGroups, 'communities': localCommunities};
    }
  }

  GroupModel _convertToGroupModel(Map<String, dynamic> json) {
    // Convert conversation data to group model
    // This assumes the backend returns group members and metadata
    return GroupModel(
      conversationId: json['conversationId'] ?? 0,
      title: json['title'] ?? 'Unnamed Group',
      type: json['type'] ?? 'group',
      members: _parseMembers(json['members']),
      metadata: json['metadata'] != null
          ? GroupMetadata.fromJson(json['metadata'])
          : null,
      lastMessageAt: json['lastMessageAt'],
      role: json['role'],
      unreadCount: json['unreadCount'] ?? 0,
      joinedAt: json['joinedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  List<GroupMember> _parseMembers(dynamic membersData) {
    if (membersData == null) return [];

    if (membersData is List) {
      return membersData.map((member) => GroupMember.fromJson(member)).toList();
    }

    return [];
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _loadGroupsAndCommunities();
      _isLoaded = false; // Reset to show loading state
    });
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
              child: Icon(Icons.groups_rounded, color: Colors.white, size: 24),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Groups & Communities',
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
                onPressed: () => _loadGroupsAndCommunities(),
              ),
            ),
          ],
        ),
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
                  hintText: 'Search groups...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

            // Groups and Communities List
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to create group page
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupPage()),
          );

          // If a group was created, refresh the data
          if (result == true) {
            _refreshData();
          }
        },
        backgroundColor: Colors.teal,
        child: Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    debugPrint(
      '🏗️ Building content: _isLoaded=$_isLoaded, filteredItems=${_filteredItems.length}',
    );

    // If we have loaded data, show it directly
    if (_isLoaded && _filteredItems.isNotEmpty) {
      return _buildItemsList();
    }

    // If we have loaded but no items, show appropriate empty state
    if (_isLoaded && _filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    // Otherwise, use FutureBuilder for initial load
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoaded) {
          return _buildSkeletonLoader();
        } else if (snapshot.hasError && !_isLoaded) {
          return _buildErrorState(snapshot.error.toString());
        } else if (snapshot.hasData || _isLoaded) {
          if (_filteredItems.isEmpty) {
            return _buildEmptyState();
          }
          return _buildItemsList();
        } else {
          return _buildSkeletonLoader();
        }
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 6,
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
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 12,
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
          ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No groups or communities yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group or join a community to start chatting',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        itemCount: _filteredItems.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final item = _filteredItems[index];

          if (item is GroupModel) {
            return GroupListItem(
              group: item,
              onTap: () async {
                // Set this group as active and clear unread count
                _setActiveConversation(item.conversationId);

                // Navigate to inner group chat page
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InnerGroupChatPage(group: item),
                  ),
                );

                // Clear unread count again when returning from inner chat
                // This ensures the count is cleared even if it was updated while in the chat
                _clearUnreadCount(item.conversationId);

                // Send inactive message before clearing active conversation
                try {
                  await _websocketService.sendMessage({
                    'type': 'inactive_in_conversation',
                    'conversation_id': item.conversationId,
                  });
                } catch (e) {
                  debugPrint('❌ Error sending inactive_in_conversation: $e');
                }

                // Clear active conversation when returning from inner chat
                _setActiveConversation(null);
              },
            );
          } else if (item is CommunityModel) {
            return CommunityListItem(
              community: item,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CommunityInnerGroupsPage(community: item),
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink(); // Fallback
        },
      ),
    );
  }
}

class GroupListItem extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;

  const GroupListItem({Key? key, required this.group, required this.onTap})
    : super(key: key);

  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null) return '';

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

  String _formatLastMessageText(GroupLastMessage? lastMessage) {
    if (lastMessage == null) return 'No messages yet';

    // If body is not empty, return it
    if (lastMessage.body.isNotEmpty) {
      return lastMessage.body;
    }

    // Handle media messages based on type
    switch (lastMessage.type.toLowerCase()) {
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
      case 'location':
        return '📍 Location';
      case 'contact':
        return '👤 Contact';
      case 'media':
        return '📎 Media';
      default:
        return 'New message';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnreadMessages = group.unreadCount > 0;
    final lastMessageText = _formatLastMessageText(group.metadata?.lastMessage);
    final timeText = _formatTime(group.lastMessageAt ?? group.joinedAt);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with proper constraints
              SizedBox(
                width: 48,
                height: 48,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal[100],
                  child: Icon(Icons.group, color: Colors.teal, size: 22),
                ),
              ),
              const SizedBox(width: 16),
              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      group.title,
                      style: TextStyle(
                        fontWeight: hasUnreadMessages
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessageText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing area
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  if (hasUnreadMessages) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        group.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
      ),
    );
  }
}

class CommunityListItem extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;

  const CommunityListItem({
    Key? key,
    required this.community,
    required this.onTap,
  }) : super(key: key);

  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null) return '';

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

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(community.updatedAt);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Community Avatar
              SizedBox(
                width: 48,
                height: 48,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.purple[100],
                  child: Icon(
                    Icons.diversity_3,
                    color: Colors.purple[700],
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            community.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'COMMUNITY',
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${community.innerGroupsCount} inner groups',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing area
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
