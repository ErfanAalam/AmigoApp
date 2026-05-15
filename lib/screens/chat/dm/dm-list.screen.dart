import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/providers/message.provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app-colors.config.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/chat-prewarm.service.dart';
import '../../../services/user-status.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/app-bar.widget.dart';
// ignore: unused_import
import '../../../ui/chat.action-sheet.dart';
import '../../../ui/blurred-dialog.widget.dart';
import '../../../ui/blurred-popup.widget.dart';
import '../../../ui/chat/searchable-list.widget.dart';
import '../../../ui/chat/user-profile.modal.dart';
import '../../../utils/route-transitions.util.dart';
import '../../contact/contact-list.screen.dart';
import 'dm-messaging.screen.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => ChatsPageState();
}

class ChatsPageState extends ConsumerState<ChatsPage>
    with WidgetsBindingObserver {
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
        .handleChatAction(action, conversation.chatId, ChatType.dm);
  }

  /// Show delete confirmation dialog
  Future<bool?> _showDeleteConfirmation(String userName) {
    return showBlurredConfirm(
      context: context,
      title: 'Delete Chat',
      message:
          'Are you sure you want to delete the chat with $userName? You can restore it from your profile.',
      confirmLabel: 'Delete',
      confirmIcon: Icons.delete_outline,
      destructive: true,
    );
  }

  /// Show chat actions as a blurred popup anchored to the long-pressed row.
  /// Replaces the legacy [ChatActionBottomSheet] sheet — kept on disk for
  /// future reuse but no longer wired.
  Future<void> _showChatActions(
    DmModel conversation,
    BuildContext anchor,
  ) async {
    final isPinned = conversation.isPinned;
    final isMuted = conversation.isMuted;
    final isFavorite = conversation.isFavorite;

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
        const BlurredPopupSeparator(),
        const BlurredPopupAction<String>(
          label: 'Delete Chat',
          icon: Icons.delete_outline,
          value: 'delete',
          style: BlurredPopupActionStyle.destructive,
        ),
      ],
    );

    if (action != null && mounted) {
      await _handleChatAction(action, conversation);
    }
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

    if (state == AppLifecycleState.resumed) {
      ref.read(chatProvider.notifier).setActiveConversation(null, null);
      // Pull any messages missed while in background and refresh WS if needed
      ref.read(chatProvider.notifier).syncOnResume();
    } else if (state == AppLifecycleState.paused) {
      ref.read(chatProvider.notifier).onAppBackground();
    }
  }

  /// Called when the page becomes visible (when user navigates to Chats tab)
  void onPageVisible() {
    // Silently refresh conversations without showing loading state
    ref.read(chatProvider.notifier).loadConvsFromServer(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final view = View.of(context);
    final systemNavInset = view.viewPadding.bottom / view.devicePixelRatio;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AmigoAppBar(
        title: 'AmigoChats',
        actions: [
          AmigoAppBarAction(
            icon: Icons.refresh_rounded,
            onPressed: _refreshConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SearchableListLayout(
        backgroundColor: Colors.white,
        searchBar: SearchableListBar(
          controller: _searchController,
          hintText: 'Search chats',
          onChanged: (value) => _onSearchChanged(),
          onClear: _clearSearch,
        ),
        content: _buildChatsContent(),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsPage()),
              );
            },
            backgroundColor: themeColor.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            tooltip: 'New chat',
            child: const Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
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
    final dmListAsync = ref.watch(dmListStreamProvider);
    // Watch user status stream so this widget rebuilds when online status changes.
    // The actual per-user value is read from UserStatusService in _buildChatsList.
    ref.watch(userStatusStreamProvider);
    // The DM list query watches the chats table only — peer profile/PFP
    // changes write to the users table and don't wake that stream. So when
    // a user:update event arrives we invalidate the provider to recompute
    // the list with the fresh recipient name & profile pic.
    ref.listen<AsyncValue<dynamic>>(userUpdateStreamProvider, (_, next) {
      next.whenData((_) {
        ref.invalidate(dmListStreamProvider);
      });
    });

    return dmListAsync.when(
      loading: () => _buildSkeletonLoader(),
      error: (_, __) {
        // Fallback to provider list on stream error
        final conversationsToShow = chatState.filteredDmList;
        if (conversationsToShow.isEmpty) return _buildEmptyState();
        return _buildChatsList(conversationsToShow);
      },
      data: (allDms) {
        // Apply search filter from provider state
        List<DmModel> conversationsToShow = allDms;
        if (chatState.searchQuery.isNotEmpty) {
          final query = chatState.searchQuery.toLowerCase();
          conversationsToShow = allDms.where((dm) {
            return dm.recipientName.toLowerCase().contains(query) ||
                (dm.lastMsgBody?.toLowerCase().contains(query) ?? false) ||
                dm.recipientPhone.toLowerCase().contains(query);
          }).toList();
        }

        if (conversationsToShow.isEmpty) {
          return chatState.searchQuery.isNotEmpty
              ? _buildSearchEmptyState()
              : _buildEmptyState();
        }

        return _buildChatsList(conversationsToShow);
      },
    );
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

          final typingUsers = chatState.typingConvUsers[conversation.chatId];
          final isTyping = typingUsers != null && typingUsers.isNotEmpty;

          return ChatListItem(
            conversation: conversation,
            isTyping: isTyping,
            isOnline: _userStatusService.isUserOnline(conversation.recipientId),
            isPinned: conversation.isPinned ?? false,
            isMuted: conversation.isMuted ?? false,
            isFavorite: conversation.isFavorite ?? false,
            onLongPress: (anchor) => _showChatActions(conversation, anchor),
            conversationId: conversation.chatId,
            onAvatarTap: () async {
              final result = await UserProfileModal.show(
                context: context,
                dm: DmModel(
                  chatId: conversation.chatId,
                  recipientId: conversation.recipientId,
                  recipientName: conversation.recipientName,
                  recipientPhone: conversation.recipientPhone,
                  recipientProfilePic: conversation.recipientProfilePic,
                  isRecipientOnline: conversation.isRecipientOnline,
                  createdAt: conversation.createdAt,
                  lastMsgAt: conversation.lastMsgAt,
                  lastMsgBody: conversation.lastMsgBody,
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
              // Kick off the first-batch DB read while the route transition
              // animates — by the time the messaging screen's initState
              // runs, the snapshot is usually already resolved, giving an
              // instant first paint instead of waiting on the Drift stream's
              // first emission.
              ChatPrewarm.warmMessages(conversation.chatId);

              // Set this conversation as active and clear unread count
              ref
                  .read(chatProvider.notifier)
                  .setActiveConversation(conversation.chatId, ChatType.dm);

              // Navigate to inner chat page with slide animation
              await Navigator.push(
                context,
                SlideRightRoute(page: InnerChatPage(dm: conversation)),
              );

              // Clear unread count again when returning from inner chat
              ref
                  .read(chatProvider.notifier)
                  .clearUnreadCount(conversation.chatId, ChatType.dm);
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
  // Receives the row's local context so the caller can anchor a blurred
  // popup to the long-pressed row's bounds.
  final void Function(BuildContext anchor)? onLongPress;
  final VoidCallback? onAvatarTap;
  final bool isTyping;
  final String? typingUserName;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;
  final String conversationId;

  const ChatListItem({
    super.key,
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
  });

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
    final themeColor = ref.watch(themeColorProvider);

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
      lastMessageBody = conversation.lastMsgBody ?? 'No messages yet';
      lastMessageType = conversation.lastMsgType;
      attachmentData = null; // DmModel doesn't have attachmentData in metadata
    }

    final lastMessageText = _formatLastMessageText(
      lastMessageBody,
      lastMessageType,
      attachmentData,
    );

    final timeText = conversation.lastMsgAt != null
        ? _formatTime(conversation.lastMsgAt!)
        : _formatTime(conversation.createdAt);

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
      child: Builder(builder: (rowContext) => ListTile(
        leading: GestureDetector(
          onTap: onAvatarTap,
          child: _buildAvatar(themeColor),
        ),
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
            ? _buildTypingIndicator(themeColor)
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
        trailing: _buildUnreadCounts(timeText, hasUnreadMessages, themeColor),
        onTap: onTap,
        onLongPress: onLongPress == null
            ? null
            : () => onLongPress!(rowContext),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      )),
    );
  }

  Widget _buildAvatar(ColorTheme themeColor) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: themeColor.primaryLight.withOpacity(0.3),
          backgroundImage: conversation.recipientProfilePic != null
              ? CachedNetworkImageProvider(conversation.recipientProfilePic!)
              : null,
          child: conversation.recipientProfilePic == null
              ? Text(
                  _getInitials(conversation.recipientName),
                  style: TextStyle(
                    color: themeColor.primary,
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

  Widget _buildTypingIndicator(ColorTheme themeColor) {
    return Row(
      children: [
        Text(
          'Typing',
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

  Widget _buildUnreadCounts(
    String timeText,
    bool hasUnreadMessages,
    ColorTheme themeColor,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(timeText, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        if (hasUnreadMessages) ...[
          const SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: (conversation.unreadCount ?? 0).toString().length <= 2
                  ? 6
                  : 8,
              vertical: 1.3,
            ),
            constraints: const BoxConstraints(minWidth: 20),
            decoration: BoxDecoration(
              color: isMuted ? Colors.grey : themeColor.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (conversation.unreadCount ?? 0).toString(),
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
