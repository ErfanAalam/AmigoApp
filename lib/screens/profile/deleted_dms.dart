import 'package:amigo/config/app_colors.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/chats.services.dart';
import '../../api/user.service.dart';
import '../../models/conversations.model.dart';
import '../../providers/theme_color_provider.dart';
import '../../types/socket.type.dart';

class DeletedChatsPage extends ConsumerStatefulWidget {
  const DeletedChatsPage({super.key});

  @override
  ConsumerState<DeletedChatsPage> createState() => _DeletedChatsPageState();
}

class _DeletedChatsPageState extends ConsumerState<DeletedChatsPage> {
  final ConversationRepository _conversationRepo = ConversationRepository();
  final ChatsServices _chatsServices = ChatsServices();
  final UserService _userService = UserService();
  List<dynamic> _deletedChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedChats();
  }

  Future<void> _loadDeletedChats() async {
    try {
      final deletedChats = await _userService.getChatList('deleted_dm');

      if (mounted) {
        setState(() {
          _deletedChats = deletedChats['data'];
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
      final conversationId = chatData['conversationId'] as int;
      await _conversationRepo.markAsDeleted(conversationId, false);
      await _chatsServices.reviveChat(conversationId);

      if (mounted) {
        setState(() {
          _deletedChats.removeWhere(
            (chat) => chat['conversationId'] == conversationId,
          );
        });

        // update the UI
        ref
            .read(chatProvider.notifier)
            .toggleDeleteChat(conversationId, ChatType.dm);

        _showSnackBar('Chat restored successfully', Colors.green);
      }
    } catch (e) {
      debugPrint('❌ Error restoring chat: $e');
      if (mounted) {
        _showSnackBar('Failed to restore chat', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error showing snackbar: $e');
    }
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
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Deleted Chats',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState(themeColor)
          : _deletedChats.isEmpty
          ? _buildEmptyState()
          : _buildDeletedChatsList(themeColor),
    );
  }

  Widget _buildLoadingState(ColorTheme themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(themeColor.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading deleted chats...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Deleted Chats',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chats you delete will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'You can restore them anytime',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedChatsList(ColorTheme themeColor) {
    return RefreshIndicator(
      onRefresh: _loadDeletedChats,
      color: themeColor.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _deletedChats.length,
        itemBuilder: (context, index) {
          final chatData = _deletedChats[index];
          return _buildDeletedChatItem(chatData, themeColor);
        },
      ),
    );
  }

  Widget _buildDeletedChatItem(
    Map<String, dynamic> chatData,
    ColorTheme themeColor,
  ) {
    final userName =
        chatData['userName'] ?? chatData['user_name'] ?? 'Unknown User';
    final userProfilePic =
        chatData['userProfilePic'] ?? chatData['user_profile_pic'];
    final deletedAt = chatData['deleted_at'] ?? '';
    final lastMessage = chatData['metadata']?['last_message'];
    final lastMessageText = lastMessage?['body'] ?? 'No messages';
    final lastMessageType = lastMessage?['type'] ?? 'text';

    // Format last message based on type
    String displayMessage = lastMessageText;
    if (lastMessageText.isEmpty || lastMessageText == 'No messages') {
      switch (lastMessageType) {
        case 'image':
          displayMessage = '📷 Photo';
          break;
        case 'video':
          displayMessage = '📹 Video';
          break;
        case 'audio':
        case 'audios':
          displayMessage = '🎵 Audio';
          break;
        case 'document':
          displayMessage = '📎 Document';
          break;
        default:
          displayMessage = 'No messages';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRestoreDialog(chatData, themeColor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with deleted indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: themeColor.primaryLight.withOpacity(0.3),
                      backgroundImage: userProfilePic != null
                          ? CachedNetworkImageProvider(userProfilePic)
                          : null,
                      child: userProfilePic == null
                          ? Text(
                              _getInitials(userName),
                              style: TextStyle(
                                color: themeColor.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.red[500],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Deleted',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayMessage,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Restore button
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeColor.primaryLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.restore_rounded,
                      color: themeColor.primary,
                      size: 20,
                    ),
                  ),
                  onPressed: () => _showRestoreDialog(chatData, themeColor),
                  tooltip: 'Restore chat',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRestoreDialog(
    Map<String, dynamic> chatData,
    ColorTheme themeColor,
  ) {
    final displayUserName =
        chatData['userName'] ?? chatData['user_name'] ?? 'Unknown User';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restore_rounded, color: themeColor.primary, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Restore Chat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Would you like to restore the chat with $displayUserName?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreChat(chatData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Restore',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
