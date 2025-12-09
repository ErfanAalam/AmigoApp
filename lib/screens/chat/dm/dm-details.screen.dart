import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../types/socket.types.dart';
import '../../../utils/user.utils.dart';

class DmDetailsScreen extends ConsumerStatefulWidget {
  final DmModel dm;

  const DmDetailsScreen({super.key, required this.dm});

  @override
  ConsumerState<DmDetailsScreen> createState() => _DmDetailsScreenState();
}

class _DmDetailsScreenState extends ConsumerState<DmDetailsScreen> {
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();
  final UserRepository _userRepo = UserRepository();

  bool _isLoading = false;
  UserModel? _recipientUser;

  @override
  void initState() {
    super.initState();
    _loadRecipientInfo();
  }

  Future<void> _loadRecipientInfo() async {
    try {
      // Try to get from chatProvider first (fastest)
      final chatState = ref.read(chatProvider);
      try {
        final dm = chatState.dmList.firstWhere(
          (dm) => dm.conversationId == widget.dm.conversationId,
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
          .getActiveMembersByConversationId(widget.dm.conversationId);

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

  Future<void> _togglePin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isPinned = widget.dm.isPinned ?? false;
      final action = isPinned ? 'unpin' : 'pin';

      await ref
          .read(chatProvider.notifier)
          .handleChatAction(action, widget.dm.conversationId, ChatType.dm);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned to top'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update pin status')),
      );
    }
  }

  Future<void> _toggleMute() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isMuted = widget.dm.isMuted ?? false;
      final action = isMuted ? 'unmute' : 'mute';

      await ref
          .read(chatProvider.notifier)
          .handleChatAction(action, widget.dm.conversationId, ChatType.dm);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMuted ? 'Chat unmuted' : 'Chat muted'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update mute status')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isFavorite = widget.dm.isFavorite ?? false;
      final action = isFavorite ? 'unfavorite' : 'favorite';

      await ref
          .read(chatProvider.notifier)
          .handleChatAction(action, widget.dm.conversationId, ChatType.dm);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Removed from favorites' : 'Added to favorites',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update favorite')),
      );
    }
  }

  Future<void> _deleteChat() async {
    final recipientName = _recipientUser?.name ?? 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete the chat with $recipientName?',
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
        await ref
            .read(chatProvider.notifier)
            .handleChatAction('delete', widget.dm.conversationId, ChatType.dm);

        if (mounted) {
          // Return true to indicate chat was deleted
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete chat')),
          );
        }
      }
    }
  }

  void _navigateToMedia() {
    // TODO: Navigate to media messages screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Media messages feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPinned = widget.dm.isPinned ?? false;
    final isMuted = widget.dm.isMuted ?? false;
    final isFavorite = widget.dm.isFavorite ?? false;
    final recipientName = _recipientUser?.name ?? 'Unknown';
    final recipientProfilePic = _recipientUser?.profilePic;
    final isOnline = _recipientUser?.isOnline ?? false;

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
                  backgroundColor: themeColor.primaryLight.withOpacity(0.3),
                  backgroundImage: recipientProfilePic != null
                      ? CachedNetworkImageProvider(recipientProfilePic)
                      : null,
                  child: recipientProfilePic == null
                      ? Text(
                          _getInitials(recipientName),
                          style: TextStyle(
                            color: themeColor.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  recipientName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Information section
          _buildInfoTile(
            icon: Icons.info_outline,
            title: 'Created',
            subtitle: _formatDate(widget.dm.createdAt),
          ),
          _buildInfoTile(
            icon: Icons.chat_bubble_outline,
            title: 'Conversation ID',
            subtitle: '${widget.dm.conversationId}',
          ),
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
            title: 'Delete Chat',
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
