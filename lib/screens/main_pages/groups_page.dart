import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/community_model.dart';
import '../../api/user.service.dart';
import 'inner_group_chat_page.dart';
import 'create_group_page.dart';
import 'community_inner_groups_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({Key? key}) : super(key: key);

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final UserService _userService = UserService();
  late Future<Map<String, dynamic>> _dataFuture;
  final TextEditingController _searchController = TextEditingController();
  List<GroupModel> _allGroups = [];
  List<CommunityModel> _allCommunities = [];
  List<dynamic> _filteredItems = []; // Can contain both groups and communities

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadGroupsAndCommunities();
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
        _filteredItems = [..._allGroups, ..._allCommunities];
      } else {
        final filteredGroups = _allGroups.where((group) {
          return group.title.toLowerCase().contains(query) ||
              group.members.any(
                (member) => member.name.toLowerCase().contains(query),
              );
        }).toList();

        final filteredCommunities = _allCommunities.where((community) {
          return community.name.toLowerCase().contains(query);
        }).toList();

        _filteredItems = [...filteredGroups, ...filteredCommunities];
      }
    });
  }

  Future<Map<String, dynamic>> _loadGroupsAndCommunities() async {
    try {
      // Load groups
      final groupResponse = await _userService.GetChatList('group');

      // Load communities
      final communityResponse = await _userService.GetCommunityChatList();
      print('Community response: $communityResponse');

      List<GroupModel> groups = [];
      List<CommunityModel> communities = [];

      // Process groups
      if (groupResponse['success']) {
        final dynamic responseData = groupResponse['data'];
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
        groups = conversationsList
            .where((json) => json['type'] == 'group')
            .map((json) => _convertToGroupModel(json))
            .toList();
      }

      // Process communities
      if (communityResponse['success'] && communityResponse['data'] != null) {
        final List<dynamic> communityList =
            communityResponse['data'] as List<dynamic>;
        communities = communityList
            .map(
              (json) => CommunityModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }

      setState(() {
        _allGroups = groups;
        _allCommunities = communities;
        _filteredItems = [...groups, ...communities];
      });

      return {'groups': groups, 'communities': communities};
    } catch (e) {
      throw Exception('Error loading data: ${e.toString()}');
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
      // unreadCount: json['unreadCount'] ?? 0,
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

  void _refreshData() {
    setState(() {
      _dataFuture = _loadGroupsAndCommunities();
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
        backgroundColor: Colors.teal,
        elevation: 0,
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.search, color: Colors.white),
        //     onPressed: () {
        //       // TODO: Implement search functionality
        //     },
        //   ),
        //   IconButton(
        //     icon: Icon(Icons.more_vert, color: Colors.white),
        //     onPressed: () {
        //       // TODO: Implement more options
        //     },
        //   ),
        // ],
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

            // Groups and Communities List
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader();
                  } else if (!snapshot.hasData || _filteredItems.isEmpty) {
                    return _buildEmptyState();
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  } else {
                    return _buildItemsList();
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

          // If a group was created, refresh the data
          if (result == true) {
            _refreshData();
          }
        },
        backgroundColor: Colors.teal,
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
          ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
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
            'No groups or communities yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group or join a community to start chatting',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        itemCount: _filteredItems.length,
        itemExtent: 80, // Fixed height for better performance
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final item = _filteredItems[index];

          if (item is GroupModel) {
            return GroupListItem(
              group: item,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InnerGroupChatPage(group: item),
                  ),
                );
              },
            );
          } else if (item is CommunityModel) {
            return CommunityListItem(
              community: item,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CommunityInnerGroupsPage(community: item),
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink(); // Fallback
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
    // final hasUnreadMessages = group.unreadCount > 0;
    final lastMessageText =
        group.metadata?.lastMessage?.body ?? 'No messages yet';
    final timeText = _formatTime(group.lastMessageAt ?? group.joinedAt);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with proper constraints
              SizedBox(
                width: 48,
                height: 48,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal[100],
                  child: Icon(Icons.group, color: Colors.teal, size: 22),
                ),
              ),
              const SizedBox(width: 16),
              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      group.title,
                      style: TextStyle(
                        // fontWeight: false
                        //     ? FontWeight.bold
                        //     : FontWeight.normal,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessageText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing area
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  // if (hasUnreadMessages) ...[
                  //   const SizedBox(height: 4),
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 8,
                  //       vertical: 2,
                  //     ),
                  //     decoration: BoxDecoration(
                  //       color: Colors.teal,
                  //       borderRadius: BorderRadius.circular(10),
                  //     ),
                  //     child: Text(
                  //       group.unreadCount.toString(),
                  //       style: const TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 12,
                  //         fontWeight: FontWeight.bold,
                  //       ),
                  //     ),
                  //   ),
                  // ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityListItem extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;

  const CommunityListItem({
    Key? key,
    required this.community,
    required this.onTap,
  }) : super(key: key);

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
    final timeText = _formatTime(community.updatedAt);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Community Avatar
              SizedBox(
                width: 48,
                height: 48,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.purple[100],
                  child: Icon(
                    Icons.diversity_3,
                    color: Colors.purple[700],
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            community.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'COMMUNITY',
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${community.innerGroupsCount} inner groups',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing area
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
