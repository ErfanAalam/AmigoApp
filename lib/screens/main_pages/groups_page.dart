import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../api/user.service.dart';
import 'inner_group_chat_page.dart';
import 'create_group_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({Key? key}) : super(key: key);

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final UserService _userService = UserService();
  late Future<List<GroupModel>> _groupsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<GroupModel> _allGroups = [];
  List<GroupModel> _filteredGroups = [];

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = List.from(_allGroups);
      } else {
        _filteredGroups = _allGroups.where((group) {
          return group.title.toLowerCase().contains(query) ||
              group.members.any(
                (member) => member.name.toLowerCase().contains(query),
              );
        }).toList();
      }
    });
  }

  Future<List<GroupModel>> _loadGroups() async {
    try {
      final response = await _userService.GetChatList('group');

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

        // Filter only group conversations and convert to GroupModel
        final groups = conversationsList
            .where((json) => json['type'] == 'group')
            .map((json) => _convertToGroupModel(json))
            .toList();

        setState(() {
          _allGroups = groups;
          _filteredGroups = List.from(groups);
        });

        return groups;
      } else {
        throw Exception(response['message'] ?? 'Failed to load groups');
      }
    } catch (e) {
      throw Exception('Error loading groups: ${e.toString()}');
    }
  }

  GroupModel _convertToGroupModel(Map<String, dynamic> json) {
    // Convert conversation data to group model
    // This assumes the backend returns group members and metadata
    return GroupModel(
      conversationId: json['conversationId'] ?? 0,
      title: json['title'] ?? 'Unnamed Group',
      type: json['type'] ?? 'group',
      members: _parseMembers(json['members']),
      metadata: json['metadata'] != null
          ? GroupMetadata.fromJson(json['metadata'])
          : null,
      lastMessageAt: json['lastMessageAt'],
      role: json['role'],
      unreadCount: json['unreadCount'] ?? 0,
      joinedAt: json['joinedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  List<GroupMember> _parseMembers(dynamic membersData) {
    if (membersData == null) return [];

    if (membersData is List) {
      return membersData.map((member) => GroupMember.fromJson(member)).toList();
    }

    return [];
  }

  void _refreshGroups() {
    setState(() {
      _groupsFuture = _loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40, // Reduce leading width to minimize gap
        leading: Padding(
          padding: EdgeInsets.only(left: 16), // Add some left padding
          child: Icon(Icons.group, color: Colors.white),
        ),
        titleSpacing: 8,
        title: Text(
          'Groups',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
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
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search groups...',
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

            // Groups List
            Expanded(
              child: FutureBuilder<List<GroupModel>>(
                future: _groupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader();
                  } else if (!snapshot.hasData || _filteredGroups.isEmpty) {
                    return _buildEmptyState();
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  } else {
                    return _buildGroupsList();
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to create group page
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupPage()),
          );

          // If a group was created, refresh the groups list
          if (result == true) {
            _refreshGroups();
          }
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.group_add, color: Colors.white),
      ),
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
          ElevatedButton(onPressed: _refreshGroups, child: const Text('Retry')),
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
            'No groups yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group to start chatting',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return RefreshIndicator(
      onRefresh: () async => _refreshGroups(),
      child: ListView.builder(
        itemCount: _filteredGroups.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final group = _filteredGroups[index];
          return GroupListItem(
            group: group,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InnerGroupChatPage(group: group),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GroupListItem extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;

  const GroupListItem({Key? key, required this.group, required this.onTap})
    : super(key: key);

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
    final hasUnreadMessages = group.unreadCount > 0;
    final lastMessageText =
        group.metadata?.lastMessage?.body ?? 'No messages yet';
    final timeText = _formatTime(group.lastMessageAt ?? group.joinedAt);
    final memberCountText = '${group.memberCount} members';

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.green[100],
          child: Icon(Icons.group, color: Colors.green, size: 24),
        ),
        title: Text(
          group.title,
          style: TextStyle(
            fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastMessageText,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              memberCountText,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeText,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (hasUnreadMessages) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  group.unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
