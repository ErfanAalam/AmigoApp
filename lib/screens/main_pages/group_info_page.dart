import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../api/groups.services.dart';
import '../../api/user.service.dart';
import '../../services/contact_service.dart';
import '../../repositories/groups_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/group_members_repository.dart';

class GroupInfoPage extends StatefulWidget {
  final GroupModel group;

  const GroupInfoPage({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage>
    with SingleTickerProviderStateMixin {
  final GroupsService _groupsService = GroupsService();
  final UserService _userService = UserService();
  final ContactService _contactService = ContactService();
  final GroupsRepository _groupsRepo = GroupsRepository();
  final UserRepository _userRepo = UserRepository();
  final GroupMembersRepository _groupMembersRepo = GroupMembersRepository();

  Map<String, dynamic>? _groupInfo;
  List<UserModel> _availableUsers = [];
  Set<int> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isUpdatingTitle = false;
  bool _isRefreshingContacts = false;
  String? _errorMessage;
  int? _currentUserId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Helper method to capitalize first letter
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadGroupInfo();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      // Try local DB first if we know the current user from group members
      // (we can infer from cached users table)

      // Fallback: Fetch from API
      final response = await _userService.getUser().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏰ getUser timed out');
          return {'success': false};
        },
      );

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _currentUserId = response['data']['id'];
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadGroupInfo() async {
    // PRIORITY 1: Load from local DB first for instant display
    await _loadGroupInfoFromLocal();

    // PRIORITY 2: Load from server in background
    try {
      final response = await _groupsService.getGroupInfo(
        widget.group.conversationId,
      );

      debugPrint('Group info response: $response');

      if (response['success'] != false) {
        final serverGroupInfo = response['data'];

        // Cache group members to local DB
        if (serverGroupInfo != null && serverGroupInfo['members'] != null) {
          await _cacheGroupMembers(serverGroupInfo['members']);
        }

        // Cache creator info if available (to group_members table)
        if (serverGroupInfo != null &&
            serverGroupInfo['group'] != null &&
            serverGroupInfo['group']['createrName'] != null &&
            serverGroupInfo['group']['createrId'] != null) {
          try {
            final creatorInfo = GroupMemberInfo(
              userId: serverGroupInfo['group']['createrId'],
              userName: serverGroupInfo['group']['createrName'],
              profilePic: serverGroupInfo['group']['createrProfilePic'],
              role: 'admin', // Creator is typically an admin
              joinedAt: serverGroupInfo['group']['createdAt'],
            );
            await _groupMembersRepo.insertOrUpdateGroupMember(
              widget.group.conversationId,
              creatorInfo,
            );
            debugPrint('✅ Cached creator info: ${creatorInfo.userName}');
          } catch (e) {
            debugPrint('❌ Error caching creator info: $e');
          }
        }

        // Parse metadata for group
        GroupMetadata? metadata;
        if (serverGroupInfo?['group'] != null) {
          final groupData = serverGroupInfo['group'];
          metadata = GroupMetadata(
            lastMessage: null,
            totalMessages: groupData['totalMessages'] ?? 0,
            createdAt: groupData['createdAt'],
            createdBy: groupData['createrId'] ?? 0,
          );
        }

        // Update group in local DB with complete info
        final updatedGroup = GroupModel(
          conversationId: widget.group.conversationId,
          title:
              serverGroupInfo?['title'] ??
              serverGroupInfo?['group']?['title'] ??
              widget.group.title,
          type: widget.group.type,
          members: _parseMembers(serverGroupInfo?['members']),
          metadata: metadata ?? widget.group.metadata,
          lastMessageAt: widget.group.lastMessageAt,
          role: serverGroupInfo?['role'] ?? widget.group.role,
          unreadCount: widget.group.unreadCount,
          joinedAt: widget.group.joinedAt,
        );
        await _groupsRepo.insertOrUpdateGroup(updatedGroup);
        debugPrint('✅ Updated group in local DB with complete metadata');

        setState(() {
          _groupInfo = serverGroupInfo;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        // Server returned error, but we have local data from _loadGroupInfoFromLocal
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Network error, but we have local data from _loadGroupInfoFromLocal
      debugPrint('❌ Error loading group info from server: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load group info from local DB first for instant display
  Future<void> _loadGroupInfoFromLocal() async {
    try {
      debugPrint('📦 Loading group info from local DB...');

      // Load group from local DB
      final localGroup = await _groupsRepo.getGroupById(
        widget.group.conversationId,
      );

      if (localGroup != null) {
        // Convert to _groupInfo format expected by the UI
        // UI expects 'userName' but DB stores 'name', so we need to convert
        final members = localGroup.members.map((m) {
          return {
            'userId': m.userId,
            'userName':
                m.name, // Convert 'name' to 'userName' for UI compatibility
            'name': m.name, // Keep 'name' as well for compatibility
            'profilePic': m.profilePic,
            'role': m.role,
            'joinedAt': m.joinedAt,
          };
        }).toList();

        // Find creator name from members list based on created_by ID
        String? creatorName;
        if (localGroup.metadata?.createdBy != null) {
          try {
            // Find creator in members list
            final creator = localGroup.members.firstWhere(
              (m) => m.userId == localGroup.metadata!.createdBy,
            );
            creatorName = creator.name;
            debugPrint('✅ Found creator in members: $creatorName');
          } catch (e) {
            // Creator not found in members, try loading from group_members table
            debugPrint(
              '⚠️ Creator not in members list, checking group_members table...',
            );
            try {
              final creatorMember = await _groupMembersRepo.getGroupMember(
                localGroup.conversationId,
                localGroup.metadata!.createdBy,
              );
              creatorName = creatorMember?.userName;
              debugPrint(
                '✅ Found creator in group_members table: $creatorName',
              );
            } catch (dbError) {
              debugPrint('⚠️ Creator not found in group_members table either');
              creatorName = null;
            }
          }
        }

        final groupInfo = {
          'conversation_id': localGroup.conversationId,
          'title': localGroup.title,
          'type': localGroup.type,
          'role': localGroup.role,
          'members': members,
          'group': {
            'title': localGroup.title,
            'createdAt': localGroup.metadata?.createdAt,
            'createrName': creatorName ?? 'Unknown', // Use actual creator name
          },
          'created_at': localGroup.metadata?.createdAt,
          'created_by': localGroup.metadata?.createdBy,
        };

        setState(() {
          _groupInfo = groupInfo;
          _isLoading = false;
        });
        _animationController.forward();

        debugPrint(
          '✅ Loaded group info from local DB with ${localGroup.members.length} members',
        );
      } else {
        debugPrint('ℹ️ No cached group info found in local DB');
      }
    } catch (e) {
      debugPrint('❌ Error loading group info from local DB: $e');
    }
  }

  /// Cache group members to local DB
  Future<void> _cacheGroupMembers(dynamic membersData) async {
    if (membersData == null) return;

    try {
      final members = _parseMembers(membersData);

      // Cache to group_members table (not users table)
      final memberInfoList = members
          .map(
            (m) => GroupMemberInfo(
              userId: m.userId,
              userName: m.name,
              profilePic: m.profilePic,
              role: m.role,
              joinedAt: m.joinedAt,
            ),
          )
          .toList();

      await _groupMembersRepo.insertOrUpdateGroupMembers(
        widget.group.conversationId,
        memberInfoList,
      );

      debugPrint('✅ Cached ${members.length} group members to local DB');
    } catch (e) {
      debugPrint('❌ Error caching group members: $e');
    }
  }

  /// Parse members from API response
  List<GroupMember> _parseMembers(dynamic membersData) {
    if (membersData == null) return [];

    if (membersData is List) {
      return membersData.map((m) {
        final memberMap = m as Map<String, dynamic>;
        // Handle both 'name' and 'userName' field names from server
        final name = memberMap['userName'] ?? memberMap['name'] ?? '';

        return GroupMember(
          userId: memberMap['userId'] ?? memberMap['user_id'] ?? 0,
          name: name,
          profilePic: memberMap['profilePic'] ?? memberMap['profile_pic'],
          role: memberMap['role'] ?? 'member',
          joinedAt: memberMap['joinedAt'] ?? memberMap['joined_at'],
        );
      }).toList();
    }

    return [];
  }

  // Local Storage Methods (using same key as contacts page)
  static const String _availableUsersStorageKey = 'available_users_contacts';

  Future<List<UserModel>> _getAvailableUsersFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? userJsonList = prefs.getStringList(
        _availableUsersStorageKey,
      );

      if (userJsonList != null) {
        final List<UserModel> users = userJsonList
            .map((userJson) => UserModel.fromJson(jsonDecode(userJson)))
            .toList();
        debugPrint(
          'Retrieved ${users.length} available users from local storage',
        );
        return users;
      }
    } catch (e) {
      debugPrint('Error retrieving available users from local storage: $e');
    }
    return [];
  }

  Future<void> _storeAvailableUsersInLocalStorage(List<UserModel> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> userJsonList = users
          .map((user) => jsonEncode(user.toJson()))
          .toList();
      await prefs.setStringList(_availableUsersStorageKey, userJsonList);
      debugPrint('Stored ${users.length} available users in local storage');
    } catch (e) {
      debugPrint('Error storing available users in local storage: $e');
    }
  }

  Future<void> _loadAvailableUsers({bool forceRefresh = false}) async {
    try {
      // if (!forceRefresh) {
      //   // First try to get from local storage
      //   final storedUsers = await _getAvailableUsersFromLocalStorage();
      //   if (storedUsers.isNotEmpty) {
      //     // Filter out users who are already members of this group
      //     final filteredUsers = storedUsers
      //         .where((user) => !_isUserAlreadyMember(user.id))
      //         .toList();
      //     _availableUsers = filteredUsers;
      //     debugPrint(
      //       'Using ${filteredUsers.length} contacts from local storage',
      //     );
      //     return;
      //   }
      // }

      // If no stored data or force refresh, fetch from backend
      debugPrint('Fetching contacts from backend...');
      final contacts = await _contactService.fetchContacts();
      if (contacts.isEmpty) {
        return;
      }

      // Get contacts in backend format (same as contacts page)
      final contactsData = contacts
          .map((contact) => contact.phoneNumber)
          .toList();

      final response = await _userService.getAvailableUsers(contactsData);

      if (response['success'] == true && response['data'] != null) {
        // Handle both response structures: direct array or nested data (same as contacts page)
        List<dynamic> usersData = response['data'] is List
            ? response['data']
            : response['data']['data'] ?? [];

        // Convert to UserModel (same as contacts page)
        List<UserModel> users = usersData
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();

        // Store in local storage for future use
        await _storeAvailableUsersInLocalStorage(users);

        // Filter out users who are already members of this group
        final filteredUsers = users
            .where((user) => !_isUserAlreadyMember(user.id))
            .toList();

        _availableUsers = filteredUsers;
        debugPrint(
          'Fetched and stored ${users.length} contacts, ${filteredUsers.length} available for group',
        );
      }
    } catch (e) {
      debugPrint('Error loading available users: $e');
    }
  }

  bool _isUserAlreadyMember(int userId) {
    if (_groupInfo?['members'] == null) return false;
    final List<dynamic> members = _groupInfo!['members'];
    return members.any((member) => member['userId'] == userId);
  }

  bool _isCurrentUserAdmin() {
    if (_groupInfo?['members'] == null || _currentUserId == null) return false;
    final List<dynamic> members = _groupInfo!['members'];
    try {
      final currentUserMember = members.firstWhere(
        (member) => member['userId'] == _currentUserId,
      );
      return currentUserMember['role'] == 'admin';
    } catch (e) {
      // User not found in members list
      return false;
    }
  }

  Widget _buildGroupAvatar(String title, {double radius = 40}) {
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _showEditTitleDialog() async {
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can edit group title', isError: true);
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: _groupInfo?['group']?['title'] ?? '',
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Group Title',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Group Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty &&
                  newTitle != _groupInfo?['group']?['title']) {
                Navigator.pop(context);
                await _updateGroupTitle(newTitle);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroupTitle(String newTitle) async {
    try {
      setState(() {
        _isUpdatingTitle = true;
      });

      final response = await _groupsService.updateGroupTitle(
        widget.group.conversationId,
        newTitle,
      );

      if (response['success'] == true) {
        setState(() {
          if (_groupInfo != null) {
            _groupInfo!['group']['title'] = newTitle;
          }
        });
        _showSnackBar('Group title updated successfully');
      } else {
        _showSnackBar(
          response['message'] ?? 'Failed to update title',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error updating title: $e', isError: true);
    } finally {
      setState(() {
        _isUpdatingTitle = false;
      });
    }
  }

  Future<void> _showAddMemberDialog() async {
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can add members', isError: true);
      return;
    }

    // Load available users first
    await _loadAvailableUsers();

    if (_availableUsers.isEmpty) {
      _showSnackBar(
        'No available contacts to add. All your contacts may already be in this group or you may need to sync your contacts first.',
        isError: true,
      );
      return;
    }

    // Reset selection
    _selectedUserIds.clear();

    // Show the animated dialog
    await _showAnimatedAddMemberDialog();
  }

  Future<void> _refreshContacts() async {
    setState(() {
      _isRefreshingContacts = true;
    });

    await _loadAvailableUsers(forceRefresh: true);

    // Filter again after refresh to update the available users
    final filteredUsers = _availableUsers
        .where((user) => !_isUserAlreadyMember(user.id))
        .toList();
    _availableUsers = filteredUsers;

    setState(() {
      _isRefreshingContacts = false;
    });
  }

  Future<void> _showAnimatedAddMemberDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation1, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(
            opacity: animation1,
            child: _buildAddMemberDialogContent(),
          ),
        );
      },
    );
  }

  Widget _buildAddMemberDialogContent() {
    return StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.teal, Colors.teal.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add Members',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Refresh button
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                await _refreshContacts();
                                // Trigger rebuild of the dialog
                                (context as Element).markNeedsBuild();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: _isRefreshingContacts
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        // Selection counter
                        if (_selectedUserIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_selectedUserIds.length}',
                              style: TextStyle(
                                color: Colors.teal.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Section
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Stats and Select All Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade50,
                              Colors.teal.shade50.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value:
                                  _selectedUserIds.length ==
                                  _availableUsers.length,
                              tristate: true,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    _selectedUserIds.addAll(
                                      _availableUsers.map((u) => u.id),
                                    );
                                  } else {
                                    _selectedUserIds.clear();
                                  }
                                });
                              },
                              activeColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUserIds.length ==
                                            _availableUsers.length
                                        ? 'Deselect All'
                                        : 'Select All',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_availableUsers.length} contacts available',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedUserIds.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_selectedUserIds.length} selected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Users List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = _availableUsers[index];
                            final isSelected = _selectedUserIds.contains(
                              user.id,
                            );

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.teal.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.teal
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? Colors.teal.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.05),
                                    blurRadius: isSelected ? 8 : 4,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        _selectedUserIds.remove(user.id);
                                      } else {
                                        _selectedUserIds.add(user.id);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.teal
                                                        .withOpacity(0.2),
                                                    blurRadius: 8,
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundColor: isSelected
                                                    ? Colors.teal.shade100
                                                    : Colors.grey.shade100,
                                                backgroundImage:
                                                    user.profilePic != null
                                                    ? NetworkImage(
                                                        user.profilePic!,
                                                      )
                                                    : null,
                                                child: user.profilePic == null
                                                    ? Text(
                                                        user.name.isNotEmpty
                                                            ? user.name[0]
                                                                  .toUpperCase()
                                                            : '?',
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? Colors
                                                                    .teal
                                                                    .shade700
                                                              : Colors
                                                                    .grey
                                                                    .shade600,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            if (isSelected)
                                              Positioned(
                                                right: -2,
                                                bottom: -2,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    3,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.teal,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                style: TextStyle(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 16,
                                                  color: isSelected
                                                      ? Colors.teal.shade700
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                user.phone,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AnimatedScale(
                                          scale: isSelected ? 1.1 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          child: Checkbox(
                                            value: isSelected,
                                            onChanged: (value) {
                                              setDialogState(() {
                                                if (value == true) {
                                                  _selectedUserIds.add(user.id);
                                                } else {
                                                  _selectedUserIds.remove(
                                                    user.id,
                                                  );
                                                }
                                              });
                                            },
                                            activeColor: Colors.teal,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedUserIds.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                _addMembers(_selectedUserIds.toList());
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: Colors.teal.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_add, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _selectedUserIds.isEmpty
                                  ? 'Add Members'
                                  : 'Add ${_selectedUserIds.length} Member${_selectedUserIds.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMembers(List<int> userIds) async {
    if (userIds.isEmpty) return;
    // print('userIds: $userIds');
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Adding members...'),
            ],
          ),
        ),
      );

      // Add all members at once
      final response = await _groupsService.addMember(
        widget.group.conversationId,
        userIds,
      );

      print('member added succesfully: $response');

      // Close loading dialog
      Navigator.pop(context);

      // Show result message
      if (response['success'] == true) {
        _showSnackBar(
          '${userIds.length} member${userIds.length > 1 ? 's' : ''} added successfully',
        );
      } else {
        _showSnackBar(
          response['message'] ?? 'Failed to add members',
          isError: true,
        );
      }

      // Refresh group info
      await _loadGroupInfo();
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error adding members: $e', isError: true);
    }
  }

  bool _isGroupCreator(int userId) {
    // Check if the user is the creator of the group
    final creatorId =
        _groupInfo?['group']?['createrId'] ?? _groupInfo?['created_by'];
    return userId == creatorId;
  }

  Future<void> _promoteToAdmin(int userId, String userName) async {
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can promote members', isError: true);
      return;
    }

    if (userId == _currentUserId) {
      _showSnackBar('You are already an admin', isError: true);
      return;
    }

    final bool? confirmed = await _showPromoteToAdminDialog(userName);

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text('Promoting $userName to admin...')),
              ],
            ),
          ),
        );

        final response = await _groupsService.promoteToAdmin(
          widget.group.conversationId,
          userId,
        );

        // Close loading dialog
        Navigator.pop(context);

        if (response['success'] == true) {
          _showSnackBar('$userName is now an admin');
          await _loadGroupInfo(); // Refresh group info
        } else {
          _showSnackBar(
            response['message'] ?? 'Failed to promote member',
            isError: true,
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _showSnackBar('Error promoting member: $e', isError: true);
      }
    }
  }

  Future<void> _demoteToMember(int userId, String userName) async {
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can demote members', isError: true);
      return;
    }

    if (_isGroupCreator(userId)) {
      _showSnackBar('Cannot demote the group creator', isError: true);
      return;
    }

    if (userId == _currentUserId) {
      _showSnackBar('You cannot demote yourself', isError: true);
      return;
    }

    final bool? confirmed = await _showDemoteToMemberDialog(userName);

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text('Demoting $userName to member...')),
              ],
            ),
          ),
        );

        final response = await _groupsService.demoteToAdmin(
          widget.group.conversationId,
          userId,
        );

        // Close loading dialog
        Navigator.pop(context);

        if (response['success'] == true) {
          _showSnackBar('$userName is now a member');
          await _loadGroupInfo(); // Refresh group info
        } else {
          _showSnackBar(
            response['message'] ?? 'Failed to demote member',
            isError: true,
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _showSnackBar('Error demoting member: $e', isError: true);
      }
    }
  }

  Future<bool?> _showPromoteToAdminDialog(String userName) async {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.teal.shade50],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              size: 48,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Promote to Admin',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Are you sure you want to make ',
                                ),
                                TextSpan(
                                  text: userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' an admin of this group?',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admins can add/remove members and edit group settings.',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: Colors.teal.withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Yes, Promote',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showDemoteToMemberDialog(String userName) async {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.orange.shade50],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_remove,
                              size: 48,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Demote to Member',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Are you sure you want to demote ',
                                ),
                                TextSpan(
                                  text: userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const TextSpan(text: ' to a regular member?'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_outlined,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'They will lose admin privileges and cannot manage the group.',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: Colors.orange.withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Yes, Demote',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeMember(int userId, String userName) async {
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can remove members', isError: true);
      return;
    }

    if (userId == _currentUserId) {
      _showSnackBar('You cannot remove yourself from the group', isError: true);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $userName from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _groupsService.removeMember(
          widget.group.conversationId,
          userId,
        );

        if (response['success'] == true) {
          _showSnackBar('$userName removed from group');
          await _loadGroupInfo(); // Refresh group info
        } else {
          _showSnackBar(
            response['message'] ?? 'Failed to remove member',
            isError: true,
          );
        }
      } catch (e) {
        _showSnackBar('Error removing member: $e', isError: true);
      }
    }
  }

  Future<void> _showDeleteGroupDialog() async {
    final groupTitle = _groupInfo?['group']?['title'] ?? 'this group';

    final bool? confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.red.shade50],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete_forever,
                              size: 48,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Delete Group',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Are you sure you want to delete ',
                                ),
                                TextSpan(
                                  text: groupTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const TextSpan(text: '?'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This action cannot be undone. All messages will be permanently deleted.',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: Colors.red.withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_forever, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _deleteGroup();
    }
  }

  Future<void> _deleteGroup() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Deleting group...')),
            ],
          ),
        ),
      );

      final response = await _groupsService.deleteGroup(
        widget.group.conversationId,
      );

      // Close loading dialog
      Navigator.pop(context);

      if (response['success'] == true) {
        // Delete from local database
        await _groupsRepo.deleteGroup(widget.group.conversationId);
        

        _showSnackBar('Group deleted successfully');

        // Navigate back with deletion result
        // This will be handled by InnerGroupChatPage
        Navigator.pop(context, {'action': 'deleted'});
      } else {
        _showSnackBar(
          response['message'] ?? 'Failed to delete group',
          isError: true,
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error deleting group: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.teal : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Group Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadGroupInfo,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Group Header Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildGroupAvatar(
                                _groupInfo?['group']?['title'] ?? 'Group',
                                radius: 50,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _capitalizeFirstLetter(
                                        _groupInfo?['group']?['title'] ??
                                            'Group',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (_isCurrentUserAdmin())
                                    IconButton(
                                      onPressed: _isUpdatingTitle
                                          ? null
                                          : _showEditTitleDialog,
                                      icon: _isUpdatingTitle
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.edit,
                                              color: Colors.teal,
                                            ),
                                      tooltip: 'Edit group title',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created by ${_groupInfo?['group']?['createrName'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Members Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Members (${_groupInfo?['members']?.length ?? 0})',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (_isCurrentUserAdmin())
                                    ElevatedButton.icon(
                                      onPressed: _showAddMemberDialog,
                                      icon: const Icon(
                                        Icons.person_add,
                                        size: 18,
                                      ),
                                      label: const Text('Add Member'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_groupInfo?['members'] != null)
                                ...(_groupInfo!['members'] as List<dynamic>).map((
                                  member,
                                ) {
                                  final isAdmin = member['role'] == 'admin';
                                  final isCurrentUser =
                                      member['userId'] == _currentUserId;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? Colors.teal.shade50
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isCurrentUser
                                          ? Border.all(
                                              color: Colors.teal.shade200,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isAdmin
                                              ? Colors.amber.shade100
                                              : Colors.teal.shade100,
                                          child: Text(
                                            (member['userName'] ?? '?')[0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: isAdmin
                                                  ? Colors.amber.shade700
                                                  : Colors.teal.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    member['userName'] ??
                                                        'Unknown',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (isCurrentUser)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            left: 8,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.teal,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        'You',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  // Creator badge
                                                  if (_isGroupCreator(
                                                    member['userId'],
                                                  ))
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            right: 6,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                              colors: [
                                                                Colors
                                                                    .purple
                                                                    .shade400,
                                                                Colors
                                                                    .purple
                                                                    .shade600,
                                                              ],
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.star,
                                                            size: 12,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'Creator',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  // Admin/Member badge
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isAdmin
                                                          ? Colors
                                                                .amber
                                                                .shade100
                                                          : Colors
                                                                .grey
                                                                .shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      isAdmin
                                                          ? 'Admin'
                                                          : 'Member',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isAdmin
                                                            ? Colors
                                                                  .amber
                                                                  .shade700
                                                            : Colors
                                                                  .grey
                                                                  .shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_isCurrentUserAdmin() &&
                                            !isCurrentUser)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Show "Make Admin" button only for non-admin members
                                              if (!isAdmin)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    right: 4,
                                                  ),
                                                  child: Material(
                                                    color: Colors.amber.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      onTap: () =>
                                                          _promoteToAdmin(
                                                            member['userId'],
                                                            member['userName'] ??
                                                                'Unknown',
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        child: Icon(
                                                          Icons
                                                              .admin_panel_settings,
                                                          size: 20,
                                                          color: Colors
                                                              .amber
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              // Show "Demote to Member" button only for admins (but not creator)
                                              if (isAdmin &&
                                                  !_isGroupCreator(
                                                    member['userId'],
                                                  ))
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    right: 4,
                                                  ),
                                                  child: Material(
                                                    color:
                                                        Colors.orange.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      onTap: () =>
                                                          _demoteToMember(
                                                            member['userId'],
                                                            member['userName'] ??
                                                                'Unknown',
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        child: Icon(
                                                          Icons.person_remove,
                                                          size: 20,
                                                          color: Colors
                                                              .orange
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              // Remove button
                                              IconButton(
                                                onPressed: () => _removeMember(
                                                  member['userId'],
                                                  member['userName'] ??
                                                      'Unknown',
                                                ),
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Colors.teal,
                                                ),
                                                tooltip: 'Remove member',
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ),

                      // Danger Zone Section (Admin Only)
                      if (_isCurrentUserAdmin())
                        SafeArea(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.red.shade400,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Danger Zone',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Delete Group',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 16,
                                                        color:
                                                            Colors.red.shade900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Permanently delete this group and all its messages',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Colors.red.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed:
                                                    _showDeleteGroupDialog,
                                                icon: const Icon(
                                                  Icons.delete_forever,
                                                  size: 20,
                                                ),
                                                label: const Text('Delete'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 10,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
