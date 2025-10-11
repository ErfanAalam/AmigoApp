import 'package:flutter/material.dart';
import '../../models/community_model.dart';
import '../../models/group_model.dart';
import '../../api/user.service.dart';
import '../../repositories/groups_repository.dart';
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
  final GroupsRepository _groupsRepo = GroupsRepository();
  late Future<List<CommunityGroupModel>> _innerGroupsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<CommunityGroupModel> _allInnerGroups = [];
  List<CommunityGroupModel> _filteredInnerGroups = [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFromLocal();
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

  /// Load community inner groups from local DB first
  Future<void> _loadFromLocal() async {
    try {
      debugPrint('📦 Loading community inner groups from local DB...');
      final localGroups = await _groupsRepo.getAllCommunityInnerGroups();

      // Filter groups that belong to this community
      final communityGroups = localGroups
          .where((group) {
            // Check if the group belongs to this community by checking metadata
            if (group.metadata?.createdBy == widget.community.id) {
              return true;
            }
            // Fallback: Check if group is in the community's group IDs list
            return widget.community.groupIds.contains(group.conversationId);
          })
          .toList();

      if (mounted) {
        setState(() {
          _allInnerGroups = communityGroups
              .map((g) => _convertGroupModelToCommunityGroupModel(g))
              .toList();
          _filteredInnerGroups = List.from(_allInnerGroups);
          _isLoaded = true;
        });

        if (communityGroups.isNotEmpty) {
          debugPrint(
            '✅ Loaded ${communityGroups.length} community inner groups from local DB',
          );
        } else {
          debugPrint('ℹ️ No cached community inner groups found in local DB');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading from local DB: $e');
      // Even on error, set isLoaded to allow showing empty state
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _allInnerGroups = [];
          _filteredInnerGroups = [];
        });
      }
    }
  }

  /// Convert GroupModel to CommunityGroupModel
  CommunityGroupModel _convertGroupModelToCommunityGroupModel(GroupModel group) {
    CommunityGroupMetadata? metadata;
    if (group.metadata != null) {
      metadata = CommunityGroupMetadata(
        timezone: 'UTC', // Default timezone, will be updated from server
        activeDays: [0, 1, 2, 3, 4, 5, 6], // Default all days, will be updated from server
        communityId: widget.community.id,
        activeTimeSlots: [], // Will be updated from server
        lastMessage: group.metadata!.lastMessage,
        totalMessages: group.metadata!.totalMessages,
        createdAt: group.metadata!.createdAt,
        createdBy: group.metadata!.createdBy,
      );
    }

    return CommunityGroupModel(
      conversationId: group.conversationId,
      title: group.title,
      type: group.type,
      members: group.members,
      metadata: metadata,
      lastMessageAt: group.lastMessageAt,
      role: group.role,
      joinedAt: group.joinedAt,
    );
  }

  Future<List<CommunityGroupModel>> _loadInnerGroups() async {
    // First, get current local data
    List<CommunityGroupModel> localInnerGroups = [];

    try {
      final localGroups = await _groupsRepo.getAllCommunityInnerGroups();
      localInnerGroups = localGroups
          .where((group) =>
              widget.community.groupIds.contains(group.conversationId) ||
              group.metadata?.createdBy == widget.community.id)
          .map((g) => _convertGroupModelToCommunityGroupModel(g))
          .toList();
      debugPrint(
        '📦 Current local DB has ${localInnerGroups.length} community inner groups',
      );
    } catch (e) {
      debugPrint('⚠️ Error reading local DB: $e');
    }

    try {
      debugPrint('📥 Loading community inner groups from server...');
      final response = await _userService.GetChatList('community_group');
      debugPrint('Community group response: $response');

      if (response['success']) {
        final dynamic responseData = response['data'];

        List<dynamic> conversationsList = [];

        if (responseData is List) {
          debugPrint("1 if -------->");
          conversationsList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          debugPrint("2 else if -------->");
          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            conversationsList = responseData['data'] as List<dynamic>;
          } else {
            debugPrint("3 else -------->");
            for (var key in responseData.keys) {
              if (responseData[key] is List) {
                conversationsList = responseData[key] as List<dynamic>;
                break;
              }
            }
          }
        }

        debugPrint(
          "--------------------------------------------------------------------------------",
        );
        debugPrint("conversationsList -> ${conversationsList}");
        debugPrint(
          "--------------------------------------------------------------------------------",
        );

        // Filter only community groups that belong to this community
        final innerGroups = conversationsList
            .where(
              (json) =>
                  json['type'] == 'community_group' && json['metadata'] != null,
            )
            .map((json) => CommunityGroupModel.fromJson(json))
            .toList();

        debugPrint(
          "--------------------------------------------------------------------------------",
        );
        debugPrint("innerGroups -> ${innerGroups}");
        debugPrint(
          "--------------------------------------------------------------------------------",
        );

        // Persist to local DB if we got data from server
        if (innerGroups.isNotEmpty) {
          final groupModels = innerGroups
              .map((cg) => _convertCommunityGroupModelToGroupModel(cg))
              .toList();
          await _groupsRepo.insertOrUpdateGroups(groupModels);
          debugPrint(
            '✅ Persisted ${groupModels.length} community inner groups to local DB',
          );
        } else {
          debugPrint(
            '⚠️ Server returned 0 community inner groups - keeping local cache',
          );
        }

        if (mounted) {
          setState(() {
            _allInnerGroups =
                innerGroups.isNotEmpty ? innerGroups : localInnerGroups;
            _filteredInnerGroups = List.from(_allInnerGroups);
            _isLoaded = true;
          });
        }

        debugPrint(
          '✅ Displaying ${_allInnerGroups.length} community inner groups',
        );
        return _allInnerGroups;
      } else {
        throw Exception(response['message'] ?? 'Failed to load inner groups');
      }
    } catch (e) {
      debugPrint('❌ Error loading from server: $e');
      debugPrint('📦 Using local DB data as fallback...');

      // Use local data on error
      if (mounted) {
        setState(() {
          _allInnerGroups = localInnerGroups;
          _filteredInnerGroups = List.from(localInnerGroups);
          _isLoaded = true;
        });
      }

      debugPrint(
        '📦 Displaying ${localInnerGroups.length} community inner groups from local DB',
      );
      return localInnerGroups;
    }
  }

  /// Convert CommunityGroupModel to GroupModel for database storage
  GroupModel _convertCommunityGroupModelToGroupModel(CommunityGroupModel cg) {
    GroupMetadata? metadata;
    if (cg.metadata != null) {
      metadata = GroupMetadata(
        lastMessage: cg.metadata!.lastMessage,
        totalMessages: cg.metadata!.totalMessages,
        createdAt: cg.metadata!.createdAt,
        createdBy: cg.metadata!.createdBy,
      );
    }

    return GroupModel(
      conversationId: cg.conversationId,
      title: cg.title,
      type: cg.type,
      members: cg.members,
      metadata: metadata,
      lastMessageAt: cg.lastMessageAt,
      role: cg.role,
      unreadCount: 0, // Community groups don't track unread count
      joinedAt: cg.joinedAt,
    );
  }

  void _refreshInnerGroups() {
    setState(() {
      _innerGroupsFuture = _loadInnerGroups();
      _isLoaded = false; // Reset to show loading state
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
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _refreshInnerGroups,
            ),
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
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    debugPrint(
      '🏗️ Building content: _isLoaded=$_isLoaded, filteredInnerGroups=${_filteredInnerGroups.length}',
    );

    // If we have loaded data, show it directly
    if (_isLoaded && _filteredInnerGroups.isNotEmpty) {
      return _buildInnerGroupsList();
    }

    // If we have loaded but no items, show appropriate empty state
    if (_isLoaded && _filteredInnerGroups.isEmpty) {
      return _buildEmptyState();
    }

    // Otherwise, use FutureBuilder for initial load
    return FutureBuilder<List<CommunityGroupModel>>(
      future: _innerGroupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoaded) {
          return _buildSkeletonLoader();
        } else if (snapshot.hasError && !_isLoaded) {
          return _buildErrorState(snapshot.error.toString());
        } else if (snapshot.hasData || _isLoaded) {
          if (_filteredInnerGroups.isEmpty) {
            return _buildEmptyState();
          }
          return _buildInnerGroupsList();
        } else {
          return _buildSkeletonLoader();
        }
      },
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
                unreadCount:
                    0, // Community inner groups don't track unread count
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
                        // if (!isActive)
                        //   Container(
                        //     padding: EdgeInsets.symmetric(
                        //       horizontal: 6,
                        //       vertical: 2,
                        //     ),
                        //     decoration: BoxDecoration(
                        //       color: Colors.orange[100],
                        //       borderRadius: BorderRadius.circular(8),
                        //     ),
                        //     child: Text(
                        //       'Inactive',
                        //       style: TextStyle(
                        //         color: Colors.orange[800],
                        //         fontSize: 10,
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //   ),
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
