import 'package:flutter/material.dart';
import '../../../models/group_model.dart';
import '../../../models/community_model.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../widgets/chat/searchable_list_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/draft_provider.dart';
import '../../../providers/group_list_provider.dart';
import 'messaging.dart';
import 'create_group.dart';
import 'community_group_list.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  final WebSocketService _websocketService = WebSocketService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // Clear active conversation
    ref.read(groupListProvider.notifier).setActiveConversation(null);
    super.dispose();
  }

  /// Handle search text changes
  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(groupListProvider.notifier).updateSearchQuery(query);
  }

  void _refreshData() {
    ref.read(groupListProvider.notifier).loadGroupsAndCommunities();
  }

  // All state management and WebSocket handling is now done by groupListProvider

  // Removed: _loadFromLocal - now handled by provider
  // Removed: _updateGroupsWithStoredLastMessages - now handled by provider
  // Removed: _setupConversationAddedListener - now handled by provider
  // Removed: _handleConversationAdded - now handled by provider
  // Removed: _setupWebSocketListener - now handled by provider
  // Removed: _handleTypingMessage - now handled by provider
  // Removed: _clearUnreadCount - now handled by provider
  // Removed: _setActiveConversation - now handled by provider
  // Removed: _handleNewGroupMessage - now handled by provider
  // Removed: _handleMessageDelete - now handled by provider
  // Removed: _onSearchChanged - now handled by provider
  // Removed: _loadGroupsAndCommunities - now handled by provider
  // Removed: _convertToGroupModel - now handled by provider
  // Removed: _parseMembers - now handled by provider

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
                onPressed: () => _refreshData(),
              ),
            ),
          ],
        ),
      ),
      body: SearchableListLayout(
        searchBar: SearchableListBar(
          controller: _searchController,
          hintText: 'Search groups...',
          onChanged: (value) => _onSearchChanged(),
        ),
        content: _buildContent(),
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
    final groupState = ref.watch(groupListProvider);

    // Show loading skeleton while loading
    if (groupState.isLoading) {
      return _buildSkeletonLoader();
    }

    // Get filtered items from provider
    final filteredItems = groupState.filteredItems;

    // Show empty state if no items
    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    // Show the items list
    return _buildItemsList(filteredItems);
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

  Widget _buildItemsList(List<dynamic> filteredItems) {
    final groupState = ref.watch(groupListProvider);

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        itemCount: filteredItems.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final item = filteredItems[index];

          if (item is GroupModel) {
            final isTyping =
                groupState.typingUsers[item.conversationId] ?? false;
            final typingUsers =
                groupState.typingUserNames[item.conversationId] ?? <String>{};
            final typingUsersCount = typingUsers.length;

            return GroupListItem(
              group: item,
              isTyping: isTyping,
              typingUsers: typingUsers,
              typingUsersCount: typingUsersCount,
              conversationId: item.conversationId,
              onTap: () async {
                // Set this group as active and clear unread count
                ref
                    .read(groupListProvider.notifier)
                    .setActiveConversation(item.conversationId);

                // Navigate to inner group chat page
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InnerGroupChatPage(group: item),
                  ),
                );

                // Check if group was deleted
                if (result is Map && result['action'] == 'deleted') {
                  // Refresh the groups list
                  _refreshData();
                  return;
                }

                // Clear unread count again when returning from inner chat
                ref
                    .read(groupListProvider.notifier)
                    .clearUnreadCount(item.conversationId);

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
                ref
                    .read(groupListProvider.notifier)
                    .setActiveConversation(null);
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

class GroupListItem extends ConsumerWidget {
  final GroupModel group;
  final VoidCallback onTap;
  final bool isTyping;
  final Set<String> typingUsers;
  final int typingUsersCount;
  final int conversationId;

  const GroupListItem({
    super.key,
    required this.group,
    required this.onTap,
    this.isTyping = false,
    this.typingUsers = const {},
    this.typingUsersCount = 0,
    required this.conversationId,
  });

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
      case 'attachment':
        if (lastMessage.attachmentData != null &&
            lastMessage.attachmentData!.containsKey('category')) {
          final attachmentType = lastMessage.attachmentData!['category']
              .toLowerCase();
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
        return lastMessage.body;
      default:
        return lastMessage.body.isNotEmpty ? lastMessage.body : 'New message';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check for draft message
    final drafts = ref.watch(draftMessagesProvider);
    final draft = drafts[conversationId];

    final hasUnreadMessages = group.unreadCount > 0;

    // Use draft if available, otherwise use last message
    String lastMessageText;
    if (draft != null && draft.isNotEmpty) {
      // Show draft as last message
      lastMessageText = draft;
    } else {
      lastMessageText = _formatLastMessageText(group.metadata?.lastMessage);
    }

    final timeText = _formatTime(group.lastMessageAt ?? group.joinedAt);
    final displayText = isTyping
        ? 'Typing...'
        : (draft != null && draft.isNotEmpty
              ? 'Draft: $lastMessageText'
              : lastMessageText);

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
                            : FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    isTyping
                        ? Row(
                            children: [
                              Text(
                                typingUsersCount == 1
                                    ? '${typingUsers.first} is typing'
                                    : '$typingUsersCount people are typing',
                                style: TextStyle(
                                  color: Colors.teal[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildTypingAnimation(),
                            ],
                          )
                        : Text(
                            displayText,
                            style: TextStyle(
                              color: draft != null && draft.isNotEmpty
                                  ? Colors.green[600]
                                  : Colors.grey[600],
                              fontSize: 14,
                              fontStyle: FontStyle.normal,
                              fontWeight: draft != null && draft.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
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
                        color: const Color.fromARGB(255, 9, 117, 103),
                        shape: BoxShape.circle,
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

class CommunityListItem extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;

  const CommunityListItem({
    super.key,
    required this.community,
    required this.onTap,
  });

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
