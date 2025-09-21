import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../api/user.service.dart';
import 'inner_chat_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({Key? key}) : super(key: key);

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final UserService _userService = UserService();
  late Future<List<ConversationModel>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _loadConversations();
  }

  Future<List<ConversationModel>> _loadConversations() async {
    try {
      final response = await _userService.GetChatList('dm');

      if (response['success']) {
        final dynamic responseData = response['data'];
        List<dynamic> conversationsList = [];

        if (responseData is List) {
          conversationsList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            conversationsList = responseData['data'] as List<dynamic>;
          } else {
            for (var key in responseData.keys) {
              if (responseData[key] is List) {
                conversationsList = responseData[key] as List<dynamic>;
                break;
              }
            }
          }
        }

        if (conversationsList.isNotEmpty) {
          // Process data in background to avoid blocking UI
          return await _processConversationsAsync(conversationsList);
        } else {
          throw Exception('No conversation data found in response');
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to load conversations');
      }
    } catch (e) {
      throw Exception('Error loading conversations: ${e.toString()}');
    }
  }

  Future<List<ConversationModel>> _processConversationsAsync(
    List<dynamic> conversationsList,
  ) async {
    // Process data in chunks to prevent UI blocking
    const chunkSize = 10;
    List<ConversationModel> processedConversations = [];

    for (int i = 0; i < conversationsList.length; i += chunkSize) {
      final end = (i + chunkSize < conversationsList.length)
          ? i + chunkSize
          : conversationsList.length;
      final chunk = conversationsList.sublist(i, end);

      final chunkProcessed = chunk
          .map(
            (json) => ConversationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      processedConversations.addAll(chunkProcessed);

      // Allow other operations to run
      if (i + chunkSize < conversationsList.length) {
        await Future.delayed(Duration.zero);
      }
    }

    return processedConversations;
  }

  void _refreshConversations() {
    setState(() {
      _conversationsFuture = _loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40, // Reduce leading width to minimize gap
        leading: Padding(
          padding: EdgeInsets.only(left: 16), // Add some left padding
          child: Icon(Icons.chat, color: Colors.white),
        ),
        titleSpacing: 8,
        title: Text(
          'Chats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Implement more options
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

            // Chats List
            Expanded(
              child: FutureBuilder<List<ConversationModel>>(
                future: _conversationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader();
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  } else {
                    return _buildChatsList(snapshot.data!);
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement new chat functionality
        },
        backgroundColor: Colors.teal,
        child: Icon(Icons.chat, color: Colors.white),
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshConversations,
            child: const Text('Retry'),
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

  Widget _buildChatsList(List<ConversationModel> conversations) {
    return RefreshIndicator(
      onRefresh: () async => _refreshConversations(),
      child: ListView.builder(
        itemCount: conversations.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return ChatListItem(
            conversation: conversation,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      InnerChatPage(conversation: conversation),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const ChatListItem({
    Key? key,
    required this.conversation,
    required this.onTap,
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
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnreadMessages = conversation.unreadCount > 0;
    final lastMessageText =
        conversation.metadata?.lastMessage.body ?? 'No messages yet';
    final timeText = conversation.metadata != null
        ? _formatTime(conversation.metadata!.lastMessage.createdAt)
        : _formatTime(conversation.joinedAt);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: ListTile(
        leading: _buildAvatar(),
        title: Text(
          conversation.userName,
          style: TextStyle(
            fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          lastMessageText,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _buildTrailing(timeText, hasUnreadMessages),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.teal[100],
      backgroundImage: conversation.userProfilePic != null
          ? NetworkImage(conversation.userProfilePic!)
          : null,
      child: conversation.userProfilePic == null
          ? Text(
              _getInitials(conversation.userName),
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,
    );
  }

  Widget _buildTrailing(String timeText, bool hasUnreadMessages) {
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
              color: Colors.teal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              conversation.unreadCount.toString(),
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
