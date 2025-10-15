import 'package:flutter/material.dart';
import '../models/conversation_model.dart';

class ChatActionMenu extends StatelessWidget {
  final ConversationModel conversation;
  final Function(String action) onActionSelected;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;

  const ChatActionMenu({
    Key? key,
    required this.conversation,
    required this.onActionSelected,
    this.isPinned = false,
    this.isMuted = false,
    this.isFavorite = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(10),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.teal[100],
                  backgroundImage: conversation.userProfilePic != null
                      ? NetworkImage(conversation.userProfilePic!)
                      : null,
                  child: conversation.userProfilePic == null
                      ? Text(
                          _getInitials(conversation.userName),
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (conversation.metadata?.lastMessage.body != null)
                        Text(
                          conversation.metadata!.lastMessage.body,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Items
          _buildActionItem(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            title: isPinned ? 'Unpin Chat' : 'Pin Chat',
            subtitle: isPinned ? 'Remove from top' : 'Keep at top',
            color: Colors.orange,
            onTap: () => onActionSelected(isPinned ? 'unpin' : 'pin'),
          ),

          _buildDivider(),

          _buildActionItem(
            icon: isMuted ? Icons.volume_up : Icons.volume_off,
            title: isMuted ? 'Unmute Chat' : 'Mute Chat',
            subtitle: isMuted
                ? 'Enable notifications'
                : 'Disable notifications',
            color: Colors.blue,
            onTap: () => onActionSelected(isMuted ? 'unmute' : 'mute'),
          ),

          _buildDivider(),

          _buildActionItem(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            title: isFavorite ? 'Remove Favorite' : 'Add to Favorites',
            subtitle: isFavorite ? 'Remove from favorites' : 'Mark as favorite',
            color: Colors.pink,
            onTap: () =>
                onActionSelected(isFavorite ? 'unfavorite' : 'favorite'),
          ),

          _buildDivider(),

          _buildActionItem(
            icon: Icons.delete_outline,
            title: 'Delete Chat',
            subtitle: 'Move to deleted chats',
            color: Colors.red,
            onTap: () => onActionSelected('delete'),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withAlpha(10)
                    : color.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : color,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey[200],
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }
}

// Bottom Sheet Wrapper for better UX
class ChatActionBottomSheet {
  static Future<String?> show({
    required BuildContext context,
    required ConversationModel conversation,
    required bool isPinned,
    required bool isMuted,
    required bool isFavorite,
  }) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        bottom: true,
        // minimum: EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 40),
        child: ChatActionMenu(
          conversation: conversation,
          isPinned: isPinned,
          isMuted: isMuted,
          isFavorite: isFavorite,
          onActionSelected: (action) {
            Navigator.pop(context, action);
          },
        ),
      ),
    );
  }
}

// Alternative Popup Menu for three-dot menu
class ChatActionPopupMenu extends StatelessWidget {
  final ConversationModel conversation;
  final Function(String action) onActionSelected;
  final bool isPinned;
  final bool isMuted;
  final bool isFavorite;

  const ChatActionPopupMenu({
    Key? key,
    required this.conversation,
    required this.onActionSelected,
    this.isPinned = false,
    this.isMuted = false,
    this.isFavorite = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
      onSelected: onActionSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: isPinned ? 'unpin' : 'pin',
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: Colors.orange,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
            ],
          ),
        ),
        PopupMenuItem(
          value: isMuted ? 'unmute' : 'mute',
          child: Row(
            children: [
              Icon(
                isMuted ? Icons.volume_up : Icons.volume_off,
                color: Colors.blue,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(isMuted ? 'Unmute Chat' : 'Mute Chat'),
            ],
          ),
        ),
        PopupMenuItem(
          value: isFavorite ? 'unfavorite' : 'favorite',
          child: Row(
            children: [
              Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.pink,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(isFavorite ? 'Remove Favorite' : 'Add to Favorites'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Delete Chat', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
