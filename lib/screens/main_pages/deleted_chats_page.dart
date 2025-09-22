import 'package:flutter/material.dart';
import '../../services/chat_preferences_service.dart';

class DeletedChatsPage extends StatefulWidget {
  const DeletedChatsPage({Key? key}) : super(key: key);

  @override
  State<DeletedChatsPage> createState() => _DeletedChatsPageState();
}

class _DeletedChatsPageState extends State<DeletedChatsPage> {
  final ChatPreferencesService _chatPreferencesService =
      ChatPreferencesService();
  List<Map<String, dynamic>> _deletedChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedChats();
  }

  Future<void> _loadDeletedChats() async {
    try {
      final deletedChats = await _chatPreferencesService.getDeletedChats();
      if (mounted) {
        setState(() {
          _deletedChats = deletedChats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading deleted chats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreChat(Map<String, dynamic> chatData) async {
    try {
      final conversationId = chatData['conversation_id'] as int;
      await _chatPreferencesService.restoreChat(conversationId);

      setState(() {
        _deletedChats.removeWhere(
          (chat) => chat['conversation_id'] == conversationId,
        );
      });

      _showSnackBar('Chat restored successfully', Colors.green);
    } catch (e) {
      debugPrint('❌ Error restoring chat: $e');
      _showSnackBar('Failed to restore chat', Colors.red);
    }
  }

  Future<void> _permanentlyDeleteChat(Map<String, dynamic> chatData) async {
    final userName = chatData['userName'] ?? chatData['user_name'] ?? 'Unknown';
    final shouldDelete = await _showPermanentDeleteConfirmation(userName);
    if (shouldDelete == true) {
      setState(() {
        _deletedChats.removeWhere(
          (chat) => chat['conversation_id'] == chatData['conversation_id'],
        );
      });
      _showSnackBar('Chat permanently deleted', Colors.red);
    }
  }

  Future<bool?> _showPermanentDeleteConfirmation(String userName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Permanently Delete'),
        content: Text(
          'Are you sure you want to permanently delete the chat with $userName? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );
  }

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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Deleted Chats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey[50],
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _deletedChats.isEmpty
            ? _buildEmptyState()
            : _buildDeletedChatsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No deleted chats',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Deleted chats will appear here',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedChatsList() {
    return RefreshIndicator(
      onRefresh: _loadDeletedChats,
      child: ListView.builder(
        itemCount: _deletedChats.length,
        itemBuilder: (context, index) {
          final chatData = _deletedChats[index];
          return _buildDeletedChatItem(chatData);
        },
      ),
    );
  }

  Widget _buildDeletedChatItem(Map<String, dynamic> chatData) {
    // Debug logging to understand the data structure
    debugPrint('🔍 Deleted chat data: $chatData');

    final userName =
        chatData['userName'] ?? chatData['user_name'] ?? 'Unknown User';
    final userProfilePic =
        chatData['userProfilePic'] ?? chatData['user_profile_pic'];
    final deletedAt = chatData['deleted_at'] ?? '';
    final lastMessage = chatData['metadata']?['last_message'];
    final lastMessageText = lastMessage?['body'] ?? 'No messages';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[200],
          backgroundImage: userProfilePic != null
              ? NetworkImage(userProfilePic)
              : null,
          child: userProfilePic == null
              ? Text(
                  _getInitials(userName),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.delete, size: 16, color: Colors.red[300]),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              lastMessageText,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              'Deleted ${_formatDate(deletedAt)}',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          onSelected: (action) {
            if (action == 'restore') {
              _restoreChat(chatData);
            } else if (action == 'delete_permanently') {
              _permanentlyDeleteChat(chatData);
            }
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(Icons.restore, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Text('Restore Chat'),
                ],
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete_permanently',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Delete Permanently',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          // Show restore dialog
          final displayUserName =
              chatData['userName'] ?? chatData['user_name'] ?? 'Unknown User';
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text('Restore Chat'),
              content: Text(
                'Would you like to restore the chat with $displayUserName?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _restoreChat(chatData);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                  child: Text('RESTORE'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
