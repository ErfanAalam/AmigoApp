import '../../../db/repositories/user.repo.dart';
import '../../../models/conversations.model.dart';
import '../../../models/group.model.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../types/socket.types.dart';
import '../../../utils/user.utils.dart';
import '../../../ui/snackbar.dart';
import 'dm/dm-media-links-docs.screen.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  final DmModel? dm;
  final GroupModel? group;

  const ChatDetailsScreen({
    super.key,
    this.dm,
    this.group,
  }) : assert(dm != null || group != null, 'Either dm or group must be provided');

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();
  final UserRepository _userRepo = UserRepository();

  bool _isLoading = false;
  UserModel? _recipientUser;
  int? _memberCount;

  bool get isGroup => widget.group != null;
  int get conversationId =>
      widget.dm?.conversationId ?? widget.group!.conversationId;
  ChatType get chatType => isGroup ? ChatType.group : ChatType.dm;

  @override
  void initState() {
    super.initState();
    if (isGroup) {
      _loadGroupInfo();
    } else {
      _loadRecipientInfo();
    }
  }

  Future<void> _loadRecipientInfo() async {
    try {
      // Try to get from chatProvider first (fastest)
      final chatState = ref.read(chatProvider);
      try {
        final dm = chatState.dmList.firstWhere(
          (dm) => dm.conversationId == widget.dm!.conversationId,
        );

        // Use recipient info from DM model
        final user = UserModel(
          id: dm.recipientId,
          name: dm.recipientName,
          phone: dm.recipientPhone,
          profilePic: dm.recipientProfilePic,
          isOnline: dm.isRecipientOnline,
        );
        setState(() {
          _recipientUser = user;
        });
        return;
      } catch (e) {
        // DM not found in provider, continue to fallback
      }

      // Fallback: Get conversation members to find recipient user
      final currentUser = await UserUtils().getUserDetails();
      final currentUserId = currentUser?.id;

      final members = await _conversationMemberRepo
          .getActiveMembersByConversationId(widget.dm!.conversationId);

      if (members.isNotEmpty && currentUserId != null) {
        // Find the recipient user (the one that's not the current user)
        for (final member in members) {
          if (member.userId != currentUserId) {
            final user = await _userRepo.getUserById(member.userId);
            if (user != null) {
              setState(() {
                _recipientUser = user;
              });
              return;
            }
          }
        }
      }

      // If still not found, use first member as fallback
      if (members.isNotEmpty && _recipientUser == null) {
        final user = await _userRepo.getUserById(members.first.userId);
        if (user != null) {
          setState(() {
            _recipientUser = user;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading recipient info: $e');
    }
  }

  Future<void> _loadGroupInfo() async {
    try {
      final members = await _conversationMemberRepo
          .getMembersWithUserDetailsByConversationId(conversationId);
      setState(() {
        _memberCount = members.length;
      });
    } catch (e) {
      debugPrint('❌ Error loading group info: $e');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0][0].toUpperCase();
  }

  String _getGroupInitials() {
    if (widget.group == null) return '?';
    final title = widget.group!.title;
    if (title.isEmpty) return '?';
    final words = title.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0][0].toUpperCase();
  }

  Future<void> _togglePin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isPinned = isGroup
          ? (widget.group!.isPinned ?? false)
          : (widget.dm!.isPinned ?? false);
      final action = isPinned ? 'unpin' : 'pin';

      await ref.read(chatProvider.notifier).handleChatAction(
            action,
            conversationId,
            chatType,
          );

      setState(() => _isLoading = false);

      Snack.show(isPinned ? 'Chat unpinned' : 'Chat pinned to top');
    } catch (e) {
      setState(() => _isLoading = false);
      Snack.error('Failed to update pin status');
    }
  }

  Future<void> _toggleMute() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isMuted = isGroup
          ? (widget.group!.isMuted ?? false)
          : (widget.dm!.isMuted ?? false);
      final action = isMuted ? 'unmute' : 'mute';

      await ref.read(chatProvider.notifier).handleChatAction(
            action,
            conversationId,
            chatType,
          );

      setState(() => _isLoading = false);

      Snack.show(isMuted ? 'Chat unmuted' : 'Chat muted');
    } catch (e) {
      setState(() => _isLoading = false);
      Snack.error('Failed to update mute status');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isFavorite = isGroup
          ? (widget.group!.isFavorite ?? false)
          : (widget.dm!.isFavorite ?? false);
      final action = isFavorite ? 'unfavorite' : 'favorite';

      await ref.read(chatProvider.notifier).handleChatAction(
            action,
            conversationId,
            chatType,
          );

      setState(() => _isLoading = false);

      Snack.show(
        isFavorite ? 'Removed from favorites' : 'Added to favorites',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Snack.error('Failed to update favorite');
    }
  }

  Future<void> _deleteChat() async {
    final chatName = isGroup
        ? widget.group!.title
        : (_recipientUser?.name ?? 'this user');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGroup ? 'Delete Group' : 'Delete Chat'),
        content: Text(
          isGroup
              ? 'Are you sure you want to delete the group "$chatName"?'
              : 'Are you sure you want to delete the chat with $chatName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(chatProvider.notifier).handleChatAction(
              'delete',
              conversationId,
              chatType,
            );

        if (mounted) {
          // Return true to indicate chat was deleted
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          Snack.error('Failed to delete chat');
        }
      }
    }
  }

  void _navigateToMedia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DmMediaLinksDocsScreen(
          dm: widget.dm,
          group: widget.group,
        ),
      ),
    );
  }

  String _getCreatedAt() {
    if (isGroup) {
      return widget.group!.joinedAt;
    } else {
      return widget.dm!.createdAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPinned = isGroup
        ? (widget.group!.isPinned ?? false)
        : (widget.dm!.isPinned ?? false);
    final isMuted = isGroup
        ? (widget.group!.isMuted ?? false)
        : (widget.dm!.isMuted ?? false);
    final isFavorite = isGroup
        ? (widget.group!.isFavorite ?? false)
        : (widget.dm!.isFavorite ?? false);

    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Details'),
        backgroundColor: themeColor.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: themeColor.primaryLight.withAlpha(30),
                  backgroundImage: isGroup
                      ? null
                      : (_recipientUser?.profilePic != null
                          ? CachedNetworkImageProvider(
                              _recipientUser!.profilePic!,
                            )
                          : null),
                  child: isGroup
                      ? Text(
                          _getGroupInitials(),
                          style: TextStyle(
                            color: themeColor.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : (_recipientUser?.profilePic == null
                          ? Text(
                              _getInitials(_recipientUser?.name ?? 'Unknown'),
                              style: TextStyle(
                                color: themeColor.primary,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null),
                ),
                const SizedBox(height: 16),
                Text(
                  isGroup
                      ? widget.group!.title
                      : (_recipientUser?.name ?? 'Unknown'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (isGroup)
                  Text(
                    '$_memberCount ${_memberCount == 1 ? 'member' : 'members'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  )
                else
                  Text(
                    (_recipientUser?.isOnline ?? false) ? 'Online' : 'Offline',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Information section
          _buildInfoTile(
            icon: Icons.info_outline,
            title: isGroup ? 'Joined' : 'Created',
            subtitle: _formatDate(_getCreatedAt()),
          ),
          _buildInfoTile(
            icon: Icons.chat_bubble_outline,
            title: 'Conversation ID',
            subtitle: '$conversationId',
          ),
          if (isGroup && _memberCount != null) ...[
            _buildInfoTile(
              icon: Icons.people_outline,
              title: 'Members',
              subtitle: '$_memberCount',
            ),
          ],
          const Divider(height: 1),
          // Actions section
          _buildActionTile(
            icon: Icons.photo_library_outlined,
            title: 'Media, Links, and Docs',
            onTap: _navigateToMedia,
          ),
          _buildActionTile(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            title: isPinned ? 'Unpin chat' : 'Pin chat',
            onTap: _togglePin,
            isLoading: _isLoading,
          ),
          _buildActionTile(
            icon: isMuted ? Icons.volume_off : Icons.volume_up_outlined,
            title: isMuted ? 'Unmute chat' : 'Mute chat',
            onTap: _toggleMute,
            isLoading: _isLoading,
          ),
          _buildActionTile(
            icon: isFavorite ? Icons.star : Icons.star_border,
            title: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onTap: _toggleFavorite,
            isLoading: _isLoading,
          ),
          _buildActionTile(
            icon: Icons.delete_outline,
            title: isGroup ? 'Delete Group' : 'Delete Chat',
            onTap: _deleteChat,
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final themeColor = ref.watch(themeColorProvider);
    return ListTile(
      leading: Icon(icon, color: themeColor.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    bool isLoading = false,
  }) {
    final themeColor = ref.watch(themeColorProvider);
    return ListTile(
      leading: Icon(icon, color: textColor ?? themeColor.primary),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isLoading ? null : onTap,
    );
  }
}

