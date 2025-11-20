import 'package:amigo/models/conversations.model.dart';
import 'package:flutter/material.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../services/user_status_service.dart';
import '../../../widgets/chat_action_menu.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/chat/searchable_list_widget.dart';
import '../../../providers/draft_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../types/socket.type.dart';
import '../../../widgets/chat/user_profile_modal.dart';
import 'messaging.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => ChatsPageState();
}

class ChatsPageState extends ConsumerState<ChatsPage>
    with WidgetsBindingObserver {
  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
  }

  /// Handle search text changes
  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(chatProvider.notifier).updateSearchQuery(query);
  }

  /// Clear search query
  void _clearSearch() {
    _searchController.clear();
    ref.read(chatProvider.notifier).updateSearchQuery('');
  }

  /// Handle chat action (pin, mute, favorite, delete)
  Future<void> _handleChatAction(String action, DmModel conversation) async {
    // Show delete confirmation if needed
    if (action == 'delete') {
      final shouldDelete = await _showDeleteConfirmation(
        conversation.recipientName,
      );
      if (shouldDelete != true) {
        return;
      }
    }

    await ref
        .read(chatProvider.notifier)
        .handleChatAction(action, conversation.conversationId, ChatType.dm);
    // Show snackbar feedback
    switch (action) {
      case 'pin':
        _showSnackBar('Chat pinned to top', Colors.orange);
        break;
      case 'unpin':
        _showSnackBar('Chat unpinned', Colors.grey);
        break;
      case 'mute':
        _showSnackBar('Chat muted', Colors.blue);
        break;
      case 'unmute':
        _showSnackBar('Chat unmuted', Colors.blue);
        break;
      case 'favorite':
        _showSnackBar('Added to favorites', Colors.pink);
        break;
      case 'unfavorite':
        _showSnackBar('Removed from favorites', Colors.grey);
        break;
      case 'delete':
        _showSnackBar('Chat deleted', Colors.teal);
        break;
    }
  }

  /// Show delete confirmation dialog
  Future<bool?> _showDeleteConfirmation(String userName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete the chat with $userName? You can restore it from your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  /// Show chat actions bottom sheet
  Future<void> _showChatActions(DmModel conversation) async {
    final chatState = ref.read(chatProvider);
    final action = await ChatActionBottomSheet.show(
      context: context,
      dm: conversation,
      isPinned: chatState.pinnedChats.contains(conversation.conversationId),
      isMuted: chatState.mutedChats.contains(conversation.conversationId),
      isFavorite: chatState.favoriteChats.contains(conversation.conversationId),
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

  void _refreshConversations() {
    ref.read(chatProvider.notifier).loadConvsFromServer();
  }

  // All state management and WebSocket handling is now done by dmListProvider

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    // Clear active conversation
    ref.read(chatProvider.notifier).setActiveConversation(null, null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes back to foreground, clear active conversation
    if (state == AppLifecycleState.resumed) {
      ref.read(chatProvider.notifier).setActiveConversation(null, null);
    }
  }

  /// Called when the page becomes visible (when user navigates to Chats tab)
  void onPageVisible() {
    // Silently refresh conversations without showing loading state
    ref.read(chatProvider.notifier).loadConvsFromServer(silent: true);
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
                onPressed: () => _refreshConversations(),
              ),
            ),
          ],
        ),
      ),

      body: SearchableListLayout(
        searchBar: SearchableListBar(
          controller: _searchController,
          hintText: 'Search chats',
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
    final chatState = ref.watch(chatProvider);

    // Show loading skeleton while loading
    if (chatState.isLoading) {
      return _buildSkeletonLoader();
    }

    // Get filtered conversations from provider
    final conversationsToShow = chatState.filteredConversations;

    // Show empty state if no conversations
    if (conversationsToShow.isEmpty) {
      return chatState.searchQuery.isNotEmpty
          ? _buildSearchEmptyState()
          : _buildEmptyState();
    }

    // Show the conversations list
    return _buildChatsList(conversationsToShow);
  }

  Widget _buildChatsList(List<DmModel> conversations) {
    final chatState = ref.watch(chatProvider);

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
          if (conversation.recipientName.isEmpty) {
            return Container(); // Skip invalid conversations
          }

          final typingUserIds =
              chatState.typingConvUsers[conversation.conversationId] ?? [];
          final isTyping = typingUserIds.isNotEmpty;

          return ChatListItem(
            conversation: conversation,
            isTyping: isTyping,
            isOnline: _userStatusService.isUserOnline(conversation.recipientId),
            isPinned: chatState.pinnedChats.contains(
              conversation.conversationId,
            ),
            isMuted: chatState.mutedChats.contains(conversation.conversationId),
            isFavorite: chatState.favoriteChats.contains(
              conversation.conversationId,
            ),
            onLongPress: () => _showChatActions(conversation),
            conversationId: conversation.conversationId,
            onAvatarTap: () async {
              final result = await UserProfileModal.show(
                context: context,
                conversation: ConversationModel(
                  id: conversation.conversationId,
                  type: 'dm',
                  createrId: conversation.recipientId,
                  pinnedMessageId: null,
                  createdAt: conversation.createdAt,
                ),
                isOnline: _userStatusService.isUserOnline(
                  conversation.recipientId,
                ),
              );
              // If chat was deleted, refresh the list
              if (result == true && mounted) {
                _refreshConversations();
              }
            },
            onTap: () async {
              // Set this conversation as active and clear unread count
              ref
                  .read(chatProvider.notifier)
                  .setActiveConversation(
                    conversation.conversationId,
                    ChatType.dm,
                  );

              // Navigate to inner chat page
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InnerChatPage(dm: conversation),
                ),
              );

              // Clear unread count again when returning from inner chat
              ref
                  .read(chatProvider.notifier)
                  .clearUnreadCount(conversation.conversationId, ChatType.dm);

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
              ref.read(chatProvider.notifier).setActiveConversation(null, null);
            },
          );
        },
      ),
    );
  }
}

