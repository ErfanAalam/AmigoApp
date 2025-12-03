import 'package:amigo/types/chat.types.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/group_model.dart';
import '../../../models/community_model.dart';
import '../../../widgets/chat/searchable_list_widget.dart';
import '../../../widgets/chat_action_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/draft_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/theme_color_provider.dart';
import '../../../config/app_colors.dart';
import '../../../types/socket.type.dart';
import '../../../utils/route_transitions.dart';
import 'messaging.dart';
import 'create_group.dart';
import 'community_group_list.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => GroupsPageState();
}

class GroupsPageState extends ConsumerState<GroupsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  /// Called when the page becomes visible (when user navigates to Groups tab)
  void onPageVisible() {
    ref.read(chatProvider.notifier).setActiveConversation(null, null);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // Clear active conversation
    ref.read(chatProvider.notifier).setActiveConversation(null, null);
    super.dispose();
  }

  /// Handle search text changes
  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(chatProvider.notifier).updateSearchQuery(query);
  }

  void _refreshData() {
    ref.read(chatProvider.notifier).loadConvsFromServer();
  }

  /// Show group chat actions bottom sheet
  Future<void> _showGroupChatActions(GroupModel group) async {
    final action = await ChatActionBottomSheet.show(
      context: context,
      group: group,
      isPinned: group.isPinned ?? false,
      isMuted: group.isMuted ?? false,
      isFavorite: group.isFavorite ?? false,
    );

    if (action != null) {
      await _handleGroupChatAction(action, group);
    }
  }

  /// Handle group chat action
  Future<void> _handleGroupChatAction(String action, GroupModel group) async {
    await ref
        .read(chatProvider.notifier)
        .handleChatAction(action, group.conversationId, ChatType.group);
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
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: themeColor.primary,
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
        backgroundColor: themeColor.primary,
        child: Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    final chatState = ref.watch(chatProvider);

    // Show loading skeleton while loading
    if (chatState.isLoading) {
      return _buildSkeletonLoader();
    }

    // Get filtered items from provider
    final filteredItems = chatState.filteredGroupItems;

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
    final chatState = ref.watch(chatProvider);

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        itemCount: filteredItems.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final item = filteredItems[index];

          if (item is GroupModel) {
            final typingUsers =
                chatState.typingConvUsers[item.conversationId] ??
                <TypingUser>{};

            return GroupListItem(
              group: item,
              typingUsers: typingUsers,
              conversationId: item.conversationId,
              isPinned: item.isPinned ?? false,
              isMuted: item.isMuted ?? false,
              isFavorite: item.isFavorite ?? false,
              onLongPress: () => _showGroupChatActions(item),
              onTap: () async {
                // Set this group as active and clear unread count
                ref
                    .read(chatProvider.notifier)
                    .setActiveConversation(item.conversationId, ChatType.group);

                final result = await Navigator.push(
                  context,
                  SlideRightRoute(page: InnerGroupChatPage(group: item)),
                );

                // Check if group was deleted
                if (result is Map && result['action'] == 'deleted') {
                  // Refresh the groups list
                  _refreshData();
                  return;
                }

                // Clear unread count again when returning from inner chat
                ref
                    .read(chatProvider.notifier)
                    .clearUnreadCount(item.conversationId, ChatType.group);

                // Clear active conversation when returning from inner chat
                ref
                    .read(chatProvider.notifier)
                    .setActiveConversation(null, null);
              },
            );
          } else if (item is CommunityModel) {
            return CommunityListItem(
              community: item,
              onTap: () {
                Navigator.push(
                  context,
                  SlideRightRoute(
                    page: CommunityInnerGroupsPage(community: item),
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
  final VoidCallback? onLongPress;
  final Set<TypingUser> typingUsers;
  final int conversationId;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;

  const GroupListItem({
    super.key,
    required this.group,
    required this.onTap,
    this.onLongPress,
    this.typingUsers = const {},
    required this.conversationId,
    this.isPinned = false,
    this.isMuted = false,
    this.isFavorite = false,
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
      case 'image':
        return '📷 Photo';
      case 'video':
        return '📹 Video';
      case 'audio':
        return '🎵 Audio';
      case 'document':
        return '📎 Document';
      case 'reply':
        return '↩️ Reply';
      case 'forwarded':
        return '↪️ Forwarded message';
      // Backward compatibility for old 'attachment' type
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
            default:
              return '📎 Attachment';
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

    final hasUnreadMessages = group.unreadCount > 0;

    // Use draft if available, otherwise use last message
    String lastMessageText = '';
    if (draft != null && draft.isNotEmpty) {
      // Show draft as last message
      lastMessageText = draft;
    } else {
      // lastMessageText = _formatLastMessageText(group.metadata?.lastMessage);
      if (group.lastMessageId != null &&
          group.lastMessageAt != null &&
          group.lastMessageType != null) {
        lastMessageText = _formatLastMessageText(
          group.lastMessageBody ?? '',
          group.lastMessageType,
          group.metadata?.lastMessage?.attachmentData,
        );
      }
    }

    final timeText = _formatTime(group.lastMessageAt ?? group.joinedAt);
    final isTyping = typingUsers.isNotEmpty;
    final displayText = isTyping
        ? 'Typing...'
        : (draft != null && draft.isNotEmpty
              ? 'Draft: $lastMessageText'
              : lastMessageText);

    final themeColor = ref.watch(themeColorProvider);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isPinned ? themeColor.primary.withOpacity(0.05) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
          left: isPinned
              ? BorderSide(color: Colors.orange, width: 3)
              : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
                  backgroundColor: themeColor.primaryLight.withOpacity(0.3),
                  child: Icon(Icons.group, color: themeColor.primary, size: 22),
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
                        if (isPinned) ...[
                          Icon(Icons.push_pin, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                        ],
                        if (isMuted) ...[
                          Icon(
                            Icons.volume_off,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                        ],
                        if (isFavorite) ...[
                          Icon(Icons.favorite, size: 16, color: Colors.pink),
                          SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    isTyping
                        ? _buildTypingIndicator(themeColor)
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
                        color: themeColor.primary,
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

  Widget _buildTypingIndicator(ColorTheme themeColor) {
    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Multiple people typing
    if (typingUsers.length > 1) {
      return Row(
        children: [
          Text(
            '${typingUsers.length} people typing',
            style: TextStyle(
              color: themeColor.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          _buildTypingAnimation(),
        ],
      );
    }

    // Single person typing
    final typingUser = typingUsers.first;
    final hasPfp = typingUser.userPfp != null && typingUser.userPfp!.isNotEmpty;
    final hasName =
        typingUser.userName != null && typingUser.userName!.isNotEmpty;

    return Row(
      children: [
        // Show profile picture if available
        if (hasPfp) ...[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.primary.withAlpha(20),
                width: 1,
              ),
            ),
            child: CircleAvatar(
              radius: 8,
              backgroundColor: themeColor.primaryLight.withAlpha(20),
              backgroundImage: CachedNetworkImageProvider(typingUser.userPfp!),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          hasPfp
              ? 'typing'
              : (hasName
                    ? '${typingUser.userName} typing'
                    : 'member is typing'),
          style: TextStyle(
            color: themeColor.primary,
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
}

class _TypingDot extends ConsumerStatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  ConsumerState<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends ConsumerState<_TypingDot>
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
    final themeColor = ref.watch(themeColorProvider);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: themeColor.primary.withOpacity(_animation.value),
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
