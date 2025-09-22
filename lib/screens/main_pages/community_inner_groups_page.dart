import 'package:flutter/material.dart';
import '../../models/community_model.dart';
import '../../models/group_model.dart';
import '../../api/user.service.dart';
import 'inner_group_chat_page.dart';

class CommunityInnerGroupsPage extends StatefulWidget {
  final CommunityModel community;

  const CommunityInnerGroupsPage({Key? key, required this.community})
    : super(key: key);

  @override
  State<CommunityInnerGroupsPage> createState() =>
      _CommunityInnerGroupsPageState();
}

class _CommunityInnerGroupsPageState extends State<CommunityInnerGroupsPage> {
  final UserService _userService = UserService();
  late Future<List<CommunityGroupModel>> _innerGroupsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<CommunityGroupModel> _allInnerGroups = [];
  List<CommunityGroupModel> _filteredInnerGroups = [];

  @override
  void initState() {
    super.initState();
    _innerGroupsFuture = _loadInnerGroups();
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
        _filteredInnerGroups = List.from(_allInnerGroups);
      } else {
        _filteredInnerGroups = _allInnerGroups.where((group) {
          return group.title.toLowerCase().contains(query) ||
              group.members.any(
                (member) => member.name.toLowerCase().contains(query),
              );
        }).toList();
      }
    });
  }

  Future<List<CommunityGroupModel>> _loadInnerGroups() async {
    try {
      final response = await _userService.GetChatList('community_group');
      print('Community group response: $response');
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

        // Filter only community groups that belong to this community
        final innerGroups = conversationsList
            .where(
              (json) =>
                  json['type'] == 'community_group' &&
                  json['metadata'] != null &&
                  json['metadata']['community_id'] == widget.community.id,
            )
            .map((json) => CommunityGroupModel.fromJson(json))
            .toList();

        setState(() {
          _allInnerGroups = innerGroups;
          _filteredInnerGroups = List.from(innerGroups);
        });

        return innerGroups;
      } else {
        throw Exception(response['message'] ?? 'Failed to load inner groups');
      }
    } catch (e) {
      throw Exception('Error loading inner groups: ${e.toString()}');
    }
  }

  void _refreshInnerGroups() {
    setState(() {
      _innerGroupsFuture = _loadInnerGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 50,
        leading: Padding(
          padding: EdgeInsets.only(left: 2),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.community.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${widget.community.innerGroupsCount} groups',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
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
                  hintText: 'Search inner groups...',
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

            // Inner Groups List
            Expanded(
              child: FutureBuilder<List<CommunityGroupModel>>(
                future: _innerGroupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader();
                  } else if (!snapshot.hasData ||
                      _filteredInnerGroups.isEmpty) {
                    return _buildEmptyState();
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  } else {
                    return _buildInnerGroupsList();
                  }
                },
              ),
            ),
          ],
        ),
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
              ],
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
            onPressed: _refreshInnerGroups,
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
          Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No inner groups found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'This community has no active groups',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerGroupsList() {
    return RefreshIndicator(
      onRefresh: () async => _refreshInnerGroups(),
      child: ListView.builder(
        itemCount: _filteredInnerGroups.length,
        itemExtent: 100, // Slightly larger for time display
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final innerGroup = _filteredInnerGroups[index];
          return CommunityInnerGroupListItem(
            innerGroup: innerGroup,
            onTap: () {
              // Convert CommunityGroupModel to GroupModel for navigation
              final groupModel = GroupModel(
                conversationId: innerGroup.conversationId,
                title: innerGroup.title,
                type: innerGroup.type,
                members: innerGroup.members,
                metadata: innerGroup.metadata != null
                    ? GroupMetadata(
                        lastMessage: innerGroup.metadata!.lastMessage,
                        totalMessages: innerGroup.metadata!.totalMessages,
                        createdAt: innerGroup.metadata!.createdAt,
                        createdBy: innerGroup.metadata!.createdBy,
                      )
                    : null,
                lastMessageAt: innerGroup.lastMessageAt,
                role: innerGroup.role,
                joinedAt: innerGroup.joinedAt,
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InnerGroupChatPage(
                    group: groupModel,
                    isCommunityGroup: true,
                    communityGroupMetadata: innerGroup.metadata,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CommunityInnerGroupListItem extends StatelessWidget {
  final CommunityGroupModel innerGroup;
  final VoidCallback onTap;

  const CommunityInnerGroupListItem({
    Key? key,
    required this.innerGroup,
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
    final lastMessageText =
        innerGroup.metadata?.lastMessage?.body ?? 'No messages yet';
    final timeText = _formatTime(
      innerGroup.lastMessageAt ?? innerGroup.joinedAt,
    );
    final isActive = innerGroup.isActiveNow;
    final activeTimeSlots = innerGroup.metadata?.activeTimeSlots ?? [];

    return Container(
      height: 100,
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
              // Avatar with status indicator
              Stack(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: isActive
                          ? Colors.green[100]
                          : Colors.grey[300],
                      child: Icon(
                        Icons.group,
                        color: isActive ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
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
                            innerGroup.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Inactive',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessageText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (activeTimeSlots.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Active: ${activeTimeSlots.map((slot) => slot.displayTime).join(', ')}',
                        style: TextStyle(
                          color: isActive
                              ? Colors.green[600]
                              : Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