class ChatListItem extends ConsumerWidget {
  final DmModel conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;
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
    this.onAvatarTap,
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

    final hasUnreadMessages = (conversation.unreadCount ?? 0) > 0 && !isMuted;

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
      lastMessageBody = conversation.lastMessageBody ?? 'No messages yet';
      lastMessageType = conversation.lastMessageType;
      attachmentData = null; // DmModel doesn't have attachmentData in metadata
    }

    final lastMessageText = _formatLastMessageText(
      lastMessageBody,
      lastMessageType,
      attachmentData,
    );
    final timeText = conversation.lastMessageAt != null
        ? _formatTime(conversation.lastMessageAt!)
        : _formatTime(conversation.createdAt);

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
        leading: GestureDetector(onTap: onAvatarTap, child: _buildAvatar()),
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
                conversation.recipientName,
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
                      ? Colors.green[600]
                      : (isMuted ? Colors.grey[400] : Colors.grey[600]),
                  fontSize: 14,
                  fontStyle: FontStyle.normal,
                  fontWeight: draft != null && draft.isNotEmpty
                      ? FontWeight.w600
                      : FontWeight.normal,
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
          backgroundImage: conversation.recipientProfilePic != null
              ? CachedNetworkImageProvider(conversation.recipientProfilePic!)
              : null,
          child: conversation.recipientProfilePic == null
              ? Text(
                  _getInitials(conversation.recipientName),
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        // Online status indicator - only show for DM conversations
        if (isOnline)
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
              color: isMuted
                  ? Colors.grey
                  : const Color.fromARGB(255, 9, 117, 103),
              shape: BoxShape.circle,
            ),
            child: Text(
              (conversation.unreadCount ?? 0).toString(),
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
