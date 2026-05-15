import 'package:amigo/providers/message.provider.dart';
import 'package:amigo/types/chat.types.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app-colors.config.dart';
import '../../../models/community.model.dart';
import '../../../models/group.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/chat-prewarm.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/app-bar.widget.dart';
// ignore: unused_import
import '../../../ui/chat.action-sheet.dart';
import '../../../ui/blurred-popup.widget.dart';
import '../../../ui/chat/searchable-list.widget.dart';
import '../../../utils/route-transitions.util.dart';
import 'community-group-list.screen.dart';
import 'create-group.screen.dart';
import 'group-messaging.screen.dart';

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

  /// Show group chat actions as a blurred popup anchored to the long-pressed
  /// row. Replaces the legacy [ChatActionBottomSheet] sheet — kept on disk
  /// for future reuse but no longer wired.
  Future<void> _showGroupChatActions(
    GroupModel group,
    BuildContext anchor,
  ) async {
    final isPinned = group.isPinned;
    final isMuted = group.isMuted;
    final isFavorite = group.isFavorite;

    final overlayBox =
        Navigator.of(anchor).overlay?.context.findRenderObject() as RenderBox?;
    final box = anchor.findRenderObject() as RenderBox?;
    if (overlayBox == null || box == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlayBox),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlayBox,
        ),
      ),
      Offset.zero & overlayBox.size,
    );

    final action = await showBlurredPopup<String>(
      context: anchor,
      position: position,
      scaleAlignment: Alignment.topCenter,
      items: [
        BlurredPopupAction<String>(
          label: isPinned ? 'Unpin Chat' : 'Pin Chat',
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          value: isPinned ? 'unpin' : 'pin',
        ),
        BlurredPopupAction<String>(
          label: isMuted ? 'Unmute Chat' : 'Mute Chat',
          icon: isMuted ? Icons.volume_up : Icons.volume_off,
          value: isMuted ? 'unmute' : 'mute',
        ),
        BlurredPopupAction<String>(
          label: isFavorite ? 'Remove Favorite' : 'Add to Favorites',
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          value: isFavorite ? 'unfavorite' : 'favorite',
        ),
      ],
    );

    if (action != null && mounted) {
      await _handleGroupChatAction(action, group);
    }
  }

  /// Handle group chat action
  Future<void> _handleGroupChatAction(String action, GroupModel group) async {
    await ref
        .read(chatProvider.notifier)
        .handleChatAction(action, group.chatId, ChatType.group);
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
    final view = View.of(context);
    final systemNavInset = view.viewPadding.bottom / view.devicePixelRatio;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AmigoAppBar(
        title: 'Groups',
        actions: [
          AmigoAppBarAction(
            icon: Icons.refresh_rounded,
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SearchableListLayout(
        backgroundColor: Colors.white,
        searchBar: SearchableListBar(
          controller: _searchController,
          hintText: 'Search groups...',
          onChanged: (value) => _onSearchChanged(),
        ),
        content: _buildContent(),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 80 + systemNavInset),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(180),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupPage(),
                ),
              );
              if (result == true) {
                _refreshData();
              }
            },
            backgroundColor: themeColor.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            tooltip: 'New group',
            child: const Icon(
              Icons.add_comment_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final chatState = ref.watch(chatProvider);
    final groupListAsync = ref.watch(groupListStreamProvider);

    return groupListAsync.when(
      loading: () => _buildSkeletonLoader(),
      error: (_, __) {
        // Fallback to provider list on stream error
        final filteredItems = chatState.filteredGroupItems;
        if (filteredItems.isEmpty) return _buildEmptyState();
        return _buildItemsList(filteredItems);
      },
      data: (groups) {
        // Merge with communities from chatState (not yet in Drift stream)
        final communities = chatState.communities;

        // Apply search filter
        List<dynamic> filteredItems;
        if (chatState.searchQuery.isNotEmpty) {
          final query = chatState.searchQuery.toLowerCase();
          final filteredGroups = groups
              .where((g) => g.title.toLowerCase().contains(query))
              .toList();
          final filteredCommunities = communities
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();
          filteredItems = [...filteredGroups, ...filteredCommunities];
        } else {
          filteredItems = [...groups, ...communities];
        }

        if (filteredItems.isEmpty) return _buildEmptyState();
        return _buildItemsList(filteredItems);
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
                chatState.typingConvUsers[item.chatId] ?? <TypingUser>{};

            return GroupListItem(
              group: item,
              typingUsers: typingUsers,
              conversationId: item.chatId,
              isPinned: item.isPinned ?? false,
              isMuted: item.isMuted ?? false,
              isFavorite: item.isFavorite ?? false,
              onLongPress: (anchor) => _showGroupChatActions(item, anchor),
              onTap: () async {
                // Kick off the first-batch DB read while the route
                // transition animates so the screen has a snapshot ready
                // by the time its initState runs.
                ChatPrewarm.warmMessages(item.chatId);

                // Set this group as active and clear unread count
                ref
                    .read(chatProvider.notifier)
                    .setActiveConversation(item.chatId, ChatType.group);

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
                    .clearUnreadCount(item.chatId, ChatType.group);

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
  // Receives the row's local context so the caller can anchor a blurred
  // popup to the long-pressed row's bounds.
  final void Function(BuildContext anchor)? onLongPress;
  final Set<TypingUser> typingUsers;
  final String conversationId;
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
      if (group.lastMsgId != null &&
          group.lastMsgAt != null &&
          group.lastMsgType != null) {
        lastMessageText = _formatLastMessageText(
          group.lastMsgBody ?? '',
          group.lastMsgType,
          group.metadata?.lastMessage?.attachmentData,
        );
      }
    }

    final timeText = _formatTime(group.lastMsgAt ?? group.joinedAt);
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
          // bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
          left: isPinned
              ? BorderSide(color: Colors.orange, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Builder(builder: (rowContext) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress == null
            ? null
            : () => onLongPress!(rowContext),
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
                    // const SizedBox(height: 4),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: group.unreadCount.toString().length <= 2
                            ? 6
                            : 8,
                        vertical: 1.3,
                      ),
                      constraints: const BoxConstraints(minWidth: 20),
                      decoration: BoxDecoration(
                        color: themeColor.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        group.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      )),
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
