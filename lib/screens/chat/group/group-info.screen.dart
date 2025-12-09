import 'dart:async';
import 'package:amigo/db/repositories/contacts.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/group.api-client.dart';
import '../../../api/user.api-client.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../models/group.model.dart';
import '../../../models/user.model.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/contact.service.dart';
import '../../../ui/snackbar.dart';

class GroupInfoPage extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupInfoPage({super.key, required this.group});

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage>
    with SingleTickerProviderStateMixin {
  final GroupsService _groupsService = GroupsService();
  final UserService _userService = UserService();
  final ContactService _contactService = ContactService();

  final ContactsRepository _contactsRepository = ContactsRepository();

  final ConversationRepository _conversationRepository =
      ConversationRepository();
  final ConversationMemberRepository _conversationMemberRepository =
      ConversationMemberRepository();
  final UserRepository _userRepository = UserRepository();

  final UserUtils _userUtils = UserUtils();

  Map<String, dynamic>? _groupInfo;
  List<UserModel> _availableUsers = [];
  final Set<int> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isUpdatingTitle = false;
  bool _isRefreshingContacts = false;
  String? _errorMessage;
  UserModel? _currentUserDetails;
  String _searchQuery = '';
  String _memberSearchQuery = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Helper method to capitalize first letter
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Get filtered users based on search query
  List<UserModel> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _availableUsers;
    }
    final query = _searchQuery.toLowerCase().trim();
    return _availableUsers.where((user) {
      final nameMatch = user.name.toLowerCase().contains(query);
      final phoneMatch = user.phone.toLowerCase().contains(query);
      return nameMatch || phoneMatch;
    }).toList();
  }

  // Get filtered members based on search query
  List<dynamic> get _filteredMembers {
    if (_groupInfo?['members'] == null) return [];
    if (_memberSearchQuery.isEmpty) {
      return _groupInfo!['members'] as List<dynamic>;
    }
    final query = _memberSearchQuery.toLowerCase().trim();
    final members = _groupInfo!['members'] as List<dynamic>;
    return members.where((member) {
      final name = (member['userName'] ?? member['name'] ?? '')
          .toString()
          .toLowerCase();
      final phone = (member['phone'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
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

    _loadCurrentUser();

    _loadGroupInfoFromLocal();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final currentUser = await _userUtils.getUserDetails();
    if (currentUser != null) {
      setState(() {
        _currentUserDetails = currentUser;
      });
    }
  }

  /// Load group info from local DB first for instant display
  Future<void> _loadGroupInfoFromLocal() async {
    try {
      final groupInfo = await _conversationRepository
          .getGroupWithMembersByConvId(widget.group.conversationId);
      if (groupInfo != null) {
        // Get conversation to access createrId
        final conv = await _conversationRepository.getConversationById(
          widget.group.conversationId,
        );

        final groupInfoMap = groupInfo.toJson();

        // Add creator information if available
        if (conv != null) {
          groupInfoMap['createrId'] = conv.createrId;
          // Find creator name from members list first
          String? creatorName;
          if (groupInfo.members != null && groupInfo.members!.isNotEmpty) {
            try {
              final creatorMember = groupInfo.members!.firstWhere(
                (member) => member.userId == conv.createrId,
              );
              creatorName = creatorMember.name;
            } catch (e) {
              // Creator not found in members list, try to get from users table
              debugPrint(
                'Creator not found in members list, fetching from users table',
              );
            }
          }

          // If creator name not found in members, try to get from users table
          if (creatorName == null || creatorName.isEmpty) {
            final creatorUser = await _userRepository.getUserById(
              conv.createrId,
            );
            creatorName = creatorUser?.name ?? 'Unknown';
          }

          groupInfoMap['createrName'] = creatorName;
        }

        setState(() {
          _groupInfo = groupInfoMap;
          _isLoading = false;
          _errorMessage = null;
        });
        // Start animation after data is loaded
        _animationController.forward();
      } else {
        // If no data found, set loading to false and show error
        setState(() {
          _isLoading = false;
          _errorMessage = 'Group information not found';
        });
        // Start animation to show error message
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Error loading group info: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading group information: $e';
      });
      // Start animation to show error message
      _animationController.forward();
    }

    // print(
    //   '######################groupInfo: ${_groupInfo?['group']['title']} ######################',
    // );
    print(
      '######################groupInfo: $_groupInfo ######################',
    );
  }

  Future<void> _loadAvailableUsers({bool forceRefresh = false}) async {
    // try {
    //   // If no stored data or force refresh, fetch from backend
    //   final contacts = await _contactService.fetchContacts();
    //   if (contacts.isEmpty) {
    //     return;
    //   }

    //   // Get contacts in backend format (same as contacts page)
    //   final contactsData = contacts
    //       .map((contact) => contact.phoneNumber)
    //       .toList();

    //   final response = await _userService.getAvailableUsers(contactsData);

    //   if (response['success'] == true && response['data'] != null) {
    //     // Handle both response structures: direct array or nested data (same as contacts page)
    //     List<dynamic> usersData = response['data'] is List
    //         ? response['data']
    //         : response['data']['data'] ?? [];

    //     // Convert to UserModel (same as contacts page)
    //     List<UserModel> users = usersData
    //         .map((userJson) => UserModel.fromJson(userJson))
    //         .toList();

    //     // Filter out users who are already members of this group
    //     final filteredUsers = users
    //         .where((user) => !_isUserAlreadyMember(user.id))
    //         .toList();

    //     _availableUsers = filteredUsers;
    //     debugPrint(
    //       'Fetched and stored ${users.length} contacts, ${filteredUsers.length} available for group',
    //     );
    //   }
    // } catch (e) {
    //   debugPrint('Error loading available users: $e');
    // }
    try {
      final localContacts = await _contactsRepository.getAllContacts();
      if (localContacts.isNotEmpty) {
        setState(() {
          _availableUsers = localContacts;
        });
      }
    } catch (_) {}
  }

  bool _isUserAlreadyMember(int userId) {
    if (_groupInfo?['members'] == null) return false;
    final List<dynamic> members = _groupInfo!['members'];
    return members.any((member) => member['userId'] == userId);
  }

  bool _isCurrentUserAdmin() {
    if (_groupInfo?['members'] == null || _currentUserDetails?.id == null)
      return false;
    final List<dynamic> members = _groupInfo!['members'];
    try {
      final currentUserMember = members.firstWhere(
        (member) => member['userId'] == _currentUserDetails?.id,
      );
      return currentUserMember['role'] == 'admin';
    } catch (e) {
      // User not found in members list
      return false;
    }
  }

  Widget _buildGroupAvatar(String title, {double radius = 40}) {
    final themeColor = ref.watch(themeColorProvider);
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [themeColor.primaryLight, themeColor.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.primary.withOpacity(0.3),
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
    final themeColor = ref.watch(themeColorProvider);
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can edit group title', isError: true);
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: _groupInfo?['title'] ?? '',
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
              borderSide: BorderSide(color: themeColor.primary, width: 2),
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
              if (newTitle.isNotEmpty && newTitle != _groupInfo?['title']) {
                Navigator.pop(context);
                await _updateGroupTitle(newTitle);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor.primary,
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
            _groupInfo?['title'] = newTitle;
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

    // if (_availableUsers.isEmpty) {
    //   _showSnackBar(
    //     'No available contacts to add. All your contacts may already be in this group or you may need to sync your contacts first.',
    //     isError: true,
    //   );
    //   return;
    // }

    // Reset selection
    _selectedUserIds.clear();
    // Reset search query
    _searchQuery = '';

    // Show the animated dialog
    // await _loadAvailableUsers();
    await _showAnimatedAddMemberDialog();
    // Load available users first
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
    await _refreshContacts();
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
    final themeColor = ref.watch(themeColorProvider);
    final TextEditingController searchController = TextEditingController(
      text: _searchQuery,
    );

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
                    colors: [themeColor.primary, themeColor.primaryDark],
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
                                color: themeColor.primary,
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
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) {
                            setDialogState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone number',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade600,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        _searchQuery = '';
                                        searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stats and Select All Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeColor.primaryLight.withOpacity(0.2),
                              themeColor.primaryLight.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themeColor.primaryLight.withOpacity(0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_filteredUsers.isNotEmpty) ...[
                              Checkbox(
                                value:
                                    _filteredUsers.every(
                                      (u) => _selectedUserIds.contains(u.id),
                                    ) &&
                                    _filteredUsers.isNotEmpty,
                                tristate: true,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      _selectedUserIds.addAll(
                                        _filteredUsers.map((u) => u.id),
                                      );
                                    } else {
                                      // Remove only filtered users from selection
                                      for (var userId in _filteredUsers.map(
                                        (u) => u.id,
                                      )) {
                                        _selectedUserIds.remove(userId);
                                      }
                                    }
                                  });
                                },
                                activeColor: themeColor.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _filteredUsers.isEmpty
                                        ? 'No remaining contacts'
                                        : _filteredUsers.every(
                                                (u) => _selectedUserIds
                                                    .contains(u.id),
                                              ) &&
                                              _filteredUsers.isNotEmpty
                                        ? 'Deselect All'
                                        : 'Select All',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? '${_availableUsers.length} available contact${_availableUsers.length > 1 ? 's' : ''}'
                                        : '${_filteredUsers.length} result${_filteredUsers.length > 1 ? 's' : ''}',
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
                                  color: themeColor.primary,
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
                        child: _filteredUsers.isEmpty && _searchQuery.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No users found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try a different search term',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  final isSelected = _selectedUserIds.contains(
                                    user.id,
                                  );

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? themeColor.primaryLight.withOpacity(
                                              0.2,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? themeColor.primary
                                            : Colors.grey.shade200,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? themeColor.primary.withOpacity(
                                                  0.1,
                                                )
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
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: themeColor
                                                              .primary
                                                              .withOpacity(0.2),
                                                          blurRadius: 8,
                                                          spreadRadius: 0,
                                                        ),
                                                      ],
                                                    ),
                                                    child: CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor:
                                                          isSelected
                                                          ? themeColor
                                                                .primaryLight
                                                                .withOpacity(
                                                                  0.4,
                                                                )
                                                          : Colors
                                                                .grey
                                                                .shade100,
                                                      backgroundImage:
                                                          user.profilePic !=
                                                              null
                                                          ? NetworkImage(
                                                              user.profilePic!,
                                                            )
                                                          : null,
                                                      child:
                                                          user.profilePic ==
                                                              null
                                                          ? Text(
                                                              user
                                                                      .name
                                                                      .isNotEmpty
                                                                  ? user.name[0]
                                                                        .toUpperCase()
                                                                  : '?',
                                                              style: TextStyle(
                                                                color:
                                                                    isSelected
                                                                    ? Colors
                                                                          .teal
                                                                          .shade700
                                                                    : Colors
                                                                          .grey
                                                                          .shade600,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                                                        padding:
                                                            const EdgeInsets.all(
                                                              3,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: themeColor
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
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
                                                            ? Colors
                                                                  .teal
                                                                  .shade700
                                                            : Colors
                                                                  .grey
                                                                  .shade800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      user.phone,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
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
                                                        _selectedUserIds.add(
                                                          user.id,
                                                        );
                                                      } else {
                                                        _selectedUserIds.remove(
                                                          user.id,
                                                        );
                                                      }
                                                    });
                                                  },
                                                  activeColor:
                                                      themeColor.primary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
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
                          backgroundColor: themeColor.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: themeColor.primary.withOpacity(0.3),
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
      // Close loading dialog
      Navigator.pop(context);

      // Show result message
      if (response['success'] == true) {
        _showSnackBar(
          '${userIds.length} member${userIds.length > 1 ? 's' : ''} added successfully',
        );
        final members = userIds
            .map(
              (userId) => ConversationMemberModel(
                conversationId: widget.group.conversationId,
                userId: userId,
                role: 'member',
                joinedAt: DateTime.now().toIso8601String(),
                unreadCount: 0,
                lastReadMessageId: 0,
                lastDeliveredMessageId: null,
              ),
            )
            .toList();
        await _conversationMemberRepository.insertConversationMembers(members);
      } else {
        _showSnackBar(
          response['message'] ?? 'Failed to add members',
          isError: true,
        );
      }

      // Refresh group info
      await _loadGroupInfoFromLocal();
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
    final creatorId = _groupInfo?['createrId'] ?? _groupInfo?['created_by'];
    return userId == creatorId;
  }

  Future<void> _promoteToAdmin(int userId, String userName) async {
    if (!_isCurrentUserAdmin()) {
      _showSnackBar('Only admins can promote members', isError: true);
      return;
    }

    if (userId == _currentUserDetails?.id) {
      _showSnackBar('You are already an admin', isError: true);
      return;
    }

    final bool? confirmed = await _showPromoteToAdminDialog(userName);

    if (confirmed == true) {
      try {
        // Show loading indicator
        final themeColor = ref.watch(themeColorProvider);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor.primary),
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

          await _conversationMemberRepository.updateMemberRole(
            widget.group.conversationId,
            userId,
            'admin',
          );
          await _loadGroupInfoFromLocal(); // Refresh group info
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

    if (userId == _currentUserDetails?.id) {
      _showSnackBar('You cannot demote yourself', isError: true);
      return;
    }

    final bool? confirmed = await _showDemoteToMemberDialog(userName);

    if (confirmed == true) {
      try {
        // Show loading indicator
        final themeColor = ref.watch(themeColorProvider);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor.primary),
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
          await _conversationMemberRepository.updateMemberRole(
            widget.group.conversationId,
            userId,
            'member',
          );
          await _loadGroupInfoFromLocal(); // Refresh group info
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
    final themeColor = ref.watch(themeColorProvider);
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
                    colors: [
                      Colors.white,
                      themeColor.primaryLight.withOpacity(0.2),
                    ],
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
                              color: themeColor.primaryLight.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              size: 48,
                              color: themeColor.primary,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: themeColor.primary,
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
                                backgroundColor: themeColor.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: themeColor.primary.withOpacity(
                                  0.3,
                                ),
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

    if (userId == _currentUserDetails?.id) {
      _showSnackBar('You cannot remove yourself from the group', isError: true);
      return;
    }

    final themeColor = ref.watch(themeColorProvider);
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
              backgroundColor: themeColor.primary,
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

          await _conversationMemberRepository
              .deleteMemberByConversationAndUserId(
                widget.group.conversationId,
                userId,
              );

          await _loadGroupInfoFromLocal(); // Refresh group info
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
    final groupTitle = _groupInfo?['title'] ?? 'this group';

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
        await _conversationRepository.deleteConversation(
          widget.group.conversationId,
        );

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
    if (isError) {
      Snack.error(message);
    } else {
      Snack.success(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Group Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(themeColor.primary),
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
                    onPressed: _loadGroupInfoFromLocal,
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
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    children: [
                      // Group Header Card
                      Card(
                        elevation: 0,
                        color: Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildGroupAvatar(
                                _groupInfo?['title'] ?? 'Group',
                                radius: 50,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _capitalizeFirstLetter(
                                        _groupInfo?['title'] ?? 'Group',
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
                                          : Icon(
                                              Icons.edit,
                                              color: themeColor.primary,
                                            ),
                                      tooltip: 'Edit group title',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created by ${_groupInfo?['createrName'] ?? 'Unknown'}',
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
                        elevation: 0,
                        color: Colors.grey[100],
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
                                    'Members (${_memberSearchQuery.isEmpty ? (_groupInfo?['members']?.length ?? 0) : _filteredMembers.length})',
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
                                        backgroundColor: themeColor.primary,
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
                              // Search Bar for Members
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _memberSearchQuery = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search members by name',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.grey.shade600,
                                    ),
                                    suffixIcon: _memberSearchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              color: Colors.grey.shade600,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _memberSearchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_groupInfo?['members'] != null)
                                if (_filteredMembers.isEmpty &&
                                    _memberSearchQuery.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No members found',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Try a different search term',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...(_filteredMembers.map((member) {
                                    final isAdmin = member['role'] == 'admin';
                                    final isCurrentUser =
                                        member['userId'] ==
                                        _currentUserDetails?.id;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser
                                            ? themeColor.primaryLight
                                                  .withOpacity(0.2)
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isCurrentUser
                                            ? Border.all(
                                                color: themeColor.primaryLight
                                                    .withOpacity(0.6),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: isAdmin
                                                ? Colors.amber.shade100
                                                : themeColor.primaryLight
                                                      .withOpacity(0.4),
                                            child: Text(
                                              ((member['userName'] ??
                                                          member['name'] ??
                                                          '?')
                                                      as String)[0]
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: isAdmin
                                                    ? Colors.amber.shade700
                                                    : themeColor.primary,
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
                                                          member['name'] ??
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
                                                          color: themeColor
                                                              .primary,
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
                                                              color:
                                                                  Colors.white,
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
                                                                color: Colors
                                                                    .white,
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
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 4,
                                                        ),
                                                    child: Material(
                                                      color:
                                                          Colors.amber.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        onTap: () => _promoteToAdmin(
                                                          member['userId'],
                                                          member['userName'] ??
                                                              member['name'] ??
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
                                                    margin:
                                                        const EdgeInsets.only(
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
                                                        onTap: () => _demoteToMember(
                                                          member['userId'],
                                                          member['userName'] ??
                                                              member['name'] ??
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
                                                  onPressed: () =>
                                                      _removeMember(
                                                        member['userId'],
                                                        member['userName'] ??
                                                            member['name'] ??
                                                            'Unknown',
                                                      ),
                                                  icon: Icon(
                                                    Icons.remove_circle_outline,
                                                    color: themeColor.primary,
                                                  ),
                                                  tooltip: 'Remove member',
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList()),
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
                                color: Colors.red.withAlpha(20),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.all(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    // decoration: BoxDecoration(
                                    //   color: Colors.red.shade50,
                                    //   borderRadius: BorderRadius.circular(12),
                                    // ),
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
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Permanently delete this group and all its messages',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          onPressed: _showDeleteGroupDialog,
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
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
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
