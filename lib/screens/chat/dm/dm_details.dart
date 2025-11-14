import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/conversation_model.dart';
import '../../../services/chat_preferences_service.dart';
import '../../../api/chats.services.dart';
import '../../../db/repositories/conversations_repository.dart';

class DmDetailsScreen extends StatefulWidget {
  final ConversationModel conversation;

  const DmDetailsScreen({super.key, required this.conversation});

  @override
  State<DmDetailsScreen> createState() => _DmDetailsScreenState();
}

class _DmDetailsScreenState extends State<DmDetailsScreen> {
  final ChatPreferencesService _chatPreferencesService =
      ChatPreferencesService();
  final ChatsServices _chatsServices = ChatsServices();
  final ConversationsRepository _conversationsRepo = ConversationsRepository();

  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final favorites = await _chatPreferencesService.getFavoriteChats();
    setState(() {
      _isFavorite = favorites.contains(widget.conversation.conversationId);
    });
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

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_isFavorite) {
        await _chatPreferencesService.unfavoriteChat(
          widget.conversation.conversationId,
        );
      } else {
        await _chatPreferencesService.favoriteChat(
          widget.conversation.conversationId,
        );
      }
      setState(() {
        _isFavorite = !_isFavorite;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Added to favorites' : 'Removed from favorites',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete the chat with ${widget.conversation.userName}?',
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
        final response = await _chatsServices.deleteDm(
          widget.conversation.conversationId,
        );

        if (response['success']) {
          await _chatPreferencesService.deleteChat(
            widget.conversation.conversationId,
            widget.conversation.toJson(),
          );
          await _conversationsRepo.deleteConversation(
            widget.conversation.conversationId,
          );

          if (mounted) {
            // Return true to indicate chat was deleted
            Navigator.pop(context, true);
          }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Details'),
        backgroundColor: Colors.teal,
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
                  backgroundColor: Colors.teal[100],
                  backgroundImage: widget.conversation.userProfilePic != null
                      ? CachedNetworkImageProvider(
                          widget.conversation.userProfilePic!,
                        )
                      : null,
                  child: widget.conversation.userProfilePic == null
                      ? Text(
                          _getInitials(widget.conversation.userName),
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.conversation.userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.conversation.isOnline == true ? 'Online' : 'Offline',
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
            subtitle: _formatDate(widget.conversation.joinedAt),
          ),
          _buildInfoTile(
            icon: Icons.chat_bubble_outline,
            title: 'Conversation ID',
            subtitle: '${widget.conversation.conversationId}',
          ),
          const Divider(height: 1),
          // Actions section
          _buildActionTile(
            icon: Icons.photo_library_outlined,
            title: 'Media, Links, and Docs',
            onTap: _navigateToMedia,
          ),
          _buildActionTile(
            icon: _isFavorite ? Icons.star : Icons.star_border,
            title: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
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
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
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
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.teal),
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
